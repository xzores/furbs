package render;

import "base:runtime"

import "core:fmt"
import c "core:c/libc"
import "core:os"
import "core:bytes"
import "core:mem"
import "core:slice"
import "core:log"
import "core:thread"

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

/////////////////////////////////// Texture 1D ///////////////////////////////////
Texture1D :: struct {
	id			: gl.Tex1d_id,            	// OpenGL texture id
	width		: i32,               		// Texture base width

	using desc : Texture_desc,
}

@(require_results)
make_texture_1D :: proc(mipmaps : bool, wrapmode : gl.Wrapmode, filtermode : gl.Filtermode, internal_format : gl.Pixel_format_internal,
							 width : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture1D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};

	return make_texture_1D_desc(desc, width, upload_format, data, loc);
}

@(require_results)
make_texture_1D_desc :: proc(using desc : Texture_desc, width : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture1D {

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex1d_id = gl.gen_texture_1D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture_1D(id, desc.wrapmode);
	gl.filtermode_texture_1D(id, desc.filtermode, mipmaps);

	size_per_component, channels : int;
	size_per_component = gl.upload_format_component_size(upload_format);
	channels = gl.upload_format_channel_cnt(upload_format);

	gl.setup_texure_1D(id, mipmaps, width, format);

	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
	}
	else {
		assert(upload_format != .no_upload, "upload_format is no_upload, but there is data", loc);
		length := int(cast(int)width * channels);
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.write_texure_data_1D(id, 0, 0, width, upload_format, data, loc);
	}

	if mipmaps && data != nil { //If there is no data, then it makes no sense to generate mipmaps
		gl.generate_mip_maps_1D(id);
	}

	tex : Texture1D = {
		id, 
		width,
		desc,
	}

    return tex;
}

destroy_texture_1D :: proc(tex : ^Texture1D) {
	gl.delete_texture_1D(tex.id);
	tex^ = {};
}

upload_texture_1D_data :: proc(tex : ^Texture1D, #any_int pixel_offset : i32, #any_int pixel_cnt : i32, format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) {
	
	gl.write_texure_data_1D(tex.id, 0, auto_cast pixel_offset, auto_cast pixel_cnt, format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_1D(tex.id);
	}
}

/////////////////////////////////// Texture 2D ///////////////////////////////////
Texture2D :: struct {
	id			: gl.Tex2d_id,            	// OpenGL texture id
	width		: i32,               		// Texture base width
	height		: i32,               		// Texture base height

	using desc : Texture_desc,
}

@(require_results)
load_texture_2D_from_file :: proc(filename : string, desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8}, loc := #caller_location) -> Texture2D {
	
	data, ok := os.read_entire_file_from_filename(filename);
	defer delete(data);

	fmt.assertf(ok, "loading texture data for %v failed", filename, loc = loc);

    return load_texture_2D_from_png_bytes(desc, data, filename, loc = loc);
}

//Load many textures threaded, good for many of the same types of textures.
//nil is returned if we failed to load. Allocator must be multithread safe if keep_allocator is true.
@(require_results)
load_textures_2D_from_file :: proc(paths : []string, desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8}, flipped := true, keep_allocator := false, loc := #caller_location) -> (textures : []Maybe(Texture2D)) {
	
	Load_png_info :: struct {
		//in
		filename : string,	//better name path
		flipped : bool,

		//out
		allocator : runtime.Allocator,
		img : ^image.Image,
		failed : bool,
	}
	
	run_load_from_disk :: proc (info : rawptr) {
		
		info : ^Load_png_info = auto_cast info;
		context.allocator = info.allocator;

		data, ok := os.read_entire_file_from_filename(info.filename);
		defer delete(data);
		if ok {
			using image;

			options := Options{
				.alpha_add_if_missing,
			};

			err: image.Error;
			info.img, err = png.load_from_bytes(data, options);

			if err != nil {
				info.failed = true;
				return;
			}

			switch info.img.depth {
				case 8:
					//do nothing
				case 16: //convert to 8 bit depth.
					current := bytes.buffer_to_bytes(&info.img.pixels);
					new := make([]u8, len(current) / 2);
					for &v, i in new {
						v = current[i*2];
					}
					bytes.buffer_destroy(&info.img.pixels);
					bytes.buffer_init(&info.img.pixels, new);
					info.img.depth = 8;
				case:
					panic("unimplemented");
			}

			fmt.assertf(info.img.depth == 8, "texture %v has depth %v, not 8", info.filename, info.img.depth);
			fmt.assertf(info.img.channels == 4, "texture %v does not have 4 channels", info.filename);

			if info.flipped {
				raw_data := bytes.buffer_to_bytes(&info.img.pixels);
				flip_texture_2D(raw_data, info.img.width, info.img.height, info.img.channels);
			}
		}
		else {
			info.failed = true;
		}
	}

	textures = make([]Maybe(Texture2D), len(paths));

	data : []Load_png_info = make([]Load_png_info, len(paths));
	threads := make([]^thread.Thread, len(paths));
	defer delete(threads);
	defer delete(data);

	for to_load, i in paths {
		res : ^Load_png_info = &data[i];
		res.filename = to_load;
		res.flipped = flipped;
		res.allocator = context.allocator;
		threads[i] = thread.create_and_start_with_data(res, run_load_from_disk);
	}

	for t, i in threads {
		thread.join(t);
		
		info := data[i];

		if !info.failed {
			raw_data := bytes.buffer_to_bytes(&info.img.pixels);
			textures[i] = make_texture_2D_desc(desc, info.img.width, info.img.height, .RGBA8, raw_data, loc);
			//cleanup
		}
		else {
			log.errorf("Could not load file : %v", info.filename);
			textures[i] = nil;
			//TODO is there any cleanup here?
		}
		
		image.destroy(info.img);
		thread.destroy(t);
	}

	return;
}

