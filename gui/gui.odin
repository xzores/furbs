package furbs_gui;

import "core:strings"
import "core:math"
import "core:unicode/utf8/utf8string"
import "core:math/linalg"
import "core:log"
import "core:fmt"

import "../utils"
import "../laycal"
import "../render"
import "../layren"
import layman "../layman_new"

State :: struct {
	pipeline : render.Pipeline,
	man : layman.Layout_mananger,
	ren : layren.Layout_render,

	window : ^render.Window,

	current_cursor : Cursor_type,
	next_cursor : Cursor_type,
	cursors : [Cursor_type]render.Cursor_handle,

	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,
	mouse_state : Key_state,

	styles : map[string][dynamic]Any,

	to_renders : [dynamic]To_render,

	self_free : bool,
}

Any :: struct {
	ptr : rawptr,
	type : typeid,
}


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
	layren.init(&gui.ren)
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

	default_button_style := Button_style {
		false, 

		Win_min{0.001}, //from sub-elements to this
		[2]Alignment{.center, .center}, //where should we align the children to
		.equal,
		
		//How does this size behave
		[2]Size{Win_min{0.09}, Win_min{0.03}},
		[2]Min_size{fit, fit},
		[2]Max_size{max(i32), max(i32)},
		1, //this is int to not have floating point problems.
		
		nil,
		
		[4]f32{0.3,0.3,0.3,1},
		[4]f32{0.5,0.5,0.5,1},
		2,
		nil,
		{5,5,5,5},
		
		{},
		false,
		false,
		15,
		render.get_default_fonts().normal,
	}
	
	push_button_style(gui, default_button_style);

	return gui;
}

