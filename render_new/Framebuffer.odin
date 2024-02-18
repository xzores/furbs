package render;

import "gl"

Color_render_attachement :: struct {
	id : Rbo_id,
}

Depth_render_attachement :: struct {
	id : Rbo_id,
}

Color_attachement :: union {
	Color_render_attachement,
}

Depth_attachement :: union {
	Depth_render_attachement,
}

Stencil_attachment :: union {

}

Depth_stencil_attachment :: union {

}

Frame_buffer :: struct {
	id : Fbo_id,
	 
	width, height : i32,
	samples : i32,
	color_format : gl.Color_format,
	depth_format : gl.Depth_format,

	color_attachments : [MAX_COLOR_ATTACH]Color_attachement,
	depth_attachment : Depth_attachement,
	
	//Maybe(Stencil_attachment),
	//Maybe(Depth_stencil_attachment),
}

make_frame_buffer :: proc (color_attachemet_cnt, width, height, samples_hint : i32, use_render_buffers : bool, color_format : gl.Color_format, depth_format : gl.Depth_format, loc := #caller_location) -> Frame_buffer {

	fbo : Frame_buffer = {
		id 				= gl.gen_frame_buffer(),
		width			= width,
		height			= height,
		color_format	= color_format,
		depth_format	= depth_format,
	};
	
	assert(color_attachemet_cnt <= len(fbo.color_attachments), "too many color attachments", loc = loc);
	
	if use_render_buffers {
		//setup color buffers
		color_attachments_max : [MAX_COLOR_ATTACH]Rbo_id;
		color_attachments := color_attachments_max[:color_attachemet_cnt];

		gl.gen_render_buffers(color_attachments);

		fbo.samples = gl.associate_color_render_buffers_with_frame_buffer(fbo.id, color_attachments, width, height, samples_hint, 0, color_format, loc); 

		for ca,i  in color_attachments {
			fbo.color_attachments[i] = Color_render_attachement{ca};
		}

		depth_buf := gl.gen_render_buffer();
		depth_samples := gl.associate_depth_render_buffer_with_frame_buffer(fbo.id, depth_buf, width, height, samples_hint, depth_format, loc)
		assert(fbo.samples == depth_samples, "inconsistent FBO samples", loc = loc); 

		fbo.depth_attachment = Depth_render_attachement{depth_buf};
	}
	else {
		panic("TODO");
	}

	assert(gl.validate_frame_buffer(fbo.id) == true, "Framebuffer is not complete!", loc);

	return fbo;
}

destroy_frame_buffer :: proc(fbo : Frame_buffer) {

	for ca, i in fbo.color_attachments {
		if ca == nil {
			//do nothing
		}
		else if attachment, ok := ca.(Color_render_attachement); ok {
			gl.delete_render_buffer(attachment.id);
		}
		else {
			panic("TODO");
		}
	}

	if fbo.depth_attachment == nil {
		//do nothing
	}
	else if attachment, ok := fbo.depth_attachment.(Depth_render_attachement); ok {
		gl.delete_render_buffer(attachment.id);
	}
	else {
		panic("TODO");
	}

	gl.delete_frame_buffer(fbo.id);
}

//Use for different OpenGL contexts, this will use the same render buffer, but remake them for the other context.
@(private)
recreate_frame_buffer :: proc (dst : ^Frame_buffer, src : Frame_buffer, loc := #caller_location) {

	assert(dst^ == {}, "dst must be empty", loc);

	dst_id := gl.gen_frame_buffer();

	for ca,i in src.color_attachments {
		
		if ca == nil {
			//skip
		}
		else if color_buf, ok := ca.(Color_render_attachement); ok {
			assert(color_buf.id != 0, "color_buf.id is 0", loc);
			gl.associate_color_render_buffers_with_frame_buffer(dst_id, {color_buf.id}, src.width, src.height, src.samples, i, src.color_format, loc); 	
		}
		else {
			panic("TODO");
		}
	}

	if depth_buf, ok := src.depth_attachment.(Depth_render_attachement); ok {
		gl.associate_depth_render_buffer_with_frame_buffer(dst_id, depth_buf.id, src.width, src.height, src.samples, src.depth_format, loc);
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

