package furbs_layman;

import "base:runtime"

import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:slice"

import "core:fmt"

import "../utils"

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
	window_collapse_button,
}

Text_type :: enum {
	checkbox_text,
	title_text,
}

Cursor_type :: enum {
	normal,
	
	clickable,
	draging, //when draging like a window
	
	text_edit,
	
	horizontal_scale,
	verical_scale,
	omni_scale,
	
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
	type : Text_type,
}

Command :: union {
	Cmd_scissor,
	Cmd_rect,
	Cmd_text,
	Cmd_swap_cursor,
}

Ordered_command :: struct {
	ordering : u32,
	cmd : Command,
}

///////////////////////////////////////////////////////////////////////////////////////

Panel :: struct {
	//objs : map[runtime.Source_Code_Location]Object
	//transform : matrix[3,3]f32, //TO greneral
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
	text_padding : f32,
	text_size : f32,
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
	netx_hot : Unique_id,
	netx_active : Unique_id,
	
	interaction_id : u16, //each time a user inteacts with an elemnt, increase this by one and assing the element and all parent contrainers to haave this interaction id.
	lowest_interaction_id : u16, // each frame search for the lowest interaction id and subtract from all the others, just to make sure it does not get out of hand.
	element_interaction_id : map[Unique_id]u16, //remember the interaction id between frames
	orderint_cnt : u16, //this intrements every time something is drawn, resets every frame. It is basicly the lower half of the z-coordiantes, where interaction_id is the most significient bits
	
	//stateful_objs : map[]Object,
	
	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	mouse_state : Key_state,
		
	originations : map[Unique_look_up]int, //resets every frame
	statefull_elements : map[Unique_id]Element_state,
	
	//z_val : i16,	
}

Window_state :: struct {
	pos : [2]f32,
	size : [2]f32,
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
		0,
		0,
		make(map[Unique_id]u16),
		0,
		{-1,-1},
		{0,0},
		.up,
		make(map[Unique_look_up]int),
		make(map[Unique_id]Element_state),
	}
	
	return s;
}

destroy :: proc(s : ^State) {
	
}

begin :: proc (s : ^State, screen_width : f32, screen_height : f32) {
	
	clear(&s.commands);
	
	panel := Panel{
		{0,0},
		{screen_width, screen_height},
		
		.left,
		.top,
		false,
		
		false,
		
		0
	};
	
	s.orderint_cnt = 0;
	s.lowest_interaction_id = max(u16);
	
	push_panel(s, panel)
}

