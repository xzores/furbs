package gui;

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:reflect"
import "core:intrinsics"
import "core:strconv"
import "core:mem"

import render "../render"
import utils "../utils"


////////////////// TYPES ////////////////////


Colored_appearance :: struct {

	// Color of elements drawn
	bg_color : [4]f32,		// This is the background color
	
	// It is the thing placed before the background, but non-interactive or changing.
	mid_color : [4]f32,		// This is the color that on the element placed on top of the background.
	mid_margin : f32,		// may be negative

	// Front are the active elements, like the _ when writing or the color of the text.
	front_color : [4]f32,	// Color of text, line or alike.
	front_margin : f32,		// may be negative
	bold, italic : bool,

	// This is how lines are drawn and are often tied to front_color and margin.
	line_width : f32,
	
 	fonts : render.Fonts, // Used if the element contains text
	
	// Some elements can also be rounded
	// Some cannot like the radio button as it is already round.
	rounded : bool, // TODO
}

// A single texture is passed, and the borders are defined from that.
Patched_appearance :: struct {
 	// TODO
	
	// Repeat, or stretch? or both?
}

// The textures will stretch to reach its size.
// This does not look good on dynamically sized objects, see Patch_appearance or Colored_appearance.
// But is it simple to set up.
Textured_appearance :: struct {
	// TODO
}

// Determines how GUI elements look.
// Can be applied to everything, per type, or per instance.
Appearance :: union {
	Colored_appearance,
	Patched_appearance,
	Textured_appearance,
}

// A collection of appearances.
Style :: struct {
	default : Appearance,
	hover : Maybe(Appearance),
	active : Maybe(Appearance),
}

