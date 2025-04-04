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

get_screen_rect :: proc () -> [4]f32 {
	w, h := render.get_render_target_size(bound_scene.window);
	return {0,0,cast(f32)w,cast(f32)h};
}

get_unit_size :: proc (width, height : f32) -> f32 {
	return math.min(width, height);
}

//Takes in unit space coordinates (0-1 ish)
//Returns screen space coordinates (0-2000 ish)
//anchor: where is the rect anchored
//self_anchor: which part of the rect is the origin (anchored place)
//anchor_rect_pixel is a parent rect given in pixels space (0-2000 ish), will redifine what "the screen" is.
//Unit size is the unit_size (0-2000 ish), see get_unit_size
get_screen_space_position_rect :: proc(anchor : Anchor_point, self_anchor : Anchor_point, rect : Rect, anchor_rect_pixel : [4]f32, unit_size : f32) -> [4]f32 {
	rect := get_rect(rect, anchor_rect_pixel);
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



////////////////////////////////////////// INPUT  //////////////////////////////////////////

is_hovered :: proc (dest : Destination, parent_rect : [4]f32) -> bool {
	rect := get_screen_space_position_rect(dest.anchor, dest.self_anchor, dest.rect, parent_rect, bound_scene.unit_size);
	
	return collision_point_rect(mouse_pos(), rect);
}

is_selected :: proc (dest : Destination, parent_rect : [4]f32) -> bool {
	
	return is_hovered(dest, parent_rect) && mouse_button_pressed(.mouse_button_1);
}

is_activated :: proc (dest : Destination, parent_rect : [4]f32) -> bool {
	
	return is_hovered(dest, parent_rect) && mouse_button_released(.mouse_button_1);
}

mouse_pos :: proc() -> [2]f32 {
	mp := render.mouse_pos(bound_scene.window);
	return {mp.x, mp.y};	
}

mouse_button_down :: render.is_button_down;
mouse_button_pressed :: render.is_button_pressed;
mouse_button_released :: render.is_button_released;

collision_point_rect :: utils.collision_point_rect;









////////////////////////////////////////// appearences //////////////////////////////////////////

get_appearences :: proc (parent : Parent, appearance, hover_appearance, selected_appearance, active_appearance : Maybe(Appearance), loc := #caller_location) -> (a : Appearance, a_hover, a_sel, a_act : Maybe(Appearance)) {
	
	default_style : Style;
	
	switch v in parent {
		
		case ^Scene:
			default_style = v.default_style;
			
		case Panel:
			p, cont := element_get(auto_cast v, Panel_info);
		 	default_style = cont.style;
			
	}
	
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







////////////////////////////////////////// Drawing //////////////////////////////////////////

//returns what it drew in screen space coordinates.
draw_quad :: proc (anchor : Anchor_point, self_anchor : Anchor_point, rect : [4]f32, parent_rect : [4]f32, color : [4]f32, loc := #caller_location) -> [4]f32 {
	
	rect := get_screen_space_position_rect(anchor, self_anchor, rect, parent_rect, bound_scene.unit_size);
	render.draw_quad_rect(rect, 0, color, loc);
	
	return rect;
}

//position, size and bounds is in unit size coordinates (0-1 ish)
//limit_by_width makes it so the text will not extend over the bounds.
//TODO anchors
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
	
	text_width := render.text_get_bounds(text, text_target_size, font).z;
	
	limiter : f32 = 1;
	if limit_by_width { 
		limiter = math.min(1, rect.z / text_width);
	}
	
	text_size := text_target_size * limiter;
	text_bounds := render.text_get_bounds(text, text_size, font);
	
	//This is a little hacky but it works.
	rect = get_screen_space_position_rect(anchor, auto_cast anchor, [4]f32{0,0,text_bounds.z, text_bounds.w} / unit_size, rect, unit_size);
	
	render.pipeline_end();
	render.text_draw(text, rect.xy - {text_bounds.x, text_bounds.y}, rect.w, bold, italic, color, {color = backdrop_color, offset = backdrop_offset * unit_size}, fonts);
	render.pipeline_begin(bound_scene.gui_pipeline);
	render.set_camera(render.camera_get_pixel_space(bound_scene.window));
}

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

draw_text :: proc {draw_text_param, draw_text_appearance}




////////////////////////////////////////// Very specific //////////////////////////////////////////

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

update_text_base :: proc (e : Base_text_info, is_selected : bool, style : Style, dest : Destination, rect : [4]f32, unit_size : f32, loc := #caller_location) {
	margin : f32 = get_logical_margin(style);
	
	x := mouse_pos().x;
	
	r := get_rect(dest.rect, rect);
	dragable_dest : [4]f32 = {0, 0, r.z - margin, r.w};
	field_rect := get_screen_space_position_rect(.center_center, .center_center, dragable_dest, rect, unit_size); //to convert to pixel space
	
	font : render.Font;
	font_size : f32;
	
	//How many rune fit in rect
	{
		switch a in style.default {
				
			case Textured_appearance:
				
			case Colored_appearance:
				font = render.text_get_font_from_fonts(a.bold, a.italic, a.fonts);
				if a.limit_horizontal_should_resize {
					font_size = a.text_size;
				}
				else {
					font_size = math.min(rect.w, a.text_size * unit_size);
				}
				
			case Patched_appearance:
				
		}
		
		//TODO something is wrong here.
		e.view_start^ = math.clamp(e.view_start^, 0, len(e.runes));
		text := utf8.runes_to_string(e.runes[e.view_start^:]);
		defer delete(text);
		dims := render.text_get_dimensions(text, font_size, font); //In pixel space
		for dims.x > field_rect.z {
			e.view_start^ += 1;
			e.view_start^ = math.clamp(e.view_start^, 0, len(e.runes));
			text := utf8.runes_to_string(e.runes[e.view_start^:]);
			defer delete(text);
			dims = render.text_get_dimensions(text, font_size, font); //In pixel space
		}
	}
	
	if is_selected == true {
		
		if render.is_key_triggered(.backspace) {
			if len(e.runes) != 0 {
				pop(e.runes);
				e.view_start^ -= 1;
				e.view_start^ = math.clamp(e.view_start^, 0, len(e.runes));
			}
		}
		
		if render.is_key_triggered(.v) && render.is_key_down(.control_left) {
			s := render.get_clipboard_string();
			for r in s {
				append(e.runes, r);
			}
		}
		
		for codepoint in render.recive_next_input() {
			append(e.runes, codepoint);
		}
	}
	
	e.cursor_pos^= len(e.runes);
	e.cursor_pos^ = math.clamp(e.cursor_pos^, e.view_start^, len(e.runes));
}