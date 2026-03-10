package furbs_gui;

import "core:math/linalg"
import "core:log"
import "../utils"
import "../render"
import "../layren"
import layman "../layman_new"

State :: struct {
	pipeline : render.Pipeline,
	man : layman.Layout_mananger,

	window : ^render.Window,

	current_cursor : Cursor_type,
	next_cursor : Cursor_type,
	cursors : [Cursor_type]render.Cursor_handle,

	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,
	mouse_state : Key_state,

	self_free : bool,
}

Unique_id :: layman.Unique_id

init :: proc (gui : ^State = nil) -> ^State {
	gui := gui;
	
	if gui == nil {
		gui = new(State);
		gui.self_free = true
	}
	
	meas_width : layman.Meassure_width_callback : proc (text : string, size : f32, font : int) -> i32 {
		bounds := render.text_get_bounds(text, size, cast(render.Font)font, false);
		return auto_cast bounds.z;
	}

	meas_height : layman.Meassure_height_callback : proc (size : f32, font : int) -> i32 {
		return auto_cast render.text_get_max_height(cast(render.Font)font, size, false)
	}

	meas_gap : layman.Meassure_gap_callback : proc (size : f32, font : int) -> i32 {
		return auto_cast render.text_get_line_gap(cast(render.Font)font, size, false)
	}

	layman.init(meas_width, meas_height, meas_gap, &gui.man);
	gui.pipeline = render.pipeline_make(render.get_default_shader(), .blend, false, false)
	
	gui.cursors = {
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
	};

	return gui;
}

destroy :: proc (gui : ^State) {
	
	layman.destroy(&gui.man);
	if gui.self_free {
		free(gui)
	}
}

begin :: proc (gui : ^State, window : ^render.Window) {
	gui.window = window;
	
	gui.mouse_pos = render.mouse_pos(window)
	gui.mouse_delta = render.mouse_delta()
	gui.scroll_delta = render.scroll_delta()
	
	gui.mouse_state = .up
	if render.is_button_released(.left) {
		gui.mouse_state = .down
	}
	if render.is_button_pressed(.left) {
		gui.mouse_state = .pressed
	}
	if render.is_button_released(.left) {
		gui.mouse_state = .released
	}

	layman.begin(&gui.man, [2]i32{window.width, window.height})
}

//target is where we render to,
//window is required for setting the mouse cursor
end :: proc (gui : ^State, loc := #caller_location) {
	target := render.get_current_render_target();
	assert(target != nil, "you must bind a render target first")

	if gui.next_cursor != gui.current_cursor {
		render.window_set_cursor_icon(gui.window, gui.cursors[gui.next_cursor])
		gui.current_cursor = gui.next_cursor
	}

	render.pipeline_begin(gui.pipeline, render.camera_get_pixel_space(target))
		md := render.mouse_delta();
		ms := render.scroll_delta();
	
		commands := layman.end(&gui.man);
		for cmd in commands {
			render.set_texture(.texture_diffuse, render.texture2D_get_white())
			//fmt.printf("cmd : %v\n", cmd)
			switch v in cmd {
				case layman.Cmd_scissor: {
					render.set_scissor_test(auto_cast v.area.x, auto_cast v.area.y, auto_cast v.area.z, auto_cast v.area.w);
				}
				case layman.Cmd_scissor_disable: {
					render.disable_scissor_test()
				}
				case layman.Cmd_rect: {
					//color := [v.element_kind]
					render.draw_quad_rect(v.rect, color = {1,1,1,0.5})
				}
				case layman.Cmd_text: {
					//descender := render.text_get_descender(render.get_default_fonts().normal, v.size)
					descender := render.text_get_descender(auto_cast v.font, v.text_size)
					
					for l in v.lines {
						bounds := render.text_get_bounds(l.line, v.text_size, auto_cast v.font)
						pos := v.rect.xy
						render.text_draw(l.line, pos + {0, -descender + (auto_cast l.ver_offset)}, v.text_size, false, false)
					}
					if ODIN_DEBUG == true {
						render.set_texture(.texture_diffuse, render.texture2D_get_white())
						render.draw_quad_rect(v.rect, color = {0.1,0.1,0.9,0.2})
					}
				}
			}
		}

	render.pipeline_end();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////

set_mouse_cursor :: proc (gui : ^State, cursor : Cursor_type) {
	
}

//returns if this is hovered assuming it did not move since last frame
is_hover :: proc (gui : ^State, uid : layman.Unique_id) -> bool {
	rect : [4]i32 = layman.get_rect(&gui.man, uid);
	return utils.collision_point_rect(gui.mouse_pos, linalg.array_cast(rect, f32));
}

/*
Overflow :: enum {
	auto_scroll, //only show the scroll bar if needed
	visible,	//show everything even if it overflows
	hidden,		//hide overflow, never show scrollbars
	scroll,		//hide overflow, always show scrollbars
}
*/

Key_state :: enum {
	up,
	pressed,
	down,
	released,
}

Cursor_type :: enum i32 {
	normal,
	
	text_edit,
	
	crosshair,
	
	//These are the same on some OS
	draging, //when draging like a window
	clickable,
	
	scale_horizontal,
	scale_verical,
	scale_NWSE,
	scale_NESW,
	scale_all,
	
	not_allowed,
}


Style_kind :: enum {
	
	debug_rect,
	
	button_background,
	button_border,
	
	checkbox_background,
	checkbox_border,
	checkbox_foreground,
	
	window_background,
	window_border,
	window_top_bar,
	window_collapse_button_down,
	window_collapse_button_up,
	window_collapse_button_left,
	window_collapse_button_right,
	
	scrollbar_background,
	scrollbar_front,
	
	menu_background,
	menu_border,
	menu_item_background,
	menu_item_background_border,
	menu_item_front,
	menu_item_front_border,

	split_panel_splitter,
}
