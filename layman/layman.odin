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

Text_type :: enum {
	button_text,
	checkbox_text,
	title_text,
	menu_item,
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

Cmd_scissor :: struct{
	area : [4]f32,
	enable : bool,
}; //

Cmd_rect :: struct {
	rect : [4]f32,
	rect_type : Rect_type,
	border_thickness : f32, 	//optional for some rects, -1 if not used
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

///////////////////////////////////////////////////////////////////////////////////////

Panel :: struct {
	//objs : map[runtime.Source_Code_Location]Object
	//transform : matrix[3,3]f32, //TO greneral
	//uid : Unique_id,
	
	position : [2]f32, //in relation to the parent panel
	size : [2]f32, //the view size
	scroll_ofset : [2]f32,	//if offset of the view
	virtual_size : [2]f32, //the size which there exists items/elements
	
	hor_behavior : Hor_placement,
	ver_behavior : Ver_placement,
	append_hor : bool,	//Should we append new elements vertically or horizontally
	
	use_scissor : bool, 
	
	current_offset : f32, //At what offset should new element be added
}

Button_style :: struct {
	border_thickness : f32,
	
	text_padding : f32,
	text_size : f32,
	text_shrink_to_fit : bool,
	text_hor : Hor_placement,
	text_ver : Ver_placement,
	
	size : [2]f32,
}

Checkbox_style :: struct {
	border_thickness : f32,
	text_padding : f32,
	text_size : f32,
	size : [2]f32,
}

Window_style :: struct {
	border_thickness : f32,
	top_bar_size : f32,
	title_padding : f32,
	title_size : f32,
	size : [2]f32,
}

Scroll_style :: struct {
	bar_bg_thickness : f32,
	bar_front_thickness : f32,
	padding : [2]f32,
	length_padding : f32,
}

Menu_style :: struct {
	border_thickness : f32,
	
	text_padding : f32,
	text_size : f32,
	text_shrink_to_fit : bool,
	text_hor : Hor_placement,
	text_ver : Ver_placement,
	
	height : f32,
}

Split_panel_style :: struct {
	border_thickness : f32,
	splitter_thickness : f32,
}

Font :: distinct int;

Style :: struct {
	font : Font,		//Same font for all objects, may be swapped by the user with push_font and pop_font
	in_padding : f32, 	//padding between elements inside a panel
	out_padding : f32, 	//padding between elements and the containing panel
	
	button : Button_style,
	checkbox : Checkbox_style,
	window : Window_style,
	scroll : Scroll_style,
	menu : Menu_style,
	split_panel : Split_panel_style,
}

Key_state :: enum {
	up,
	pressed,
	down,
	released,
}

Unique_id :: struct {
	src : runtime.Source_Code_Location,
	special_number : int, //user_id  or callcount
	sub_priotity : int, //For elements with many interactive components
}

Unique_look_up :: struct {
	src : runtime.Source_Code_Location,
	user_id : int,
}

Insert_subnode :: struct {};

Sub_command :: union {
	Insert_subnode, //sortable reference
	^Node,	//inlined, unsortable
	Command,
}

Node :: struct {
	uid : Unique_id,
	sub_nodes : [dynamic]^Node,
	sub_commands : [dynamic]Sub_command,
	parent : ^Node,
	
	refound : bool,
}

Split_panel :: struct {
	uid : Unique_id,
	dir : Split_dir,
	next_panel : int,
	panels : [dynamic]Panel,
}

State :: struct {
	
	//////////////////////// STATIC ////////////////////////
	user_data : rawptr,
	font_width : Text_width_f,
	font_height : Text_height_f,
	
	//////////////////////// DYNAMIC ////////////////////////
	style_stack : [dynamic]Style,
	panel_stack : [dynamic]Panel,
	scissor_stack : [dynamic]Cmd_scissor,
	split_panel_stack : [dynamic]Split_panel,
	
	hot : Unique_id,
	active : Unique_id,
	next_hot : Unique_id,
	next_active : Unique_id,
	to_promote : ^Node, //Almost the same as to next_active, but this one has 
	
	highest_priority : u32,
	prio_cnt : u32,
	
	root : ^Node,
	current_node : ^Node,
	uid_to_node : map[Unique_id]^Node,
	priorities : map[^Node]u16, //last priorties used to control which one is next_active and next_hot
	
	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,
	is_input_trackpad : bool,
	mouse_state : Key_state,
	
	current_cursor : Cursor_type,
	next_cursor : Cursor_type,
	
	originations : map[Unique_look_up]int, //resets every frame
	statefull_elements : map[Unique_id]Element_state,
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
		make([dynamic]Split_panel),
		{},
		{},
		{},
		{},
		{},
		0,
		0,
		nil,
		nil,
		make(map[Unique_id]^Node),
		make(map[^Node]u16),
		{-1,-1},
		{0,0},
		{},
		false,
		.up,
		.normal,
		.normal,
		make(map[Unique_look_up]int),
		make(map[Unique_id]Element_state),
	}
	
	return s;
}

destroy :: proc(s : ^State) {
	
	for uid, node in s.uid_to_node {
		free(node);
		delete(node.sub_nodes);
		delete(node.sub_commands);
	}
	
	delete(s.style_stack);
	delete(s.panel_stack);
	delete(s.scissor_stack);
	delete(s.uid_to_node);
	delete(s.priorities);
	delete(s.originations);
	delete(s.statefull_elements); 
	
	free(s);
}

begin :: proc (s : ^State, screen_width : f32, screen_height : f32, user_id := 0, dont_touch := #caller_location) {
	uid := Unique_id {
		dont_touch,
		0,
		0, //For elements with many interactive components
	}
	
	push_node(s, uid, false, dont_touch);
	
	panel := Panel{
		{0,0},
		{screen_width, screen_height},
		{0,0},
		{screen_width, screen_height},
		
		.left,
		.top,
		false,
		
		true,
		
		0,
	};
	
	push_panel(s, panel);
	
	s.root = s.current_node;
	
	for uid, node in s.uid_to_node {
		node.refound = false;
		clear(&node.sub_commands);
	}
	s.root.refound = true;
	
	s.hot = s.next_hot;
	s.active = s.next_active;
	if s.active != {} {
		s.hot = s.next_active;
	}
	s.next_hot = {};
	s.next_active = {};
	
	s.highest_priority = 0;
	s.prio_cnt = 0;
	
	s.next_cursor = .normal;
	
}

end :: proc(s : ^State, do_sort := true, loc := #caller_location) -> []Command {
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
	
	///after the hot and active stuff has been found
	if s.current_cursor != s.next_cursor {
		append_command(s, Cmd_swap_cursor{s.next_cursor, 0});
	}
	s.current_cursor = s.next_cursor;
	
	p := pop_panel(s);
	
	//Promote the to_promote element to the end of its parents sub_nodes
	if s.to_promote != {} {
		
		promote :: proc (s : ^State, to_promote : ^Node) {
			if to_promote.parent == nil {
				return;
			}
			
			i, found := slice.linear_search(to_promote.parent.sub_nodes[:], to_promote);
			if found {
				fmt.assertf(found, "the subnode to promote was not found subnode : %p, parent : %#v", to_promote, to_promote.parent);
				ordered_remove(&to_promote.parent.sub_nodes, i);
				append(&to_promote.parent.sub_nodes, to_promote);
			}
			
			promote(s, to_promote.parent);
			
		}
		
		promote(s, s.to_promote);
		
		s.to_promote = {};
	}
	
	//Recalculate all the priorities
	clear(&s.priorities);
	
	// Do a depth first search on the nodes and assign an ever increasing priority to each one, in the order they are visited.
	commands := make([dynamic]Command, context.temp_allocator);
	priority : u16;
	
	depth_first_assign_priority :: proc(s : ^State, node: ^Node, commands : ^[dynamic]Command, priority : ^u16) {
		assert(node != nil, "node is nil");
		
		s.priorities[node] = priority^;
		priority^ += 1;
		
		current_sub_node : int = 0;
		
		if node.refound == true {
			
			for cmd in node.sub_commands {
				switch val in cmd {
					case Command: {
						append(commands, val);
					}
					case ^Node: {
						depth_first_assign_priority(s, val, commands, priority);
					}
					case Insert_subnode:{
						sub_node : ^Node;
						
						for i := current_sub_node; i < len(node.sub_nodes); i+=1 {
							if node.sub_nodes[i].refound {
								sub_node = node.sub_nodes[i];
								current_sub_node = i + 1;
								break;
							}
						}
						fmt.assertf(sub_node != nil, "Failed to find sub_node from %v in %v", current_sub_node, node.sub_nodes);
						
						depth_first_assign_priority(s, sub_node, commands, priority);
					}
				}
			}
		}
	}
	
	depth_first_assign_priority(s, s.root, &commands, &priority);
	
	pop_node(s);
	
	s.root = nil;
	
	assert(s.current_node == nil, "not all nodes where popped");
	
	return commands[:];
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

set_scroll :: proc (s : ^State, scroll_x, scroll_y : f32, is_trackpad : bool) {
	s.scroll_delta = {scroll_x, scroll_y}
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
		r := s.scissor_stack[len(s.scissor_stack)-1].area;
		scissor.area.x = math.clamp(scissor.area.x, r.x, r.x + r.z);
		scissor.area.y = math.clamp(scissor.area.y, r.y, r.y + r.w);
		scissor.area.z = math.min(scissor.area.z, r.x + r.z - scissor.area.x);
		scissor.area.w = math.min(scissor.area.w, r.y + r.w - scissor.area.y);
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

push_panel :: proc (s : ^State, panel : Panel, loc := #caller_location) {
	
	append(&s.panel_stack, panel);
	
	increase_offset(s, get_style(s).out_padding);
	
	if panel.use_scissor {
		r := Cmd_scissor{{panel.position.x, panel.position.y, panel.size.x, panel.size.y}, panel.use_scissor};
		push_scissor(s, r);
	}
}

pop_panel :: proc (s : ^State, loc := #caller_location) -> Panel {
	
	panel := s.panel_stack[len(s.panel_stack) - 1]
	
	if panel.use_scissor {
		pop_scissor(s);
	}
	pop(&s.panel_stack, loc);
		
	return panel;
}

//////////////////////////////////////// PRIVATE ////////////////////////////////////////

append_command :: proc (s : ^State, cmd : Command) {
	append(&s.current_node.sub_commands, cmd);
}

set_mouse_cursor :: proc (s : ^State, cursor_type : Cursor_type) {
	s.next_cursor = cursor_type;
}

push_node :: proc (s : ^State, uid : Unique_id, sortable : bool, loc := #caller_location) {
	
	assert(uid != {});
	
	node : ^Node;
	
	if uid in s.uid_to_node {
		//Mark node as being found this frame, (so it has been decalred same as last frame)
		node = s.uid_to_node[uid];
		fmt.assertf(node != s.current_node, "You are pushing the same node twice %v", uid, loc = loc);
	}
	else {
		node = new(Node);
		node^ = {
			uid,
			make([dynamic]^Node),
			make([dynamic]Sub_command),
			nil,
			true,
		};
		s.uid_to_node[uid] = node;
	}
	
	if s.current_node == nil {
		s.root = node;
	}
	else {
		i, found := slice.linear_search(s.current_node.sub_nodes[:], node);
		if sortable {
			if !found {
				append(&s.current_node.sub_nodes, node);
			}
			append(&s.current_node.sub_commands, Insert_subnode{}); // this should happen every frame as the sub_commands gets cleared.
		}
		else {
			append(&s.current_node.sub_commands, node); // this should happen every frame as the sub_commands gets cleared.
		}
	}
	
	node.refound = true;
	node.parent = s.current_node;
	s.current_node = node;
}

pop_node :: proc (s : ^State) -> Unique_id {
	
	popped := s.current_node;
	s.current_node = popped.parent;
	
	return popped.uid;
}

try_set_hot :: proc (s : ^State, uid : Unique_id) {
	//if you where active last frame always win the hot
	//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
	
	cur_prio := get_next_priority(s);
	
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

//tries to set the currently pushed element to active
try_set_active :: proc (s : ^State, uid : Unique_id) {
	//if you where active last frame always win the active
	//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
	
	cur_prio := get_next_priority(s);
	
	//If it wins, increase its priority
	if s.active == uid {
		s.next_active = uid;
		s.to_promote = s.current_node;
		s.highest_priority = max(u32);
		return;
	}
	
	if s.highest_priority > cur_prio {
		return; //We do not grant this the hot.
	}
	
	s.next_active = uid;
	s.to_promote = s.current_node;
	s.highest_priority = cur_prio;
}

get_next_priority :: proc (s : ^State) -> u32 {
	
	cur_prio : u16 = 0;
	if s.current_node in s.priorities {
		cur_prio = s.priorities[s.current_node];	
	}
	s.prio_cnt += 1;
	
	return (cast(u32)cur_prio << 16) + s.prio_cnt;
}

get_style :: proc (s : ^State) -> Style {
	return s.style_stack[len(s.style_stack)-1];
}

@(require_results)
get_scroll_style :: proc (s : ^State) -> Scroll_style {
 	return get_style(s).scroll;
}

@(require_results)
get_button_style :: proc (s : ^State) -> Button_style {
 	return get_style(s).button;
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
get_menu_style :: proc (s : ^State) -> Menu_style {
 	return get_style(s).menu;
}

@(require_results)
get_split_panel_style :: proc (s : ^State) -> Split_panel_style {
 	return get_style(s).split_panel;
}

current_hot :: proc (s : ^State) -> Unique_id {
	return s.hot;
}

current_active :: proc (s : ^State) -> Unique_id {
	return s.active;
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
	
	padding : f32; 
	
	if p.current_offset != 0 {
		padding = get_style(s).in_padding;
	}
	
	if p.append_hor {
		p.current_offset += offset.x + padding;
		p.virtual_size.x = p.current_offset - padding + get_style(s).out_padding;
		p.virtual_size.y = math.max(p.virtual_size.y, offset.y + 2 * get_style(s).out_padding);
	}
	else {
		p.current_offset += offset.y + padding;
		p.virtual_size.x = math.max(p.virtual_size.x, offset.x + 2 * get_style(s).out_padding);
		p.virtual_size.y = p.current_offset - padding + get_style(s).out_padding;;
	}
}

@(require_results)
place_in_parent :: proc (s : ^State, parent_pos : [2]f32, parent_size : [2]f32, scroll_offset : [2]f32, dest : Dest, size : [2]f32) -> [4]f32 {
	
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
	
	pos += parent_pos + scroll_offset;
	
	return {pos.x, pos.y, size.x, size.y};
}

is_hover :: proc (s : ^State, placement : [4]f32) -> bool {
	
	if len(s.scissor_stack) != 0 {
		cur_scissor := s.scissor_stack[len(s.scissor_stack) - 1];
		
		if cur_scissor.enable {
			if !utils.collision_point_rect(s.mouse_pos, cur_scissor.area) {
				return false;
			}
		}
	}
	
	return utils.collision_point_rect(s.mouse_pos, placement);
}

//TODO, we want a is_this_the_current_scoll_item besides is_hot_path
is_hot_path :: proc (s : ^State, node : ^Node) -> bool {
	
	if s.hot == node.uid {
		return true;
	}
	
	check_sub_nodes :: proc (s : ^State, node : ^Node) -> bool {
		for sub in node.sub_nodes {	
			if s.hot == sub.uid {
				return true;
			}
			if check_sub_nodes(s, sub) {
				return true;
			}
		}
		
		for sub in node.sub_commands {	
			switch val in sub {
				case ^Node:
					if s.hot == val.uid {
						return true;
					}
					if check_sub_nodes(s, val) {
						return true;
					}
				case Insert_subnode, Command:
					//Do nothing
			}
		}
		
		return false;
	}
	
	if check_sub_nodes(s, node) {
		return true;
	}
	
	return false;
}

make_uid :: proc (s : ^State, user_id : int, dont_touch : runtime.Source_Code_Location, sub_prio := 0) -> Unique_id {
	call_cnt := s.originations[{dont_touch, user_id}];
	s.originations[{dont_touch, user_id}] += 1;
	
	special_number := call_cnt;
	
	if user_id != 0 {
		special_number = user_id;
	}
	
	uid := Unique_id {
		dont_touch,
		call_cnt,
		sub_prio,
	}
	
	return uid;
}