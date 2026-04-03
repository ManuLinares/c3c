module fixed_pool_bench;

import std::thread::threadpool;

FixedThreadPool pool;

fn void init_bench() @init
{
	pool.init(8)!!;
	set_benchmark_warmup_iterations(1);
	set_benchmark_max_iterations(5);
}

fn void empty_task(any[] args) {}

fn void spawner_task(any[] args)
{
	FixedThreadPool* p = *anycast(args[0], FixedThreadPool*)!!;
	int depth = *anycast(args[1], int)!!;
	if (depth > 0)
	{
		p.push(&spawner_task, p, depth - 1)!!;
		p.push(&spawner_task, p, depth - 1)!!;
	}
}

fn void global_queue() @benchmark
{
	@start_benchmark();
	for (int i = 0; i < 50000; i++) pool.push(&empty_task)!!;
	pool.join();
	@end_benchmark();
}

fn void local_spawning() @benchmark
{
	@start_benchmark();
	pool.push(&spawner_task, &pool, 19)!!;
	pool.join();
	@end_benchmark();
}

fn void work_stealing() @benchmark
{
	@start_benchmark();
	for (int i = 0; i < 8; i++) pool.push(&spawner_task, &pool, 16)!!;
	pool.join();
	@end_benchmark();
}
