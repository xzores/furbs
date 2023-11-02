package gui;

import "core:fmt"
import "core:strings"
import "core:encoding/json"

////////////////////////////////////////////////////////////////////////////////////
//The is the simplified interface, this is more like your classical gui interface.//
////////////////////////////////////////////////////////////////////////////////////

//TODO what about sound?
draw_button :: proc (text : string, dest : Destination) -> (clicked : bool) {
	
	ele : Element_container = {
		element = init_button(text, &clicked),
		dest = dest,
	}
	defer destroy_element(&ele);

	h, a, t := draw_element(&ele);

	return;
}

draw_label :: proc (text : string, dest : Destination, style : Maybe(Style) = nil) {

	ele : Element_container = {
		element = init_label(text),
		dest = dest
	}

	if s, ok := style.?; ok {
		ele.style = s;
		ele.hover_style = s;
		ele.active_style = s;
	};

	defer destroy_element(&ele);
	h, a, t := draw_element(&ele);
}

draw_rect :: proc (dest : Destination, style : Maybe(Style) = nil) {

	ele : Element_container = {
		element = init_rect(),
		dest = dest
	}

	if s, ok := style.?; ok {
		ele.style = s;
		ele.hover_style = s;
		ele.active_style = s;
	};

	defer destroy_element(&ele);
	h, a, t := draw_element(&ele);
}

draw_checkbox :: proc (checked : bool, dest : Destination) -> bool {
	
	checked : bool = checked;

	ele : Element_container = {
		element = init_checkbox(&checked),
		dest = dest,
	}
	defer destroy_element(&ele);
	h, a, t := draw_element(&ele);

	return checked;
}

//TODO this might not be possaible with a slider_input...
draw_slide_input :: proc (v : f32, selected: bool, lower_bound, upper_bound : f32, dest : Destination) -> (f32, bool) {
	v := v;
	
	element := init_slide_input(&v, lower_bound, upper_bound);
	strings.write_string(&element.current_text, fmt.tprintf("%.4f",v)); //TODO make style select precision, also selection does not work

	ele := Element_container{element = element, dest = dest, is_selected = selected};
	defer destroy_element(&ele);
	
	h, a, t := draw_element(&ele);

	return v, ele.is_selected;
}

draw_slider :: proc (value : f32, dest : Destination) -> f32 {

	value := value;
	ele : Element_container = {
		element = init_slider(&value),
		dest = dest,
	}
	defer destroy_element(&ele);
	
	h, a, t := draw_element(&ele);

	return value;
}