package render;

import "core:fmt"
import c "core:c/libc"
import "core:os"
import "core:bytes"
import "core:mem"

import "core:image"
import "core:image/png"

import "gl"

import "../utils"

Texture_desc :: struct {

	wrapmode : gl.Wrapmode,
	filtermode : gl.Filtermode,
	mipmaps : bool,						// Is mipmaps enabled?
	format	: gl.Pixel_format_internal,	// Data format (PixelFormat type)
}

Texture2D :: struct {
	id		: gl.Tex2d_id,            	// OpenGL texture id
	width	: i32,               		// Texture base width
	height	: i32,               		// Texture base height

	using desc : Texture_desc,
}

make_texture_2D :: proc(width, height : i32, mipmaps : bool, wrapmode : gl.Wrapmode, filtermode : gl.Filtermode, internal_format : gl.Pixel_format_internal, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture2D {

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex2d_id = gl.gen_texture_2D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture_2D(id, .repeat);
	gl.filtermode_texture_2D(id, .linear);

	size_per_component, channels : int;
	size_per_component = gl.Upload_format_component_size(upload_format);
	channels = gl.Upload_format_channel_cnt(upload_format);

	gl.setup_texure_2D(id, mipmaps, width, height, internal_format);

	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
	}
	else {
		assert(upload_format != .no_upload, "upload_format is no_upload, but there is data", loc);
		length := int(cast(int)width * cast(int)height * channels);
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.write_texure_data_2D(id, 0, 0, 0, width, height, upload_format, data, loc);
	}

	if mipmaps && data != nil { //If there is no data, then it makes no sense to generate mipmaps
		gl.generate_mip_maps_2D(id);
	}

	tex : Texture2D = {
		id, 
		width,
		height,
		{
			wrapmode,
			filtermode,
			mipmaps,
			internal_format,
		},
	}

    return tex;
}

destroy_texture_2D :: proc(tex : ^Texture2D) {
	fmt.printf("TODO? in destroy_texture_2D\n");
	gl.delete_texture_2D(tex.id);
	tex^ = {};
}

/*

Depth_attachment :: union {Texture_id, Render_buffer_id}

Depth_texture2D :: struct {
	id					: Depth_attachment,          // OpenGL texture/renderbuffer id
	width				: c.int,               // Texture base width
	height				: c.int,               // Texture base height
	format				: Depth_format,        // Data format (PixelFormat type)
}

load_texture_from_file :: proc(filename : string, loc := #caller_location) -> Texture2D {
	
	data, ok := os.read_entire_file_from_filename(filename);
	defer delete(data);

	fmt.assertf(ok, "loading texture data for %v failed", filename, loc = loc);

    return load_texture_from_png_bytes(data, filename, loc = loc);
}

flip_texture :: proc(data : []byte, width, height, channels : int) {
	
	line_size := width * channels;
	line_mem, err := mem.alloc_bytes(line_size, allocator = context.temp_allocator);

	assert(err == nil, "Failed to allocate");

	for h in 0..<height/2 {
		row_1 : = h;
		row_2 := (height-h-1);
		mem.copy(raw_data(line_mem), 				&data[h * line_size], 				line_size);	
		mem.copy(&data[h * line_size], 				&data[(height-h-1) * line_size], 	line_size);
		mem.copy(&data[(height-h-1) * line_size], 	raw_data(line_mem), 				line_size);
	}
}

//Data is compressed bytes (ex png format)
load_texture_from_png_bytes :: proc(data : []byte, texture_path := "", flipped := true, loc := #caller_location) -> Texture2D {
	using image;

	options := Options{
		.alpha_add_if_missing,
	};

    img, err := png.load_from_bytes(data, options);

	if err != nil {
		fmt.panicf("Failed to load texture %s, err : %v", texture_path, err, loc = loc);
	}

	defer destroy(img)

	//fmt.printf("Image: %vx%vx%v, %v-bit.\n", img.width, img.height, img.channels, img.depth)

	//TODO do we need any header data?
	/* 
	if v, ok := img.metadata.(^image.PNG_Info); ok {
		
	}
	else {
		panic("Image is not png info");
	}
	*/

	assert(img.depth == 8);
	assert(img.channels == 4);

	raw_data := bytes.buffer_to_bytes(&img.pixels);

	if flipped {
		flip_texture(raw_data, img.width, img.height, img.channels);
	}

    return load_texture_from_raw_bytes(raw_data, auto_cast img.width, auto_cast img.height, .uncompressed_RGBA8, loc = loc);
}

