package furbs_laycal;

import "core:c"
import "vendor:fontstash"
import "core:fmt"
import "core:relative"
import "core:math"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "core:log"

///////////TODO TODO///////////
//We need some more features here.
//First we need the ability to be able to pick min and max sizes. (i think this works)
//Then we need to be able to pick % of parent, so 50% of parent (50% of screen can be easily absracted in the next layer)
//Then we need to be able to do text, this requires doing all the steps.
//then we have absolute position that needs to be done.

//ohh yeah and element wrapping, so when we fill the one axis we go to next line.
//How would wrapping work with grow? we could make it so the last line have a single large grow and all the others are small
//That is likely the most reasonable way.
//Or we could check beforehand if we need more then 1 line and then treat the two lines as 1 long one and split it by that, approximately and then deligate them to each line.


Layout_state :: struct {
	elements : [dynamic]^Element,	 //this is operated by close, aka it gets pop from element_stack to elements
	element_stack : [dynamic]^Element, //this is operated by open_...
	root : ^Element,
	
	has_begun : bool,

	meas_width : Meassure_text_width_callback,
	meas_height : Meassure_text_height_callback,
	meas_line_gap :  Meassure_line_gap_callback,

	draw_commands : [dynamic]Element_layout,

	self_free : bool,
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

Axis :: enum {
	up_right,
	up_left,
	down_right,
	down_left,
}

Fixed :: i32;
Parent_ratio :: struct{rel_size : f32};
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

Text :: struct {
	text : string,			//if it is text
	size : f32,
	font : int,
}

Sizeing :: union {
	[2]Size,
	Text,
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
	axis : Axis, //What direction is the coordinate system provided by offset (there is no inherent origin (0,0))
	offset : [2]i32,
}

//TODO have some system for bumping to the next line on overflow instad of overflowing
Overflow_dir :: enum {
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
	overflow : Overflow_dir,
	
	//How does this size behave
	sizing : Sizeing,
	min_size : [2]Min_size,
	max_size : [2]Max_size,
	grow_weight : i32, //this is int to not have floating point problems.
	
	split_on_dash : bool, 	//for text

	abs_position : Maybe(Absolute_postion),
}

Element :: struct {
	parent : ^Element,
	children : [dynamic]^Element,
	in_flow : [dynamic]^Element,
	out_flow : [dynamic]^Element,
	size : [2]i32,
	position : [2]i32,
	text_to_draw : [dynamic]string, //one string per line to draw
	debug_name : cstring,

	using param : Parameters,
}

Text_line :: struct{
	ver_offset : i32,
	line : string
}

Element_layout :: struct {
	size : [2]i32,
	position : [2]i32,
	text_size : f32,	//use only if there is text
	font : int, 		//use only if there is text
	lines : []Text_line, //non-nil if there is text
}

rect_parameters :: proc (size_x : Size = fit, size_y : Size = fit, min_size_x : Min_size = 0, min_size_y : Min_size = 0, max_size_x : Max_size = max(i32), max_size_y : Max_size = max(i32),
						grow_weight : i32 = 1, padding : [4]i32 = {5, 5, 5, 5}, child_gap : i32 = 2, layout_dir : Layout_dir = .top_down,
						alignment_x : Alignment = .near, alignment_y : Alignment = .near, overflow : Overflow_dir = .right, abs_position : Maybe(Absolute_postion) = nil) -> Parameters {
	
	return Parameters {
		padding,
		child_gap,
		layout_dir,
		{ alignment_x, alignment_y },
		overflow,
		[2]Size{size_x, size_y},
		{min_size_x, min_size_y},
		{max_size_x, max_size_y},
		grow_weight,
		false,
		abs_position,
	}
}

text_parameters :: proc (text : string, size : f32, font : int, min_size_x : Min_size = 0, min_size_y : Min_size = 0, max_size_x : Max_size = max(i32), max_size_y : Max_size = max(i32),
						grow_weight : i32 = 1, padding : [4]i32 = {5, 5, 5, 5}, child_gap : i32 = 2, layout_dir : Layout_dir = .top_down,	alignment_x : Alignment = .near,
						alignment_y : Alignment = .near, overflow : Overflow_dir = .right, split_on_dash := true, tab_width : i32 = 4, abs_position : Maybe(Absolute_postion) = nil) -> Parameters {
	
	return Parameters {
		padding,
		child_gap,
		layout_dir,
		{ alignment_x, alignment_y },
		overflow,
		Text{text, size, font},
		{min_size_x, min_size_y},
		{max_size_x, max_size_y},
		grow_weight,
		split_on_dash,
		abs_position,
	}
}

Meassure_text_width_callback :: proc (text : string, size : f32, font : int) -> i32
Meassure_text_height_callback :: proc (size : f32, font : int) -> i32
Meassure_line_gap_callback :: proc (size : f32, font : int) -> i32

make_layout_state :: proc (meas_width : Meassure_text_width_callback, meas_height : Meassure_text_height_callback,
							meas_line_gap :  Meassure_line_gap_callback, ls : ^Layout_state = nil, params : Parameters = default_root_params) -> ^Layout_state {
	ls := ls;
	
	if ls == nil {
		ls = new(Layout_state);
		ls.self_free = true
	}
	
	ne := new(Element);
	ne^ = {
		nil, 
		make([dynamic]^Element),
		make([dynamic]^Element),
		make([dynamic]^Element),
		{0,0},
		{0,0},
		nil,
		"root",
		
		params,
	}

	ls.root = ne;

	ls.meas_width = meas_width;
	ls.meas_height = meas_height;
	ls.meas_line_gap = meas_line_gap;

	return ls;
}

destroy_laytout_state :: proc (ls : ^Layout_state) {
	delete(ls.elements);
	delete(ls.element_stack);
	delete(ls.draw_commands);
	destroy_element(ls.root)
	if ls.self_free {
		free(ls);
	}
}

default_root_params : Parameters = {
	{0,0,0,0}, //padding
	{0,0}, //child gap
	.top_down, //for the sub-elements
	{.near, .near}, //where should we align the children to
	.right,

	//How does this size behave
	[2]Size{0,0},
	{0,0}, //min size
	{max(i32), max(i32)}, //max size
	1,

	false,

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

open_element :: proc (ls : ^Layout_state, params : Parameters, debug_name : cstring = "") {
	assert(ls.has_begun, "you must begin the layout state once at the start of the frame");
	
	ne := new(Element);
	ne.param = params;
	ne.debug_name = debug_name;
	
	if t, ok := ne.param.sizing.(Text); ok {
		t.text = strings.clone(t.text, context.temp_allocator);
		ne.param.sizing = t;
	}
	
	if len(ls.element_stack) != 0 {
		ne.parent = ls.element_stack[len(ls.element_stack)-1];
		append(&ne.parent.children, ne);
	}
	else {
		ne.parent = ls.root;
		append(&ne.parent.children, ne);
	}

	if _, ok := ne.param.abs_position.?; ok {
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
	
	//size horizontally only, vertically is done in the end
	do_size_fit(ls, elem, 0);
}

//WHEN WE DO A TEXT ELEMENT, WE NEED TO MAKE IT SO THAT IT SETS A PREFERED WIDTH BEFORE THE FIT AND EXPAND; THIS MEANS THAT WHEN WE FIT WE WILL TRY TO FIT THE TEXT AND WHEN WE EXPAND IT 
//WILL ALSO TAKE INTO ACCOUNT THE TEXT WIDTH; THAT SAID THE WIDTH OF THE TEXT SHOULD MAYBE BE SHARED WITH THE GROW ELEMETNS? OR NOT? NOT REALLY RIGHT; SO IT SHOULD TAKE UP AS MUCH SPACE AS POSSIABLE
//THEN IT FAILS TO DO SO AND WE MAKE IT SMALLER AND WRAP IT AT STAGE 3. SO NEXT UP HOW DO WE MAKE IT TAkE UP AS MUCH SPACE AS POSSIABLE; WELL WE JUST SET IT S MAX SIZE AND SET IT TO GROW, THAT IS BASICLY IT

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
		do_expand_and_shrink_recursive(ls, ls.root, 0, &ls.draw_commands);
	}

	{ //3. wrap text
		//we need to do a reverse breath first search
		do_text_height_recursive(ls, ls.root)
	}

	{ //4. fit sizing heigths
		do_fit_recursive :: proc (ls : ^Layout_state, elem : ^Element, axis : int) {
			for c in elem.children {
				do_fit_recursive(ls, c, axis)
			}
			do_size_fit(ls, elem, axis);
		}
		
		//we need to do a reverse breath first search
		do_fit_recursive(ls, ls.root, 1)
	}
	
	{ //5. grow and shrink heigths
		do_expand_and_shrink_recursive(ls, ls.root, 1, &ls.draw_commands);
	}
	
	{ //6. position
		do_position_recursive(ls.root, {0,0});
	}

	{ //7. draw commands
		clear(&ls.draw_commands);
		
		draw_elem :: proc(ls : ^Layout_state, elem : ^Element, commands : ^[dynamic]Element_layout) {

			el : Element_layout
			if elem.text_to_draw == nil {
				el = {
					size = elem.size,
					position = elem.position,
				}
			}
			else {
				t := elem.sizing.(Text)

				line_height := ls.meas_height(t.size, t.font) + ls.meas_line_gap(t.size, t.font)
				lines := make([]Text_line, len(elem.text_to_draw), context.temp_allocator)
				
				vertical_offset : i32 = 0
				#reverse for ttd, i in elem.text_to_draw {
					lines[i] = Text_line{vertical_offset, ttd}
					vertical_offset += line_height;
				}
				defer delete(elem.text_to_draw)

				el = {
					elem.size,
					elem.position,
					t.size,
					t.font,
					lines,
				}
			}

			append(commands, el);

			for child in elem.children {
				draw_elem(ls, child, commands);
			}
		}
		
		for child in ls.root.children {
			draw_elem(ls, child, &ls.draw_commands);
		}
	}

	assert(len(ls.element_stack) == 0, "Popped too few elements", loc);
	for e in ls.elements {
		destroy_element(e)
	}
	clear(&ls.elements);

	clear(&ls.root.children)
	clear(&ls.root.in_flow)
	clear(&ls.root.out_flow)

	return ls.draw_commands[:];
}