Theme :: struct {
	styles : map[typeid]Style,
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

//Common for all elements, determines screen position in a 0-1 range.
//Well the range is 0-1 for a square screen
//For a non-square screen the range will extend in the longest direction propertionally to the width/heigth or heigth/width ratio.
//This ensures that all elements allways are placed correct relativly to each other.
Destination :: struct {
    anchor : Anchor_point, // This decides where 0,0 is on the screen
    self_anchor : Anchor_point, // This decides at which point on element is anchored to 0,0
    rect : [4]f32,
}

//These are the all the GUI elements
Element :: distinct i32;

//These are GUI primitives handles
Rect :: struct { e : Element, };
Button :: struct { e : Element, };
Checkbox :: struct { e : Element, };
Label :: struct { e : Element, };
Slider :: struct { e : Element, };
Int_field :: struct { e : Element, };
Float_field :: struct { e : Element, };
Text_field :: struct { e : Element, };
Text_area :: struct { e : Element, };
Radio_buttons :: struct { e : Element, };
Dropdown :: struct { e : Element, };

//There are kinda special, used mainly in games
Progess_bar :: struct { e : Element, };
Slot :: struct { e : Element, };
Color_picker :: struct { e : Element, };
Gradient_picker :: struct { e : Element, };
Custom :: struct { e : Element, };

//These panels handles 
Panel :: struct { e : Element, };			//A panel contains other elements
Split_panel :: struct { e : Element, }; 	//This is panel with multiable smaller panels, they can be resized and moved around by the user.
Accordion :: struct { e : Element, };		//This can be opened to revieal more (kinda like a "spoiler")
Screen_panel :: struct { e : Element, };	//This takes up the entire screen, used to bundle elements together that needs to be hidden/shown. Good for menus
Horizontal_bar :: struct { e : Element, }; //These fill the entire screen in a dimension and act as a panel
Vertical_bar :: struct { e : Element, };	//These fill the entire screen in a dimension and act as a panel

Rect_info :: struct {
	
}

//Button, true or false. Get the value from clicked.
Button_info :: struct {
	//Set by user
	text : string,
	clicked : ^bool,

	//Internal use
	last_down : bool,
	down : bool,
}

//A tooltip can be both a string or a Panel
//If it is a string then it will be displayed when hovering
//If it is a panel than it will be displayed when hovering
Tooltip :: union {
	string,
	Panel,
}

//These hold the information about each element
Element_info :: union {
	Rect_info,
	Button_info,
}

//Common contiainer for all elements.
Element_container :: struct {

	//Content
    element : Element_info,
	
    //Position
    dest : Destination,

    //visability
    is_showing : bool,

	//This is used by some types when using mouse and most types when using controller (TODO controller)
	is_selected : bool,
	
	//What will be displayed when hovering the elements (optional) may be nil
	tooltip : Tooltip,

	//TODO hover, click sounds

	//User data, so the user can use the callback system if wanted (not recommended)
	user_data : rawptr,
	
	//If any of these are set, they will override the style for the specific element.
	style : Maybe(Style),
	hover_style : Maybe(Style),
	active_style : Maybe(Style),
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


Gui_state :: struct {

	default_style : Style,
	Theme : Theme,

	target : render.Render_target,
	
	active_elements : map[i32]Element_container,
	
	unit_size : f32,
	
	gui_pipeline : render.Pipeline,
}

current_element_index : i32;
bound_state : ^Gui_state;

////////////////// USER FUNCTIONS ////////////////////

@(require_results)
init :: proc (loc := #caller_location) -> (state : Gui_state) {
	using state;
	
	active_elements = make(map[i32]Element_container);
	gui_pipeline = render.pipeline_make(render.get_default_shader(), .blend, false, false);

	default_style = {
		default = Colored_appearance{
			bg_color = {0.3,0.3,0.3,1},

			mid_color = {0.6,0.6,0.6,1},
			mid_margin = 0.01,

			front_color = {0,0,0,1},	
			front_margin = 0.015,
			line_width = 0.03,
			
			fonts = render.get_default_fonts(),
			rounded = false,
		},
		hover = nil,
		active = nil,
	}

	return;
}

destroy :: proc (using state : ^Gui_state) {

	for k, e in active_elements {
		element_cleanup(e);
		delete_key(&active_elements, k);
	}

	delete(active_elements); active_elements = {};
	
	render.pipeline_destroy(gui_pipeline);
}

begin :: proc (using state : ^Gui_state, render_target : render.Render_target, loc := #caller_location) {
	assert(bound_state == nil, "begin has already been called.", loc);
	assert(render.state.is_begin_frame == true, "regui's begin must be called after render's begin_frame", loc);
	bound_state = state;

	target = render_target;
	w, h := render.get_render_target_size(target);
	unit_size = get_unit_size(cast(f32)w, cast(f32)h);

	//Do logic
}

end :: proc (using state : ^Gui_state, loc := #caller_location) {
	assert(bound_state != nil, "begin has not been called.", loc);
	assert(bound_state == state, "The passed gui state does not match the begin's statement.", loc);
	assert(render.state.is_begin_frame == true, "regui's begin must be called before render's end_frame", loc);
	
	render.target_begin(target, nil, {});
	render.pipeline_begin(gui_pipeline, render.camera_get_pixel_space(target));

	style : Style = state.default_style;
	appear : Appearance = style.default;

	//Draw
	for k, e in active_elements {

		element_draw(auto_cast k, appear, loc);
	}
	render.pipeline_end();
	render.target_end();

	target = nil;
	bound_state = nil;
}

//Common for all elements, only use if you are doing a custom element.
element_make :: proc (state : ^Gui_state, container : Element_container, loc := #caller_location) -> i32 {
	assert(state != nil, "The bound state is nil", loc)
	using state;

	current_element_index += 1;
	active_elements[current_element_index] = container;

	return current_element_index;
}

//Common for all elements
element_destroy :: proc (using state : ^Gui_state, handle : Element, loc := #caller_location) {
	assert(cast(i32)handle in active_elements, "The handle is not valid", loc);
	key, container := delete_key(&active_elements, cast(i32)handle);
	element_cleanup(container);
}

//Clicked will refer to a boolean, the boolean will be made true in the frame button is clicked.
//Clicked may be nil
//The text is copied, so you can delete it when wanted.
button_make :: proc (state : ^Gui_state, dest : Destination, text : string, clicked : ^bool, show : bool = true, tooltip : Tooltip = nil, user_data : rawptr = nil,
					style : Maybe(Style) = nil, hover_style : Maybe(Style) = nil, active_style : Maybe(Style) = nil, loc := #caller_location) -> Button {

	element : Button_info = {
		clicked = clicked,
		text = strings.clone(text),
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		tooltip = tooltip,
		style = style,
		hover_style = hover_style,
		active_style = active_style,
	}

	return {auto_cast element_make(state, container, loc)};
}

button_is_down :: proc (button : Button, loc := #caller_location) -> bool {
	info := element_get(button.e, Button_info, loc);
	return info.down;
}

button_is_pressed :: proc (button : Button, loc := #caller_location) -> bool {
	info := element_get(button.e, Button_info, loc);
	return !info.last_down && info.down;
}

button_is_released :: proc (button : Button, loc := #caller_location) -> bool {
	info := element_get(button.e, Button_info, loc);
	return info.last_down && !info.down;
}

////////////////// Private Functions ////////////////////

draw_quad :: proc (anchor : Anchor_point, self_anchor : Anchor_point, rect : [4]f32, color : [4]f32, loc := #caller_location) -> [4]f32 {
	
	w, h := render.get_render_target_size(bound_state.target);
	rect := get_screen_space_position_rect(anchor, self_anchor, rect, {0,0,cast(f32)w,cast(f32)h}, bound_state.unit_size);
	render.draw_quad_rect(rect, 0, color, loc);

	return rect;
}

//position, size and spacing is in unit size coordinates (0-1 ish)
//place_rect is in screen size coordinates (0-2000 ish)
draw_text :: proc (text : string, position : [2]f32, size : f32, place_rect : [4]f32, bold, italic : bool, spacing : f32, color : [4]f32, fonts : render.Fonts) {

	unit_size := bound_state.unit_size;
	font := render.text_get_font_from_fonts(bold, italic, fonts);

	fmt.printf("position : %v\n", render.text_get_max_height());

	rect := get_screen_space_position_rect(.center_center, .center_center, render.text_get_bounds(text, position, font, size), place_rect, unit_size);

	fmt.printf("rect : %v\n", rect);

	render.pipeline_end();
	render.text_draw(text, rect.xy, rect.w, bold, italic, spacing, color, fonts);
	render.pipeline_begin(bound_state.gui_pipeline, render.camera_get_pixel_space(bound_state.target));
}

get_unit_size :: proc (width, height : f32) -> f32 {
	return math.min(width, height);
}

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

        case .bottom_left     :
            //No code required

        case .bottom_center   :
            rectangle.x += anchor_rect_pixel.z / 2;
			
        case .bottom_right    :
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

@(private)
element_draw :: proc (handle : Element, appear : Appearance, loc := #caller_location) {
	using bound_state;
	container := active_elements[cast(i32)handle];
	dest := container.dest;

	switch e in container.element {
		case Rect_info: 
			//TODO
		
		case Button_info:

			switch a in appear {

				case Textured_appearance:

				case Colored_appearance:
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					
					draw_quad(dest.anchor, dest.self_anchor, dest.rect, a.bg_color, loc);
					mid_dest := dest.rect - {0,0,a.mid_margin,a.mid_margin};
					cont_rect := draw_quad(dest.anchor, dest.self_anchor, mid_dest, a.mid_color, loc);
					//TODO text anchor,
					font_dest : [2]f32 = mid_dest.xy + {a.front_margin, a.front_margin};
					draw_text(e.text, font_dest, 0.1, cont_rect, a.bold, a.italic, 0, a.front_color, a.fonts);
					//{a.mid_margin/2, a.mid_margin/2, -2*a.mid_margin, -2*a.mid_margin}

				case Patched_appearance:

			}

	}
}

@(private)
element_get :: proc (handle : Element, $T : typeid, loc := #caller_location) -> T {
	using bound_state;
	assert(cast(i32)handle in active_elements, "The handle is not valid", loc);
	contrainer := active_elements[cast(i32)handle];

	e, ok := contrainer.element.(T);
	fmt.assertf(ok, "The handle %v is not of type %v. Handle data : %v", handle, type_info_of(T), contrainer.element);
	return e;
}


@(private)
element_cleanup :: proc(container : Element_container) {
	switch e in container.element {
		case Rect_info: 
			//TODO 

		case Button_info:
			button_destroy(e);

	}
}

//Use gui.destroy
@(private)
button_destroy :: proc (button : Button_info) {
	delete(button.text);
}

