package python_wrap_example;

import "core:testing"
import "core:fmt"
import "core:time"
import "core:log"
import "core:mem"
import "core:os"

import wrap ".."

import "../../utils"

entry :: proc() {
	
	//wrap.promt_image_and_string("test1.jpg", "what color is the image", os.args[1]);	
	wrap.image_convert_png_and_denoise({"test1.jpg", "test2.jpg"});
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