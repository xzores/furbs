package render;

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"
import "core:math"

Pipeline :: struct(U, A : typeid) {
	render_target : Render_target, shader : Shader(U, A),
	clear_color : [4]f32,
	blend_mode : Blend_mode,
	depth_write : bool,
	depth_test : bool,
	polygon_mode : Polygon_mode,
	fill_mode : Fill_method,
	culling : Cull_method,
}

make_pipeline :: proc(s : ^Render_state($U, $A), render_target : Render_target, shader : Shader(U, A),
						clear_color : [4]f32 = {0,0,0,1}, blend_mode : Blend_mode = .one_minus_src_alpha, depth_write : bool = true, depth_test : bool = true,
						polygon_mode : Polygon_mode = .triangles, fill_mode : Fill_method = .fill, culling : Cull_method = .no_cull, loc := #caller_location) -> (pipeline : Pipeline(U, A)) {
	
	pipeline = Pipeline(U, A) {
		render_target = render_target,
		shader = shader,
		clear_color = clear_color,
		blend_mode = blend_mode,
		depth_write = depth_write,
		depth_test = depth_test,
		polygon_mode = polygon_mode,
		fill_mode = fill_mode,
		culling = culling,
	}

	return;
}

destroy_pipeline :: proc(s : ^Render_state($U, $A), pipeline : ^Pipeline(U, A)) {
	panic("todo");
}

being_pipeline :: proc (s : ^Render_state($U, $A), using pipeline : Pipeline(U, A), cam : union {Camera2D, Camera3D}, loc := #caller_location) {
	
	bind_shader(s, shader);
	
	////////////////////////////

	//set the state
	set_blend_mode(s, blend_mode);
	set_depth_write(s, depth_write);
	set_depth_test(s, depth_test);
	set_polygon_mode(s, polygon_mode);
	set_fill_mode(s, fill_mode);
	set_cull_method(s, culling);

	//Clear the screen
	clear_color_depth(s, clear_color);
	
	//Set render target
	if target, ok := render_target.(Render_texture); ok {
		s.current_render_target_width = cast(f32)target.texture.width;
		s.current_render_target_height = cast(f32)target.texture.height;
			
		assert(s.current_render_target_width != 0);
		assert(s.current_render_target_height != 0);

		enable_frame_buffer(s, target.id); // Enable render target
		set_view(s);
	}
	else if target, ok := render_target.(^Window); ok {

		disable_frame_buffer(s, loc);
		
		s.current_render_target_width = auto_cast get_screen_width(s);
		s.current_render_target_height = auto_cast get_screen_height(s);
		
		set_view(s);
	}
	else {
		panic("todo")
	}

	////////////// CAMERA STUFF //////////////

	aspect : f32 = s.current_render_target_width / s.current_render_target_height;

	if camera, ok := cam.(Camera3D); ok {
		s.view_mat = glsl.mat4LookAt(cast(glsl.vec3)camera.position, cast(glsl.vec3)camera.target, -cast(glsl.vec3)camera.up);
		s.inv_view_mat = linalg.matrix4_inverse(s.view_mat);

		assert(camera.near != 0, "near is 0", loc);
		assert(camera.far != 0, "far is 0", loc);
		
		if (camera.projection == .perspective)
		{
			s.prj_mat = linalg.matrix4_perspective(camera.fovy, aspect, camera.near, camera.far, flip_z_axis = true); //matrix_perspective(math.to_radians(fovy), aspect, near, far);
		}
		else if (camera.projection == .orthographic)
		{	
			top : f32 = camera.fovy/2.0;
			right : f32 = top*aspect;
			
			s.prj_mat = glsl.mat4Ortho3d(-right, right, -top, top, camera.near, camera.far);
		}
		else {
			panic("TODO");
		}
		
		s.inv_prj_mat = linalg.matrix4_inverse(s.prj_mat);

	} else if camera, ok := cam.(Camera2D); ok {

		translation_mat := linalg.matrix4_translate(-linalg.Vector3f32{camera.position.x, camera.position.y, 0});
		rotation_mat := linalg.matrix4_from_quaternion(linalg.quaternion_angle_axis_f32(math.to_radians(-camera.rotation), {0,0,1}));
		s.view_mat = linalg.mul(translation_mat, rotation_mat);
		s.inv_view_mat = linalg.matrix4_inverse(s.view_mat);
		
		top : f32 = 1/camera.zoom;
		right : f32 = top*aspect;
		s.prj_mat = glsl.mat4Ortho3d(-right, right, -top, top, camera.near, camera.far);
		s.inv_prj_mat = linalg.matrix4_inverse(s.prj_mat);
	
	} else {
		panic("TODO");
	}
}


end_pipeline :: proc(s : ^Render_state($U, $A), pipeline : Pipeline(U, A)) {
	panic("TODO");
}

