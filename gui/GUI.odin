package gui;

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:reflect"
import "core:intrinsics"
import "core:strconv"

import render "../render"
import utils "../utils"

////////////////// GLOBALS //////////////////

current_theme : Theme;
style_stack : [20]Theme; //MAX 20 styles, TODO make dynamic
style_stack_len : int;

current_panel : ^Panel;
panel_stack : [20]^Panel; //MAX 20 styles
current_pixel_space : [4]f32;
pixel_space_stack : [20][4]f32; //MAX 20 styles
panel_stack_len : int;

current_context : Maybe(Gui_context);
screen_panel : Panel;

////////////////// TYPES ////////////////////

Theme :: struct {

	default_style : Style,
	default_hover_style : Maybe(Style),
	default_active_style : Maybe(Style),

	styles : map[typeid][3]Style,
}

Mouse_info :: struct {

    mouse_pos : [2]f32,
    mouse_delta : [2]f32,

    scroll_delta : [2]f32,

    left_down, left_released, left_pressed,
    right_down, right_released, right_pressed,
    middle_down, middle_released, middle_pressed : bool,
}

Gui_context :: struct {
	width : f32,
	height : f32,
	unit_size : f32,

	mouse_info : Mouse_info,

	slider_sensitivity : f32,
}

Font_style :: struct {
	font : render.Font,
	font_size : f32,
	font_spacing : f32,
	font_color : [4]f32,
}