@(private="file")
destroy_element :: proc (e : ^Element) {
	delete(e.children)
	delete(e.in_flow)
	delete(e.out_flow)
	free(e);
}

@(private="file")
do_text_height_recursive :: proc (ls : ^Layout_state, elem : ^Element) {
	for c in elem.children {
		do_text_height_recursive(ls, c);
	}
	for &c in elem.in_flow {
		switch what in c.sizing {
			case [2]Size: {
				//nothing
			}
			case Text: {
				max_size := c.size.x;

				cur_line := strings.builder_make();
				defer strings.builder_destroy(&cur_line);
				cur_word := strings.builder_make();
				defer strings.builder_destroy(&cur_word);
				
				//find the line count
				i := 0
				for r in what.text {
					//0xA0 is a space that may not be line-wrapped
					if (unicode.is_white_space(r) && r != 0xA0) || (r == '-' && strings.builder_len(cur_word) > 0 && elem.split_on_dash) {
						width := ls.meas_width(strings.concatenate({strings.to_string(cur_line), strings.to_string(cur_word), fmt.tprintf("%v", r)}, context.temp_allocator), what.size, what.font)
						
						if r == '-' {
							log.warnf("TODO correct - behvaior when wrapping UI text")
							strings.write_rune(&cur_word, r)
						}
						
						if width > max_size {
							//there is not space for this word, so print the current line and then
							if strings.builder_len(cur_line) != 0 {
								append(&c.text_to_draw, strings.clone(strings.to_string(cur_line), context.temp_allocator));
								strings.builder_reset(&cur_line)
							}
							strings.write_string(&cur_line, strings.to_string(cur_word))
							strings.builder_reset(&cur_word)
						}
						else {
							//this write this word to the line
							if r == '\n' {
								append(&c.text_to_draw, strings.clone(strings.to_string(cur_line), context.temp_allocator));
								strings.builder_reset(&cur_line)
								panic("TODO, not right")
							}
							else if r == ' ' {
								strings.write_rune(&cur_line, r) //write the whitespace charactor
							}
							else if r == '-' || r == '\r' || r == '\t' { //tab size is handled from user side
								//ignore
							}
							else {
								fmt.panicf("whitespace type '%h' not supported", cast(int) r);
							}
							strings.write_string(&cur_line, strings.to_string(cur_word))
							strings.builder_reset(&cur_word)
						}
					}
					else if r == 0xA0 {
						strings.write_rune(&cur_word, ' ') //translate to a normal space
					}
					else {
						strings.write_rune(&cur_word, r)
					}
					i += 1;
				}
				strings.write_string(&cur_line, strings.to_string(cur_word))
				append(&c.text_to_draw, strings.clone(strings.to_string(cur_line), context.temp_allocator));
				
				h := ls.meas_height(what.size, what.font);
				baseline_step := ls.meas_height(what.size, what.font) + ls.meas_line_gap(what.size, what.font)
				for i in 0..<len(c.text_to_draw)-1 {
					h += baseline_step
				}
				c.size.y = h
			}
		}
	}
}

