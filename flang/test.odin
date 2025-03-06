package flang;

import "../utils"
import "core:fmt"
import "core:mem"

test :: proc () {
	
	s := create_context_from_file("shaders/test.flang");
	defer destroy_contrext(s);
	
	lex(s);
	parse_and_check(s);
	
	emit_glsl_330(s);
	
}

main :: proc () {
	
	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	context.logger = utils.create_console_logger(.Info);
	defer utils.destroy_console_logger(context.logger);
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,
		
		test();
		
		free_all(context.temp_allocator);
	}
	
	utils.print_tracking_memory_results();
	utils.destroy_tracking_allocators();
}