Style :: struct {

	//color of elements drawn
	bg_color : [4]f32,
	texture : Maybe(render.Texture2D),

	line_width : f32,
	line_margin : f32,
	line_texture : Maybe(render.Texture2D),

	front_color : [4]f32,
	front_margin : f32,
	
 	using font_style : Font_style,
	
	//Mesh
	rect_mesh : render.Mesh,
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

Destination :: struct {
    anchor : Anchor_point, // This decides where 0,0 is on the screen
    self_anchor : Anchor_point, // This decides at which point on element is anchored to 0,0
    rect : [4]f32,
}

//These are the all the GUI elements
Element :: union {
	Rect,
    Button,
	Checkbox,
	Slide_input,
	Slider,
	Input_field,
	Selector,
	Slot,
	Label,
}

//Common contiainer for all elements.
Element_container :: struct {

	//Content
    element : Element,
	
    //Position
    dest : Destination,

    //visability
    is_showing : ^bool,

	//This is used by some types when using mouse and most types when using controller (TODO controller)
	is_selected : bool,

	//If any of these are set, they will override the style for the specific element.
	style : Maybe(Style),
	hover_style : Maybe(Style),
	active_style : Maybe(Style),
}

Rect :: struct {
	//A simple rectangle. No data here.
}

//Button, true or false. Get the value from clicked.
Button :: struct {
	text : string,
	clicked : ^bool,
}

//Checkbox, true or false. Get the value from checked.
Checkbox :: struct {
    //Static
    checked : ^bool,
}

//A single line text input, get the value from value.
Input_field :: struct {
	value : ^string,
	//TODO current_index : int,
}

//Slider value is from 0 to 1.
Slider :: struct {
    value : ^f32,
}

//A numeric input, where user can slide while holding to mouse to change value. Alternativly the element can be clicked to write a precise value. The sensitivity can be set with slider_sensitivity in ctx.
Slide_input :: struct {
    //Static, set by user.
	value : ^f32,
	upper_bound, lower_bound : f32,

	//Dynamic, user should not touch.
	was_dragged : bool,
	current_text : strings.Builder,
}

//Ex: select difficulty (easy, intermediate, hard) contains fixed values to choose from, use selected_value to get the value.
Selector :: struct { 
    options : []string,     
    selected_value : ^int,
}

Slot :: struct {
    slot_value : rawptr,
}

Label :: struct {
    text : string,
}

//Panels can hold other elements (including other panels), the other elements will consider the panel and a sub-window.
Panel :: struct {
	//Static
	dest : Destination,
	render_texture : render.Render_texture,
	scrollable_x, scrollable_y : bool,

	//Dynamic
	scroll_pos : [2]f32,
}

////////////////// FUNCTIONS ////////////////////

init_theme :: proc () -> (pack : Theme) {

	pack = {
		styles = make(map[typeid][3]Style),
	}
	
	return pack;
}

destroy_theme :: proc (pack : ^Theme) {

	delete(pack.styles);
}

begin :: proc (slider_sensitivity : f32 = 1.0/100.0) {
	using render;

	cc := Gui_context{

		width = render.current_render_target_width,
		height = render.current_render_target_height,
		unit_size = math.min(render.current_render_target_width, render.current_render_target_height),
		
		slider_sensitivity = slider_sensitivity,

		mouse_info = {
			mouse_pos = [2]f32{render.mouse_pos.x, render.current_render_target_height - render.mouse_pos.y},
			mouse_delta = render.mouse_delta,

			scroll_delta = render.scroll_delta,

			left_down 		= is_button_down(.left),
			left_released 	= is_button_released(.left),
			left_pressed 		= is_button_pressed(.left),

			right_down 		= is_button_down(.right),
			right_released	= is_button_released(.right),
			right_pressed		= is_button_pressed(.right),
			
			middle_down 	= is_button_down(.middel),
			middle_released	= is_button_released(.middel),
			middle_pressed		= is_button_pressed(.middel),
		},
	};

	current_context = cc;
	
	screen_panel = init_panel(
		dest = {
			self_anchor = .bottom_left,
			anchor = .bottom_left,
			rect = {0, 0, cc.width / cc.unit_size, cc.height / cc.unit_size},
		}
	)

	push_panel(&screen_panel);
}

end :: proc () {
	current_context = nil;
	pop_panel(&screen_panel);
}

push_theme :: proc (style : Theme) {
	current_theme = style;
	style_stack[style_stack_len] = style;
	style_stack_len += 1;
}

pop_theme :: proc (style : Theme, loc := #caller_location) {
	
	assert(style_stack_len != 0, "You popped one too many!", loc = loc);

	style_stack_len -= 1;
	current_theme = style_stack[style_stack_len];
}

push_panel :: proc (panel : ^Panel, loc := #caller_location) {

	if ctx, ok := current_context.?; ok {

		old_panel := current_panel;

		current_panel = panel;
		current_pixel_space = get_screen_space_position_rect(current_panel.dest.rect, current_panel.dest.anchor, current_panel.dest.self_anchor, current_pixel_space, {ctx.width, ctx.height}, ctx.unit_size);

		panel_stack[panel_stack_len] = panel;
		pixel_space_stack[panel_stack_len] = current_pixel_space;
		panel_stack_len += 1;

		if panel.scrollable_x || panel.scrollable_y {
			
			if panel_stack_len != 0 {
				if old_panel.scrollable_x || old_panel.scrollable_y  {
					render.end_texture_mode(old_panel.render_texture);
				}
			}

			if panel.render_texture.texture.width == 0 || panel.render_texture.texture.height == 0 {
				panel.render_texture = render.load_render_texture(auto_cast current_pixel_space.z, auto_cast current_pixel_space.w);
			}
			if panel.render_texture.texture.width != auto_cast current_pixel_space.z || panel.render_texture.texture.height != auto_cast current_pixel_space.w {
				render.resize_render_texture(&panel.render_texture, auto_cast current_pixel_space.z, auto_cast current_pixel_space.w);
			}
			fmt.assertf(render.is_render_texture_ready(panel.render_texture), "texture is not ready : \n%#v\n", panel.render_texture);

			render.draw_shape([4]f32{100, 100, 400, 400}, color = {1,1,1,1}, texture = panel.render_texture.texture);
			render.begin_texture_mode(panel.render_texture);
			render.clear_color_depth(clear_color = {1,0,1,0})
		}
	}
	else {
		panic("there is no context", loc = loc);
	}
}

pop_panel :: proc (panel : ^Panel, loc := #caller_location) {

	assert(panel_stack_len != 0, "You popped one too many!", loc = loc);
	assert(panel == current_panel, "Panel is not current panel", loc = loc);
	
	if panel.scrollable_x || panel.scrollable_y {
		render.end_texture_mode(panel.render_texture);
		assert(render.bound_frame_buffer_id == 0);
	}

	to_draw := current_pixel_space;

	panel_stack_len -= 1;

	if panel_stack_len != 0 {
		current_panel = panel_stack[panel_stack_len-1];
		current_pixel_space = pixel_space_stack[panel_stack_len-1];

		if current_panel.scrollable_x || current_panel.scrollable_y {
			render.begin_texture_mode(current_panel.render_texture);
		}
	}
	
	//TODO what about scrollable?
	//render.draw_shape([4]f32{100, 100, 400, 400}, color = {1,1,1,1}, texture = panel.render_texture.texture);
}

/////////////////////////////////////////////////////////////////

//We could split this into draw and update. IDK if that is a good idea.
draw_element :: proc (container : ^Element_container, style : Theme = current_theme, anchor_rect_pixel : [4]f32 = current_pixel_space,
						ctx : Maybe(Gui_context) = current_context, loc := #caller_location) -> (hovering : bool, active : bool, triggered : bool) {

	assert(container.element != nil, "Element is nil", loc);
	
	stl : Style = current_theme.default_style;

	if ctx, ok := ctx.?; ok {
		
		//anchor_rect_pixel : [4]f32 = get_screen_space_position_rect(current_panel.dest.rect, current_panel.anchor, current_panel.self_anchor, anchor_rect_pixel, {ctx.width, ctx.height}, unit_size);
		
		mouse_info := ctx.mouse_info;
		unit_size := ctx.unit_size;
		
		deselect := mouse_info.left_released;
		
		if deselect {
			container.is_selected = false;
		}
		
		if container.is_showing == nil || container.is_showing^  {
			
			dest := container.dest;

			//Common for all elemetns
			elem_rect : [4]f32 = get_screen_space_position_rect(dest.rect, dest.anchor, dest.self_anchor, anchor_rect_pixel, {ctx.width, ctx.height}, unit_size)

			active = container.is_selected;
			
			if utils.collision_point_rect(mouse_info.mouse_pos, elem_rect) {
				
				hovering = true;

				if mouse_info.left_down {
					active = true;
				}
				if mouse_info.left_released {
					triggered = true;
				}
			}
			
			if hovering {
				if hover_style, ok := current_theme.default_hover_style.?; ok {
					stl = hover_style;
				}
			}
			
			if active {
				if active_style, ok := current_theme.default_active_style.?; ok {
					stl = active_style;
				}
			}

			currently_holding : typeid = reflect.union_variant_typeid(container.element);

			if currently_holding in current_theme.styles {

				stl = current_theme.styles[currently_holding][0];

				if hovering {
					stl = current_theme.styles[currently_holding][1];
				}
				if active {
					stl = current_theme.styles[currently_holding][2];
				}
			}
			
			if cthem, ok := container.style.?; ok && !hovering && !active {
				stl = cthem;
			}
			if cthem, ok := container.hover_style.?; ok && hovering && !active {
				stl = cthem;
			}
			if cthem, ok := container.active_style.?; ok && active {
				stl = cthem;
			}

			texture := stl.texture;
			line_texture := stl.line_texture;
			
			//Element specific behavior
       		switch element in &container.element {
			case Rect:
				using element;
				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);
			case Button:

				using element;

				if clicked == nil {
					fmt.panicf("Clicked on button : %s has not been set", text);
				}
				
				clicked^ = false;
				
				//Hover button
				if triggered {
					clicked^ = true;
				}

				//place text in the middle of button
				text_size : [2]f32 = render.getTextDimensions(text, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
				text_pos : [2]f32 = elem_rect.xy + elem_rect.zw/2 - text_size / 2;

				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);
				render.draw_text(text, text_pos, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size, stl.font_color);

			case Checkbox:
				using element;

				if triggered {
					checked^ = !checked^;
				}

				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);

				if checked^ {
					
					//Line (0,0) to (1,1)
					{
						p1 := elem_rect.xy + (stl.line_margin) * unit_size;
						p2 := elem_rect.xy + elem_rect.zw - (stl.line_margin) * unit_size;
						line : render.Line = {p1, p2, stl.line_width * unit_size};
						render.draw_shape(line, color = stl.front_color, texture = line_texture);
					}

					//Line (0,1) to (1,0)
					{
						p1 := [2]f32{elem_rect.x + (stl.line_margin) * unit_size, elem_rect.y + elem_rect.w - (stl.line_margin) * unit_size};
						p2 := [2]f32{elem_rect.x + elem_rect.z - (stl.line_margin) * unit_size, elem_rect.y + (stl.line_margin) * unit_size};
						
						line : render.Line = {p1, p2, stl.line_width * unit_size};
						render.draw_shape(line, color = stl.front_color, texture = line_texture);							
					}
				}

			case Slide_input:
				using element;

				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);

				if active && !container.is_selected {
					dv := mouse_info.mouse_delta.x * ctx.slider_sensitivity;
					if dv != 0 {
						value^ += dv;
						was_dragged = true;
					}
				}
				else {
					was_dragged = false;
				}

				if triggered && !was_dragged {
					container.is_selected = true;
				}

				if container.is_selected == true {
					
					if render.is_key_triggered(.backspace) {
						strings.pop_rune(&current_text);
					}
					
					if render.is_key_triggered(.v) && render.is_key_down(.control_left) {
						strings.write_string(&current_text, render.get_clipboard_string());
						container.is_selected = false;
					}

					for codepoint in render.recive_next_input() {
						if utils.is_number(codepoint) || codepoint == '.' {
							strings.write_rune(&current_text, codepoint);
						}
					}

					if render.is_key_triggered(.enter) {
						container.is_selected = false;
					}
					
					value^ = auto_cast strconv.atof(strings.to_string(current_text));
				}

				value^ = math.clamp(value^, lower_bound, upper_bound);

				if !container.is_selected {
					strings.builder_reset(&current_text);
					strings.write_string(&current_text, fmt.tprintf("%.4f",value^)); //TODO make style select precision.
				}

				//Writing input section
				text_value := strings.to_string(current_text);
				text_size : [2]f32 = render.getTextDimensions(text_value, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
				text_pos : [2]f32 = elem_rect.xy + elem_rect.zw/2 - text_size / 2;

				render.draw_text(text_value, text_pos, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size, stl.font_color);

			case Slider:
				using element;

				fm_unit := stl.front_margin * unit_size;
				
				if active {
					value^ = (mouse_info.mouse_pos.x - (elem_rect.x + fm_unit)) / (elem_rect.z - 2*fm_unit); //Something only mouse position
				}
				
				value^ = math.clamp(value^, 0, 1);

				//Determinec only by the value.
				slider_line : [2][2]f32 = {	{elem_rect.x + (elem_rect.z - 2*fm_unit) * value^ + fm_unit, elem_rect.y + stl.line_margin/2 * unit_size},
											{elem_rect.x + (elem_rect.z - 2*fm_unit) * value^ + fm_unit, elem_rect.y + elem_rect.w - stl.line_margin/2 * unit_size}}

				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);
				render.draw_shape(render.Line{slider_line[0], slider_line[1], stl.line_width * unit_size}, color = stl.bg_color, texture = line_texture);
				
			case Input_field:
				using element;

				assert(value != nil, "value is nil");
				//assert(raw_data(value^) != nil, "value^ is nil");

				if utils.collision_point_rect(mouse_info.mouse_pos, elem_rect) {
					
					//Clicks
					if mouse_info.left_released {
						container.is_selected = true;
					}
				}

				if container.is_selected == true {
					builder := strings.builder_make();
					strings.write_string(&builder, value^);
					
					if render.is_key_triggered(.backspace) {
						strings.pop_rune(&builder);
					}
					
					if render.is_key_triggered(.v) && render.is_key_down(.control_left) {
						strings.write_string(&builder, render.get_clipboard_string());
					}

					for codepoint in render.recive_next_input() {
						strings.write_rune(&builder, codepoint);
					}

					delete(value^);
					value^ = strings.to_string(builder);
				}

				to_display : string = value^[:];

				letter_size := render.getTextDimensions("A", stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size).x;
				text_size := render.getTextDimensions(to_display, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
				
				line_height := render.get_max_text_height(stl.font, stl.font_size * unit_size);

				Text_rect := elem_rect;
				Text_rect.xy += {stl.front_margin * unit_size, elem_rect.w/2 - line_height/2};
				Text_rect.z -= stl.front_margin * unit_size * 2;
				
				for text_size.x + letter_size * 2 >= elem_rect.z {
					to_display = to_display[1:];
					text_size = render.getTextDimensions(to_display, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
				}

				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);
				render.draw_text(to_display, elem_rect.xy + {stl.front_margin * unit_size, elem_rect.w/2 - line_height/2}, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
				
				head := [4]f32{elem_rect.x + text_size.x + letter_size/2 + stl.line_width * unit_size, elem_rect.y + stl.line_margin/2 * unit_size, stl.line_width * unit_size, elem_rect.w - stl.line_margin * unit_size};
				render.draw_shape(render.Line{head.xy, head.xy + {0, head.w}, stl.line_width * unit_size}, color = stl.front_color, texture = stl.line_texture);
			case Selector:
				using element;
				
				render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);

				//limit range to 0..<len(options), if set too high by user.
				selected_value^ = selected_value^ %% len(options);
				
				//place text in the middle of select_button
				assert(len(options) != 0);
				assert(selected_value^ >= 0);
				assert(options[selected_value^] != "");
				assert(len(options[selected_value^]) > 0);

				text_value := options[selected_value^];
				text_size : [2]f32 = render.getTextDimensions(text_value, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
				text_pos : [2]f32 = elem_rect.xy + elem_rect.zw/2 - text_size / 2;

				render.draw_text(text_value, text_pos, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size, stl.font_color);

				//Hover button
				if hovering {
					//Click
					if mouse_info.left_released {
						//Changes the value of select element.
						selected_value^ += 1;
						selected_value^ = selected_value^ %% len(options);
					}
				}
				case Slot:
					using element;

					//TODO swapping elements.
					render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);
				case Label:
					using element;
					render.draw_shape(elem_rect, color = stl.bg_color, texture = texture);
					
					text_size : [2]f32 = render.getTextDimensions(text, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size);
					text_pos : [2]f32 = elem_rect.xy + elem_rect.zw/2 - text_size / 2;
					render.draw_text(text, text_pos, stl.font, stl.font_size * unit_size, stl.font_spacing * unit_size, stl.font_color);
			}
		}
		else {
			switch element in &container.element {
				case Rect:
					using element;
				case Button:
					using element;
					clicked^ = false;
				case Checkbox:
					using element;
					checked^ = false;
				case Slide_input:
					using element;
					was_dragged = false;
				case Slider:
					using element;
				case Input_field:
					using element;
				case Selector:
					using element;
				case Slot:
					using element;
				case Label:
					using element;
			}
		}
	}
	else {
		panic("The gui_context is nil, did you forget to call gui.begin?", loc = loc);
	}

	return;
}

get_screen_space_position_rect :: proc(rect : [4]f32, anchor : Anchor_point, self_anchor : Anchor_point, anchor_rect_pixel : [4]f32, screen_size : [2]f32, unit_size : f32) -> [4]f32 {
	
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

add_style :: proc (Theme : ^Theme, $element_type : typeid, style, hover_style : Style, active_style : Style) where intrinsics.type_is_variant_of(Element, element_type) {

	Theme.styles[element_type] = {style, hover_style, active_style};
}