load_texture_from_raw_bytes :: proc(data : []byte, width, height : i32, format : Pixel_format, loc := #caller_location) -> Texture2D {

    texture : Texture2D = {
		id			= load_texture_id(data, width, height, format, loc = loc),              // OpenGL texture id
		width   	= width,        	// Texture base width
		height  	= height,       	// Texture base height
		mipmaps 	= 1,            				// TODO Mipmap levels, 1 by default
		format  	= format,         				// Data format (PixelFormat type)
	};

	return texture;
}

// Load texture for rendering (framebuffer)
// NOTE: Render texture is loaded by default with RGBA color attachment and depth RenderBuffer
load_render_texture :: proc(width : i32, height : i32, number_of_color_attachments : int = 1, depth_as_render_buffer : bool = false,
							 depth_buffer_bits : Depth_format = .bits_24, color_format : Pixel_format = .uncompressed_RGBA8, loc := #caller_location) -> Render_texture {
	
	//TODO number_of_color_attachments							
	
	assert(bound_frame_buffer_id == 0, "Cannot create a render texture while a frame_buffer is bound", loc);

    target : Render_texture = {
    	id = load_frame_buffer(width, height),   // Load an empty framebuffer
	};

    assert(target.id > 0);
	
	enable_frame_buffer(target.id, loc);

	// Create color texture (default to RGBA)
	target.texture.id = load_texture_id(nil, width, height, color_format); //TODO custom internal format?
	target.texture.width = width;
	target.texture.height = height;
	target.texture.format = color_format; 										//TODO custom internal format?
	target.texture.mipmaps = 1;

	// Create depth renderbuffer/texture
	target.depth = {
		width = width,
		height = height,
		format = auto_cast depth_buffer_bits,
	}
	if depth_as_render_buffer {
		target.depth.id = load_depth_render_buffer_id(width, height, depth_as_render_buffer, depth_buffer_bits);
	} else {
		target.depth.id = load_depth_texture_id(width, height, depth_as_render_buffer, depth_buffer_bits);
	}

	// Attach color texture and depth renderbuffer/texture to FBO
	attach_framebuffer_color(target.id, target.texture.id, false);
	attach_framebuffer_depth(target.id, target.depth.id);
	
	// Check if fbo is complete with attachments (valid)
	assert(verify_render_texture(target), "render texture not ready!", loc = loc);
	

	disable_frame_buffer(target.id, loc);

	// Set the list of draw buffers.
	//TODO //draw_buffers(target.id);

    return target;
}

resize_render_texture :: proc(render_texture : ^Render_texture, width : i32, height : i32) {
	
	unload_render_texture(render_texture);
	render_texture^ = load_render_texture(width, height);
	generate_mip_maps(render_texture.texture);
}

unload_render_texture :: proc(rt : ^Render_texture) {
	//TODO
	
	//depth_type, depth_id := get_frame_buffer_depth_info(rt.id);
	//assert(depth_type == gl.RENDERBUFFER, "CPU and GPU depth type does not correspond for depth texture");
	//assert(depth_id == cast(i32)v, "CPU and GPU depth ID does not correspond for depth texture");

	//do the deletions
	unload_frame_buffer(rt.id);
	unload_texture(&rt.texture);
	unload_depth_texture(&rt.depth);
	
	rt.id = 0;
}

unload_texture :: proc(tex : ^Texture2D) {
	unload_texture_id(tex.id);
	tex^ = {};
}

unload_depth_texture :: proc(tex : ^Depth_texture2D) {
	
	if v, ok := tex.id.(Render_buffer_id); ok {
		unload_render_buffer_id(v);
	}
	else if v, ok := tex.id.(Texture_id); ok {
		unload_texture_id(v);
	}
	else {
		panic("AHHHH");
	}

	tex^ = {};
}

// Check if a texture is ready
is_texture_ready :: proc(texture : Texture2D, loc := #caller_location) -> bool {
    
	fmt.assertf(get_max_supported_texture_resolution_2D() >= texture.width, "Texture too large, max res is : %i and texture is %v", get_max_supported_texture_resolution_2D(), texture.width, loc);
	fmt.assertf(get_max_supported_texture_resolution_2D() >= texture.height, "Texture too large, max res is : %i and texture is %v", get_max_supported_texture_resolution_2D(), texture.height, loc);

    return (texture.id > 0 	&&         					// Validate OpenGL id
            texture.width > 0 &&
            texture.height > 0 &&     					// Validate texture size
            utils.is_enum_valid(texture.format) &&     // Validate texture pixel format
            texture.mipmaps > 0);     					// Validate texture mipmaps (at least 1 for basic mipmap level)
}

