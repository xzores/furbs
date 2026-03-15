package furbs_layman;

import "core:math"
import "core:slice"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "base:runtime"
import "core:strings"

import "../laycal"

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																	
//		The point of this is to create a persistents state for the gui elements (implemented on top of this) and manage the hot path.
//		That is it know what element is currently begin hovered, clicked or was clicked (and is now active)
//		Also it manages if the order of elements needs to be changed, that is if there are elements which orders can be swapped, like in a window system.
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

	scissor_stack : [dynamic][4]f32,

	hot : Unique_id,
	active : Unique_id,
	next_hot : Unique_id,
	next_active : Unique_id,
	
	highest_priority : u32,
	prio_cnt : u32,
	
	last_rect : map[Unique_id][4]i32,

	originations : map[Unique_look_up]int, //resets every frame
	
	items : [dynamic]Item_or_pop,
	items_shadow_stack : [dynamic]int, //this will act like a stack instead of recording so that we know the type when we do a pop, this points to the items array

	self_free : bool,
}

Cmd_rect :: struct {
	rect : [4]f32,
	element_kind : int, //use this to store what kind element needs to be rendered.
	state : Display_state,
}

Text_line :: laycal.Text_line;

Cmd_text :: struct {
	rect : [4]f32,
	text_size : f32, 
	font : int,
	lines : []Text_line,
	type : int,
	rotation : f32, //rotation around the begining of the baseline 
}

Cmd_scissor :: struct{
	area : [4]f32,
}

Cmd_scissor_disable :: struct {}

Command :: union {
	Cmd_rect,
	Cmd_text,
	Cmd_scissor, 			//this should automaticly enable the scissor stack
	Cmd_scissor_disable,	//disable it
}

Overflow :: struct {
	x : bool, //show overflow
	y : bool, //show overflow
}

default_overflow := Overflow {false, false}

@private
Item :: struct {
	type : int,
	text : string,
	overflow : Maybe(Overflow),
	uid : Maybe(Unique_id),
	layout : Layout,
	transform : Transform,
}

@private
Pop :: struct {
	pop_scissor : bool,
}

