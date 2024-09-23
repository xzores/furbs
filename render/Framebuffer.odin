package render;

import "gl"
import "core:fmt"

Color_render_buffer :: struct {
	id 		: Rbo_id,
	width	: i32,			   		// Texture base width
	height	: i32,			   		// Texture base height
	samples : i32,
	format 	: Color_format,
}

Depth_render_buffer :: struct {
	id 		: Rbo_id,
	width	: i32,			   		// Texture base width
	height	: i32,			   		// Texture base height
	samples : i32,
	format 	: Depth_format,
}

Color_attachement :: union {
	Color_render_buffer,
	Texture2D,
	//Texture2D_multisampled,
}

Depth_attachement :: union {
	Depth_render_buffer,
	Texture2D,
	//Texture2D_multisampled,
}

Stencil_attachment :: union {

}

Depth_stencil_attachment :: union {

}

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
	samples : i32,					//1 for no multisampling, >1 for multisampling
	color_format : Color_format,	//Only a few color formats are valid for a FBO, see Color_format
	depth_format : Depth_format,

	color_attachments : [MAX_COLOR_ATTACH]Color_attachement,
	depth_attachment : Depth_attachement,
	
	//Maybe(Stencil_attachment),
	//Maybe(Depth_stencil_attachment),
}

frame_buffer_make_render_buffers :: proc (#any_int color_attachemet_cnt, width, height, samples_hint : i32, color_format : Color_format, depth_format : Depth_format, loc := #caller_location) -> (fbo : Frame_buffer) {
	assert(width != 0, "width is 0", loc);
	assert(height != 0, "height is 0", loc);
	assert(color_format != nil, "color_format is nil", loc);
	assert(depth_format != nil, "depth_format is nil", loc);

	fbo = Frame_buffer{
		id 				= gl.gen_frame_buffer(),
		width			= width,
		height			= height,
		color_format	= color_format,
		depth_format	= depth_format,
	};
	
	assert(color_attachemet_cnt <= len(fbo.color_attachments), "too many color attachments", loc = loc);
	
	//setup color buffers
	{
		color_attachments_max : [MAX_COLOR_ATTACH]Rbo_id;
		color_attachments := color_attachments_max[:color_attachemet_cnt];

		gl.gen_render_buffers(color_attachments);

		fbo.samples = gl.associate_color_render_buffers_with_frame_buffer(fbo.id, color_attachments, width, height, samples_hint, 0, auto_cast color_format); 
		
		for ca,i  in color_attachments {
			fbo.color_attachments[i] = Color_render_buffer{ca, width, height, fbo.samples, color_format};
		}
	}

	//setup depth buffer
	{
		depth_buf := gl.gen_render_buffer();
		depth_samples := gl.associate_depth_render_buffer_with_frame_buffer(fbo.id, depth_buf, width, height, samples_hint, auto_cast depth_format)
		assert(fbo.samples == depth_samples, "inconsistent FBO samples", loc = loc); 

		fbo.depth_attachment = Depth_render_buffer{depth_buf, width, height, depth_samples, depth_format};
	}

	//chekc if everything is good
	assert(gl.validate_frame_buffer(fbo.id) == true, "Framebuffer is not complete!", loc);

	return;
}

