package render;

import "gl"
import "core:fmt"

Fbo_color_tex_desc :: struct {
	wrapmode : Wrapmode,
	filtermode : Filtermode,
	format	: Color_format,
}

Color_render_buffer :: struct {
	id 		: Rbo_id,
	format 	: Color_format,
}

Color_render_texture :: struct {
	id 			: gl.Tex2d_id,
	using desc 	: Fbo_color_tex_desc,
}

Fbo_depth_tex_desc :: struct {
	wrapmode : Wrapmode,
	filtermode : Filtermode,
}

Depth_render_buffer :: struct {
	id 		: Rbo_id,
}

Depth_render_texture :: struct {
	id 			: gl.Tex2d_id,
	using desc 	: Fbo_depth_tex_desc,
}

Color_attachement :: union {
	Color_render_buffer,
	Color_render_texture,
}

Depth_attachement :: union {
	Depth_render_buffer,
	Depth_render_texture,
}

//TODO
Stencil_attachment :: struct {
	
}

//TODO
Depth_stencil_attachment :: struct {
	
}

//Only a few color formats are valid for a FBO, see Color_format
Color_format :: enum i32 {
	RGBA8 			= cast(i32)gl.Pixel_format_internal.RGBA8,
	RGBA16_float 	= cast(i32)gl.Pixel_format_internal.RGBA16_float,
	RGBA32_float 	= cast(i32)gl.Pixel_format_internal.RGBA32_float,
	RGB8 			= cast(i32)gl.Pixel_format_internal.RGB8,
	RGB16_float 	= cast(i32)gl.Pixel_format_internal.RGB16_float,
	RGB32_float 	= cast(i32)gl.Pixel_format_internal.RGB32_float,
}

Depth_format :: enum i32 {
	depth_component16 = cast(i32)gl.Pixel_format_internal.depth_component16,
	depth_component24 = cast(i32)gl.Pixel_format_internal.depth_component24,
	depth_component32 = cast(i32)gl.Pixel_format_internal.depth_component32,
}

Frame_buffer :: struct {
	id : Fbo_id,
	
	width, height : i32,
	is_color_attachment_texture : bool,
	is_depth_attachment_texture : bool, 
	
	samples : i32,						//1 for no multisampling, >1 for multisampling
	
	color_attachments_cnt : i32,
	color_attachments : [MAX_COLOR_ATTACH]Color_attachement,
	depth_attachment : Depth_attachement,
	depth_format 	: Depth_format,
	
	//Maybe(Stencil_attachment),
	//Maybe(Depth_stencil_attachment),
}

//An attachment is created for each color format passed.
frame_buffer_make_render_buffers :: proc (color_formats : []Color_format, width, height, samples_hint : i32, depth_format : Depth_format, loc := #caller_location) -> (fbo : Frame_buffer) {
	assert(width != 0, "width is 0", loc);
	assert(height != 0, "height is 0", loc);
	
	fbo = Frame_buffer{
		id 				= gl.gen_frame_buffer(loc),
		width			= width,
		height			= height,
		is_color_attachment_texture = false,
		is_depth_attachment_texture = false,
		depth_format = depth_format,
		color_attachments_cnt = auto_cast len(color_formats),
	};
	
	assert(len(color_formats) <= len(fbo.color_attachments), "too many color attachments", loc = loc);
	
	//setup color buffers
	{
		color_attachments_max : [MAX_COLOR_ATTACH]Rbo_id;
		color_attachments := color_attachments_max[:len(color_formats)];
		
		gl.gen_render_buffers(color_attachments);
		fbo.samples = gl.associate_color_render_buffers_with_frame_buffer(fbo.id, color_attachments, width, height, samples_hint, 0); 
		
		for f, i in color_formats {
			fbo.color_attachments[i] = Color_render_buffer{color_attachments[i], f};
		}
	}
	
	//setup depth buffer
	{
		depth_buf := gl.gen_render_buffer(loc);
		depth_samples := gl.associate_depth_render_buffer_with_frame_buffer(fbo.id, depth_buf, width, height, samples_hint, auto_cast depth_format)
		assert(fbo.samples == depth_samples, "inconsistent FBO samples", loc = loc); 

		fbo.depth_attachment = Depth_render_buffer{depth_buf};
	}

	//chekc if everything is good
	assert(gl.validate_frame_buffer(fbo.id) == true, "Framebuffer is not complete!", loc);

	return;
}

