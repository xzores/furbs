package gui

import "core:reflect"
import "core:fmt"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:encoding/json"
import "core:os"

import "../render"
import "../utils"

//Int = Intermediate
Int_style :: struct {

	//color of elements drawn
	bg_color : [4]f32,
	texture : string, //relative path

	line_width : f32,
	line_margin : f32,
	line_texture : string, //relative path

	front_color : [4]f32, //FRONT not font
	front_margin : f32,
}

//Int = Intermediate
Int_gui_theme :: struct {

	default_style : Int_style,
	default_hover_style : Int_style,
	default_active_style : Int_style,
	
	styles : map[string][3]Int_style,
}

//The font is passed because this is likely shared between all/many of the styles, and so loading it many times would be a waste.
load_style_from_filename :: proc (path : string, font_style : Font_style, resave := true, loc := #caller_location) -> Style {

	data, ok := os.read_entire_file_from_filename(path);
	defer delete(data);

	fmt.assertf(ok, "loading style for %v failed", path, loc = loc);
	
	if resave {
		return load_style_from_mem(data, font_style, path);
	}
	else {
		return load_style_from_mem(data, font_style);
	}
}

int_style_to_style :: proc(istyle : Int_style, font_style : Font_style) -> (style : Style) {

	style.font_style 		= font_style;
	style.bg_color 			= istyle.bg_color;
	if istyle.texture != "" {
		style.texture 			= render.load_texture_from_file(istyle.texture);
	}

	style.line_width 		= istyle.line_width;
	style.line_margin 		= istyle.line_margin;
	if istyle.line_texture != "" {
		style.line_texture 		= render.load_texture_from_file(istyle.line_texture);
	}

	style.front_color 		= istyle.front_color;
	style.front_margin 		= istyle.front_margin;

	return;
}

//When loading the data, it is possiable to save out the result to a file, this helps ensure the json file contains all the needed fields.
load_style_from_mem :: proc (json_data : []u8, font_style : Font_style, save_to : string = "") -> (style : Style) {

	istyle : Int_style;
	err := json.unmarshal(json_data, &istyle);

	if err != nil {
		fmt.printf("Failed to load style, Err: %#v\n", err)
	} else {
		fmt.printf("\nSuccesfully loaded style\n")
	}

	if save_to != "" {
		data, err := json.marshal(istyle, {pretty = true});
	    defer delete(data);

    	assert(err == nil);
    	os.write_entire_file(save_to, data);
	}
	
	//Convert the intermetiate to a real style.
	return int_style_to_style(istyle, font_style);
}

load_theme_from_filename :: proc (path : string, font_style : Font_style, resave := true, loc := #caller_location) -> Theme {

	data, ok := os.read_entire_file_from_filename(path);
	defer delete(data);

	fmt.assertf(ok, "loading theme for %v failed", path, loc = loc);
	
	if resave {
		return load_theme_from_mem(data, font_style, path);
	}
	else {
		return load_theme_from_mem(data, font_style);
	}
}

load_theme_from_mem :: proc(json_data : []u8, font_style : Font_style, save_to : string = "", loc := #caller_location) -> (theme : Theme) {
	
	itheme : Int_gui_theme;
	err := json.unmarshal(json_data, &itheme);

	if err != nil {
		fmt.panicf("Failed to load theme, Err: %#v\n", err)
	} else {
		fmt.printf("\nSuccesfully loaded theme\n")
	}

	if save_to != "" {
		data, err := json.marshal(itheme, {pretty = true});
	    defer delete(data);

    	assert(err == nil);
    	os.write_entire_file(save_to, data);
	}
	
	theme.default_style = int_style_to_style(itheme.default_style, font_style);
	theme.default_hover_style = int_style_to_style(itheme.default_hover_style, font_style);
	theme.default_active_style = int_style_to_style(itheme.default_active_style, font_style);

	for type_name, istyle in itheme.styles {
		fmt.assertf(utils.is_type_name_in_union(Element, type_name), "The typename %v is not a valid gui element", type_name, loc = loc)
		
		theme.styles[utils.type_name_in_union_to_typeid(Element, type_name)] = {

			int_style_to_style(istyle[0], font_style),
			int_style_to_style(istyle[1], font_style),
			int_style_to_style(istyle[2], font_style),
		}
	}
	
	return;
}

