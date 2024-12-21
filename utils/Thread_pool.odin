package utils;

import base_thread "core:thread"
import "base:intrinsics"
import "core:sync"
import "core:mem"
import "core:container/queue"

Task :: base_thread.Task;
Task_Proc :: base_thread.Task_Proc;

pool_start :: base_thread.pool_start;

pool_join :: base_thread.pool_join;

pool_num_waiting :: base_thread.pool_num_waiting;

pool_num_in_processing :: base_thread.pool_num_in_processing;

pool_num_outstanding :: base_thread.pool_num_outstanding;

pool_num_done :: base_thread.pool_num_done;

pool_is_empty :: base_thread.pool_is_empty;

pool_pop_waiting :: base_thread.pool_pop_waiting;

pool_pop_done :: base_thread.pool_pop_done;

pool_do_work :: base_thread.pool_do_work;

pool_finish :: base_thread.pool_finish;

pool_add_task :: base_thread.pool_add_task;

Pool :: struct {
	using _base : base_thread.Pool,

	untils_threads : []^Thread,	
	priority : base_thread.Thread_Priority,
};

pool_init :: proc(pool: ^Pool, allocator: mem.Allocator, thread_count: int, priority := base_thread.Thread_Priority.Normal) {
	context.allocator = allocator
	pool.allocator = allocator
	queue.init(&pool.tasks);
	pool.tasks_done = make([dynamic]Task)
	pool.untils_threads = make([]^Thread, max(thread_count, 1));
	pool.threads    = make([]^base_thread.Thread, max(thread_count, 1));
	pool.priority = priority;
	
	pool.is_running = true

	for _, i in pool.untils_threads {
		t := create(proc(t: ^Thread) {
			pool := (^Pool)(t.data);

			for intrinsics.atomic_load(&pool.is_running) {
				sync.wait(&pool.sem_available)

				if task, ok := pool_pop_waiting(pool); ok {
					pool_do_work(pool, task)
				}
			}

			sync.post(&pool.sem_available, 1)
		}, pool, i, priority)
		t.user_index = i
		t.data = pool
		pool.untils_threads[i] = t;
	}

	for t, i in pool.untils_threads {
		pool.threads[i] = t.base;
	}

}

pool_destroy :: proc(pool: ^Pool) {
	queue.destroy(&pool.tasks);
	delete(pool.tasks_done);

	for &t in pool.untils_threads {
		destroy(t);
		free(t);
	}

	delete(pool.threads, pool.allocator);
	delete(pool.untils_threads, pool.allocator);
}