//grow children to fit the parent
@(private="file")
do_expand_and_shrink_recursive :: proc(ls : ^Layout_state, elem : ^Element, axis : int, commands : ^[dynamic]Element_layout) {
	//We must do 2 things in this function
	//first, the primary axis must look at its children to find all the ones the must grow.
	//secoudly I must grow my children if i am on the non-primary
	
	Expandus :: struct{elem : ^Element, min_width : i32, max_size : i32}
	expand_in_flow : [dynamic]Expandus; //the children whom needs to grow
	defer delete(expand_in_flow);
	shrink_in_flow : [dynamic]Expandus;
	defer delete(shrink_in_flow);

	for c in elem.in_flow {
		switch what in c.sizing {
			case [2]Size: {
				switch t in what[axis] {
					case i32, Fit:
						//Do nothing
					case Parent_ratio:
						//here we know the size of the parent, so we set its size to be that
						c.size[axis] = cast(i32) (cast(f32)elem.size[axis] * t.rel_size);
						//fmt.printf("eval_min_size(c, axis), eval_max_size(c, axis : %v, %v\n", eval_min_size(c, axis), eval_max_size(c, axis))
						c.size[axis] = math.clamp(c.size[axis], eval_min_size(c, axis), eval_max_size(c, axis));
					case Grow, Grow_fit:
						append(&expand_in_flow, Expandus{c, 0, max(i32)});
				}
			}
			case Text: {
				//Text should expand if we are expanding the horizontal axis
				//Text should not expand beyond the max text size, but it should be part of this expand loop
				if axis == 0 {
					max_width := ls.meas_width(what.text, what.size, what.font);
					min_width := find_min_text_width(ls, what.text, what.size, what.font)
					append(&shrink_in_flow, Expandus{c, min_width, max_width});
				}
			}
		}
	}
	
	if is_primary_axis(elem, axis) { //all this is just for the primary axis

		//TODO this parent ratio needs to happen here, we have just set the parents size and we should now look at what it is to set our prefered size
		remaning_width := elem.size[axis] - elem.padding[axis] - elem.padding[axis + 2];
		
		//how much width is there in total and how much weight, we can use to determine how many pixels a single width is worth
		for child in elem.in_flow {
			remaning_width -= child.size[axis];
		}
		remaning_width -= (cast(i32) len(elem.in_flow) - 1) * elem.child_gap[axis];
		total_width := remaning_width;
		
		total_weight : i32 = 0;
		for child in expand_in_flow {
			total_weight += child.elem.grow_weight;
		}

		for remaning_width > 0 && len(expand_in_flow) != 0 {
			least_pressence : i32 = max(i32)
			next_least_pressence : i32 = max(i32)
			
			for thing, i in expand_in_flow {
				child := thing.elem
				if child.grow_weight * child.size[axis] < least_pressence {
					next_least_pressence = least_pressence;
					least_pressence = child.grow_weight * child.size[axis];
				}
				if child.grow_weight * child.size[axis] != least_pressence {
					next_least_pressence = math.min(next_least_pressence, child.grow_weight * child.size[axis]);
				}
			}
			
			#reverse for thing, i in expand_in_flow {
				child := thing.elem
				consumed : i32;

				if len(expand_in_flow) == 1 { //we do give the last element the rest of the width, this is a way to handle floating point precision.
					consumed = remaning_width;
				}
				else {
					if next_least_pressence == max(i32) {
						//they are all the same, just expand by weight
						consumed = cast(i32)math.round(cast(f32)total_width * cast(f32)child.grow_weight / cast(f32)total_weight);
					} else {
						//consume until the least pressence becomes the same as the next_least_pressence, get this childs current pressence, if it is the least expand to next_least
						if child.grow_weight * child.size[axis] == least_pressence {
							consumed = math.max(1, cast(i32)math.round((cast(f32)next_least_pressence - cast(f32)least_pressence) / cast(f32)child.grow_weight));
						}
						else {
							consumed = 0;
							continue;
						}
					}
				}
				
				//if child.size[axis] + consumed becomes larger then eval_max_size(elem, axis), then subtract the differnce from consumed, this means we will enforce the elements max_size
				consumed -= math.max(0, (child.size[axis] + consumed) - math.min(eval_max_size(elem, axis), thing.max_size));

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
		
		//we want to shrink the item with the mose pressence so they all become closer to the same size if they take up too much space
		for remaning_width < 0 && len(shrink_in_flow) != 0 {
			most_pressence : i32 = 0
			next_most_pressence : i32 = 0
			
			for thing, i in shrink_in_flow {
				child := thing.elem
				if child.size[axis] > most_pressence {
					next_most_pressence = most_pressence;
					most_pressence = child.size[axis];
				}
				if child.size[axis] != most_pressence {
					next_most_pressence = math.max(next_most_pressence, child.size[axis]);
				}
			}

			#reverse for thing, i in shrink_in_flow {
				child := thing.elem
				consumed : i32;
				
				if i == 0 { //we do give the last element the rest of the width, this is a way to handle floating point precision.
					consumed = -remaning_width; //consumed is positive like 200
				}
				else {
					if next_most_pressence == 0 {
						//they are all the same, just expand by weight
						consumed = cast(i32)math.round(cast(f32)-total_width);
					} else {
						consumed = math.max(1, cast(i32)math.round((cast(f32)next_most_pressence - cast(f32)most_pressence)));
					}
				}
				
				//if child.size[axis] + consumed becomes larger then eval_max_size(elem, axis), then subtract the differnce from consumed, this means we will enforce the elements max_size
				consumed -= math.max(0, math.max(eval_min_size(elem, axis), thing.min_width) - (child.size[axis] - consumed)); //consumed is still positive like 200
				//fmt.printf("child.size[axis] - consumed : %v, eval_min_size(elem, axis) : %v, thing.min_width : %v\n", child.size[axis] - consumed, eval_min_size(elem, axis), thing.min_width)
				//fmt.printf("consumed : %v of %v from %v, remaining before : %v, remaning now : %v\n", consumed, child.size[axis], child.debug_name, remaning_width, remaning_width + consumed)
				
				if consumed == 0 {
					ordered_remove(&shrink_in_flow, i);
				}
				else {
					child.size[axis] -= consumed;
					remaning_width += consumed;
				}
			}
		}
		
		elem.size[axis] = math.clamp(elem.size[axis], eval_min_size(elem, axis), eval_max_size(elem, axis));
	}
	else { //this is for the non-primary axis, it needs to be applied for all children even if this current element is not on the primary axis.
		//simply move this down to the max size (that is the size of the parent - padding)
		for thing in expand_in_flow {
			child := thing.elem
			child.size[axis] = elem.size[axis] - elem.padding[axis] - elem.padding[axis+2]; 
			elem.size[axis] = math.clamp(elem.size[axis], eval_min_size(elem, axis), eval_max_size(elem, axis));
		}
		for thing in shrink_in_flow {
			child := thing.elem
			child.size[axis] = elem.size[axis] - elem.padding[axis] - elem.padding[axis+2]; 
			elem.size[axis] = math.clamp(elem.size[axis], eval_min_size(elem, axis), eval_max_size(elem, axis));
		}		
	}

	//recurse down the tree in DFS
	for child in elem.children {
		do_expand_and_shrink_recursive(ls, child, axis, commands);
	}
}

