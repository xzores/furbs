package render;

Pipeline :: struct {
	target : Render_target, shader : Shader(U, A),
	clear_color : [4]f32,
	use_transparency : bool,
	blend_mode : Blend_mode,
	depth_write : bool,
	depth_test : bool,
	render_topology : Primitive,
	fill_mode : Fill_method,
	culling : Cull_method = .no_cul
}

make_pipeline :: proc(s : Render_state($U, $A), target : Render_target, shader : Shader(U, A),
							clear_color : [4]f32 = {0,0,0,1}, use_transparency : bool = true, blend_mode : Blend_mode = .alpha_minus_one, depth_write : bool = true,
							depth_test : bool = true, render_topology : Primitive = .triangles, fill_mode : Fill_method = .fill, culling : Cull_method = .no_cull) -> (pipeline : Pipeline) {
	
	pipeline = Pipeline {
		target = target,
		shader = shader,
		clear_color = clear_color,
		use_transparency = use_transparency,
		blend_mode = blend_mode,
		depth_write = depth_write,
		depth_test = depth_test,
		render_topology = render_topology,
		fill_mode = fill_mode,
		culling = culling,
	}

	return;
}

being_pipeline :: proc (s : Render_state($U, $A), using pipeline : Pipeline, cam : union {Camera2D, Camera3D}) {
	
	render.bind_shader(&state1, shader);
	
	////////////////////////////

	if culling == .no_cull {
		gl.Disable(gl.CULL_FACE);
	}
	else {
		gl.FrontFace(gl.CCW);
		gl.Enable(gl.CULL_FACE);
		
		if culling == .front_cull {
			gl.CullFace(gl.FRONT);
		} else {
			gl.CullFace(gl.BACK);
		}
	}

	////////////////////////////

	enable_depth_test(s);
	enable_transparency(s, pipeline.use_transparency);
	
	////////////////////////////

	assert(bound_camera == nil, "A camera is already bound, unbind it first", loc = loc);
	bound_camera = cam;

	aspect : f32 = current_render_target_width / current_render_target_height;

	if camera, ok := cam.(Camera3D); ok {
		s.view_mat = glsl.mat4LookAt(cast(glsl.vec3)camera.position, cast(glsl.vec3)camera.target, -cast(glsl.vec3)camera.up);
		s.inv_view_mat = linalg.matrix4_inverse(view_mat);

		assert(near != 0, "near is 0", loc);
		assert(far != 0, "far is 0", loc);
		
		if (camera.projection == .perspective)
		{
			s.prj_mat = linalg.matrix4_perspective(camera.fovy, aspect, near, far, flip_z_axis = true); //matrix_perspective(math.to_radians(fovy), aspect, near, far);
		}
		else if (camera.projection == .orthographic)
		{	
			top : f32 = camera.fovy/2.0;
			right : f32 = top*aspect;
			
			s.prj_mat = glsl.mat4Ortho3d(-right, right, -top,top, near, far);
		}
		else {
			panic("TODO");
		}
		
		s.inv_prj_mat = linalg.matrix4_inverse(prj_mat);

	} else if camera, ok := cam.(Camera2D); ok {

		translation_mat := linalg.matrix4_translate(-linalg.Vector3f32{camera.position.x, camera.position.y, 0});
		rotation_mat := linalg.matrix4_from_quaternion(linalg.quaternion_angle_axis_f32(math.to_radians(-camera.rotation), {0,0,1}));
		s.view_mat = linalg.mul(translation_mat, rotation_mat);
		s.inv_view_mat = linalg.matrix4_inverse(view_mat);
		
		top : f32 = 1/zoom;
		right : f32 = top*aspect;
		s.prj_mat = glsl.mat4Ortho3d(-right, right, -top, top, near, far);
		s.inv_prj_mat = linalg.matrix4_inverse(prj_mat);
	
	} else {
		panic("TODO");
	}
	
	assert(camera == bound_camera, "The camera you are trying to unbind is not the currently bound camera", loc = loc);
	bound_camera = nil;

}