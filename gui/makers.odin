package gui;

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:slice"

import utils "../utils"
import render "../render"

//TODO rounded
make_style :: proc(font_style : Font_style, bg_color : [4]f32, front_color : [4]f32 = {1, 1, 1, 1}, texture : Maybe(render.Texture2D) = nil,
					line_width : f32 = 0.01, line_margin : f32 = 0.01, line_texture :  Maybe(render.Texture2D) = nil, front_margin : f32 = 0.01) -> (style : Style) {
	
	style = Style{
		bg_color,
		texture,
		
		line_width,
		line_margin,
		line_texture,

		front_color,
		front_margin,
		
		font_style,
		{},//rect_mesh = nil, //TODO 
	}

	return;
}

////////////////////////

init_panel :: proc(dest : Destination, scrollable_x := false, scrollable_y := false, resizeable := false, moveable := false, moveable_area : Maybe(Destination) = nil) -> (panel : Panel) {

	panel.dest = dest;

	panel.scrollable_x = scrollable_x;
	panel.scrollable_y = scrollable_y;

	return;
}

destroy_panel :: proc(p : ^Panel) {


}

////////////////////////

init_rect :: proc() -> Rect {
	return {};
}

init_button :: proc (button_text : string, button_clicked : ^bool) -> Button{
	return {strings.clone(button_text), button_clicked};
}

init_label :: proc (text : string) -> Label{
	
	return {strings.clone(text)};
}

init_slide_input :: proc(value : ^f32, lower_bound, upper_bound : f32) -> Slide_input {

	return {value, 
			lower_bound,
			upper_bound,
			false,
			strings.builder_make(),
			}
}

init_slider :: proc (value : ^f32) -> Slider {
	return {value = value}
}

init_checkbox :: proc(checked : ^bool) -> Checkbox {
	return {checked};
}

init_input_field :: proc(text : ^string) -> Input_field {
	return {text};
}

init_slot :: proc() -> Slot {
	return {nil};
}

init_selector :: proc (options : []string, selected_value : ^int) -> Selector {

	new_opt := make([]string, len(options))

	for &s, i in new_opt {
		s = strings.clone(options[i]);
	}
	
	return {
		new_opt,
		selected_value,
	}
}

destroy_element :: proc (container : ^Element_container) {
	
	switch element in &container.element {
		case Rect:
			using element;
		case Button:
			delete(element.text);
		case Slide_input:
			strings.builder_destroy(&element.current_text);
		case Slider:
		case Checkbox:
		case Input_field:
		case Selector:
			using element;
			for o in options {
				delete(o);
			}
			delete(options);
		case Slot:
			//TODO delete user data?
		case Label:
			delete(element.text);
	}
}