//Data is compressed bytes (ex png format)
@(require_results)
load_texture_2D_from_png_bytes :: proc(desc : Texture_desc, data : []byte, texture_path := "", auto_convert_depth := true, flipped := true, loc := #caller_location) -> Texture2D {
	using image;

	options := Options{
		.alpha_add_if_missing,
	};

    img, err := png.load_from_bytes(data, options);
	defer image.destroy(img);
	
	if err != nil {
		fmt.panicf("Failed to load texture %s, err : %v", texture_path, err, loc = loc);
	}

	if auto_convert_depth {
		switch img.depth {
			case 8:
				//do nothing
			case 16: //convert to 8 bit depth.
				current := bytes.buffer_to_bytes(&img.pixels);
				new := make([]u8, len(current) / 2);
				for &v, i in new {
					v = current[i*2];
				}
				bytes.buffer_destroy(&img.pixels);
				bytes.buffer_init(&img.pixels, new);
				img.depth = 8;
			case:
				panic("unimplemented");
		}
	}

	fmt.assertf(img.depth == 8, "texture %v has depth %v, not 8", texture_path, img.depth, loc = loc);
	fmt.assertf(img.channels == 4, "texture %v does not have 4 channels", texture_path, loc = loc);
	
	raw_data := bytes.buffer_to_bytes(&img.pixels); //these are owned by the image and it will be deleted at the end of call.
	
	if flipped {
		flip_texture_2D(raw_data, img.width, img.height, img.channels);
	}

	return make_texture_2D_desc(desc, img.width, img.height, .RGBA8, raw_data, loc);
}

@(require_results)
make_texture_2D :: proc(mipmaps : bool, wrapmode : gl.Wrapmode, filtermode : gl.Filtermode, internal_format : gl.Pixel_format_internal,
							 width, height : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture2D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};

	return make_texture_2D_desc(desc, width, height, upload_format, data, loc);
}

@(require_results)
make_texture_2D_desc :: proc(using desc : Texture_desc, #any_int width, height : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture2D {

	/*
	assert(wrapmode != nil, "wrapmode is nil", loc);
	assert(filtermode != nil, "filtermode is nil", loc);
	assert(format != nil, "format is nil", loc);
	*/
	
	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex2d_id = gl.gen_texture_2D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture_2D(id, desc.wrapmode);
	gl.filtermode_texture_2D(id, desc.filtermode, mipmaps);

	size_per_component, channels : int;
	size_per_component = gl.upload_format_component_size(upload_format);
	channels = gl.upload_format_channel_cnt(upload_format);

	gl.setup_texure_2D(id, mipmaps, width, height, format);

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
		desc,
	}

    return tex;
}

upload_texture_2D_data :: proc(tex : ^Texture2D, upload_format : gl.Pixel_format_upload, pixel_offset : [2]i32, pixel_cnt : [2]i32, data : []$T, loc := #caller_location) {
	
	gl.write_texure_data_2D(tex.id, 0, pixel_offset.x, pixel_offset.y, pixel_cnt.x, pixel_cnt.y, upload_format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_2D(tex.id);
	}
}

