package regui_base;

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:reflect"
import "base:intrinsics"
import "core:strconv"
import "core:mem"
import "core:slice"

import "core:time" //Temp

import render "../../render"
import utils "../../utils"

//This is a global for all gui states, and all panels with sub elements, so it is "very" unique
current_element_index : Element;

bound_scene : ^Scene;

active_elements : map[i64]Element_container;

debug_draw : bool;

////////////////// TYPES ////////////////////

Font_appearance :: struct {
	
	text_anchor : Anchor_point,	//Text placement inside the parent gui element.
	text_size : f32, 			//It is in unit space (aka 0-1 ish) likely in the 0.01 to 0.1 range.
	
	bold, italic : bool, 		
 	fonts : render.Fonts, 		// Used if the element contains text
	
	limit_by_width, limit_by_height : bool, //These tell if size shoud be limited by the parent gui element.
	limit_horizontal_should_resize : bool,
		
	text_backdrop_offset : [2]f32, //This is for makeing a backdrop / shadow. This is in screen space, likely something like 0.001
	text_backdrop_color : [4]f32, //This is the color of the backdrop / shadow
}

Colored_appearance :: struct {
	using _ : Font_appearance,
	
	// Color of elements drawn
	bg_color : [4]f32,		// This is the background color
	
	// It is the thing placed before the background, but non-interactive or changing.
	mid_color : [4]f32,		// This is the color that on the element placed on top of the background.
	mid_margin : f32,		// may be negative

	front_color : [4]f32,	// Color of text, line or alike.
	front_margin : f32,		// may be negative

	// This is how lines are drawn and are often tied to front_color and margin.
	line_width : f32,
	line_margin : f32,
	
	//Additional varies from element to element.
	additional_show : bool, 	//Mark the discrete points
	additional_color : [4]f32, 	//The color of the marks.
	additional_line_width : f32,
	additional_margin : f32,
	
	// Some elements can also be rounded
	// Some cannot like the radio button as it is already round.
	rounded : bool, // TODO
}

// A single texture is passed, and the borders are defined from that.
Patched_appearance :: struct {
	using _ : Font_appearance,
 	
	// TODO
	// Repeat, or stretch? or both?
}

// The textures will stretch to reach its size.
// This does not look good on dynamically sized objects, see Patch_appearance or Colored_appearance.
// But is it simple to set up.
Textured_appearance :: struct {
	using _ : Font_appearance,
	
	// TODO
}

// Determines how GUI elements look.
// Can be applied to everything, per type, or per instance.
//An appearance controls the appearance of the elements, it is a collection of render settings.
//There are 3 types of appearance, Colored_appearance, Patched_appearance and Textured_appearance.
//The Colored_appearance is a minimalistic way a drawing, thing are only drawn in colors controlled by the appearance.
//Patched_appearance is the most common as it is able to draw *any* width/heigth of a gui element while *not* steching any textures.
//** = only true sometimes.
//It works by using 9 textures, 4 for the corners, 4 for the edges and 1 for the center.
//The Textured_appearance is a simple texture drawn. It should only be used are sure you don't want to scale things.
Appearance :: union {
	Colored_appearance,
	Patched_appearance,
	Textured_appearance,
}

// A collection of appearances, these are applied per element or as a type, a default backing style can also be set.
Style :: struct {
	default : Appearance,
	hover : Maybe(Appearance),
	selected : Maybe(Appearance),
	active : Maybe(Appearance),
}

//The theme maps
Theme :: struct {
	styles : map[typeid]Style, //Maps from the element to the style.
}

////////////////////////////////////////////////////////////

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

Fill_x :: struct {y, w : f32}
Fill_y :: struct {x, z : f32}
Fill :: struct {};
Rect :: union{[4]f32, Fill_x, Fill_y, Fill};

