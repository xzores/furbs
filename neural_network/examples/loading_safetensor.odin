package nn_examples;

import "core:testing"
import "core:fmt"
import "core:time"

import "../../utils"

import nn ".."

//@(test) load_safetensor_1 :: proc (t : ^testing.T) {

entry :: proc() {
	
	//nn.load_safetensors_from_filename("tiny_model/model.safetensors");
	tokens := nn.tokenize_string("This is my string", "tiny_model");
	
	config := nn.load_configuration("tiny_model/config.json");
	
	fmt.printf("config : %#v\n", config);
	
	//my_model := nn.load_model();
	s := nn.inference_model("tiny_model", tokens);
	//fmt.printf("%v", string(s))
	
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