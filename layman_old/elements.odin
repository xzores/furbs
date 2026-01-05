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
	_ = do_offset(s, space);
}

//////////////////////////////////////// Button ////////////////////////////////////////

button :: proc (s : ^State, dest : Maybe(Dest) = nil, label := "", user_id := 0, dont_touch := #caller_location) -> (value : bool) {	
	uid := make_uid(s, user_id, dont_touch);
	
	push_node(s, uid, false, false);
	defer pop_node(s);
	
	panel := get_current_panel(s);
	
	style := get_button_style(s);
	size := style.size;
	
	offset := do_offset(s, size);
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x, offset.y + gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x + gstyle.out_padding, offset.y};
		}
	}
	
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_offset, _dest, size);
	
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
	append_command(s, Cmd_rect{placement, .button_border, style.border_thickness, gui_state});
	
	if label != "" {
		padding := style.text_padding
		
		asc, dec := s.font_height(s.user_data, style.text_size);
		text_width := s.font_width(s.user_data, style.text_size, label);
		
		text_size :=  [2]f32{text_width, asc - dec};
		
		text_placement := place_in_parent(s, placement.xy + style.text_padding, placement.zw - 2 * style.text_padding, 0, Dest{style.text_hor, style.text_ver, 0, 0}, text_size);
		text_placement.y -= dec
		append_command(s, Cmd_text{text_placement.xy, strings.clone(label, context.temp_allocator), style.text_size, 0, .button_text});
	}
	
	return;
}

//////////////////////////////////////// Checkbox ////////////////////////////////////////

checkbox :: proc (s : ^State, value : ^bool, dest : Maybe(Dest) = nil, label := "", user_id := 0, dont_touch := #caller_location) -> bool {	
	uid := make_uid(s, user_id, dont_touch);
	
	push_node(s, uid, false, false);
	defer pop_node(s);
	
	panel := get_current_panel(s);
	
	style := get_checkbox_style(s);
	size := style.size;
	total_size := size;
	
	if label != "" {
		text_size := style.text_size;
		asc, dec := s.font_height(s.user_data, style.text_size);
		total_size.x += style.text_padding + s.font_width(s.user_data, asc - dec, label); //TODO this should be total_placement as the text can expand in the negative direction.
	}
	
	offset := do_offset(s, total_size);
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x, offset.y + gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x +  gstyle.out_padding, offset.y};
		}
	}
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_offset, _dest, size);
	
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
	append_command(s, Cmd_rect{placement, .checkbox_border, style.border_thickness, checkbox_state}); //The background	
	
	if value^ {
		act_placement := place_in_parent(s, placement.xy, placement.zw, 0, Dest{.mid, .mid, 0, 0}, size - style.border_thickness*6);
		append_command(s, Cmd_rect{act_placement, .checkbox_foreground, -1, checkbox_state}); //The background
	}
	
	if label != "" {
		text_size := style.text_size
		
		text_placement := placement.xy;
		text_placement.x += + size.x + style.text_padding;
		asc, dec := s.font_height(s.user_data, style.text_size);
		text_placement.y += -dec;
		append_command(s, Cmd_text{text_placement, strings.clone(label, context.temp_allocator), style.text_size, 0, .checkbox_text});
	}
	
	return value^;
}

//////////////////////////////////////// Input Field ////////////////////////////////////////

//TODO input field


//////////////////////////////////////// Container ////////////////////////////////////////

//TODO rename the current panel to something else, and then use panel as the everyone else uses it.
//That means a windows should have a panel and the panel is what should controll the scroll and such.  (Maybe that is the way the current panel works)

