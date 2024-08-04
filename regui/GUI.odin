package gui;

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:reflect"
import "base:intrinsics"
import "core:strconv"
import "core:mem"

import "core:time" //Temp

import render "../render"
import utils "../utils"

/////////////////////////////////////////////////////////////// AT STARTUP /////////////////////////////////////////////////////////////// 

@(require_results)
init :: proc (fallback_appearance := default_appearance, loc := #caller_location) -> (state : Scene) {
	
	state = {
		gui_pipeline = render.pipeline_make(render.get_default_shader(), .blend, false, false),
		default_style = {
			default = default_appearance,
			hover = default_appearance,
			active = default_appearance,
		},
	}
	
	state.default_style.hover = default_hover_appearance;
	state.default_style.selected = default_selected_appearance;
	state.default_style.active = default_active_appearance;
	
	return;
}

destroy :: proc (using state : ^Scene) {

	for k in owned_elements {
		e := active_elements[k];
		element_cleanup(e);
		delete_key(&active_elements, k);
	}
	
	delete(owned_elements); owned_elements = {};
	
	if len(active_elements) == 0 {
		delete(active_elements); active_elements = {};
	}
	
	render.pipeline_destroy(gui_pipeline);
}

/////////////////////////////////////////////////////////////// PER FRAME ///////////////////////////////////////////////////////////////

begin :: proc (state : ^Scene, target_window : ^render.Window, loc := #caller_location) {
	assert(bound_scene == nil, "begin has already been called.", loc);
	assert(render.state.is_begin_frame == true, "regui's begin must be called after render's begin_frame", loc);
	assert(render.state.current_target != nil, "You must set the target with render.target_begin(some_window) before calling gui.begin", loc);
	
	bound_scene = state;
	
	state.window = target_window;
	w, h := render.get_render_target_size(state.window);
	state.unit_size = get_unit_size(cast(f32)w, cast(f32)h);
	
	style : Style = state.default_style;
	
	for k in state.owned_elements {
		e : ^Element_container = &active_elements[k];
		element_update(e, style, get_screen_rect(), loc);
	}
}

end :: proc (state : ^Scene, loc := #caller_location) {
	assert(bound_scene != nil, "begin has not been called.", loc);
	assert(bound_scene == state, "The passed gui state does not match the begin's statement.", loc);
	assert(render.state.is_begin_frame == true, "regui's begin must be called before render's end_frame", loc);
	
	style : Style = state.default_style;
	
	render.pipeline_begin(state.gui_pipeline, render.camera_get_pixel_space( state.window));
	
	//Draw
	for k in state.owned_elements {
		e : Element_container = active_elements[k];
		element_draw(auto_cast e, style, get_screen_rect(), loc);
	}
	
	render.pipeline_end();

	state.window = nil;
	bound_scene = nil;
}

////////////////// TYPES ////////////////////