destroy_texture_2D :: proc(tex : ^Texture2D) {
	gl.delete_texture_2D(tex.id);
	tex^ = {};
}

flip_texture_2D :: proc(data : []byte, width, height, channels : int) {
	
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

get_white_texture :: proc() -> Texture2D {
	
	if state.white_texture.id == 0 {
		
		desc := Texture_desc{
			.repeat,
			.nearest,
			false,
			.RGBA8,
		};

		state.white_texture = make_texture_2D_desc(desc, 1, 1, .RGBA8, {255, 255, 255, 255});
	}

	return state.white_texture;
}

get_black_texture :: proc () -> Texture2D {
	
	if state.black_texture.id == 0 {
		
		desc := Texture_desc{
			.repeat,
			.nearest,
			false,
			.RGBA8,
		};

		state.black_texture = make_texture_2D_desc(desc, 1, 1, .RGBA8, {0, 0, 0, 255});
	}

	return state.black_texture;
}

/////////////////////////////////// Texture 3D ///////////////////////////////////
Texture3D :: struct {
	id			: gl.Tex3d_id,            	// OpenGL texture id
	width		: i32,               		// Texture base width
	height		: i32,               		// Texture base height
	depth 		: i32, 						// Texture base depth

	using desc : Texture_desc,
}

@(require_results)
make_texture_3D :: proc(mipmaps : bool, wrapmode : gl.Wrapmode, filtermode : gl.Filtermode, internal_format : gl.Pixel_format_internal,
							 width, height, depth : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture3D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};

	return make_texture_3D_desc(desc, width, height, depth, upload_format, data, loc);
}

@(require_results)
make_texture_3D_desc :: proc(using desc : Texture_desc, width, height, depth : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture3D {

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex3d_id = gl.gen_texture_3D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture_3D(id, desc.wrapmode);
	gl.filtermode_texture_3D(id, desc.filtermode, mipmaps);
	
	size_per_component, channels : int;
	size_per_component = gl.upload_format_component_size(upload_format);
	channels = gl.upload_format_channel_cnt(upload_format);

	gl.setup_texure_3D(id, mipmaps, width, height, depth, format);

	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
	}
	else {
		assert(upload_format != .no_upload, "upload_format is no_upload, but there is data", loc);
		length := int(cast(int)width * channels);
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.write_texure_data_3D(id, 0, 0, 0, 0, width, height, depth, upload_format, data, loc);
	}

	if mipmaps && data != nil { //If there is no data, then it makes no sense to generate mipmaps
		gl.generate_mip_maps_3D(id);
	}

	tex : Texture3D = {
		id, 
		width,
		height,
		depth,
		desc,
	}

    return tex;
}

destroy_texture_3D :: proc(tex : ^Texture3D) {
	gl.delete_texture_3D(tex.id);
	tex^ = {};
}

upload_texture_3D_data :: proc(tex : ^Texture3D, pixel_offset : [3]i32, pixel_cnt : [3]i32, format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) {
	
	gl.write_texure_data_3D(tex.id, 0, pixel_offset.x, pixel_offset.y, pixel_offset.z, pixel_cnt.x, pixel_cnt.y, pixel_cnt.z, format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_3D(tex.id);
	}
}


/////////////////////////////////// Texture 2D multisampled ///////////////////////////////////




/////////////////////////////////// Texture arrays 2D ///////////////////////////////////





/////////////////////////////////// Texture cubemap 2D ///////////////////////////////////
//TODO use glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS)































/*
Depth_attachment :: union {Texture_id, Render_buffer_id}

Depth_texture2D :: struct {
	id					: Depth_attachment,          // OpenGL texture/renderbuffer id
	width				: c.int,               // Texture base width
	height				: c.int,               // Texture base height
	format				: Depth_format,        // Data format (PixelFormat type)
}

// Load texture for rendering (framebuffer)
// NOTE: Render texture is loaded by default with RGBA color attachment and depth RenderBuffer
load_render_texture :: proc(width : i32, height : i32, number_of_color_attachments : int = 1, depth_as_render_buffer : bool = false,
							 depth_buffer_bits : Depth_format = .bits_24, color_format : Pixel_format = .RGBA8, loc := #caller_location) -> Render_texture {
	
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