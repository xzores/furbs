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
	
	s_gui := gui.init();
	defer gui.destroy(s_gui);
	
	checkbox_state : bool = false;
	slider_value : f32 = 0.5;
	text_buffer : cstring = "Edit me!";
	combo_index : int = 0;
	color := gui.Color{255, 0, 128, 255};
	
	for !render.window_should_close(window) {
		
		render.begin_frame();
			
			render.target_begin(window, [4]f32{0.24, 0.34, 0.12, 1});
				
				gui.begin(s_gui);
					
					// Window with title and basic widgets
					if gui.window_begin(s_gui, "Demo Window", rect = gui.Rect{100, 100, 400, 400}, flags = {.window_movable, .window_scaleable, .window_border}, title = "my window") {
						/*
						gui.layout_row_dynamic(s_gui, 30, 1);
						gui.label(s_gui, "Hello, Nuklear!", .left);

						gui.layout_row_dynamic(s_gui, 30, 2);
						if gui.button_label(s_gui, "Button") {
							gui.label(s_gui, "Button pressed!", .left);
						}

						gui.checkbox_label(s_gui, "Enable feature", &checkbox_state);

						gui.layout_row_dynamic(s_gui, 30, 1);
						gui.slider_float(s_gui, 0.0, &slider_value, 1.0, 0.01);

						gui.layout_row_dynamic(s_gui, 30, 1);
						gui.edit_string(s_gui, .simple, text_buffer[:], text_buffer.len, nil);

						gui.layout_row_dynamic(s_gui, 30, 1);
						combo_items := []cstring{"Option 1", "Option 2", "Option 3"};
						gui.combo(s_gui, combo_items, combo_items.len, &combo_index, 30, Vec2{200, 200});

						gui.layout_row_dynamic(s_gui, 30, 1);
						gui.label(s_gui, "Pick a color:", .left);
						gui.color_picker(s_gui, &color, .rgba);

						gui.layout_row_dynamic(s_gui, 30, 1);
						if gui.tree_push(s_gui, .node, "Tree", .collapsed) {
							gui.label(s_gui, "Inside tree node", .left);
							gui.tree_pop(s_gui);
						}

						*/
						gui.window_end(s_gui);
					}
					
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