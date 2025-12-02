package furbs_laycal;

import "vendor:fontstash"
import "core:fmt"
import "core:relative"
import "core:math"

Layout_state :: struct {
	elements : [dynamic]^Element,	
	element_stack : [dynamic]^Element,
	root : ^Element,
	
	draw_commands : [dynamic]Element_layout
}

Layout_dir :: enum {
	left_right,
	top_down,
	right_left,
	bottom_up,
}

Alignment :: enum {
	near,
	center,
	far,
}

Anchor_point :: enum {
	bottom_left,
	bottom_center,
	bottom_right,
	center_left,
	center_center,
	center_right,
	top_left,
	top_center,
	top_right,
}

Fixed :: i32;
Fit :: struct {};
Grow :: struct {};

fit :: Fit{}
grow :: Grow{}

Size :: union {
	Fixed,	//Have a fixed size in pixels
	Fit, 	//Be just be enough to fit all your sub-content
	Grow,	//Grow to fill the container
}

Abselute_postion :: struct {
	anchor : Anchor_point,
	self_anchor : Anchor_point,
	offset : [2]i32,
}

Parameters :: struct {
	//How do children behave
	padding : [4]i32, //from sub-elements to this
	child_gap : [2]i32, //between each sub element
	layout_dir : Layout_dir, //for the sub-elements
	alignment : [2]Alignment, //where should we align the children to

	//How does this size behave
	sizing : [2]Size,
	min_size : [2]i32,
	max_size : [2]i32,
	grow_weight : i32, //this is int to not have floating point problems.

	abs_position : Maybe(Abselute_postion),
}

parameters :: proc (size_x : Size = fit, size_y : Size = fit, min_size_x : i32 = 0, min_size_y : i32 = 0, max_size_x := max(i32), max_size_y := max(i32),
						grow_weight : i32 = 1, padding : [4]i32 = {5, 5, 5, 5}, child_gap : i32 = 2, layout_dir : Layout_dir = .left_right, alignment_x : Alignment = .near, alignment_y : Alignment = .near, abs_position : Maybe(Abselute_postion) = nil) -> Parameters {
	
	return Parameters {
		padding,
		child_gap,
		layout_dir,
		{ alignment_x, alignment_y },
		{size_x, size_y},
		{min_size_x, min_size_y},
		{max_size_x, max_size_y},
		grow_weight, 
		abs_position,
	}
}

Element :: struct {
	parent : ^Element,
	children : [dynamic]^Element,
	size : [2]i32,
	position : [2]i32,
	user_ptr : rawptr,

	using param : Parameters,
}

Element_layout :: struct {
	size : [2]i32,
	position : [2]i32,
	user_data : rawptr,
}

make_layout_state :: proc (params : Parameters = default_root_params) -> ^Layout_state {
	ls := new(Layout_state);

	ne := new(Element);
	ne^ = {
		nil, 
		make([dynamic]^Element),
		{0,0},
		{0,0},
		nil,

		params
	}

	ls.root = ne;

	return ls;
}

destroy_laytout_state :: proc (ls : ^Layout_state) {
	delete(ls.elements);
	delete(ls.element_stack);
	delete(ls.draw_commands);
	free(ls);
}

default_root_params : Parameters = {
	{0,0,0,0}, //padding
	{0,0}, //child gap
	.left_right, //for the sub-elements
	{.near, .near}, //where should we align the children to

	//How does this size behave
	{0,0},
	{0,0}, //min size
	{max(i32), max(i32)}, //max size
	1,

	nil,
}

begin_layout_state :: proc (ls : ^Layout_state, screen_size : [2]i32) {
	
	//add root note which is the same size as the screen? TODO??
	ls.root.size = screen_size;
	ls.root.param.max_size = screen_size;
	ls.root.param.min_size = screen_size;
}


open_element :: proc (state : ^Layout_state, params : Parameters, user_data : rawptr = nil) {

	ne := new(Element);
	ne.param = params;
	ne.user_ptr = user_data;
	if len(state.element_stack) != 0 {
		ne.parent = state.element_stack[len(state.element_stack)-1];
		append(&ne.parent.children, ne);
	}
	else {
		ne.parent = state.root;
		append(&ne.parent.children, ne);
		//panic("no root node");
		//state.root = ne;
	}
	
	append(&state.element_stack, ne);
}

