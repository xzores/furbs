package furbs_gui;

import mu "vendor:microui"

import "core:fmt"

import "../render"
import "core:math/linalg"

w : ^render.Window;

State :: struct {
	pipeline : render.Pipeline,
	window : ^render.Window,
	using ctx : mu.Context,
	
	//temp
	stored : render.Stored_pipeline,
}

init :: proc (window : ^render.Window) -> ^State {
	
	w = window;
	
	state := new(State);
	
	set_clipboard_callback :: proc (user_data : rawptr, s : string) -> bool {
		
		//render.get_clipboard_string();
		return true;
	}

	get_clipboard_callback :: proc (user_data : rawptr) -> (s : string, ok : bool) {
		
		return render.get_clipboard_string(), true;
	}
	
	text_width :: proc(font: mu.Font, str: string) -> i32 {
		return 40;
	}
	
	text_height :: proc(font: mu.Font) -> i32 {
		return 10;
	}
	
	draw_frame :: proc(ctx: ^mu.Context, rect: mu.Rect, colorid: mu.Color_Type) {
		
		color : mu.Color = ctx.style.colors[colorid];
		
		render.set_texture(.texture_diffuse, render.texture2D_get_white());
		render.draw_quad_rect(from_rect_f32(rect), 0, from_color(color));
		
		//fmt.printf("rect : %v, mp : %v\n", rect, render.mouse_pos(w));
		
		//fmt.printf("drawing : %v, color : %v, ctx.style.colors[colorid] : %v, from_color(color) : %v\n", from_rect_f32(rect), colorid, ctx.style.colors[colorid], from_color(color));
	}
	
	state.window = window;
	state.pipeline = render.pipeline_make(render.get_default_shader(), .blend, false);
	
	mu.init(state, set_clipboard_callback, get_clipboard_callback, nil);
	
	state.ctx.text_width = text_width;
	state.ctx.text_height = text_height;
	state.ctx.draw_frame = draw_frame;
	
	return state;
}

destroy :: proc (state : ^State) {
	
	render.pipeline_destroy(state.pipeline);
	
	free(state);
}

begin :: proc (state : ^State, loc := #caller_location) {
	
	for ev in render.key_events() {
		
		k, ok := to_microui_key(ev.key);
		if ev.action == .press || ev.action == .repeat {
			mu.input_key_down(state, k);
		}
		else {
			mu.input_key_up(state, k);
		}
	}
	
	mp := linalg.array_cast(render.mouse_pos(state.window), i32);
	
	for ev in render.mouse_events() {
		
		a, ok := to_microui_button(ev.button);
		if ev.action == .press || ev.action == .repeat {
			fmt.printf("down : %v\n", a);
			mu.input_mouse_down(state, mp.x, mp.y, a);
		}
		else {
			fmt.printf("up: %v\n", a);
			mu.input_mouse_up(state, mp.x, mp.y, a);
		}
	}
	
	mu.input_mouse_move(state, mp.x, mp.y);
	
	//mu.input_text();
	state.stored = render.store_pipeline();
	render.pipeline_begin(state.pipeline, render.camera_get_pixel_space(render.get_current_render_target()));
	
	fmt.printf("begin\n");
	mu.begin(state);
}

end :: proc (state : ^State) {
	
	mu.end(state);
	
	render.pipeline_end();
	render.restore_pipeline(state.stored); state.stored = {};
	
}

Window_opt :: enum u32 {
	ALIGN_CENTER = auto_cast mu.Opt.ALIGN_CENTER,
	ALIGN_RIGHT = auto_cast mu.Opt.ALIGN_RIGHT,
	NO_INTERACT = auto_cast mu.Opt.NO_INTERACT,
	NO_FRAME = auto_cast mu.Opt.NO_FRAME,
	NO_RESIZE = auto_cast mu.Opt.NO_RESIZE,
	NO_SCROLL = auto_cast mu.Opt.NO_SCROLL,
	NO_CLOSE = auto_cast mu.Opt.NO_CLOSE,
	NO_TITLE = auto_cast mu.Opt.NO_TITLE,
	HOLD_FOCUS = auto_cast mu.Opt.HOLD_FOCUS,
	AUTO_SIZE = auto_cast mu.Opt.AUTO_SIZE,
	POPUP = auto_cast mu.Opt.POPUP,
	CLOSED = auto_cast mu.Opt.CLOSED,
	EXPANDED = auto_cast mu.Opt.EXPANDED,
}
Window_options :: distinct bit_set[Window_opt; u32]

begin_window :: proc (state : ^State, title : string, rect : [4]i32, options : Window_options = {}) {
	
	mu.begin_window(state, title, to_rect(rect), transmute(mu.Options)options);
}

end_window :: proc (state : ^State) {
	
	mu.end_window(state);
}

draw_quad :: proc (state : ^State, rect : [4]i32, color : [4]f32) {
	
	mu.draw_rect(state, to_rect(rect), to_color(color));
}

@private
to_rect :: proc (r : [4]i32) -> mu.Rect {
	
	return {r.x, r.y, r.z, r.w};
}

@private
from_rect :: proc (r : mu.Rect) -> [4]i32 {

	return {r.x, r.y, r.w, r.h};
}

@private
from_rect_f32 :: proc (r : mu.Rect) -> [4]f32 {
	return {cast(f32)r.x, cast(f32)r.y, cast(f32)r.w, cast(f32)r.h};
}

@private
to_color :: proc (c : [4]f32) -> mu.Color {
	c := 255 * c;
	return mu.Color{cast(u8)c.a, cast(u8)c.g, cast(u8)c.b, cast(u8)c.a};
}

@private
from_color :: proc (c : mu.Color) -> [4]f32 {
	return {cast(f32)c.r, cast(f32)c.g, cast(f32)c.b, cast(f32)c.a} / 255.0;
}

@private
to_microui_button :: proc (button : render.Mouse_code) -> (res : mu.Mouse, ok : bool) {

	#partial switch button {
		case .left:
			return .LEFT, true;
		case .right:
			return .RIGHT, true;
		case .middel:
			return .MIDDLE, true;
		case:
			return nil, false;
	}
	
	unreachable();
}

@private
to_microui_key :: proc (key_code : render.Key_code) -> (res : mu.Key, ok : bool) {
	
	#partial switch key_code {
		
		case .shift_left, .shift_right:
			return .SHIFT, true
		case .control_left, .control_right:
			return .CTRL, true
		case .alt_left, .alt_right:
			return .ALT, true
		case .backspace:
			return .BACKSPACE, true
		case .delete:
			return .DELETE, true
		case .enter:
			return .RETURN, true
		case .left:
			return .LEFT, true
		case .right:
			return .RIGHT, true
		case .home:
			return .HOME, true
		case .end:
			return .END, true
		case .a:
			return .A, true
		case .x:
			return .X, true
		case .c:
			return .C, true
		case .v:
			return .V, true
		case:
			return nil, true;
	}
	
	unreachable();
}
