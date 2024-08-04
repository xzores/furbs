package render;

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:time"


//Used internally
get_coordinate_overlay_texture :: proc(camera : Camera3D, texture_size : [2]i32 = {256,256}, loc := #caller_location) -> Texture2D {
	
	if state.overlay_init == false {
		//s, ok := load_shader_from_path("my_shader.glsl"); assert(ok == nil);
		state.shapes_pipeline = pipeline_make(get_default_shader(), .blend, true, true, .fill, .no_cull);
		state.overlay_pipeline = pipeline_make(get_default_shader(), .blend, true, true, .fill, .no_cull);
		state.arrow_fbo = frame_buffer_make_textures(1, texture_size.x, texture_size.y, .RGBA8, .depth_component16, false, .linear);
		state.overlay_init = true;
	}
	
	f := camera_forward(camera);
	r := camera_right(camera);
	u := camera.up;

	overlay_camera : Camera3D = {
		position		= -f,				// Camera position
		target			= {0,0,0},	   // Camera target it looks-at
		up				= {0,1,0},						// Camera up vector (rotation over its axis)
		fovy			= 45,							// Camera field-of-view apperture in Y (degrees) in perspective
		ortho_height 	= 2,							// Camera ortho_height when using orthographic projection
		projection		= .orthographic, 				// Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
		
		near 			= -1,
		far 			= 2,
	}

	target_begin(&state.arrow_fbo, [4]f32{0,0,0,0});
		pipeline_begin(state.shapes_pipeline, overlay_camera);
			set_texture(.texture_diffuse, texture2D_get_white());
			draw_arrow({0,0,0}, {1,0,0},  [4]f32{0.8, 0.1, 0.1, 1});
			draw_arrow({0,0,0}, {0,1,0},  [4]f32{0.1, 0.8, 0.1, 1});
			draw_arrow({0,0,0}, {0,0,1},  [4]f32{0.1, 0.1, 0.8, 1});
		pipeline_end();
	target_end();

	return state.arrow_fbo.color_attachments[0].(Texture2D);
	//return arrow_fbo.depth_attachment.(Texture2D);
}

//offset is in "screen coordinates" from top right corner.
draw_coordinate_overlay :: proc (target : Render_target, camera : Camera3D, offset : [2]f32 = {0.05, 0.05}, scale : f32 = 0.25, loc := #caller_location) {
	
	assert(state.current_target == nil, "There must not be a target, call target_end", loc);
	
	tex := get_coordinate_overlay_texture(camera);

	cam : Camera2D = {
		position 		= {0,0},		// Camera position
		target_relative = {0,0},		// 
		rotation 		= 0,			// in degrees
		zoom 			= 1,			//
		near 			= -10,
		far 			= 10,
	};
	
	target_begin(target, nil);
		aspect : f32 = state.target_pixel_width / state.target_pixel_height;
		pipeline_begin(state.overlay_pipeline, cam);
			set_texture(.texture_diffuse, tex);
			draw_quad(linalg.matrix4_from_trs_f32([3]f32{(aspect) - offset.x - scale/2, 1.0 - offset.y - scale/2, 0}, 0, {scale,scale,1}));
		pipeline_end();
	target_end();
}

//offset is in "screen coordinates" from top left corner.
draw_fps_overlay :: proc (target : Render_target, offset : [2]f32 = {0,0}, scale : f32 = 1) {
	
	//A low pass filter XD
	smoothing : f32 = 0.94; // larger=more smoothing
	state.fps_measurement = (state.fps_measurement * smoothing) + (state.delta_time * (1.0-smoothing))
	
	t := fmt.aprintf("FPS : %i", cast(int)(1.0 / state.fps_measurement));
	defer delete(t);
	
	color : [4]f32 = {1,1,1,1};
	
	size := scale * 40;
	text_bounds := text_get_bounds(t, get_default_fonts().normal, size);

	target_begin(target, nil);
		text_draw_simple(t, {offset.x, state.target_pixel_height - text_bounds.w - offset.y - text_bounds.y}, size, color, {{0,0,0,1}, {2,-2}});
	target_end();
}