close_element :: proc (state : ^Layout_state) {
	elem := pop(&state.element_stack);
	append(&state.elements, elem);
	
	//size horizontally
	switch sizing in elem.sizing.x { //calculate the size of the element, we know it here
		case Fixed: {
			elem.size.x = sizing;
		}
		case Fit: {
			do_size_fit(elem, 0);
		}
		case Grow: {
			//nothing here, this happens later in the DFS
		}
	}

	elem.size.x = math.clamp(elem.size.x, elem.min_size.x, elem.max_size.x);

	//size horizontally
	switch sizing in elem.sizing.y { //calculate the size of the element, we know it here
		case Fixed: {
			elem.size.y = sizing;
		}
		case Fit: {
			do_size_fit(elem, 1);
		}
		case Grow: {
			//nothing here, this happens later in the DFS
		}
	}

}

end_layout_state :: proc (ls : ^Layout_state, loc := #caller_location) -> []Element_layout {
	
	//do multiple passes over the structure.
	//this is how clay does it:
	//1. fit sizing width (this happens in close element)
	//2. grow and shrink widths
	//3. wrap text
	//4. fit sizing heigths
	//5. grow and shrink sizing heigths
	//6. position
	//7. draw commands

	{ //2. grow and shrink widths
		do_expand_recursive(ls.root, 0, &ls.draw_commands);
	}

	{ //3. wrap text
		
	}

	{ //4. fit sizing heigths
		//we need to do a reverse breath first search 
		//for e in ls.r 
	}

	{ //5. grow and shrink heigths
		do_expand_recursive(ls.root, 1, &ls.draw_commands);
	}

	{ //6. position
		do_position_recursive(ls.root, {0,0});
	}

	{ //7. draw commands
		clear(&ls.draw_commands);
		
		draw_elem :: proc(elem : ^Element, commands : ^[dynamic]Element_layout) {

			el := Element_layout {
				size = elem.size,
				position = elem.position, //todo
				user_data = elem.user_ptr,
			}

			append(commands, el);

			for child in elem.children {
				draw_elem(child, commands);
			}
		}	
		
		for child in ls.root.children {
			draw_elem(child, &ls.draw_commands);
		}
	}

	assert(len(ls.element_stack) == 0, "Popped too few elements", loc);
	for e in ls.elements {
		delete(e.children)
		free(e);
	}
	clear(&ls.elements);

	clear(&ls.root.children)

	return ls.draw_commands[:];
}

//grow children to fit the parent
@(private="file")
do_expand_recursive :: proc(elem : ^Element, axis : int, commands : ^[dynamic]Element_layout) {

	is_prim : bool;
	if axis == 0 {
		is_prim = elem.layout_dir == .left_right || elem.layout_dir == .right_left
	}
	else {
		is_prim = elem.layout_dir == .top_down || elem.layout_dir == .bottom_up
	}
	
	children : [dynamic]^Element;
	defer delete(children);
	for c in elem.children {
		switch _ in c.sizing[axis] {
			case i32, Fit:
				
			case Grow:
				append(&children, c);
		}
	}

	if is_prim {
		remaning_width := elem.size[axis] - elem.padding[axis] - elem.padding[axis + 2];
		
		for child in elem.children {
			remaning_width -= child.size[axis];
		}
		remaning_width -= (cast(i32) len(elem.children) - 1) * elem.child_gap[axis];
		
		//how much width is there in total and how much weight, we can use to determine how many pixels a single width is worth
		total_remaning_width := remaning_width;
		total_weight : i32 = 0;
		for child in children {
			total_weight += child.grow_weight;
		}
		
		for remaning_width > 0 && len(children) != 0 {
			least_pressence : i32 = max(i32)
			next_least_pressence : i32 = max(i32)
			
			for child, i in children {
				if child.grow_weight * child.size[axis] < least_pressence {
					next_least_pressence = least_pressence;
					least_pressence = child.grow_weight * child.size[axis];
				}
				if child.grow_weight * child.size[axis] != least_pressence {
					next_least_pressence = math.min(next_least_pressence, child.grow_weight * child.size[axis]);
				}
			}
			
			if next_least_pressence == max(i32) {
				//they are all the same, just expand by weight
				for &child, i in children {
					if i == len(children) - 1 { //we do give the last element the rest of the width, this is a way to handle floating point precision.
						child.size[axis] = remaning_width;
						remaning_width -= child.size[axis];
					}
					else {
						consumed := cast(i32)math.round(cast(f32)total_remaning_width * cast(f32)child.grow_weight / cast(f32)total_weight);
						child.size[axis] += consumed;
						remaning_width -= consumed;
					}
				}
			}
			else {
				for &child, i in children {
					consumed := math.max(1, cast(i32)math.round((cast(f32)next_least_pressence - cast(f32)least_pressence) / cast(f32)child.grow_weight));
					child.size[axis] += consumed;
					remaning_width -= consumed;
				}
			}
		}
	}
	else {
		//simply move this down to the max size (that is the size of the parent - padding)
		for child in children {
			child.size[axis] = elem.size[axis] - elem.padding[axis] - elem.padding[axis+2];  
		}
	}
	
	//recurse down the tree in DFS
	for child in elem.children {
		do_expand_recursive(child, axis, commands);
	}
}

