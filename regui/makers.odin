package gui;

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

import render "../render"
import utils "../utils"

/////////////////////////////////////////////////////////////// RECT /////////////////////////////////////////////////////////////// 
/*
The rect is simple rectangle it is not interactable (expect for the tooltop).
Can be used to display a simple color, texture or alike.
You likely want to use a label or a panel.
*/

make_rect :: proc (parent : Parent, dest : Destination, show : bool = true, tooltip : Tooltip = nil,
					 appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Rect {
	
	def_appearance, _, _, _ := get_appearences(parent, appearance, nil, nil, nil);
	
	element : Rect_info = {}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = nil,
			selected = nil,
			active = nil,
		}
	}

	return auto_cast element_make(parent, container, loc);
}

////////////////////////////////////////////////////////////// BUTTON ////////////////////////////////////////////////////////////// 

button_is_hover :: proc (button : Button, loc := #caller_location) -> bool {
	info, container := element_get(auto_cast button, Button_info, loc);
	return container.is_hover;
}

button_is_selected :: proc (button : Button, loc := #caller_location) -> bool {
	info, container := element_get(auto_cast button, Button_info, loc);
	return container.is_selected;
}

button_is_pressed :: proc (button : Button, loc := #caller_location) -> bool {
	info, container := element_get(auto_cast button, Button_info, loc);
	return container.is_active;
}

//Clicked will refer to a boolean, the boolean will be made true in the frame button is clicked.
//Clicked may be nil
//The text is copied, so you can delete it when wanted.
make_button :: proc (parent : Parent, dest : Destination, text : string, clicked : ^bool, show : bool = true, tooltip : Tooltip = nil,
		appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Button {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	element : Button_info = {
		clicked = clicked,
		text = strings.clone(text),
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}
	
	return auto_cast element_make(parent, container, loc);
}

/////////////////////////////////////////////////////////////// CHECKBOX /////////////////////////////////////////////////////////////// 

checkbox_is_hover :: proc (checkbox : Checkbox, loc := #caller_location) -> bool {
	info, container := element_get(auto_cast checkbox, Checkbox_info, loc);
	return container.is_hover;
}

checkbox_is_selected :: proc (checkbox : Checkbox, loc := #caller_location) -> bool {
	info, container := element_get(auto_cast checkbox, Checkbox_info, loc);
	return container.is_active;
}

checkbox_is_checked :: proc (checkbox : Checkbox, loc := #caller_location) -> bool {
	info, container := element_get(auto_cast checkbox, Checkbox_info, loc);
	return info.checked;
}

make_checkbox :: proc (parent : Parent, dest : Destination, initial_checked : bool, checked : ^bool, show : bool = true, tooltip : Tooltip = nil,
		appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Button {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	element : Checkbox_info = {
		checked = initial_checked,
		checked_res = checked,
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast element_make(parent, container, loc);
}

////////////////////////////////////////////////////////////// LABEL ////////////////////////////////////////////////////////////// 

make_label :: proc (parent : Parent, dest : Destination, text : string, show : bool = true, tooltip : Tooltip = nil,
		appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Button {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	element : Label_info = {
		text = strings.clone(text),
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast element_make(parent, container, loc);
}

////////////////////////////////////////////////////////////// SLIDER ////////////////////////////////////////////////////////////// 

make_slider :: proc (parent : Parent, dest : Destination, init_value, min_value, max_value : f32, value : ^f32, show : bool = true, tooltip : Tooltip = nil,
		appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Button {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	element : Slider_info = {
		min_val = min_value,
		max_val = max_value,
		current_val = init_value,
		current_val_res = value,
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast element_make(parent, container, loc);
}

////////////////////////////////////////////////////////////// INT SLIDER ////////////////////////////////////////////////////////////// 

make_int_slider :: proc (parent : Parent, dest : Destination, init_value, min_value, max_value : int, value : ^int, show : bool = true, tooltip : Tooltip = nil,
		appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Button {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	element : Int_slider_info = {
		min_val = min_value,
		max_val = max_value,
		current_val = init_value,
		current_val_res = value,
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast element_make(parent, container, loc);
}

////////////////////////////////////////////////////////////// TEXT FEILD ////////////////////////////////////////////////////////////// 

make_text_field :: proc (parent : Parent, dest : Destination, init_text : string, bg_text : string, max_rune_length : int, text_res : ^string, show : bool = true, tooltip : Tooltip = nil,
		appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Button {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	fmt.printf("def_appearance : %#v\n", def_appearance);
	
	element : Text_field_info = {
		max_rune_length = 100,
		runes = nil,
		view_start = 0,
		cursor_pos = 0,
		bg_text = strings.clone(bg_text),
		text_res = text_res,
	}
	
	element.runes = slice.to_dynamic(utf8.string_to_runes(init_text));
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		stay_selected = true,
		is_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast element_make(parent, container, loc);
}

////////////////////////////////////////////////////////////// PANEL ////////////////////////////////////////////////////////////// 

make_panel :: proc (parent : Parent, dest : Destination, show : bool = true, tooltip : Tooltip = nil,
					appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil, active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> Panel {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := get_appearences(parent, appearance, hover_appearance, selected_appearance, active_appearance);
	
	element : Panel_info = {
		
	}
	
	container : Element_container = {
		element = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = tooltip,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast element_make(parent, container, loc);
}











