package furbs_layman;

import "core:math"
import "core:slice"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "base:runtime"

import "../laycal"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																	
//		The point of this is to create a persistents state for the gui elements (implemented on top of this) and manage the hot path.
//		That is it know what element is currently begin hovered, clicked or was clicked (and is now active)
//		Also it manages if the order of elements needs to be changed, that is if there are elements which orders can be swapped, like in a window system.
// 		It also swaps the cursor on hover or drag.
//																	
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//The manager does not know what is a button and how it behaves, it does not set any values.

/*
So it is responsiable for render order, active/hot/cold elements, clipping, opacity (that is a framebuffer) and caching.

An elements is opened and then all elements inside that belongs to that (so a tree), from here it is possiable.
Each open has a uid
TODO remember what the nuaceces of the UID is.

So since we need all drawn things to have some UID? (or do we, should there be a difference, a single UID can draw many thigns?)
Yes a single UID can have things draw before and after its sub-elements.

so opening a uid means giving a list of layout/visual/transforms to the layout manager.
*/

///////////////////////////////////////////////////////////////////////////////////////

Unique_id :: struct {
	src : runtime.Source_Code_Location,
	element_number : int,
	is_call_count : bool,
}

Unique_look_up :: struct {
	src : runtime.Source_Code_Location,
	user_id : int,
}

Key_state :: enum {
	up,
	pressed,
	down,
	released,
}

Layout_mananger :: struct {
	ls : laycal.Layout_state,

	hot : Unique_id,
	active : Unique_id,
	next_hot : Unique_id,
	next_active : Unique_id,
	
	highest_priority : u32,
	prio_cnt : u32,
	
	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,
	mouse_state : Key_state,

	originations : map[Unique_look_up]int, //resets every frame

	items : [dynamic]Item_or_pop,
}

init :: proc (lm : ^Layout_mananger = nil) -> ^Layout_mananger {
	lm := lm;

	if lm == nil {
		lm = new(Layout_mananger);
	}

	laycal.make_layout_state(&lm.ls);
	
	return lm;
}

destroy :: proc (lm : ^Layout_mananger) {
	laycal.destroy_laytout_state(&lm.ls);
}

begin :: proc (lm : ^Layout_mananger, screen_size : [2]i32) {
	laycal.begin_layout_state(&lm.ls, screen_size);
}

Transform :: struct {
	offset : [2]int,
	offset_anchor : Anchor_point,
	size_multiplier : f32,
	size_anchor : Anchor_point,
	rotation : f32,
	rotation_anchor : Anchor_point,
}

default_transform := Transform {
	{0,0},
	.center_center,
	1,
	.center_center,
	0,
	.center_center,
}

///////////////////////////////////////////////////////////////////////////////////////

To_draw :: struct {
	type : Type_number, //This is an indicator that tells you how to draw it, set by you
	text : string, //is non-empty ("") for string only
	rect : [4]f32, 
}

@private
Item :: struct {
	type : Type_number,
	text : string,
	layout : Layout,
	transform : Transform,
}

Pop :: struct {}

@(private)
Item_or_pop :: struct {
	what : union {
		Item,
		Pop,
	},
	loc : runtime.Source_Code_Location,
}

//time: what is the current time.
@(require_results)
end :: proc (lm : ^Layout_mananger, loc := #caller_location) -> []To_draw {
	item := make([dynamic]Item, 0, len(lm.items) / 2, context.temp_allocator) //half the size because for every push there is a pop
	
	defer laycal.end_layout_state(&lm.ls);

	for opt in lm.items {
		switch o in opt.what {
			case Item: {
				//log.debugf("interpolated_params : %v\n", interpolated_params);
				laycal.open_element(&lm.ls, o.layout, fmt.ctprint("", opt.loc));
				append_elem(&item, o);
			}
			case Pop: {
				laycal.close_element(&lm.ls);
			}
		}
	}

	to_draw := make([]To_draw, len(item), context.temp_allocator)
	elems := laycal.end_layout_state(&lm.ls);
	assert(len(item) == len(elems))
	assert(len(item) == len(to_draw))
	for e, i in elems {
		itm := item[i];
		
		//TODO in the furture re-order these if there is push_orderable

		to_draw[i] = To_draw {
			itm.type,
			itm.text,
			{cast(f32)e.position.x, cast(f32)e.position.y, cast(f32)e.size.x, cast(f32)e.size.y},
		}
	}
	
	clear(&lm.items);
	return to_draw;
}

///////////////////////////////////////////////////////////////////////////////////////

Display_state :: enum {
	cold, 
	hot,
	active,
}