Font_appearance :: struct {
	
	text_anchor : Anchor_point,	//Text placement inside the parent gui element.
	text_size : f32, 			//It is in unit space (aka 0-1 ish) likely in the 0.01 to 0.1 range.
	
	bold, italic : bool, 		
 	fonts : render.Fonts, 		// Used if the element contains text
	
	limit_by_width, limit_by_height : bool, //These tell if size shoud be limited by the parent gui element.
	
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

//Common for all elements, determines screen position in a 0-1 range.
//The range is 0-1 for a square screen
//For a non-square screen the range will extend in the longest direction propertionally to the width/heigth or heigth/width ratio.
//This ensures that all elements always are placed correct relativly to each other.
Destination :: struct {
	anchor : Anchor_point, // This decides where 0,0 is on the screen
	self_anchor : Anchor_point, // This decides at which point on element is anchored to 0,0
	rect : [4]f32,
}

////////////////////////////////////////////////////////////

//These are the all the GUI elements, these are wrappers around the Element type, they are there so that their typeid can be used to index into Theme.styles
Element :: distinct i64;

//These are GUI primitives handles
Rect :: struct { e : Element, };
Button :: struct { e : Element, };
Checkbox :: struct { e : Element, };
Label :: struct { e : Element, };
Slider :: struct { e : Element, };
Int_slider :: struct { e : Element, };
Text_field :: struct { e : Element, };
Int_field :: struct { e : Element, }; 	//TODO
Float_field :: struct { e : Element, };	//TODO
Text_area :: struct { e : Element, };	
Radio_buttons :: struct { e : Element, };
Dropdown :: struct { e : Element, };

//There are kinda special, used mainly in games
Bar :: struct { e : Element, };
Slot :: struct { e : Element, };
Color_picker :: struct { e : Element, };
Gradient_picker :: struct { e : Element, };
Text_editor :: struct { e : Element, };
Custom :: struct { e : Element, };

//These panels handles 
Panel :: struct { e : Element, };			//A panel contains other elements
Split_panel :: struct { e : Element, }; 	//This is panel with multiable smaller panels, they can be resized and moved around by the user.
Accordion :: struct { e : Element, };		//This can be opened to revieal more (kinda like a "spoiler")
Screen_panel :: struct { e : Element, };	//This takes up the entire screen, used to bundle elements together that needs to be hidden/shown. Good for menus
Horizontal_bar :: struct { e : Element, }; //These fill the entire screen in a dimension and act as a panel
Vertical_bar :: struct { e : Element, };	//These fill the entire screen in a dimension and act as a panel

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
@(private)
Element_info :: union {
	Rect_info,
	Button_info,
	Checkbox_info,
	Label_info,
	Slider_info,
	Int_slider_info,
	Text_field_info,
	Panel_info,
}

//A box with no text, and no interactions.
@(private)
Rect_info :: struct {
	//Contains no information
}

//Button, true or false. Get the value from clicked.
@(private)
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

Text_field_info :: struct {
	//User settings
	max_rune_length : int,
	
	//Internal
	runes : [dynamic]rune,
	view_start : int,
	cursor_pos : int,
	
	bg_text : string,
	text_res : ^string,
}

@(private)
Panel_info :: struct {
	//movable : bool,
	//drag_area : Destination,
	//scrollable : bool,
	sub_elements : [dynamic]Element,
}

////////////////////////////////////////////////////////////

//Common contiainer for all elements.
@(private)
Element_container :: struct {

	//Content
	element : Element_info,
	
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
/*
current_theme : Theme;
style_stack : [20]Theme; //MAX 20 styles, TODO make dynamic
style_stack_len : int;

current_panel : ^Panel;
panel_stack : [20]^Panel; //MAX 20 styles
current_pixel_space : [4]f32;
pixel_space_stack : [20][4]f32; //MAX 20 styles
panel_stack_len : int;
*/

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

//This is a global for all gui states, and all panels with sub elements, so it is "very" unique
@(private)
current_element_index : Element;

@(private)
bound_scene : ^Scene;

@(private)
active_elements : map[Element]Element_container;

////////////////// Private Functions ////////////////////

//Common for all elements, only use if you are doing a custom element.
@(private)
element_make :: proc (parent : Parent, container : Element_container, loc := #caller_location) -> Element {
	
	current_element_index += 1;
	active_elements[current_element_index] = container;
	
	switch v in parent {
		
		case ^Scene:
		 	append(&v.owned_elements, current_element_index);
			
		case Panel:
			contrainer : ^Element_container = &active_elements[v.e];
			
			ok : bool;
			e : ^Panel_info;
			e, ok = &(&contrainer.element).(Panel_info);
			fmt.assertf(ok, "The handle %v is not of type %v. Handle data : %v", v.e, type_info_of(Panel_info), contrainer.element);
			
			append_elem(&e.sub_elements, current_element_index);
	}

	return current_element_index;
}

//Common for all elements
@(private)
element_destroy :: proc (handle : Element, loc := #caller_location) {
	assert(handle in active_elements, "The handle is not valid", loc);
	key, container := delete_key(&active_elements, handle);
	element_cleanup(container);
}


//returns what it drew in screen space coordinates.
@(private)
draw_quad :: proc (anchor : Anchor_point, self_anchor : Anchor_point, rect : [4]f32, parent_rect : [4]f32, color : [4]f32, loc := #caller_location) -> [4]f32 {
	
	rect := get_screen_space_position_rect(anchor, self_anchor, rect, parent_rect, bound_scene.unit_size);
	render.draw_quad_rect(rect, 0, color, loc);
	
	return rect;
}

//position, size and bounds is in unit size coordinates (0-1 ish)
//limit_by_width makes it so the text will not extend over the bounds.
//TODO anchors
@(private)
draw_text_param :: proc (text : string, bounds : [4]f32, parent_rect : [4]f32, size : f32, anchor : Anchor_point, bold, italic : bool, color : [4]f32, fonts : render.Fonts,
 						backdrop_color : [4]f32, backdrop_offset : [2]f32, limit_by_height : bool = true, limit_by_width : bool = true, loc := #caller_location) {
	
	if text == "" {
		return;
	}
	assert(size != 0, "text size may not be zero", loc = loc);
	
	unit_size := bound_scene.unit_size;
	font := render.text_get_font_from_fonts(bold, italic, fonts);
	
	//This is the rect in pixels which the text should be drawn within.
	rect := get_screen_space_position_rect(.center_center, .center_center, bounds, parent_rect, bound_scene.unit_size);
	
	text_target_size := size * unit_size; 
	
	if limit_by_height {
		text_target_size = math.min(rect.w, text_target_size);
	}	
	
	text_width := render.text_get_bounds(text, font, text_target_size).z;
	
	limiter : f32 = 1;
	if limit_by_width { 
		limiter = math.min(1, rect.z / text_width);
	}
	
	text_size := text_target_size * limiter;
	text_bounds := render.text_get_bounds(text, font, text_size);
	
	//This is a little hacky but it works.
	rect = get_screen_space_position_rect(anchor, anchor, {0,0,text_bounds.z, text_bounds.w} / unit_size, rect, unit_size);
	
	render.pipeline_end();
	render.text_draw(text, rect.xy - {text_bounds.x, text_bounds.y}, rect.w, bold, italic, color, {color = backdrop_color, offset = backdrop_offset * unit_size}, fonts);
	render.pipeline_begin(bound_scene.gui_pipeline, render.camera_get_pixel_space(bound_scene.window));
}

@(private)
draw_text_appearance :: proc (text : string, bounds : [4]f32, parent_rect : [4]f32, color : [4]f32, appearance : Appearance, loc := #caller_location) {
	
	switch a in appearance {
		
		case Colored_appearance:
			draw_text_param(text, bounds, parent_rect, a.text_size, a.text_anchor, a.bold, a.italic, color, a.fonts,
							a.text_backdrop_color, a.text_backdrop_offset, a.limit_by_height, a.limit_by_width, loc);
		
		case Patched_appearance:
			//draw_text_param(text, bounds, a.text_size, a.text_anchor, a.bold, a.italic, a.front_color, a.fonts, a.limit_by_height, a.limit_by_width, loc);
			panic("TODO");
			
		case Textured_appearance:
			//draw_text_param(text, bounds, a.text_size, a.text_anchor, a.bold, a.italic, a.front_color, a.fonts, a.limit_by_height, a.limit_by_width, loc);
			panic("TODO");
	}
}

@(private)
draw_text :: proc {draw_text_param, draw_text_appearance}

@(private)
get_screen_rect :: proc () -> [4]f32 {
	w, h := render.get_render_target_size(bound_scene.window);
	return {0,0,cast(f32)w,cast(f32)h};
}

@(private)
get_unit_size :: proc (width, height : f32) -> f32 {
	return math.min(width, height);
}

//Takes in unit space coordinates (0-1 ish)
//Returns screen space coordinates (0-2000 ish)
//anchor: where is the rect anchored
//self_anchor: which part of the rect is the origin (anchored place)
//anchor_rect_pixel is a parent rect given in pixels space (0-2000 ish), will redifine what "the screen" is.
//Unit size is the unit_size (0-2000 ish), see get_unit_size
@(private)
get_screen_space_position_rect :: proc(anchor : Anchor_point, self_anchor : Anchor_point, rect : [4]f32, anchor_rect_pixel : [4]f32, unit_size : f32) -> [4]f32 {
	
	offset : [2]f32;

	switch self_anchor {
		
		case .bottom_left:
			//No code required

		case .bottom_center:
			offset.x = -rect.z / 2;

		case .bottom_right:
			offset.x = -rect.z

		case .center_left:
			offset.y = -rect.w / 2;

		case .center_center:
			offset.x = -rect.z / 2;
			offset.y = -rect.w / 2;
		
		case .center_right:
			offset.x = -rect.z
			offset.y = -rect.w / 2;

		case .top_left:
			offset.y = -rect.w;
		
		case .top_center:
			offset.x = -rect.z / 2
			offset.y = -rect.w

		case .top_right:
			offset.x = -rect.z
			offset.y = -rect.w
		case: // default
	}

	rectangle := [4]f32{
		(rect.x + offset.x) * unit_size,
		(rect.y + offset.y) * unit_size,
		rect.z * unit_size,
		rect.w * unit_size,
	}

	rectangle.xy += anchor_rect_pixel.xy;

	switch anchor {

		case .bottom_left	 :
			//No code required

		case .bottom_center   :
			rectangle.x += anchor_rect_pixel.z / 2;
			
		case .bottom_right	:
			rectangle.x += anchor_rect_pixel.z;

		case .center_left  :
			rectangle.y += anchor_rect_pixel.w / 2;

		case .center_center:
			rectangle.x += anchor_rect_pixel.z / 2;
			rectangle.y += anchor_rect_pixel.w / 2;
		
		case .center_right :
			rectangle.x += anchor_rect_pixel.z
			rectangle.y += anchor_rect_pixel.w / 2;

		case .top_left  :
			rectangle.y += anchor_rect_pixel.w;

		case .top_center:
			rectangle.x += anchor_rect_pixel.z / 2;
			rectangle.y += anchor_rect_pixel.w;

		case .top_right :
			rectangle.x += anchor_rect_pixel.z;
			rectangle.y += anchor_rect_pixel.w;

		case: // default
			unreachable();
	}

	return rectangle;
}

/*
// Function to check if a point is inside a rectangle
@(private)
point_rect_collision :: proc(point: [2]f32, rect: [4]f32) -> bool {
	return point.x >= rect.x &&
		   point.x <= rect.x + rect.z &&
		   point.y >= rect.y &&
		   point.y <= rect.y + rect.w;
}
*/

@(private)
is_hovered :: proc (dest : Destination, parent_rect : [4]f32) -> bool {
	rect := get_screen_space_position_rect(dest.anchor, dest.self_anchor, dest.rect, parent_rect, bound_scene.unit_size);
	
	return collision_point_rect(mouse_pos(), rect);
}

@(private)
is_selected :: proc (dest : Destination, parent_rect : [4]f32) -> bool {
	
	return is_hovered(dest, parent_rect) && mouse_button_pressed(.mouse_button_1);
}

@(private)
is_activated :: proc (dest : Destination, parent_rect : [4]f32) -> bool {
	
	return is_hovered(dest, parent_rect) && mouse_button_released(.mouse_button_1);
}

@(private)
mouse_pos :: proc() -> [2]f32 {
	mp := render.mouse_pos(bound_scene.window);
	return {mp.x, mp.y};	
}

mouse_button_down :: render.button_down;
mouse_button_pressed :: render.button_pressed;
mouse_button_released :: render.button_released;

collision_point_rect :: utils.collision_point_rect;

///////////// Very private functions /////////////

@(private)
get_appearences :: proc (parent : Parent, appearance, hover_appearance, selected_appearance, active_appearance : Maybe(Appearance), loc := #caller_location) -> (a : Appearance, a_hover, a_sel, a_act : Maybe(Appearance)) {
	
	default_style : Style;
	
	switch v in parent {
		
		case ^Scene:
			default_style = v.default_style;
			
		case Panel:
			p, cont := element_get(v.e, Panel_info);
		 	default_style = cont.style;
			
	}
	
	fmt.printf("appearance : %v\n", appearance);
	
	appearance := appearance;
	hover_appearance := hover_appearance;
	selected_appearance := selected_appearance;
	active_appearance := active_appearance;
	
	default_appearance : Appearance;
	
	if a, ok := &appearance.?; !ok {
		default_appearance = default_style.default;
	}
	
	if a, ok := &hover_appearance.?; !ok {
		hover_appearance = default_style.hover;
	}
	
	if a, ok := &selected_appearance.?; !ok {
		selected_appearance = default_style.selected;
	}
	
	if a, ok := &active_appearance.?; !ok {
		active_appearance = default_style.active;
	}
	
	return default_appearance, hover_appearance, selected_appearance, active_appearance;
}

@(private)
get_logical_margin :: proc (s : Style) -> f32 {
	
	margin : f32;
	
	switch v in s.default {
		case Textured_appearance:
			panic("TODO");
			
		case Colored_appearance:
			margin = v.front_margin;
			
		case Patched_appearance:
			panic("TODO");
	}	
	
	return margin;
}

//TODO take in parent_rect, it is needed for panels.
@(private)
element_update :: proc (container : ^Element_container, style : Style, parent_rect : [4]f32, loc := #caller_location) {
	
	dest : Destination = container.dest; //Dest is in unit space (0 to 1)
	rect := get_screen_space_position_rect(dest.anchor, dest.self_anchor, dest.rect, parent_rect, bound_scene.unit_size);
	
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
	
	unit_size := bound_scene.unit_size;
	
	switch &e in container.element {
		case Rect_info:
			//A rect has not logic
			
		case Button_info:
			if e.clicked != nil {
				e.clicked^ = container.is_active;
			}
		
		case Checkbox_info:
			if container.is_active {
				e.checked = !e.checked;
			}
			if e.checked_res != nil {
				e.checked_res^ = e.checked;
			}
		
		case Label_info:
			//A label has not logic
		
		case Slider_info:
			
			margin : f32 = get_logical_margin(style);
			x := mouse_pos().x;
			
			//offset : f32 = margin/2 + (e.current_val - e.min_val) / (e.max_val - e.min_val) * (dest.rect.z - margin);
			
			dragable_dest : [4]f32 = {0, 0, dest.rect.z - margin, dest.rect.w};
			slider_rect := get_screen_space_position_rect(.center_center, .center_center, dragable_dest, rect, bound_scene.unit_size); //to convert to pixel space
			if container.is_selected {
				t := ((x - slider_rect.x) / slider_rect.z * (e.max_val - e.min_val)) + e.min_val;
				e.current_val = math.clamp(t, e.min_val, e.max_val);
			}
			
			if e.current_val_res != nil {
				e.current_val_res^ = e.current_val;
			}
			
		case Int_slider_info:
			
			margin : f32 = get_logical_margin(style);
			x := mouse_pos().x;
			
			dragable_dest : [4]f32 = {0, 0, dest.rect.z - margin, dest.rect.w};
			slider_rect := get_screen_space_position_rect(.center_center, .center_center, dragable_dest, rect, bound_scene.unit_size); //to convert to pixel space
			if container.is_selected {
				t := ((x - slider_rect.x) / slider_rect.z * f32(e.max_val - e.min_val)) + f32(e.min_val);
				e.current_val = cast(int)math.round(math.clamp(t, f32(e.min_val), f32(e.max_val)));
			}
			
			if e.current_val_res != nil {
				e.current_val_res^ = e.current_val;
			}
			
		case Text_field_info:
			
			margin : f32 = get_logical_margin(style);
			x := mouse_pos().x;
			
			dragable_dest : [4]f32 = {0, 0, dest.rect.z - margin, dest.rect.w};
			field_rect := get_screen_space_position_rect(.center_center, .center_center, dragable_dest, rect, unit_size); //to convert to pixel space
			
			font : render.Font;
			font_size : f32;
			
			//How many rune fit in rect
			{
				switch a in style.default {
					
					case Textured_appearance:
						
					case Colored_appearance:
						font = render.text_get_font_from_fonts(a.bold, a.italic, a.fonts);
						font_size = math.min(rect.w, a.text_size * unit_size);
					
					case Patched_appearance:
						
				}	
				
				//TODO something is wrong here.
				e.view_start = math.clamp(e.view_start, 0, len(e.runes));
				text := utf8.runes_to_string(e.runes[e.view_start:]);
				defer delete(text);
				dims := render.text_get_dimensions(text, font_size, font); //In pixel space
				for dims.x > field_rect.z {
					e.view_start += 1;
					e.view_start = math.clamp(e.view_start, 0, len(e.runes));
					text := utf8.runes_to_string(e.runes[e.view_start:]);
					defer delete(text);
					dims = render.text_get_dimensions(text, font_size, font); //In pixel space
				}
				
			}
			
			if container.is_selected && mouse_button_pressed(.mouse_button_1) {
				//The user clicked
				t := math.clamp((x - field_rect.x) / field_rect.z, 0, 1);
				//
				fmt.printf("t : %v", t);
			}
			
			if container.is_selected == true {
				
				if render.is_key_triggered(.backspace) {
					if len(e.runes) != 0 {
						pop(&e.runes);
					}
				}
				
				if render.is_key_triggered(.v) && render.is_key_down(.control_left) {
					s := render.get_clipboard_string();
					for r in s {
						append(&e.runes, r);
					}
				}
				
				for codepoint in render.recive_next_input() {
					append(&e.runes, codepoint);
				}
			}
		
		case Panel_info:
			panel_rect := get_screen_space_position_rect(container.dest.anchor, container.dest.self_anchor, container.dest.rect, parent_rect, bound_scene.unit_size);
			
			for key in e.sub_elements {
				e := &active_elements[key];
				element_update(e, style, panel_rect);
			}
	}
}

@(private)
element_draw :: proc (container : Element_container, style : Style, parent_rect : [4]f32, loc := #caller_location) {
	
	dest : Destination = container.dest; //Dest is in unit space (0 to 1)
	
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
	
	switch e in container.element {
		case Rect_info:
			switch a in style.default {
				
				case Textured_appearance:
					//TODO
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
				case Patched_appearance:
					//TODO
				
			}
			
		case Button_info:
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					mid_dest : [4]f32 = {0,0, dest.rect.z - a.mid_margin, dest.rect.w - a.mid_margin};
					new_rect = draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color, loc);
					
					text_dest := mid_dest - {0,0, a.front_margin, a.front_margin};
					draw_text(e.text, text_dest, new_rect, a.front_color, a, loc);
					
				case Patched_appearance:

			}
		
		case Checkbox_info:
			
			switch a in appear {
					
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					mid_dest : [4]f32 = {0,0, dest.rect.z - a.mid_margin, dest.rect.w - a.mid_margin};
					new_rect = draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color, loc);
					
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
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					text_dest : [4]f32 = {0,0, dest.rect.z - a.front_margin, dest.rect.w - a.front_margin};
					draw_text(e.text, text_dest, new_rect, a.front_color, a, loc);
					
				case Patched_appearance:

			}
		
		case Slider_info:
			
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					mid_dest : [4]f32 = {0,0, dest.rect.z - a.mid_margin, dest.rect.w - a.mid_margin};
					draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color, loc);
					
					margin := get_logical_margin(style);
					offset : f32 = margin/2 + (e.current_val - e.min_val) / (e.max_val - e.min_val) * (dest.rect.z - margin);
					
					draw_quad(.center_left, .center_center, {offset, 0, a.line_width, dest.rect.w - a.line_margin}, new_rect, a.front_color, loc);
					
				case Patched_appearance:

			}
		
		case Int_slider_info:
			
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					mid_dest : [4]f32 = {0,0, dest.rect.z - a.mid_margin, dest.rect.w - a.mid_margin};
					draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color, loc);
					
					margin := get_logical_margin(style);
					offset : f32 = margin/2 + f32(e.current_val - e.min_val) / f32(e.max_val - e.min_val) * (dest.rect.z - margin);
					
					draw_quad(.center_left, .center_center, {offset, 0, a.line_width, dest.rect.w - a.line_margin}, new_rect, a.front_color, loc);
					
				case Patched_appearance:

			}
			
		case Text_field_info:
			
			text := utf8.runes_to_string(e.runes[e.view_start:]);
			defer delete(text);
			
			switch a in appear {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					new_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					mid_dest : [4]f32 = {0,0, dest.rect.z - a.mid_margin, dest.rect.w - a.mid_margin};
					new_rect = draw_quad(.center_center, .center_center, mid_dest, new_rect, a.mid_color, loc);
					
					if len(e.runes) != 0 {
						text_dest := mid_dest - {0,0, a.front_margin, a.front_margin};
						draw_text(text, text_dest, new_rect, a.front_color, a, loc);
					}
					else {
						text_dest := mid_dest - {0,0, a.additional_margin, a.additional_margin};
						draw_text_param(e.bg_text, text_dest, new_rect, a.text_size, a.text_anchor, a.bold, a.italic, a.additional_color, a.fonts,
							{}, a.text_backdrop_offset, a.limit_by_height, a.limit_by_width, loc);
					}
					
				case Patched_appearance:

			}	
			
		case Panel_info:
			switch a in style.default {
				
				case Textured_appearance:
					
				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					parent_rect := draw_quad(dest.anchor, dest.self_anchor, dest.rect, parent_rect, a.bg_color, loc);
					
					for key in e.sub_elements {
						e := active_elements[key];
						element_draw(e, style, parent_rect);
					}
					
				case Patched_appearance:

			}
			
	
	}
}