/*
Register_container :: proc (s : ^State, , user_id := 0, dont_touch := #caller_location) {
	
	
	
}

begin_container :: proc (s : ^State, placement : [4]f32, user_id := 0, dont_touch := #caller_location) {
	uid := make_uid(s, user_id, dont_touch);
	
	parent := s.panel_stack[len(s.panel_stack) - 1];
	
	push_node(s, uid, false);
	
	push_panel(s, Panel {
		placement.xy,
		placement.zw,
		{},
		{}, //calculated when things are added
		
		.left,
		.top,
		false,	//Should we append new elements vertically or horizontally
		
		false,
		
		0, //At what offset should new element be added
	});
}

end_container :: proc (s : ^State) -> Container_ref {
	
	pop_panel(s);
}
*/

//////////////////////////////////////// Splitter (simple) ////////////////////////////////////////

Split_panel_falgs_enum :: enum {
	
	//looks
	no_border,
	no_background,
	//TODO maybe a no_splitter option
	
	//How elements are added
	allow_resize,
	bottom_to_top,
	right_to_left,
	append_horizontally,
	wrap_on_overflow,
	
	//Scrollbar
	hor_scrollbar,
	ver_scrollbar,
	scroll_auto_hide, //TODO
	
	//Automagicly figure out size of the begining panels, last panel get the rest
	auto_size, //shrink to just fit the sub elements except the last panel, it takes the rest of the space.
}

Split_panel_falgs :: bit_set[Split_panel_falgs_enum];

Split_dir :: enum {
	horizontal,
	vertical,
}

Splitter_state :: struct {
	procentages : [dynamic]f32,
	last_size : [dynamic][2]f32,
	flags : Split_panel_falgs,
}