//Mipmaps not allowed, copy to another texture for that.
//if depth_tex_desc is nil a render_buffer is used for the depth texture, otherwise a texture is used.
frame_buffer_make_textures :: proc (color_descs : []Fbo_color_tex_desc, width, height : i32, depth_format : Depth_format, depth_tex_desc : Maybe(Fbo_depth_tex_desc) = nil, loc := #caller_location) -> (fbo : Frame_buffer){
	
	assert(width != 0, "width is 0", loc);
	assert(height != 0, "height is 0", loc);
	
	fbo = Frame_buffer{
		id 				= gl.gen_frame_buffer(loc),
		width			= width,
		height			= height,
		is_color_attachment_texture = true,
		is_depth_attachment_texture = (depth_tex_desc != nil),
		depth_format = depth_format,
		color_attachments_cnt = auto_cast len(color_descs),
	};
	
	assert(len(color_descs) <= len(fbo.color_attachments), "too many color attachments", loc = loc);
	
	//setup color buffers
	{
		color_attachments_max : [MAX_COLOR_ATTACH]gl.Tex2d_id;
		for desc, i in color_descs {
			
			id : gl.Tex2d_id = gl.gen_texture2D(loc);
			
			{ //Setup the texture
				assert(id > 0, "Failed to create texture ID for FBO", loc);
				gl.wrapmode_texture2D(id, desc.wrapmode);
				gl.filtermode_texture2D(id, desc.filtermode, false);	
				gl.setup_texture_2D(id, false, width, height, auto_cast desc.format);
			}
			
			color_attachments_max[i] = id;
			fbo.color_attachments[i] = Color_render_texture{id, desc};
		}
		
		color_attachments := color_attachments_max[:len(color_descs)];
		fbo.samples = 1;
		gl.associate_color_texture_with_frame_buffer(fbo.id, color_attachments);
	}
	
	//setup depth buffer
	if depth_desc, ok := depth_tex_desc.?; ok {
		depth_texture := texture2D_make(false, depth_desc.wrapmode, depth_desc.filtermode, auto_cast depth_format, width, height, .no_upload, nil, loc = loc);
		fbo.depth_attachment = Depth_render_texture{depth_texture.id, depth_desc};
		gl.associate_depth_texture_with_frame_buffer(fbo.id, depth_texture.id);
	}
	else {
		depth_buf := gl.gen_render_buffer();
		depth_samples := gl.associate_depth_render_buffer_with_frame_buffer(fbo.id, depth_buf, width, height, 1, auto_cast depth_format, loc = loc)
		assert(fbo.samples == depth_samples, "inconsistent FBO samples", loc = loc);
		fbo.depth_attachment = Depth_render_buffer{depth_buf};
	}
	
	assert(gl.validate_frame_buffer(fbo.id) == true, "Framebuffer is not complete!", loc);

	return;
}

//The texture is owned by the frame_buffer object, do not delete it.
frame_buffer_color_attach_as_texture :: proc (fbo : ^Frame_buffer, #any_int attach : i32, loc := #caller_location) -> Texture2D {
	fmt.assertf(attach < fbo.color_attachments_cnt, "Attachment index out of bounds, index : %v, count : %v\n", attach, fbo.color_attachments_cnt, loc = loc);
	
	tex, ok := fbo.color_attachments[attach].(Color_render_texture);
	
	return Texture2D{
		tex.id,
		fbo.width,			   		// Texture base width
		fbo.height,			   		// Texture base heights
		{
			tex.wrapmode,
			tex.filtermode,
			false,					// Is mipmaps enabled?
			auto_cast tex.format,	// Data format (PixelFormat type)
			{0,0,0,0},
		}
	};
}

//The texture is owned by the frame_buffer object, do not delete it.
frame_buffer_depth_attach_as_texture :: proc (fbo : ^Frame_buffer) -> Texture2D {

	tex, ok := fbo.depth_attachment.(Depth_render_texture);
	
	return Texture2D{
		tex.id,
		fbo.width,			   			// Texture base width
		fbo.height,			   			// Texture base heights
		{
			tex.wrapmode,
			tex.filtermode,
			false,						// Is mipmaps enabled?
			auto_cast fbo.depth_format,	// Data format (PixelFormat type)
			{0,0,0,0},
		}
	};
}

frame_buffer_blit_color_attach_to_texture :: proc (fbo : ^Frame_buffer, #any_int attach_index : int, tex : Texture2D, linear_interpolation := true, loc := #caller_location) {
	
	assert(tex.width == fbo.width, "Width of the texture and FBO does not match", loc);
	assert(tex.height == fbo.height, "Height of the texture and FBO does not match", loc);
	
	fbo_format : Pixel_format_internal;
	
	switch v in fbo.color_attachments[attach_index] {
		case Color_render_buffer:
			fbo_format = auto_cast v.format;
		case Color_render_texture:
			fbo_format = auto_cast v.format;
	}
	
	assert(gl.internal_format_to_texture_type(fbo_format) == gl.internal_format_to_texture_type(tex.format), "Cannot blit from/to a color format to/from a depth format", loc);
	
	fbo_channels := gl.internal_format_channel_cnt(fbo_format);
	tex_channels := gl.internal_format_channel_cnt(tex.format);
	fmt.assertf(fbo_channels == tex_channels, "The FBO's color attachment and the texture does not have the same amount of channels. The FBO has %v and the texture has %v.", fbo_channels, tex_channels, loc = loc);
	
	//attach the texture to the default fbo
	gl.associate_color_texture_with_frame_buffer(state.default_copy_fbo, {tex.id});
	
	gl.blit_fbo_color_attach(fbo.id, state.default_copy_fbo, 0, 0, 0, 0, fbo.width, fbo.height, 0, 0, tex.width, tex.height, linear_interpolation);
	
	//unattach the texture from the default fbo
	gl.associate_color_texture_with_frame_buffer(state.default_copy_fbo, {0});
}