do_size_fit_recursive :: proc (elem : ^Element, axis : int) {
	



} 

@(private="file")
do_size_fit :: proc (elem : ^Element, axis : int) {
	
	is_prim : bool;
	
	if axis == 0 {
		is_prim = elem.layout_dir == .left_right || elem.layout_dir == .right_left
	}
	else {
		is_prim = elem.layout_dir == .top_down || elem.layout_dir == .bottom_up
	}

	switch sizing in elem.sizing[axis] { //calculate the size of the element, we know it here
		case Fixed: {
			elem.size[axis] = sizing;
		}
		case Fit: {
			if is_prim {
				size := elem.padding[axis] + elem.padding[axis + 2];
				
				for child, i in elem.children {
					if i != 0 {
						size += elem.child_gap[axis];
					}
					
					size += child.size[axis];
				}
				
				elem.size[axis] = size;
			}
			else {
				size : i32 = 0;

				for child, i in elem.children {
					size = math.max(size, child.size[axis]);
				}

				elem.size[axis] = size + elem.padding[axis] + elem.padding[axis + 2];
			}
		}
		case Grow: {
			//nothing here, this happens later in the DFS
		}
	}

	elem.size[axis] = math.clamp(elem.size[axis], elem.min_size[axis], elem.max_size[axis]);
}

@(private="file")
do_position_recursive :: proc (elem : ^Element, screen_offset : [2]i32) {
	
	axis : int;
	internal_offset : i32 = 0; //how for are we going in the layout directio, so if right to left still a positive number
	total_child_size : i32 = 0;
	max_child_other : i32 = 0;

	switch elem.layout_dir {
		case .left_right: {
			axis = 0;
		}
		case .top_down: {
			axis = 1;
		}
		case .right_left: {
			axis = 0;
		}
		case .bottom_up: {
			axis = 1;
		}
	}

	other_axis := axis + 1 %% 2;

	for child, i in elem.children {
		if i != 0 {
			total_child_size += elem.child_gap[axis];
		}
		total_child_size += child.size[axis];

		max_child_other = math.max(max_child_other, child.size[other_axis]);
	}

	for child, i in elem.children {

		child.position = screen_offset;
		{ //everything in here is for the primary axis
			if i != 0 {
				internal_offset += elem.child_gap[axis];
			}
			switch elem.alignment[axis] { //These are wrong for right_left and top_bottom
				case .near: {
					child.position[axis] += internal_offset + elem.padding[axis];
				}
				case .center: {
					child.position[axis] += internal_offset + (elem.size[axis] - total_child_size) / 2; //we undo the origianl offset from the padding here.
				}
				case .far: {
					child.position[axis] += internal_offset - elem.padding[axis + 2] + (elem.size[axis] - total_child_size);
				}
			}
			internal_offset += child.size[axis];
		}

		TODO make right_left and top_bottom work

		{ //everything in here is for the other axis
			switch elem.alignment[other_axis] { //These are wrong for right_left and top_bottom
				case .near: {
					child.position[other_axis] += elem.padding[other_axis];
				}
				case .center: {
					child.position[other_axis] += (elem.size[other_axis] - child.size[other_axis]) / 2;
				}
				case .far: {
					child.position[other_axis] += elem.size[other_axis] - elem.padding[other_axis + 2] - child.size[other_axis];
				}
			}
		}
	}

	for child, i in elem.children {
		do_position_recursive(child, child.position);
	}

}