begin_split_panel :: proc (s : ^State, ratios : []f32, dir : Split_dir, flags : Split_panel_falgs, user_id := 0, dont_touch := #caller_location) {
	uid := make_uid(s, user_id, dont_touch);
	
	push_node(s, uid, false, false);
	
	style := get_split_panel_style(s);
	
	total_ratios : f32;
	for r in ratios {
		total_ratios += r;
	}
	
	cur_offset : [2]f32 = {0, 0};
	
	parent := s.panel_stack[len(s.panel_stack) - 1]
	s_state : Splitter_state;
	
	//the first time the split is found
	{
		_s := get_state(s, uid);
		if _s == nil {
			
			procentages := make([dynamic]f32, len(ratios), len(ratios));
			
			s_state = Splitter_state {
				procentages,
				make([dynamic] [2]f32),
				flags,
			};
		}
		else if last_splitter, ok := _s.(Splitter_state); ok {
			s_state = last_splitter;
		}
		else  {
			panic("The was not a window last frame");
		}
		
		if !(.allow_resize in flags) || _s == nil {
			for &p, i in s_state.procentages {
				p = ratios[i] / total_ratios;
			}
		}
	}
	s_state.flags = flags;
	
	//if auto_size then overwrite the ratios with ratios calculated from last frame.
	if .auto_size in flags && len(s_state.last_size) == len(ratios) {
		ratio_acc : f32 = 0;
		for &r, i in ratios[:len(ratios)-1] {
			if dir == .horizontal {
				r = s_state.last_size[i].x;
				ratio_acc += r;
			}
			else {
				r = s_state.last_size[i].y;
				ratio_acc += r;
			}
		}
		
		if dir == .horizontal {
			ratios[len(ratios) - 1] = parent.size.x - ratio_acc;
		}
		else {
			ratios[len(ratios) - 1] = parent.size.y - ratio_acc;
		}
		
		for &p, i in s_state.procentages {
			p = ratios[i] / total_ratios;
		}	
	}
	
	width := parent.size.x;
	height := parent.size.y;
	
	if is_hover(s, {parent.position.x, parent.position.y, parent.size.x, parent.size.y}) {
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
	}
	
	panels := make([dynamic]Panel, context.temp_allocator);
	
	for procent, i in s_state.procentages {
		
		placement : [4]f32;
		sub_size := [2]f32{width, height};
		ver : Ver_placement = .top;
		
		if .bottom_to_top in flags {
			ver = .bottom
		}
		
		if dir == .horizontal {
			sub_size.x = procent * width;
		}
		else {
			sub_size.y = procent * height;
		}
		
		placement = place_in_parent(s, parent.position, parent.size, {}, Dest{.left, ver, cur_offset.x , cur_offset.y}, sub_size);
		
		if dir == .horizontal {
			cur_offset.x += procent * width;
		}
		else {
			cur_offset.y += procent * height;
		}
		
		splitter_uid := make_uid(s, user_id, dont_touch, 1);
		splitter_placement : [4]f32; 
		
		if dir == .horizontal {
			splitter_placement = place_in_parent(s, parent.position, parent.size, {}, Dest{.left, ver, cur_offset.x, cur_offset.y}, {style.splitter_thickness, height});
		}
		else {
			splitter_placement = place_in_parent(s, parent.position, parent.size, {}, Dest{.left, ver, cur_offset.x, cur_offset.y}, {width, style.splitter_thickness});
		}
		
		if .allow_resize in flags {
			
			if is_hover(s, splitter_placement) {
				try_set_hot(s, splitter_uid);
				if s.mouse_state == .pressed {
					try_set_active(s, splitter_uid);
				}
				
				if dir == .horizontal {
					set_mouse_cursor(s, .scale_horizontal);
					//TODO make a split_panel state, which stores procentage of panel which is accesiable.
				}
				else {
					set_mouse_cursor(s, .scale_verical);
				}
			}
			
			if current_active(s) == splitter_uid {
				if s.mouse_state == .down {
					try_set_active(s, splitter_uid);
				}
				
				if dir == .horizontal {
					set_mouse_cursor(s, .scale_horizontal);
					delta := s.mouse_pos.x - splitter_placement.x - splitter_placement.z;
					//turn into procentage
					new_procentage := procent + (delta / parent.size.x);
					next_new_procentage := s_state.procentages[i + 1] - (delta / parent.size.x);
					s_state.procentages[i] = new_procentage;
					s_state.procentages[i+1] = next_new_procentage;
				}
				else {
					set_mouse_cursor(s, .scale_verical);
					delta := s.mouse_pos.y - splitter_placement.y - splitter_placement.w;
					//turn into procentage
					new_procentage := procent - (delta / parent.size.y);
					next_new_procentage := s_state.procentages[i + 1] + (delta / parent.size.y);
					s_state.procentages[i] = new_procentage;
					s_state.procentages[i+1] = next_new_procentage;
				}
			}
		}
		
	}
	
	cur_offset = {0, 0};
	
	total_procentage : f32;
	
	for p in s_state.procentages {
		total_procentage += p;
	}
	
	for &p, i in s_state.procentages {
		p = p / total_procentage
	}
	
	for &p, i in s_state.procentages {
		p = math.clamp(p, 0.01, 0.99);
	}
	
	for procent, i in s_state.procentages {
		
		placement : [4]f32;
		sub_size := [2]f32{width, height};
		ver : Ver_placement = .top;
		hor : Hor_placement = .left;
		
		if .bottom_to_top in flags {
			ver = .bottom
		}
		
		if .right_to_left in flags {
			hor = .right
		}
		
		if dir == .horizontal {
			sub_size.x = procent * width;
		}
		else {
			sub_size.y = procent * height;
		}
		
		placement = place_in_parent(s, parent.position, parent.size, {}, Dest{.left, ver, cur_offset.x , cur_offset.y}, sub_size);
		
		if dir == .horizontal {
			cur_offset.x += procent * width;
		}
		else {
			cur_offset.y += procent * height;
		}
		
		//create a panel for each seqment
		if !(.no_background in flags) {
			append_command(s, Cmd_rect{placement, .window_background, -1, .cold});
		}
		if !(.no_border in flags) {
			append_command(s, Cmd_rect{placement, .window_border, style.border_thickness, .cold}); 
		}
		
		splitter_uid := make_uid(s, user_id, dont_touch, 1);
		splitter_placement : [4]f32; 
		
		if dir == .horizontal {
			splitter_placement = place_in_parent(s, parent.position, parent.size, {}, Dest{.left, ver, cur_offset.x, cur_offset.y}, {style.splitter_thickness, height});
		}
		else {
			splitter_placement = place_in_parent(s, parent.position, parent.size, {}, Dest{.left, ver, cur_offset.x, cur_offset.y}, {width, style.splitter_thickness});
		}
		
		append_command(s, Cmd_rect{splitter_placement, .split_panel_splitter, style.splitter_thickness, .cold}); 
		
		if dir == .horizontal {
			cur_offset.x += style.splitter_thickness;
		}
		else {
			cur_offset.y += style.splitter_thickness;
		}
		
		append(&panels, Panel{
			placement.xy, //position
			placement.zw, //size
			{}, //scroll_ofset
			{}, //virtual_size
			hor, //hor_behavior
			ver, //ver_behavior
			.append_horizontally in flags, //append_hor
			true, //use_scissor
			.hor_scrollbar in flags, //scroll_hor
			.ver_scrollbar in flags, //scroll_ver
			.wrap_on_overflow in flags,
			0, //current_offset
			nil, //uid
		});
	}
	
	save_state(s, uid, s_state);
	
	append(&s.split_panel_stack, Split_panel {
		uid,
		dir,
		0,
		panels,
	});
	
	next_split_panel(s, true);
}

