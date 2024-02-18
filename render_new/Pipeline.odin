package render;

import "core:fmt"

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

begin_pipeline :: proc (pipeline : Pipeline) {
	using gl;
	
	if window, ok := pipeline.render_target.(^Window); ok {
		if window.glfw_window == state.owner_context {
			gl.set_viewport(0, 0, window.width, window.height);
			gl.unbind_frame_buffer();
		}
		else {
			gl.set_viewport(0, 0, window.framebuffer.width, window.framebuffer.height);
			gl.bind_frame_buffer(window.framebuffer.id);
		}
	}
	else if fbo, ok := pipeline.render_target.(^Frame_buffer); ok {
		gl.set_viewport(0, 0, fbo.width, fbo.height);
		gl.bind_frame_buffer(fbo.id);
	}
	else {
		panic("TODO");
	}
	
	bind_shader(pipeline.shader);
	gl.set_blend_mode(pipeline.blend_mode);
	gl.set_depth_write(pipeline.depth_write);
	gl.set_depth_test(pipeline.depth_test);
	gl.set_polygon_mode(pipeline.polygon_mode);
	gl.set_culling(pipeline.culling);
}

end_pipeline :: proc () {
	using gl;

}