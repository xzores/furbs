package furbs_laycal;

import "core:c"
import "vendor:fontstash"
import "core:fmt"
import "core:relative"
import "core:math"

///////////TODO TODO///////////
//We need some more features here.
//First we need the ability to be able to pick min and max sizes.
//Then we need to be able to pick % of parent, so 50% of parent (50% of screen can be easily absracted in the next layer)
//Then we need to be able to do text, this requires doing all the steps.
//then we have absolute position that needs to be done.

//ohh yeah and element wrapping, so when we fill the one axis we go to next line.
//How would wrapping work with grow? we could make it so the last line have a single large grow and all the others are small
//That is likely the most reasonable way.
//Or we could check beforehand if we need more then 1 line and then treat the two lines as 1 long one and split it by that, approximately and then deligate them to each line.

Layout_state :: struct {
	elements : [dynamic]^Element,	
	element_stack : [dynamic]^Element,
	root : ^Element,
	
	has_begun : bool,

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
Parent_ratio :: distinct f32;
Fit :: struct {};
Grow :: struct {};
Grow_fit  :: struct{};

fit :: Fit{}
grow :: Grow{}
grow_fit :: Grow_fit{}

Size :: union {
	Fixed,			//Have a fixed size in pixels
	Parent_ratio,	
	Fit, 			//Be just be enough to fit all your sub-content
	Grow,			//Grow to fill the container
	Grow_fit,
}

Min_size :: union {
	Fixed,	//Have a fixed size in pixels
	Parent_ratio,
	Fit, //this means always have space for children.
}

Max_size :: union {
	Fixed,	//Have a fixed size in pixels
	Parent_ratio,
}

Absolute_postion :: struct {
	anchor : Anchor_point,
	self_anchor : Anchor_point,
	offset : [2]i32,
}

Overflow :: enum {
	right,
	equal,
	left,
}

Parameters :: struct {
	//How do children behave
	padding : [4]i32, //from sub-elements to this
	child_gap : [2]i32, //between each sub element
	layout_dir : Layout_dir, //for the sub-elements
	alignment : [2]Alignment, //where should we align the children to
	overflow : Overflow,

	//How does this size behave
	sizing : [2]Size,
	min_size : [2]Min_size,
	max_size : [2]Max_size,
	grow_weight : i32, //this is int to not have floating point problems.

	abs_position : Maybe(Absolute_postion),
}

parameters :: proc (size_x : Size = fit, size_y : Size = fit, min_size_x : Min_size = 0, min_size_y : Min_size = 0, max_size_x : Max_size = max(i32), max_size_y : Max_size = max(i32),
						grow_weight : i32 = 1, padding : [4]i32 = {5, 5, 5, 5}, child_gap : i32 = 2, layout_dir : Layout_dir = .left_right,
						alignment_x : Alignment = .near, alignment_y : Alignment = .near, overflow : Overflow = .right, abs_position : Maybe(Absolute_postion) = nil) -> Parameters {
	
	return Parameters {
		padding,
		child_gap,
		layout_dir,
		{ alignment_x, alignment_y },
		overflow,
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
	in_flow : [dynamic]^Element,
	out_flow : [dynamic]^Element,
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
		make([dynamic]^Element),
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
	.right,

	//How does this size behave
	{0,0},
	{0,0}, //min size
	{max(i32), max(i32)}, //max size
	1,

	nil,
}

begin_layout_state :: proc (ls : ^Layout_state, screen_size : [2]i32) {
	assert(!ls.has_begun);

	//add root note which is the same size as the screen? TODO??
	ls.root.size = screen_size;
	ls.root.param.max_size = {screen_size.x, screen_size.y};
	ls.root.param.min_size = {screen_size.x, screen_size.y};
	ls.has_begun = true;
}

open_element :: proc (ls : ^Layout_state, params : Parameters, user_data : rawptr = nil) {
	assert(ls.has_begun, "you must begin the layout state once at the start of the frame");

	ne := new(Element);
	ne.param = params;
	ne.user_ptr = user_data;

	if len(ls.element_stack) != 0 {
		ne.parent = ls.element_stack[len(ls.element_stack)-1];
		append(&ne.parent.children, ne);
	}
	else {
		ne.parent = ls.root;
		append(&ne.parent.children, ne);
	}

	append(&ne.parent.children, ne);
	if _, ok := ne.abs_position.?; ok {
		append(&ne.parent.out_flow, ne);
	}
	else {
		append(&ne.parent.in_flow, ne);
	}

	append(&ls.element_stack, ne);
}

close_element :: proc (ls : ^Layout_state) {
	elem := pop(&ls.element_stack);
	append(&ls.elements, elem);
	
	//size horizontally
	do_size_fit(elem, 0);

	//size horizontally, todo remove this when doing text, so it fits later on the vertical axis
	do_size_fit(elem, 1);

	/*
	for t in 0..<len(state.element_stack) {
		fmt.print("    ");
	}
	fmt.printf("did size : %v\n", elem.size[0]);
	if elem.size[0] == 0 {
		fmt.printf("size was 0 for : %#v\n", elem);
	}
	*/
}

end_layout_state :: proc (ls : ^Layout_state, loc := #caller_location) -> []Element_layout {
	ls.has_begun = false;

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
		delete(e.in_flow)
		delete(e.out_flow)
		free(e);
	}
	clear(&ls.elements);

	clear(&ls.root.children)
	clear(&ls.root.in_flow)
	clear(&ls.root.out_flow)

	return ls.draw_commands[:];
}

//grow children to fit the parent
@(private="file")
do_expand_recursive :: proc(elem : ^Element, axis : int, commands : ^[dynamic]Element_layout) {

	//We must do 2 things in this function
	//first, the primary axis must look at its children to find all the ones the must grow.
	//secoudly I must grow my children if i am on the non-primary
	
	expand_in_flow : [dynamic]^Element; //the children whom needs to grow
	defer delete(expand_in_flow);
	for c in elem.in_flow {
		switch _ in c.sizing[axis] {
			case i32, Fit:

			case Parent_ratio:
				panic("TODO");
			
			case Grow, Grow_fit:
				append(&expand_in_flow, c);
		}
	}

	if is_primary_axis(elem, axis) { //all this is just for the primary axis

		//TODO this parent ratio needs to happen here
		remaning_width := elem.size[axis] - elem.padding[axis] - elem.padding[axis + 2];
		
		//how much width is there in total and how much weight, we can use to determine how many pixels a single width is worth
		total_weight : i32 = 0;
		for child in expand_in_flow {
			remaning_width -= child.size[axis];
			total_weight += child.grow_weight;
		}
		remaning_width -= (cast(i32) len(expand_in_flow) - 1) * elem.child_gap[axis];
		total_width := remaning_width;

		
		for remaning_width > 0 && len(expand_in_flow) != 0 {
			least_pressence : i32 = max(i32)
			next_least_pressence : i32 = max(i32)
			
			for child, i in expand_in_flow {
				if child.grow_weight * child.size[axis] < least_pressence {
					next_least_pressence = least_pressence;
					least_pressence = child.grow_weight * child.size[axis];
				}
				if child.grow_weight * child.size[axis] != least_pressence {
					next_least_pressence = math.min(next_least_pressence, child.grow_weight * child.size[axis]);
				}
			}
			
			#reverse for &child, i in expand_in_flow {
				consumed : i32;

				if i == len(expand_in_flow) - 1 { //we do give the last element the rest of the width, this is a way to handle floating point precision.
					consumed = remaning_width;
					fmt.printf("remaning_width : %v, parent size : %v\n", remaning_width, elem.parent);
				}
				else {
					if next_least_pressence == max(i32) {
						//they are all the same, just expand by weight
						consumed = cast(i32)math.round(cast(f32)total_width * cast(f32)child.grow_weight / cast(f32)total_weight);
					} else {
						consumed = math.max(1, cast(i32)math.round((cast(f32)next_least_pressence - cast(f32)least_pressence) / cast(f32)child.grow_weight));
					}
				}

				//if child.size[axis] + consumed becomes larger then eval_max_size(elem, axis), then subtract the differnce from consumed, this means we will enforce the elements max_size
				consumed -= math.max(0, (child.size[axis] + consumed) - eval_max_size(elem, axis));
				
				if consumed == 0 {
					ordered_remove(&expand_in_flow, i);
					total_weight -= child.grow_weight;
				}
				else {
					child.size[axis] += consumed;
					remaning_width -= consumed;
				}
			}
		}
		
		elem.size[axis] = math.clamp(elem.size[axis], eval_min_size(elem, axis), eval_max_size(elem, axis));
	}
	else { //this is for the non-primary axis, it needs to be applied for all children even if this current element is not on the primary axis.
		//simply move this down to the max size (that is the size of the parent - padding)
		for child in expand_in_flow {
			child.size[axis] = elem.size[axis] - elem.padding[axis] - elem.padding[axis+2]; 
			elem.size[axis] = math.clamp(elem.size[axis], eval_min_size(elem, axis), eval_max_size(elem, axis));
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

	switch sizing in elem.sizing[axis] { //calculate the size of the element, we know it here
		case Fixed: {
			elem.size[axis] = sizing;
		}
		case Fit, Grow_fit: {
			elem.size[axis] = get_fit_space(elem, axis);
		}
		case Parent_ratio:
			panic("TODO");
		case Grow: {
			//grow does not make space for children
		}
	}
	
	elem.size[axis] = math.clamp(elem.size[axis], eval_min_size(elem, axis), eval_max_size(elem, axis));
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
	
	other_axis := (axis + 1) %% 2;

	for child, i in elem.in_flow {
		if i != 0 {
			total_child_size += elem.child_gap[axis];
		}
		total_child_size += child.size[axis];

		max_child_other = math.max(max_child_other, child.size[other_axis]);
	}

	for child, i in elem.in_flow {

		child.position = screen_offset;
		{ //everything in here is for the primary axis
			if i != 0 {
				internal_offset += elem.child_gap[axis];
			}

			reverse := elem.layout_dir == .right_left || elem.layout_dir == .top_down;
			inner_box := [4]i32{elem.padding[0], elem.padding[1], elem.size.x - elem.padding[0] - elem.padding[2], elem.size.y - elem.padding[1] - elem.padding[3]}

			//TODO center breaks, likely using the inner box solves the problem.
			switch elem.alignment[axis] { //These are wrong for right_left and top_bottom
				case .near: {
					if reverse {
						child.position[axis] += inner_box[axis] + inner_box[axis + 2] - internal_offset - child.size[axis];
					}
					else {
						child.position[axis] += inner_box[axis] + internal_offset;
					}
				}
				case .center: {
					//the reverse and non-reverse are the same
					center_off := (inner_box[axis + 2] - total_child_size) / 2;
					switch elem.overflow {
						case .right:
							center_off = max(0, center_off);
						case .equal:
							//nothing
						case .left:
							panic("TODO, this is not easy to solve, i think");
					}
					
					child.position[axis] += inner_box[axis] + internal_offset + center_off; //we undo the origianl offset from the padding here.
				}
				case .far: {
					if reverse {
						child.position[axis] += elem.padding[axis + 2] + (elem.size[axis] - total_child_size) - internal_offset
					}
					else {
						child.position[axis] += internal_offset - elem.padding[axis + 2] + (elem.size[axis] - total_child_size);
					}
				}
			}
			internal_offset += child.size[axis];
		}

		//TODO make right_left and top_bottom work, this is just making an if inside each .near, .center or .far
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

eval_min_size :: proc (elem : ^Element, axis : int) -> i32 {
	
	switch min in elem.min_size[axis] {
		case i32:
			return min;
		case Parent_ratio:
			panic("TODO");
		case Fit:
			return get_fit_space(elem, axis);
	}

	unreachable();
}

eval_max_size :: proc (elem : ^Element, axis : int) -> i32 {
	switch max in elem.max_size[axis] {
		case i32:
			return max;
		case Parent_ratio:
			panic("TODO");
	}

	unreachable();
}

@(private="file")
get_fit_space :: proc (elem : ^Element, axis : int) -> i32 {
	
	//make space for children
	if is_primary_axis(elem, axis) {
		size := elem.padding[axis] + elem.padding[axis + 2];
		
		for child, i in elem.in_flow {
			if i != 0 {
				size += elem.child_gap[axis];
			}
			
			size += child.size[axis];
		}

		//make it so we can always fit the elements even the abs position ones
		for child, i in elem.out_flow {
			size = max(size, elem.padding[axis] + elem.padding[axis + 2] + child.size[axis]);
			panic("todo, this does not work for centered abs position elements")
		}

		return size;
	}
	else {
		size : i32 = 0;
		
		for child, i in elem.in_flow {
			size = math.max(size, child.size[axis]);
			panic("todo, this does not work for centered abs position elements")
		}

		return size + elem.padding[axis] + elem.padding[axis + 2];
	}

	unreachable();
}

@(private="file")
is_primary_axis :: proc (elem : ^Element, axis : int) -> bool {
	is_prim : bool;
	
	if axis == 0 {
		is_prim = elem.layout_dir == .left_right || elem.layout_dir == .right_left
	}
	else {
		is_prim = elem.layout_dir == .top_down || elem.layout_dir == .bottom_up
	}

	return is_prim;
}