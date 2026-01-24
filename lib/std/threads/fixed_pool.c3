module std::thread;
faultdef THREAD_QUEUE_FULL;

module std::thread::threadpool @if (env::POSIX || env::WIN32);
import std::thread;
import std::thread::cpu;
import std::math::random;
import std::time;
import std::atomic::types;
import libc;

// A high-performance Work-Stealing Thread Pool.
// Uses Chase-Lev Deques for local work and a Ring Buffer for global fallback.

alias ThreadPoolFn = fn void(any[] args);

struct FixedThreadPool
{
	Worker*[] workers;
	
	// Dynamic Ring Buffer
	GlobalQueue global_queue;
	Mutex global_mu;

	Atomic{bool} initialized;
	Atomic{bool} stop;      // Stop accepting new, finish current
	Atomic{bool} stop_now;  // Stop immediately
	
	Atomic{int} active_jobs; // Track active work for join()
	
	Mutex sync_mu;
	ConditionVariable worker_cond; // Workers sleep here
	ConditionVariable join_cond;   // join() sleeps here
}

<*
 @require !self.initialized.load() : "ThreadPool must not be already initialized"
 @require threads > 0 && threads < 0x1000 : `Threads should be greater than 0 and less than 0x1000`
*>
fn void? FixedThreadPool.init(&self, usz threads, usz queue_size = 0)
{
	if (self.initialized.load()) return;
	defer catch @ok(self.destroy());

	// Default size if 0
	if (queue_size == 0) queue_size = threads * 256;
	
	// Determine local deque capacity
	usz local_size = queue_size / threads;
	if (local_size < 256) local_size = 256;
	
	*self = {
		.workers = mem::new_array(Worker*, threads),
	};
	
	self.global_queue.init(queue_size);
	self.global_mu.init()!;
	self.sync_mu.init()!;
	self.worker_cond.init()!;
	self.join_cond.init()!;
	
	self.initialized.store(true);
	self.stop.store(false);
	self.stop_now.store(false);
	self.active_jobs.store(0);

	for (usz i = 0; i < threads; i++)
	{
		// Workers are aligned to prevent false sharing
		Worker* w = mem::new_aligned(Worker);
		w.id = (int)i;
		w.pool = self;
		w.deque.init(local_size);
		random::seed(&w.rng, (ulong)libc::time(null) + i);
		
		self.workers[i] = w;
		w.thread.create(&process_work, w)!;
	}
}

<*
 Join all tasks in the pool.
 Waits until all queued and active jobs are finished.
*>
fn void? FixedThreadPool.join(&self) @maydiscard
{
	if (!self.initialized.load()) return;

	self.sync_mu.lock();
	defer self.sync_mu.unlock();

	// Wait while there are jobs in queue or running
	while (self.active_jobs.load(RELAXED) > 0)
	{
		self.join_cond.wait(&self.sync_mu);
	}
}

<*
 Push a new job to the pool.
 @require func != null : "Job function cannot be null"
*>
fn void? FixedThreadPool.push(&self, ThreadPoolFn func, args...)
{
	if (!self.initialized.load() || self.stop.load()) return thread::THREAD_QUEUE_FULL~;

	// 1. Prepare Data
	any[] data;
	if (args.len > 0)
	{
		data = mem::alloc_array(any, args.len);
		foreach (i, arg : args) data[i] = allocator::clone_any(mem, arg);
	}
	
	// Allocate the job container
	QueueItem* item = mem::new(QueueItem);
	*item = { func, data };

	self.active_jobs.add(1);

	// 2. Try Local Push (Work Stealing Optimization)
	// If the caller is a worker thread of THIS pool, push to its own lock-free deque.
	bool pushed = false;
	Worker* local_worker = tls_current_worker;

	if (local_worker && local_worker.pool == self)
	{
		if (local_worker.deque.push(item)) pushed = true;
	}

	// 3. Fallback to Global Queue (Locking)
	if (!pushed)
	{
		self.global_mu.lock();
		if (!self.global_queue.push(item))
		{
			// Critical: Queue is full. Cleanup and error.
			self.global_mu.unlock();
			self.active_jobs.sub(1);
			free_qitem(item);
			return thread::THREAD_QUEUE_FULL~;
		}
		self.global_mu.unlock();
	}

	// 4. Wake up a sleeping worker
	self.worker_cond.signal();
}