@(private)
element_get :: proc (handle : Element, $T : typeid, loc := #caller_location) -> (element : T, contrainer : Element_container) {
	assert(handle in active_elements, "The handle is not valid", loc);
	contrainer = active_elements[handle];
	
	e, ok := contrainer.element.(T);
	fmt.assertf(ok, "The handle %v is not of type %v. Handle data : %v", handle, type_info_of(T), contrainer.element);
	return e, contrainer;
}

@(private)
element_cleanup :: proc(container : Element_container) {
	switch e in container.element {
		case Rect_info: 
			//TODO 

		case Button_info:
			button_destroy(e);
		
		case Checkbox_info:
			checkbox_destroy(e);
			
		case Label_info:
			label_destroy(e);
		
		case Slider_info:
			slider_destroy(e);
			
		case Int_slider_info:
			int_slider_destroy(e);
		
		case Text_field_info:
			text_field_destroy(e);
			
		case Panel_info:
			panel_destroy(e);
		
	}
}

//Use gui.destroy
@(private)
button_destroy :: proc (button : Button_info) {
	delete(button.text);
}

//Use gui.destroy
@(private)
checkbox_destroy :: proc (checkbox : Checkbox_info) {
	//Nothing
}

//Use gui.destroy
label_destroy :: proc (label : Label_info) {
	delete(label.text);
}

slider_destroy :: proc (slider : Slider_info) {
	//Nothing
}

int_slider_destroy :: proc (slider : Int_slider_info) {
	//Nothing
}

text_field_destroy :: proc (text_field : Text_field_info) {
	delete(text_field.runes);
	delete(text_field.bg_text);
}

//Use gui.destroy
@(private)
panel_destroy :: proc (panel : Panel_info) {
	
	for k in panel.sub_elements {
		e := active_elements[k];
		element_cleanup(e);
		delete_key(&active_elements, k);
	}
	 
	delete(panel.sub_elements);
}

