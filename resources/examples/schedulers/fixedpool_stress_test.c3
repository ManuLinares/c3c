module fixedpool_stress_test;
import std;

const int INTENSITY = 1;

Atomic{long} global_counter;

fn void main()
{
	usz num_threads = os::num_cpu();
	io::printfn(">>> Starting Work-Stealing Pool Stress Test (%d threads, x%d Intensity) <<<", num_threads, INTENSITY);

	FixedThreadPool pool;
	pool.init(num_threads, 65536)!!;
	defer pool.stop_and_destroy();

	Stopwatch sw;
	String desc; 

	// ---------------------------------------------------------
	// 1. Flat Push (Throughput & Backpressure)
	// ---------------------------------------------------------
	const int COUNT_FLAT = 100_000 * INTENSITY;
	
	// FIXED: Using string::tformat
	desc = string::tformat("1. [Flat Push] Pushing %d tasks...", COUNT_FLAT);
	io::printf("%-60s", desc);

	global_counter.store(0);
	sw.reset();
	sw.start();

	for (int i = 0; i < COUNT_FLAT; i++)
	{
		pool.push_wait(&task_light)!!;
	}

	pool.join();
	sw.stop();

	if (global_counter.load() != COUNT_FLAT)
	{
		io::printfn("FAILED! Expected %d, got %d", COUNT_FLAT, global_counter.load());
		return;
	}
	report_success(sw.elapsed().to_ms(), COUNT_FLAT);


	// ---------------------------------------------------------
	// 2. Recursion (Local Deque / Stealing)
	// ---------------------------------------------------------
	const int DEPTH = 20;
	long nodes_per_tree = (1L << (DEPTH + 1)) - 1;
	long total_expected = nodes_per_tree * INTENSITY;

	desc = string::tformat("2. [Recursion] Building %d trees (depth %d, %d nodes)...", INTENSITY, DEPTH, total_expected);
	io::printf("%-60s", desc);

	global_counter.store(0);
	sw.reset();
	sw.start();

	for (int i = 0; i < INTENSITY; i++)
	{
		pool.push_wait(&task_recursive_tree, DEPTH, &pool)!!;
	}

	pool.join();
	sw.stop();

	if (global_counter.load() != total_expected)
	{
		io::printfn("FAILED! Expected %d, got %d", total_expected, global_counter.load());
		return;
	}
	report_success(sw.elapsed().to_ms(), total_expected);


	// ---------------------------------------------------------
	// 3. Load Balance (Mixed Heavy/Light)
	// ---------------------------------------------------------
	const int COUNT_HEAVY = 100 * INTENSITY;
	const int COUNT_LIGHT = 40_000 * INTENSITY;
	long total_mixed = (long)(COUNT_HEAVY + COUNT_LIGHT);

	desc = string::tformat("3. [Load Balance] %d Heavy + %d Light tasks...", COUNT_HEAVY, COUNT_LIGHT);
	io::printf("%-60s", desc);

	global_counter.store(0);
	sw.reset();
	sw.start();

	for (int i = 0; i < COUNT_HEAVY; i++) pool.push_wait(&task_heavy)!!;
	for (int i = 0; i < COUNT_LIGHT; i++) pool.push_wait(&task_light)!!;

	pool.join();
	sw.stop();

	if (global_counter.load() != total_mixed)
	{
		io::printfn("FAILED! Expected %d, got %d", total_mixed, global_counter.load());
		return;
	}
	report_success(sw.elapsed().to_ms(), total_mixed);

	io::printn("\n>>> All Stress Tests Passed <<<");
}

/* --- Helpers --- */

fn void report_success(long ms, long count)
{
	long safe_ms = ms > 0 ? ms : 1; 
	long rate = (count * 1000) / safe_ms;
	
	io::printfn("SUCCESS | Time: %5dms | Rate: %9d ops/sec", ms, rate);
}

struct Stopwatch
{
	Clock _start_time;
	NanoDuration _accumulated;
	bool _running;
}

fn void Stopwatch.start(&self)
{
	if (self._running) return;
	self._start_time = clock::now();
	self._running = true;
}

fn void Stopwatch.stop(&self)
{
	if (!self._running) return;
	self._accumulated += clock::now() - self._start_time;
	self._running = false;
}

fn void Stopwatch.reset(&self)
{
	self._accumulated = (NanoDuration)0;
	self._running = false;
}

fn NanoDuration Stopwatch.elapsed(&self)
{
	if (self._running)
	{
		return self._accumulated + (clock::now() - self._start_time);
	}
	return self._accumulated;
}

/* --- Tasks --- */

fn void task_light(any[] args)
{
	global_counter.add(1, RELAXED);
}

fn void task_recursive_tree(any[] args)
{
	int depth = *anycast(args[0], int)!!;
	global_counter.add(1, RELAXED);

	if (depth > 0)
	{
		int new_depth = depth - 1;
		FixedThreadPool* pool = *anycast(args[1], FixedThreadPool*)!!;
		
		pool.push(&task_recursive_tree, new_depth, pool)!!;
		pool.push(&task_recursive_tree, new_depth, pool)!!;
	}
}

fn void task_heavy(any[] args)
{
	thread::sleep_ms(10);
	task_light(args);
}