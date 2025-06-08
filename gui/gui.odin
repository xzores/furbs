package furbs_im_gui;

import "base:runtime"

import "core:mem"
import "core:c"
import "core:log"
import "core:math"
import "core:math/linalg"
import _c "core:c"
import "core:fmt"
import "core:strings"

import "../render"
import lm "../layman"

State :: struct {
	
	cam : render.Camera,
	
	gui_framebuffer : render.Frame_buffer,
	
	window : ^render.Window,
	shader : ^render.Shader,
	pipeline : render.Pipeline,
	
	font : render.Font,
	
	odin_allocator : mem.Allocator,
	logger : log.Logger,
	
	cursors : [lm.Cursor_type]render.Cursor_handle,
	
	using ctx : ^lm.State,
}

init :: proc (window : ^render.Window, default_font := render.get_default_fonts().normal, font_size : f32 = 0.02) -> ^State {
	
	s := new(State);
	
	lm_font_width : lm.Text_width_f : proc (user_data : rawptr, size : f32, str: string) -> f32 {
		user_data : ^State = cast(^State)user_data;
		
		context = runtime.default_context();
		context.allocator = user_data.odin_allocator;
		context.logger = user_data.logger;
		
		return render.text_get_bounds(str, size, user_data.font).z;
	}
	
	lm_font_height : lm.Text_height_f : proc (user_data : rawptr, size : f32) -> (ascender : f32, decender : f32){
		user_data : ^State = cast(^State)user_data;
		
		context = runtime.default_context();
		context.allocator = user_data.odin_allocator;
		context.logger = user_data.logger;
		
		ascender = render.text_get_ascender(user_data.font, size);
		decender = render.text_get_descender(user_data.font, size);
		
		return ascender, decender;
	}
	
	gui_shader, e := render.shader_load_from_src("gui_shader.glsl", #load("gui_shader.glsl"), nil);
	assert(e == nil);
	//gui_shader := render.get_default_shader();
	
	s^ = State {
		render.camera_get_pixel_space_flipped(window),
		//render.camera_get_pixel_space(window),
		render.frame_buffer_make_textures({render.Fbo_color_tex_desc{.clamp_to_edge, .nearest, .RGBA8}}, 1, 1, .depth_component16),
		window,
		gui_shader,
		render.pipeline_make(gui_shader, .blend, false),
		default_font,
		context.allocator,
		context.logger,
		{
			.normal 			= render.get_os_cursor(.arrow),
			.text_edit 			= render.get_os_cursor(.Ibeam),
			.crosshair 			= render.get_os_cursor(.crosshair),
			.draging 			= render.get_os_cursor(.resize_all),
			.clickable 			= render.get_os_cursor(.pointing_hand),
			.scale_horizontal 	= render.get_os_cursor(.resize_east_west),
			.scale_verical 		= render.get_os_cursor(.resize_north_south),
			.scale_NWSE 		= render.get_os_cursor(.resize_NWSE),
			.scale_NESW 		= render.get_os_cursor(.resize_NESW),
			.scale_all 			= render.get_os_cursor(.resize_all),
			.not_allowed 		= render.get_os_cursor(.not_allowed),
		},
		lm.init(s, lm_font_width, lm_font_height),
	};
	
	lm.push_style(s, lm.Style{
		font = auto_cast default_font,
		in_padding = 0.005,
		out_padding = 0.01,
		button = lm.Button_style{
			0.003, // border_thickness
			0.003, // text_padding
			0.03, // text_size
			false, // text_shrink_to_fit
			.mid, // text_hor
			.mid, // text_ver
			{0.12, 0.04}, // size
		},
		checkbox = lm.Checkbox_style{
			border_thickness = 0.003,
			text_padding = 0.003,
			text_size = 0.03,
			size = {0.03, 0.03},
		},
		window = lm.Window_style{	
			0.005,			//	border_thickness : f32,
			0.03,			//	top_bar_size : f32,
			0.01,			//	title_padding : f32,
			0.025,			//	title_size : f32,
			{0.03, 0.03},	//	size : [2]f32,
		},
		scroll = lm.Scroll_style{
			0.01,	//bar_thickness
			0.015,	//bar_thickness
			{0.01, 0.01},	//padding
			0.035,				//length_padding
		},
		menu = lm.Menu_style{
			0.002, // border_thickness
			0.003, // text_padding
			0.02, // text_size
			false, // text_shrink_to_fit
			.left, // text_hor
			.mid, // text_ver
			0.025, // size
		},
		split_panel = lm.Split_panel_style {
			0.002, // border_thickness
			0.005, //split thickness
		}
	});
	
	return s;
}

destroy :: proc(s : ^State) {
	
	render.frame_buffer_destroy(s.gui_framebuffer);
	render.pipeline_destroy(s.pipeline);
	render.shader_destroy(s.shader);
	
	for cursor in s.cursors {
		render.destroy_cursor(cursor);
	}
	
	lm.destroy(s.ctx);
	free(s);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

begin :: proc(s : ^State, user_id := 0, dont_touch := #caller_location) {
	
	unit_size := cast(f32)math.min(s.window.width, s.window.height);
	
	mp := render.mouse_pos(s.window) / unit_size;
	md := render.mouse_delta() / unit_size;
	lm.set_mouse_pos(s, mp.x, mp.y, md.x, md.y);
	
	sd := render.scroll_delta() * 0.03;
	lm.set_scroll(s, sd.x, sd.y, false);
	
	if render.is_button_pressed(.left) {
		lm.mouse_event(s, true);
	}
	else if render.is_button_released(.left) {
		lm.mouse_event(s, false);
	}
	
	lm.begin(s, cast(f32)s.window.width / unit_size, cast(f32)s.window.height / unit_size, user_id, dont_touch);
}

end :: proc(s : ^State) {
	
	unit_size := cast(f32)math.min(s.window.width, s.window.height);
	
	render.pipeline_begin(s.pipeline, render.camera_get_pixel_space(s.window));
	defer render.pipeline_end();
	
	cmds := lm.end(s);
	
	//render.set_uniform(s.pipeline.shader, .);
	
	/*
		roundness = 0.05,
		front_color = {0.6, 0.25, 0.25, 1},
		border_color = {0.25, 0.25, 0.25, 1},
		bg_color = {0.15, 0.15, 0.15, 1},
		text_color = {0.9, 0.9, 0.9, 1},
	*/
	
	for cmd in cmds {
		switch c in cmd {			
			case lm.Cmd_rect: {
				
				render.set_texture(.texture_diffuse, render.texture2D_get_white());
				
				switch c.rect_type {
					
					case .menu_item_front:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.25, 0.15, 0.25, 1});
							case .hot:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.35, 0.25, 0.35, 1});
							case .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.55, 0.45, 0.55, 1});
						}
					
					case .split_panel_splitter:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						render.draw_quad_rect(c.rect * unit_size, 0, {0.55, 0.55, 0.55, 1});
						
					case .menu_background:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.25, 0.15, 0.15, 1});
							case .hot:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.35, 0.25, 0.25, 1});
							case .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.55, 0.45, 0.45, 1});
						}
					
					case .menu_item_background:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						render.draw_quad_rect(c.rect * unit_size, 0, {0.35, 0.35, 0.35, 1});
					
					case .debug_rect:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						render.draw_quad_rect(c.rect * unit_size, 0, {0.75, 0.15, 0.15, 0.3});
						
					case .button_background:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.15, 0.15, 0.15, 1});
							case .hot:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.25, 0.25, 0.25, 1});
							case .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.45, 0.45, 0.45, 1});
						}
					
					case .checkbox_background:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.15, 0.15, 0.15, 1});
							case .hot:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.25, 0.25, 0.25, 1});
							case .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.45, 0.45, 0.45, 1});
						}
						
					case .window_background:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						render.draw_quad_rect(c.rect * unit_size, 0, {0.15, 0.15, 0.15, 1});
				
					case .window_top_bar:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.6, 0.25, 0.25, 1});
							case .hot:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.7, 0.4, 0.4, 1});
							case .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.9, 0.4, 0.4, 1});
						}
					
					case .scrollbar_background:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.7, 0.7, 0.7, 0.2});
							case .hot, .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.8, 0.8, 0.8, 0.4});
						}
						
					case .scrollbar_front:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						switch c.state {
							case .cold:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.5, 0.5, 0.5, 1});
							case .hot:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.9, 0.9, 0.9, 1});
							case .active:
								render.draw_quad_rect(c.rect * unit_size, 0, {0.9, 0.9, 0.9, 1});
						}
					
					case .checkbox_border, .window_border, .button_border, .menu_border, .menu_item_background_border, .menu_item_front_border:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, false);
						render.set_uniform(s.shader, render.Uniform_location.gui_line_thickness, cast(f32)c.border_thickness * unit_size);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						render.draw_quad_rect(c.rect * unit_size, 0, {0.25, 0.25, 0.25, 1});
						
					case .checkbox_foreground:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)0); //TODO roundness
						render.draw_quad_rect(c.rect * unit_size, 0, {0.6, 0.25, 0.25, 1});
						
					case .window_collapse_button_up, .window_collapse_button_down, .window_collapse_button_left, .window_collapse_button_right:
						render.set_uniform(s.shader, render.Uniform_location.gui_fill, true);
						render.set_uniform(s.shader, render.Uniform_location.gui_line_thickness, cast(f32)c.border_thickness * unit_size);
						//render.set_uniform(s.shader, render.Uniform_location.gui_roundness, cast(f32)c.roundness * unit_size);
						
						a, b, d : [2]f32;
						
						#partial switch c.rect_type {
							case .window_collapse_button_up: 
								a = c.rect.xy;
								b = c.rect.xy + {c.rect.z, 0};
								d = c.rect.xy + {c.rect.z / 2, c.rect.w};
							
							case .window_collapse_button_down:			
								a = c.rect.xy + {0, c.rect.w};
								b = c.rect.xy + {c.rect.z, c.rect.w};
								d = c.rect.xy + {c.rect.z / 2, 0};
							
							case .window_collapse_button_right:			
								a = c.rect.xy;
								b = c.rect.xy + {0, c.rect.w};
								d = c.rect.xy + {c.rect.z, c.rect.w / 2};
								
							case .window_collapse_button_left:			
								a = c.rect.xy + {c.rect.z, 0};
								b = c.rect.xy + {c.rect.z, c.rect.w};
								d = c.rect.xy + {0, c.rect.w / 2};
						}
						
						switch c.state {
							case .cold:
								render.draw_triangle(a * unit_size, b * unit_size, d * unit_size, {0.6, 0.6, 0.6, 1});
							case .hot:
								render.draw_triangle(a * unit_size, b * unit_size, d * unit_size, {0.7, 0.7, 0.7, 1});
							case .active:
								render.draw_triangle(a * unit_size, b * unit_size, d * unit_size, {0.9, 0.9, 0.9, 1});
						}
				}
			}
			case lm.Cmd_scissor: {
				if c.enable {
					r := c.area * unit_size;
					render.set_scissor_test(r.x, r.y, r.z, r.w);
				}
				else {
					render.disable_scissor_test();
				}
			}
			case lm.Cmd_text: {
				render.text_draw(c.val, c.position * unit_size, c.size * unit_size, false, false, {1,1,1,1}, rotation = c.rotation);
			}
			case lm.Cmd_swap_cursor: {
				render.window_set_cursor_icon(s.window, s.cursors[c.type]);
			}
		}
	}
	
	render.disable_scissor_test();
	
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Ver_placement :: lm.Ver_placement;
Hor_placement :: lm.Hor_placement;
Dest :: lm.Dest;
Top_bar_location :: lm.Top_bar_location;
Sub_menu :: lm.Sub_menu;
Menu_popout_dir :: lm.Menu_popout_dir;

spacer :: lm.spacer;

button :: lm.button;
checkbox :: lm.checkbox;
begin_window :: lm.begin_window;
end_window :: lm.end_window;
menu :: lm.menu;
begin_split_panel :: lm.begin_split_panel;
next_split_panel :: lm.next_split_panel;
end_split_panel :: lm.end_split_panel;

/*
checkbox :: proc (s : ^State, dest : Dest, value : ^bool, label := "") {
	lm.checkbox(s, dest, value, label);
}
*/

Menu_bar_enum :: enum {
	
}

Menu_bar_flags :: bit_set[Menu_bar_enum];

menu_bar :: proc (s : ^State, menus : []Sub_menu, popout_hor : Hor_placement, popout_ver : Ver_placement, reverse_sort : bool = false, dest : Maybe(Dest) = nil, user_id := 0, dont_touch := #caller_location) {
	
}