frame_buffer_blit_depth_attach_to_texture :: proc (fbo : ^Frame_buffer, tex : Texture2D) {
	
	//attach the texture to the default fbo
	gl.associate_depth_texture_with_frame_buffer(state.default_copy_fbo, tex.id);
	
	gl.blit_fbo_depth_attach(fbo.id, state.default_copy_fbo, 0, 0, fbo.width, fbo.height, 0, 0, tex.width, tex.height);
	
	//unattach the texture from the default fbo
	gl.associate_depth_texture_with_frame_buffer(state.default_copy_fbo, 0);
}

//Destroy and recreate a FBO
frame_buffer_resize :: proc (fbo : ^Frame_buffer, new_size : [2]i32, loc := #caller_location) {
	
	fbo_old := fbo^;
	
	use_depth_attachment : bool;
	
	if use_depth_attachment {
		switch atch in fbo.depth_attachment {
			case Depth_render_buffer:
				use_depth_attachment = true;
			case Depth_render_texture:
				use_depth_attachment = true;
			case:
				use_depth_attachment = false;
		}
	}
	
	if fbo.is_color_attachment_texture {
		color_descs := make([]Fbo_color_tex_desc, fbo.color_attachments_cnt);
		defer delete(color_descs);
		depth_format : Depth_format;
		depth_desc : Maybe(Fbo_depth_tex_desc);
		
		//Fill the color descs from the old fbo
		for &cd, i in color_descs {
			cd = fbo.color_attachments[i].(Color_render_texture).desc;
		}
		
		depth_format = fbo.depth_format;
		
		switch v in fbo.depth_attachment {
			case Depth_render_buffer:
				depth_desc = nil;
			case Depth_render_texture:
				depth_desc = v.desc;
		}
		
		fbo^ = frame_buffer_make_textures(color_descs, new_size.x, new_size.y, depth_format, depth_desc, loc = loc);
	}
	else {
		color_formats := make([]Color_format, fbo.color_attachments_cnt);
		defer delete(color_formats);
		
		for &cd, i in color_formats {
			cd = fbo.color_attachments[i].(Color_render_buffer).format;
		}
		
		fbo^ = frame_buffer_make_render_buffers(color_formats, new_size.x, new_size.y, fbo.samples, fbo.depth_format, loc = loc);
	}
	
	frame_buffer_destroy(fbo_old);	
}

frame_buffer_destroy :: proc(fbo : Frame_buffer) {

	for ca, i in fbo.color_attachments {
		switch &attachment in ca {
			case nil:
				//do nothing
			case Color_render_buffer:
				gl.delete_render_buffer(attachment.id);
			case Color_render_texture:
				gl.delete_texture2D(attachment.id);
		}
	}
	
	switch &attachment in fbo.depth_attachment {
		case nil:
			//do nothing
		case Depth_render_buffer:
			gl.delete_render_buffer(attachment.id);
		case Depth_render_texture:
			gl.delete_texture2D(attachment.id);
	}
	
	gl.delete_frame_buffer(fbo.id);
}

//Use for different OpenGL contexts, this will use the same render buffers/textures, but remake them for the other context.
@(private)
frame_buffer_recreate :: proc (dst : ^Frame_buffer, src : Frame_buffer, loc := #caller_location) {

	assert(dst^ == {}, "dst must be empty", loc);

	dst_id := gl.gen_frame_buffer();

	for ca,i in src.color_attachments {
		
		if ca == nil {
			//skip
		}
		else if color_buf, ok := ca.(Color_render_buffer); ok {
			assert(color_buf.id != 0, "color_buf.id is 0", loc);
			gl.associate_color_render_buffers_with_frame_buffer(dst_id, {color_buf.id}, src.width, src.height, src.samples, i, auto_cast color_buf.format, loc); 	
		}
		else {
			panic("TODO");
		}
	}
	
	if depth_buf, ok := src.depth_attachment.(Depth_render_buffer); ok {
		gl.associate_depth_render_buffer_with_frame_buffer(dst_id, depth_buf.id, src.width, src.height, src.samples, auto_cast src.depth_format, loc);
	}
	else {
		panic("TODO");
	}
	
	dst^ = Frame_buffer {
		dst_id,
		src.width,
		src.height,
		false,
		false, 
		src.samples,
		src.color_attachments_cnt,
		src.color_attachments,
		src.depth_attachment,
		src.depth_format,
	}
	
	assert(gl.validate_frame_buffer(dst.id) == true, "Framebuffer is not complete!", loc);

	return;
}
