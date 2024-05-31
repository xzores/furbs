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
import "core:math"
import "core:time"

import "core:image"
import "core:image/png"

import "gl"

import "../utils"

Pixel_format_internal 	:: gl.Pixel_format_internal;
Wrapmode 				:: gl.Wrapmode;
Filtermode 				:: gl.Filtermode;

Texture_desc :: struct {
	wrapmode : Wrapmode,
	filtermode : Filtermode,
	mipmaps : bool,						// Is mipmaps enabled?
	format	: Pixel_format_internal,	// Data format (PixelFormat type)
}

/////////////////////////////////// Texture 1D ///////////////////////////////////
Texture1D :: struct {
	id			: gl.Tex1d_id,            	// OpenGL texture id
	width		: i32,               		// Texture base width

	using desc : Texture_desc,
}

@(require_results)
texture1D_make :: proc(mipmaps : bool, wrapmode : Wrapmode, filtermode : Filtermode, internal_format : Pixel_format_internal,
							 width : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture1D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};

	return texture1D_make_desc(desc, width, upload_format, data, loc);
}

@(require_results)
texture1D_make_desc :: proc(using desc : Texture_desc, width : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture1D {

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex1d_id = gl.gen_texture1D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture1D(id, desc.wrapmode);
	gl.filtermode_texture1D(id, desc.filtermode, mipmaps);

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

texture1D_destroy :: proc(tex : ^Texture1D) {
	gl.delete_texture1D(tex.id);
	tex^ = {};
}

texture1D_upload_data :: proc(tex : ^Texture1D, #any_int pixel_offset : i32, #any_int pixel_cnt : i32, format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) {
	
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
texture2D_load_from_file :: proc(filename : string, desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8}, loc := #caller_location) -> Texture2D {
	
	data, ok := os.read_entire_file_from_filename(filename);
	defer delete(data);

	fmt.assertf(ok, "loading texture data for %v failed", filename, loc = loc);

    return texture2D_load_from_png_bytes(desc, data, filename, loc = loc);
}

//Load many textures threaded, good for many of the same types of textures.
//nil is returned if we failed to load. Allocator must be multithread safe if keep_allocator is true.
@(require_results)
texture2D_load_multi_from_file :: proc(paths : []string, desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8}, flipped := true, keep_allocator := false, loc := #caller_location) -> (textures : []Maybe(Texture2D)) {
	
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
			textures[i] = texture2D_make_desc(desc, info.img.width, info.img.height, .RGBA8, raw_data, loc);
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

	return texture2D_make_desc(desc, img.width, img.height, .RGBA8, raw_data, loc);
}

@(require_results)
texture2D_make :: proc(mipmaps : bool, wrapmode : Wrapmode, filtermode : Filtermode, internal_format : Pixel_format_internal,
							#any_int width, height : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture2D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};

	return texture2D_make_desc(desc, width, height, upload_format, data, loc);
}

@(require_results)
texture2D_make_desc :: proc(using desc : Texture_desc, #any_int width, height : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture2D {

	/*
	assert(wrapmode != nil, "wrapmode is nil", loc);
	assert(filtermode != nil, "filtermode is nil", loc);
	assert(format != nil, "format is nil", loc);
	*/
	
	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex2d_id = gl.gen_texture2D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture2D(id, desc.wrapmode);
	gl.filtermode_texture2D(id, desc.filtermode, mipmaps);

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

texture2D_upload_data :: proc(tex : ^Texture2D, upload_format : gl.Pixel_format_upload, pixel_offset : [2]i32, pixel_cnt : [2]i32, data : []$T, loc := #caller_location) {
	
	gl.write_texure_data_2D(tex.id, 0, pixel_offset.x, pixel_offset.y, pixel_cnt.x, pixel_cnt.y, upload_format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_2D(tex.id);
	}
}

//TODO should this require the pointer?
texture2D_destroy :: proc(tex : Texture2D) {
	gl.delete_texture2D(tex.id);
}

texture2D_flip :: proc(data : []byte, width, height, channels : int) {
	
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
		};

		state.white_texture = texture2D_make_desc(desc, 1, 1, .RGBA8, {255, 255, 255, 255});
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
		};

		state.black_texture = texture2D_make_desc(desc, 1, 1, .RGBA8, {0, 0, 0, 255});
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
texture3D_make :: proc(mipmaps : bool, wrapmode : Wrapmode, filtermode : Filtermode, internal_format : Pixel_format_internal,
							 width, height, depth : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture3D {

	desc : Texture_desc = {
		mipmaps 		= mipmaps,
		wrapmode 		= wrapmode,
		filtermode 		= filtermode,
		format 			= internal_format,
	};

	return texture3D_make_desc(desc, width, height, depth, upload_format, data, loc);
}

@(require_results)
texture3D_make_desc :: proc(using desc : Texture_desc, width, height, depth : i32, upload_format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) -> Texture3D {

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO

	id : gl.Tex3d_id = gl.gen_texture3D(loc);
	assert(id > 0, "TEXTURE: Failed to load texture", loc);

    gl.wrapmode_texture3D(id, desc.wrapmode);
	gl.filtermode_texture3D(id, desc.filtermode, mipmaps);
	
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

texture3D_destroy :: proc(tex : ^Texture3D) {
	gl.delete_texture3D(tex.id);
	tex^ = {};
}

texture3D_upload_data :: proc(tex : ^Texture3D, pixel_offset : [3]i32, pixel_cnt : [3]i32, format : gl.Pixel_format_upload, data : []u8, loc := #caller_location) {
	
	gl.write_texure_data_3D(tex.id, 0, pixel_offset.x, pixel_offset.y, pixel_offset.z, pixel_cnt.x, pixel_cnt.y, pixel_cnt.z, format, data, loc);
	
	if (tex.mipmaps) {
		gl.generate_mip_maps_3D(tex.id);
	}
}

/////////////////////////////////// Texture 2D Atlas ///////////////////////////////////

//Refers to a quad in the atlas, there are returned from texture2D_atlas_upload
Atlas_handle :: distinct i32;

//internal use
Altas_row :: struct {
	heigth : i32,
	width : i32,
	y_offset : i32,
	quads : [dynamic]Atlas_handle, //quads owned by this row.
}

//Uses a modified strip packing, it is quite fast as it gets and the packing ratio is good for similar sized rectangles. 
//It might not work well for very large differences in quad sizes.
//Resize might not be fast.
Texture2D_atlas :: struct {
	backing : Texture2D,
	upload_format : gl.Pixel_format_upload,
	
	atlas_handle_counter : Atlas_handle,
	margin : i32,

	rows : [dynamic]Altas_row,
	quads : map[Atlas_handle][4]i32, //from handle to index
	free_quads : map[Atlas_handle][4]i32,
	
	pixels : []u8, //TODO dont store pixels on the CPU, just do GPU (requires texture copy)
}

texture2D_atlas_make :: proc (upload_format : gl.Pixel_format_upload, desc : Texture_desc = {.clamp_to_edge, .linear, true, .RGBA8},
								#any_int margin : i32 = 0, #any_int init_size : i32 = 128, loc := #caller_location) -> (atlas : Texture2D_atlas) {
	
	assert(upload_format != nil, "upload_format may not be nil", loc);
	//TODO remove assert(gl.upload_format_channel_cnt(upload_format) == 4, "upload_format channel count must be 4", loc);

	atlas = {
		backing = texture2D_make_desc(desc, init_size, init_size, upload_format, nil, loc),
		rows = make([dynamic]Altas_row),
		quads = make(map[Atlas_handle][4]i32),
		free_quads = make(map[Atlas_handle][4]i32),
		margin = margin,
		atlas_handle_counter = 0,
		upload_format = upload_format,
		pixels = make([]u8, init_size * init_size * cast(i32)gl.upload_format_channel_cnt(upload_format)),
	}

	return;
}

//internal use
/*@(require_results, private="file")
atlas_get_free_quad :: proc (atlas : ^Texture2D_atlas, #any_int width, height : i32) -> (placement : [4]i32, found : bool) {
	
	//find a free quad that fits
	//ordered_remove(&atlas.free_quads, );

	return;
}

@(require_results, private="file")
atlas_sort :: proc (a, b : [4]i32) -> slice.Ordering {

	if a.w == b.w {
		return .Equal;
	}
	if a.w < b.w {
		return .Less;
	}

	return .Greater;
}
*/

//Uploads a texture into the atlas and returns a handle.
//Success may return false if the GPU texture size limit is reached.
//TODO this has a "bug", where it does not add a free_quad if the row is grown. This is because we do not remember the "source/refence" of the row and column.
@(require_results)
texture2D_atlas_upload :: proc (using atlas : ^Texture2D_atlas, pixel_cnt : [2]i32, data : []u8, loc := #caller_location) -> (handle : Atlas_handle, success : bool) {
	fmt.assertf(cast(i32)len(data) == cast(i32)gl.upload_format_channel_cnt(upload_format) * pixel_cnt.x * pixel_cnt.y, "upload size must match, data len : %v, but size resulted in %v", len(data), pixel_cnt.x * pixel_cnt.y * 4, loc = loc);

	tex_size := pixel_cnt + 2 * [2]i32{atlas.margin, atlas.margin};

	//If the texture is not big enough, then we double and try again.
	if tex_size.x > atlas.backing.width || tex_size.x > atlas.backing.width {
		growed := texture2D_atlas_grow(atlas);
		if !growed {
			return -1, false;
		}
		return texture2D_atlas_upload(atlas, tex_size, data, loc);
	}
	//At this point the texture is big enough, but there might still not be space because if the other rects.
	
	//We will check if an unused placement is sutiable, and if it is we will use that first.
	{
		found_area : i32 = max(i32);
		handle : Atlas_handle = -1;

		for k, q in free_quads {
			if q.z >= tex_size.x && q.w >= tex_size.y {
				if (q.z * q.w) <= found_area {
					handle = k;
					found_area = q.z * q.w;
				}
			}
		}
		if handle != -1 {
			//We found a unused quad, now we make a handle for it and return that.
			quad := free_quads[handle];
			quad.zw = pixel_cnt;

			quads[handle] = quad; //Create the quad reference

			//remove the quad from free quads, as it is now not free
			delete_key(&free_quads, handle);

			//Upload/copy data into texture
			texture2D_upload_data(&backing, atlas.upload_format, quad.xy, quad.zw, data, loc);
			utils.copy_pixels(gl.upload_format_channel_cnt(upload_format), pixel_cnt.x, pixel_cnt.y, 0, 0, data, atlas.backing.width, atlas.backing.height, quad.x, quad.y, atlas.pixels, pixel_cnt.x, pixel_cnt.y);
			
			return handle, true; //We have already found a good solution!
		}
	}

	//Followingly we will find the row with the lowest (height) that can accomedate the texture.
	min_row_index : int = -1;
	min_row_heigth : i32 = max(i32);

	//linear search though all rows.
	for r, i in rows {

		if r.heigth >= tex_size.y && r.heigth < min_row_heigth {
			//there is enough vertical space, but is there enough horizontal space

			if atlas.backing.width - r.width >= tex_size.x {
				//There is enough space and we can use this row.
				min_row_index = i;
				min_row_heigth = r.heigth;
			}
		}
	}
	
	//If there is no rows add an empty row. This will make sure not to go out of bounds in the next step.
	if len(rows) == 0 {
		append(&rows, Altas_row{0, 0, 0, make([dynamic]Atlas_handle)});
	}
	
	if min_row_index == -1 {
		
		//We did not find a row, check if we can grow the last row, if not grow texture.
		row := rows[len(rows)-1];
		
		if backing.height - row.y_offset >= tex_size.y {
			
			//We can grow the last row!
			
			//Now We want to check if we have enough horizontal space if we grow the last row.
			if backing.width - row.width >= tex_size.x {
				//The row will now grow

				//Go back and increase secoundary heigth
				for h in row.quads {
					if h in atlas.free_quads {
						//if there is a free quad then we will make it bigger, if it also shared the top.
						q := atlas.free_quads[h];

						if q.y + q.w == row.y_offset + row.heigth {
							q.w += (tex_size.y - row.heigth);
							atlas.free_quads[h] = q; //There is a bug, this does not always work? dunno why
						}
					}
				}

				//there is enough horizontal space and so we grow!
				row.heigth = tex_size.y;
				min_row_index = len(rows)-1;
				min_row_heigth = row.heigth;
			}
			else {
				//There was not enough horizontal space, try to make a new row.
				append(&rows, Altas_row{0, 0, row.y_offset + row.heigth, make([dynamic]Atlas_handle)});
				return texture2D_atlas_upload(atlas, tex_size, data, loc);
			}
		}
	}

	if min_row_index == -1 {
		//No placement has been found and the texture must be grown and we try again.
		growed := texture2D_atlas_grow(atlas);
		if !growed {
			return -1, false;
		}
		return texture2D_atlas_upload(atlas, tex_size, data, loc);
	}
	else {
		//A placement was found.

		pixels_offset : [2]i32 = {rows[min_row_index].width + margin, rows[min_row_index].y_offset + margin};

		quad := [4]i32{
			rows[min_row_index].width + margin,		//X_pos
			rows[min_row_index].y_offset + margin,	//Y_pos
			pixel_cnt.x, 							//Width (x_size)
			pixel_cnt.y								//Heigth (y_size)
		};
		quad2 := [4]i32{
			quad.x,									//X is the same
			quad.y + quad.w,						//the quad is place on top
			quad.z,									//The width is the same
			rows[min_row_index].heigth - quad.w		//The heigth is what is left
		};
		
		rows[min_row_index].heigth = math.max(rows[min_row_index].heigth, tex_size.y); //increase the row heigth to this quads hight, if it is bigger.
		rows[min_row_index].width += tex_size.x; //incease the width by the size of the sub-texture.
		
		atlas_handle_counter += 1;
		res := atlas_handle_counter;
		quads[res] = quad; //Create the quad 1 reference
		append(&rows[min_row_index].quads, res);

		//If there is space left then we create a secoundary handle, but at the top.
		//This handle is inactive and not in use, so it is added to "free_quads".
		if rows[min_row_index].heigth - quad.w != 0 {
			assert(rows[min_row_index].heigth - quad.w > 0, "internal error");

			atlas_handle_counter += 1;
			sec_res := atlas_handle_counter;
			atlas.free_quads[sec_res] = quad2;
			append(&rows[min_row_index].quads, sec_res);
		}

		//fmt.printf("new_column : %v\n", new_column);
		texture2D_upload_data(&backing, atlas.upload_format, quad.xy, quad.zw, data, loc);
		utils.copy_pixels(gl.upload_format_channel_cnt(upload_format), pixel_cnt.x, pixel_cnt.y, 0, 0, data, atlas.backing.width,
								atlas.backing.height, pixels_offset.x, pixels_offset.y, atlas.pixels, pixel_cnt.x, pixel_cnt.y);
		
		return res, true;
	}

	unreachable();
}

//Returns the texture coordinates in (0,0) -> (1,1) coordinates. 
//The coordinates until the atlas is resized or destroy.
//resized refers to texture2D_atlas_shirnk, texture2D_atlas_grow and texture2D_atlas_upload.
@(require_results)
texture2D_atlas_get_coords :: proc (atlas : Texture2D_atlas, handle : Atlas_handle) -> [4]i32 {
	return atlas.quads[handle] / atlas.backing.width;
}

texture2D_atlas_remove :: proc(atlas : Texture2D_atlas, handle : Atlas_handle) {
	
	//TODO add a list of deleted quads and then try those before increasing the row widht/height.
	panic("todo");
}

//Will double the size (in each dimension) of the atlas, the old rects will be repacked in a smart way to increase the packing ratio.
//Retruns false if the GPU texture size limit is reached.
texture2D_atlas_grow :: proc (atlas : ^Texture2D_atlas, loc := #caller_location) -> (success : bool) {

	max_texture_size :: 10000;

	//fmt.printf("Growing to new size : %v, %v\n", atlas.backing.width * 2, atlas.backing.width * 2);

	//Check if there is space on the GPU.
	if atlas.backing.width * 2 > max_texture_size {
		return false;
	}

	//Sort the old data, so we know the best order to add them in (this would be heighest to lowest)
	Handle :: struct {
		handle : Atlas_handle,
		width, heigth : i32,
	}
	
	//Used to sort the array
	sort_proc :: proc (a : Handle, b : Handle) -> bool {
		return a.heigth < b.heigth;
	}

	//Make a slice of handles
	handles := make([]Handle, len(atlas.quads));
	defer delete(handles);
	
	i : int = 0;

	//Now we add the values that needs to be sorted.
	for k, quad in atlas.quads {

		handles[i] = Handle{
			k,
			quad.z,
			quad.w,
		}

		i += 1;
	}

	//The sort, it sorts from heighest to lowest quad height.
	slice.reverse_sort_by(handles, sort_proc);
	
	//Make a new teature atlas
	new_atlas := texture2D_atlas_make(atlas.upload_format, atlas.backing.desc, atlas.margin, atlas.backing.width * 2, loc);
	
	current_row := 0;
	current_y_offset : i32 = 0;
	current_x_offset : i32 = 0;
	row_heigth : i32 = 0;

	if len(new_atlas.rows) == 0 {

		h : i32 = 0;
		
		if len(handles) != 0 {
			h = handles[0].heigth;
		}

		append(&new_atlas.rows, Altas_row{
			heigth = h,
			width = 0,
			y_offset = 0,
		});
	}

	//Now add the old quads to the new atlas in the right order.
	for h in handles {

		quad := atlas.quads[h.handle];
		q := quad.zw + (2 * [2]i32{atlas.margin, atlas.margin});
		
		//Because we sort from heigst to lowest, we can just append to each row.
		//when the end of the row is reached, we make a new row. There will always be space enough.

		row := &new_atlas.rows[current_row];
		
		if row.width + q.x > new_atlas.backing.width {
			//There is not enough space to place the quad on the same row, so we move forward.
			
			//Create a new row
			current_row += 1;
			current_y_offset += row.heigth;
			current_x_offset = 0;
			row_heigth = q.y;
			append(&new_atlas.rows, Altas_row{
				heigth = q.y,
				width = 0,
				y_offset = current_y_offset,
				quads = make([dynamic]Atlas_handle),
			});
			row = &new_atlas.rows[current_row];	//the move
		}

		//The row width is increased
		row.width += q.x;

		//The handle is added to the new atlas
		new_atlas.atlas_handle_counter += 1;
		new_atlas.quads[new_atlas.atlas_handle_counter] = [4]i32{
			current_x_offset,
			current_y_offset,
			q.x,
			q.y,
		};
		append(&row.quads, new_atlas.atlas_handle_counter);

		//There might be space for another quad.
		if row_heigth - q.y > 0 {
			//An empty quad is added on top
			new_atlas.atlas_handle_counter += 1;
			new_atlas.free_quads[new_atlas.atlas_handle_counter] = [4]i32{
				current_x_offset,
				current_y_offset + q.y,
				q.x,
				row_heigth - q.y,
			};
			append(&row.quads, new_atlas.atlas_handle_counter);
		}

		
		src_offset := quad.xy;
		
		utils.copy_pixels(gl.upload_format_channel_cnt(atlas.upload_format), atlas.backing.width, atlas.backing.height, src_offset.x, src_offset.y, atlas.pixels,
												new_atlas.backing.width, new_atlas.backing.height, current_x_offset, current_y_offset, new_atlas.pixels, q.x, q.y);		

		current_x_offset += q.x
	}
	
	//Swap the old and new atlas's
	atlas^, new_atlas = new_atlas, atlas^;
	
	//Destroy the old atlas
	texture2D_atlas_destroy(new_atlas);

	//Upload the initial data.
	texture2D_upload_data(&atlas.backing, atlas.upload_format, {0,0}, {atlas.backing.width, current_y_offset + atlas.rows[current_row].heigth}, atlas.pixels, loc);

	return true;
}

//Will try and shrink the atlas to half the size, returns true if success, returns false if it could not shrink.
//To shrink as much as possiable do "for texture2D_atlas_shirnk(atlas) {};"
texture2D_atlas_shirnk :: proc (atlas : ^Texture2D_atlas) -> (success : bool) {

	

	return false;
}

texture2D_atlas_destroy :: proc (using atlas : Texture2D_atlas) {

	delete(pixels);

	texture2D_destroy(atlas.backing);
	for r in rows {
		delete(r.quads);
	}
	delete(rows);
	delete(quads);
	delete(free_quads);
} 

/////////////////////////////////// Texture 2D Atlas Array ///////////////////////////////////

//Might do in the future

/////////////////////////////////// Texture 3D Atlas ///////////////////////////////////



/////////////////////////////////// Texture 2D multisampled ///////////////////////////////////



/////////////////////////////////// Texture arrays 2D ///////////////////////////////////



/////////////////////////////////// Texture cubemap 2D ///////////////////////////////////
//TODO use glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS)