//move to next panel
next_split_panel :: proc (s : ^State, keep_false := false) {
	style := get_split_panel_style(s);
	sp := &s.split_panel_stack[len(s.split_panel_stack) - 1];
	
	s_state : Splitter_state = get_state(s, sp.uid).(Splitter_state);
	if !keep_false {
		p := pop_panel(s);
		resize(&s_state.last_size, len(s_state.procentages));
		s_state.last_size[sp.next_panel - 1] = p.virtual_size;
		pop_node(s);
	}
	
	save_state(s, sp.uid, s_state);
	
	uid := sp.uid;
	uid.sub_priotity += sp.next_panel + 1;
	
	push_node(s, uid, false, false);
	push_panel(s, sp.panels[sp.next_panel]);
	sp.next_panel += 1;
	
}

end_split_panel :: proc (s : ^State, loc := #caller_location) {
	//DO some stuff
	
	sp := pop(&s.split_panel_stack);
	s_state : Splitter_state = get_state(s, sp.uid).(Splitter_state);
	
	assert(sp.next_panel == len(sp.panels), "You did not go though all the panels", loc)
	
	p := pop_panel(s);
	pop_node(s);
	
	resize(&s_state.last_size, len(s_state.procentages));
	s_state.last_size[sp.next_panel - 1] = p.virtual_size;
	
	save_state(s, sp.uid, s_state);
	
	//the split panel nodes
	pop_node(s);
}


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
	wrap_on_overflow,
	
	//Ables
	movable,
	scaleable,
	collapsable,
	
	//Scrollbar
	hor_scrollbar,
	ver_scrollbar,
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
	dest : Dest,
	size : [2]f32,
	drag_by_mouse : Maybe([2]f32), //relavtive to mouse position 
	collapsed : bool,
	flags : Window_falgs,
}