@(private)
Item_or_pop :: struct {
	what : union {
		Item,
		Pop,
	},
	loc : runtime.Source_Code_Location,
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

Meassure_width_callback 	:: laycal.Meassure_text_width_callback 
Meassure_height_callback 	:: laycal.Meassure_text_height_callback 
Meassure_gap_callback 		:: laycal.Meassure_line_gap_callback 

init :: proc (meas_width : Meassure_width_callback, meas_height : Meassure_height_callback, meas_line_gap :  Meassure_gap_callback, lm : ^Layout_mananger = nil) -> ^Layout_mananger {
	lm := lm;

	if lm == nil {
		lm = new(Layout_mananger);
	}

	laycal.make_layout_state(meas_width, meas_height, meas_line_gap, &lm.ls);
	
	return lm;
}

destroy :: proc (lm : ^Layout_mananger) {
	laycal.destroy_laytout_state(&lm.ls);
	delete(lm.scissor_stack)
	delete(lm.originations)
	delete(lm.items)
	delete(lm.last_rect)
	delete(lm.items_shadow_stack)
	if lm.self_free {
		free(lm)
	}
}

begin :: proc (lm : ^Layout_mananger, screen_size : [2]i32) {
	clear(&lm.originations)
	laycal.begin_layout_state(&lm.ls, screen_size);
}

///////////////////////////////////////////////////////////////////////////////////////

@(require_results)
end :: proc (lm : ^Layout_mananger, loc := #caller_location) -> ([]Command) {

	clear(&lm.last_rect);

	Proto_scissor_push :: struct {
		overflow : Overflow,
		layout_lookup : int,
	}

	Proto_rect :: struct {
		kind : int,
		text : string,
		layout_lookup : int,
		uid : Maybe(Unique_id),
		transform : Transform
	} //int to lookup in the elem
	
	Proto_scissor_pop :: struct {}

	Proto_command :: union {
		Proto_rect,
		Proto_scissor_push,
		Proto_scissor_pop,
	}

	proto_commands := make([dynamic]Proto_command, 0, len(lm.items), context.temp_allocator) //half the size because for every push there is a pop
	
	defer laycal.end_layout_state(&lm.ls);

	lc_count := 0;
	for opt in lm.items {
		switch o in opt.what {
			case Item: {
				//log.debugf("interpolated_params : %v\n", interpolated_params);
				laycal.open_element(&lm.ls, o.layout, fmt.ctprint("", opt.loc));
				append_elem(&proto_commands, Proto_rect{o.type, o.text, lc_count, o.uid, o.transform});
				if overflow, ok := o.overflow.?; ok {
					append(&proto_commands, Proto_scissor_push{overflow, lc_count})
				}
				lc_count += 1;
			}
			case Pop: {
				if o.pop_scissor {
					append(&proto_commands, Proto_scissor_pop{});
				}
				laycal.close_element(&lm.ls);
			}
		}
	}
	
	commands := make([dynamic]Command, 0, len(proto_commands), context.temp_allocator)
	elems := laycal.end_layout_state(&lm.ls);
	assert(len(proto_commands) >= len(elems));
	
	for proto, i in proto_commands {
		cmd : Command;
		
		switch v in proto {
			case Proto_rect: {
				elem := elems[v.layout_lookup]
				if uid, ok := v.uid.?; ok {
					lm.last_rect[uid] = [4]i32{elem.position.x, elem.position.y, elem.size.x, elem.size.y}
				}
				if v.text == "" {
					cmd = Cmd_rect {
						[4]f32{auto_cast elem.position.x, auto_cast elem.position.y, auto_cast elem.size.x, auto_cast elem.size.y},
						v.kind,
						.cold,
					}
				}
				else {
					cmd = Cmd_text {
						[4]f32{auto_cast elem.position.x, auto_cast elem.position.y, auto_cast elem.size.x, auto_cast elem.size.y},
						elem.text_size,
						elem.font,
						elem.lines,
						v.kind,
						0, //rotation around the begining of the baseline 
					}
				}
			}
			case Proto_scissor_push: {
				elem := elems[v.layout_lookup]
				clip := [4]f32{math.inf_f32(-1), math.inf_f32(-1), math.inf_f32(1), math.inf_f32(1)}
				if v.overflow.x == false {
					//if overflow = false then clipping = true and we should clip
					clip.x = auto_cast elem.position.x
					clip.z = auto_cast elem.size.x
				}
				if v.overflow.y == false {
					//if overflow = false then clipping = true and we should clip
					clip.y = auto_cast elem.position.y
					clip.w = auto_cast elem.size.y
				}
				if len(lm.scissor_stack) != 0 {
					last_scissor := lm.scissor_stack[len(lm.scissor_stack) - 1]
					clip = [4]f32{math.max(last_scissor.x, clip.x), math.max(last_scissor.y, clip.y),
									math.min(last_scissor.z, clip.z), math.min(last_scissor.w, clip.w)}
				}
				append(&lm.scissor_stack, clip)
				cmd = Cmd_scissor {
					clip,
				}
			}
			case Proto_scissor_pop: {
				pop(&lm.scissor_stack);
				if len(lm.scissor_stack) != 0 {
					cmd = Cmd_scissor {
						lm.scissor_stack[len(lm.scissor_stack) - 1],
					}
				}
				else {
					cmd = Cmd_scissor_disable {}
				}
			}
		}

		//TODO in the furture re-order these if there is push_orderable
		append(&commands, cmd)
	}
	
	lm.hot = lm.next_hot
	lm.active = lm.next_active
	lm.next_hot = {}
	lm.next_active = {}

	assert(len(lm.items_shadow_stack) == 0, "lm.items_shadow_stack was not length zero")
	assert(len(lm.scissor_stack) == 0, "length of scissor stack not zero")

	clear(&lm.items);
	return commands[:];
}

///////////////////////////////////////////////////////////////////////////////////////

//pushes a contrainer (might be drawn or not drawn) for things can be reordered by hot-path, like windows
//push_orderable :: proc(lm : ^Layout_mananger, type : Element_kind, layout : Layout, transform := default_transform) {}

//Pushes a text to be drawn
open :: proc (lm : ^Layout_mananger, kind : int, layout : Layout, uid : Maybe(Unique_id) = nil, overflow := default_overflow, transform := default_transform, loc := #caller_location) {
	layout := layout
	
	s : string
	if t, ok := &layout.sizing.(laycal.Text); ok {
		t.text = strings.clone(t.text, context.temp_allocator)
		s = t.text
	} 

	append(&lm.items_shadow_stack, len(lm.items))
	append(&lm.items, Item_or_pop{Item{kind, s, overflow, uid, layout, transform}, loc})
}

close :: proc(lm : ^Layout_mananger, loc := #caller_location) {
	index := pop(&lm.items_shadow_stack)
	#partial switch l in lm.items[index].what {
		case Item: {
			append_elem(&lm.items, Item_or_pop{Pop{l.overflow != nil}, loc})
		}
		case:
			fmt.panicf("found a %v", l)
	}
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
	panic("TODO")
}

//if you where active last frame always win the hot
//otherwise if uid is the same except for the sub_priority, then the highest sub_priority wins
try_set_hot :: proc (lm : ^Layout_mananger, uid : Unique_id, loc := #caller_location) {
	lm.next_hot = uid
}

//tries to set the currently pushed element to active
try_set_active :: proc (lm : ^Layout_mananger, uid : Unique_id) {
	lm.next_active = uid
}

current_active :: proc (lm : ^Layout_mananger) -> Unique_id {
	return lm.active
}

current_hot :: proc (lm : ^Layout_mananger) -> Unique_id {
	return lm.hot
}

get_rect :: proc (lm : ^Layout_mananger, uid : Unique_id) -> [4]i32 {
	//assert(uid in lm.last_rect, "not valid");
	//log.debugf("last_rect : %v", lm.last_rect);
	return lm.last_rect[uid]
}

//promote :: proc (lm : ^Layout_mananger, uid : Unique_id) -> bool {}

///////////////////////////////////////////////////////////////////////////////////////

@private
get_next_priority :: proc (lm : ^Layout_mananger) -> u32 {
	panic("TODO");
}

Layout_dir :: laycal.Layout_dir;
Alignment ::laycal.Alignment;
Anchor_point :: laycal.Anchor_point;
Axis :: laycal.Axis;
Size :: laycal.Size;
Sizeing :: laycal.Sizeing;
Min_size :: laycal.Min_size;
Max_size :: laycal.Max_size;
Absolute_postion :: laycal.Absolute_postion;
Overflow_dir :: laycal.Overflow_dir;

Fixed :: laycal.Fixed;
Parent_ratio :: laycal.Parent_ratio;
Fit :: laycal.Fit;
Grow :: laycal.Grow;
Grow_fit :: laycal.Grow_fit;
fit :: laycal.fit;
grow :: laycal.grow;
grow_fit :: laycal.grow_fit;

rect :: laycal.rect_parameters;
text :: laycal.text_parameters;
Layout :: laycal.Parameters;

acast :: linalg.array_cast;