//create a new uid only do this when a new element is shown
@(require_results)
make_uid :: proc (lm : ^Layout_mananger, dont_touch : runtime.Source_Code_Location, user_id : int = 0) -> Unique_id {
	
	special_number : int;
	is_call_count : bool;

	if user_id != 0 {
		special_number = user_id;
		is_call_count = false;
	}
	else {
		special_number = lm.originations[{dont_touch, user_id}];
		lm.originations[{dont_touch, user_id}] += 1;
		is_call_count = true;
	}
	
	uid := Unique_id {
		dont_touch,
		special_number,
		is_call_count,
	}
	
	return uid;
}

//This is not strictly need, but can be used to forget the state of an element 
forget_uid :: proc (lm : ^Layout_mananger, uid : Unique_id) {
	
}

//the uid is a candidate to become active, like if it hovered
@(require_results)
is_hot :: proc(lm : ^Layout_mananger, uid : Unique_id) -> bool {
	panic("TODO");
}

//the uid is active, that is it is currectly being interacted with
@(require_results)
is_active :: proc(lm : ^Layout_mananger, uid : Unique_id) -> bool {
	panic("TODO");
}

//if you where active last frame always win the hot
//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
try_set_hot :: proc (lm : ^Layout_mananger, uid : Unique_id) {
	
}

//tries to set the currently pushed element to active
try_set_active :: proc (lm : ^Layout_mananger, uid : Unique_id) {

}

//promote :: proc (lm : ^Layout_mananger, uid : Unique_id) -> bool {} 

///////////////////////////////////////////////////////////////////////////////////////

Type_number :: distinct int

//pushes a contrainer (might be drawn or not drawn) for things can be reordered by hot-path, like windows
//push_orderable :: proc(lm : ^Layout_mananger, type : Type_number, layout : Layout, transform := default_transform) {}

//Pushes a rect (might be drawn or not drawn)
push_rect :: proc (lm : ^Layout_mananger, type : Type_number, layout : Layout, transform := default_transform, loc := #caller_location) {
	append_elem(&lm.items, Item_or_pop{Item{type, "", layout, transform}, loc})
}

//Pushes a selectiable, that can be hot and active (might be drawn or not drawn)
//push_selectiable :: proc(lm : ^Layout_mananger, type : Type_number, uid : Unique_id, layout : Layout, transform := default_transform, loc := #caller_location) {}

//Pushes a text to be drawn
push_text :: proc (lm : ^Layout_mananger, type : Type_number, text : string, layout : Layout, transform := default_transform, loc := #caller_location) {
	panic("TODO");
}

//pops any of the above
pop :: proc(lm : ^Layout_mananger, loc := #caller_location) {
	append_elem(&lm.items, Item_or_pop{Pop{}, loc})
}

///////////////////////////////////////////////////////////////////////////////////////

@private
get_next_priority :: proc (lm : ^Layout_mananger) -> u32 {
	panic("TODO");
}

/*
Panel :: struct {
	scroll_offset : [2]f32,
	virtual_size : [2]f32, //the size which there exists items/elements
	
	use_scissor : bool, 
	enable_hor_scroll : bool,
	enable_ver_scroll : bool,
	
	uid : Maybe(Unique_id),
}

Node :: struct {
	uid : Unique_id,
	sub_nodes : [dynamic]^Node,
	sub_commands : [dynamic]Sub_command,
	parent : ^Node,
	is_overlay : bool,
	
	refound : bool,
}
*/

Layout_dir :: laycal.Layout_dir;
Alignment ::laycal.Alignment;
Anchor_point :: laycal.Anchor_point;
Axis :: laycal.Axis;
Size :: laycal.Size;
Min_size :: laycal.Min_size;
Max_size :: laycal.Max_size;
Absolute_postion :: laycal.Absolute_postion;
Overflow :: laycal.Overflow;

Fixed :: laycal.Fixed;
Parent_ratio :: laycal.Parent_ratio;
Fit :: laycal.Fit;
Grow :: laycal.Grow;
Grow_fit :: laycal.Grow_fit;
fit :: laycal.fit;
grow :: laycal.grow;
grow_fit :: laycal.grow_fit;

layout :: laycal.parameters;
Layout :: laycal.Parameters;

acast :: linalg.array_cast;

/*
///////////////////////////////////////////////////////////////////////////////////////

Text_type :: enum {
	button_text,
	checkbox_text,
	title_text,
	menu_item,
}

///////////////////////////////////////////////////////////////////////////////////////

Cmd_scissor :: struct{
	area : [4]f32,
	enable : bool,
}; //

Cmd_rect :: struct {
	rect : [4]f32,
	element_kind : i32, //use this to store what kind element needs to be rendered. 
	part_kind  : i32, //use this to store what, use this to store if it the border or background or whatever.
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
*/