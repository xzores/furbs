package render;

import "core:fmt"
import "core:math/linalg"

import "vendor:glfw"

import "gl"

Pipeline_desc :: struct {
	render_target : Render_target,
	shader : ^Shader,
	blend_mode : Blend_mode,
	depth_write : bool,
	depth_test : bool,
	polygon_mode : Polygon_mode,
	culling : Cull_method ,
}

Pipeline :: struct {
	using _ : Pipeline_desc,
	//TODO
}

make_pipeline_parameterized :: proc(render_target : Render_target,
									shader : ^Shader,
									blend_mode : Blend_mode = .blend,
									depth_write : bool = true,
									depth_test : bool = true,
									polygon_mode : Polygon_mode = .fill,
									culling : Cull_method = .no_cull,
									loc := #caller_location) -> (pipeline : Pipeline) {
	
	desc : Pipeline_desc = {
		render_target = render_target,
		shader = shader,
		blend_mode = blend_mode,
		depth_write = depth_write,
		depth_test = depth_test,
		polygon_mode = polygon_mode,
		culling = culling,
	};

	return make_pipeline_desc(desc, loc);
}

make_pipeline_desc :: proc(desc : Pipeline_desc, loc := #caller_location) -> (pipeline : Pipeline) {

	return {desc};
}

make_pipeline :: proc {make_pipeline_desc, make_pipeline_parameterized};

begin_pipeline :: proc (pipeline : Pipeline, camera : Camera, clear_if_fbo : Maybe([4]f32) = [4]f32{0,0,0,0}, flip_if_fbo := true) {
	using gl;

	if window, ok := pipeline.render_target.(^Window); ok {
		if window.glfw_window == state.owner_context {
			state.target_pixel_width, state.target_pixel_height = cast(f32)window.width, cast(f32)window.height;
			gl.bind_frame_buffer(0);
		}
		else {
			state.target_pixel_width, state.target_pixel_height = cast(f32)window.framebuffer.width, cast(f32)window.framebuffer.height;
			gl.bind_frame_buffer(window.framebuffer.id);
		}
	}
	else if fbo, ok := pipeline.render_target.(^Frame_buffer); ok {
		state.target_pixel_width, state.target_pixel_height = cast(f32)fbo.width, cast(f32)fbo.height;
		gl.bind_frame_buffer(fbo.id);

		if clear_colorm, ok := clear_if_fbo.?; ok {
			gl.clear(clear_colorm, {.color_bit, .depth_bit});
		}
	}
	else {
		panic("TODO");
	}

	bind_camera(camera); //must be here so we can flip the camera y-axis when desired.

	if _, ok := pipeline.render_target.(^Frame_buffer); ok {
		if flip_if_fbo { //Because of opengl texcoords, it is ussually desired to flip the texture, we instead flip the camera.
			inverse := matrix[4,4]f32{  //TODO WHY DO WE FLIP THE X-axis? and not the Y-axis? Is is something to do the the camera being 3D? does it work for 2D cameras?
			1,0,0,0,
			0,1,0,0,
			0,0,1,0,
			0,0,0,1,
			};

			state.view_mat = state.view_mat * inverse;
			state.inv_view_mat = linalg.matrix4_inverse(state.view_mat);
			state.prj_mat = state.prj_mat * inverse;
			state.inv_prj_mat = linalg.matrix4_inverse(state.prj_mat);
		}
	}

	bind_shader(pipeline.shader);

	gl.set_viewport(0, 0, state.target_pixel_width, state.target_pixel_height);
	gl.set_blend_mode(pipeline.blend_mode);
	gl.set_depth_write(pipeline.depth_write);
	gl.set_depth_test(pipeline.depth_test);
	gl.set_polygon_mode(pipeline.polygon_mode);
	gl.set_culling(pipeline.culling);
	
	set_uniform(pipeline.shader, .prj_mat, state.prj_mat);
	set_uniform(pipeline.shader, .inv_prj_mat, state.inv_prj_mat);
	set_uniform(pipeline.shader, .view_mat, state.view_mat);
	set_uniform(pipeline.shader, .inv_view_mat, state.inv_view_mat);
}

end_pipeline :: proc (pipeline : Pipeline) {
	using gl;

	unbind_shader(pipeline.shader);

	state.target_pixel_width, state.target_pixel_height = 0, 0;
	state.camera = {};
}