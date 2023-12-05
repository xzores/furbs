package interface;

//////////////////////////////////////////////////////////////////////// DOCUMENTATION ////////////////////////////////////////////////////////////////////////

//This file is not required to use furbs, but it is very recommended that you add this file to your project or you create a new package with this file.
//This will handle the global state of the render furbs libs. This file creates a single "Render_state", this might be refered to as the global state.

//In this file you will find comments like this above functions, these are the documentation for that function.
/*
Description 		: Here you will find a description of the function,
GPU_state_changes 	: Here you will typically find a yes or a no, telling you if the function interacts with the GPU. Somethis this is more elaporated.
CPU_state_changes 	: Furbs keep track of the GPU state to minimize state changes and more.
Allocations 		: This tells if the function allocates/frees any memory from the heap.
Notes 				: Some additional comments
Failures			: This tells if the function can fail, aka it has a assert, panic or return an error code. Somethis this is more elaporated, if elaporated there might still be more then one way to fail.
*/



//////////////////////////////////////////////////////////////////////// USER IMPLEMENTATION ////////////////////////////////////////////////////////////////////////

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
	//texture_diffuse
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

uniforms_types : [Uniform_location]Uniform_info = {
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
							uniform_type = .sampler_2d,	//This must be defined
							array_size = -1},		//-1 means don't care	
}

attribute_types : [Attribute_location]Attribute_info = {

	.position 		= {	location = -1,			//-1 means don't care	
						attribute_type = .vec3},

	.texcoord 		= {	location = -1,			//-1 means don't care
						attribute_type = .vec2},

	.normal 		= {	location = -1,			//-1 means don't care	
						attribute_type = .vec3},		
}