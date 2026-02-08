package furbs_layman;

import "core:crypto/legacy/sha1"
import "core:math"
import "core:slice"
import "core:fmt"
import "core:log"
import "vendor:OpenEXRCore"
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
//It only supports rects (and rounded rects).

/*
So it is responsiable for collision detection, render order, active/hot/cold elements, cursor management, clipping, opacity (that is a framebuffer) and caching.

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
	call_count : i32,
	user_number : i32,
}

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

Layout_mananger :: struct {
	ls : laycal.Layout_state,
	
	font_size : f32,
	panel_stack : [dynamic]Panel,
	scissor_stack : [dynamic]Cmd_scissor,

	hot : Unique_id,
	active : Unique_id,
	next_hot : Unique_id,
	next_active : Unique_id,
	to_promote : ^Node, //This is used to figure out what elements go in top of what other elements

	highest_priority : u32,
	prio_cnt : u32,
	
	root : ^Node,
	current_node : ^Node,
	uid_to_node : map[Unique_id]^Node,
	priorities : map[^Node]u16, //last priorties used to control which one is next_active and next_hot

	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,
	mouse_state : Key_state,

	current_cursor : Cursor_type,
	next_cursor : Cursor_type,

	originations : map[Unique_look_up]int, //resets every frame

	items : [dynamic]Item_or_pop,
	
	//stored here for speed increase
	renders : [dynamic]Command,
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

init :: proc (lm : ^Layout_mananger = nil) -> ^Layout_mananger {
	lm := lm;

	if lm == nil {
		lm = new(Layout_mananger);
	}

	laycal.make_layout_state(&lm.ls);
	layren.make_layout_render(&lm.lr);
	
	return lm;
}

destroy :: proc (lm : ^Layout_mananger) {
	laycal.destroy_laytout_state(&lm.ls);
	layren.destroy_layout_render(&lm.lr);
}

begin :: proc (lm : ^Layout_mananger) {
	laycal.begin_layout_state(&lm.ls, render.get_render_target_size(render.get_current_render_target()));
}

Transform :: struct {
	offset : [2]int,
	offset_anchor : Anchor_point,
	size_multiplier : f32,
	size_anchor : Anchor_point,
	rotation : f32,
	rotation_anchor : Anchor_point,
}

@(private="file")
Item :: struct {
	layout : Layout,
	transform : Transform,
}

Layout :: laycal.Parameters;

default_transform := Transform {
	{0,0},
	.center_center,
	1,
	.center_center,
	0,
	.center_center,
}

open_element :: proc (lm : ^Layout_mananger, loc := #caller_location) {

}

close_element :: proc (lm : ^Layout_mananger, loc := #caller_location) {
	
}

//An item is a rect that is drawn and layout'ed
//An element can contian many items, like a background and a border.
//The element is pushed once and popped once.
//pusing an element can push and pop multiple items.
//This uses the temp allocator.
open_item :: proc (lm : ^Layout_mananger, layout : Layout, transform := default_transform, loc := #caller_location) {
	append(&lm.items, Item_or_pop{Item{layout, transform}, loc});
}

close_item :: proc (lm : ^Layout_mananger, loc := #caller_location) {
	append(&lm.items, Item_or_pop{Pop{}, loc});
}

interpolate_abs_position :: proc (a, b : Maybe(Absolute_postion), t : f32) -> Absolute_postion {

	return {};
}

acast :: linalg.array_cast;

//time: what is the current time.
end :: proc (lm : ^Layout_mananger, time : f32, loc := #caller_location) {
	item := make([dynamic]Item, 0, len(lm.items) / 2, context.temp_allocator)
	
	//time := time;
	//time = time - math.floor(time);

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
	
	elems := laycal.end_layout_state(&lm.ls);
	for e, i in elems {
		pos := [4]f32{cast(f32)e.position.x, cast(f32)e.position.y, cast(f32)e.size.x, cast(f32)e.size.y};
		itm := item[i];
		
		append(&lm.renders, layren.Render_rect{
			pos,
			render.texture2D_get_white(), 
			itm.visual,
			0,
		});
	}
	
	layren.render(&lm.lr, lm.renders[:]);
	clear(&lm.renders);
	clear(&lm.items);
}






///////////////////////////////////////////////////////////////////////////////////////

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
