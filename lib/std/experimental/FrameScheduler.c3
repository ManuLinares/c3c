<*
 A thread-safe event scheduler designed for frame-based processing loops.
 It supports immediate events and time-delayed events, ensuring that events
 pushed from any thread are processed safely in a controlled manner.

 Example usage:
 ```c3
	import std::experimental::frame_scheduler;

	struct MyEvent { int id; }

	// Instantiate generic scheduler
	FrameScheduler{MyEvent} scheduler;
	scheduler.init();

	// Cleanup with a handler for remaining events
	defer scheduler.@destroy(; MyEvent e) {
		io::printfn("Remaining event: %d", e.id);
	};

	// Queue safe from any thread
	scheduler.queue_event({1});

	// Process in frame loop
	while (try e = scheduler.pop_event())
	{
		// Handle event...
	}
 ```
*>
module std::experimental::frame_scheduler{Event} @if (env::POSIX || env::WIN32);
import std::collections, std::thread, std::time;

struct DelayedSchedulerEvent @local
{
	inline Event event;
	Clock execution_time;
}

fn int DelayedSchedulerEvent.compare_to(self, DelayedSchedulerEvent other) @local
{
	switch
	{
		case self.execution_time < other.execution_time: return -1;
		case self.execution_time > other.execution_time: return 1;
		default: return 0;
	}
}

<*
The FrameScheduler manages multiple event queues to facilitate
cross-thread communication and timed event execution.
*>
struct FrameScheduler
{
	PriorityQueue{DelayedSchedulerEvent} delayed_events;
	List{Event} events;
	List{Event} pending_events;
	bool pending;
	Mutex mtx;
}

<*
Initializes the FrameScheduler and its internal synchronization primitives.
@param [&out] self : `The scheduler instance to initialize.`
*>
fn void FrameScheduler.init(&self)
{
	self.events.init(mem);
	self.pending_events.init(mem);
	self.delayed_events.init(mem);
	(void)self.mtx.init();
	self.pending = false;
}

<*
Frees all resources associated with the scheduler and handles any remaining events.
@param [&inout] self : `The scheduler instance to destroy.`
@destruct `A macro body invoked for every unprocessed event still in the queues.`
*>
macro void FrameScheduler.@destroy(&self; @destruct(Event e))
{
	foreach (e : self.events) @destruct(e);
	foreach (e : self.pending_events) @destruct(e);
	foreach (e : self.delayed_events.heap) @destruct(e.event);
	self.events.free();
	self.pending_events.free();
	self.delayed_events.free();
	self.mtx.destroy();
}

<*
Queues an event to be processed after a specific delay.
@param [&inout] self : `The scheduler instance.`
@param event : `The event data to queue.`
@param delay : `The duration to wait before the event becomes ready.`
@require delay >= (Duration)0 : "Delay must be non-negative"
*>
fn void FrameScheduler.queue_delayed_event(&self, Event event, Duration delay)
{
	self.mtx.@in_lock()
	{
		self.delayed_events.push({ event, clock::now().add_duration(delay)});
		@atomic_store(self.pending, true);
	};
}

<*
Checks if there are any delayed events currently waiting in the queue.
@param [&in] self : `The scheduler instance.`
@return `true if there are delayed events, false otherwise.`
*>
fn bool FrameScheduler.has_delayed(&self)
{
	self.mtx.@in_lock()
	{
		return @ok(self.delayed_events.first());
	};
}

<*
Queues an event for immediate processing in the next batch.
@param [&inout] self : `The scheduler instance.`
@param event : `The event data to queue.`
*>
fn void FrameScheduler.queue_event(&self, Event event)
{
	self.mtx.@in_lock()
	{
		self.pending_events.push(event);
		@atomic_store(self.pending, true);
	};
}

<*
Retrieves the next ready event from the scheduler.
If the current frame's batch is empty, it will attempt to ingest any
pending immediate events and any delayed events that have matured.

@param [&inout] self : `The scheduler instance.`
@return `The next Event, or NO_MORE_ELEMENT? if no events are ready.`
*>
fn Event? FrameScheduler.pop_event(&self)
{
	while (true)
	{
		if (try event = self.events.pop()) return event;
    	if (!@atomic_load(self.pending)) return NO_MORE_ELEMENT~;
        self.mtx.@in_lock()
        {
            self.events.add_all(&self.pending_events);
            self.pending_events.clear();
            Clock c = clock::now();
            while (try top = self.delayed_events.first())
            {
                if (top.execution_time > c) break;
                self.events.push(self.delayed_events.pop()!!);
            }
            @atomic_store(self.pending, self.delayed_events.len() > 0);
            if (!self.events.len()) return NO_MORE_ELEMENT~;
        };
	}
}
