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

my_print :: proc (args : []sand.Sand_value) -> sand.Sand_value {	
	//fmt.printf(to_print);
	
	assert(len(args) != 0);
	
	first, ok := args[0].(string);
	assert(ok)
	
	printed : [dynamic]any;
	defer delete(printed);
	
	for a, i in args {
		if i != 0 {
			append(&printed, a);
		}
	}
	
	fmt.printf(first, ..printed[:]);
	
	return nil;
}  

entry :: proc () {
	
	ud : Sand_user_data;
	
	lang := sand.init(&ud);
	defer sand.destroy(lang);
	
	
	sand.expose_func(lang, "print", my_print);
	errs := sand.add_file(lang, "sandfiles/test1.sl");
	
	for name, func in lang.global_scope.functions {
		log.infof("global state has func %v", name);
	}
	
	for e in errs {
		fmt.panicf("Error : %v", e);
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