end :: proc(s : ^State, do_sort := true) -> []Ordered_command {
	
	if s.mouse_state == .pressed {
		s.mouse_state = .down;
	}
	if s.mouse_state == .released {
		s.mouse_state = .up;
	}
	
	for _, &i in s.originations {
		i = 0;
	}
	
	pop_panel(s);
	
	///after the hot and active stuff has been found
	
	if s.lowest_interaction_id != max(u16) {
		for src, &id in s.element_interaction_id {
			id -= s.lowest_interaction_id;
		}
	}
	
	slice.sort_by(s.commands[:], proc(a, b : Ordered_command) -> bool {
		return a.ordering < b.ordering;
	});
	
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

push_panel :: proc (s : ^State, panel : Panel) {
	if panel.use_scissor {
		r := Cmd_scissor{panel.position.x, panel.position.y, panel.size.x, panel.size.y};
		append(&s.scissor_stack, r);
		append_command(s, r);
	}

	append(&s.panel_stack, panel)
}

pop_panel :: proc (s : ^State, loc := #caller_location) {
	panel := pop(&s.panel_stack, loc);
	
	if panel.use_scissor {
		r := pop(&s.scissor_stack);
		append_command(s, r);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////

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

checkbox :: proc (s : ^State, value : ^bool, dest : Maybe(Dest) = nil, label := "") -> bool {
	
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
		
		if s.mouse_state == .released {
			value^ = !value^;
		}
	}
	
	checkbox_state : Display_state = .cold;
	
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
		append_command(s, Cmd_text{text_placement, strings.clone(label, context.temp_allocator), style.text_size, .checkbox_text});
		total_size += {s.font_width(s.user_data, text_size, label), 0};
	}
	
	if d, ok := dest.?; !ok {
		increase_offset(s, total_size);
	}	
	
	return value^;
}

@private
Window_falgs_enum :: enum {
	
	//how it looks
	no_border,
	no_background,
	no_top_bar,
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

//TODO min_size
begin_window :: proc (s : ^State, size : [2]f32, flags : Window_falgs, dest : Dest, title := "", top_bar_loc := Top_bar_location.top, user_id := 0, dont_touch := #caller_location) {
	
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		0,
		user_id,
	}
	
	gstyle := get_style(s);
	style := get_window_style(s);
	
	top_bar_occupie : [2]f32;
	bar_cause_offset : [2]f32;
	switch top_bar_loc {
		case .top:
			top_bar_occupie = {0, style.text_size};
			bar_cause_offset = {0,0};
		case .bottom:
			top_bar_occupie = {0, style.text_size};
			bar_cause_offset = {0, style.text_size};
		case .right:
			top_bar_occupie = {style.text_size, 0};
			bar_cause_offset = {0, 0};
		case .left:
			top_bar_occupie = {style.text_size, 0};
			bar_cause_offset = {style.text_size,0};
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
			
			w_state = {
				[2]f32{dest.offset_x, dest.offset_y} + bar_cause_offset,
				size - top_bar_occupie,
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
	
	dest := dest;
	dest.offset_x = w_state.pos.x;
	dest.offset_y = w_state.pos.y;
	placement := place_in_parent(s, parent.position, parent.size, dest, w_state.size + top_bar_occupie);
	placement.zw -= top_bar_occupie;
	
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
	if !(.no_background in flags) {
		append_command(s, Cmd_rect{placement, .window_background, -1, .cold});
	}
	if !(.no_border in flags) {
		append_command(s, Cmd_rect{placement, .window_border, style.line_thickness, .cold}); 
	}
	
	if .movable in flags {
		if s.mouse_state == .released || s.mouse_state == .up {
			set_cold(s, top_uid);
		}
		if utils.collision_point_rect(s.mouse_pos, top_bar_placement) {
			try_set_hot(s, top_uid);
			if s.mouse_state == .pressed {
				try_set_active(s, top_uid);
			}
		}
	}
	
	if s.active == uid {
		w_state.drag_by_mouse = top_bar_placement.xy - s.mouse_pos;
	}
	else {
		w_state.drag_by_mouse = nil;
	}
	
	if drag, ok := w_state.drag_by_mouse.([2]f32); ok {
		w_state.pos += s.mouse_delta;
	}
	
	if .collapsable in flags {
		collapse_placement := place_in_parent(s, top_bar_placement.xy, top_bar_placement.zw, {.right, .mid, gstyle.out_padding / 2, 0}, [2]f32{style.text_size, style.text_size} - gstyle.out_padding);
		
		collapse_uid := Unique_id {
			dont_touch,
			call_cnt,
			2,
			user_id,
		}
		
		collapse_button_state : Display_state = .cold;
		
		if s.hot == uid {
			collapse_button_state = .hot;
		}
		if s.active == uid {
			collapse_button_state = .active;
		}
		
		append_command(s, Cmd_rect{collapse_placement, .window_collapse_button, -1, collapse_button_state});
		
		if s.mouse_state == .released || s.mouse_state == .up {
			set_cold(s, collapse_uid);
		}
		if utils.collision_point_rect(s.mouse_pos, collapse_placement) {
			try_set_hot(s, collapse_uid);
			if s.mouse_state == .pressed {
				try_set_active(s, collapse_uid);
			}
		}
	}
	
	push_panel(s, Panel {
		placement.xy,
		placement.zw,
		
		hor_behavior,
		ver_behavior,
		append_hor,	//Should we append new elements vertically or horizontally
		
		(.allow_overflow in flags),
		
		0, //At what offset should new element be added
	});
	
	save_state(s, uid, w_state);
	
}

end_window :: proc (s : ^State) {
	
	pop_panel(s);
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
	append(&s.commands, Ordered_command{get_z(s), cmd_type});
}

get_z :: proc (s : ^State) -> u32 {
	res : u32;
	
	s.orderint_cnt += 1;
	
	lower : u32 = cast(u32)s.orderint_cnt;
	upper : u32 = cast(u32)s.interaction_id;
	
	res = (upper << 16) | lower;
	
	return res;
} 

//Call to set to cold, some elements does not reset to cold even after letting go of the mouse, like an inputfield, this is therefor explicit
set_cold  :: proc (s : ^State, uid : Unique_id) {
	
}

try_set_hot :: proc (s : ^State, uid : Unique_id) {
	//if you where active last frame always win the hot
	
	//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
	
}

try_set_active :: proc (s : ^State, uid : Unique_id) {
	//if you where active last frame always win the active
	//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
		
	//If it wins, increase its priority
	
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




