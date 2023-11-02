package render;

import "core:fmt"
import "core:mem"

/*
Draw_buffer_entry :: struct {
	mesh : Mesh,
	transforms : matrix[4, 4]f32,
	//Uniforms
}

update_draw_buffer :: proc(draw_buffer : ^Draw_buffer) {

	if len(entires) != len(arrays_buffer) + len(elements_buffer) {
		setup_draw_buffer(draw_buffer);
	}
}

draw_mesh :: proc (shader : Shader, draw_buffer : Draw_buffer) {
	
	//TODO Conditional rendering 
	//	glBeginConditionalRender(GLuint id​, GLenum mode​);
	//  glEndConditionalRender();

	/*
	if opengl_version >= .opengl_4_3 {

		commands := make([dynamic]gl.DrawElementsIndirectCommand, alloc = context.temp_allocator);

		for mesh in meshs {
			//TODO check frustum

			draw_command : gl.DrawArraysIndirectCommand = {
				count 			= 0,
				instanceCount 	= ,
				first 			= 0,
				baseInstance 	= 0,
			}

			append(&commands, mesh);
		}

		if mesh.indices != nil {
			gl.MultiDrawElementsIndirect(mode: u32, type: u32, indirect: [^]DrawElementsIndirectCommand, drawcount: i32, stride: i32);
		} else {
			gl.MultiDrawArraysIndirect(mode: u32, indirect: [^]DrawArraysIndirectCommand, drawcount: i32, stride: i32);
		}
	}
	*/

}
*/