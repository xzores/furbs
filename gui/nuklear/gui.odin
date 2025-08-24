package frubs_gui;

import "base:runtime"

import "core:mem"
import "core:c"
import "core:log"
import "core:math/linalg"
import _c "core:c"
import "core:fmt"
import "core:strings"

import nk "../../nuklear"

import "../../render"

virtual_screen_size : f32 : 8192;

State :: struct {
	
	cam : render.Camera,
	
	gui_framebuffer : render.Frame_buffer,
	
	window : ^render.Window,
	shader : ^render.Shader,
	pipeline : render.Pipeline,
	
	font : render.Font,
	
	odin_allocator : mem.Allocator,
	logger : log.Logger,
	
	nk_font : nk.User_font,
	nk_alloc : nk.Allocator,
	
	ctx : nk.Context,
}

init :: proc (window : ^render.Window, font := render.get_default_fonts().normal, font_size : f32 = 0.02) -> ^State {
	
	s := new(State);
	
	nk_allocate : nk.nk_plugin_alloc : proc "c" (h : nk.Handle, old: rawptr, size: nk.nk_size) -> rawptr {
		user_data : ^State = cast(^State)h.ptr;
		
		context = runtime.default_context();
		context.allocator = user_data.odin_allocator;
		context.logger = user_data.logger;
		
		// If realloc not supported, always allocate new memory
		if old != nil {
			// You must manage freeing 'old' externally, if needed
			mem.free(old, user_data.odin_allocator);
		}
		
		new_ptr, err := mem.alloc(auto_cast size, mem.DEFAULT_ALIGNMENT, user_data.odin_allocator); // your allocator here
		assert(err == nil);
		
		return new_ptr // your allocator here
	}
	
	nk_free : nk.nk_plugin_free : proc "c" (h: nk.Handle, old: rawptr)  {
		user_data : ^State = cast(^State)h.ptr;
		
		context = runtime.default_context();
		
		mem.free(old, user_data.odin_allocator); 
	}
	
	s.nk_alloc = nk.Allocator {
		nk.Handle{ptr = s},
		nk_allocate,
		nk_free,
	}
	
	nk_font_width : nk.Text_width_f : proc "c" (h : nk.Handle, height : f32, str: cstring, len: c.int) -> f32 {
		user_data : ^State = cast(^State)h.ptr;
		
		context = runtime.default_context();
		context.allocator = user_data.odin_allocator;
		context.logger = user_data.logger;
		
		text := strings.clone_from_cstring(str, context.temp_allocator)[:len]
		return render.text_get_dimensions(text, height, user_data.font).x;
	}
	
	gui_shader, e := render.shader_load_from_src("gui_shader.glsl", #load("gui_shader.glsl"), nil);
	assert(e == nil);
	//gui_shader := render.get_default_shader();
	
	s^ = State {
		render.camera_get_pixel_space_flipped(window),
		//render.camera_get_pixel_space(window),
		render.frame_buffer_make_textures({render.Fbo_color_tex_desc{.clamp_to_edge, .nearest, .RGBA8}}, 1, 1, .depth_component16),
		window,
		gui_shader,
		render.pipeline_make(gui_shader, .blend, false),
		font,
		context.allocator,
		context.logger,
		nk.User_font {
			nk.Handle{ptr = s},    	/**!< user provided font handle */
			render.text_get_max_height(font, virtual_screen_size * font_size),          				/**!< max height of the font */
			nk_font_width, 				/**!< font string width in pixel callback */
		},
		nk.Allocator {
			nk.Handle{ptr = s},
			nk_allocate,
			nk_free,
		},
		{},
	};
	
	if !nk.init(&s.ctx, &s.nk_alloc, &s.nk_font) {
		panic("failed to init nuklear");
	}
	else {
		log.infof("Nuklear initialized successfully");
	}
	
	// convert to color table:
	color_table := [nk.Style_colors]nk.Color{
		.COLOR_TEXT                = nk.rgba(175,175,175,255),
		.COLOR_WINDOW              = nk.rgba(45, 45, 45, 255),
		.COLOR_HEADER              = nk.rgba(40, 40, 40, 255),
		.COLOR_BORDER              = nk.rgba(65, 65, 65, 255),
		.COLOR_BUTTON              = nk.rgba(50, 50, 50, 255),
		.COLOR_BUTTON_HOVER        = nk.rgba(40, 40, 40, 255),
		.COLOR_BUTTON_ACTIVE       = nk.rgba(35, 35, 35, 255),
		.COLOR_TOGGLE              = nk.rgba(100,100,100,255),
		.COLOR_TOGGLE_HOVER        = nk.rgba(120,120,120,255),
		.COLOR_TOGGLE_CURSOR       = nk.rgba(45, 45, 45, 255),
		.COLOR_SELECT              = nk.rgba(45, 45, 45, 255),
		.COLOR_SELECT_ACTIVE       = nk.rgba(35, 35, 35,255),
		.COLOR_SLIDER              = nk.rgba(38, 38, 38, 255),
		.COLOR_SLIDER_CURSOR       = nk.rgba(100,100,100,255),
		.COLOR_SLIDER_CURSOR_HOVER = nk.rgba(120,120,120,255),
		.COLOR_SLIDER_CURSOR_ACTIVE= nk.rgba(150,150,150,255),
		.COLOR_PROPERTY            = nk.rgba(38, 38, 38, 255),
		.COLOR_EDIT                = nk.rgba(38, 38, 38, 255),
		.COLOR_EDIT_CURSOR         = nk.rgba(175,175,175,255),
		.COLOR_COMBO               = nk.rgba(45, 45, 45, 255),
		.COLOR_CHART               = nk.rgba(120,120,120,255),
		.COLOR_CHART_COLOR         = nk.rgba(45, 45, 45, 255),
		.COLOR_CHART_COLOR_HIGHLIGHT = nk.rgba(255, 0,  0, 255),
		.COLOR_SCROLLBAR           = nk.rgba(40, 40, 40, 255),
		.COLOR_SCROLLBAR_CURSOR    = nk.rgba(100,100,100,255),
		.COLOR_SCROLLBAR_CURSOR_HOVER = nk.rgba(120,120,120,255),
		.COLOR_SCROLLBAR_CURSOR_ACTIVE = nk.rgba(150,150,150,255),
		.COLOR_TAB_HEADER          = nk.rgba(40, 40, 40,255),
		.COLOR_KNOB                = nk.rgba(38, 38, 38, 255),
		.COLOR_KNOB_CURSOR         = nk.rgba(100,100,100,255),
		.COLOR_KNOB_CURSOR_HOVER   = nk.rgba(120,120,120,255),
		.COLOR_KNOB_CURSOR_ACTIVE  = nk.rgba(150,150,150,255),
	};
	
	style_from_table(&s.ctx, color_table);
	
	return s;
}

destroy :: proc (state : ^State) {
	
	render.frame_buffer_destroy(state.gui_framebuffer);
	render.pipeline_destroy(state.pipeline);
	render.shader_destroy(state.shader);
	
	nk.free(&state.ctx);
	free(state);
}

begin :: proc (state : ^State, loc := #caller_location) {
	height : f32 = auto_cast state.window.height;
	ratio := height / virtual_screen_size;
	
	nk.input_begin(&state.ctx);
	{
		mp := render.mouse_pos(state.window);
		mp.y = height - mp.y;
		mp /= ratio;
		
		fmt.printf("mp : %v\n", mp);
		
		nk.input_motion(&state.ctx, auto_cast mp.x, auto_cast mp.y);
		
		for e in render.key_events() {
			k, ok := to_nk_key(e.key);
			if ok && e.action == .press || e.action == .repeat {
				nk.input_key(&state.ctx, k, true);
			}
			else {
				nk.input_key(&state.ctx, k, false);
			}
		}
		
		for e in render.mouse_events() {
			b, ok := to_nk_button(e.button);
			if ok && (e.action == .press || e.action == .repeat) {
				nk.input_button(&state.ctx, b, auto_cast mp.x, auto_cast mp.y, true);
			}
			else {
				nk.input_button(&state.ctx, b, auto_cast mp.x, auto_cast mp.y, false);
			}
		}
		
		ms := render.scroll_delta();
		nk.input_scroll(&state.ctx, nk.Vec2{auto_cast ms.x, auto_cast ms.y});
		
		//nk.input_char(&state.ctx, char);
		//nk.input_glyph(&state.ctx, const nk_glyph);
		//nk.input_unicode(&state.ctx, nk_rune);
	}
	
	nk.input_end(&state.ctx); //SO here
}

//TODO this is kinda nasty we render to a texture and then flip it, this requires swapping pipeline multiple times
end :: proc (state : ^State) {
	height : f32 = auto_cast state.window.height;
	ratio := height / virtual_screen_size;
	aspect :=  cast(f32)state.window.width / height;
	
	if state.gui_framebuffer.height != state.window.height || state.gui_framebuffer.width != state.window.width {
		//destroy the old and remake with new size
		render.frame_buffer_resize(&state.gui_framebuffer, {state.window.width, state.window.height});
	}
	
	{
		stored := render.store_target();
		defer render.restore_target(stored);	
		
		render.target_begin(&state.gui_framebuffer);
		defer render.target_end();
		
		fmt.printf("w, h : %v %v", virtual_screen_size * aspect, virtual_screen_size);
		state.cam = render.camera_get_pixel_space(virtual_screen_size * aspect, virtual_screen_size);
		render.pipeline_begin(state.pipeline, state.cam);
		defer render.pipeline_end();
		
		//TODO draw!
		for c := nk._begin(&state.ctx); c != nil; (c) = nk._next(&state.ctx, c) {
			
			switch c.typ {
				case .NK_COMMAND_ARC:{
					cmd := cast(^nk.nk_command_arc)c;
					fmt.printf("nk_command_arc : %v\n", cmd);
				}
				case .NK_COMMAND_ARC_FILLED:{
					cmd := cast(^nk.nk_command_arc_filled)c;
					fmt.printf("nk_command_arc_filled : %v\n", cmd);
				}
				case .NK_COMMAND_CIRCLE:{
					cmd := cast(^nk.nk_command_circle)c;
					fmt.printf("nk_command_circle : %v\n", cmd);
				}
				case .NK_COMMAND_CIRCLE_FILLED:{
					cmd := cast(^nk.nk_command_circle_filled)c;
					fmt.printf("nk_command_circle_filled : %v\n", cmd);
				}
				case .NK_COMMAND_CURVE:{
					cmd := cast(^nk.nk_command_curve)c;
					fmt.printf("nk_command_curve : %v\n", cmd);
				}
				case .NK_COMMAND_LINE:{
					cmd := cast(^nk.nk_command_line)c;
					fmt.printf("nk_command_line : %v\n", cmd);
				}
				case .NK_COMMAND_POLYGON:{
					cmd := cast(^nk.nk_command_polygon)c;
					fmt.printf("nk_command_polygon : %v\n", cmd);
				}
				case .NK_COMMAND_POLYGON_FILLED:{
					cmd := cast(^nk.nk_command_polygon_filled)c;
					fmt.printf("nk_command_polygon_filled : %v\n", cmd);
				}
				case .NK_COMMAND_RECT:{
					cmd := cast(^nk.nk_command_rect)c;
					
					render.set_uniform(state.shader, render.Uniform_location.gui_fill, false);
					render.set_uniform(state.shader, render.Uniform_location.gui_line_thickness, cast(f32)cmd.line_thickness);
					render.set_uniform(state.shader, render.Uniform_location.gui_roundness, cast(f32)cmd.rounding);
					
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					r := [4]f32{cast(f32)cmd.x, cast(f32)cmd.y, cast(f32)cmd.w, cast(f32)cmd.h}
					render.draw_quad_rect(r, 0, to_colorf32(cmd.color));
				}
				case .NK_COMMAND_RECT_FILLED:{
					cmd := cast(^nk.nk_command_rect_filled)c;
					
					render.set_uniform(state.shader, render.Uniform_location.gui_fill, true);
					render.set_uniform(state.shader, render.Uniform_location.gui_line_thickness, cast(f32)0 );
					render.set_uniform(state.shader, render.Uniform_location.gui_roundness, cast(f32)cmd.rounding);
					
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					r := [4]f32{cast(f32)cmd.x, cast(f32)cmd.y, cast(f32)cmd.w, cast(f32)cmd.h};
					render.draw_quad_rect(r, 0, to_colorf32(cmd.color));
				}
				case .NK_COMMAND_TEXT:{
					cmd := cast(^nk.nk_command_text)c;
					
					s : ^_c.char = cast(^_c.char)&cmd.string[0];
					as_cstring := cstring(s);
					
					r := [4]f32{cast(f32)cmd.x, cast(f32)cmd.y, cast(f32)cmd.w, cast(f32)cmd.h} * ratio;
					render.text_draw(fmt.tprintf("%v", as_cstring), {r.x, r.y}, cast(f32)cmd.height * ratio, false, false, to_colorf32(cmd.foreground), flip_y = true);
				}
				case .NK_COMMAND_TRIANGLE:{
					cmd := cast(^nk.nk_command_triangle)c;
					fmt.printf("nk_command_triangle : %v\n", cmd);
				}
				case .NK_COMMAND_TRIANGLE_FILLED:{
					cmd := cast(^nk.nk_command_triangle_filled)c;
					
					a := [3]f32{cast(f32)cmd.a.x, cast(f32)cmd.a.y, 0};
					b := [3]f32{cast(f32)cmd.b.x, cast(f32)cmd.b.y, 0};
					c := [3]f32{cast(f32)cmd.c.x, cast(f32)cmd.c.y, 0};
					
					render.set_uniform(state.shader, render.Uniform_location.gui_fill, true);
					render.set_uniform(state.shader, render.Uniform_location.gui_line_thickness, cast(f32)0);
					render.set_uniform(state.shader, render.Uniform_location.gui_roundness, cast(f32)0);
					
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					render.draw_triangle(a, b, c, to_colorf32(cmd.color));
				}
				case .NK_COMMAND_POLYLINE:{
					cmd := cast(^nk.nk_command_polyline)c;
					fmt.printf("nk_command_polyline : %v\n", cmd);
				}
				case .NK_COMMAND_SCISSOR:{
					cmd := cast(^nk.nk_command_scissor)c;				
					//render.set_scissor_test(cmd.x, cmd.y, cmd.w, cmd.h);
				}
				case .NK_COMMAND_RECT_MULTI_COLOR:{
					cmd := cast(^nk.nk_command_rect_multi_color)c;
					fmt.printf("nk_command_rect_multi_color : %v\n", cmd);
				}		
				case .NK_COMMAND_IMAGE:{
					cmd := cast(^nk.nk_command_image)c;
					fmt.printf("nk_command_image : %v\n", cmd);
				}
				case .NK_COMMAND_NOP:{
					fmt.printf("No operation command!\n");
				}
				case .NK_COMMAND_CUSTOM	:{
					cmd := cast(^nk.nk_command_custom)c;
					fmt.printf("nk_command_custom : %v\n", cmd);
				}
			}
		}
		
		render.draw_quad_rect({0, 0, 100, 100}, 0, {1,0,0,1});
		
		render.disable_scissor_test();	
		nk.clear(&state.ctx);
	}
	
	tex := render.frame_buffer_color_attach_as_texture(&state.gui_framebuffer, 0);
	
	//draw the texture over the screen
	
	stored := render.store_pipeline();
	defer render.restore_pipeline(stored);
	
	q_pipe := render.pipeline_make(render.get_default_shader(), .blend, false, false, .fill, .no_cull);
	defer render.pipeline_destroy(q_pipe);
	
	render.pipeline_begin(q_pipe, render.Camera2D{
		position		= {0,0},				// Camera position
		target_relative	= {0,0},				// 
		rotation		= 0,				// in degrees
		zoom 			= 1,				//
		
		near 			= -1,
		far 			= 1,
	});
	defer render.pipeline_end();
	
	render.set_texture(.texture_diffuse, tex);
	render.draw_quad_rect({-1,1,2,-2});
}

/////////////////////////////////////// GUI functions ///////////////////////////////////////

Panel_flags :: nk.Panel_flags;

window_begin :: proc (state : ^State, name : string, rect : [4]f32, flags : Panel_flags, title := "") -> bool {
	rect := rect * virtual_screen_size;
	
	if title != "" {
		return nk.begin_titled(&state.ctx, fmt.ctprintf(name), fmt.ctprintf(title), to_rect(rect), flags);
	}
	else {
		return nk.begin(&state.ctx, fmt.ctprintf(name), to_rect(rect), flags);
	}
}

window_end :: proc (state : ^State) {
	nk.end(&state.ctx);
}

layout_row_dynamic :: proc (state : ^State, h : f32, #any_int cols : c.int) {
	
	nk.layout_row_dynamic(&state.ctx, h * virtual_screen_size, cols);
}

Text_alignment :: nk.Text_alignment;
label :: proc (state : ^State, text : string, align : Text_alignment) {
	
	nk.label(&state.ctx, fmt.ctprintf(text), align);
}

checkbox_label :: proc (state : ^State, text : string, val : ^bool) -> bool {
	
	return nk.checkbox_label(&state.ctx, fmt.ctprintf(text), val);
}

/////////////////////////////////////// translations ///////////////////////////////////////

Color :: nk.Color;
ColorF :: nk.ColorF;
Rect :: nk.Rect;
Recti :: nk.Recti;
Vec2 :: nk.Vec2;
Vec2i :: nk.Vec2i;

to_rect :: proc (r : [4]f32) -> nk.Rect {
	return {r.x, r.y, r.z, r.w};
}

to_colorf32 :: proc (color : nk.Color) -> [4]f32 {
	return linalg.array_cast(color, f32) / 255;
}

to_nk_key :: proc (key_code : render.Key_code) -> (k : nk.nk_keys, ok : bool) {
	
	#partial switch key_code {
		case .shift_left, .shift_right:
			return .NK_KEY_SHIFT, true;
		case .control_left, .control_right:
			return .NK_KEY_CTRL, true
		case .enter:
			return .NK_KEY_ENTER, true
		case .tab:
			return .NK_KEY_TAB, true
		case .backspace:
			return .NK_KEY_BACKSPACE, true
		//KEY_COPY,
		//KEY_CUT,
		//KEY_PASTE,
		case .up:
			return .NK_KEY_UP, true
		case .down:
			return .NK_KEY_DOWN, true
		case .left:	
			return .NK_KEY_LEFT, true
		case .right:	
			return .NK_KEY_RIGHT, true
		/*
		case .insert:
			return .KEY_TEXT_INSERT_MODE;
		case .insert:
			return .KEY_TEXT_REPLACE_MODE;
		KEY_TEXT_RESET_MODE,
		KEY_TEXT_LINE_START,
		KEY_TEXT_LINE_END,
		KEY_TEXT_START,
		KEY_TEXT_END,
		KEY_TEXT_UNDO,
		KEY_TEXT_REDO,
		KEY_TEXT_SELECT_ALL,
		KEY_TEXT_WORD_LEFT,
		KEY_TEXT_WORD_RIGHT,
		KEY_SCROLL_START,
		KEY_SCROLL_END,
		KEY_SCROLL_DOWN,
		KEY_SCROLL_UP,
		*/
		case:{
			return .NK_KEY_NONE, false
		}
	}
	
	return .NK_KEY_NONE, false
}