destroy :: proc (gui : ^State) {
	
	pop_button_style(gui);

	layren.destroy(&gui.ren);
	layman.destroy(&gui.man);
	delete(gui.styles)
	delete(gui.to_renders)
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
	if render.is_button_down(.left) {
		gui.mouse_state = .down
	}
	if render.is_button_pressed(.left) {
		gui.mouse_state = .pressed
	}
	if render.is_button_released(.left) {
		gui.mouse_state = .released
	}

	gui.next_cursor = .normal;

	clear(&gui.to_renders)

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

		md := render.mouse_delta();
		ms := render.scroll_delta();

		commands := layman.end(&gui.man);
		for cmd in commands {
			
			switch v in cmd {
				case layman.Cmd_scissor: {
					render.set_scissor_test(auto_cast v.area.x, auto_cast v.area.y, auto_cast v.area.z, auto_cast v.area.w);
				}
				case layman.Cmd_scissor_disable: {
					render.disable_scissor_test()
				}
				case layman.Cmd_rect: {
					thing := gui.to_renders[v.element_kind];
					
					switch t in thing {
						case To_render_rect: {
							to_render : layren.Render_rect = {
								v.rect,
								render.texture2D_get_white(),
								layren.Rect_options{
									t.color,
									t.fill,
									t.border, //set this if it is border (width is pixels) default is fill.
									t.shadow,
									t.rounding // TL, TR, BR, BL
								},
								0,
							}

							layren.render(&gui.ren, []layren.To_render{to_render});
						}
						case To_render_text: {
							render.pipeline_begin(gui.pipeline, render.camera_get_pixel_space(target));
							
							descender := render.text_get_descender(auto_cast t.font, t.text_size)
							render.text_draw(t.text, v.rect.xy + {0, -descender}, v.rect.w, false, false)

							render.pipeline_end();
						}
					}
				}
				case layman.Cmd_text: {
					render.pipeline_begin(gui.pipeline, render.camera_get_pixel_space(target));
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
					render.pipeline_end();
				}
			}
		}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////

set_mouse_cursor :: proc (gui : ^State, cursor : Cursor_type) {
	gui.next_cursor = cursor
}

//returns if this is hovered assuming it did not move since last frame
is_hover :: proc (gui : ^State, uid : layman.Unique_id) -> bool {
	rect : [4]i32 = layman.get_rect(&gui.man, uid);
	return utils.collision_point_rect(gui.mouse_pos, linalg.array_cast(rect, f32));
}

push_style :: proc (gui : ^State, elem_type : string, val : ^$T) {
	if !(elem_type in gui.styles) {
		gui.styles[strings.clone(elem_type)] = make([dynamic]Any);
	}

	append(&gui.styles[elem_type], Any{val, T});
}

pop_style :: proc (gui : ^State, elem_type : string, loc := #caller_location) -> (rawptr, typeid) {
	if !(elem_type in gui.styles) {
		panic("Not a valid style", loc);
	}

	a := pop(&gui.styles[elem_type]);
	
	if len(gui.styles[elem_type]) == 0 {
		kp, vp, ji, a_err := map_entry(&gui.styles, elem_type)
		assert(a_err == nil)
		assert(ji == false)
		delete(kp^)
		delete(gui.styles[elem_type]);
		delete_key(&gui.styles, elem_type);
	}
	
	return a.ptr, a.type; 
}

get_style :: proc (gui : ^State, elem_type : string, $T : typeid, loc := #caller_location) -> T {
	if !(elem_type in gui.styles) {
		panic("No such style", loc);
	}

	stack := gui.styles[elem_type];
	last := stack[len(stack) - 1];

	fmt.assertf(last.type == T, "The style is not of the correct type, got '%v', expected '%v'", last.type, type_info_of(T), loc = loc);

	return (cast(^T)last.ptr)^;
}

To_render_text :: struct {
	//color : Color_or_gradient, //TODO
	text : string,
	font : int,
	//border : f32 // outgoing border around text //TODO
	//shadow : Maybe(Shadow), //Drop shadow //TODO
	text_size : f32,
}

To_render_rect :: struct {
	color : Color_or_gradient,
	fill : bool,
	border : f32, //set this if it is border (width is pixels) default is fill.
	shadow : Maybe(Shadow),
	rounding : [4]f32, // TL, TR, BR, BL
}

To_render :: union {
	To_render_text,
	To_render_rect,
}

render_index :: proc (gui : ^State, to_render : To_render) -> int {
	append(&gui.to_renders, to_render);
	return len(gui.to_renders) - 1;
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

/////////////////////////////////////////////////////////////////////////////////////////////////////////

Win_min :: struct {
	rel_size : f32,
}

Win_max :: struct {
	rel_size : f32,
}

Color_or_gradient :: layren.Color_or_gradient;
Shadow :: layren.Shadow;

Alignment :: laycal.Alignment
Layout_dir :: laycal.Layout_dir

Absolute_postion :: laycal.Absolute_postion
Overflow_dir :: laycal.Overflow_dir

Fixed :: layman.Fixed
Parent_ratio :: layman.Parent_ratio
Fit :: layman.Fit
Grow :: layman.Grow
Grow_fit :: layman.Grow_fit

grow :: laycal.grow
fit :: laycal.fit
grow_fit :: laycal.grow_fit

Unique_id :: layman.Unique_id

parent_ratio :: proc (rel_size : f32) -> Parent_ratio {
	return Parent_ratio{rel_size}
}

//give a number between 0 and 1 ranging from 0% min dimension of the window to 100% of min dimension of the window
win_min :: proc(rel_size : f32) -> Win_min {
	return Win_min{rel_size}
}

//this is relative to the max axis of the window
win_max :: proc(rel_size : f32) -> Win_max {
	return Win_max{rel_size}
}

Size :: union {
	Fixed,			//Have a fixed size in pixels
	Parent_ratio,	
	Fit, 			//Be just be enough to fit all your sub-content
	Grow,			//Grow to fill the container
	Grow_fit,
	Win_min,		//In relation to the min screen dimension, between 0 and 1
	Win_max,
}

Min_size :: union {
	Fixed,			//Have a fixed size in pixels
	Parent_ratio,	
	Fit, 			//Be just be enough to fit all your sub-content
	Win_min,		//In relation to the min screen dimension, between 0 and 1
	Win_max,
}

Max_size :: union {
	Fixed,			//Have a fixed size in pixels
	Parent_ratio,	
	Win_min,		//In relation to the min window dimension, between 0 and 1
	Win_max,
}

Text :: struct {
	text : string,			//if it is text
	size : f32,
	font : int,
}

Sizeing :: union {
	[2]Size,
	Text,
}

Padding :: Max_size;
Font :: render.Font;

size_gui_to_man :: proc (size : Size, window_dim : [2]f32) -> laycal.Size {
	
	switch s in size {
		case Fixed:
			return s
		case Parent_ratio:
			return s;
		case Fit:
			return s;
		case Grow:
			return s;
		case Grow_fit:
			return s;
		case Win_min:
			unit_dim := math.min(window_dim.x, window_dim.y)
			fixed_size := s.rel_size * unit_dim
			return cast(Fixed)fixed_size
		case Win_max:
			unit_dim := math.max(window_dim.x, window_dim.y)
			fixed_size := s.rel_size * unit_dim
			return cast(Fixed)fixed_size
	}
	
	unreachable()
}

size_gui_to_man_2 :: proc (size : [2]Size, window_dim : [2]f32) -> [2]laycal.Size {
	return [2]laycal.Size{size_gui_to_man(size[0], window_dim), size_gui_to_man(size[1], window_dim)};
}

min_size_gui_to_man :: proc (size : Min_size, window_dim : [2]f32) -> laycal.Min_size {
	
	switch s in size {
		case Fixed:
			return s
		case Parent_ratio:
			return s;
		case Fit:
			return s;
		case Win_min:
			unit_dim := math.min(window_dim.x, window_dim.y)
			fixed_size := s.rel_size * unit_dim
			return cast(Fixed)fixed_size
		case Win_max:
			unit_dim := math.max(window_dim.x, window_dim.y)
			fixed_size := s.rel_size * unit_dim
			return cast(Fixed)fixed_size
	}
	
	unreachable()
}

min_size_gui_to_man_2 :: proc (size : [2]Min_size, window_dim : [2]f32) -> [2]laycal.Min_size {
	return [2]laycal.Min_size{min_size_gui_to_man(size[0], window_dim), min_size_gui_to_man(size[1], window_dim)};
}

max_size_gui_to_man :: proc (size : Max_size, window_dim : [2]f32) -> laycal.Max_size {
	
	switch s in size {
		case Fixed:
			return s
		case Parent_ratio:
			return s;
		case Win_min:
			unit_dim := math.min(window_dim.x, window_dim.y)
			fixed_size := s.rel_size * unit_dim
			return cast(Fixed)fixed_size
		case Win_max:
			unit_dim := math.max(window_dim.x, window_dim.y)
			fixed_size := s.rel_size * unit_dim
			return cast(Fixed)fixed_size
	}
	
	unreachable()
}

max_size_gui_to_man_2 :: proc (size : [2]Max_size, window_dim : [2]f32) -> [2]laycal.Max_size {
	return [2]laycal.Max_size{max_size_gui_to_man(size[0], window_dim), max_size_gui_to_man(size[1], window_dim)};
}


convert_size :: proc {size_gui_to_man, size_gui_to_man_2, min_size_gui_to_man, min_size_gui_to_man_2, max_size_gui_to_man, max_size_gui_to_man_2}

window_dim :: proc (s : ^State) -> [2]f32 {
	return [2]f32{auto_cast s.window.width, auto_cast s.window.height};
}
