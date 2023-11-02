package utils;

import "core:mem"
import "core:fmt"
import "core:runtime"
import "core:sync"
import base_thread "core:thread"

Thread_Priority :: base_thread.Thread_Priority;

Thread_Proc :: #type proc(^Thread);

Thread :: struct {
	base 	: ^base_thread.Thread,
	procedure	: Thread_Proc,
	
	data		: rawptr,
	user_index	: int,
	creator 	: runtime.Source_Code_Location,
}

thread_global_allocator : mem.Allocator;
thread_global_temp_allocator : mem.Allocator;
thread_track_temp_allocators : bool;

create :: proc(procedure: Thread_Proc, data : rawptr, user_index : int = 0, priority := base_thread.Thread_Priority.Normal, loc := #caller_location) -> ^Thread {
	
	wrapper_proc : base_thread.Thread_Proc = proc(t : ^base_thread.Thread) {
		
		utils_thread : ^Thread = cast(^Thread)t.data;
		
		/// ALLOC SETUP ///
		alloc : mem.Allocator = context.allocator;
		if thread_global_allocator.data != nil {
			alloc = thread_global_allocator;
		}
		context.allocator = alloc;

		when MEM_DEBUG {
			/// TEMP ALLOC SETUP ///
			arena_alloc : runtime.Arena;
			temp_alloc : mem.Allocator = context.allocator; //this is the backing allocator.
			if thread_global_temp_allocator.data != nil {
				temp_alloc = thread_global_temp_allocator;
			}

			if thread_track_temp_allocators {
				temp_alloc = make_tracking_allocator(context.allocator);
			}
			err := runtime.arena_init(&arena_alloc, 0, context.allocator);
			assert(err == nil);
			context.temp_allocator = runtime.arena_allocator(&arena_alloc);
		}

		/// RUN THE PROC ///
		utils_thread.procedure(utils_thread);

		when MEM_DEBUG {
			/// DESTORY ///
			//Only destroy if, there is no memory leaks, otherwise we will mask them off.
			if arena_alloc.total_used == 0 {
				runtime.arena_destroy(&arena_alloc);
			}
		}
	}

	t : ^Thread = new(Thread, loc = loc);
	
	t.base = base_thread.create(wrapper_proc, priority);
	t.base.data = t;
	t.base.procedure = wrapper_proc;

	t.data = data;
	t.procedure = procedure;
	t.user_index = user_index;
	t.creator = loc;

	return t;
}

destroy :: proc(t: ^Thread, loc := #caller_location) {
	base_thread.destroy(t.base);
	//free(t, loc = loc); //TODO WHY SHOULD WE NOT DESTROY HERE?
}

start :: proc(t: ^Thread) {
	base_thread.start(t.base);
}

is_done :: proc(t: ^Thread) -> bool {
	return base_thread.is_done(t.base);
}

join :: proc(t: ^Thread) {
	base_thread.join(t.base);
}

terminate :: proc(t: ^Thread, exit_code: int) {
	base_thread.terminate(t.base, exit_code);
}