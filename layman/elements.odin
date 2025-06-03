package furbs_layman;

import "base:runtime"

import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:slice"
import "core:container/queue"

import "core:fmt"

import "../utils"
import "../render"

//////////////////////////////////////// Common ////////////////////////////////////////

Ver_placement :: enum {
	bottom, mid, top
}

Hor_placement :: enum {
	left, mid, right,
}

Dest :: struct {
	hor : Hor_placement,
	ver : Ver_placement,
	offset_x : f32,
	offset_y : f32,
}

//////////////////////////////////////// Button ////////////////////////////////////////

button :: proc (s : ^State, dest : Maybe(Dest) = nil, label := "", user_id := 0, dont_touch := #caller_location) -> (value : bool) {	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	panel := get_current_panel(s);
	total_size : [2]f32;
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, panel.current_offset + gstyle.out_padding, gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, gstyle.out_padding, panel.current_offset + gstyle.out_padding};
		}
	}
	
	style := get_button_style(s);
	size := style.size;
	total_size += size;
	
	placement := place_in_parent(s, panel.position, panel.size, _dest, size);
	
	if utils.collision_point_rect(s.mouse_pos, placement) {
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
		if current_active(s) == uid && s.mouse_state == .down {
			try_set_active(s, uid);
		}
		if current_active(s) == uid && s.mouse_state == .released {
			try_set_active(s, uid);
			value = true;
		}
	}
	
	gui_state : Display_state = .cold;
	
	if current_hot(s) == uid {
		gui_state = .hot;
		set_mouse_cursor(s, .clickable);
	}
	if current_active(s) == uid {
		gui_state = .active;
		set_mouse_cursor(s, .clickable);
	}
	
	append_command(s, Cmd_rect{placement, .button_background, -1, gui_state});
	append_command(s, Cmd_rect{placement, .button_border, style.line_thickness, gui_state});
	
	if label != "" {
		padding := style.text_padding
		
		asc, dec := s.font_height(s.user_data, style.text_size);
		text_width := s.font_width(s.user_data, style.text_size, label);
		
		text_size :=  [2]f32{text_width, asc - dec};
		
		text_placement := place_in_parent(s, placement.xy + style.text_padding, placement.zw - 2 * style.text_padding, Dest{style.text_hor, style.text_ver, 0, 0}, text_size);
		text_placement.y -= dec
		append_command(s, Cmd_text{text_placement.xy, strings.clone(label, context.temp_allocator), style.text_size, 0, .checkbox_text});
	}
	
	if d, ok := dest.?; !ok {
		increase_offset(s, total_size);
	}
	
	return;
}

//////////////////////////////////////// Checkbox ////////////////////////////////////////

checkbox :: proc (s : ^State, value : ^bool, dest : Maybe(Dest) = nil, label := "", user_id := 0, dont_touch := #caller_location) -> bool {	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	panel := get_current_panel(s);
	total_size : [2]f32;
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, panel.current_offset + gstyle.out_padding, gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, gstyle.out_padding, panel.current_offset + gstyle.out_padding};
		}
	}
	
	style := get_checkbox_style(s);
	size := style.size;
	total_size += size;
	
	placement := place_in_parent(s, panel.position, panel.size, _dest, size);
	
	if utils.collision_point_rect(s.mouse_pos, placement) {
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
		if current_active(s) == uid && s.mouse_state == .down {
			try_set_active(s, uid);
		}
		if current_active(s) == uid && s.mouse_state == .released {
			value^ = !value^;
		}
	}
	
	checkbox_state : Display_state = .cold;
	
	if current_hot(s) == uid {
		checkbox_state = .hot;
		set_mouse_cursor(s, .clickable);
	}
	if current_active(s) == uid {
		checkbox_state = .active;
		set_mouse_cursor(s, .clickable);
	}
	
	append_command(s, Cmd_rect{placement, .checkbox_background, -1, checkbox_state}); //The background
	append_command(s, Cmd_rect{placement, .checkbox_border, style.line_thickness, checkbox_state}); //The background	
	
	if value^ {
		act_placement := place_in_parent(s, placement.xy, placement.zw, Dest{.mid, .mid, 0, 0}, size - style.line_thickness*6);
		append_command(s, Cmd_rect{act_placement, .checkbox_foreground, -1, checkbox_state}); //The background
	}
	
	if label != "" {
		text_size := style.text_size
		padding := style.text_padding
		
		text_placement := placement.xy;
		text_placement.x += + size.x + style.text_padding;
		asc, dec := s.font_height(s.user_data, style.text_size);
		text_placement.y += -dec;
		append_command(s, Cmd_text{text_placement, strings.clone(label, context.temp_allocator), style.text_size, 0, .checkbox_text});
		total_size += {s.font_width(s.user_data, text_size, label), 0};
	}
	
	if d, ok := dest.?; !ok {
		increase_offset(s, total_size);
	}	
	
	return value^;
}

