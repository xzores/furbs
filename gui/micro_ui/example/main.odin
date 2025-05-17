package gui_exmaple;

import "core:mem"

import gui ".."
import "../../render"
import "core:fmt"
import "../../utils"

entry :: proc () {
	
	window_desc : render.Window_desc = {
		width = 1000,
		height = 1000,
		title = "my gui window",
		resize_behavior = .allow_resize,
		antialiasing = .msaa4,
	}
	
	window := render.init({}, required_gl_verion = .opengl_4_3, window_desc = window_desc, pref_warn = true);
	defer render.destroy();
	
	////////////////////
	
	vsync : bool = true;
	fullscreen : render.Fullscreen_mode = .windowed;
	render.window_set_vsync(vsync);
	
	////////////////////
	
	s_gui := gui.init(window);
	defer gui.destroy(s_gui);
	
	for !render.window_should_close(window) {
		
		render.begin_frame();
			
			render.target_begin(window, [4]f32{0.24, 0.34, 0.12, 1});
				
				gui.begin(s_gui);
				
					gui.begin_window(s_gui, "My window", {500, 50, 100, 200}, {});
						
						//gui.draw_quad(s_gui, {10, 10, 10, 10}, {0.3, 0.1, 0.3, 1});
						
					gui.end_window(s_gui);
				
				gui.end(s_gui);
				
				render.draw_fps_overlay();
			render.target_end();
			
		render.end_frame();
		mem.free_all(context.temp_allocator);
	}
	
	
	
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