@(private="file")
do_size_fit :: proc (ls : ^Layout_state, elem : ^Element, axis : int) {

	switch what in elem.sizing { 
		case [2]Size: {
			switch sizing in what[axis] { //calculate the size of the element, we know it here
				case Fixed: {
					elem.size[axis] = sizing;
				}
				case Fit, Grow_fit: {
					elem.size[axis] = get_fit_space(elem, axis);
				}
				case Parent_ratio:
					//we dont know the size of the parent, so we calculate later
					elem.size[axis] = 0;
				case Grow: {
					//grow does not make space for children
					elem.size[axis] = 0;
				}
			}
		}
		case Text: {
			if axis == 0 {
				elem.size[axis] = ls.meas_width(what.text, what.size, what.font)
			}
			else {
				//The text size heights are handled elsewhere, in the text wrapping logic and is already set
			}
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
					center_off := (inner_box[axis + 2] - total_child_size) / 2;
					switch elem.overflow {
						case .right:
							center_off = max(0, center_off);
						case .equal:
							//nothing
						case .left:
							panic("TODO, this is not easy to solve, i think");
					}
					
					if reverse {
						child.position[axis] += inner_box[axis] + inner_box[axis + 2] - internal_offset - child.size[axis] - center_off;
					}
					else {
						child.position[axis] += inner_box[axis] + internal_offset + center_off; //we undo the origianl offset from the padding here.
					}
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
	
	for child, i in elem.out_flow {
		if abs, ok := child.abs_position.?; ok {
			child.position = position_abs_rect(abs.anchor, abs.self_anchor, abs.axis, abs.offset, child.size, elem.position, elem.size);
		}
		else {
			panic("out of flow must be abs position");
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
	fmt.assertf(elem.max_size[axis] != nil, "element %v has max size that is nil", elem.debug_name);
	
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
			//panic("todo, this does not work for centered abs position elements")
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

@(private="file")
position_abs_rect :: proc(anchor : Anchor_point, self_anchor : Anchor_point, axis : Axis, child_offset, child_size, parent_pos, parent_size : [2]i32) -> [2]i32 {
	offset := [2]i32{0, 0};
	parent_rect := [4]i32{parent_pos.x, parent_pos.y, parent_size.x, parent_size.y};

	switch self_anchor {
		
		case .bottom_left:
			//No code required

		case .bottom_center:
			offset.x = -child_size.x / 2;

		case .bottom_right:
			offset.x = -child_size.x

		case .center_left:
			offset.y = -child_size.y / 2;

		case .center_center:
			offset.x = -child_size.x / 2;
			offset.y = -child_size.y / 2;
		
		case .center_right:
			offset.x = -child_size.x
			offset.y = -child_size.y / 2;

		case .top_left:
			offset.y = -child_size.y
		
		case .top_center:
			offset.x = -child_size.x / 2
			offset.y = -child_size.y

		case .top_right:
			offset.x = -child_size.x
			offset.y = -child_size.y		
		
		case: // default
			unreachable();
	}
	
	offset += parent_rect.xy;

	switch anchor {

		case .bottom_left	 :
			//No code required

		case .bottom_center   :
			offset.x += parent_rect.z / 2;
			
		case .bottom_right	:
			offset.x += parent_rect.z;

		case .center_left  :
			offset.y += parent_rect.w / 2;

		case .center_center:
			offset.x += parent_rect.z / 2;
			offset.y += parent_rect.w / 2;
		
		case .center_right :
			offset.x += parent_rect.z
			offset.y += parent_rect.w / 2;

		case .top_left  :
			offset.y += parent_rect.w;

		case .top_center:
			offset.x += parent_rect.z / 2;
			offset.y += parent_rect.w;

		case .top_right :
			offset.x += parent_rect.z;
			offset.y += parent_rect.w;

		case: // default
			unreachable();
	}
	
	switch axis {
		
		case .up_right:
			offset += child_offset;

		case .up_left:
			offset += {-child_offset.x, child_offset.y};
		
		case .down_right:
			offset += {child_offset.x, -child_offset.y};

		case .down_left:
			offset += {-child_offset.x, -child_offset.y};

		case: // default
			unreachable();
	}

	return offset;
}

@(private="file")
find_min_text_width :: proc(ls : ^Layout_state, text : string, size : f32, font : int) -> i32 {
	
	b := strings.builder_make();
	defer strings.builder_destroy(&b);

	//max_string := ""
	max_size : i32 = 0;
	
	i := 0
	for r in text {
		if unicode.is_white_space(r) {
			width := ls.meas_width(strings.to_string(b), size, font)
			if width > max_size {
				max_size = width
				//max_string = strings.clone(strings.to_string(b), context.temp_allocator)
			}
			strings.builder_reset(&b)
		}
		else {
			strings.write_rune(&b, r)
		}

		i += 1
	}
	
	return auto_cast max_size

}