//////////////////////////////////////// Input Field ////////////////////////////////////////

//TODO input field

//////////////////////////////////////// Window ////////////////////////////////////////

@private
Window_falgs_enum :: enum {
	
	//how it looks
	no_border,
	no_background,
	no_top_bar,
	center_title,
	allow_overflow, //dont scissor
	
	//How elements are added
	bottom_to_top,
	right_to_left,
	append_horizontally,
	
	//Ables
	movable,
	scaleable,
	collapsable,
	
	//Scrollbar
	scrollbar,
	scroll_auto_hide,
	
	//Dont allow use the interact with it or any sub elements.
	no_input,
	
	//Start as
	collapsed,
}

Window_falgs :: bit_set[Window_falgs_enum];

Top_bar_location :: enum {
	top,
	left,
	right,
	bottom,
}

begin_window :: proc (s : ^State, size : [2]f32, flags : Window_falgs, dest : Dest, title := "", center_title := false, top_bar_loc := Top_bar_location.top, user_id := 0, dont_touch := #caller_location) -> bool {
	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	push_node(s, uid);
	
	gstyle := get_style(s);
	style := get_window_style(s);
	
	min_size := [2]f32{1, 1} * (gstyle.out_padding + style.line_thickness) * 2 + style.title_size;
	
	top_bar_occupie : [2]f32;
	bar_cause_offset : [2]f32;
	switch top_bar_loc {
		case .top:
			top_bar_occupie = {0, style.top_bar_size};
			bar_cause_offset = {0,0};
		case .bottom:
			top_bar_occupie = {0, style.top_bar_size};
			bar_cause_offset = {0, style.top_bar_size};
		case .right:
			top_bar_occupie = {style.top_bar_size, 0};
			bar_cause_offset = {0, 0};
		case .left:
			top_bar_occupie = {style.top_bar_size, 0};
			bar_cause_offset = {style.top_bar_size,0};
	}
	
	if (.no_top_bar in flags) {
		top_bar_occupie = {};
	}
	
	parent := get_current_panel(s);
	w_state : Window_state;
	
	{
		_w := get_state(s, uid);
		
		if _w == nil {
			start_collapsed := false;
			
			if .collapsed in flags {
				start_collapsed = true;
			}
			
			first_placement := place_in_parent(s, parent.position, parent.size, dest, size);
			
			first_placement.xy += bar_cause_offset
			first_placement.zw -= top_bar_occupie
			
			w_state = {
				first_placement,
				nil, //relavtive to mouse position 
				start_collapsed,
			}
		}
		else if last_window, ok := _w.(Window_state); ok {
			w_state = last_window;
		}
		else  {
			panic("The was not a window last frame");
		}
	}
	
	hor_behavior : Hor_placement = .left;
	ver_behavior : Ver_placement = .top;
	append_hor : bool = false;
	
	if .bottom_to_top in flags {
		ver_behavior = .bottom;
	}
	if .right_to_left in flags {
		hor_behavior = .right;
	}
	if .append_horizontally in flags {
		append_hor = true;
	}
	
	placement := place_in_parent(s, parent.position, parent.size, {.left, .bottom, w_state.placement.x, w_state.placement.y}, w_state.placement.zw);;
	
	if utils.collision_point_rect(s.mouse_pos, placement) {
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
	}
	
	top_bar_placement : [4]f32;
	
	//top bar
	{		
		top_uid := Unique_id {
			dont_touch,
			call_cnt,
			1,
			user_id,
		}
		
		switch top_bar_loc {
			case .top:
				top_bar_placement.xy = placement.xy + {0, placement.w};
				top_bar_placement.zw = {placement.z, top_bar_occupie.y};
			case .bottom:
				top_bar_placement.xy = placement.xy - {0, top_bar_occupie.y};
				top_bar_placement.zw = {placement.z, top_bar_occupie.y};
			case .right:
				top_bar_placement.xy = placement.xy + {placement.z, 0};
				top_bar_placement.zw = {top_bar_occupie.x, placement.w};
			case .left:
				top_bar_placement.xy = placement.xy - {top_bar_occupie.x, 0};
				top_bar_placement.zw = {top_bar_occupie.x, placement.w};
		}
		
		if top_bar_occupie != {} {
			top_bar_state : Display_state = .cold;
			
			if current_hot(s) == top_uid {
				top_bar_state = .hot;
			}
			if current_active(s) == top_uid {
				top_bar_state = .active;
			}
			
			append_command(s, Cmd_rect{top_bar_placement, .window_top_bar, -1, top_bar_state});
		}
		
		if .movable in flags {
			if utils.collision_point_rect(s.mouse_pos, top_bar_placement) {
				try_set_hot(s, top_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, top_uid);
				}
			}
			if s.mouse_state == .down && current_active(s) == top_uid {
				try_set_active(s, top_uid);
			}
			if current_hot(s) == top_uid {
				set_mouse_cursor(s, .clickable);
			}
			
			if current_active(s) == top_uid {
				w_state.drag_by_mouse = top_bar_placement.xy - s.mouse_pos;
				set_mouse_cursor(s, .draging);
			}
			else {
				w_state.drag_by_mouse = nil;
			}
		
			if drag, ok := w_state.drag_by_mouse.([2]f32); ok {
				w_state.placement.xy += s.mouse_delta;
			}
		}
	
		//Collapse button
		if .collapsable in flags {
			collapse_uid := Unique_id {
				dont_touch,
				call_cnt,
				2,
				user_id,
			}
			
			collapse_dest : Dest;
			switch top_bar_loc {
				case .top, .bottom:
					collapse_dest = {.right, .mid, gstyle.out_padding / 2, 0};
				case .left, .right:
					collapse_dest = {.mid, .top, 0, gstyle.out_padding / 2};
			}	
			collapse_placement := place_in_parent(s, top_bar_placement.xy, top_bar_placement.zw, collapse_dest, [2]f32{style.top_bar_size, style.top_bar_size} - gstyle.out_padding);
			
			collapse_button_state : Display_state = .cold;
			
			if current_hot(s) == collapse_uid {
				collapse_button_state = .hot;
			}
			if current_active(s) == collapse_uid {
				collapse_button_state = .active;
			}
			
			collapse_dir : Rect_type = .window_collapse_button_down;
			
			switch top_bar_loc {
				case .top:
					if w_state.collapsed {
						collapse_dir = .window_collapse_button_down
					}
					else {
						collapse_dir = .window_collapse_button_up
					}
				case .bottom:
					if w_state.collapsed {
						collapse_dir = .window_collapse_button_up
					}
					else {
						collapse_dir = .window_collapse_button_down
					}
				case .left:
					if w_state.collapsed {
						collapse_dir = .window_collapse_button_right
					}
					else {
						collapse_dir = .window_collapse_button_left
					}
				case .right:
					if w_state.collapsed {
						collapse_dir = .window_collapse_button_left
					}
					else {
						collapse_dir = .window_collapse_button_right
					}
			}
			
			append_command(s, Cmd_rect{collapse_placement, collapse_dir, -1, collapse_button_state});
			
			if utils.collision_point_rect(s.mouse_pos, collapse_placement) {
				try_set_hot(s, collapse_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, collapse_uid);
				}
				else if s.mouse_state == .down && current_active(s) == collapse_uid {
					try_set_active(s, collapse_uid);
				}
				else if s.mouse_state == .released  && current_active(s) == collapse_uid {
					w_state.collapsed = !w_state.collapsed; 
				}
			}
			
			if current_hot(s) == collapse_uid {
				set_mouse_cursor(s, .clickable);
			}
			
		}
		
		if title != "" && !(.no_top_bar in flags) {
			width := s.font_width(s.user_data, style.title_size, title);
			asc, des := s.font_height(s.user_data, style.title_size);
			
			dest : Dest;
			rotation : f32 = 0;
			title_size : [2]f32;
			
			switch top_bar_loc {
				case .top:
					if center_title {
						dest = Dest{.mid, .mid, 0, 0}
					}
					else {
						dest = Dest{.left, .mid, style.title_padding, 0}
					}
					title_size = {width, asc + des}
				case .bottom:
					if center_title {
						dest = Dest{.mid, .mid, 0, 0}
					}
					else {
						dest = Dest{.left, .mid, style.title_padding, 0}
					}
					title_size = {width, asc + des}
				case .left:
					if center_title {
						dest = Dest{.mid, .mid, 0, 0}
						rotation = 90;
					}
					else {
						dest = Dest{.right, .bottom, des, style.title_padding}
						rotation = 90;
					}
					title_size = {asc + des, width}
				case .right:
					if center_title {
						dest = Dest{.mid, .mid, 0, 0}
						rotation = 90;
					}
					else {
						dest = Dest{.right, .bottom, des, style.title_padding}
						rotation = 90;
					}
					title_size = {asc + des, width}
			}
			
			title_rect := place_in_parent(s, top_bar_placement.xy, top_bar_placement.zw, dest, title_size);
			title_scissor : Cmd_scissor = {auto_cast top_bar_placement, true};
			title_scissor.area.zw -= top_bar_occupie.yx;
			push_scissor(s, title_scissor);
			append_command(s, Cmd_text{title_rect.xy, strings.clone(title, context.temp_allocator), style.title_size, rotation, .title_text});
			pop_scissor(s);
		}	
		
	}
	
	if .scaleable in flags {
		
		move : [2]f32;
		resize : [2]f32;
		
		if top_bar_loc != .top {
			drag_uid := Unique_id {
				dont_touch,
				call_cnt,
				3,
				user_id,
			}
			
			//if we are close to the left edge (within one line_thickness)
			r := [4]f32{placement.x, placement.y + placement.w - style.line_thickness, placement.z, style.line_thickness};
			if utils.collision_point_rect(s.mouse_pos, r) {
				try_set_hot(s, drag_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, drag_uid);
				}
			}
			if s.mouse_state == .down && current_active(s) == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if current_hot(s) == drag_uid {
				set_mouse_cursor(s, .scale_verical);
			}
			
			if current_active(s) == drag_uid {
				delta := s.mouse_pos.y - (r.y + r.w);
				resize.y += delta;
			}
		}
		
		if top_bar_loc != .left {
			drag_uid := Unique_id {
				dont_touch,
				call_cnt,
				4,
				user_id,
			}
			
			//if we are close to the left edge (within one line_thickness)
			r := [4]f32{placement.x, placement.y, style.line_thickness, placement.w};
			if utils.collision_point_rect(s.mouse_pos, r) {
				try_set_hot(s, drag_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, drag_uid);
				}
			}
			if s.mouse_state == .down && current_active(s) == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if current_hot(s) == drag_uid {
				set_mouse_cursor(s, .scale_horizontal);
			}
			
			if current_active(s) == drag_uid {
				delta := s.mouse_pos.x - r.x;
				move.x += delta;
				resize.x -= delta;
			}
		}
		
		if top_bar_loc != .right {
			drag_uid := Unique_id {
				dont_touch,
				call_cnt,
				5,
				user_id,
			}
			
			//if we are close to the left edge (within one line_thickness)
			r := [4]f32{placement.x + placement.z - style.line_thickness, placement.y, style.line_thickness, placement.w};
			if utils.collision_point_rect(s.mouse_pos, r) {
				try_set_hot(s, drag_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, drag_uid);
				}
			}
			if s.mouse_state == .down && current_active(s) == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if current_hot(s) == drag_uid {
				set_mouse_cursor(s, .scale_horizontal);
			}
			
			if current_active(s) == drag_uid {
				delta := s.mouse_pos.x - (r.x + r.z);
				resize.x += delta;
			}
		}
		
		if top_bar_loc != .bottom {
			drag_uid := Unique_id {
				dont_touch,
				call_cnt,
				6,
				user_id,
			}
			
			//if we are close to the left edge (within one line_thickness)
			r := [4]f32{placement.x, placement.y, placement.z, style.line_thickness};
			if utils.collision_point_rect(s.mouse_pos, r) {
				try_set_hot(s, drag_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, drag_uid);
				}
			}
			if s.mouse_state == .down && current_active(s) == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if current_hot(s) == drag_uid {
				set_mouse_cursor(s, .scale_verical);
			}
			
			if current_active(s) == drag_uid {
				delta := s.mouse_pos.y - r.y;
				move.y += delta;
				resize.y -= delta;
			}
		}
		
		new_placement := w_state.placement;
		
		new_placement.zw += resize;
		
		if new_placement.z < min_size.x {
			if move.x != 0 {
				move.x += new_placement.z - min_size.x
			}
			new_placement.z = min_size.x
		}
		
		if new_placement.w < min_size.y {
			if move.y != 0 {
				move.y += new_placement.w - min_size.y
			}
			new_placement.w = min_size.y
		}
		
		new_placement.xy += move;
		
		w_state.placement = new_placement; 
		
	}
	
	if .scrollbar in flags {
		//w_state.
	}
	
	if !w_state.collapsed {
		if !(.no_background in flags) {
			append_command(s, Cmd_rect{placement, .window_background, -1, .cold});
		}
		if !(.no_border in flags) {
			append_command(s, Cmd_rect{placement, .window_border, style.line_thickness, .cold}); 
		}
	}
	
	push_panel(s, Panel {
		placement.xy + style.line_thickness,
		placement.zw - 2 * style.line_thickness,
		
		hor_behavior,
		ver_behavior,
		append_hor,	//Should we append new elements vertically or horizontally
		
		!(.allow_overflow in flags),
		
		0, //At what offset should new element be added
	});
	
	save_state(s, uid, w_state);
	
	return !w_state.collapsed;
}

end_window :: proc (s : ^State) {
	
	/*
	TODO, dont save the state in begin, save it here instead
	THIs means you should push the window and then pop it here to get it.
	Then find the internal size of all the elements and do the scrollbar.
	I am realizing that this seems like a panel thing and now a window thing, so maybe we should just do it in the panel.
	That said, i would like the window to automagicly size it fit the elements if no window size is given, this cannot be done if  the panel is not refered to by a uid.
	So either the windows store that information, or the panel is linked to the window somehow.
	*/
	
	w_state : Window_state;
	
	pop_panel(s);
	
	{
		_w := get_state(s, s.current_node.uid)
		if __w, ok := _w.(Window_state); ok {
			w_state = __w;
		}
		else {
			fmt.panicf("%v is not a window", _w);
		}
	}
	
	pop_node(s);
}

expand_window :: proc () {
	
}

collapse_window :: proc () {
	
}

bring_window_to_front :: proc () {
	
}

bring_window_to_back :: proc () {
	
}