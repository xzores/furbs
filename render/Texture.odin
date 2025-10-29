package render;

import "core:math/linalg"
import "core:reflect"
import "base:runtime"

import "core:fmt"
import c "core:c/libc"
import "core:os"
import "core:bytes"
import "core:mem"
import "core:slice"
import "core:log"
import "core:thread"
import "core:math"
import "core:time"

import "core:image"
import "core:image/png"
import "core:container/priority_queue"

import "gl"

import "../utils"
import fs "../fontstash"

Pixel_format_internal 	:: gl.Pixel_format_internal;
Wrapmode 				:: gl.Wrapmode;
Filtermode 				:: gl.Filtermode;

Texture_desc :: struct {
	wrapmode : Wrapmode,
	filtermode : Filtermode,
	mipmaps : bool,						// Is mipmaps enabled?
	format	: Pixel_format_internal,	// Data format (PixelFormat type)
	border_color : [4]f32,
}

/////////////////////////////////// Texture 1D ///////////////////////////////////
Texture1D :: struct {
	id			: gl.Tex1d_id,				// OpenGL texture id
	width		: i32,			   		// Texture base width

	using desc : Texture_desc,
}

@(require_results)
texture1D_make :: proc(mipmaps : bool, wrapmode : Wrapmode, filtermode : Filtermode, internal_format : Pixel_format_internal,
							 width : i32, upload_format : gl.Pixel_format_upload, data : []u8, border_color := [4]f32{0,0,0,0}, clear_color : Maybe([4]f64) = [4]f64{0,0,0,0}, loc := #caller_location) -> Texture1D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
		border_color 	= border_color,
	};
	
	return texture1D_make_desc(desc, width, upload_format, data, loc = loc);
}

@(require_results)
texture1D_make_desc :: proc(using desc : Texture_desc, width : i32, upload_format : gl.Pixel_format_upload, data : []u8, clear_color : Maybe([4]f64) = [4]f64{0,0,0,0}, label := "", loc := #caller_location) -> Texture1D {
	assert(state.is_init, "You must init first", loc);

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex1d_id = gl.gen_texture1D(label, loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

	gl.wrapmode_texture1D(id, desc.wrapmode);
	gl.filtermode_texture1D(id, desc.filtermode, mipmaps);

	size_per_component, channels : int;
	size_per_component = gl.upload_format_component_size(upload_format);
	channels = gl.upload_format_channel_cnt(upload_format);

	gl.setup_texure_1D(id, mipmaps, width, format);
	gl.set_texture_border_color_1D(id, desc.border_color);

	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
		if cc, ok := clear_color.([4]f64); ok {
			gl.clear_texture_1D(id, cc, loc);
		}
	}
	else {
		assert(upload_format != .no_upload, "upload_format is no_upload, but there is data", loc);
		length := int(cast(int)width * channels);
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.write_texure_data_1D(id, 0, 0, width, upload_format, data, loc = loc);
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

texture1D_clear :: proc(tex : ^Texture1D, clear_color : [4]f64, loc := #caller_location) {
	gl.clear_texture_1D(tex.id, clear_color, loc);
}

texture1D_destroy :: proc(tex : Texture1D) {
	gl.delete_texture1D(tex.id);
}

texture1D_upload_data :: proc(tex : ^Texture1D, #any_int pixel_offset : i32, #any_int pixel_cnt : i32, format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) {
	
	gl.write_texure_data_1D(tex.id, 0, auto_cast pixel_offset, auto_cast pixel_cnt, format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_1D(tex.id);
	}
}

/////////////////////////////////// Texture 2D ///////////////////////////////////
Texture2D :: struct {
	id			: gl.Tex2d_id,				// OpenGL texture id
	width		: i32,			   		// Texture base width
	height		: i32,			   		// Texture base height

	using desc : Texture_desc,
}

@(require_results)
texture2D_load_from_file :: proc(filename : string, desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8, {0,0,0,0}}, loc := #caller_location) -> (tex : Texture2D, ok : bool) {
	
	data, load_ok := os.read_entire_file_from_filename(filename);
	defer delete(data);
	
	if !load_ok {
		log.errorf("loading texture data for %v failed", filename, location = loc);
		return {}, false;
	}

	return texture2D_load_from_png_bytes(desc, data, filename, loc = loc), true;
}

default_tex_desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8, {0,0,0,0}};

