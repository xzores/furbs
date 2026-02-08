package furbs_layman_old;

import "base:runtime"

import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:slice"
import "core:container/queue"

import "core:fmt"

import "../utils"
import "../render"


// NOTES //
/*
padding inserts a space between the parent and the elements and its children.
*/

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

//TODO, i need to be able to specify a min, max size in pixel or ratio and so on, and i should target the following:
//px	//pixels, easy
//%, //unit size, will be screen-size independent, but might look bad for thin lines which dont align with the pixels.
//em, //text size, not sure how this is usefull
//vw or vh ratio, //like take up 100% of the screen width, usefull for some elements. This should likely be container width, not screen.
//auto/fit-content //this i am not sure how i would implement/use

Panel :: struct {
	position : [2]f32, //in relation to the parent panel
	size : [2]f32, //the view size
	scroll_offset : [2]f32,
	virtual_size : [2]f32, //the size which there exists items/elements
	
	hor_behavior : Hor_placement,
	ver_behavior : Ver_placement,
	append_hor : bool,	//Should we append new elements vertically or horizontally
	wrap_on_overflow : bool,
	
	use_scissor : bool, 
	enable_hor_scroll : bool,
	enable_ver_scroll : bool,
	
	current_offset : [2]f32, //At what offset should new element be added
	uid : Maybe(Unique_id),
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
	is_overlay : bool,
	
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
	Splitter_state,
	Panel_state,
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
	delete(s.split_panel_stack);
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
	
	//this is root node?
	push_node(s, uid, false, false, dont_touch);
	
	panel := Panel{
		{0,0},
		{screen_width, screen_height},
		{0,0},
		{screen_width, screen_height},
		
		.left,
		.top,
		false,
		
		true,
		false,
		false,
		false,
		
		0,
		nil,
	};
	
	push_panel(s, panel);
	
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
	overlay_commands := make([dynamic]Command, context.temp_allocator);
	priority : u16;
	
	depth_first_assign_priority :: proc(s : ^State, node: ^Node, commands : ^[dynamic]Command, overlay_commands : ^[dynamic]Command, priority : ^u16, is_overlay : bool) {
		is_overlay := is_overlay;
		assert(node != nil, "node is nil");
		
		s.priorities[node] = priority^;
		priority^ += 1;
		
		current_sub_node : int = 0;
		
		if node.refound == true {
			
			for cmd in node.sub_commands {
				switch val in cmd {
					case Command: {
						if is_overlay {
							append(overlay_commands, val);
						} else {
							append(commands, val);
						}
					}
					case ^Node: {
						if val.is_overlay {
							is_overlay = true;
						}
						
						depth_first_assign_priority(s, val, commands, overlay_commands, priority, is_overlay);
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
						
						depth_first_assign_priority(s, sub_node, commands, overlay_commands, priority, is_overlay);
					}
				}
			}
		}
	}
	
	depth_first_assign_priority(s, s.root, &commands, &overlay_commands, &priority, false);
	
	for c in overlay_commands {
		append(&commands, c);
	}
	
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
	dx : f32 = 0;
	dy : f32 = 0;
	
	if len(s.scissor_stack) >= 1 {
		parent_scissor := s.scissor_stack[len(s.scissor_stack)-1];
		
		if parent_scissor.enable {
			r := parent_scissor.area;
			if scissor.area.x < r.x {
				dx = r.x - scissor.area.x;
				scissor.area.x = r.x;
			}
			if scissor.area.y < r.y {
				dy = r.y - scissor.area.y;
				scissor.area.y = r.y;
			}
			
			scissor.area.z = math.min(scissor.area.z - dx, r.x + r.z - scissor.area.x);
			scissor.area.w = math.min(scissor.area.w - dy, r.y + r.w - scissor.area.y);
		}
	}
	
	scissor.area.z = math.max(scissor.area.z, 0);
	scissor.area.w = math.max(scissor.area.w, 0);
	
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

Panel_state :: struct {
	scroll_offset : [2]f32,
}

PANEL_SUBPRIORITY :: 10_000;

push_panel :: proc (s : ^State, panel : Panel, loc := #caller_location) {
	panel := panel;
	
	uid : Unique_id = s.current_node.uid;
	uid.special_number = PANEL_SUBPRIORITY;
	if u, ok := panel.uid.?; ok {
		uid = u;
	}
	
	p_state : Panel_state;
	
	{
		_p := get_state(s, uid);
		
		if _p == nil {
			
			p_state = Panel_state {
				panel.scroll_offset,
			};
		}
		else if last_panel, ok := _p.(Panel_state); ok {
			p_state = last_panel;
		}
		else  {
			panic("The was not a window last frame");
		}
	}
	
	if panel.enable_hor_scroll {
		panel.scroll_offset.x = p_state.scroll_offset.x;
	}
	if panel.enable_ver_scroll {
		panel.scroll_offset.y = p_state.scroll_offset.y;
	}
	
	panel.uid = uid;
	append(&s.panel_stack, panel);
	_ = do_offset(s, get_style(s).out_padding);
	
	if panel.use_scissor {
		r := Cmd_scissor{{panel.position.x, panel.position.y, panel.size.x, panel.size.y}, panel.use_scissor};
		push_scissor(s, r);
	}
	
	save_state(s, uid, p_state);
}

pop_panel :: proc (s : ^State, loc := #caller_location) -> Panel {
	
	panel := s.panel_stack[len(s.panel_stack) - 1]
	
	{
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
		
		if panel.enable_hor_scroll && panel.virtual_size.x > panel.size.x {
			scroll_uid := s.current_node.uid;
			scroll_uid.sub_priotity = PANEL_SUBPRIORITY + 1;
			
			//the horizontal scrollbar
			scroll_height := panel.size.x - 2 * scroll_style.length_padding;
			scroll_placement := place_in_parent(s, panel.position, panel.size, 0, Dest{.mid, .bottom, 0, scroll_style.padding.y}, [2]f32{scroll_height, scroll_style.bar_bg_thickness});
			
			sd : f32 = scroll_delta.x;
			if s.hot == scroll_uid {
				sd = s.scroll_delta.x;
				sd += s.scroll_delta.y;
			}
			
			push_node(s, scroll_uid, false, false);
			defer pop_node(s);
			
			scroll_procent, active_height, display_state := handle_scroll_bar(s, s.mouse_pos.x, sd, panel.virtual_size.x, panel.size.x, scroll_uid, scroll_height, scroll_placement, scroll_placement.x, scroll_placement.z, &panel.scroll_offset.x, false, false);
			
			view_scroll_placement := place_in_parent(s, scroll_placement.xy, scroll_placement.zw, 0, Dest{.left, .mid, scroll_procent * (scroll_height - active_height), 0}, [2]f32{active_height, scroll_style.bar_front_thickness});
			
			append_command(s, Cmd_rect{scroll_placement, .scrollbar_background, -1, display_state});
			append_command(s, Cmd_rect{view_scroll_placement, .scrollbar_front, -1, display_state});
		}
		if panel.virtual_size.x < panel.size.x {
			panel.scroll_offset.x = 0;
		}
		
		if panel.enable_ver_scroll && panel.virtual_size.y > panel.size.y {
		
			fmt.printf("vert scroll\n");
			scroll_uid := s.current_node.uid;
			scroll_uid.sub_priotity = PANEL_SUBPRIORITY + 2;
			
			sd : f32 = scroll_delta.y;
			if s.hot == scroll_uid {
				sd += s.scroll_delta.y;
			}
			
			//the vertical scrollbar
			scroll_height := panel.size.y - 2 * scroll_style.length_padding;
			scroll_placement := place_in_parent(s, panel.position, panel.size, 0, Dest{.right, .mid, scroll_style.padding.x, 0}, [2]f32{scroll_style.bar_bg_thickness, scroll_height});
			
			push_node(s, scroll_uid, false, false);
			defer pop_node(s);
			
			scroll_procent, active_height, display_state := handle_scroll_bar(s, s.mouse_pos.y, sd, panel.virtual_size.y, panel.size.y, scroll_uid, scroll_height, scroll_placement, scroll_placement.y, scroll_placement.w, &panel.scroll_offset.y, true, true);
			
			view_scroll_placement := place_in_parent(s, scroll_placement.xy, scroll_placement.zw, 0, Dest{.mid, .top, 0, scroll_procent * (scroll_height - active_height)}, [2]f32{scroll_style.bar_front_thickness, active_height});
			
			append_command(s, Cmd_rect{scroll_placement, .scrollbar_background, -1, display_state});
			append_command(s, Cmd_rect{view_scroll_placement, .scrollbar_front, -1, display_state});
		}
		if panel.virtual_size.y < panel.size.y {
			panel.scroll_offset.y = 0;
		}
	}
	
	if panel.use_scissor {
		pop_scissor(s);
	}
	pop(&s.panel_stack, loc);
	
	save_state(s, panel.uid.(Unique_id), Panel_state{panel.scroll_offset});
	
	return panel;
}


//////////////////////////////////////// RTIGHT CLICK OPTION ////////////////////////////////////////

/*
//prio of -1 means append
option_panel :: proc (label : string, prio := -1) -> {
	
}

option_element :: proc () -> {
	
}
*/


//////////////////////////////////////// PRIVATE ////////////////////////////////////////

append_command :: proc (s : ^State, cmd : Command) {
	append(&s.current_node.sub_commands, cmd);
}

set_mouse_cursor :: proc (s : ^State, cursor_type : Cursor_type) {
	s.next_cursor = cursor_type;
}

push_node :: proc (s : ^State, uid : Unique_id, sortable : bool, overlay : bool, loc := #caller_location) {
	
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
			overlay,
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
			append(&s.current_node.sub_commands, Insert_subnode{}); // this should happen every frame as the sub_commands gets cleared
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
		s.highest_priority = max(u32) / 4 + cur_prio;
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
		s.highest_priority = max(u32) / 4;
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
	
	res := (cast(u32)cur_prio << 16) + s.prio_cnt;
	
	if s.current_node.is_overlay {
		res += max(u32) / 4
	}
	
	return res;
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

@(require_results)
do_offset :: proc (s : ^State, to_offset : [2]f32) -> [2]f32 {
	p := &s.panel_stack[len(s.panel_stack)-1]
	
	res : [2]f32 = p.current_offset;
	
	/*
	where_append_ver :: proc (s : ^State, p : ^Panel, to_offset : [2]f32) -> (new_offset : [2]f32, space_occ : [4]f32) {
		
	}
	
	where_append_hor :: proc (s : ^State, p : ^Panel, to_offset : [2]f32) -> (new_offset : [2]f32, space_occ : [4]f32) {
		
	}
	*/

	do_append_hor :: proc (s : ^State, p : ^Panel, to_offset : [2]f32, is_alternative : bool) {
		padding : f32; 
	
		if p.current_offset != 0 {
			padding = get_style(s).in_padding;
		}
	
		p.current_offset.x += to_offset.x + padding;
		p.virtual_size.x = math.max(p.virtual_size.x, p.current_offset.x - padding + get_style(s).out_padding);
		p.virtual_size.y = math.max(p.virtual_size.y, to_offset.y + 2 * get_style(s).out_padding);  // incease the virtual size to fit the element
		if is_alternative { //if it is alternative it adds to element to the virtual size
			p.virtual_size.x = math.max(p.virtual_size.x, p.current_offset.x + to_offset.x + 2 * get_style(s).out_padding);
		}
	}
	
	do_append_ver :: proc (s : ^State, p : ^Panel, to_offset : [2]f32, is_alternative : bool) {
		padding : f32; 
		
		if p.current_offset != 0 {
			padding = get_style(s).in_padding;
		}
		
		p.current_offset.y += to_offset.y + padding;
		p.virtual_size.x = math.max(p.virtual_size.x, to_offset.x + 2 * get_style(s).out_padding);  // incease the virtual size to fit the element
		p.virtual_size.y = math.max(p.virtual_size.y, p.current_offset.y - padding + get_style(s).out_padding);
		if is_alternative { //if it is alternative it adds to element to the virtual size
			p.virtual_size.y = math.max(p.virtual_size.y, p.current_offset.y + to_offset.y + 2 * get_style(s).out_padding);
		}
	}
	
	if p.append_hor {
		
		if (p.current_offset.x + get_style(s).out_padding + to_offset.x > p.size.x) && to_offset.x > get_style(s).out_padding {
			p.current_offset.x = get_style(s).out_padding;
			do_append_ver(s, p, to_offset, true);
			res = p.current_offset;
		}
		
		do_append_hor(s, p, to_offset, false);
	}
	else {
		
		if (p.current_offset.y + get_style(s).out_padding + to_offset.y > p.size.y) && to_offset.y != 0 {
			p.current_offset.y = get_style(s).out_padding;
			do_append_hor(s, p, to_offset, true);
			res = p.current_offset;
		}
		
		do_append_ver(s, p, to_offset, false);
	}
	
	return res;
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

@(require_results)
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
@(require_results)
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

@(require_results)
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

@(require_results)
move_dest :: proc(dest: Dest, dx, dy: f32) -> Dest {
	new_dest := dest;

	// Horizontal adjustment
	switch dest.hor {
		case .left, .mid:
			new_dest.offset_x += dx;
		case .right:
			new_dest.offset_x -= dx;
	}

	// Vertical adjustment
	switch dest.ver {
		case .bottom, .mid:
			new_dest.offset_y += dy;
		case .top:
			new_dest.offset_y -= dy;
	}

	return new_dest;
}

Resize_edge :: enum {
	left,
	right,
	top,
	bottom,
}

resize_rect :: proc(dest: Dest, size: [2]f32, delta: f32, edge : Resize_edge) -> (Dest, [2]f32) {
	new_dest := dest;
	new_size := size;
	
	switch edge {
		case .left:
			switch dest.hor {
				case .left:
					new_size.x -= delta;
					new_dest.offset_x += delta;
				case .mid:
					new_size.x -= delta;
					new_dest.offset_x += delta / 2;
				case .right:
					new_size.x -= delta;
			}
		
		case .right:
			switch dest.hor {
				case .left:
					new_size.x += delta;
				case .mid:
					new_size.x += delta;
					new_dest.offset_x += delta / 2;
				case .right:
					new_size.x += delta;
					new_dest.offset_x -= delta;
			}
	
		case .top:
			switch dest.ver {
				case .bottom:
					new_size.y += delta;
				case .mid:
					new_size.y += delta;
					new_dest.offset_y += delta / 2;
				case .top:
					new_size.y += delta;
					new_dest.offset_y -= delta;
			}
		
		case .bottom:
			switch dest.ver {
				case .bottom:
					new_size.y -= delta;
					new_dest.offset_y += delta;
				case .mid:
					new_size.y -= delta;
					new_dest.offset_y += delta / 2;
				case .top:
					new_size.y -= delta;
			}
	}
	
	return new_dest, new_size;
}
