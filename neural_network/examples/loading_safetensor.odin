package nn_examples;

import "core:testing"
import "core:fmt"
import "core:time"
import "core:log"
import "core:mem"

import "../../utils"

import nn ".."

//@(test) load_safetensor_1 :: proc (t : ^testing.T) {

entry :: proc() {
	
	//nn.load_safetensors_from_filename("tiny_model/model.safetensors");
	
	// Time tokenization
	start_tokenize := time.now()
	tokens := nn.tokenize_string("This is my string", "tiny_model");
	tokenize_duration := time.diff(start_tokenize, time.now())
	log.infof("Tokenization took: %v", tokenize_duration)
	
	// Time configuration loading
	start_config := time.now()
	config := nn.load_configuration("tiny_model/config.json");
	config_duration := time.diff(start_config, time.now())
	log.infof("Config loading took: %v", config_duration)
	
	fmt.printf("config : %#v\n", config);
	
	// Time inference
	start_inference := time.now()
	s := nn.inference_model("tiny_model", tokens);
	inference_duration := time.diff(start_inference, time.now())
	log.infof("Inference took: %v", inference_duration)
	
	// Print total time
	total_duration := tokenize_duration + config_duration + inference_duration
	log.infof("Total processing time: %v", total_duration)
	
	fmt.printf("output :%v", string(s))
	
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