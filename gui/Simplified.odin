package gui;

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

draw_slide_input :: proc (v : f32, upper_bound, lower_bound : f32, dest : Destination) -> f32 {

	v := v;
	ele : Element_container = {
		element = init_slide_input(&v, upper_bound, lower_bound),
		dest = dest,
	}
	defer destroy_element(&ele);
	h, a, t := draw_element(&ele);

	return v;
}