package frubs_gui;

import "base:runtime"

import "core:mem"
import "core:c"
import "core:log"
import "core:math/linalg"
import "core:fmt"

import nk "../nuklear"

import "../render"


State :: struct {
	
	pipeline : render.Pipeline,
	
	odin_allocator : mem.Allocator,
	logger : log.Logger,
	
	nk_font : nk.User_font,
	nk_alloc : nk.Allocator,
	
	ctx : nk.Context,
}

init :: proc () -> ^State {
	
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
		log.warnf("allocating");
		fmt.printf("allocating");
		
		return new_ptr // your allocator here
	}
	
	nk_free : nk.nk_plugin_free : proc "c" (h: nk.Handle, old: rawptr)  {
		user_data : ^State = cast(^State)h.ptr;
		
		context = runtime.default_context();
		log.warnf("freeing");
		
		mem.free(old, user_data.odin_allocator); 
	}
	
	s.nk_alloc = nk.Allocator {
		nk.Handle{ptr = s},
		nk_allocate,
		nk_free,
	}
	
	nk_font_width : nk.Text_width_f : proc "c" (handle : nk.Handle, h: f32, str: cstring, len: c.int) -> f32 {
		
		return 40;
	}
	
	s^ = State {
		render.pipeline_make(render.get_default_shader(), .blend, false),
		context.allocator,
		context.logger,
		nk.User_font {
			nk.Handle{ptr = nil},    	/**!< user provided font handle */
			20,          				/**!< max height of the font */
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
	
	return s;
}

destroy :: proc (state : ^State) {
	
	nk.free(&state.ctx);
	free(state);
}

begin :: proc (state : ^State, loc := #caller_location) {
	
	render.pipeline_begin(state.pipeline, render.camera_get_pixel_space(render.get_current_render_target()));
}

end :: proc (state : ^State) {

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
				fmt.printf("nk_command_rect : %v\n", cmd);
				
			}
			case .NK_COMMAND_RECT_FILLED:{
				cmd := cast(^nk.nk_command_rect_filled)c;
				//fmt.printf("nk_command_rect_filled : %v\n", cmd);
				
				render.set_texture(.texture_diffuse, render.texture2D_get_white());
				render.draw_quad_rect([4]f32{cast(f32)cmd.x, cast(f32)cmd.y, cast(f32)cmd.w, cast(f32)cmd.h}, 0, linalg.array_cast(cmd.color, f32) / 255);
			}
			case .NK_COMMAND_TEXT:{
				cmd := cast(^nk.nk_command_text)c;
				fmt.printf("nk_command_text : %v\n", cmd);
			}
			case .NK_COMMAND_TRIANGLE:{
				cmd := cast(^nk.nk_command_triangle)c;
				fmt.printf("nk_command_triangle : %v\n", cmd);
			}
			case .NK_COMMAND_TRIANGLE_FILLED:{
				cmd := cast(^nk.nk_command_triangle_filled)c;
				fmt.printf("nk_command_triangle_filled : %v\n", cmd);
			}
			case .NK_COMMAND_POLYLINE:{
				cmd := cast(^nk.nk_command_polyline)c;
				fmt.printf("nk_command_polyline : %v\n", cmd);
		}
			case .NK_COMMAND_SCISSOR:{
				cmd := cast(^nk.nk_command_scissor)c;				
				render.set_scissor_test(cmd.x, cmd.y, cmd.w, cmd.h);
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
	log.warn("CLEAR!");
	
	render.disable_scissor_test();	
	nk.clear(&state.ctx);
}



/////////////////////////////////////// GUI functions ///////////////////////////////////////

Panel_flags :: nk.Panel_flags;

window_begin :: proc (state : ^State, name : string, rect : Rect, flags : Panel_flags, title := "") -> bool {
	
	if title != "" {
		return nk.begin_titled(&state.ctx, fmt.ctprintf(name), fmt.ctprintf(title), rect, flags);
	}
	else {
		return nk.begin(&state.ctx, fmt.ctprintf(name), rect, flags);
	}
		
}

window_end :: proc (state : ^State) {
	
	nk.end(&state.ctx);
}







/////////////////////////////////////// translations ///////////////////////////////////////


Color :: nk.Color;
ColorF :: nk.ColorF;
Rect :: nk.Rect;
Recti :: nk.Recti;
Vec2 :: nk.Vec2;
Vec2i :: nk.Vec2i;





