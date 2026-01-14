module frame_scheduler_example;
import std;
import std::experimental::frame_scheduler;
import std::time;
import std::time::clock;
import std::thread;
import std::math::random;

// Define an event structure
enum EventType
{
    SYSTEM_LOG,
    NETWORK_RESPONSE,
    VFX_SPAWN,
    SHUTDOWN
}

struct AppEvent
{
    EventType type;
    int id;
    String message;
}

fn void main()
{
    // Initialize the scheduler for AppEvent types
    FrameScheduler{AppEvent} scheduler;
    scheduler.init();

    io::printfn("=== FrameScheduler Capability Test ===\n"
    			"[System] Starting main simulation loop...");

    Clock start_time = clock::now();

    // 1. Schedule some "future" events
    scheduler.queue_delayed_event((AppEvent){ .type = EventType.SYSTEM_LOG, .message = "Snapshot: at 1.0s elapsed"        }, time::sec(1));
    scheduler.queue_delayed_event((AppEvent){ .type = EventType.SYSTEM_LOG, .message = "Snapshot: at 2.0s elapsed"        }, time::sec(2));
    scheduler.queue_delayed_event((AppEvent){ .type = EventType.SHUTDOWN,   .message = "Simulation complete - exiting" }, time::ms(1500 + (usz)rand(1000)));

    // 2. Immediate events
    scheduler.queue_event((AppEvent){ .type = EventType.SYSTEM_LOG, .message = "System Online" });

    // 3. Start a background "Worker" thread to simulate async network traffic
    Thread t;
    (void)Thread.create(&t, &background_worker, &scheduler);
    (void)t.detach();

    bool running = true;
    while (running)
    {
        NanoDuration elapsed = clock::now() - start_time;
        float timestamp = elapsed.to_duration().to_ms() / 1000.0f;

        // "Frame" processing: Pop and handle all events currently ready
        while (try event = scheduler.pop_event())
        {
            io::printf("[%5.2fs] ", timestamp);
            
            switch (event.type)
            {
                case EventType.SYSTEM_LOG:
                    io::printfn("LOG: %s", event.message);
                case EventType.NETWORK_RESPONSE:
                    io::printfn("NET: Received packet #%d - '%s'", event.id, event.message);
                case EventType.VFX_SPAWN:
                    io::printfn("VFX: Spawning particle effect %s %d", event.message, event.id);
                case EventType.SHUTDOWN:
                    io::printfn("CMD: %s", event.message);
                    running = false;
            }
        }

        thread::sleep(time::us(16666)); // ~60 FPS polling
    }

    io::printfn("[System] Cleaning up resources...");
    
    // The @destroy macro allows us to define how to handle events still in the queue
    scheduler.@destroy(; AppEvent remaining) {
        io::printfn("[Cleanup] Discarding unprocessed event: %s", remaining.message);
    };

    io::printfn("=== Simulation Finished ===");
}

/**
 * Simulates an asynchronous process (like a network thread) 
 * pushing events to the scheduler at random intervals.
 */
fn int background_worker(void* arg) => @pool_init(mem, 4 * 1024)
{
    FrameScheduler{AppEvent}* scheduler = (FrameScheduler{AppEvent}*)arg;
    
    for (int i = 1; i <= 3; i++)
    {
        // Simulate varying latency
        thread::sleep(time::ms(200 + (usz)rand(400)));
        
        scheduler.queue_event((AppEvent){ 
            .type = EventType.NETWORK_RESPONSE, 
            .id = i, 
            .message = "OK" 
        });

        // Also schedule a secondary VFX effect to happen slightly after the network response
        scheduler.queue_delayed_event((AppEvent){
            .type = EventType.VFX_SPAWN,
            .id = 100 + i,
            .message = "Spark"
        }, time::ms(200));
    }
    
    return 0;
}
