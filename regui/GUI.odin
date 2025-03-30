package regui;

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
import "regui_base" //Temp

import render "../render"
import utils "../utils"

@(require_results)
init :: proc (fallback_appearance := default_appearance, loc := #caller_location) -> (state : Scene) {
	
	assert(render.state.is_init, "The render library is not initialized", loc);
	
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
		e := regui_base.active_elements[cast(i64)k];
		regui_base.element_cleanup(e);
		delete_key(&regui_base.active_elements, cast(i64)k);
	}
	
	delete(owned_elements); owned_elements = {};
	
	if len(regui_base.active_elements) == 0 {
		delete(regui_base.active_elements); regui_base.active_elements = {};
	}
	
	render.pipeline_destroy(gui_pipeline);
}

/////////////////////////////////////////////////////////////// PER FRAME ///////////////////////////////////////////////////////////////

begin :: proc (state : ^Scene, target_window : ^render.Window, loc := #caller_location) {
	assert(regui_base.bound_scene == nil, "begin has already been called.", loc);
	assert(render.state.is_begin_frame == true, "regui's begin must be called after render's begin_frame", loc);
	assert(render.state.current_target != nil, "You must set the target with render.target_begin(some_window) before calling gui.begin", loc);
	assert(state.gui_pipeline != {}, "gui_scene is not initialized", loc)
	
	regui_base.bound_scene = state;
	
	state.window = target_window;
	w, h := render.get_render_target_size(state.window);
	state.unit_size = regui_base.get_unit_size(cast(f32)w, cast(f32)h);
	
	style : Style = state.default_style;
	
	for k in state.owned_elements {
		e : ^Element_container = &regui_base.active_elements[cast(i64)k];
		regui_base.element_update(e, style, regui_base.get_screen_rect(), loc);
	}
}

end :: proc (state : ^Scene, loc := #caller_location) {
	assert(regui_base.bound_scene != nil, "begin has not been called.", loc);
	assert(regui_base.bound_scene == state, "The passed gui state does not match the begin's statement.", loc);
	assert(render.state.is_begin_frame == true, "regui's begin must be called before render's end_frame", loc);
	style : Style = state.default_style;
	
	render.pipeline_begin(state.gui_pipeline, render.camera_get_pixel_space(state.window), loc = loc);
	
	//Draw
	for k in state.owned_elements {
		e : Element_container = regui_base.active_elements[cast(i64)k];
		regui_base.element_draw(auto_cast e, style, regui_base.get_screen_rect());
	}
	
	render.pipeline_end();
	
	state.window = nil;
	regui_base.bound_scene = nil;
}

/////////////////////////////////////////////////////////////// OTHER ///////////////////////////////////////////////////////////////

//Will remove the element and free the owned data.
destroy_element :: proc (handle : Element, loc := #caller_location) {
	assert(cast(i64)handle in regui_base.active_elements, "The handle is not valid", loc);
	key, container := delete_key(&regui_base.active_elements, cast(i64)handle);
	regui_base.element_cleanup(container);
}

set_debug_draw :: proc (enable : bool) {
	regui_base.debug_draw = enable;
}

/////////////////////////////////////////////////////////////// DEFINES ///////////////////////////////////////////////////////////////

Font_appearance		:: regui_base.Font_appearance;
Colored_appearance 	:: regui_base.Colored_appearance;
Patched_appearance 	:: regui_base.Patched_appearance;
Textured_appearance :: regui_base.Textured_appearance;
Appearance 			:: regui_base.Appearance;

Style 				:: regui_base.Style;
Theme 				:: regui_base.Theme;
Anchor_point 		:: regui_base.Anchor_point;
Destination 		:: regui_base.Destination;

Element 			:: regui_base.Element;
Panel 				:: regui_base.Panel;

/*
Rect 				:: regui_base.Rect;
Button 				:: regui_base.Button;
Checkbox 			:: regui_base.Checkbox;
Label 				:: regui_base.Label;
Slider 				:: regui_base.Slider;
Int_slider 			:: regui_base.Int_slider;
Text_field 			:: regui_base.Text_field;
Int_field 			:: regui_base.Int_field;
Float_field 		:: regui_base.Float_field;
Text_area 			:: regui_base.Text_area;
Radio_buttons 		:: regui_base.Radio_buttons;
Dropdown 			:: regui_base.Dropdown;

Bar 				:: regui_base.Bar;
Slot 				:: regui_base.Slot;
Color_picker 		:: regui_base.Color_picker;
Gradient_picker 	:: regui_base.Gradient_picker;
Text_editor 		:: regui_base.Text_editor;
Custom 				:: regui_base.Custom;

Split_panel 		:: regui_base.Split_panel;
Accordion 			:: regui_base.Accordion;
Screen_panel 		:: regui_base.Screen_panel;
Horizontal_bar 		:: regui_base.Horizontal_bar;
Vertical_bar 		:: regui_base.Vertical_bar;

Handle 				:: regui_base.Handle;
*/

Tooltip 			:: regui_base.Tooltip;
Element_info 		:: regui_base.Element_info;
Rect_info 			:: regui_base.Rect_info;
Button_info 		:: regui_base.Button_info;
Checkbox_info 		:: regui_base.Checkbox_info;
Label_info 			:: regui_base.Label_info;
Slider_info 		:: regui_base.Slider_info;
Int_slider_info 	:: regui_base.Int_slider_info;

Base_text_info 		:: regui_base.Base_text_info;
Text_field_info 	:: regui_base.Text_field_info;
Custom_info 		:: regui_base.Custom_info;
Panel_info 			:: regui_base.Panel_info;
Element_container 	:: regui_base.Element_container;
Parent 				:: regui_base.Parent;
Scene 				:: regui_base.Scene;

Input 				:: regui_base.Input;