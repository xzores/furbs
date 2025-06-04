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

//////////////////////////////////////// Spacers ////////////////////////////////////////

spacer :: proc (s : ^State, space : f32) {
	increase_offset(s, space);
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
	
	push_node(s, uid, false);
	defer pop_node(s);
	
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
			_dest = {panel.hor_behavior, panel.ver_behavior, panel.current_offset, gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, gstyle.out_padding, panel.current_offset};
		}
	}
	
	style := get_button_style(s);
	size := style.size;
	total_size += size;
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_ofset, _dest, size);
	
	if is_hover(s, placement) {
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
		
		text_placement := place_in_parent(s, placement.xy + style.text_padding, placement.zw - 2 * style.text_padding, 0, Dest{style.text_hor, style.text_ver, 0, 0}, text_size);
		text_placement.y -= dec
		append_command(s, Cmd_text{text_placement.xy, strings.clone(label, context.temp_allocator), style.text_size, 0, .button_text});
	}
	
	if d, ok := dest.?; !ok {
		increase_offset(s, total_size);
	}
	else {
		//expand_virtual_size(s, [4]f32{placement.x, placement.y, total_size.x, total_size.y});
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
	
	push_node(s, uid, false);
	defer pop_node(s);
	
	panel := get_current_panel(s);
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, panel.current_offset, gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, gstyle.out_padding, panel.current_offset};
		}
	}
	
	style := get_checkbox_style(s);
	size := style.size;
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_ofset, _dest, size);
	
	if is_hover(s, placement) {
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
		act_placement := place_in_parent(s, placement.xy, placement.zw, 0, Dest{.mid, .mid, 0, 0}, size - style.line_thickness*6);
		append_command(s, Cmd_rect{act_placement, .checkbox_foreground, -1, checkbox_state}); //The background
	}
	
	total_size := size;
	if label != "" {
		text_size := style.text_size
		
		text_placement := placement.xy;
		text_placement.x += + size.x + style.text_padding;
		asc, dec := s.font_height(s.user_data, style.text_size);
		text_placement.y += -dec;
		append_command(s, Cmd_text{text_placement, strings.clone(label, context.temp_allocator), style.text_size, 0, .checkbox_text});
		total_size += {style.text_padding + s.font_width(s.user_data, asc - dec, label), 0}; //TODO this should be total_placement as the text can expand in the negative direction.
	}
	
	if d, ok := dest.?; !ok {
		increase_offset(s, total_size);
	}
	else {
		//expand_virtual_size(s, placement);
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
	ver_scrollbar,
	hor_scrollbar,
	scroll_auto_hide, //TODO
	
	//Dont allow use the interact with it or any sub elements.
	no_input, //TODO
	
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

Window_state :: struct {
	placement : [4]f32,
	drag_by_mouse : Maybe([2]f32), //relavtive to mouse position 
	collapsed : bool,
	flags : Window_falgs,
	scroll_offset : [2]f32,
}

begin_window :: proc (s : ^State, size : [2]f32, flags : Window_falgs, dest : Dest, title := "", top_bar_loc := Top_bar_location.top, user_id := 0, dont_touch := #caller_location) -> bool {
	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	push_node(s, uid, true);
	
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
	
	//the first time the window is found
	{
		_w := get_state(s, uid);
		
		first_placement := place_in_parent(s, parent.position, parent.size, parent.scroll_ofset, dest, size);
		
		first_placement.xy += bar_cause_offset
		first_placement.zw -= top_bar_occupie
		
		if _w == nil {
			
			
			w_state = Window_state {
				first_placement, 		//placement : [4]f32,
				nil,					//drag_by_mouse : Maybe([2]f32), //relavtive to mouse position 
				.collapsed in flags,	//collapsed : bool,
				flags,					//flags : Window_falgs,
				{0,0},					//scroll_offset : [2]f32,
			};
		}
		else if last_window, ok := _w.(Window_state); ok {
			w_state = last_window;
		}
		else  {
			panic("The was not a window last frame");
		}
		
		if !(.movable in flags) {
			w_state.placement = first_placement;
		}
	}
	w_state.flags = flags;
	
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
	
	placement := place_in_parent(s, parent.position, parent.size, parent.scroll_ofset, {.left, .bottom, w_state.placement.x, w_state.placement.y}, w_state.placement.zw);;
	//expand_virtual_size(s, placement);
	
	if !w_state.collapsed {
		if is_hover(s, placement) {
			try_set_hot(s, uid);
			if s.mouse_state == .pressed {
				try_set_active(s, uid);
			}
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
			if is_hover(s, top_bar_placement) {
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
			collapse_placement := place_in_parent(s, top_bar_placement.xy, top_bar_placement.zw, 0, collapse_dest, [2]f32{style.top_bar_size, style.top_bar_size} - gstyle.out_padding);
			
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
			
			if is_hover(s, collapse_placement) {
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
			
			center_title := .center_title in flags;
			
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
			
			title_rect := place_in_parent(s, top_bar_placement.xy, top_bar_placement.zw, 0, dest, title_size);
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
			if is_hover(s, r) {
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
			if is_hover(s, r) {
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
			if is_hover(s, r) {
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
			if is_hover(s, r) {
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
	
	if !w_state.collapsed {
		
		if !(.no_background in flags) {
			append_command(s, Cmd_rect{placement, .window_background, -1, .cold});
		}
		if !(.no_border in flags) {
			append_command(s, Cmd_rect{placement, .window_border, style.line_thickness, .cold}); 
		}
		
		push_panel(s, Panel {
			placement.xy + style.line_thickness,
			placement.zw - 2 * style.line_thickness,
			w_state.scroll_offset,
			
			hor_behavior,
			ver_behavior,
			append_hor,	//Should we append new elements vertically or horizontally
			
			!(.allow_overflow in flags),
			
			0, //At what offset should new element be added
			{}, //calculated when things are added
		});
	}
	
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
	
	{
		_w := get_state(s, s.current_node.uid)
		if __w, ok := _w.(Window_state); ok {
			w_state = __w;
		}
		else {
			fmt.panicf("%v is not a window", _w);
		}
	}
	
	if !w_state.collapsed {
		
		panel := s.panel_stack[len(s.panel_stack)-1]
		
		scroll_style := get_scroll_style(s);
		
		handle_scroll_bar :: proc (s : ^State, mouse_pos : f32, scroll_delta : f32, virtual_size, size : f32, scroll_uid : Unique_id, scroll_height : f32, placement : [4]f32, scroll_placement_coord : f32,
									 scroll_placement_height : f32, scroll_offset : ^f32, reverse, reverse_scroll: bool) -> (scroll_procent : f32, active_height : f32, display_state : Display_state) {
			
			if is_hover(s, placement) {
				try_set_hot(s, scroll_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, scroll_uid);
				}
				if s.mouse_state == .down && s.hot == scroll_uid {
					try_set_active(s, scroll_uid);
				}
			}
			if s.mouse_state == .down && s.active == scroll_uid {
				try_set_active(s, scroll_uid);
			}
			
			procentage_of_view_in_virtual : f32 = size / virtual_size;
			active_height = scroll_height * procentage_of_view_in_virtual;
			
			display_state = .cold;
			
			m : f32= -1
			if reverse { 
				m = 1;
			}
			
			scroll_procent = m * scroll_offset^ / (virtual_size - size);
			
			if s.hot == scroll_uid {
				display_state = .hot;
			}
			if s.active == scroll_uid {
				display_state = .active;
				scroll_procent = math.remap_clamped(mouse_pos, scroll_placement_coord + active_height / 2, scroll_placement_coord + scroll_placement_height - active_height / 2, 0, 1);
				
				if reverse {
					scroll_procent = 1 - scroll_procent;
				}
			}
			
			m_scroll : f32= -1
			if reverse_scroll { 
				m = 1;
			}
			
			scroll_procent += m_scroll * scroll_delta / (virtual_size - size);
			scroll_procent = math.clamp(scroll_procent, 0, 1);
			
			scroll_offset^ = m * scroll_procent * (virtual_size - size);
			
			return;
		}
		
		scroll_delta : [2]f32;
		
		//TODO there can be things inside things that scroll, we do not handle that yet.
		if is_hot_path(s, s.current_node) {
			scroll_delta = s.scroll_delta;
		}
		
		if .hor_scrollbar in w_state.flags && panel.virtual_size.x > panel.size.x {
			scroll_uid := s.current_node.uid;
			scroll_uid.sub_priotity = 101;
			
			//the horizontal scrollbar
			scroll_height := panel.size.x - 2 * scroll_style.length_padding;
			scroll_placement := place_in_parent(s, panel.position, panel.size, 0, Dest{.mid, .bottom, 0, scroll_style.padding.y}, [2]f32{scroll_height, scroll_style.bar_bg_thickness});
			
			sd : f32 = scroll_delta.x;
			if s.hot == scroll_uid {
				sd = s.scroll_delta.x;
				sd += s.scroll_delta.y;
			}
			
			scroll_procent, active_height, display_state := handle_scroll_bar(s, s.mouse_pos.x, sd, panel.virtual_size.x, panel.size.x, scroll_uid, scroll_height, scroll_placement, scroll_placement.x, scroll_placement.z, &w_state.scroll_offset.x, false, false);
			
			view_scroll_placement := place_in_parent(s, scroll_placement.xy, scroll_placement.zw, 0, Dest{.left, .mid, scroll_procent * (scroll_height - active_height), 0}, [2]f32{active_height, scroll_style.bar_front_thickness});
			
			append_command(s, Cmd_rect{scroll_placement, .scrollbar_background, -1, display_state});
			append_command(s, Cmd_rect{view_scroll_placement, .scrollbar_front, -1, display_state});
		}
		
		if .ver_scrollbar in w_state.flags && panel.virtual_size.y > panel.size.y {
			scroll_uid := s.current_node.uid;
			scroll_uid.sub_priotity = 100;
			
			sd : f32 = scroll_delta.y;
			if s.hot == scroll_uid {
				sd += s.scroll_delta.y;
			}
			
			//the vertical scrollbar
			scroll_height := panel.size.y - 2 * scroll_style.length_padding;
			scroll_placement := place_in_parent(s, panel.position, panel.size, 0, Dest{.right, .mid, scroll_style.padding.x, 0}, [2]f32{scroll_style.bar_bg_thickness, scroll_height});
			
			scroll_procent, active_height, display_state := handle_scroll_bar(s, s.mouse_pos.y, sd, panel.virtual_size.y, panel.size.y, scroll_uid, scroll_height, scroll_placement, scroll_placement.y, scroll_placement.w, &w_state.scroll_offset.y, true, true);
			
			view_scroll_placement := place_in_parent(s, scroll_placement.xy, scroll_placement.zw, 0, Dest{.mid, .top, 0, scroll_procent * (scroll_height - active_height)}, [2]f32{scroll_style.bar_front_thickness, active_height});
			
			append_command(s, Cmd_rect{scroll_placement, .scrollbar_background, -1, display_state});
			append_command(s, Cmd_rect{view_scroll_placement, .scrollbar_front, -1, display_state});
		}
		
		pop_panel(s);
	}
	
	save_state(s, s.current_node.uid, w_state);
	
	pop_node(s);
	
}

bring_window_to_front :: proc () {
		
}

bring_window_to_back :: proc () {
	
}

//////////////////////////////////////// Menu ////////////////////////////////////////

//TODO implment in to Menu_option
Menu_checkbox :: struct {
	label : string,
	value : ^bool,
}

Menu_option :: union {
	string,
	//Menu_checkbox //TODO
	Sub_menu
}

Sub_menu :: struct {
	label : string,
	options : []Menu_option,
	popout_dir : Menu_popout_dir,
	reverse_sort : bool,
}

Menu_popout_dir :: enum {
	down, //center_down but without centering
	up, //center_up but without centering
	
	down_right, //same as down, but keeps right
	up_right, //same as up, but keeps right
	
	left_up,
	center_up,
	right_up,
	left_center,
	center_center,
	right_center,
	left_down,
	center_down,
	right_down,
}

menu :: proc (s : ^State, label : string, options : []Menu_option, popout_dir : Menu_popout_dir, reverse_sort : bool = false, dest : Maybe(Dest) = nil, user_id := 0, dont_touch := #caller_location) -> string {
	
	sub := Sub_menu {
		label, 
		options,
		popout_dir,
		reverse_sort,
	}
	
	path := make([dynamic]int);
	
	return sub_menu(s, sub, 0, &path, dest, user_id, dont_touch);
}

sub_menu :: proc (s : ^State, using menu : Sub_menu, sub_prio : int, path : ^[dynamic]int, dest : Maybe(Dest) = nil, user_id := 0, dont_touch := #caller_location) -> (res : string) {
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		sub_prio,
		user_id,
	}
	
	push_node(s, uid, true);
	defer pop_node(s);
	
	panel := get_current_panel(s);
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, panel.current_offset, gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, gstyle.out_padding, panel.current_offset};
		}
	}
	
	style := get_menu_style(s);
	
	width := s.font_width(s.user_data, style.text_size, label) + style.text_padding * 2;
	size := [2]f32{width, style.height};
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_ofset, _dest, size);
	
	if is_hover(s, placement) {
		try_set_hot(s, uid);
	}
	
	gui_state : Display_state = .cold;
	
	if is_hot_path(s, s.current_node) {
		gui_state = .hot;
	}
	
	append_command(s, Cmd_rect{placement, .menu_background, -1, gui_state});
	append_command(s, Cmd_rect{placement, .menu_border, style.line_thickness, gui_state});
	
	if label != "" {
		padding := style.text_padding
		
		asc, dec := s.font_height(s.user_data, style.text_size);
		text_width := s.font_width(s.user_data, style.text_size, label);
		
		text_size :=  [2]f32{text_width, asc - dec};
		
		text_placement := place_in_parent(s, placement.xy + style.text_padding, placement.zw - 2 * style.text_padding, 0, Dest{style.text_hor, style.text_ver, 0, 0}, text_size);
		text_placement.y -= dec
		append_command(s, Cmd_text{text_placement.xy, strings.clone(label, context.temp_allocator), style.text_size, 0, .menu_item});
	}
	
	if is_hot_path(s, s.current_node) {
		//find the size of all the options 
		
		max_text_width : f32 = 0;
		
		for opt, i in options {
			
			switch o in opt {
				case string:
					max_text_width = math.max(max_text_width, s.font_width(s.user_data, style.text_size, o));
				case Sub_menu:
					max_text_width = math.max(max_text_width, s.font_width(s.user_data, style.text_size, o.label));
			}
		}
		
		sub_width := max_text_width + style.text_padding * 2;
		
		items_placement := placement;
		items_placement.zw = [2]f32{sub_width, f32(len(options)) * style.height};
		
		switch popout_dir {
			case .down:
				items_placement.y += -items_placement.w
				
			case .up:
				items_placement.y += placement.w
				
			case .down_right:
				items_placement.y += -items_placement.w
				items_placement.x += placement.z - items_placement.z
				
			case .up_right:
				items_placement.y += placement.w
				items_placement.x += placement.z - items_placement.z
				
			case .left_up:
				items_placement.y += placement.w
				items_placement.x += -items_placement.z
				items_placement.y -= style.height
				
			case .center_up:
				items_placement.y += placement.w
				items_placement.y += placement.w / 2 - items_placement.w /2
				items_placement.x += placement.z / 2 - items_placement.z /2
				
			case .right_up:
				items_placement.y += placement.w
				items_placement.x += placement.z
				items_placement.y -= style.height
				
			case .left_center:
				items_placement.y += placement.w / 2 - items_placement.w /2
				items_placement.x += -items_placement.z
				
			case .center_center:
				items_placement.y += placement.w / 2 - items_placement.w /2
				items_placement.x += placement.z / 2 - items_placement.z /2
				
			case .right_center:
				items_placement.y += placement.w / 2 - items_placement.w /2
				items_placement.x += placement.z
				
			case .left_down:
				items_placement.y += -items_placement.w
				items_placement.x += -items_placement.z
				items_placement.y += style.height
				
			case .center_down:
				items_placement.y += -items_placement.w
				items_placement.x += placement.z / 2 - items_placement.z /2
				
			case .right_down:
				items_placement.y += -items_placement.w
				items_placement.x += placement.z
				items_placement.y += style.height
		}
		
		//limit the placement to inside the parent scissors
		{
			scissor := s.scissor_stack[len(s.scissor_stack) - 1];
			if scissor.enable {
				items_placement.x = math.clamp(items_placement.x, scissor.area.x, scissor.area.x + scissor.area.z);
				items_placement.y = math.clamp(items_placement.y, scissor.area.y, scissor.area.y + scissor.area.w);
			}
		}
		
		//disable scissors to allow the options to spill into other places
		push_scissor(s, {0, false});
		defer pop_scissor(s);
		
		append_command(s, Cmd_rect{items_placement, .menu_item_background, -1, gui_state});
		append_command(s, Cmd_rect{items_placement, .menu_item_background_border, style.line_thickness, gui_state});
		
		push_panel(s, Panel{
			items_placement.xy,
			items_placement.zw, //the view size
			0,	//if offset of the view
			
			.left,
			.top,
			false,	//Should we append new elements vertically or horizontally
			
			false,
			
			0, //At what offset should new element be added
			{}, //the size which there exists items/elements
		});
		defer pop_panel(s);
		
		if is_hover(s, items_placement) {
			try_set_hot(s, uid);
		}
		
		for opt, i in options {
			
			sub_placement : [4]f32;
			if reverse_sort {
				sub_placement.xy = items_placement.xy
				sub_placement.zw = {sub_width, style.height}
				sub_placement.y += f32(i) * style.height;
			}
			else {
				sub_placement.xy = items_placement.xy + {0, f32(len(options) - 1) * style.height};
				sub_placement.zw = {sub_width, style.height}
				sub_placement.y -= f32(i) * style.height;
			}
			
			switch o in opt {
				case string:
					
					clicked : bool
					gui_state : Display_state = .cold;
					
					if is_hover(s, sub_placement) {
						try_set_hot(s, uid);
						try_set_active(s, uid);
						gui_state = .hot;
						if s.mouse_state == .pressed {
							gui_state = .active;
						}
						if current_active(s) == uid && s.mouse_state == .down {
							gui_state = .active;
						}
						if current_active(s) == uid && s.mouse_state == .released {
							clicked = true
							res = o;
						}
					}
					
					append_command(s, Cmd_rect{sub_placement, .menu_item_front, -1, gui_state});
					append_command(s, Cmd_rect{sub_placement, .menu_item_front_border, style.line_thickness, gui_state});
					
					if o != "" {
						padding := style.text_padding
						
						asc, dec := s.font_height(s.user_data, style.text_size);
						text_width := s.font_width(s.user_data, style.text_size, o);
						
						text_size :=  [2]f32{text_width, asc - dec};
						
						text_placement := place_in_parent(s, sub_placement.xy + style.text_padding, sub_placement.zw - 2 * style.text_padding, 0, Dest{style.text_hor, style.text_ver, 0, 0}, text_size);
						text_placement.y -= dec
						append_command(s, Cmd_text{text_placement.xy, strings.clone(o, context.temp_allocator), style.text_size, 0, .menu_item});
					}
					
				case Sub_menu:
					sub_res := sub_menu(s, o, sub_prio + 1, path, Dest{.left, .bottom, sub_placement.x - items_placement.x, sub_placement.y - items_placement.y}, user_id, dont_touch);
					if sub_res != "" {
						res = sub_res;
					}
			}
		}
	}
	
	if d, ok := dest.?; !ok {
		increase_offset(s, size);
	}
	else {
		//expand_virtual_size(s, [4]f32{placement.x, placement.y, total_size.x, total_size.y});
	}
	
	return;
}