<*
 Push a job, blocking the current thread if the queue is full.
 It yields the CPU to allow workers to drain the queue.
 
 Returns THREAD_QUEUE_FULL~ only if the pool is stopped/destroyed.
*>
macro void? FixedThreadPool.push_wait(&self, ThreadPoolFn func, args...)
{
	int spins = 0;
	while (true)
	{
		if (try self.push(func, ...args)) return;

		if (self.stop.load(RELAXED) || !self.initialized.load(RELAXED)) 
		{
			return thread::THREAD_QUEUE_FULL~;
		}

		// If just full, we wait.
		if (spins++ < 32)
		{
			// CPU-level pause
			cpu::relax();
		}
		else
		{
			// let other threads run
			thread::yield();
		}
	}
}

<*
 Stop all the threads and cleanup the pool.
 Any pending work will be dropped.
*>
fn void? FixedThreadPool.destroy(&self)
{
	self.@shutdown(true);
}

<*
 Stop all the threads and cleanup the pool.
 Any pending work will be processed.
*>
fn void? FixedThreadPool.stop_and_destroy(&self) @maydiscard
{
	self.@shutdown(false);
}

macro void FixedThreadPool.@shutdown(&self, bool stop_now) @private
{
	if (!self.initialized.load()) return;
	
	// Signal stop
	if (stop_now) 
	{
		self.stop_now.store(true);
	}
	else 
	{
		self.stop.store(true);
	}
	
	self.worker_cond.broadcast();

	// Join threads
	foreach (w : self.workers)
	{
		if (w) w.thread.join();
	}

	// Cleanup Global Queue
	self.global_mu.lock();
	while (QueueItem* item = self.global_queue.pop()) free_qitem(item);
	self.global_queue.destroy();
	self.global_mu.unlock();

	// Cleanup Workers
	foreach (w : self.workers)
	{
		if (!w) continue;
		while (QueueItem* item = w.deque.pop()) free_qitem(item);
		w.deque.destroy();
		mem::free_aligned(w);
	}
	mem::free(self.workers);

	self.global_mu.destroy();
	self.sync_mu.destroy();
	self.worker_cond.destroy();
	self.join_cond.destroy();
	
	self.initialized.store(false);
}

