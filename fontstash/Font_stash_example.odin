package furbs_fontstash;

//////////////////////////////////////////////////////////////////////////////////////
//	Written by Jakob Furbo Enevoldsen, as an alternative to the original fontstash	//
//				This work is devoteted to the public domain 2024					//
///////////////////////////////////////////////////////////////////////////////////////

//These are examples made using my furbs library collection, you can find it at : https://github.com/xzores/furbs

//To init the library do
/*
	font_ctx := fs.font_init(get_texture_limit());
	defer fs.font_destroy(&font_ctx);
	
	my_font := fs.add_font_path_single(&font_ctx, "path_to_a_tff_or_otf_file");
	
	texture := texture2D_make(false, .repeat, .linear, .R8, 1, 1, .no_upload, nil, clear_color = [4]f32{0.5,0,0,0});
	defer texture2D_destroy(texture);	
*/
//get_texture_limit, path_to_a_tff_or_otf_file, texture2D_make and texture2D_destroy is assumed to be implemented by the user.


//When drawing you must do:
/*
	fs.push_font(&font_ctx, my_font); //Set the use of this font.
	fs.set_em_size(&font_ctx, 20);	//Set the size, alternatively use set_max_heigth_size
	
	iter := fs.make_font_iter(&font_ctx, "This is my string"); //This will make sure all the glyphs are loaded and return an iterator.
	
	//Now you the user, must resize your GPU side texture to match the library.
	if new_size, ok := fs.requires_reupload(&font_ctx); ok {
		texture2D_destroy(texture);
		texture = texture2D_make(false, .repeat, .linear, .R8, new_size.x, new_size.y, .R8, fs.get_bitmap(&font_ctx));
	}
	
	//The user must now upload each quad to the GPU
	rect, done := fs.get_next_quad_upload(&font_ctx);
	for !done {
		//Here the atlas data is extracted from the atlas, alternatively the entire atlas can be uploaded.
		extracted_data := make([]u8, rect.z * rect.w);
		defer delete(extracted_data);
		
		dims := fs.get_bitmap_dimension(&font_ctx);
		fs.copy_pixels(1, dims.x, dims.y, rect.x, rect.y, fs.get_bitmap(&font_ctx), rect.z, rect.w, 0, 0, extracted_data, rect.z, rect.w);
		texture2D_upload_data(&texture, .R8, {rect.x, rect.y}, rect.zw, extracted_data);
		
		rect, done = fs.get_next_quad_upload(&font_ctx);
	}
	
	//Get all the quads that needs to be drawn
	//q is the quad relative to the text baseline and coords are the texture_coordinates that shall be used.
	for q, coords in fs.font_iter_next(&font_ctx, &iter) {
		draw_text_quad(q, coords);
	}
	
	//Cleanup
	fs.destroy_font_iter(iter); //Destroy the iter when you are done with it. This is not needed if you pass a temp_allocator in make_font_iter.
	fs.pop_font(&font_ctx); //you call this when you don't want to use the font anymore.
*/
//Again, draw_text_quad, texture2D_make, texture2D_upload_data and texture2D_destroy is assumed to be implemented by the user.



//Alternatively to uploading each rect induvidially, you could upload the entire texture each time.
//If you wish to see an implementation of a texture2D in OpenGL visit : https://github.com/xzores/furbs
//Here is an example using my library:
/*
	fs.push_font(&font_ctx, my_font); //Set the use of this font.
	fs.set_em_size(&font_ctx, 20);	//Set the size, alternatively use set_max_heigth_size
	
	iter := fs.make_font_iter(&font_ctx, "This is my string"); //This will make sure all the glyphs are loaded and return an iterator.
	
	//Now you the user, must resize your GPU side texture to match the library.
	if new_size, ok := fs.requires_reupload(&font_ctx); ok {
		texture2D_destroy(texture);
		texture = texture2D_make(false, .repeat, .linear, .R8, new_size.x, new_size.y, .R8, fs.get_bitmap(&font_ctx));
	}
	
	//The user must now upload each quad to the GPU
	rect, done := fs.get_next_quad_upload(&font_ctx);
	for !done {
		//Here the atlas data is extracted from the atlas, alternatively the entire atlas can be uploaded.
		extracted_data := make([]u8, rect.z * rect.w);
		defer delete(extracted_data);
		
		dims := fs.get_bitmap_dimension(&font_ctx);
		fs.copy_pixels(1, dims.x, dims.y, rect.x, rect.y, fs.get_bitmap(&font_ctx), rect.z, rect.w, 0, 0, extracted_data, rect.z, rect.w);
		texture2D_upload_data(&texture, .R8, {rect.x, rect.y}, rect.zw, extracted_data);
		fmt.printf("Rect : %v\n", rect);
		
		rect, done = fs.get_next_quad_upload(&font_ctx);
	}
	
	//Alternatively one could upload the entire texture after all quads have been fetched (and ignored).
	//Once could do something like this: texture2D_upload_data(&texture, .R8, {0,0}, fs.get_bitmap_dimension(&font_ctx), fs.get_bitmap(&font_ctx));
	
	//At this point the texture is uploaded correctly and drawing can now commence
	//I draw the quads instanced but that part is up to the user.
	instance_data := make([dynamic]Default_instance_data);
	defer delete(instance_data);
	
	//Get all the quads that needs to be drawn
	//q is the quad relative to the text baseline and coords are the texture_coordinates that shall be used.
	for q, coords in fs.font_iter_next(&font_ctx, &iter) {
		append(&instance_data, Default_instance_data {
			instance_position 	= {q.x + 50, q.y + 40, 0},
			instance_scale 		= {q.z, q.w, 1},
			instance_rotation 	= {0, 0, 0}, //Euler rotation
			instance_tex_pos_scale 	= coords,
		});
	}
	
	//The data is addded as instance data
	if i_data, ok := char_mesh.instance_data.?; ok {
		if i_data.data_points < len(instance_data) {
			mesh_resize_instance_single(&char_mesh, len(instance_data));
			log.infof("Resized text instance data. New length : %v", len(instance_data));
		}
	}
	else {
		unreachable();
	}

	upload_instance_data_single(&char_mesh, 0, instance_data[:]);
	
	set_uniform(get_default_text_shader(), .color_diffuse, [4]f32{1,1,1,1});
	set_texture(.texture_diffuse, texture);
	mesh_draw_instanced(&char_mesh, len(instance_data)); //The text is drawn.
	
	//Cleanup
	fs.destroy_font_iter(iter); //Destroy the iter when you are done with it. This is not needed if you pass a temp_allocator in make_font_iter.
	fs.pop_font(&font_ctx); //you call this when you don't want to use the font anymore.
*/