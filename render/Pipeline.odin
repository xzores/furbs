package render;

import "core:fmt"
import "core:math/linalg"

import "vendor:glfw"

import "gl"

Pipeline_desc :: struct {
	shader : ^Shader,
	blend_mode : Blend_mode,
	depth_write : bool,
	depth_test : bool,
	polygon_mode : Polygon_mode,
	culling : Cull_method,
	depth_clamp : Maybe([2]f64),
}

Pipeline :: struct {
	using _ : Pipeline_desc,
	//TODO
}

@(require_results)
pipeline_make :: proc(	shader : ^Shader,
						blend_mode : Blend_mode = .blend,
						depth_write : bool = true,
						depth_test : bool = true,
						polygon_mode : Polygon_mode = .fill,
						culling : Cull_method = .no_cull,
						depth_clamp : Maybe([2]f64) = nil,
						loc := #caller_location) -> (pipeline : Pipeline) {
	
	assert(shader != nil, "shader is nil", loc);
	
	desc : Pipeline_desc = {
		shader = shader,
		blend_mode = blend_mode,
		depth_write = depth_write,
		depth_test = depth_test,
		polygon_mode = polygon_mode,
		culling = culling,
		depth_clamp = depth_clamp,
	};
	
	return pipeline_make_desc(desc, loc);
}

@(require_results)
pipeline_make_desc :: proc(desc : Pipeline_desc, loc := #caller_location) -> (pipeline : Pipeline) {
	return {desc};
}

pipeline_destroy :: proc (pipeline : Pipeline, loc := #caller_location) {
	//Currently it does nothing, might do something in the future.
}

//TODO flags: clear_color : [4]f32 = {0,0,0,1}, falgs : gl.Clear_flags = {.color_bit, .depth_bit}
pipeline_begin :: proc (pipeline : Pipeline, camera : Camera, loc := #caller_location) {
	assert(state.current_pipeline == {}, "There must not be a bound target before calling begin_pipeline (remember to call end_pipeline).", loc);
	assert(state.current_target != {}, "There must be a bound target before calling begin_pipeline (call begin_target before begin_pipeline).", loc);
	assert(state.target_pixel_width != 0, "target_pixel_width is 0", loc);
	assert(state.target_pixel_height != 0, "target_pixel_height is 0", loc);
	assert(pipeline != {}, "pipeline is nil", loc);

	using gl;
	
	{
		shader_bind(pipeline.shader);
		
		gl.set_blend_mode(pipeline.blend_mode);
		gl.set_depth_write(pipeline.depth_write);
		gl.set_depth_test(pipeline.depth_test);
		gl.set_polygon_mode(pipeline.polygon_mode);
		gl.set_culling(pipeline.culling);
		if range, ok := pipeline.depth_clamp.([2]f64); ok {
			gl.set_depth_clamp(true);
			gl.set_depth_clamp_range(range);
		}
		else {
			gl.set_depth_clamp(false);
		}
		
		camera_bind(camera);

		set_uniform(.prj_mat, state.prj_mat);
		set_uniform(.inv_prj_mat, state.inv_prj_mat);
		
		set_uniform(.view_mat, state.view_mat);
		set_uniform(.inv_view_mat, state.inv_view_mat);

		set_uniform(.view_prj_mat, state.view_prj_mat);
		set_uniform(.inv_view_prj_mat, state.inv_view_prj_mat);

		set_uniform(.time, 		state.time_elapsed);
		set_uniform(.delta_time, 	state.delta_time);

		state.current_pipeline = pipeline;
	}
}

pipeline_end :: proc (loc := #caller_location) {
	assert(state.current_pipeline != {}, "There must be a bound target before calling end_pipeline (use begin_pipeline).", loc);

	using gl;
	
	shader_unbind(state.current_pipeline.shader);

	state.camera = {};
	state.current_pipeline = {};
}


////// TARGET //////

//Following draw commands will draw the the given taret, clear method maybe be nil if clearing is not wanted. Clearing will clear both color and depth buffer if default falgs are used.
target_begin :: proc (render_target : Render_target, clear_method : Maybe([4]f32) = [4]f32{0,0,0,0}, falgs : gl.Clear_flags = {.color_bit, .depth_bit}, loc := #caller_location) {
	assert(state.current_target == {}, "There must not be a bound target before calling begin_target (remember to call end_target).", loc);
	assert(state.is_begin_frame, "You must begin frame before target_begin", loc);
	using gl;

	if clear_method != nil {
		set_depth_write(true);
	}
	
	switch t in render_target {
		case ^Window:{
			if t.glfw_window == state.owner_context {
				state.target_pixel_width, state.target_pixel_height = cast(f32)t.width, cast(f32)t.height;
				gl.bind_frame_buffer(0);
			}
			else {
				state.target_pixel_width, state.target_pixel_height = cast(f32)t.framebuffer.width, cast(f32)t.framebuffer.height;
				gl.bind_frame_buffer(t.framebuffer.id);
			}
		}	
		case ^Frame_buffer:{
			state.target_pixel_width, state.target_pixel_height = cast(f32)t.width, cast(f32)t.height;
			gl.bind_frame_buffer(t.id);
		}
	}
	
	assert(state.target_pixel_width != 0, "target_pixel_width is 0, internal error");
	assert(state.target_pixel_height != 0, "target_pixel_height is 0, internal error");
	
	gl.set_viewport(0, 0, state.target_pixel_width, state.target_pixel_height);

	if clear_color, ok := clear_method.?; ok {
		gl.clear(clear_color, falgs);
	}

	state.current_target = render_target;

}

target_end :: proc (loc := #caller_location) {
	assert(state.current_target != {}, "There must be a bound target before calling target_end (use target_begin).", loc);
	assert(state.current_pipeline == {}, "pipeline_end has not been called before target_end", loc);

	state.target_pixel_width, state.target_pixel_height = 0, 0;

	gl.unbind_frame_buffer();
	state.current_target = {};
}


set_scissor_test :: gl.set_scissor_test;
disable_scissor_test :: gl.disable_scissor_test;
