package main_tokenizer;

import "core:log"
import "core:mem"
import "core:fmt"
import "../../utils"

import sand ".."

Sand_user_data :: struct {

}

import_callback :: proc (to_import : string, sand_state : ^sand.Sand_state, user_data : rawptr) {
	user_data := cast(^Sand_user_data)user_data;
	
	log.debugf("Importing %v", to_import);
	
}

entry :: proc () {
	
	lang := sand.init();
	defer sand.destroy(lang);
	
	errs := sand.add_file(lang, "sandfiles/test1.sl");
	
	for e in errs {
		//fmt.panicf("Error : %v, got %v", e, );
	}
	
	for name, func in lang.global_scope.functions {
		log.debugf("func %v has instructions : %#v", name, func.instructions);
	}
	
	sand.call_func(lang, "my_func");
	
}



























main :: proc () {
	
	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);
	
	when ODIN_DEBUG {
		context.assertion_failure_proc = utils.init_stack_trace();
		defer utils.destroy_stack_trace();
		
		
		utils.init_tracking_allocators();
		
		{
			tracker : ^mem.Tracking_Allocator;
			context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,
			
			entry();
		}
		
		utils.print_tracking_memory_results();
		utils.destroy_tracking_allocators();
	}
	else {
		entry();
	}
}