//if textures is not nil, textures will be filled with the texture attachments.
frame_buffer_make_textures :: proc (#any_int color_attachemet_cnt, width, height : i32, color_format : Color_format, depth_format : Depth_format,
														 mipmaps : bool, filtermode : gl.Filtermode, use_depth_texture := true, wrapmode : Wrapmode = .clamp_to_border, loc := #caller_location) -> (fbo : Frame_buffer){
	
	assert(width != 0, "width is 0", loc);
	assert(height != 0, "height is 0", loc);
	assert(color_format != nil, "color_format is nil", loc);
	assert(depth_format != nil, "depth_format is nil", loc);

	fbo = Frame_buffer{
		id 				= gl.gen_frame_buffer(loc),
		width			= width,
		height			= height,
		color_format	= color_format,
		depth_format	= depth_format,
	};
	
	assert(color_attachemet_cnt <= len(fbo.color_attachments), "too many color attachments", loc = loc);
	
	//setup color buffers
	{
		color_attachments_max : [MAX_COLOR_ATTACH]gl.Tex2d_id;
		for i in 0 ..<color_attachemet_cnt {
			color_texture := texture2D_make(mipmaps, wrapmode, filtermode, auto_cast color_format, width, height, .no_upload, nil, loc = loc);
			color_attachments_max[i] = color_texture.id;
			fbo.color_attachments[i] = color_texture;
		}

		color_attachments := color_attachments_max[:color_attachemet_cnt];
		fbo.samples = 1;
		gl.associate_color_texture_with_frame_buffer(fbo.id, color_attachments);
	}

	//setup depth buffer
	if use_depth_texture {
		depth_texture := texture2D_make(mipmaps, wrapmode, filtermode, auto_cast depth_format, width, height, .no_upload, nil, loc = loc);
		fbo.depth_attachment = depth_texture;
		gl.associate_depth_texture_with_frame_buffer(fbo.id, depth_texture.id);
	}
	else {
		depth_buf := gl.gen_render_buffer();
		depth_samples := gl.associate_depth_render_buffer_with_frame_buffer(fbo.id, depth_buf, width, height, 1, auto_cast depth_format, loc = loc)
		assert(fbo.samples == depth_samples, "inconsistent FBO samples", loc = loc);
		fbo.depth_attachment = Depth_render_buffer{depth_buf, width, height, depth_samples, depth_format};
	}
	
	assert(gl.validate_frame_buffer(fbo.id) == true, "Framebuffer is not complete!", loc);

	return;
}

frame_resize_buffer :: proc (fbo : ^Frame_buffer, new_size : [2]i32, loc := #caller_location) {
	
	frame_buffer_destroy(fbo^);
	
	use_depth_texture : bool;
	
	if use_depth_texture {
		switch atch in fbo.depth_attachment {
			case Depth_render_buffer:
				use_depth_texture = true;
			case Texture2D:
				use_depth_texture = true;
			case:
				use_depth_texture = false;
		}
	}
	
	if texture, use_textures := fbo.color_attachments[0].(Texture2D); use_textures {
		fbo^ = frame_buffer_make_textures(1, new_size.x, new_size.y, fbo.color_format, fbo.depth_format, texture.mipmaps, texture.filtermode, use_depth_texture, texture.wrapmode, loc = loc);
	}
	else {
		fbo^ = frame_buffer_make_render_buffers(1, new_size.x, new_size.y, fbo.samples, fbo.color_format, fbo.depth_format, loc = loc);
	}
}

frame_buffer_destroy :: proc(fbo : Frame_buffer) {

	for ca, i in fbo.color_attachments {
		switch &attachment in ca {
			case nil:
				//do nothing
			case Color_render_buffer:
				gl.delete_render_buffer(attachment.id);
			case Texture2D:
				texture2D_destroy(attachment);
		}
	}

	switch &attachment in fbo.depth_attachment {
		case nil:
			//do nothing
		case Depth_render_buffer:
			gl.delete_render_buffer(attachment.id);
		case Texture2D:
			texture2D_destroy(attachment);
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
			gl.associate_color_render_buffers_with_frame_buffer(dst_id, {color_buf.id}, src.width, src.height, src.samples, i, auto_cast src.color_format, loc); 	
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
		id = dst_id,
		width = src.width,
		height = src.height,
		samples = src.samples,
		color_format  = src.color_format,
		depth_format = src.depth_format,
		color_attachments = src.color_attachments,
		depth_attachment = src.depth_attachment,
	}

	assert(gl.validate_frame_buffer(dst.id) == true, "Framebuffer is not complete!", loc);

	return;
}