fn int process_work(void* arg) @private
{
	Worker* self = (Worker*)arg;
	FixedThreadPool* pool = self.pool;
	
	// Set TLS for efficient push() checks
	tls_current_worker = self;

	const int SPIN_COUNT = 64;

	while (true)
	{
		if (pool.stop_now.load(RELAXED)) break;

		QueueItem* item = null;
		
		// ------------------------------------------
		// 1. Try Local LIFO (Fastest)
		// ------------------------------------------
		item = self.deque.pop();

		// ------------------------------------------
		// 2. Try Global FIFO (Medium)
		// ------------------------------------------
		if (!item)
		{
			// Check length before locking to reduce contention
			if (pool.global_queue.count > 0)
			{
				bool locked = false;
				$if (!env::WIN32):
					// On POSIX, try_lock prevents halting the thread if busy
					locked = pool.global_mu.try_lock();
				$else
					// Windows mutexes behave differently, just lock
					pool.global_mu.lock();
					locked = true;
				$endif

				if (locked)
				{
					item = pool.global_queue.pop();
					pool.global_mu.unlock();
				}
			}
		}

		// ------------------------------------------
		// 3. Try Stealing (Remote FIFO)
		// ------------------------------------------
		if (!item)
		{
			int len = (int)pool.workers.len;
			int start = (int)random::next(&self.rng, (uint)len);
			
			for (int i = 0; i < len; i++)
			{
				int idx = (start + i);
				if (idx >= len) idx -= len; // Manual Modulo
				if (idx == self.id) continue;
				
				Worker* victim = pool.workers[idx];
				if (!victim) continue;

				item = victim.deque.steal();
				if (item) break;
			}
		}

		// ------------------------------------------
		// 4. Process or Wait
		// ------------------------------------------
		if (item)
		{
			item.func(item.args);
			free_qitem(item);
			
			// Decrement active jobs. Returns OLD value.
			// If it was 1 and becomes 0, notify joiners.
			if (pool.active_jobs.sub(1) == 1)
			{
				pool.sync_mu.lock();
				pool.join_cond.broadcast();
				pool.sync_mu.unlock();
			}
		}
		else
		{
			if (pool.stop.load(RELAXED)) break;

			// Spin briefly before sleeping (Latency reduction)
			bool spin_found = false;
			for (int s = 0; s < SPIN_COUNT; s++)
			{
				thread::yield();
				if (pool.stop_now.load(RELAXED) || pool.stop.load(RELAXED) || pool.global_queue.count > 0) 
				{
					spin_found = true; 
					break;
				}
			}
			if (spin_found) continue;

			// Sleep
			pool.global_mu.lock();
			if (!pool.stop.load(RELAXED) && !pool.stop_now.load(RELAXED) && pool.global_queue.count == 0)
			{
				(void)pool.worker_cond.wait_timeout(&pool.global_mu, 10);
			}
			pool.global_mu.unlock();
		}
	}
	return 0;
}

fn void free_qitem(QueueItem* item) @private
{
	foreach (arg : item.args) free(arg.ptr);
	free(item.args);
	free(item);
}

// --- Data Structures ---

tlocal Worker* tls_current_worker @private;

struct QueueItem
{
	ThreadPoolFn func;
	any[] args;
}

struct Worker @private
{
	Thread thread;
	ChaseLevDeque deque;
	FixedThreadPool* pool;
	int id;
	DefaultRandom rng; 
}

// Internal Ring Buffer for Global Queue
struct GlobalQueue
{
	QueueItem*[] items;
	usz head;
	usz tail;
	usz count;
}

fn void GlobalQueue.init(&self, usz capacity)
{
	self.items = mem::alloc_array(QueueItem*, capacity);
	self.head = 0;
	self.tail = 0;
	self.count = 0;
}

fn void GlobalQueue.destroy(&self)
{
	if (self.items.len > 0) mem::free(self.items);
}

fn bool GlobalQueue.push(&self, QueueItem* item)
{
	if (self.count == self.items.len) return false;
	
	self.items[self.tail] = item;
	self.tail = (self.tail + 1);
	if (self.tail == self.items.len) self.tail = 0;
	
	self.count++;
	return true;
}

fn QueueItem* GlobalQueue.pop(&self)
{
	if (self.count == 0) return null;
	
	QueueItem* item = self.items[self.head];
	self.head = (self.head + 1);
	if (self.head == self.items.len) self.head = 0;
	
	self.count--;
	return item;
}

const usz CACHE_LINE = 64;

// Chase-Lev Work Stealing Deque (Lock-Free)
struct ChaseLevDeque
{
	Atomic{isz} top;
	Atomic{isz} bottom @align(CACHE_LINE);
	Atomic{QueueItem*}[] buffer @align(CACHE_LINE);
	usz mask;
}

<*
 @require capacity > 0 : "Capacity must be positive"
*>
fn void ChaseLevDeque.init(&self, usz capacity)
{
	self.top.store(0, RELAXED);
	self.bottom.store(0, RELAXED);
	
	// Power of 2 sizing for efficient masking
	usz cap = 256;
	while (cap < capacity) cap <<= 1;
	
	self.buffer = mem::alloc_array(Atomic{QueueItem*}, cap);
	self.mask = cap - 1;
}

fn void ChaseLevDeque.destroy(&self)
{
	if (self.buffer.len > 0) mem::free(self.buffer);
}

<*
 @require item != null