//Common for all elements, determines screen position in a 0-1 range.
//The range is 0-1 for a square screen
//For a non-square screen the range will extend in the longest direction propertionally to the width/heigth or heigth/width ratio.
//This ensures that all elements always are placed correct relativly to each other.
Destination :: struct {
	anchor : Anchor_point, // This decides where 0,0 is on the screen
	self_anchor : Anchor_point, // This decides at which point on element is anchored to 0,0
	rect : Rect,
}

get_rect :: proc (rect : Rect, parent : [4]f32) -> [4]f32 {
	aspect := parent;
	
	switch r in rect {
		case [4]f32: 
			return r;
			
		case Fill_x:
			return {0, r.y, math.max(1, parent.z / parent.w), r.w};
			
		case Fill_y:
			return {r.x, 0, r.z, math.max(1, parent.w / parent.z)};
		
		case Fill:
			return {0, 0, math.max(1, parent.z / parent.w), math.max(1, parent.w / parent.z)};
	}
	
	unreachable();
}

////////////////////////////////////////////////////////////

//These are the all the GUI elements, these are wrappers around the Element type, they are there so that their typeid can be used to index into Theme.styles
Element :: distinct i64;
Panel :: distinct i64;

/*
//These are GUI primitives handles
Rect :: distinct i64;
Button :: distinct i64;
Checkbox :: distinct i64;
Label :: distinct i64;
Slider :: distinct i64;
Int_slider :: distinct i64;
Text_field :: distinct i64;
Int_field :: distinct i64; 	//TODO
Float_field :: distinct i64;//TODO
Text_area :: distinct i64;
Radio_buttons :: distinct i64;
Dropdown :: distinct i64;

//There are kinda special, used mainly in games
Bar :: distinct i64;
Slot :: distinct i64;
Color_picker :: distinct i64;
Gradient_picker :: distinct i64;
Text_editor :: distinct i64;
Custom :: distinct i64;

//These panels handles 
Panel :: distinct i64;			//A panel contains other elements
Split_panel :: distinct i64; 	//This is panel with multiable smaller panels, they can be resized and moved around by the user.
Accordion :: distinct i64;		//This can be opened to revieal more (kinda like a "spoiler")
Screen_panel :: distinct i64;	//This takes up the entire screen, used to bundle elements together that needs to be hidden/shown. Good for menus
Horizontal_bar :: distinct i64; //These fill the entire screen in a dimension and act as a panel
Vertical_bar :: distinct i64;	//These fill the entire screen in a dimension and act as a panel

Handle :: union {
	Rect,
	Button,
	Checkbox,
	Label,
	Slider,
	Int_slider,
	Text_field,
	//TODO rest
}
*/

////////////////////////////////////////////////////////////

//A tooltip can be both a string or a Panel
//If it is a string then it will be displayed when hovering
//If it is a panel than it will be displayed when hovering
Tooltip :: union {
	string,
	Panel,
}

////////////////////////////////////////////////////////////
// The *_info holds the instance data of the gui elements.

//These hold the information about each element
Element_info :: union {
	Rect_info,
	Button_info,
	Checkbox_info,
	Label_info,
	Slider_info,
	Int_slider_info,
	Text_field_info,
	Panel_info,
	Custom_info,
}

//A box with no text, and no interactions.
Rect_info :: struct {
	//Contains no information
}

//Button, true or false. Get the value from clicked.
Button_info :: struct {
	//Set by user
	text : string,
	clicked : ^bool,
}

//Checkbox true or false.
Checkbox_info :: struct {
	checked : bool,
	checked_res : ^bool,
}

//Checkbox true or false.
Label_info :: struct {
	text : string,
}

//Slider, a continues value.
Slider_info :: struct {
	//User settings
	min_val : f32,
	max_val : f32,
	
	//Internal
	current_val : f32,
	current_val_res : ^f32,
}

//Int slider, discontinues values
Int_slider_info :: struct {
	//User settings
	min_val : int,
	max_val : int,
	
	//Internal
	current_val : int,
	current_val_res : ^int,
}