begin_window :: proc (s : ^State, size : [2]f32, flags : Window_falgs, dest : Dest, title := "", top_bar_loc := Top_bar_location.top, user_id := 0, dont_touch := #caller_location) -> bool {
	uid := make_uid(s, user_id, dont_touch);
	
	push_node(s, uid, false, false);
	
	gstyle := get_style(s);
	style := get_window_style(s);
	
	min_size := [2]f32{1, 1} * (gstyle.out_padding + style.border_thickness) * 2 + style.title_size;
	
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
		
		first_placement := place_in_parent(s, parent.position, parent.size, parent.scroll_offset, dest, size);
		
		first_placement.xy += bar_cause_offset
		first_placement.zw -= top_bar_occupie
		
		if _w == nil {
			
			w_state = Window_state {
				dest,
				size,
				nil,					//drag_by_mouse : Maybe([2]f32), //relavtive to mouse position 
				.collapsed in flags,	//collapsed : bool,
				flags,					//flags : Window_falgs,
			};
		}
		else if last_window, ok := _w.(Window_state); ok {
			w_state = last_window;
		}
		else  {
			panic("The was not a window last frame");
		}
		
		if !(.movable in flags) && !(.scaleable in flags) {
			w_state.dest = dest;
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
	
	placement := place_in_parent(s, parent.position, parent.size, parent.scroll_offset, w_state.dest, w_state.size);
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
		top_uid := uid;
		top_uid.sub_priotity = 1;
		
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
				if w_state.drag_by_mouse == nil {
					w_state.drag_by_mouse = s.mouse_pos - placement.xy;
				}
				set_mouse_cursor(s, .draging);
			}
			else {
				w_state.drag_by_mouse = nil;
			}
			
			if drag, ok := w_state.drag_by_mouse.([2]f32); ok {
				delta := (s.mouse_pos - placement.xy) - drag
				w_state.dest = move_dest(w_state.dest, delta.x, delta.y);
			}
		}
		
		//Collapse button
		if .collapsable in flags {
			collapse_uid := uid;
			collapse_uid.sub_priotity = 2;
			
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
		delta_size : [2]f32;
		
		if top_bar_loc != .top || (.no_top_bar in flags) {
			drag_uid := uid;
			drag_uid.sub_priotity = 3;
			
			//if we are close to the left edge (within one border_thickness)
			r := [4]f32{placement.x, placement.y + placement.w - style.border_thickness, placement.z, style.border_thickness};
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
				w_state.dest, w_state.size = resize_rect(w_state.dest, w_state.size, delta, .top);
			}
		}
		
		if top_bar_loc != .left || (.no_top_bar in flags) {
			drag_uid := uid;
			drag_uid.sub_priotity = 4;
			
			//if we are close to the left edge (within one border_thickness)
			r := [4]f32{placement.x, placement.y, style.border_thickness, placement.w};
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
				w_state.dest, w_state.size = resize_rect(w_state.dest, w_state.size, delta, .left);
			}
		}
		
		if top_bar_loc != .right || (.no_top_bar in flags) {
			drag_uid := uid;
			drag_uid.sub_priotity = 5;
			
			//if we are close to the left edge (within one border_thickness)
			r := [4]f32{placement.x + placement.z - style.border_thickness, placement.y, style.border_thickness, placement.w};
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
				w_state.dest, w_state.size = resize_rect(w_state.dest, w_state.size, delta, .right);
			}
		}
		
		if top_bar_loc != .bottom || (.no_top_bar in flags) {
			drag_uid := uid;
			drag_uid.sub_priotity = 6;
			
			//if we are close to the left edge (within one border_thickness)
			r := [4]f32{placement.x, placement.y, placement.z, style.border_thickness};
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
				w_state.dest, w_state.size = resize_rect(w_state.dest, w_state.size, delta, .bottom);
			}
		}
		
		//delta_size
		
		/*
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
		*/
	}
	
	if !w_state.collapsed {
		
		if !(.no_background in flags) {
			append_command(s, Cmd_rect{placement, .window_background, -1, .cold});
		}
		if !(.no_border in flags) {
			append_command(s, Cmd_rect{placement, .window_border, style.border_thickness, .cold}); 
		}
		
		push_panel(s, Panel {
			placement.xy + style.border_thickness, 			//	position : [2]f32, //in relation to the parent panel
			placement.zw - 2 * style.border_thickness, 		//	size : [2]f32, //the view size
			{0,0}, 											//	scroll_offset : [2]f32,
			{}, //calculated when things are added 			//	virtual_size : [2]f32, //the size which there exists items/elements
			 													
			hor_behavior, 									//	hor_behavior : Hor_placement,
			ver_behavior, 									//	ver_behavior : Ver_placement,
			append_hor,										//	append_hor : bool,	//Should we append new elements vertically or horizontally
			.wrap_on_overflow in flags, 					//	wrap_on_overflow : bool,
			 											
			!(.allow_overflow in flags),					//	use_scissor : bool, 
			.hor_scrollbar in flags, 						//	enable_hor_scroll : bool,
			.ver_scrollbar in flags, 						//	enable_ver_scroll : bool,
			 													
			0, 												//	current_offset : [2]f32, //At what offset should new element be added
			nil, 											//	uid : Maybe(Unique_id),
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
	
	res, _ := sub_menu(s, sub, 0, &path, dest, user_id, dont_touch);
	
	return res;
}

sub_menu :: proc (s : ^State, using menu : Sub_menu, sub_prio : int, path : ^[dynamic]int, dest : Maybe(Dest) = nil, user_id := 0, dont_touch := #caller_location) -> (res : string, is_hovered : bool) {
	uid := make_uid(s, user_id, dont_touch, sub_prio);
	push_node(s, uid, false, false);
	defer pop_node(s);
	
	panel := get_current_panel(s);
	
	style := get_menu_style(s);
	
	width := s.font_width(s.user_data, style.text_size, label) + style.text_padding * 2;
	size := [2]f32{width, style.height};
	
	offset := do_offset(s, size);
	
	_dest : Dest;
	if d, ok := dest.?; ok {
		_dest = d;
	}
	else {
		//use parent panel behavior
		gstyle := get_style(s);
		
		if panel.append_hor {
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x, offset.y + gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x +  gstyle.out_padding, offset.y};
		}
	}
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_offset, _dest, size);
	
	if is_hover(s, placement) {
		is_hovered = true;
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
	}
	
	gui_state : Display_state = .cold;
	
	if is_hot_path(s, s.current_node) {
		gui_state = .hot;
	}
	
	append_command(s, Cmd_rect{placement, .menu_background, -1, gui_state});
	append_command(s, Cmd_rect{placement, .menu_border, style.border_thickness, gui_state});
	
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
		uid := make_uid(s, user_id, dont_touch, sub_prio + 1000);
		push_node(s, uid, true, true); 
		defer pop_node(s);
		
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
			//TODO
			scissor := s.scissor_stack[len(s.scissor_stack) - 1];
			if scissor.enable {
				//items_placement.x = math.clamp(items_placement.x, scissor.area.x, scissor.area.x + scissor.area.z);
				//items_placement.y = math.clamp(items_placement.y, scissor.area.y, scissor.area.y + scissor.area.w);
			}
		}
		
		//disable scissors to allow the options to spill into other places
		push_scissor(s, {0, false});
		defer pop_scissor(s);
		
		append_command(s, Cmd_rect{items_placement, .menu_item_background, -1, gui_state});
		append_command(s, Cmd_rect{items_placement, .menu_item_background_border, style.border_thickness, gui_state});
		
		push_panel(s, Panel{
			items_placement.xy,
			items_placement.zw, //the view size
			0,	//if offset of the view
			{}, //the size which there exists items/elements
			
			.left,
			.top,
			false,	//Should we append new elements vertically or horizontally
			
			false,
			true,
			true,
			false,
						
			0, //At what offset should new element be added
			nil,
		});
		defer pop_panel(s);
		
		if is_hover(s, items_placement) {
			try_set_hot(s, uid);
			is_hovered = true;
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
			
			clicked : bool
			
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
				}
			}
			
			switch o in opt {
				case string:
					
					gui_state : Display_state = .cold;
					
					if clicked {
						res = o;
					}
					
					append_command(s, Cmd_rect{sub_placement, .menu_item_front, -1, gui_state});
					append_command(s, Cmd_rect{sub_placement, .menu_item_front_border, style.border_thickness, gui_state});
					
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
					sub_res, hov := sub_menu(s, o, sub_prio + 1, path, Dest{.left, .bottom, sub_placement.x - items_placement.x, sub_placement.y - items_placement.y}, user_id, dont_touch);
					if sub_res != "" {
						res = sub_res;
					}
					if hov {
						is_hovered = true;
					}
			}
		}
	}
	
	return;
}



