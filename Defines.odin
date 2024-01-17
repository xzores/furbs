package user_defs;

Uniform_location :: enum {

	//Per Frame
	bg_color,
	game_time,
	real_time,

	//Per prost processing
	post_depth_buffer,
	post_color_texture,
	post_normal_texture,
	
	//For fog post processing
	distance_fog_color,
	fog_density,
	start_far_fog,
	end_far_fog,

	//

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
	
	col_diffuse,
	
	//Textures
	texture_diffuse,
	emission_tex,

	//For text
	texcoords,
}