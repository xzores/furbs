package utils;

//To init the library do
/*
	font_ctx := utils.font_init(get_texture_limit());
	defer utils.font_destroy(&font_ctx);
	
	my_font := utils.add_font_path_single(&font_ctx, "path_to_a_tff_or_otf_file");
	
	texture := texture2D_make(false, .repeat, .linear, .R8, 1, 1, .no_upload, nil, clear_color = [4]f32{0.5,0,0,0});
	defer texture2D_destroy(texture);	
*/
//get_texture_limit, path_to_a_tff_or_otf_file, texture2D_make and texture2D_destroy is assumed to be implemented by the user.


//When drawing you must do:
/*
	utils.push_font(&font_ctx, my_font); //Set the use of this font.
	utils.set_em_size(&font_ctx, 20);	//Set the size, alternatively use set_max_heigth_size
	
	iter := utils.make_font_iter(&font_ctx, "This is my string"); //This will make sure all the glyphs are loaded and return an iterator.
	
	//Now you the user, must resize your GPU side texture to match the library.
	if new_size, ok := utils.requires_reupload(&font_ctx); ok {
		texture2D_destroy(texture);
		texture = texture2D_make(false, .repeat, .linear, .R8, new_size.x, new_size.y, .R8, utils.get_bitmap(&font_ctx));
	}
	
	TODODODODODODOODODODODODODODODODODODODO!?!?
	
	utils.destroy_font_iter(iter); //Destroy the iter when you are done with it. This is not needed if you pass a temp_allocator in make_font_iter.
	utils.pop_font(&font_ctx); //you call this when you don't want to use the font anymore.
*/
//Again, texture2D_make, texture2D_upload_data and texture2D_destroy is assumed to be implemented by the user.


//Alternatively to uploading each quad induvidially, you could upload the entire texture each time.


//If you wish to see an implementation of a texture2D in OpenGL visit : https://github.com/xzores/furbs