//Common for Text_field, Int_field, text_area and other input things.
Base_text_info :: struct {
	//User settings
	max_rune_cnt : Maybe(int),
	max_line_cnt : Maybe(int),
	display_line_number : bool,
	
	//What runes are allowed
	allow_letters : bool,
	capital_behavior : enum {keep, capital_only, lower_only},
	allow_numbers : bool,
	allow_white_space : bool,
	allow_symbols : bool, //everything else
	white_list : []rune,
	black_list : []rune,
	
	//Internal
	runes : ^[dynamic]rune,
	view_start : ^int,
	cursor_pos : ^int,
	
	bg_text : string,
}

Text_field_info :: struct {
	//User settings
	max_rune_cnt : Maybe(int),
	
	//Internal
	runes : [dynamic]rune,
	view_start : int,
	cursor_pos : int,
	
	bg_text : string,
	text_res : ^string,
}

Custom_info :: struct {
	update_call 	: proc(data : rawptr, container : Element_container, parent_rect : [4]f32, unit_size : f32, mouse_pos : [2]f32),
	draw_call 		: proc(data : rawptr, container : Element_container, parent_rect : [4]f32, unit_size : f32, mouse_pos : [2]f32, style : Style),
	destroy_call 	: proc(data : rawptr),
	custom_data 	: rawptr,
}

Panel_info :: struct {
	//movable : bool,
	//drag_area : Destination,
	//scrollable : bool,
	sub_elements : [dynamic]Element,
}

////////////////////////////////////////////////////////////

//Common contiainer for all elements.
Element_container :: struct {

	//Content
	element_info : Element_info,
	
	//Position
	dest : Destination,

	//visability
	is_showing : bool,
	
	stay_selected : bool, //For some types this is true.
	
	//This is used by some types when using mouse and most types when using controller (TODO controller)
	//These are the states
	is_selected : bool,
	is_active : bool,
	is_hover : bool,
	
	//What will be displayed when hovering the elements (optional) may be nil
	tooltip : Tooltip,
	
	//TODO hover, and click sounds
	
	//User data, so the user can use the callback system if wanted (not recommended)
	user_data : rawptr, //TODO delete, dont do callbacks, i think.
	
	//If any of these are set, they will override the style for the specific element.
	using style : Style,
}

////////////////// CONTEXT //////////////////

Parent :: union {
	^Scene,
	Panel,
}

Scene :: struct {
	
	default_style : Style,
	Theme : Theme,
	
	window : ^render.Window, //TODO remove this window, it only used for input, find another way.
	
	owned_elements : [dynamic]Element,
	
	unit_size : f32,
	gui_pipeline : render.Pipeline,
}

//generic way to change stuff, maybe do something else later...
get_element_data :: proc (handle : Element, $type_info : typeid, loc := #caller_location) -> type_info {
	
	v := active_elements[handle].element_info;
	r, ok := v.(type_info);
	fmt.assertf(ok, "the handle type %v does not match the internal type %v", h, v, loc = loc);
	return r;
}

//generic way to change stuff, maybe do something else later...
set_element_data :: proc (handle : Element, info : $type_info, loc := #caller_location) {
	
	v := active_elements[handle].element_info;
	r, ok := v.(type_of(type_info));
	fmt.assertf(ok, "the handle type %v does not match the internal type %v", h, v, loc = loc);
	
	r.element_info = info;
	active_elements[handle] = r;
}

//Common for all elements, only use if you are doing a custom element.
element_make :: proc (parent : Parent, container : Element_container, loc := #caller_location) -> Element {
	
	current_element_index += 1;
	active_elements[cast(i64)current_element_index] = container;
	
	switch v in parent {
		
		case ^Scene:
		 	append(&v.owned_elements, current_element_index);
			
		case Panel:
			contrainer : ^Element_container = &active_elements[cast(i64)v];
			
			ok : bool;
			e : ^Panel_info;
			e, ok = &(&contrainer.element_info).(Panel_info);
			fmt.assertf(ok, "The handle %v is not of type %v. Handle data : %v", v, type_info_of(Panel_info), contrainer.element_info);
			
			append_elem(&e.sub_elements, current_element_index);
	}

	return current_element_index;
}