/*
display_fields :: proc (target_panel : ^Element_container, to_display : any, show : ^bool, scrollable := true) {

    using strings;

	p, ok := &target_panel.element.(Panel);
	assert(ok);
	p.scrollable = scrollable;

    sf := reflect.struct_fields_zipped(to_display.id);
    

    current_position : [2]f32;
    elem_size : [2]f32;
	for f in sf {

        ti : ^runtime.Type_Info = f.type;
        if named_type_info, ok := ti.variant.(runtime.Type_Info_Named); ok {
            ti = named_type_info.base;
        }

        element : Element_container;

		if ti == type_info_of(bool) {

            switch f.tag {

                case "checked":
                    element = {
                
                        anchor = .top_left,

                        element = Checkbox {
                            border = 0.003,
                            color_outer = {150,150,150,255},
                            color_inner = {100,100,100,255},
                            checked  = cast(^bool)(cast(uintptr)to_display.data + f.offset),
                            description = fmt.aprintf("%v", f.name),
                            description_text_color = {255,255,255,255},
                            cross_color = {255,255,255,255},
                            description_placement = .north,
                        },
                        rect  = {current_position.x, current_position.y, 0.05, 0.05},
                        is_showing = show,
                    }
                
                case "button":

                    fmt.printf("Created button")
                    element = {
                        

                        anchor      = .top_left,
                        self_anchor = .top_left,

                        color = {100,100,100,100},
                        rect  = {current_position.x, current_position.y, target_panel.rect.z / 2, 0.05},

                        element = Button {
                            color = {100,100,100,100},
                            clicked     = cast(^bool)(cast(uintptr)to_display.data + f.offset),
                            text        = fmt.aprintf("%v", f.name),
                            text_color  = {100,100,100,255},
                        },

                        hover = Hover {
                            color = {255,255,255,255},
                        },
                        is_showing = show
                    };

                //No tag
                case "":
                
                case :
                    panic("Tag not set")
            }
            
            
		}
        else if ti == type_info_of(string) {

            element = {

                anchor = .top_left,

                element = Input {
                    border = 0.003,
                    color_inner = {100,100,100,255}, 
                    value       =  cast(^string)(cast(uintptr)to_display.data + f.offset),
                    description = fmt.aprintf("%v", f.name),
                    input_color = {230,230,230,255},
                    description_text_color = {255,255,255,255},
                    description_placement = .north,
                },

                rect  = {current_position.x, current_position.y, 0.2, 0.05},
                is_showing = show,
            }
        } 
        else if ti == type_info_of(f32) {

            if _, ok := reflect.struct_tag_lookup(f.tag, "input_float"); ok {

                val, ok1 := reflect.struct_tag_lookup(f.tag, "bounds")

                split_val := split_n(cast (string)val, "-", 2)

                assert(len(split_val) == 2);

                lower_bound, _ := strconv.parse_f32(split_val[0]);
                upper_bound, _ := strconv.parse_f32(split_val[1]);

                element = {

                        anchor = .top_left,

                        element = Slide_input {
                            border = 0.003,
                            color_inner = {100,100,100,255}, 
                            value       =  cast(^f32)(cast(uintptr)to_display.data + f.offset),
                            description = fmt.aprintf("%v", f.name),
                            input_color = {230,230,230,255},
                            description_text_color = {255,255,255,255},
                            upper_bound = upper_bound,
                            lower_bound = lower_bound,
                            description_placement = .north,
                        },

                        rect  = {current_position.x, current_position.y, 0.2, 0.05},
                        is_showing = show,
                }
            } 
            else if _, ok := reflect.struct_tag_lookup(f.tag, "slider"); ok {
                
                element = {

                    anchor = .top_left,

                    element = Slider {
                        border = 0.003,
                        color_inner = {100,100,100,255}, 
                        value       =  cast(^f32)(cast(uintptr)to_display.data + f.offset),
                        description = fmt.aprintf("%v", f.name),
                        description_text_color = {255,255,255,255},
                        description_placement = .north,
                    },

                    rect  = {current_position.x, current_position.y, 0.2, 0.05},
                    is_showing = show,
                } 
            } 
            else {
                panic("f32 tag not implemented")
            }
        }
        else if _, ok := ti.variant.(runtime.Type_Info_Struct); ok {

            struct_ptr : rawptr = cast(^rawptr)(cast(uintptr)to_display.data + f.offset)
            my_new_sub_type : any = any{data = struct_ptr, id = f.type.id };

            element = {
                
                anchor = .top_left,
                self_anchor = .top_left,

                rect = {current_position.x, current_position.y, target_panel.rect.z, 0},

                element = Panel {

                    elements = make([dynamic]Element_container),
                },

                is_showing = show,
            }

            display_fields(&element, my_new_sub_type, show, false)
        }

        if element.is_showing != nil {
            elem_size = get_element_size(&element, 1);
    
            if current_position.x + elem_size.x < target_panel.rect.z{
                
                current_position += {elem_size.x, 0};
                
            } else {
                current_position.x = 0;
                current_position.y += elem_size.y;
            }

            append(&p.elements, element);
        }
	}
}
*/