// Check if a texture is ready
is_depth_texture_ready :: proc(depth : Depth_texture2D, loc := #caller_location) -> bool {
    
	if id, ok := depth.id.(Render_buffer_id); ok {

		fmt.assertf(get_max_supported_texture_resolution_2D() >= depth.width, "Texture too large, max res is : %i and texture is %v", get_max_supported_texture_resolution_2D(), depth.width, loc);
		fmt.assertf(get_max_supported_texture_resolution_2D() >= depth.height, "Texture too large, max res is : %i and texture is %v", get_max_supported_texture_resolution_2D(), depth.height, loc);

		return (id > 0 	&&         					// Validate OpenGL id
				depth.width > 0 &&						
				depth.height > 0 &&     					// Validate texture size
				utils.is_enum_valid(depth.format));
	}
	else if id, ok := depth.id.(Texture_id); ok {

		fmt.assertf(get_max_supported_texture_resolution_2D() >= depth.width, "Texture too large, max res is : %i and texture is %v", get_max_supported_texture_resolution_2D(), depth.width, loc);
		fmt.assertf(get_max_supported_texture_resolution_2D() >= depth.height, "Texture too large, max res is : %i and texture is %v", get_max_supported_texture_resolution_2D(), depth.height, loc);

		return (id > 0 	&&         					// Validate OpenGL id
				depth.width > 0 &&						
				depth.height > 0 &&     					// Validate texture size
				utils.is_enum_valid(depth.format));
	}

	return false;
}

// Check if a render texture is ready
is_render_texture_ready :: proc(render_texture : Render_texture, loc := #caller_location) -> bool {

    return is_texture_ready(render_texture.texture) && is_depth_texture_ready(render_texture.depth) && verify_render_texture(render_texture);     		// TODO Validate texture mipmaps (at least 1 for basic mipmap level)
}

blit_render_texture_to_screen :: proc(render_texture : Render_texture, loc := #caller_location) { //TODO choose attachment
		
	assert(render_texture.texture.width == auto_cast current_render_target_width, "render_texture and screen must have same dimensions", loc = loc);
	assert(render_texture.texture.height == auto_cast current_render_target_height, "render_texture and screen must have same dimensions", loc = loc);
	width := render_texture.texture.width;
	height := render_texture.texture.height;

	enable_frame_buffer_read(render_texture.id);
	enable_frame_buffer_draw(0);
	
	//draw_buffers(render_texture.id);
	blit_frame_buffer(width, height);

	disable_frame_buffer_draw(0);
	disable_frame_buffer_read(render_texture.id);
}

/* 
begin_texture_mode :: proc(target : Render_texture, loc := #caller_location){
	
	fmt.assertf(bound_frame_buffer_id == 0, "Another frame buffer (render texture) is already bound, its id is : %v", bound_frame_buffer_id, loc = loc);

	current_render_target_width = cast(f32)target.texture.width;
	current_render_target_height = cast(f32)target.texture.height;
		
	assert(current_render_target_width != 0);
	assert(current_render_target_height != 0);

    enable_frame_buffer(target.id); // Enable render target
	set_view();
}

end_texture_mode :: proc(target : Render_texture, loc := #caller_location){
	
	fmt.assertf(target.id == bound_frame_buffer_id, "You are unbinding a texture that is not currently bound, currently bound : %v, what you are undbinding : %v\n", bound_frame_buffer_id, target.id, loc = loc);

	//generate_mip_maps(target.texture);

	//draw_buffers(target.id);

	disable_frame_buffer(target.id, loc);
	
	current_render_target_width = auto_cast get_screen_width();
	current_render_target_height = auto_cast get_screen_height();
	set_view();
	
	//fmt.printf("current_render_target_width : %v, current_render_target_height : %v\n", current_render_target_width, current_render_target_height);
}
*/

////////////////////////

get_white_texture :: proc() -> Texture2D {

	if !is_texture_ready(white_texture) {
		white_texture = load_texture_from_raw_bytes({255, 255, 255, 255}, 1, 1, .uncompressed_RGBA8);
	}

	return white_texture;
}

////////////////////////

/*
// NOTE: Data stored in GPU memory
Texture :: struct {
	id:      c.uint,              // OpenGL texture id
	width:   c.int,               // Texture base width
	height:  c.int,               // Texture base height
	mipmaps: c.int,               // Mipmap levels, 1 by default
	format:  PixelFormat,         // Data format (PixelFormat type)
}

// Texture2D type, same as Texture
Texture2D :: Texture

// TextureCubemap type, actually, same as Texture
TextureCubemap :: Texture


gl.activeTextureId();


*/
*/