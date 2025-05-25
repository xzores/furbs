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

/*
This is a layout manager for an immitiate mode GUI, 
to init, do init, to destroy do destroy
to begin the frame do begin, this will push a panel which is the same as the screen size, allowing the user to place other elements(object) in positions relative to the "left, mid, right" or "up, mid, down".
to end the frame do end, this will return a list of simple geometry to draw, 

The library is made so that a window or panel does not need a size, if no size is passed then the window scales to fit the elements.

*/

///////////////////////////////////////////////////////////////////////////////////////

Rect_type :: enum {
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
	
}

Text_type :: enum {
	checkbox_text,
	title_text,
}

Cursor_type :: enum {
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

Display_state :: enum {
	cold, 
	hot,
	active,
}

///////////////////////////////////////////////////////////////////////////////////////

Cmd_scissor :: distinct [4]f32; //

Cmd_rect :: struct {
	rect : [4]f32,
	rect_type : Rect_type,
	line_thickness : f32, 	//optional for some rects, -1 if not used
	state : Display_state, 	//Used by some interactive elements
}

Cmd_swap_cursor :: struct {
	type : Cursor_type,
	user_id : int,
}

Cmd_text :: struct {
	position : [2]f32,
	val : string,
	size : f32, //in pixels
	rotation : f32, //rotation around the begining of the baseline 
	type : Text_type,
}

Command :: union {
	Cmd_scissor,
	Cmd_rect,
	Cmd_text,
	Cmd_swap_cursor,
}

Ordered_command :: struct {
	node : ^Node,
	ordering : u32,
	cmd : Command,
}

///////////////////////////////////////////////////////////////////////////////////////

Panel :: struct {
	//objs : map[runtime.Source_Code_Location]Object
	//transform : matrix[3,3]f32, //TO greneral
	//uid : Unique_id,
	
	position : [2]f32,
	size : [2]f32,
	
	hor_behavior : Hor_placement,
	ver_behavior : Ver_placement,
	append_hor : bool,	//Should we append new elements vertically or horizontally
	
	use_scissor : bool,
	
	current_offset : f32, //At what offset should new element be added
}

Checkbox_style :: struct {
	line_thickness : f32,
	text_padding : f32,
	text_size : f32,
	size : [2]f32,
}

Window_style :: struct {
	line_thickness : f32,
	top_bar_size : f32,
	title_padding : f32,
	title_size : f32,
	size : [2]f32,
}

Font :: distinct int;

Style :: struct {
	font : Font,		//Same font for all objects, may be swapped by the user with push_font and pop_font
	in_padding : f32, 	//padding between elements inside a panel
	out_padding : f32, 	//padding between elements and the containing panel
	checkbox : Checkbox_style,
	window : Window_style,
}

Key_state :: enum {
	up,
	pressed,
	down,
	released,
}

Unique_id :: struct {
	src : runtime.Source_Code_Location,
	call_cnt : int,
	sub_priotity : int, //For elements with many interactive components
	user_id : int,
}

Unique_look_up :: struct {
	src : runtime.Source_Code_Location,
	user_id : int,
}

Node :: struct {
	uid : Unique_id,
	sub_nodes : [dynamic]^Node,
	parent : ^Node,
}

State :: struct {
	
	//////////////////////// STATIC ////////////////////////
	user_data : rawptr,
	font_width : Text_width_f,
	font_height : Text_height_f,
	
	//////////////////////// DYNAMIC ////////////////////////
	//main_panel : Panel,
	style_stack : [dynamic]Style,
	panel_stack : [dynamic]Panel,
	scissor_stack : [dynamic]Cmd_scissor,
	commands : [dynamic]Ordered_command,
	
	hot : Unique_id,
	active : Unique_id,
	next_hot : Unique_id,
	next_active : Unique_id,
	to_promote : Unique_id, //Almost the same as to next_active, but this one has 
	
	root : ^Node,
	current_node : ^Node,
	
	upper_priorities : map[Unique_id]u16,
	lower_priotity_cnt : u16,
	highest_priority : u32,
	
	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	mouse_state : Key_state,
	
	current_cursor : Cursor_type,
	next_cursor : Cursor_type,
	
	originations : map[Unique_look_up]int, //resets every frame
	statefull_elements : map[Unique_id]Element_state,
	
	//z_val : i16,	
}

Window_state :: struct {
	placement : [4]f32,
	drag_by_mouse : Maybe([2]f32), //relavtive to mouse position 
	collapsed : bool,
}

Element_state :: union {
	Window_state,
}

Text_width_f :: #type proc (user_data : rawptr, size : f32, str: string) -> (width : f32);
Text_height_f :: #type proc (user_data : rawptr, size : f32) -> (acsender : f32, decender : f32);

init :: proc (user_data : rawptr, font_width : Text_width_f, font_height : Text_height_f) -> ^State {
	
	s := new(State);
	
	s^ = {
		//static
		user_data,
		font_width,
		font_height,
		//Dynamic
		make([dynamic]Style),
		make([dynamic]Panel),
		make([dynamic]Cmd_scissor),
		make([dynamic]Ordered_command),
		{},
		{},
		{},
		{},
		{},
		nil,
		nil,
		make(map[Unique_id]u16),
		0,
		0,
		{-1,-1},
		{0,0},
		.up,
		.normal,
		.normal,
		make(map[Unique_look_up]int),
		make(map[Unique_id]Element_state),
	}
	
	return s;
}

destroy :: proc(s : ^State) {
	
}

begin :: proc (s : ^State, screen_width : f32, screen_height : f32, user_id := 0, dont_touch := #caller_location) {
	
	uid := Unique_id {
		dont_touch,
		0,
		0,
		user_id,
	}
	
	push_element(s, uid);
	clear(&s.commands);
	
	s.hot = s.next_hot;
	s.active = s.next_active;
	if s.active != {} {
		s.hot = s.next_active;
	}
	s.next_hot = {};
	s.next_active = {};
	
	s.next_cursor = .normal;
	s.lower_priotity_cnt = 0;
	s.highest_priority = 0;
	
	panel := Panel{
		{0,0},
		{screen_width, screen_height},
		
		.left,
		.top,
		false,
		
		true,
		
		0
	};
	
	push_panel(s, panel);
}

end :: proc(s : ^State, do_sort := true, loc := #caller_location) -> []Ordered_command {
	assert(len(s.panel_stack) == 1, "did you call end to many times?", loc);
		
	if s.mouse_state == .pressed {
		s.mouse_state = .down;
	}
	if s.mouse_state == .released {
		s.mouse_state = .up;
	}
	
	for _, &i in s.originations {
		i = 0;
	}
	
	p := pop_panel(s);
	
	///after the hot and active stuff has been found
	
	if s.current_cursor != s.next_cursor {
		append_command(s, Cmd_swap_cursor{s.next_cursor, 0});
	}
	s.current_cursor = s.next_cursor;
	
	//Promote the to_promote element to the end of its parents sub_nodes
	node := s.root
	if s.to_promote != {} {
		
		handle_promote :: proc (s : ^State, node : ^Node) -> bool {
			
			if node.uid == s.to_promote {
				i, ok := slice.linear_search(node.parent.sub_nodes[:], node);
				assert(ok);
				
				ordered_remove(&node.parent.sub_nodes, i);
				append(&node.parent.sub_nodes, node);
				fmt.printf("premoted node : %v\n", node);
				
				return true; //found
			}
			
			for sub in node.sub_nodes {
				if handle_promote(s, sub) {
					return true;
				}
			}
			
			return false;
		}
		
		assert(handle_promote(s, node))
		s.to_promote = {};
	}
	
	//Do a breath first search on the nodes and assign an ever increasing priority to each one, in the order they are visted.
	nodes_q : queue.Queue(^Node);
	queue.init(&nodes_q);
	defer queue.destroy(&nodes_q);
	queue.append(&nodes_q, s.root);
	priority : u16 = 0;
	
	for queue.len(nodes_q) > 0 {
		node := queue.pop_front(&nodes_q);
		assert(node != nil, "node is nil");
		
		s.upper_priorities[node.uid] = priority;
		priority += 1;
		
		for sub in node.sub_nodes {
			queue.append(&nodes_q, sub)
		}
	}
	
	cnt : u32 = 0;
	
	for &e in s.commands[:] {
	
		upper := s.upper_priorities[e.node.uid];
		prio := cast(u32)(upper << 16) + cnt;
		
		e.ordering = prio;
		cnt += 1;
	}
	
	//fmt.printf("s.upper_priorities : %#v\n\n", s.upper_priorities);
	
	slice.sort_by(s.commands[:], proc(a, b : Ordered_command) -> bool {
		return a.ordering < b.ordering;
	});
	
	pop_element(s);
	s.current_node = nil;
	s.root = nil;
	
	return s.commands[:];
}

push_style :: proc (s : ^State, style : Style) {
	append(&s.style_stack, style);
}

pop_style :: proc (s : ^State) {
	pop(&s.style_stack);
}

set_mouse_pos :: proc (s : ^State, mouse_x, mouse_y, delta_x, delta_y : f32) {
	s.mouse_pos = {mouse_x, mouse_y};
	s.mouse_delta = {delta_x, delta_y};
}

mouse_event :: proc (s : ^State, pressed : bool) {
	if pressed {
		s.mouse_state = .pressed;
	}
	else {
		s.mouse_state = .released;
	}
}

push_scissor :: proc(s : ^State, scissor : Cmd_scissor) {
	scissor := scissor;
	
	//make sure the scissor stays inside the current one
	//scissor_stack is x, y, width, height
	if len(s.scissor_stack) >= 1 {
		r := s.scissor_stack[len(s.scissor_stack)-1];
		scissor.x = math.clamp(scissor.x, r.x, r.x + r.z);
		scissor.y = math.clamp(scissor.y, r.y, r.y + r.w);
		scissor.z = math.min(scissor.z, r.x + r.z - scissor.x);
		scissor.w = math.min(scissor.w, r.y + r.w - scissor.y);
	}
	
	append(&s.scissor_stack, scissor);
	append_command(s, scissor);
}

pop_scissor :: proc(s : ^State) {
	pop(&s.scissor_stack);
	if len(s.scissor_stack) >= 1 {
		r := s.scissor_stack[len(s.scissor_stack)-1];
		append_command(s, r);
	}
}

push_panel :: proc (s : ^State, panel : Panel) {
	if panel.use_scissor {
		r := Cmd_scissor{panel.position.x, panel.position.y, panel.size.x, panel.size.y};
		append(&s.scissor_stack, r);
		append_command(s, r);
	}
	
	append(&s.panel_stack, panel)
}

pop_panel :: proc (s : ^State, loc := #caller_location) -> Panel {
	panel := pop(&s.panel_stack, loc);
	
	if panel.use_scissor {
		pop_scissor(s);
	}
	
	return panel;
}

//////////////////////////////////////// Checkbox ////////////////////////////////////////

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

checkbox :: proc (s : ^State, value : ^bool, dest : Maybe(Dest) = nil, label := "", user_id := 0, dont_touch := #caller_location) -> bool {
	
	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	push_element(s, uid)
	defer pop_element(s);
	
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
		//TODO draw hover stuff
		try_set_hot(s, uid);
		if s.mouse_state == .pressed {
			try_set_active(s, uid);
		}
		if s.active == uid && s.mouse_state == .down {
			try_set_active(s, uid);
		}
		if s.active == uid && s.mouse_state == .released {
			value^ = !value^;
		}
	}
	
	checkbox_state : Display_state = .cold;
	
	if s.hot == uid {
		checkbox_state = .hot;
		set_mouse_cursor(s, .clickable);
	}
	if s.active == uid {
		checkbox_state = .active;
		set_mouse_cursor(s, .clickable);
	}
	
	append_command(s, Cmd_rect{placement, .checkbox_background, -1, checkbox_state}); //The background
	append_command(s, Cmd_rect{placement, .checkbox_border, style.line_thickness, checkbox_state}); //The background	
	
	if value^ {
		act_placement := place_in_parent(s, placement.xy, placement.zw, Dest{.mid, .mid, 0, 0}, size - style.line_thickness*6);
		append_command(s, Cmd_rect{act_placement, .checkbox_foreground, -1, checkbox_state}); //The background
	}
	
	//TODO also if a destination is not parse then figure it out self.
	if label != "" {
		text_size := get_current_size(s);
		padding := get_in_padding(s);
		
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

/*
TODO do the thing where you make a priority stack, and then add 2 and progate the top-1 back to root.
This makes it so that thing are in the right order, get_z will then work and the thing are drawn in the correct order.
*/ 

//TODO min_size
begin_window :: proc (s : ^State, size : [2]f32, flags : Window_falgs, dest : Dest, title := "", center_title := false, top_bar_loc := Top_bar_location.top, user_id := 0, dont_touch := #caller_location) -> bool {
	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	push_element(s, uid);
	
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
	
	top_uid := Unique_id {
		dont_touch,
		call_cnt,
		1,
		user_id,
	}
	
	if top_bar_occupie != {} {
		top_bar_state : Display_state = .cold;
		
		if s.hot == top_uid {
			top_bar_state = .hot;
		}
		if s.active == top_uid {
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
		if s.mouse_state == .down && s.active == top_uid {
			try_set_active(s, top_uid);
		}
	}
	
	if s.hot == top_uid {
		set_mouse_cursor(s, .clickable);
	}
	
	if s.active == top_uid {
		w_state.drag_by_mouse = top_bar_placement.xy - s.mouse_pos;
		set_mouse_cursor(s, .draging);
	}
	else {
		w_state.drag_by_mouse = nil;
	}
	
	if drag, ok := w_state.drag_by_mouse.([2]f32); ok {
		w_state.placement.xy += s.mouse_delta;
	}
	
	if .collapsable in flags {
		collapse_dest : Dest;
		switch top_bar_loc {
			case .top, .bottom:
				collapse_dest = {.right, .mid, gstyle.out_padding / 2, 0};
			case .left, .right:
				collapse_dest = {.mid, .top, 0, gstyle.out_padding / 2};
		}	
		collapse_placement := place_in_parent(s, top_bar_placement.xy, top_bar_placement.zw, collapse_dest, [2]f32{style.top_bar_size, style.top_bar_size} - gstyle.out_padding);
		
		collapse_uid := Unique_id {
			dont_touch,
			call_cnt,
			2,
			user_id,
		}
		
		collapse_button_state : Display_state = .cold;
		
		if s.hot == collapse_uid {
			collapse_button_state = .hot;
		}
		if s.active == collapse_uid {
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
			else if s.mouse_state == .down && s.active == collapse_uid {
				try_set_active(s, collapse_uid);
			}
			else if s.mouse_state == .released  && s.active == collapse_uid {
				w_state.collapsed = !w_state.collapsed; 
			}
		}
		
		if s.hot == collapse_uid {
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
		title_scissor : Cmd_scissor = auto_cast top_bar_placement;
		title_scissor.zw -= top_bar_occupie.yx;
		push_scissor(s, title_scissor);
		append_command(s, Cmd_text{title_rect.xy, strings.clone(title, context.temp_allocator), style.title_size, rotation, .title_text});
		pop_scissor(s);
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
			
			hor_behavior,
			ver_behavior,
			append_hor,	//Should we append new elements vertically or horizontally
			
			!(.allow_overflow in flags),
			
			0, //At what offset should new element be added
		});
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
			if s.mouse_state == .down && s.active == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if s.hot == drag_uid {
				set_mouse_cursor(s, .scale_verical);
			}
			
			if s.active == drag_uid {
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
			if s.mouse_state == .down && s.active == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if s.hot == drag_uid {
				set_mouse_cursor(s, .scale_horizontal);
			}
			
			if s.active == drag_uid {
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
			if s.mouse_state == .down && s.active == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if s.hot == drag_uid {
				set_mouse_cursor(s, .scale_horizontal);
			}
			
			if s.active == drag_uid {
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
			if s.mouse_state == .down && s.active == drag_uid {
				try_set_active(s, drag_uid);
			}
			
			if s.hot == drag_uid {
				set_mouse_cursor(s, .scale_verical);
			}
			
			if s.active == drag_uid {
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
	e := pop_element(s);
	
	w_state : Window_state;
	
	{
		_w := get_state(s, e)
		if __w, ok := _w.(Window_state); ok {
			w_state = __w;
		}
		else {
			panic("Not a window");
		}
	}
	
	if !w_state.collapsed {
		pop_panel(s);
	}
}

expand_window :: proc () {
	
}

collapse_window :: proc () {
	
}

bring_window_to_front :: proc () {
	
}

bring_window_to_back :: proc () {
	
}

//////////////////////////////////////// PRIVATE ////////////////////////////////////////

append_command :: proc (s : ^State, cmd_type : Command) {
	
	append(&s.commands, Ordered_command{s.current_node, 0, cmd_type});
}

set_mouse_cursor :: proc (s : ^State, cursor_type : Cursor_type) {
	s.next_cursor = cursor_type;
}

push_element :: proc (s : ^State, uid : Unique_id) {
	
	//walk up the stack, and increase their uid if this has a higher one
	new := new_node(uid, s.current_node);
	if s.current_node != nil {
		// Insert `new` into sub_nodes in sorted order by s.upper_priorities[uid]
		inserted := false;
		for other_node, i in s.current_node.sub_nodes {
			if s.upper_priorities[uid] < s.upper_priorities[other_node.uid] {
				append(&s.current_node.sub_nodes, nil);
				for j := len(s.current_node.sub_nodes)-1; j > i; j -= 1 {
					s.current_node.sub_nodes[j] = s.current_node.sub_nodes[j-1];
				}
				s.current_node.sub_nodes[i] = new;
				inserted = true;
				break;
			}
			panic("TODO this does not work, we need to verify that the uid is correct and is inserted sorted");
		}
		if !inserted {
			append(&s.current_node.sub_nodes, new);
		}
	}
	else {
		s.root = new;
	}
	s.current_node = new;
}

pop_element :: proc (s : ^State) -> Unique_id {
	
	popped := s.current_node;
	s.current_node = s.current_node.parent;
	
	return popped.uid;
}

try_set_hot :: proc (s : ^State, uid : Unique_id) {
	//if you where active last frame always win the hot
	//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
	
	cur_prio := next_priority(s);
	
	if s.active == uid {
		s.next_hot = uid;
		s.highest_priority = max(u32);
		return;
	}
	
	if s.highest_priority > cur_prio {
		return; //We do not grant this the hot.
	}
	
	s.next_hot = uid;
	s.highest_priority = cur_prio;
}

try_set_active :: proc (s : ^State, uid : Unique_id) {
	//if you where active last frame always win the active
	//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
	
	cur_prio := next_priority(s);
	
	//If it wins, increase its priority
	if s.active == uid {
		s.next_active = uid;
		s.to_promote = s.current_node.uid;
		s.highest_priority = max(u32);
		return;
	}
	
	if s.highest_priority > cur_prio {
		return; //We do not grant this the hot.
	}
	
	s.next_active = uid;
	s.to_promote = s.current_node.uid;
	s.highest_priority = cur_prio;
	
	fmt.printf("set to active : %v\n", uid);
}

next_priority :: proc (s : ^State) -> u32 {
	
	upper_bits := s.upper_priorities[s.current_node.uid];
	s.lower_priotity_cnt += 1;
	priority := cast(u32)(upper_bits << 16) + cast(u32)s.lower_priotity_cnt;
	
	return priority;
}

get_style :: proc (s : ^State) -> Style {
	return s.style_stack[len(s.style_stack)-1];
}

@(require_results)
get_checkbox_style :: proc (s : ^State) -> Checkbox_style {
 	return get_style(s).checkbox;
}

@(require_results)
get_window_style :: proc (s : ^State) -> Window_style {
 	return get_style(s).window;
}

@(require_results)
get_in_padding :: proc (s : ^State) -> f32 {
	return get_style(s).in_padding;
}

@(require_results)
get_out_padding :: proc (s : ^State) -> f32 {
	return get_style(s).out_padding;
}

@(require_results)
get_current_size :: proc (s : ^State) -> f32 {
	return 0.05;
}

@(require_results)
//only valid for a until end of function
get_current_panel :: proc (s : ^State) -> Panel {	
	return s.panel_stack[len(s.panel_stack)-1];
}

get_state :: proc (s : ^State, uid : Unique_id) -> Element_state {
	return s.statefull_elements[uid];
}

save_state :: proc (s : ^State, uid : Unique_id, new : Element_state) {
	s.statefull_elements[uid] = new;
}

increase_offset :: proc (s : ^State, offset : [2]f32) {
	p := &s.panel_stack[len(s.panel_stack)-1]
	
	if p.append_hor {
		p.current_offset += offset.x;
	}
	else {
		p.current_offset += offset.y;
	}
	
	p.current_offset += get_style(s).in_padding;
}

@(require_results)
place_in_parent :: proc (s : ^State, parent_pos : [2]f32, parent_size : [2]f32, dest : Dest, size : [2]f32) -> [4]f32 {
	
	pos : [2]f32;
	
	switch dest.hor {
		case .left:
			pos.x = dest.offset_x;
		case .mid:
			pos.x = parent_size.x / 2 + dest.offset_x - size.x / 2;
		case .right:
			pos.x = parent_size.x - dest.offset_x - size.x;
	}
	
	switch dest.ver {
		case .bottom:
			pos.y = dest.offset_y;
		case .mid:
			pos.y = parent_size.y / 2 + dest.offset_y - size.y / 2;
		case .top:
			pos.y = parent_size.y - dest.offset_y - size.y;
	}
	
	pos += parent_pos;
	
	return {pos.x, pos.y, size.x, size.y};
}

@(private, require_results)
new_node :: proc (uid : Unique_id, parent : ^Node) -> ^Node {
	
	n := new(Node)
	
	n^ = {
		uid,
		make([dynamic]^Node),
		parent,
	};
	
	return n;
}

@private
destroy_node :: proc (node : ^Node) {
	
	for n in node.sub_nodes {
		destroy_node(n);
	}
}