//Load many textures threaded, good for many of the same types of textures.
//nil is returned if we failed to load. Allocator must be multithread safe if keep_allocator is true.
@(require_results)
texture2D_load_multi_from_file :: proc(paths : []string, desc : Texture_desc = default_tex_desc, flipped := true, keep_allocator := false, loc := #caller_location) -> (textures : []Maybe(Texture2D)) {
	
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
				texture2D_flip(raw_data, info.img.width, info.img.height, info.img.channels);
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

	for scene_to_load, i in paths {
		res : ^Load_png_info = &data[i];
		res.filename = scene_to_load;
		res.flipped = flipped;
		res.allocator = context.allocator;
		threads[i] = thread.create_and_start_with_data(res, run_load_from_disk);
	}

	for t, i in threads {
		thread.join(t);
		
		info := data[i];

		if !info.failed {
			raw_data := bytes.buffer_to_bytes(&info.img.pixels);
			textures[i] = texture2D_make_desc(desc, info.img.width, info.img.height, .RGBA8, raw_data, loc = loc);
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
texture2D_load_from_png_bytes :: proc(desc : Texture_desc, data : []byte, texture_path := "", auto_convert_depth := true, flipped := true, loc := #caller_location) -> Texture2D {
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
		texture2D_flip(raw_data, img.width, img.height, img.channels);
	}

	return texture2D_make_desc(desc, img.width, img.height, .RGBA8, raw_data, label = texture_path, loc = loc);
}

//Clear color is only used if data is nil
@(require_results)
texture2D_make :: proc(mipmaps : bool, wrapmode : Wrapmode, filtermode : Filtermode, internal_format : Pixel_format_internal,
							#any_int width, height : i32, upload_format : gl.Pixel_format_upload, data : []u8, clear_color : Maybe([4]f64) = [4]f64{0,0,0,0}, label := "", loc := #caller_location) -> Texture2D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};
	
	return texture2D_make_desc(desc, width, height, upload_format, data, clear_color, label, loc);
}

//Clear color is only used if data is nil
@(require_results)
texture2D_make_desc :: proc(using desc : Texture_desc, #any_int width, height : i32, upload_format : gl.Pixel_format_upload, data : []u8, clear_color : Maybe([4]f64) = [4]f64{0,0,0,0}, label := "", loc := #caller_location) -> Texture2D {
	assert(state.is_init, "You must init first", loc);
	assert(wrapmode != nil, "wrapmode is nil", loc);
	assert(filtermode != nil, "filtermode is nil", loc);
	assert(format != nil, "format is nil", loc);
	
	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	if upload_format != .no_upload {
		assert(data != nil, "Data must not be nil if upload_format is not .no_upload", loc = loc);
	}
	
	id : gl.Tex2d_id = gl.gen_texture2D(label, loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);
	
	gl.wrapmode_texture2D(id, desc.wrapmode);
	gl.filtermode_texture2D(id, desc.filtermode, mipmaps);	
	gl.setup_texture_2D(id, mipmaps, width, height, format);
	gl.set_texture_border_color_2D(id, desc.border_color);
	
	channels := gl.upload_format_channel_cnt(upload_format);
	
	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
		
		if cc, ok := clear_color.([4]f64); ok {
			gl.clear_texture_2D(id, cc, loc);
		}
	}
	else {
		assert(upload_format != .no_upload, "upload_format is no_upload, but there is data", loc);
		length := int(cast(int)width * cast(int)height * channels);
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.write_texure_data_2D(id, 0, 0, 0, width, height, upload_format, data, loc);
	}

	if mipmaps { //If there is no data, then it makes no sense to generate mipmaps
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

texture2D_upload_data :: proc(tex : ^Texture2D, upload_format : gl.Pixel_format_upload, pixel_offset : [2]i32, pixel_cnt : [2]i32, data : []$T, loc := #caller_location) {
	
	gl.write_texure_data_2D(tex.id, 0, pixel_offset.x, pixel_offset.y, pixel_cnt.x, pixel_cnt.y, upload_format, slice.reinterpret([]u8, data), loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_2D(tex.id);
	}
}

texture2D_resize :: proc (tex : ^Texture2D, new_size : [2]i32) {
	texture2D_destroy(tex^);
	tex^ = texture2D_make(tex.mipmaps, tex.wrapmode, tex.filtermode, tex.format, new_size.x, new_size.y, .no_upload, nil, nil);
}

texture2D_clear :: proc(tex : ^Texture2D, clear_color : [4]f64, loc := #caller_location) {
	gl.clear_texture_2D(tex.id, clear_color, loc);
}

//TODO should this require the pointer?
texture2D_destroy :: proc(tex : Texture2D, loc := #caller_location) {
	gl.delete_texture2D(tex.id, loc);
}

@(require_results)
texture2D_download_texture :: proc(tex : Texture2D, loc := #caller_location) -> (data : [][4]u8) {
	
	res := gl.get_texture_image2D(tex.id, 0, loc);
	
	assert(auto_cast len(res) == tex.width * tex.height, "Internal error. There is a mismatch is GL and Odin states, they dont agree on texture size.");
	
	return res;
}

texture2D_flip :: proc(data : []byte, #any_int width, height, channels : int) {
	
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

texture2D_get_white :: proc() -> Texture2D {
	
	if state.white_texture.id == 0 {
		
		desc := Texture_desc{
			.repeat,
			.nearest,
			false,
			.RGBA8,
			{0,0,0,0},
		};

		state.white_texture = texture2D_make_desc(desc, 1, 1, .RGBA8, {255, 255, 255, 255}, label = "Default White Texture");
	}

	return state.white_texture;
}

texture2D_get_black :: proc () -> Texture2D {
	
	if state.black_texture.id == 0 {
		
		desc := Texture_desc{
			.repeat,
			.nearest,
			false,
			.RGBA8,
			{0,0,0,0},
		};

		state.black_texture = texture2D_make_desc(desc, 1, 1, .RGBA8, {0, 0, 0, 255}, label = "Default Black Texture");
	}

	return state.black_texture;
}

/////////////////////////////////// Texture 3D ///////////////////////////////////
Texture3D :: struct {
	id			: gl.Tex3d_id,				// OpenGL texture id
	width		: i32,			   		// Texture base width
	height		: i32,			   		// Texture base height
	depth 		: i32, 						// Texture base depth

	using desc : Texture_desc,
}

@(require_results)
texture3D_make :: proc(mipmaps : bool, wrapmode : Wrapmode, filtermode : Filtermode, internal_format : Pixel_format_internal,
							 width, height, depth : i32, upload_format : gl.Pixel_format_upload, data : []u8, clear_color : Maybe([4]f64) = [4]f64{0,0,0,0}, label := "", loc := #caller_location) -> Texture3D {
	
	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};
	
	return texture3D_make_desc(desc, width, height, depth, upload_format, data, clear_color, label, loc);
}

//clear_color is in range 0 to 1
@(require_results)
texture3D_make_desc :: proc(using desc : Texture_desc, width, height, depth : i32, upload_format : gl.Pixel_format_upload, data : []u8, clear_color : Maybe([4]f64) = [4]f64{0,0,0,0}, label := "", loc := #caller_location) -> Texture3D {
	assert(state.is_init, "You must init first", loc);
	assert(desc.wrapmode != nil, "mode is invalid", loc);
	
	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO this is done at startup is that enough?
	
	id : gl.Tex3d_id = gl.gen_texture3D(label, loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);
	
	gl.wrapmode_texture3D(id, desc.wrapmode);
	gl.filtermode_texture3D(id, desc.filtermode, mipmaps);
	
	size_per_component, channels : int;
	size_per_component = gl.upload_format_component_size(upload_format);
	channels = gl.upload_format_channel_cnt(upload_format);
	
	gl.setup_texure_3D(id, mipmaps, width, height, depth, format);
	gl.set_texture_border_color_3D(id, desc.border_color);
		
	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
		if cc, ok := clear_color.([4]f64); ok {		
			gl.clear_texture_3D(id, cc, loc);
		}
	}
	else {
		assert(upload_format != .no_upload, "upload_format is no_upload, but there is data", loc);
		length := cast(int)depth * cast(int)height * cast(int)width * channels;
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.write_texure_data_3D(id, 0, 0, 0, 0, width, height, depth, upload_format, data, loc = loc);
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

texture3D_clear :: proc(tex : ^Texture3D, clear_color : [4]f64, loc := #caller_location) {
	gl.clear_texture_3D(tex.id, clear_color, loc);
}

texture3D_destroy :: proc(tex : Texture3D) {
	gl.delete_texture3D(tex.id);
}

texture3D_upload_data :: proc(tex : ^Texture3D, pixel_offset : [3]i32, pixel_cnt : [3]i32, format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) {
	
	pixel_size := gl.upload_format_channel_cnt(format) * gl.upload_format_component_size(format)
	exp_size := pixel_size * auto_cast pixel_cnt.x * auto_cast pixel_cnt.y * auto_cast pixel_cnt.z;
	fmt.assertf(exp_size == len(data), "The dimensions of the uploaded data and the number of pixels does not match, expected %v bytes for %v with upload type %v, got %v", exp_size, pixel_cnt, format, len(data), loc = loc)

	gl.write_texure_data_3D(tex.id, 0, pixel_offset.x, pixel_offset.y, pixel_offset.z, pixel_cnt.x, pixel_cnt.y, pixel_cnt.z, format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_3D(tex.id);
	}
}

/////////////////////////////////// Texture 2D Atlas ///////////////////////////////////

//Refers to a quad in the atlas, there are returned from texture2D_atlas_add
Atlas_handle :: fs.Atlas_handle;

@(private="file")
Texture2D_atlas_data :: struct {
	backing : Texture2D,
	upload_format : gl.Pixel_format_upload,
	pixels : []u8, //TODO dont store pixels on the CPU, just do GPU (requires texture copy)
}

//Uses a modified strip packing, it is quite fast as it gets and the packing ratio is good for similar sized rectangles. 
//It might not work well for very large differences in quad sizes.
//Resize might not be fast.
Texture2D_atlas :: struct {
	using impl : fs.Atlas,
	using data : Texture2D_atlas_data,
}

@(require_results)
texture2D_atlas_make :: proc (upload_format : gl.Pixel_format_upload, desc : Texture_desc = {.clamp_to_edge, .linear, false, .RGBA8, {0,0,0,0}},
								#any_int margin : i32 = 0, #any_int init_size : i32 = 128, loc := #caller_location) -> (atlas : Texture2D_atlas) {
	
	assert(upload_format != nil, "upload_format may not be nil", loc);
	//TODO remove assert(gl.upload_format_channel_cnt(upload_format) == 4, "upload_format channel count must be 4", loc);
	
	data := Texture2D_atlas_data {
		backing = texture2D_make_desc(desc, init_size, init_size, upload_format, nil, label = "Texture Atlas", loc = loc),
		upload_format = upload_format,
		pixels = make([]u8, init_size * init_size * cast(i32)gl.upload_format_channel_cnt(upload_format)),
	}
	
	atlas = Texture2D_atlas{
		data = data,
		impl = fs.atlas_make(init_size, margin, loc),
	}
	
	return;
}

//Uploads a texture into the atlas and returns a handle.
//Success may return false if the GPU texture size limit is reached.
//TODO this has a "bug", where it does not add a free_quad if the row is grown. This is because we do not remember the "source/refence" of the row and column.
@(require_results)
texture2D_atlas_claim :: proc (atlas : ^Texture2D_atlas, pixel_cnt : [2]i32, data : []u8, loc := #caller_location) -> (handle : Atlas_handle, success : bool) {
	fmt.assertf(cast(i32)len(data) == cast(i32)gl.upload_format_channel_cnt(atlas.upload_format) * pixel_cnt.x * pixel_cnt.y, "upload size must match, data len : %v, but size resulted in %v", len(data), pixel_cnt.x * pixel_cnt.y * 4, loc = loc);
	quad : [4]i32;
	handle, quad, success = fs.atlas_add(&atlas.impl, pixel_cnt, loc = loc);
	
	for !success { //if we fail, we prune and try again.
		grew := texture2D_atlas_grow(atlas);
		handle, quad, success = fs.atlas_add(&atlas.impl, pixel_cnt, loc = loc);
		if !grew {
			pruned := texture2D_atlas_prune(atlas);
			handle, quad, success = fs.atlas_add(&atlas.impl, pixel_cnt, loc = loc);
			break;
		}
	}
	
	if success {
		fmt.assertf(quad.z == pixel_cnt.x, "quad width does not match pixel count: %v, %v", quad, pixel_cnt);
		fmt.assertf(quad.w == pixel_cnt.y, "quad heigth does not match pixel count: %v, %v", quad, pixel_cnt);
		
		//TODO make it not store pixels client side and just do an GPU-GPU copy.
		fs.copy_pixels(gl.upload_format_channel_cnt(atlas.upload_format), quad.z, quad.w, 0, 0, data, atlas.backing.width, atlas.backing.height, quad.x, quad.y, atlas.pixels, quad.z, quad.w);
		if data != nil {
			texture2D_upload_data(&atlas.backing, atlas.upload_format, quad.xy, quad.zw, data);
		}
	}
	
	return handle, success;
}

//Returns the texture coordinates in (0,0) -> (1,1) coordinates. 
//The coordinates until the atlas is resized or destroy.
//resized refers to texture2D_atlas_shirnk, texture2D_atlas_grow and texture2D_atlas_add.
@(require_results)
texture2D_atlas_get_coords :: proc (atlas : Texture2D_atlas, handle : Atlas_handle) -> [4]f32 {
	return fs.atlas_get_coords(atlas.impl, handle);
}

texture2D_atlas_unclaim :: proc(atlas : ^Texture2D_atlas, handle : Atlas_handle) {
	//TODO add a list of deleted quads and then try those before increasing the row widht/height.
	quad := fs.atlas_remove(&atlas.impl, handle);
	
	assert(quad.z != 0);
	assert(quad.w != 0);
	erase_data : []u8 = make([]u8, quad.z * quad.w * cast(i32)gl.upload_format_channel_cnt(atlas.upload_format));
	defer delete(erase_data);
	
	for d, i in erase_data {
		erase_data[i] = 0;
	}
	
	texture2D_upload_data(&atlas.backing, atlas.upload_format, quad.xy, quad.zw, erase_data);
}

texture2D_atlas_prune :: proc (atlas : ^Texture2D_atlas, loc := #caller_location) -> (success : bool) {
	return texture2D_atlas_transfer(atlas, atlas.impl.size);
}

//TODO, read from opengl
max_texture_size :: 10000;
max_3d_texture_size :: 10000;

//Will double the size (in each dimension) of the atlas, the old rects will be repacked in a smart way to increase the packing ratio.
//Retruns false if the GPU texture size limit is reached.
texture2D_atlas_grow :: proc (atlas : ^Texture2D_atlas, loc := #caller_location) -> (success : bool) {
	if atlas.impl.size * 2 > max_texture_size {
		return false;
	}
	return texture2D_atlas_transfer(atlas, atlas.impl.size * 2);
}

//Will try and shrink the atlas to half the size, returns true if success, returns false if it could not shrink.
//To shrink as much as possiable do "for texture2D_atlas_shirnk(atlas) {};"
texture2D_atlas_shirnk :: proc (atlas : ^Texture2D_atlas) -> (success : bool) {
	return texture2D_atlas_transfer(atlas, math.max(1, atlas.impl.size / 2));
}

texture2D_atlas_destroy :: proc (using atlas : Texture2D_atlas) {
	
	delete(atlas.pixels);	
	fs.atlas_destroy(atlas.impl);
	texture2D_destroy(atlas.backing);
}

//used internally
@(private="file")
texture2D_atlas_transfer :: proc (atlas : ^Texture2D_atlas, new_size : i32, loc := #caller_location) -> (success : bool) {
	
	new_atlas : Texture2D_atlas = texture2D_atlas_make(atlas.upload_format, atlas.backing.desc, atlas.margin, new_size);
	
	handle_map := make(map[fs.Atlas_handle][2]i32);
	defer delete(handle_map);
	for h, v in atlas.impl.handles {
		handle_map[h] = v.rect.zw;
	}
	
	rects, ok := fs.atlas_add_multi(&new_atlas, handle_map, loc = loc);
	defer delete(rects);
	
	if !ok {
		texture2D_atlas_destroy(new_atlas);
		return false;
	}
	
	used_height : i32 = 0;
	
	for h, v in atlas.impl.handles {
		assert(h in handle_map, "internal error, h is not in handle_map");
		
		src_quad := fs.atlas_get_coords(atlas, h);
		dst_quad := rects[h];
		fs.copy_pixels(gl.upload_format_channel_cnt(atlas.upload_format), atlas.size, atlas.size, src_quad.x, src_quad.y, atlas.pixels,
							new_atlas.size, new_atlas.size, dst_quad.x, dst_quad.y, new_atlas.pixels, dst_quad.z, dst_quad.w);
		
		used_height = math.max(used_height, dst_quad.y + dst_quad.w);
	}
	
	texture2D_upload_data(&new_atlas.backing, atlas.upload_format, {0,0}, {new_atlas.backing.width, used_height}, new_atlas.pixels);
	
	atlas^, new_atlas = new_atlas, atlas^;
	texture2D_atlas_destroy(new_atlas);
	
	return true;
}

/////////////////////////////////// Texture 2D Atlas Array ///////////////////////////////////
//Might do in the future

/////////////////////////////////// Texture 3D Atlas ///////////////////////////////////

Atlas_3D_handle :: distinct i32;

@(private="file")
Atlas_3D_sort :: struct  {
	size : i32,
	arr : [dynamic][3]i32,
}

//This is a dumb algorithem, use only for similar sized cubes to the power of 2, preferably exactly the same size.
//it is an implicit octree implementation
Texture3D_atlas :: struct {
	backing : Texture3D,
	upload_format : gl.Pixel_format_upload,
	next_handle : Atlas_3D_handle,
	handle_map : map[Atlas_3D_handle]struct{index : [3]i32, size : [3]i32, occupy : i32},
	
	//a sorted list of unsorted list
	free_slots : [dynamic]Atlas_3D_sort,
}

@(require_results)
texture3D_atlas_make :: proc (upload_format : gl.Pixel_format_upload, desc : Texture_desc = {.clamp_to_edge, .linear, false, .RGBA8, {0,0,0,0}}, 
								label := "", #any_int init_size : i32 = 128, loc := #caller_location) -> (atlas : Texture3D_atlas) {

	backing := texture3D_make_desc(desc, init_size, init_size, init_size, .no_upload, nil, [4]f64{0,0,0,0}, label, loc);
	
	free_slots := make([dynamic]Atlas_3D_sort)
	temp := make([dynamic][3]i32, 0, 10, loc = loc);
	append(&temp, [3]i32{0,0,0}, loc)
	append(&free_slots, Atlas_3D_sort{size = init_size, arr = temp}, loc)


	return Texture3D_atlas {
		backing,
		upload_format,
		0,
		make(map[Atlas_3D_handle]struct{index : [3]i32, size : [3]i32, occupy : i32}),
		free_slots,
	}
}

//Uploads a texture into the atlas and returns a handle.
//Success may return false if the GPU texture size limit is reached.
@(require_results)
texture3D_atlas_claim :: proc (atlas : ^Texture3D_atlas, size : [3]i32, data : []u8, loc := #caller_location) -> (handle : Atlas_3D_handle, success : bool) {
	
	h, ok := texture3D_atlas_allocate(atlas, size, loc);
	index, i_size := texture3D_atlas_get_coords_int(atlas^, h);
	assert(size == i_size)
	
	//upload it.
	if data != nil {
		texture3D_upload_data(&atlas.backing, index, size, atlas.upload_format, data, loc);
	}

	return h, ok;
}

//TODO this should be called upload and upload should be called something else.
texture3D_atlas_upload :: proc (atlas : ^Texture3D_atlas, handle : Atlas_3D_handle, index : [3]i32, size : [3]i32, data : []u8, loc := #caller_location) {
	assert(handle in atlas.handle_map, "not a valid handle", loc);

	atlas_index, i_size := texture3D_atlas_get_coords_int(atlas^, handle);
	assert(size.x <= i_size.x, "size parameter is bigger then the allocated size of the handle", loc);
	assert(size.y <= i_size.y, "size parameter is bigger then the allocated size of the handle", loc);
	assert(size.z <= i_size.z, "size parameter is bigger then the allocated size of the handle", loc);

	texture3D_upload_data(&atlas.backing, index + atlas_index, size, atlas.upload_format, data, loc);
}

//Returns the texture coordinates in (0,0,0) -> (1,1,1) coordinates. 
//The coordinates until the atlas is resized or destroy.
@(require_results)
texture3D_atlas_get_coords_float :: proc (atlas : Texture3D_atlas, handle : Atlas_3D_handle) -> (index : [3]f32, size : [3]f32) {
	i, s := texture3D_atlas_get_coords_int(atlas, handle);
	return linalg.array_cast(i, f32) / f32(atlas.backing.width), linalg.array_cast(s, f32) / f32(atlas.backing.width);
}

//Returns the texture coordinates in (0,0,0) -> (size,size,size) coordinates.  Size might be 128, 256, 512, 736 or whatever
//The coordinates until the atlas is resized or destroy.
@(require_results)
texture3D_atlas_get_coords_int :: proc (atlas : Texture3D_atlas, handle : Atlas_3D_handle, loc := #caller_location) -> (index : [3]i32, size : [3]i32) {
	assert(handle in atlas.handle_map, "handle is not registiered", loc)
	v := atlas.handle_map[handle];
	return v.index, v.size
}

//free data from the atlas
texture3D_atlas_remove :: proc (atlas : Texture3D_atlas, handle : Atlas_3D_handle) {
	panic("TODO");
}

//Will double the size (in each dimension) of the atlas, the old rects will be repacked in a smart way to increase the packing ratio.
//Retruns false if the GPU texture size limit is reached.
@(require_results)
texture3D_atlas_grow :: proc (atlas : ^Texture3D_atlas, loc := #caller_location) -> (success : bool) {
	assert(atlas.backing.desc.wrapmode != .invalid, "Cannot texture3D_atlas_grow corrupted texture desc", loc);

	if atlas.backing.width * 2 > max_3d_texture_size {
		return false;
	}

	return texture3D_atlas_transfer(atlas, atlas.backing.width * 2, loc);
}

//Will try and shrink the atlas to half the size, returns true if success, returns false if it could not shrink.
//To shrink as much as possiable do "for texture2D_atlas_shirnk(atlas) {};"
texture3D_atlas_shirnk :: proc (atlas : ^Texture3D_atlas) -> (success : bool) {
	return texture3D_atlas_transfer(atlas, math.max(1, atlas.backing.width / 2));
}

texture3D_atlas_destroy :: proc (using atlas : Texture3D_atlas) {
	texture3D_destroy(atlas.backing)
	delete(atlas.handle_map)
	for fs in atlas.free_slots {
		delete(fs.arr);
	}
	delete(atlas.free_slots);
}

//used internally
@(private="file", require_results)
texture3D_atlas_transfer :: proc (atlas : ^Texture3D_atlas, new_size : i32, loc := #caller_location) -> (success : bool) {
	
	assert(atlas.backing.desc.wrapmode != .invalid, "Hugh??? corrupted texture desc", loc);
	new_atlas := texture3D_atlas_make(atlas.upload_format, atlas.backing.desc, gl.get_label(atlas.backing.id), new_size, loc);
	
	for key, entry in atlas.handle_map {
		handle, ok := texture3D_atlas_allocate(&new_atlas, entry.size, loc);
		dst, size := texture3D_atlas_get_coords_int(new_atlas, handle);
		assert(entry.size == size)
		assert(ok);

		gl.copy_texture3D_sub_data(atlas.backing.id, new_atlas.backing.id, entry.index, dst, size);
	}
	
	new_atlas, atlas^ = atlas^, new_atlas;
	texture3D_atlas_destroy(new_atlas);

	return true;
}

//finds a free space and allocates it, used internally
@(private="file", require_results)
texture3D_atlas_allocate :: proc (atlas : ^Texture3D_atlas, size : [3]i32, loc := #caller_location) -> (Atlas_3D_handle, bool) {

	//This algorithem works with block size, and no element can be bigger then a block, so we need to redo the blocksize if we got a new element which is bigger.
	max_size := math.max(size.x, math.max(size.y, size.z));
	pow_2_max_size : i32 = 1 << cast(u32)math.ceil(math.log2(f32(max_size)));

	//find small index which can fit the cube.
	index : [3]i32 = {-1,-1,-1};
	for index == {-1,-1,-1} {
		for &fs in atlas.free_slots {
			if fs.size >= pow_2_max_size {
				index = pop(&fs.arr);
			}
			if fs.size > pow_2_max_size {
				//This is a reccursive splitting of the tree
				//add 7 others, descrease the size, if we hit the size stop, otherwise do it again.
				half_size := fs.size / 2;
				for half_size >= pow_2_max_size {

					cur_free_slots : ^Atlas_3D_sort
					//find the array with the right size
					for &fs in atlas.free_slots {
						if fs.size == half_size {
							cur_free_slots = &fs;
							break;
						}
					}
					if cur_free_slots == nil {
						
						append(&atlas.free_slots, Atlas_3D_sort{half_size, make([dynamic][3]i32)})
						
						slice.sort_by(atlas.free_slots[:], proc(i,j : Atlas_3D_sort) -> bool {
							return i.size < j.size;
						});
						
						for &fs in atlas.free_slots {
							if fs.size == half_size {
								cur_free_slots = &fs
								break;
							}
						}
					}
					assert(cur_free_slots != nil);
					assert(cur_free_slots.size == half_size);

					for x in 0..=i32(1) {
						for y in 0..=i32(1) {
							for z in 0..=i32(1) {
								v := [3]i32{x,y,z};
								if v != {0,0,0} {
									append(&cur_free_slots.arr, index + v * half_size, loc = loc)
								}
							}
						}
					}
					half_size = half_size / 2;
				}
			}
			if index != {-1,-1,-1} {
				break;
			}
		}

		if index == {-1,-1,-1} {
			//we failed finding a big enough one.
			assert(texture3D_atlas_grow(atlas)) //TODO dont assert
		}
	}

	assert(index != {-1,-1,-1})
	
	#reverse for fs, i in atlas.free_slots {
		if len(fs.arr) == 0 {
			delete(fs.arr);
			ordered_remove(&atlas.free_slots, i);
		}
	}

	//put this in the map
	atlas.next_handle += 1;
	atlas.handle_map[atlas.next_handle] = {index, size, pow_2_max_size};

	return atlas.next_handle, true;
}


/////////////////////////////////// Texture 2D multisampled ///////////////////////////////////



/////////////////////////////////// Texture arrays 2D ///////////////////////////////////



/////////////////////////////////// Texture cubemap 2D ///////////////////////////////////

Cubemap_side :: gl.Cubemap_side;

Texture_cubemap :: struct {
	id			: gl.Tex_cubemap_id,				// OpenGL texture id
	width		: i32,			   		// Texture base width of each face
	height		: i32,			   		// Texture base height of each face
	
	using desc : Texture_desc, 			//Wrapmode is ignored
}

@(require_results)
texture_cubemap_load_from_file :: proc(filename : string, desc : Texture_desc = {.clamp_to_border, .linear, true, .RGBA8, {0,0,0,0}}, loc := #caller_location) -> (tex : Texture_cubemap, ok : bool) {
	assert(desc.wrapmode == .clamp_to_border, "wrapmode must be clamp_to_border for cubemap textures", loc);

	data, load_ok := os.read_entire_file_from_filename(filename);
	defer delete(data);
	
	if !load_ok {
		log.errorf("loading texture data for %v failed", filename, location = loc);
		return {}, false;
	}

	return texture_cubemap_load_from_png_bytes(desc, data, filename, loc = loc), true;
}

//order is x->z positive->negative
//like xp, np, py, ny, zp, nz
@(require_results)
texture_cubemap_load_from_files :: proc(filenames : [6]string, desc : Texture_desc = {.clamp_to_border, .linear, true, .RGBA8, {0,0,0,0}}, multi_threaded_load := true, loc := #caller_location) -> (tex : Texture_cubemap, ok : bool) {
	assert(desc.wrapmode == .clamp_to_border, "wrapmode must be clamp_to_border for cubemap textures", loc);
	
	loc := loc;

	texture_datas : [6]struct{img : ^image.Image, err : bool};
	defer {
		for t in texture_datas {
			image.destroy(t.img);
		}
	}
	
	do_texture_image_load :: proc (filename : string, texture_datas : ^[6]struct{img : ^image.Image, err : bool}, self : int, loc : ^runtime.Source_Code_Location) {
		data, load_ok := os.read_entire_file_from_filename(filename);
		defer delete(data);
		
		if !load_ok {
			log.errorf("loading texture data for %v failed", filename, location = loc^);
			texture_datas[self].err = true;
			return;
		}
		options := image.Options{
			.alpha_add_if_missing,
		};

		img, err := png.load_from_bytes(data, options);
		if err != nil {
			log.errorf("Faild to read png data for %v, err: %v", filename, err, location = loc^);
			texture_datas[self].err = true;
			return;
		}
		texture_datas[self].img = img;
	}
	
	if multi_threaded_load {
		threads : [6]^thread.Thread;
		for filename, i in filenames {
			threads[i] = thread.create_and_start_with_poly_data4(filename, &texture_datas, i, &loc, do_texture_image_load, context);
		}
		for t in threads {
			thread.destroy(t);
		}
	}
	else {
		for filename, i in filenames {
			do_texture_image_load(filename, &texture_datas, i, &loc);
		}
	}

	size := [2]int{texture_datas[0].img.width, texture_datas[0].img.height}
	for t in texture_datas {
		if size != {t.img.width, t.img.height} {
			log.error("cubemap images must be the same size", loc);
			return {}, false;
		}
		if t.err {
			return {}, false;
		}
	}

	res := texture_cubemap_make_desc(desc, size.x, size.y, filenames[0], loc);
	
	i := 0;
	for side in reflect.enum_field_values(Cubemap_side) {
		assert(texture_datas[i].img.channels == 4)
		assert(texture_datas[i].img.which == .PNG);
		
		upload_format : gl.Pixel_format_upload;
		switch texture_datas[i].img.depth {
			case 8:
				upload_format = .RGBA8;
			case 16:
				upload_format = .RGBA16;
			case:
				panic("depth not supported");
		}
		
		texture_cubemap_upload_data(&res, auto_cast side, upload_format, {0,0}, {auto_cast size.x, auto_cast size.y}, texture_datas[i].img.pixels.buf[:], loc);
		i += 1;
	}

	return res, true;
}

//Data is compressed bytes (ex png format)
@(require_results)
texture_cubemap_load_from_png_bytes :: proc(desc : Texture_desc, data : []byte, texture_path := "", auto_convert_depth := true, flipped := true, loc := #caller_location) -> Texture_cubemap {
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
	fmt.assertf(img.height == 3 * (img.width / 4), "cubemap must have the width be 4 / 3 times the height, size was (%v, %v), expected ()", img.width, img.height, img.width, 3 * (img.width / 4))

	raw_data := bytes.buffer_to_bytes(&img.pixels); //these are owned by the image and it will be deleted at the end of call.
	
	if flipped {
		texture2D_flip(raw_data, img.width, img.height, img.channels);
	}
	
	per_side_size : i32 = auto_cast img.width / 4;
	tc := texture_cubemap_make_desc(desc, per_side_size, per_side_size, label = texture_path, loc = loc);

	extract_cubemap_data_from_combined :: proc (raw_data : []u8, per_side_size : i32, side : Cubemap_side) -> [][4]u8 {
		raw_data := slice.reinterpret([][4]u8, raw_data);

		res := make([][4]u8, per_side_size * per_side_size);

		image_width := per_side_size * 4;
		image_height := per_side_size * 3;
		fmt.assertf(auto_cast len(raw_data) == image_width * image_height, "image dimension does not match");
		
		mpos : [2]i32;

		switch side {
			case .pos_x: {
				mpos = {2,1}
			}
			case .neg_x: {
				mpos = {0,1}
			}
			case .pos_y: {
				mpos = {1,2}
			}
			case .neg_y: {
				mpos = {1,0}
			}
			case .pos_z: {
				mpos = {1,1}
			}
			case .neg_z: {
				mpos = {3,1}
			}
		}
		
		start_pos := mpos * per_side_size;

		for x in 0..<per_side_size {
			for y in 0..<per_side_size {
				xx := x + start_pos.x;
				yy := y + start_pos.y;
				res[y * per_side_size + x] = raw_data[yy * image_width + xx];
			}
		}
		
		texture2D_flip(slice.reinterpret([]u8, res), per_side_size, per_side_size, 4);

		return res;
	}

	for side in reflect.enum_field_values(Cubemap_side) {
		side := cast(Cubemap_side) side;
		data : [][4]u8 = extract_cubemap_data_from_combined(raw_data, per_side_size, side);
		defer delete(data);
		texture_cubemap_upload_data(&tc, side, .RGBA8, {0,0}, {per_side_size, per_side_size}, data, loc);
	}

	return tc
}

@(require_results)
texture_cubemap_make :: proc(mipmaps : bool, filtermode : Filtermode, internal_format : Pixel_format_internal, #any_int width, height : i32, label := "", loc := #caller_location) -> Texture_cubemap {
	
	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= .clamp_to_border,
		filtermode 		= filtermode,
		format 			= internal_format,
	};
	
	return texture_cubemap_make_desc(desc, width, height, label, loc);
}

//Clear color is only used if data is nil
@(require_results)
texture_cubemap_make_desc :: proc(using desc : Texture_desc, #any_int width, height : i32, label := "", loc := #caller_location) -> Texture_cubemap {
	assert(state.is_init, "You must init first", loc);
	assert(wrapmode != nil, "wrapmode is nil", loc);
	assert(filtermode != nil, "filtermode is nil", loc);
	assert(format != nil, "format is nil", loc);
	
	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id := gl.gen_texture_cubemap(label, loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);
	
	gl.filtermode_texture_cubemap(id, desc.filtermode, mipmaps);	
	gl.setup_texure_cubemap(id, mipmaps, width, height, format);
	gl.set_texture_border_color_cubemap(id, desc.border_color);
	
	tex : Texture_cubemap = {
		id, 
		width,
		height,
		desc,
	}

	return tex;
}

texture_cubemap_upload_data :: proc(tex : ^Texture_cubemap, side : Cubemap_side, upload_format : gl.Pixel_format_upload, pixel_offset : [2]i32, pixel_cnt : [2]i32, data : []$T, loc := #caller_location) {
	
	gl.write_texure_data_cubemap(tex.id, side, 0, pixel_offset.x, pixel_offset.y, pixel_cnt.x, pixel_cnt.y, upload_format, slice.reinterpret([]u8, data), loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_cubemap(tex.id);
	}
}

//clears all data
texture_cubemap_resize :: proc (tex : ^Texture_cubemap, new_size : [2]i32) {
	texture_cubemap_destroy(tex^);
	tex^ = texture_cubemap_make(tex.mipmaps, tex.filtermode, tex.format, new_size.x, new_size.y); //TODO pass along old label
}

//TODO should this require the pointer?
texture_cubemap_destroy :: proc(tex : Texture_cubemap, loc := #caller_location) {
	gl.delete_texture_cubemap(tex.id, loc);
}
