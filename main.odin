package main;

import "render"
import "core:fmt"

import "core:math/linalg"

//Here you can define the attributes you need, position, texcoord, normal are required by furbs.
Attribute_location :: enum {
	position,
    texcoord,
    normal,
}

//Here you can define the uniforms you need. The following are required and set by furbs:
	//time
	//prj_mat, inv_prj_mat
	//view_mat, inv_view_mat
	//mvp, inv_mvp
	//model_mat, inv_model_mat
	//color_diffuse
	//diffuse_texture
	//texcoords_mat
Uniform_location :: enum {

	//TODO time,

	//Per camera
	prj_mat,
	inv_prj_mat,
	
	view_mat,
	inv_view_mat,
		
	/////////// Anything above binds at bind_shader or before, anything below is a draw call implementation thing ///////////

	//Per model
	mvp,
	inv_mvp,		//will it ever be used?

	model_mat,
	inv_model_mat,	//will it ever be used?
	
	//Per material (materials are not a part of furbs, handle yourself)
	diffuse_color,
	diffuse_texture,

	//Primarily for text
	texcoords_mat,

	/////////// Enter user uniforms below ///////////
}

uniforms_types : [Uniform_location]render.Uniform_info = {
	.prj_mat 			= {	location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care

	.inv_prj_mat 		= {	location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care

	.view_mat 			= {	location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care

	.inv_view_mat 		= {location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care

	.mvp 				= {location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care
	
	.inv_mvp 			= {location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care

	.model_mat 			= {location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care	
	
	.inv_model_mat 		= {location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care

	.diffuse_color 		= {location = -1, 			//-1 means don't care
							uniform_type = .vec4,	//This must be defined
							array_size = -1},		//-1 means don't care	

	.diffuse_texture 	= {location = -1, 			//-1 means don't care
							uniform_type = .sampler_2d,	//This must be defined
							array_size = -1},		//-1 means don't care

	.texcoords_mat 		= {location = -1, 			//-1 means don't care
							uniform_type = .mat4,	//This must be defined
							array_size = -1},		//-1 means don't care
}

attribute_types : [Attribute_location]render.Attribute_info = {

	.position 		= {	location = -1,			//-1 means don't care	
						attribute_type = .vec3},

	.texcoord 		= {	location = -1,			//-1 means don't care
						attribute_type = .vec2},

	.normal 		= {	location = -1,			//-1 means don't care	
						attribute_type = .vec3},		
}

texture_locations : map[Uniform_location]render.Texture_slot = {
	.diffuse_texture = 0,
}

//When opening 2 windows you must manually bind and unbind the windows, this is not required when using a single window as it is just always bound.
open_two_windows :: proc() {

	state1 : render.Render_state(Uniform_location, Attribute_location);
	state2 : render.Render_state(Uniform_location, Attribute_location);

	render.init_render(&state1, uniforms_types, attribute_types, texture_locations, nil, "examples/res/shaders");
	render.unbind_window(&state1);
	render.init_render(&state2, uniforms_types, attribute_types, texture_locations, nil, "examples/res/shaders");
	render.unbind_window(&state2);
	fmt.printf("render inited %v\n", state1.opengl_version);
	fmt.printf("render inited %v\n", state2.opengl_version);

	//s := render.get_default_shader(&state);
	//fmt.printf("Compiling default shader : %v\n", state.opengl_version);
	//init_window
	
	for !render.should_close(&state1) {
		render.bind_window(&state1);
		render.begin_frame(&state1);



		render.end_frame(&state1);
		render.unbind_window(&state1);
		//////////////////////////////////////
		render.bind_window(&state2);
		render.begin_frame(&state2);



		render.end_frame(&state2);
		render.unbind_window(&state2);
	}

	//TODO combine init_render and init_window, then if we need multiable windows, you create multiple renders. This is the best way.

	render.bind_window(&state1);
	render.destroy_render(&state1);
	render.bind_window(&state2);
	render.destroy_render(&state2);

	fmt.printf("successfull shutdown\n");
}

main :: proc () {

	fmt.printf("hello world\n");

	state1 : render.Render_state(Uniform_location, Attribute_location);
	
	render.init_render(&state1, uniforms_types, attribute_types, texture_locations, nil, "examples/res/shaders");
	fmt.printf("render inited %v\n", state1.opengl_version);

	my_quad := render.generate_quad(&state1, size = {1,1,1}, position = {0,0,0}, use_index_buffer=false);
	
	//my_shader : render.Shader(Uniform_location, Attribute_location);
	//render.load_shader(&state1, &my_shader, "gui", "gui");
	
	my_camera : render.Camera2D = {
		position 			= {0,0},
		target_relative 	= {0,0},
		rotation 			= 0,
		zoom	   			= 1,
		
		far 				= 1,
		near 				= -1,
	};
	
	shader := render.get_default_shader(&state1);
	
	opaque := render.make_pipeline(.....);

	for !render.should_close(&state1) {
		
		TODO also make it so you have a single render_state and multiple windows, this allows for sharing resources in multiple windows and is the best way to not have bugs.
		TODO make it so the window is not bound by default, and it gets bound in begin_pipeline
		render.being_pipeline(opaque);

		render.draw_mesh_single(&state1, render.get_default_shader(&state1), my_quad, linalg.MATRIX4F32_IDENTITY);
		
		render.end_pipeline(opaque);
	}

	destroy_pipeline(&opaque);

	render.destroy_render(&state1);

	fmt.printf("successfull shutdown\n");
}