/*
sub_menu :: proc (s : ^State, using menu : Sub_menu, sub_prio : int, path : ^[dynamic]int, dest : Maybe(Dest) = nil, user_id := 0, dont_touch := #caller_location) -> (res : string, is_hovered : bool) {
	uid := make_uid(s, user_id, dont_touch, sub_prio);
	
	push_node(s, uid, true, false);
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
			_dest = {panel.hor_behavior, panel.ver_behavior, offset.x, gstyle.out_padding};
		}
		else {
			_dest = {panel.hor_behavior, panel.ver_behavior, gstyle.out_padding, offset.y};
		}
	}
	
	style := get_menu_style(s);
	
	width := s.font_width(s.user_data, style.text_size, label) + style.text_padding * 2;
	size := [2]f32{width, style.height};
	
	placement := place_in_parent(s, panel.position, panel.size, panel.scroll_offset, _dest, size);
	
	if is_hover(s, placement) {
		is_hovered = true;
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
	}
	
	gui_state : Display_state = .cold;
	
	if is_hot_path(s, s.current_node) {
		gui_state = .hot;
	}
	
	append_command(s, Cmd_rect{placement, .menu_background, -1, gui_state});
	append_command(s, Cmd_rect{placement, .menu_border, style.border_thickness, gui_state});
	
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
		uid := make_uid(s, user_id, dont_touch, sub_prio + 1000);
		push_node(s, uid, true, true); 
		defer pop_node(s);
		
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
			//TODO
			scissor := s.scissor_stack[len(s.scissor_stack) - 1];
			if scissor.enable {
				//items_placement.x = math.clamp(items_placement.x, scissor.area.x, scissor.area.x + scissor.area.z);
				//items_placement.y = math.clamp(items_placement.y, scissor.area.y, scissor.area.y + scissor.area.w);
			}
		}
		
		//disable scissors to allow the options to spill into other places
		push_scissor(s, {0, false});
		defer pop_scissor(s);
		
		append_command(s, Cmd_rect{items_placement, .menu_item_background, -1, gui_state});
		append_command(s, Cmd_rect{items_placement, .menu_item_background_border, style.border_thickness, gui_state});
		
		push_panel(s, Panel{
			items_placement.xy,
			items_placement.zw, //the view size
			0,	//if offset of the view
			{}, //the size which there exists items/elements
			
			.left,
			.top,
			false,	//Should we append new elements vertically or horizontally
			
			false,
			true,
			true,
			
			0, //At what offset should new element be added
			nil,
		});
		defer pop_panel(s);
		
		if is_hover(s, items_placement) {
			try_set_hot(s, uid);
			is_hovered = true;
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
			
			clicked : bool
			
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
				}
			}
			
			switch o in opt {
				case string:
					
					gui_state : Display_state = .cold;
					
					if clicked {
						res = o;
					}
					
					append_command(s, Cmd_rect{sub_placement, .menu_item_front, -1, gui_state});
					append_command(s, Cmd_rect{sub_placement, .menu_item_front_border, style.border_thickness, gui_state});
					
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
					sub_res, hov := sub_menu(s, o, sub_prio + 1, path, Dest{.left, .bottom, sub_placement.x - items_placement.x, sub_placement.y - items_placement.y}, user_id, dont_touch);
					if sub_res != "" {
						res = sub_res;
					}
					if hov {
						is_hovered = true;
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
*/