element_get :: proc (handle : Element, $T : typeid, loc := #caller_location) -> (element : T, contrainer : Element_container) {
	assert(cast(i64)handle in active_elements, "The handle is not valid", loc);
	contrainer = active_elements[cast(i64)handle];
	
	e, ok := contrainer.element_info.(T);
	fmt.assertf(ok, "The handle %v is not of type %v. Handle data : %v", handle, type_info_of(T), contrainer.element_info);
	return e, contrainer;
}

element_cleanup :: proc(container : Element_container) {
	switch e in container.element_info {
		case Rect_info: 
			//TODO
			
		case Button_info:
			delete(e.text);
		
		case Checkbox_info:
			//nothing
			
		case Label_info:
			delete(e.text);
		
		case Slider_info:
			//nothing
			
		case Int_slider_info:
			//nothing
		
		case Text_field_info:
			delete(e.runes);
			delete(e.bg_text);
			
		case Panel_info:
			for k in e.sub_elements {
				e := active_elements[cast(i64)k];
				element_cleanup(e);
				delete_key(&active_elements, cast(i64)k);
			}
			delete(e.sub_elements);
			
		case Custom_info:
			e.destroy_call(e.custom_data);
		
	}
}

//TODO take in parent_rect, it is needed for panels.
element_update :: proc (container : ^Element_container, style : Style, parent_rect : [4]f32, loc := #caller_location) {
	
	dest : Destination = container.dest; //Dest is in unit space (0 to 1 ish)
	dest_rect := get_rect(container.dest.rect, parent_rect); 
	rect := get_screen_space_position_rect(container.dest.anchor, container.dest.self_anchor, container.dest.rect, parent_rect, bound_scene.unit_size);
	
	fmt.printf("rect : %v\n", rect);
	
	container.is_active = false;
	container.is_hover = false;
	if container.stay_selected {
		if mouse_button_pressed(.mouse_button_1) {
			container.is_selected = false;
		}
	}
	else if !mouse_button_down(.mouse_button_1) {
		container.is_selected = false;
	}
	
	if is_activated(dest, parent_rect) {
		container.is_active = true;
	}
	else if is_selected(dest, parent_rect) {
		container.is_selected = true;
	}
	
	if is_hovered(dest, parent_rect) {
		container.is_hover = true;
	}
		
	switch &e in container.element_info {
		case Rect_info:{
			//A rect has not logic
		}
		case Button_info:{
			if e.clicked != nil {
				e.clicked^ = container.is_active;
			}
		}
		case Checkbox_info: {
			if container.is_active {
				e.checked = !e.checked;
			}
			if e.checked_res != nil {
				e.checked_res^ = e.checked;
			}
		}
		case Label_info: {
			//A label has not logic
		}
		case Slider_info: {
						
			margin : f32 = get_logical_margin(style);
			x := mouse_pos().x;
			
			//offset : f32 = margin/2 + (e.current_val - e.min_val) / (e.max_val - e.min_val) * (dest.rect.z - margin);
			
			dragable_dest : [4]f32 = {0, 0, dest_rect.z - margin, dest_rect.w};
			slider_rect := get_screen_space_position_rect(.center_center, .center_center, dragable_dest, rect, bound_scene.unit_size); //to convert to pixel space
			if container.is_selected {
				t := ((x - slider_rect.x) / slider_rect.z * (e.max_val - e.min_val)) + e.min_val;
				e.current_val = math.clamp(t, e.min_val, e.max_val);
			}
			
			if e.current_val_res != nil {
				e.current_val_res^ = e.current_val;
			}
		}
		case Int_slider_info:{
			
			margin : f32 = get_logical_margin(style);
			x := mouse_pos().x;
			
			dragable_dest : [4]f32 = {0, 0, dest_rect.z - margin, dest_rect.w};
			slider_rect := get_screen_space_position_rect(.center_center, .center_center, dragable_dest, rect, bound_scene.unit_size); //to convert to pixel space
			if container.is_selected {
				t := ((x - slider_rect.x) / slider_rect.z * f32(e.max_val - e.min_val)) + f32(e.min_val);
				e.current_val = cast(int)math.round(math.clamp(t, f32(e.min_val), f32(e.max_val)));
			}
			
			if e.current_val_res != nil {
				e.current_val_res^ = e.current_val;
			}
		}
		case Text_field_info:{
			
			base := Base_text_info{
				e.max_rune_cnt, 		//max_rune_cnt : Maybe(int),
				1, 						//max_line_cnt : Maybe(int),
				false, 					//display_line_number : bool,
				
				true,					//allow_letters : bool,
				.keep,					//capital_behavior : enum {keep, capital_only, lower_only},
				true,					//allow_numbers : bool,
				true,					//allow_white_space : bool,
				true,					//allow_symbols : bool, //everything else
				{},						//white_list : []rune,
				{},						//black_list : []rune,
				
				&e.runes,				//runes : ^[dynamic]rune,
				&e.view_start,			//view_start : ^int,
				&e.cursor_pos,			//cursor_pos : ^int,
				e.bg_text				//bg_text : string,
			}
			
			update_text_base(base, container.is_selected, style, dest, rect, bound_scene.unit_size, loc);
		}
		case Panel_info:{
			for key in e.sub_elements {
				e := &active_elements[cast(i64)key];
				element_update(e, style, rect);
			}
		}
		case Custom_info: {
			e.update_call(e.custom_data, container^, parent_rect, bound_scene.unit_size, mouse_pos());
		}
	}
}

