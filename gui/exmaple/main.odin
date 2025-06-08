package gui_exmaple;

import "core:mem"
import "core:math"
import "core:time"

import gui ".."
import "../../render"
import "core:fmt"
import "../../utils"

entry :: proc () {
	
	window_desc : render.Window_desc = {
		width = 1400,
		height = 1000,
		title = "my gui window",
		resize_behavior = .allow_resize,
		antialiasing = .msaa16,
	}
	
	window := render.init({}, required_gl_verion = .opengl_4_3, window_desc = window_desc, pref_warn = true);
	defer render.destroy();
	
	////////////////////
	
	vsync : bool = true;
	fullscreen : render.Fullscreen_mode = .windowed;
	render.window_set_vsync(vsync);
	
	////////////////////
	
	s := gui.init(window, font_size = 0.04);
	defer gui.destroy(s);
	
	checkbox_state : bool = true;
	slider_value : f32 = 0.5;
	text_buffer : cstring = "Edit me!";
	combo_index : int = 0;
	color := [4]f32{255, 0, 128, 255};
	
	for !render.window_should_close(window) {
		
		render.begin_frame();
			
			render.target_begin(window, [4]f32{0.24, 0.34, 0.12, 1});
				
				gui.begin(s);
					
					//inside render loop, begin with two versions of panel_a, they share a game state, so their intacting with one will also interact with the ohter (i think that might be how i want it.)
					gui.begin_split_panel(s, {0.03, 0.77, 0.2}, .vertical, {});
					
					gui.next_split_panel(s);
						
						popout_dir : gui.Menu_popout_dir;
						popout_dir = cast(gui.Menu_popout_dir)(int(render.elapsed_time()) %% len(gui.Menu_popout_dir));
						gui.menu(s, "hover me", {"option a", "option b", "option c"}, popout_dir, false, gui.Dest{.left, .top, 0.1, 0.1});
											
						if gui.begin_window(s, {0.5, 0.5}, {.scaleable, .ver_scrollbar, .hor_scrollbar, .movable, .collapsable}, gui.Dest{.mid, .mid, 0, 0}, "Hello world", .top) {
							gui.checkbox(s, &checkbox_state, dest = gui.Dest{.left, .bottom, 0.01, 0.01}, label = "Enable feature y");
							gui.checkbox(s, &checkbox_state, gui.Dest{.mid, .mid, 0, 0.4}, label = "Something one");
							
							if gui.begin_window(s, {0.2, 0.2}, {.scaleable, .ver_scrollbar, .hor_scrollbar, .movable, .collapsable, .center_title, .append_horizontally}, gui.Dest{.left, .mid, 0, 0}, "1234", .top) {
								gui.checkbox(s, &checkbox_state, label = "Enable feature x");
								gui.spacer(s, 0.02);
								gui.checkbox(s, &checkbox_state, label = "Something two");
							}
							gui.end_window(s);
							
							if gui.button(s, label = "MyButton") {
								fmt.printf("Button clicked\n");
							}
							
							if gui.begin_window(s, {0.2, 0.2}, {.scaleable, .movable, .collapsable}, gui.Dest{.right, .top, 0, 0.1}, "", .top) {
								//
							}
							gui.end_window(s);
						}
						gui.end_window(s);
						
						if gui.begin_window(s, {0.4, 0.4}, {.scaleable, .ver_scrollbar, .hor_scrollbar, .movable, .collapsable}, gui.Dest{.left, .top, 0.05, 0.3}, "asfga", .left) {
							gui.checkbox(s, &checkbox_state, label = "very very very very very very very very very long");
							for i in 0..<100 {
								gui.checkbox(s, &checkbox_state, label = fmt.tprintf("Text thing %v", i));
								gui.button(s, label = fmt.tprintf("Text thing %v", i));
							}
						}
						gui.end_window(s);
						
						if checkbox_state {
							gui.begin_window(s, {0.2, 0.2}, {}, gui.Dest{.mid, .bottom, math.sin(render.elapsed_time() / 2) / 4, 0}, "", .top);
								gui.checkbox(s, &checkbox_state, label = "Something 2");
								res := gui.menu(s, "Something 3", {"option a", "option b", "option c"}, .right_center);
								if res != "" {
									fmt.printf("option : %v\n", res);
								}
							gui.end_window(s);
						}
						
						if gui.begin_window(s, {0.3, 0.3}, {.no_top_bar, .hor_scrollbar, .ver_scrollbar, .append_horizontally, .scaleable}, gui.Dest{.right, .mid, 0.04, 0.01}, "") {
							
							for i in 0..<10 {
								res :=  gui.menu(s, fmt.tprintf("Something %v", i), {"option a", "option b", 
									gui.Sub_menu{
										"Sub menu",
										{
											"sub option 1",
											"sub option 2",
											gui.Sub_menu{
												"Sub sub menu",
												{
													"sub sub option 1",
													"sub sub option 2",
												},
												.right_down,
												false,
											},
										},
										.right_down,
										false,
									},
									"option c",
								}, .down, false);
								if res != "" {
									fmt.printf("option : %v\n", res);
								}
							}
							gui.end_window(s);
						}
						
					gui.next_split_panel(s);
						
						//inside render loop, begin with two versions of panel_a, they share a game state, so their intacting with one will also interact with the ohter (i think that might be how i want it.)
						gui.begin_split_panel(s, {2, 1}, .horizontal, {.allow_resize});
							gui.checkbox(s, &checkbox_state, label = "Inside split panel");
						gui.next_split_panel(s);
							gui.checkbox(s, &checkbox_state, label = "Inside split panel2");
						
						gui.end_split_panel(s);
						
					gui.end_split_panel(s);
					
				gui.end(s);
				
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