to_nk_button :: proc (mouse_code : render.Mouse_code) -> (b : nk.nk_buttons, ok : bool) {
	
	#partial switch mouse_code {
		case .left:
			return .NK_BUTTON_LEFT, true;
		case .middel:
			return .NK_BUTTON_MIDDLE, true;
		case .right:
			return .NK_BUTTON_RIGHT, true;
		case:
			return {}, false
	}
	
	return {}, false
}

//translate this to odin
style_from_table :: proc(ctx: ^nk.Context, table: [nk.Style_colors]nk.Color) {
	style: ^nk.Style = &ctx.style;
	// table is expected to be a pointer to an array of nk.Color

	// Default text
	text := &style.text;
	text.color = table[.COLOR_TEXT];
	text.padding = nk.vec2(0, 0);
	text.color_factor = 1.0;
	text.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	
	// Default button
	button := &style.button;
	button.normal = nk.style_item_color(table[.COLOR_BUTTON]);
	button.hover = nk.style_item_color(table[.COLOR_BUTTON_HOVER]);
	button.active = nk.style_item_color(table[.COLOR_BUTTON_ACTIVE]);
	button.border_color = table[.COLOR_BORDER];
	button.text_background = table[.COLOR_BUTTON];
	button.text_normal = table[.COLOR_TEXT];
	button.text_hover = table[.COLOR_TEXT];
	button.text_active = table[.COLOR_TEXT];
	button.padding = nk.vec2(2.0, 2.0);
	button.image_padding = nk.vec2(0.0, 0.0);
	button.touch_padding = nk.vec2(0.0, 0.0);
	button.userdata = nk.handle_ptr(nil);
	button.text_alignment = .TEXT_CENTERED;
	button.border = 1.0;
	button.rounding = 4.0;
	button.color_factor_text = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin = nil;
	button.draw_end = nil;

	// Contextual button
	button = &style.contextual_button;
	button.normal = nk.style_item_color(table[.COLOR_WINDOW]);
	button.hover = nk.style_item_color(table[.COLOR_BUTTON_HOVER]);
	button.active = nk.style_item_color(table[.COLOR_BUTTON_ACTIVE]);
	button.border_color = table[.COLOR_WINDOW];
	button.text_background = table[.COLOR_WINDOW];
	button.text_normal = table[.COLOR_TEXT];
	button.text_hover = table[.COLOR_TEXT];
	button.text_active = table[.COLOR_TEXT];
	button.padding = nk.vec2(2.0, 2.0);
	button.touch_padding = nk.vec2(0.0, 0.0);
	button.userdata = nk.handle_ptr(nil);
	button.text_alignment = .TEXT_CENTERED;
	button.border = 0.0;
	button.rounding = 0.0;
	button.color_factor_text = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin = nil;
	button.draw_end = nil;

	// Menu button
	button = &style.menu_button;
	button.normal = nk.style_item_color(table[.COLOR_WINDOW]);
	button.hover = nk.style_item_color(table[.COLOR_WINDOW]);
	button.active = nk.style_item_color(table[.COLOR_WINDOW]);
	button.border_color = table[.COLOR_WINDOW];
	button.text_background = table[.COLOR_WINDOW];
	button.text_normal = table[.COLOR_TEXT];
	button.text_hover = table[.COLOR_TEXT];
	button.text_active = table[.COLOR_TEXT];
	button.padding = nk.vec2(2.0, 2.0);
	button.touch_padding = nk.vec2(0.0, 0.0);
	button.userdata = nk.handle_ptr(nil);
	button.text_alignment = .TEXT_CENTERED;
	button.border = 0.0;
	button.rounding = 1.0;
	button.color_factor_text = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin = nil;
	button.draw_end = nil;

	// Checkbox toggle
	toggle := &style.checkbox;
	toggle.normal = nk.style_item_color(table[.COLOR_TOGGLE]);
	toggle.hover = nk.style_item_color(table[.COLOR_TOGGLE_HOVER]);
	toggle.active = nk.style_item_color(table[.COLOR_TOGGLE_HOVER]);
	toggle.cursor_normal = nk.style_item_color(table[.COLOR_TOGGLE_CURSOR]);
	toggle.cursor_hover = nk.style_item_color(table[.COLOR_TOGGLE_CURSOR]);
	toggle.userdata = nk.handle_ptr(nil);
	toggle.text_background = table[.COLOR_WINDOW];
	toggle.text_normal = table[.COLOR_TEXT];
	toggle.text_hover = table[.COLOR_TEXT];
	toggle.text_active = table[.COLOR_TEXT];
	toggle.padding = nk.vec2(2.0, 2.0);
	toggle.touch_padding = nk.vec2(0.0, 0.0);
	toggle.border_color = nk.rgba(0, 0, 0, 0);
	toggle.border = 0.0;
	toggle.spacing = 4;
	toggle.color_factor = 1.0;
	toggle.disabled_factor = nk.WIDGET_DISABLED_FACTOR;

	// Option toggle
	toggle = &style.option;
	toggle.normal = nk.style_item_color(table[.COLOR_TOGGLE]);
	toggle.hover = nk.style_item_color(table[.COLOR_TOGGLE_HOVER]);
	toggle.active = nk.style_item_color(table[.COLOR_TOGGLE_HOVER]);
	toggle.cursor_normal = nk.style_item_color(table[.COLOR_TOGGLE_CURSOR]);
	toggle.cursor_hover = nk.style_item_color(table[.COLOR_TOGGLE_CURSOR]);
	toggle.userdata = nk.handle_ptr(nil);
	toggle.text_background = table[.COLOR_WINDOW];
	toggle.text_normal = table[.COLOR_TEXT];
	toggle.text_hover = table[.COLOR_TEXT];
	toggle.text_active = table[.COLOR_TEXT];
	toggle.padding = nk.vec2(3.0, 3.0);
	toggle.touch_padding = nk.vec2(0.0, 0.0);
	toggle.border_color = nk.rgba(0, 0, 0, 0);
	toggle.border = 0.0;
	toggle.spacing = 4;
	toggle.color_factor = 1.0;
	toggle.disabled_factor = nk.WIDGET_DISABLED_FACTOR;

	// Selectable
	select := &style.selectable;
	select.normal = nk.style_item_color(table[.COLOR_SELECT]);
	select.hover = nk.style_item_color(table[.COLOR_SELECT]);
	select.pressed = nk.style_item_color(table[.COLOR_SELECT]);
	select.normal_active = nk.style_item_color(table[.COLOR_SELECT_ACTIVE]);
	select.hover_active = nk.style_item_color(table[.COLOR_SELECT_ACTIVE]);
	select.pressed_active = nk.style_item_color(table[.COLOR_SELECT_ACTIVE]);
	select.text_normal = table[.COLOR_TEXT];
	select.text_hover = table[.COLOR_TEXT];
	select.text_pressed = table[.COLOR_TEXT];
	select.text_normal_active = table[.COLOR_TEXT];
	select.text_hover_active = table[.COLOR_TEXT];
	select.text_pressed_active = table[.COLOR_TEXT];
	select.padding = nk.vec2(2.0, 2.0);
	select.image_padding = nk.vec2(2.0, 2.0);
	select.touch_padding = nk.vec2(0.0, 0.0);
	select.userdata = nk.handle_ptr(nil);
	select.rounding = 0.0;
	select.color_factor = 1.0;
	select.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	select.draw_begin = nil;
	select.draw_end = nil;

	// Slider
	slider := &style.slider;
	slider.normal = nk.style_item_hide();
	slider.hover = nk.style_item_hide();
	slider.active = nk.style_item_hide();
	slider.bar_normal = table[.COLOR_SLIDER];
	slider.bar_hover = table[.COLOR_SLIDER];
	slider.bar_active = table[.COLOR_SLIDER];
	slider.bar_filled = table[.COLOR_SLIDER_CURSOR];
	slider.cursor_normal = nk.style_item_color(table[.COLOR_SLIDER_CURSOR]);
	slider.cursor_hover = nk.style_item_color(table[.COLOR_SLIDER_CURSOR_HOVER]);
	slider.cursor_active = nk.style_item_color(table[.COLOR_SLIDER_CURSOR_ACTIVE]);
	slider.inc_symbol = .SYMBOL_TRIANGLE_RIGHT;
	slider.dec_symbol = .SYMBOL_TRIANGLE_LEFT;
	slider.cursor_size = nk.vec2(16, 16);
	slider.padding = nk.vec2(2, 2);
	slider.spacing = nk.vec2(2, 2);
	slider.userdata = nk.handle_ptr(nil);
	slider.show_buttons = false;
	slider.bar_height = 8;
	slider.rounding = 0;
	slider.color_factor = 1.0;
	slider.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	slider.draw_begin = nil;
	slider.draw_end = nil;

	// Slider buttons
	button = &style.slider.inc_button;
	button.normal = nk.style_item_color(nk.rgb(40, 40, 40));
	button.hover = nk.style_item_color(nk.rgb(42, 42, 42));
	button.active = nk.style_item_color(nk.rgb(44, 44, 44));
	button.border_color = nk.rgb(65, 65, 65);
	button.text_background = nk.rgb(40, 40, 40);
	button.text_normal = nk.rgb(175, 175, 175);
	button.text_hover = nk.rgb(175, 175, 175);
	button.text_active = nk.rgb(175, 175, 175);
	button.padding = nk.vec2(8.0, 8.0);
	button.touch_padding = nk.vec2(0.0, 0.0);
	button.userdata = nk.handle_ptr(nil);
	button.text_alignment = .TEXT_CENTERED;
	button.border = 1.0;
	button.rounding = 0.0;
	button.color_factor_text = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin = nil;
	button.draw_end = nil;
	style.slider.dec_button = style.slider.inc_button;

	// knob
	knob := &style.knob;
	knob.normal        = nk.style_item_hide();
	knob.hover         = nk.style_item_hide();
	knob.active        = nk.style_item_hide();
	knob.knob_normal   = table[.COLOR_KNOB];
	knob.knob_hover    = table[.COLOR_KNOB];
	knob.knob_active   = table[.COLOR_KNOB];
	knob.cursor_normal = table[.COLOR_KNOB_CURSOR];
	knob.cursor_hover  = table[.COLOR_KNOB_CURSOR_HOVER];
	knob.cursor_active = table[.COLOR_KNOB_CURSOR_ACTIVE];

	knob.knob_border_color = table[.COLOR_BORDER];
	knob.knob_border       = 1.0;

	knob.padding         = nk.vec2(2,2);
	knob.spacing         = nk.vec2(2,2);
	knob.cursor_width    = 2;
	knob.color_factor    = 1.0;
	knob.disabled_factor = nk.WIDGET_DISABLED_FACTOR;

	knob.userdata        = nk.handle_ptr(nil);
	knob.draw_begin      = nil;
	knob.draw_end        = nil;

	// progressbar
	prog := &style.progress;
	prog.normal            = nk.style_item_color(table[.COLOR_SLIDER]);
	prog.hover             = nk.style_item_color(table[.COLOR_SLIDER]);
	prog.active            = nk.style_item_color(table[.COLOR_SLIDER]);
	prog.cursor_normal     = nk.style_item_color(table[.COLOR_SLIDER_CURSOR]);
	prog.cursor_hover      = nk.style_item_color(table[.COLOR_SLIDER_CURSOR_HOVER]);
	prog.cursor_active     = nk.style_item_color(table[.COLOR_SLIDER_CURSOR_ACTIVE]);
	prog.border_color      = nk.rgba(0,0,0,0);
	prog.cursor_border_color = nk.rgba(0,0,0,0);
	prog.userdata          = nk.handle_ptr(nil);
	prog.padding           = nk.vec2(4,4);
	prog.rounding          = 0;
	prog.border            = 0;
	prog.cursor_rounding   = 0;
	prog.cursor_border     = 0;
	prog.color_factor      = 1.0;
	prog.disabled_factor   = nk.WIDGET_DISABLED_FACTOR;
	prog.draw_begin        = nil;
	prog.draw_end          = nil;

	// scrollbars
	scroll := &style.scrollh;
	scroll.normal          = nk.style_item_color(table[.COLOR_SCROLLBAR]);
	scroll.hover           = nk.style_item_color(table[.COLOR_SCROLLBAR]);
	scroll.active          = nk.style_item_color(table[.COLOR_SCROLLBAR]);
	scroll.cursor_normal   = nk.style_item_color(table[.COLOR_SCROLLBAR_CURSOR]);
	scroll.cursor_hover    = nk.style_item_color(table[.COLOR_SCROLLBAR_CURSOR_HOVER]);
	scroll.cursor_active   = nk.style_item_color(table[.COLOR_SCROLLBAR_CURSOR_ACTIVE]);
	scroll.dec_symbol      = .SYMBOL_CIRCLE_SOLID;
	scroll.inc_symbol      = .SYMBOL_CIRCLE_SOLID;
	scroll.userdata        = nk.handle_ptr(nil);
	scroll.border_color    = table[.COLOR_SCROLLBAR];
	scroll.cursor_border_color = table[.COLOR_SCROLLBAR];
	scroll.padding         = nk.vec2(0,0);
	scroll.show_buttons    = false;
	scroll.border          = 0;
	scroll.rounding        = 0;
	scroll.border_cursor   = 0;
	scroll.rounding_cursor = 0;
	scroll.color_factor    = 1.0;
	scroll.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	scroll.draw_begin      = nil;
	scroll.draw_end        = nil;
	style.scrollv = style.scrollh;

	// scrollbars buttons
	button = &style.scrollh.inc_button;
	button.normal          = nk.style_item_color(nk.rgb(40,40,40));
	button.hover           = nk.style_item_color(nk.rgb(42,42,42));
	button.active          = nk.style_item_color(nk.rgb(44,44,44));
	button.border_color    = nk.rgb(65,65,65);
	button.text_background = nk.rgb(40,40,40);
	button.text_normal     = nk.rgb(175,175,175);
	button.text_hover      = nk.rgb(175,175,175);
	button.text_active     = nk.rgb(175,175,175);
	button.padding         = nk.vec2(4.0,4.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 1.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;
	style.scrollh.dec_button = style.scrollh.inc_button;
	style.scrollv.inc_button = style.scrollh.inc_button;
	style.scrollv.dec_button = style.scrollh.inc_button;

	// edit
	edit := &style.edit;
	edit.normal            = nk.style_item_color(table[.COLOR_EDIT]);
	edit.hover             = nk.style_item_color(table[.COLOR_EDIT]);
	edit.active            = nk.style_item_color(table[.COLOR_EDIT]);
	edit.cursor_normal     = table[.COLOR_TEXT];
	edit.cursor_hover      = table[.COLOR_TEXT];
	edit.cursor_text_normal= table[.COLOR_EDIT];
	edit.cursor_text_hover = table[.COLOR_EDIT];
	edit.border_color      = table[.COLOR_BORDER];
	edit.text_normal       = table[.COLOR_TEXT];
	edit.text_hover        = table[.COLOR_TEXT];
	edit.text_active       = table[.COLOR_TEXT];
	edit.selected_normal   = table[.COLOR_TEXT];
	edit.selected_hover    = table[.COLOR_TEXT];
	edit.selected_text_normal  = table[.COLOR_EDIT];
	edit.selected_text_hover   = table[.COLOR_EDIT];
	edit.scrollbar_size    = nk.vec2(10,10);
	edit.scrollbar         = style.scrollv;
	edit.padding           = nk.vec2(4,4);
	edit.row_padding       = 2;
	edit.cursor_size       = 4;
	edit.border            = 1;
	edit.rounding          = 0;
	edit.color_factor      = 1.0;
	edit.disabled_factor   = nk.WIDGET_DISABLED_FACTOR;

	// property
	property := &style.property;
	property.normal        = nk.style_item_color(table[.COLOR_PROPERTY]);
	property.hover         = nk.style_item_color(table[.COLOR_PROPERTY]);
	property.active        = nk.style_item_color(table[.COLOR_PROPERTY]);
	property.border_color  = table[.COLOR_BORDER];
	property.label_normal  = table[.COLOR_TEXT];
	property.label_hover   = table[.COLOR_TEXT];
	property.label_active  = table[.COLOR_TEXT];
	property.sym_left      = .SYMBOL_TRIANGLE_LEFT;
	property.sym_right     = .SYMBOL_TRIANGLE_RIGHT;
	property.userdata      = nk.handle_ptr(nil);
	property.padding       = nk.vec2(4,4);
	property.border        = 1;
	property.rounding      = 10;
	property.draw_begin    = nil;
	property.draw_end      = nil;
	property.color_factor  = 1.0;
	property.disabled_factor = nk.WIDGET_DISABLED_FACTOR;

	// property buttons
	button = &style.property.dec_button;
	button.normal          = nk.style_item_color(table[.COLOR_PROPERTY]);
	button.hover           = nk.style_item_color(table[.COLOR_PROPERTY]);
	button.active          = nk.style_item_color(table[.COLOR_PROPERTY]);
	button.border_color    = nk.rgba(0,0,0,0);
	button.text_background = table[.COLOR_PROPERTY];
	button.text_normal     = table[.COLOR_TEXT];
	button.text_hover      = table[.COLOR_TEXT];
	button.text_active     = table[.COLOR_TEXT];
	button.padding         = nk.vec2(0.0,0.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 0.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;
	style.property.inc_button = style.property.dec_button;

	// property edit
	edit = &style.property.edit;
	edit.normal            = nk.style_item_color(table[.COLOR_PROPERTY]);
	edit.hover             = nk.style_item_color(table[.COLOR_PROPERTY]);
	edit.active            = nk.style_item_color(table[.COLOR_PROPERTY]);
	edit.border_color      = nk.rgba(0,0,0,0);
	edit.cursor_normal     = table[.COLOR_TEXT];
	edit.cursor_hover      = table[.COLOR_TEXT];
	edit.cursor_text_normal= table[.COLOR_EDIT];
	edit.cursor_text_hover = table[.COLOR_EDIT];
	edit.text_normal       = table[.COLOR_TEXT];
	edit.text_hover        = table[.COLOR_TEXT];
	edit.text_active       = table[.COLOR_TEXT];
	edit.selected_normal   = table[.COLOR_TEXT];
	edit.selected_hover    = table[.COLOR_TEXT];
	edit.selected_text_normal  = table[.COLOR_EDIT];
	edit.selected_text_hover   = table[.COLOR_EDIT];
	edit.padding           = nk.vec2(0,0);
	edit.cursor_size       = 8;
	edit.border            = 0;
	edit.rounding          = 0;
	edit.color_factor      = 1.0;
	edit.disabled_factor   = nk.WIDGET_DISABLED_FACTOR;

	// chart
	chart := &style.chart;
	chart.background       = nk.style_item_color(table[.COLOR_CHART]);
	chart.border_color     = table[.COLOR_BORDER];
	chart.selected_color   = table[.COLOR_CHART_COLOR_HIGHLIGHT];
	chart.color            = table[.COLOR_CHART_COLOR];
	chart.padding          = nk.vec2(4,4);
	chart.border           = 0;
	chart.rounding         = 0;
	chart.color_factor     = 1.0;
	chart.disabled_factor  = nk.WIDGET_DISABLED_FACTOR;
	chart.show_markers     = true;

	// combo
	combo := &style.combo;
	combo.normal           = nk.style_item_color(table[.COLOR_COMBO]);
	combo.hover            = nk.style_item_color(table[.COLOR_COMBO]);
	combo.active           = nk.style_item_color(table[.COLOR_COMBO]);
	combo.border_color     = table[.COLOR_BORDER];
	combo.label_normal     = table[.COLOR_TEXT];
	combo.label_hover      = table[.COLOR_TEXT];
	combo.label_active     = table[.COLOR_TEXT];
	combo.sym_normal       = .SYMBOL_TRIANGLE_DOWN;
	combo.sym_hover        = .SYMBOL_TRIANGLE_DOWN;
	combo.sym_active       = .SYMBOL_TRIANGLE_DOWN;
	combo.content_padding  = nk.vec2(4,4);
	combo.button_padding   = nk.vec2(0,4);
	combo.spacing          = nk.vec2(4,0);
	combo.border           = 1;
	combo.rounding         = 0;
	combo.color_factor     = 1.0;
	combo.disabled_factor  = nk.WIDGET_DISABLED_FACTOR;

	// combo button
	button = &style.combo.button;
	button.normal          = nk.style_item_color(table[.COLOR_COMBO]);
	button.hover           = nk.style_item_color(table[.COLOR_COMBO]);
	button.active          = nk.style_item_color(table[.COLOR_COMBO]);
	button.border_color    = nk.rgba(0,0,0,0);
	button.text_background = table[.COLOR_COMBO];
	button.text_normal     = table[.COLOR_TEXT];
	button.text_hover      = table[.COLOR_TEXT];
	button.text_active     = table[.COLOR_TEXT];
	button.padding         = nk.vec2(2.0,2.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 0.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;

	// tab
	tab := &style.tab;
	tab.background         = nk.style_item_color(table[.COLOR_TAB_HEADER]);
	tab.border_color       = table[.COLOR_BORDER];
	tab.text               = table[.COLOR_TEXT];
	tab.sym_minimize       = .SYMBOL_TRIANGLE_RIGHT;
	tab.sym_maximize       = .SYMBOL_TRIANGLE_DOWN;
	tab.padding            = nk.vec2(4,4);
	tab.spacing            = nk.vec2(4,4);
	tab.indent             = 10.0;
	tab.border             = 1;
	tab.rounding           = 0;
	tab.color_factor       = 1.0;
	tab.disabled_factor    = nk.WIDGET_DISABLED_FACTOR;

	// tab button
	button = &style.tab.tab_minimize_button;
	button.normal          = nk.style_item_color(table[.COLOR_TAB_HEADER]);
	button.hover           = nk.style_item_color(table[.COLOR_TAB_HEADER]);
	button.active          = nk.style_item_color(table[.COLOR_TAB_HEADER]);
	button.border_color    = nk.rgba(0,0,0,0);
	button.text_background = table[.COLOR_TAB_HEADER];
	button.text_normal     = table[.COLOR_TEXT];
	button.text_hover      = table[.COLOR_TEXT];
	button.text_active     = table[.COLOR_TEXT];
	button.padding         = nk.vec2(2.0,2.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 0.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;
	style.tab.tab_maximize_button = style.tab.tab_minimize_button;

	// node button
	button = &style.tab.node_minimize_button;
	button.normal          = nk.style_item_color(table[.COLOR_WINDOW]);
	button.hover           = nk.style_item_color(table[.COLOR_WINDOW]);
	button.active          = nk.style_item_color(table[.COLOR_WINDOW]);
	button.border_color    = nk.rgba(0,0,0,0);
	button.text_background = table[.COLOR_TAB_HEADER];
	button.text_normal     = table[.COLOR_TEXT];
	button.text_hover      = table[.COLOR_TEXT];
	button.text_active     = table[.COLOR_TEXT];
	button.padding         = nk.vec2(2.0,2.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 0.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;
	style.tab.node_maximize_button = style.tab.node_minimize_button;

	// window header
	win := &style.window;
	win.header.align = .HEADER_RIGHT;
	win.header.close_symbol = .SYMBOL_X;
	win.header.minimize_symbol = .SYMBOL_MINUS;
	win.header.maximize_symbol = .SYMBOL_PLUS;
	win.header.normal = nk.style_item_color(table[.COLOR_HEADER]);
	win.header.hover = nk.style_item_color(table[.COLOR_HEADER]);
	win.header.active = nk.style_item_color(table[.COLOR_HEADER]);
	win.header.label_normal = table[.COLOR_TEXT];
	win.header.label_hover = table[.COLOR_TEXT];
	win.header.label_active = table[.COLOR_TEXT];
	win.header.label_padding = nk.vec2(4,4);
	win.header.padding = nk.vec2(4,4);
	win.header.spacing = nk.vec2(0,0);

	// window header close button
	button = &style.window.header.close_button;
	button.normal          = nk.style_item_color(table[.COLOR_HEADER]);
	button.hover           = nk.style_item_color(table[.COLOR_HEADER]);
	button.active          = nk.style_item_color(table[.COLOR_HEADER]);
	button.border_color    = nk.rgba(0,0,0,0);
	button.text_background = table[.COLOR_HEADER];
	button.text_normal     = table[.COLOR_TEXT];
	button.text_hover      = table[.COLOR_TEXT];
	button.text_active     = table[.COLOR_TEXT];
	button.padding         = nk.vec2(0.0,0.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 0.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;

	// window header minimize button
	button = &style.window.header.minimize_button;
	button.normal          = nk.style_item_color(table[.COLOR_HEADER]);
	button.hover           = nk.style_item_color(table[.COLOR_HEADER]);
	button.active          = nk.style_item_color(table[.COLOR_HEADER]);
	button.border_color    = nk.rgba(0,0,0,0);
	button.text_background = table[.COLOR_HEADER];
	button.text_normal     = table[.COLOR_TEXT];
	button.text_hover      = table[.COLOR_TEXT];
	button.text_active     = table[.COLOR_TEXT];
	button.padding         = nk.vec2(0.0,0.0);
	button.touch_padding   = nk.vec2(0.0,0.0);
	button.userdata        = nk.handle_ptr(nil);
	button.text_alignment  = .TEXT_CENTERED;
	button.border          = 0.0;
	button.rounding        = 0.0;
	button.color_factor_text    = 1.0;
	button.color_factor_background = 1.0;
	button.disabled_factor = nk.WIDGET_DISABLED_FACTOR;
	button.draw_begin      = nil;
	button.draw_end        = nil;

	// window
	win.background = table[.COLOR_WINDOW];
	win.fixed_background = nk.style_item_color(table[.COLOR_WINDOW]);
	win.border_color = table[.COLOR_BORDER];
	win.popup_border_color = table[.COLOR_BORDER];
	win.combo_border_color = table[.COLOR_BORDER];
	win.contextual_border_color = table[.COLOR_BORDER];
	win.menu_border_color = table[.COLOR_BORDER];
	win.group_border_color = table[.COLOR_BORDER];
	win.tooltip_border_color = table[.COLOR_BORDER];
	win.scaler = nk.style_item_color(table[.COLOR_TEXT]);

	win.rounding = 0.0;
	win.spacing = nk.vec2(4,4);
	win.scrollbar_size = nk.vec2(10,10);
	win.min_size = nk.vec2(64,64);

	win.combo_border = 1.0;
	win.contextual_border = 1.0;
	win.menu_border = 1.0;
	win.group_border = 1.0;
	win.tooltip_border = 1.0;
	win.popup_border = 1.0;
	win.border = 3.0;
	win.min_row_height_padding = 8;

	win.padding = nk.vec2(4,4);
	win.group_padding = nk.vec2(4,4);
	win.popup_padding = nk.vec2(4,4);
	win.combo_padding = nk.vec2(4,4);
	win.contextual_padding = nk.vec2(4,4);
	win.menu_padding = nk.vec2(4,4);
	win.tooltip_padding = nk.vec2(4,4);
}