*>
fn bool ChaseLevDeque.push(&self, QueueItem* item) @inline
{
	isz b = self.bottom.load(RELAXED);
	isz t = self.top.load(ACQUIRE);
	
	if (b - t > (isz)self.mask) return false; 

	self.buffer[b & (isz)self.mask].store(item, RELAXED);
	thread::fence(RELEASE);
	self.bottom.store(b + 1, RELAXED);
	return true;
}

fn QueueItem* ChaseLevDeque.pop(&self) @inline
{
	isz b = self.bottom.load(RELAXED) - 1;
	self.bottom.store(b, RELAXED);
	thread::fence(SEQ_CONSISTENT);
	
	isz t = self.top.load(RELAXED);
	
	if (t > b)
	{
		self.bottom.store(b + 1, RELAXED);
		return null;
	}
	
	QueueItem* item = self.buffer[b & (isz)self.mask].load(RELAXED);
	
	if (t != b) return item;

	// Race for the last item
	if (mem::compare_exchange(&self.top.data, t, t + 1, SEQ_CONSISTENT, RELAXED) != t)
	{
		self.bottom.store(b + 1, RELAXED);
		return null;
	}

	self.bottom.store(b + 1, RELAXED);
	return item;
}

fn QueueItem* ChaseLevDeque.steal(&self) @inline
{
	isz t = self.top.load(ACQUIRE);
	thread::fence(SEQ_CONSISTENT);
	isz b = self.bottom.load(ACQUIRE);
	
	if (t >= b) return null;

	QueueItem* item = self.buffer[t & (isz)self.mask].load(RELAXED);

	if (mem::compare_exchange(&self.top.data, t, t + 1, SEQ_CONSISTENT, RELAXED) != t)
	{
		return null;
	}

	return item;
}

module std::thread::cpu;

<*
 Hints to the processor that the current thread is performing a busy-wait loop.
*>
fn void relax() @inline
{
	$switch env::ARCH_TYPE:
		$case RISCV32:
		$case RISCV64:
		$case X86:
		$case X86_64:
			asm("pause");
		$case ARM:
		$case AARCH64:
			asm("yield");
		$default:
			// __asm__ volatile("" ::: "memory");
	$endswitch
}

/**
 * Example Usage:
 *
 * import std::io;
 * import std::thread::threadpool;
 *
 * fn void main()
 * {
 *     FixedThreadPool pool;
 *
 *     // 1. Initialize (for example, 4 threads)
 *     pool.init(4)!!;
 *     defer pool.destroy();
 *
 *     // 2. Standard Usage (Global Queue):
 *     // We push 13 tasks (more than the thread count).
 *     // Since 'main' is not a worker, these go to the central Global Queue.
 *     foreach (i : 0..13)
 *     {
 *         pool.push(&print_task, i, "Global Job")!!;
 *     }
 *
 *     // 3. Advanced Usage (Work Stealing):
 *     // We push a task that generates *more* tasks.
 *     // Pushing from within a worker puts tasks in the Local Deque (Chase-Lev).
 *     // This reduces contention and allows idle threads to 'steal' this work.
 *     pool.push(&generator_task, &pool)!!;
 *
 *     // 4. Wait for all tasks to complete
 *     pool.join();
 * }
 *
 * fn void print_task(any[] args)
 * {
 *     // Unpack arguments safely
 *     int id = *anycast(args[0], int)!!;
 *     String name = *anycast(args[1], String)!!;
 *
 *     io::printfn("[Task %d] %s", id, name);
 * }
 *
 * fn void generator_task(any[] args)
 * {
 *     // Retrieve the pool pointer passed as an argument
 *     FixedThreadPool* p = *anycast(args[0], FixedThreadPool*)!!;
 *
 *     io::printn("Worker generating sub-tasks...");
 *
 *     // These pushes happen inside a Worker.
 *     // They go into this thread's Local Deque (LIFO).
 *     p.push(&print_task, 100, "Sub-Task A")!!;
 *     p.push(&print_task, 101, "Sub-Task B")!!;
 * }
 */