element_draw :: proc (container : Element_container, style : Style, parent_rect : [4]f32) {
	
	dest : Destination = container.dest; //Dest is in unit space (0 to 1)
	dest_rect := get_rect(dest.rect, parent_rect);
	
	appear : Appearance = style.default;
	if act, ok := style.active.?; ok && container.is_active {
		appear = act;
	}
	else if sel, ok := style.selected.?; ok && container.is_selected {
		appear = sel;
	}
	else if  hov, ok := style.hover.?; ok && container.is_hover {
		appear = hov;
	}
	
	unit_size := bound_scene.unit_size;
	
	switch e in container.element_info {
		case Rect_info:
			switch a in style.default {
				
				case Textured_appearance:
					//TODO
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
				case Patched_appearance:
					//TODO
				
			}
			
		case Button_info:
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					mid_dest : [4]f32 = {0,0, dest_rect.z - a.mid_margin, dest_rect.w - a.mid_margin};
					new_rect = draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color);
					
					text_dest := mid_dest - {0,0, a.front_margin, a.front_margin};
					draw_text(e.text, text_dest, new_rect, a.front_color, a);
					
				case Patched_appearance:

			}
		
		case Checkbox_info:
			
			switch a in appear {
					
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					mid_dest : [4]f32 = {0,0, dest_rect.z - a.mid_margin, dest_rect.w - a.mid_margin};
					new_rect = draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color);
					
					//TODO draw x
					if e.checked {
						
						//Line (0,0) to (1,1)
						{
							p1 := new_rect.xy + (a.line_margin) * bound_scene.unit_size;
							p2 := new_rect.xy + new_rect.zw - (a.line_margin) * bound_scene.unit_size;	
							render.draw_line_2D(p1, p2, unit_size * a.line_width, color = a.front_color);
						}
						
						//Line (0,1) to (1,0)
						{
							p1 := [2]f32{new_rect.x + (a.line_margin) * unit_size, new_rect.y + new_rect.w - (a.line_margin) * unit_size};
							p2 := [2]f32{new_rect.x + new_rect.z - (a.line_margin) * unit_size, new_rect.y + (a.line_margin) * unit_size};
							
							render.draw_line_2D(p1, p2, unit_size * a.line_width, color = a.front_color);
						}
						
					}
					
				case Patched_appearance:

			}
		
		case Label_info:
			
			switch a in style.default {
					
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					text_dest : [4]f32 = {0,0, dest_rect.z - a.front_margin, dest_rect.w - a.front_margin};
					draw_text(e.text, text_dest, new_rect, a.front_color, a);
					
				case Patched_appearance:

			}
		
		case Slider_info:
			
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					mid_dest : [4]f32 = {0,0, dest_rect.z - a.mid_margin, dest_rect.w - a.mid_margin};
					draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color);
					
					margin := get_logical_margin(style);
					offset : f32 = margin/2 + (e.current_val - e.min_val) / (e.max_val - e.min_val) * (dest_rect.z - margin);
					
					draw_quad(.center_left, .center_center, {offset, 0, a.line_width, dest_rect.w - a.line_margin}, new_rect, a.front_color);
					
				case Patched_appearance:

			}
		
		case Int_slider_info:
			
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					mid_dest : [4]f32 = {0,0, dest_rect.z - a.mid_margin, dest_rect.w - a.mid_margin};
					draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color);
					
					margin := get_logical_margin(style);
					offset : f32 = margin/2 + f32(e.current_val - e.min_val) / f32(e.max_val - e.min_val) * (dest_rect.z - margin);
					
					draw_quad(.center_left, .center_center, {offset, 0, a.line_width, dest_rect.w - a.line_margin}, new_rect, a.front_color);
					
				case Patched_appearance:

			}
			
		case Text_field_info:
			
			fmt.assertf(e.view_start <= len(e.runes), "e.view_start is greater then the runes length, e.view_start : %v, runes : %v", e.view_start, e.runes);
			text := utf8.runes_to_string(e.runes[e.view_start:]);
			defer delete(text);
			
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					mid_dest : [4]f32 = {0,0, dest_rect.z - a.mid_margin, dest_rect.w - a.mid_margin};
					new_rect = draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color);
					
					if len(e.runes) != 0 {
						text_dest := mid_dest - {0,0, a.front_margin, a.front_margin};
						draw_text(text, text_dest, new_rect, a.front_color, a);
						
						if debug_draw {
							render.set_texture(.texture_diffuse, render.texture2D_get_white());
							draw_quad(.center_center, .center_center, text_dest, new_rect, {1,0.1,0.1,0.5});
						}
					}
					else {
						text_dest := mid_dest - {0,0, a.additional_margin, a.additional_margin};
						draw_text_param(e.bg_text, text_dest, new_rect, a.text_size, a.text_anchor, a.bold, a.italic, a.additional_color, a.fonts,
							{}, a.text_backdrop_offset, a.limit_by_height, a.limit_by_width);
					}
					
					//Draw cursor
					cursor_text := utf8.runes_to_string(e.runes[e.view_start:e.cursor_pos])
					defer delete(cursor_text);
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					//fmt.printf("render.text_get_dimensions(cursor_text, a.text_size).x : %v\n", render.text_get_dimensions(cursor_text, a.text_size).x);
					draw_quad(.center_left, .center_center, {render.text_get_dimensions(cursor_text, a.text_size).x, mid_dest.y, 0.005, 0.1}, new_rect, a.mid_color);
					
				case Patched_appearance:

			}	
			
		case Panel_info: {
			
			//panel_camera := {};
			//render.set_camera();
			
			switch a in style.default {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					parent_rect := draw_quad(dest.anchor, dest.self_anchor, dest_rect, parent_rect, a.bg_color);
					
					for key in e.sub_elements {
						e := active_elements[cast(i64)key];
						element_draw(e, style, parent_rect);
					}
					
				case Patched_appearance:

			}
		}
		case Custom_info: {
			
			e.draw_call(e.custom_data, container, parent_rect, unit_size, mouse_pos(), style);
		}
	}
}
