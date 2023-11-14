package render;

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:strconv"
import "core:runtime"

import "vendor:glfw"
import gl "vendor:OpenGL"

import "../utils"

load_vertex_buffer :: proc(data : rawptr, #any_int size : int, dyn : bool) -> Vbo_id {
	using gl;

 	id : Vbo_id = 0;

	GenBuffers(1, auto_cast &id);
	vertex_buffers_alive[id] = true;

	enable_vertex_buffer(id);
	BufferData(ARRAY_BUFFER, size, data, dyn ? DYNAMIC_DRAW : STATIC_DRAW);
	
	//flags : u32 = MAP_WRITE_BIT; // | MAP_PERSISTENT_BIT | MAP_COHERENT_BIT;
	//gl.BufferStorage(ARRAY_BUFFER, size, data, flags);
	//res := gl.MapBuffer(gl.ARRAY_BUFFER, gl.WRITE_ONLY);
	//mem.copy(res, data, size);
	//gl.UnmapBuffer(gl.ARRAY_BUFFER);
	
	disable_vertex_buffer(id);

    return id;
}

upload_vertex_sub_buffer_data :: proc(vbo : Vbo_id, offset : int, size : int, data : rawptr) {
	enable_vertex_buffer(vbo);
	gl.BufferSubData(gl.ARRAY_BUFFER, offset, size, data);
	disable_vertex_buffer(vbo);
}

unload_vertex_buffer :: proc (vbo_id : Vbo_id, loc := #caller_location) { 	
	vbo_id := vbo_id;
	assert(vbo_id in vertex_buffers_alive, "Vbo is not created", loc = loc);
	vertex_buffers_alive[vbo_id] = false;
	gl.DeleteBuffers(1, auto_cast &vbo_id);
}

enable_vertex_buffer :: proc(id : Vbo_id, loc := #caller_location) {
	assert(id in vertex_buffers_alive, "Vbo is not created", loc = loc)
	assert(vertex_buffers_alive[id] == true, "Vbo is deleted", loc = loc)
	assert(vertex_buffer_targets[.array_buffer] == 0, "Another vbo is already bound", loc = loc);
	vertex_buffer_targets[.array_buffer] = id

	gl.BindBuffer(gl.ARRAY_BUFFER, auto_cast id);
}

disable_vertex_buffer :: proc(id : Vbo_id, loc := #caller_location) {
	assert(id in vertex_buffers_alive, "Vbo is not created")
	assert(vertex_buffers_alive[id] == true, "Vbo is deleted")
	assert(vertex_buffer_targets[.array_buffer] == id, "The vbo that is trying to be disabled is not enabled", loc = loc);
	vertex_buffer_targets[.array_buffer] = 0;

	gl.BindBuffer(gl.ARRAY_BUFFER, 0);
}
/////////////////////

//VBO element
load_vertex_array :: proc(loc := #caller_location) -> Vao_id {
	using gl;

    vao_id : Vao_id = 0;
    gl.GenVertexArrays(1, auto_cast &vao_id);

	array_buffers_alive[vao_id] = {is_alive = true};
    return vao_id;
}

unload_vertex_array :: proc(vao_id : Vao_id, loc := #caller_location) {

	vao_id := vao_id;

	array_buffers_alive[vao_id] = {};
    gl.DeleteVertexArrays(1, auto_cast &vao_id);
}

enable_vertex_array :: proc(id : Vao_id, loc := #caller_location) {
	when ODIN_DEBUG {
		assert(id in array_buffers_alive, "Vao is not created", loc = loc);
		assert(array_buffers_alive[id].is_alive == true, "Vao is deleted", loc = loc);
		assert(bound_array_buffer == 0, "Another vao is already bound", loc = loc);
	}
	
	if bound_array_buffer == id {
		return;
	}
	
	bound_array_buffer = id;
    gl.BindVertexArray(auto_cast id);
}

disable_vertex_array :: proc(id : Vao_id, loc := #caller_location) {
	when ODIN_DEBUG {
		assert(id in array_buffers_alive, "Vao is not created", loc = loc);
		assert(array_buffers_alive[id].is_alive == true, "Vao is deleted", loc = loc);
		assert(bound_array_buffer == id, "Vao is not bound", loc = loc);

		bound_array_buffer = 0;
		gl.BindVertexArray(0);
	}
}

// Enable vertex attribute index
setup_vertex_attribute :: proc(vao : Vao_id, vbo : Vbo_id, components : i32, type : Attribute_data_type, index : Attribute_client_index, loc := #caller_location) {
	//TODO this should take all the information and do in one swop,
	//use vertex_buffers_alive 
	//enable_vertex_attribute :: proc(vao : Vao_id, vbo : Vbo_id, index : u32)
	//array_buffers_alive.vertex_attrib_enabled[id] = true;

	assert(vbo in vertex_buffers_alive, "Vbo is not created")
	assert(vertex_buffers_alive[vbo] == true, "Vbo is deleted")
	assert(vertex_buffer_targets[.array_buffer] == 0, "Another vbo is already bound", loc = loc);
	
	assert(vao in array_buffers_alive, "Vao is not created", loc = loc);
	assert(array_buffers_alive[vao].is_alive == true, "Vao is deleted", loc = loc);
	assert(bound_array_buffer == 0, "Another vao is already bound", loc = loc);

	fmt.assertf(array_buffers_alive[vao].vertex_attrib_enabled[index] == false, "The attribute location is already bound, at : %v", index, loc = loc);

	gl.BindVertexArray(auto_cast vao);

	gl.EnableVertexAttribArray(auto_cast index);
	gl.BindBuffer(gl.ARRAY_BUFFER, auto_cast vbo);
	
	gl.VertexAttribPointer(auto_cast index, components, auto_cast type, false, 0, 0); //TODO make pointer allways nil? or 0? should we ever use it?

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
	gl.BindVertexArray(0);

	(&(array_buffers_alive[vao])).vertex_attrib_enabled[index] = true;
}

/*
// Enable vertex attribute index
disable_vertex_attribute :: proc(index : u32) {
	//TODO disable_vertex_attribute :: proc(vao : Vao_id, vbo : Vbo_id, index : u32)
	//gl.DisableVertexAttribArray(index);
	gl.DisableVertexAttribArray(auto_cast index);
}
*/

/////////////////////


load_program :: proc() -> Shader_program_id {
	id : Shader_program_id = auto_cast gl.CreateProgram();
	shader_program_alive[id] = true;
	return id;
}

load_vertex_shader :: proc() -> Shader_vertex_id {
	id : Shader_vertex_id = auto_cast gl.CreateShader(gl.VERTEX_SHADER);
	shader_vertex_alive[id] = true;
	return id;
}

load_fragment_shader :: proc() -> Shader_fragment_id {
	id : Shader_fragment_id = auto_cast gl.CreateShader(gl.FRAGMENT_SHADER);
	shader_fragment_alive[id] = true;
	return id;
}

unload_vertex_shader :: proc(shader_id : Shader_vertex_id){
	shader_vertex_alive[shader_id] = false;
	gl.DeleteShader(auto_cast shader_id);
}

unload_fragment_shader :: proc(shader_id : Shader_fragment_id){
	shader_fragment_alive[shader_id] = false;
	gl.DeleteShader(auto_cast shader_id);
}

unload_program :: proc(shader_id : Shader_program_id) {
	shader_program_alive[shader_id] = false;
	gl.DeleteProgram(auto_cast shader_id);
}

// Enable shader program
enable_shader :: proc(id : Shader_program_id, loc := #caller_location) {
	assert(bound_shader_program == 0, "A shader program is already bound", loc);
	bound_shader_program = id;
	gl.UseProgram(auto_cast id);
}

// Disable shader program
disable_shader :: proc(id : Shader_program_id, loc := #caller_location) {
	assert(bound_shader_program != 0, "A shader program is not bound", loc);
	assert(bound_shader_program == id, "A shader program is not bound", loc);
	bound_shader_program = 0;
	gl.UseProgram(0);
}

/////////////////////

load_frame_buffer :: proc(width : i32, height : i32) -> Frame_buffer_id {

	//TODO glTexImage2DMultisample, somehow...
	
    fbo_id : Frame_buffer_id = 0;
    gl.GenFramebuffers(1, auto_cast &fbo_id);       	// Create the framebuffer object
    disable_frame_buffer(0);   					// Unbind any framebuffer
	frame_buffer_alive[fbo_id] = true;
    return fbo_id;
}

unload_frame_buffer :: proc(fbo_id : Frame_buffer_id) {
	fbo_id := fbo_id;
	frame_buffer_alive[fbo_id] = false;
    gl.DeleteFramebuffers(1, auto_cast &fbo_id);
}

enable_frame_buffer :: proc(id : Frame_buffer_id, loc := #caller_location) {
	assert(bound_frame_buffer_id == 0, "A frame buffer is already bound", loc = loc);
	gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast id);
	bound_frame_buffer_id = id;

	//Check if it is bound
	bound_fbo : i32;
	gl.GetIntegerv(gl.FRAMEBUFFER_BINDING, &bound_fbo);
	assert(bound_fbo == auto_cast id, "FBO did not bind");
}

disable_frame_buffer :: proc(fbo_id : Frame_buffer_id, loc := #caller_location) {
	fmt.assertf(fbo_id == bound_frame_buffer_id, "enable_frame_buffer and disable_frame_buffer was not called on the same frame_buffer, bound_frame_buffer_id : %v, fbo_id : %v", bound_frame_buffer_id, fbo_id, loc = loc);
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
	bound_frame_buffer_id = 0;
}

enable_frame_buffer_read :: proc(id : Frame_buffer_id, loc := #caller_location) {
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, auto_cast id);
	bound_read_frame_buffer_id = id;
}

disable_frame_buffer_read :: proc(fbo_id : Frame_buffer_id, loc := #caller_location) {
	assert(fbo_id == bound_read_frame_buffer_id, "enable_frame_buffer_read and disable_frame_buffer_read was not called on the same frame_buffer", loc = loc);
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0);
	bound_read_frame_buffer_id = 0;
}

enable_frame_buffer_draw :: proc(id : Frame_buffer_id, loc := #caller_location) {
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, auto_cast id);
	bound_write_frame_buffer_id = id;
}

disable_frame_buffer_draw :: proc(fbo_id : Frame_buffer_id, loc := #caller_location) {
	assert(fbo_id == bound_write_frame_buffer_id, "enable_frame_buffer_write and disable_frame_buffer_write was not called on the same frame_buffer", loc = loc);
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
	bound_write_frame_buffer_id = 0;
}

draw_buffers :: proc (fbo_id : Frame_buffer_id, loc := #caller_location) {
	drawbuf : []i32 = {gl.COLOR_ATTACHMENT0};
    gl.DrawBuffers(auto_cast len(drawbuf), auto_cast &drawbuf);
}


////////

load_depth_texture_id :: proc(width : i32, height : i32, use_render_buffer : bool, bit_depth : Depth_format) -> Texture_id {
	
	id : Texture_id;

	gl.GenTextures(1, auto_cast &id);
	gl.BindTexture(gl.TEXTURE_2D, auto_cast id);

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	
	gl.TexImage2D(gl.TEXTURE_2D, 0, auto_cast bit_depth, width, height, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, nil);
	gl.GenerateMipmap(gl.TEXTURE_2D);

	gl.BindTexture(gl.TEXTURE_2D, 0);

	textures_alive[id] = true;

	return id;
}

load_depth_render_buffer_id :: proc(width : i32, height : i32, use_render_buffer : bool, bit_depth : Depth_format) -> Render_buffer_id {
	
	id : Render_buffer_id;

	gl.GenRenderbuffers(1, auto_cast &id);
	gl.BindRenderbuffer(gl.RENDERBUFFER, auto_cast id);
	gl.RenderbufferStorage(gl.RENDERBUFFER, auto_cast bit_depth, width, height);

	gl.BindRenderbuffer(gl.RENDERBUFFER, 0);

	render_buffer_alive[id] = true;

	return id;
}

unload_render_buffer_id :: proc(depth_id : Render_buffer_id) {
	depth_id := depth_id;
	render_buffer_alive[depth_id] = false;
	gl.DeleteRenderbuffers(1, auto_cast &depth_id)
}

load_texture_id :: proc(data : []u8, width : i32, height : i32, format : Pixel_format, loc := #caller_location) -> Texture_id {
    
    //TODO assert bound_texture2D == nil

	//gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1); //TODO deleted?

	id : Texture_id = 0;

    gl.GenTextures(1, auto_cast &id);              						// Generate texture id
    gl.BindTexture(gl.TEXTURE_2D, auto_cast id);

	//TODO options for different things:
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);       // Set texture to repeat on x-axis
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);       // Set texture to repeat on y-axis

    // Magnification and minification filters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);  // Alternative: GL_LINEAR
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);  // Alternative: GL_LINEAR

	gl_unsized_name, channels := format_info(format);

	if len(data) == 0 {
		assert(raw_data(data) == nil, "Texture data is 0 len, but is not nil", loc);
		gl.TexImage2D(gl.TEXTURE_2D, 0, auto_cast format, width, height, 0, gl_unsized_name, gl.UNSIGNED_BYTE, nil);
	}
	else {
		length := int(width * height * channels);
		fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
		gl.TexImage2D(gl.TEXTURE_2D, 0, auto_cast format, width, height, 0, gl_unsized_name, gl.UNSIGNED_BYTE, raw_data(data)); //TODO internal format,
		//TODO upload format.
	}

	gl.GenerateMipmap(gl.TEXTURE_2D); //TODO make it so that we can upload our own mipmaps? no? right we donø't need to?

    // Unbind current texture
    gl.BindTexture(gl.TEXTURE_2D, 0);

    if (id > 0) {
		//fmt.printf("Loaded texture id\n");
    }
	else {
		panic("TEXTURE: Failed to load texture");
	}

	textures_alive[id] = true;

    return id;
}

unload_texture_id :: proc(tex_id : Texture_id) {
	tex_id := tex_id;
	textures_alive[tex_id] = false;
	gl.DeleteTextures(1, auto_cast &tex_id);
}

generate_mip_maps :: proc(tex : Texture2D) {
	gl.BindTexture(gl.TEXTURE_2D, auto_cast tex.id);
	gl.GenerateMipmap(gl.TEXTURE_2D);
	gl.BindTexture(gl.TEXTURE_2D, 0);
}

/*
reload_texture_data :: proc(data : []u8, width : i32, height : i32, format : Pixel_format) {

	//TODO assert bound_texture2D == nil

	gl.BindTexture(gl.TEXTURE_2D, auto_cast id);

	//TODO stuff like gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);       // Set texture to repeat on x-axis

	length := int(width * height * 4);
	fmt.assertf(len(data) == length, "Data is not in the correct format, len is %i, while it should have been %i", len(data), length, loc = loc);
	gl.TexImage2D(gl.TEXTURE_2D, 0, auto_cast format, width, height, 0, unsized_eqvilent_format(format), gl.UNSIGNED_BYTE, raw_data(data));

	gl.GenerateMipmap(gl.TEXTURE_2D);
	
	gl.BindTexture(gl.TEXTURE_2D, 0);
}
*/

/////////////////////

// Enable vertex buffer element (VBO element)
enable_vertex_buffer_element :: proc(id : Vbo_id, loc := #caller_location) {
	assert(bound_element_buffer == 0, "There is already a bound element buffer", loc = loc);
	bound_element_buffer = id;
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, auto_cast id);
}
// Disable vertex buffer element (VBO element)
disable_vertex_buffer_element :: proc(id : Vbo_id, loc := #caller_location) {
	assert(bound_element_buffer == id, "The element buffer your are trying to unbind is not bound", loc = loc);
	bound_element_buffer = 0;
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
}

/*
bind_texture_id :: proc(id : Texture_id) {

}

unbind_texture_id :: proc() {

	
}
*/

/////////////////////////////////////////////////////////

enable_depth_test :: proc() {
	//TODO check it is disabled
	gl.Enable(gl.DEPTH_TEST);
}

disable_depth_test :: proc() {
	//TODO check it is enabled
	gl.Disable(gl.DEPTH_TEST);
}

clear_color_depth :: proc(clear_color : [4]f32) {
	gl.ClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

//////////////////////////////

/*
// Set shader value attribute
set_vertex_attribute_default :: proc(locIndex : u32, value : rawptr, attribType : Shader_attribute_data_type, count : int) {
	//TODO remove this function
	switch attribType {

        case .float:
			if (count == 1) { gl.VertexAttrib1fv(locIndex, cast(^f32)value) };

        case .vector2:
			if (count == 2) { gl.VertexAttrib2fv(locIndex, cast(^[2]f32)value) };

        case .vector3:
			if (count == 3) { gl.VertexAttrib3fv(locIndex, cast(^[3]f32)value) };

        case .vector4:
			if (count == 4) { gl.VertexAttrib4fv(locIndex, cast(^[4]f32)value) };

        case: 
			panic("SHADER: Failed to set attrib default value, data type not recognized");
    }
}
*/

/*
// Set vertex attribute divisor
set_vertex_attribute_divisor :: proc(index : u32, divisor : u32) {
    gl.VertexAttribDivisor(index, divisor);
}
*/

//////////////////////////////

// Draw vertex array
draw_vertex_array :: proc(offset : i32, count : i32, loc := #caller_location) {
	//assert(offset < count, "Offset is greater or equal to count", loc = loc);
	assert(count != 0, "Count is zero", loc = loc);
	assert(count % 3 == 0, "Count is not a multiable of 3", loc = loc);
	assert(bound_array_buffer != 0, "No array buffer is bound", loc = loc);
	
	found_attrib : bool = false;
	for b in array_buffers_alive[bound_array_buffer].vertex_attrib_enabled {
		if b {
			found_attrib = true;
			break;
		}
	}

	if !found_attrib {
		panic("The currently bound VAO has no atributes bound", loc = loc);
	}
	
    gl.DrawArrays(gl.TRIANGLES, offset, count);
}

draw_vertex_array_indirect :: proc (offset : i32, count : i32, loc := #caller_location) {
	assert(offset < count, "Offset is greater or equal to count", loc = loc);
	assert(count != 0, "Count is zero", loc = loc);
	assert(count % 3 == 0, "Count is not a multiable of 3", loc = loc);

	/*
	buf : gl.DrawArraysIndirectCommand = {
		count 		= number_of_verts,
		primCount 	= number_of_instances,
		first 		= 0, //always begin from 0
		baseInstance = ??,
	}
	
    gl.MultiDrawArraysIndirect(gl.TRIANGLES, raw_data(indirect_buffer), len(indirect_buffer), 0);

		fillBuffers();
		glDispatchIndirect();
		glMemoryBarrier(GL_COMMAND_BARRIER_BIT /*|GL_SHADER_STORAGE_BARRIER_BIT*/);
		glBindBuffer(GL_DRAW_INDIRECT_BUFFER, indirectBuffer);
		glBindVertexArray(vao);
		glMultiDraw*Indirect();
	*/

	panic("unimplemented");
}

// Draw vertex array elements
draw_vertex_array_elements :: proc(count : i32, loc := #caller_location) {
	assert(bound_element_buffer != 0, "There is not a bound element buffer", loc = loc);
    gl.DrawElements(gl.TRIANGLES, count, gl.UNSIGNED_SHORT, nil);
}

// Draw vertex array instanced
draw_vertex_array_instanced :: proc(offset : i32, count : i32, instances : i32) {
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, count, instances);
}

// Draw vertex array elements instanced
draw_vertex_array_elements_instanced :: proc(count : i32, instances : i32, loc := #caller_location) {
	assert(bound_element_buffer != 0, "There is not a bound element buffer", loc = loc);
    gl.DrawElementsInstanced(gl.TRIANGLES, count, gl.UNSIGNED_SHORT, nil, instances);
}

//////////////////////////////

//TODO GL_MAX_DRAW_BUFFERS

get_max_supported_attributes :: proc() -> i32 {
	supported_attributes : i32;
	gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &supported_attributes);

	return supported_attributes;
}

get_max_supported_active_textures :: proc() -> i32 {
	texture_units : i32;
	gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &texture_units);
	return texture_units;
}

get_max_supported_texture_resolution_2D :: proc() -> i32 {
	//GL_MAX_TEXTURE_SIZE
	texture_resolution : i32;
	gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &texture_resolution);
	return texture_resolution;
}

get_gl_version :: proc() -> GL_version {
	
	v := gl.GetString(gl.VERSION); //TODO: This does not need to be deleted i think?
	version := fmt.tprintf("%v", v);

	Major : int = strconv.atoi(version[0:1]);
	Minor : int = strconv.atoi(version[2:3]);
	
	fmt.printf("OPENGL version : %v\n", v);

	if Major < 3 {
		panic("A higher version of opengl is required");
	}
	
	if Major == 3 && Minor == 0 {
		return .opengl_3_0;
	}
	else if Major == 3 && Minor == 1 {
		return .opengl_3_1;
	}
	else if Major == 3 && Minor == 2 {
		return .opengl_3_2;
	}
	else if Major == 3 && Minor == 3 {
		return .opengl_3_3;
	}
	else if Major == 3 {
		return .opengl_3_3; //if 3.4 or 3.5 releases at some point.
	}
	
	if Major == 4 && Minor == 0 {
		return .opengl_4_0;
	}
	else if Major == 4 && Minor == 1 {
		return .opengl_4_1;
	}
	else if Major == 4 && Minor == 2 {
		return .opengl_4_2;
	}
	else if Major == 4 && Minor == 3 {
		return .opengl_4_3;
	}
	else if Major == 4 && Minor == 4 {
		return .opengl_4_4;
	}
	else if Major == 4 && Minor == 5 {
		return .opengl_4_5;
	}
	else if Major == 4 && Minor == 6 {
		return .opengl_4_6;
	}
	else if  Major == 4 {
		return .opengl_4_6; //if 4.7 or 4.8 releases at some point.
	}

	if Major > 4 {
		return .opengl_4_6;
	}

	unreachable();
}

get_shader_attributes :: proc(program_id : Shader_program_id, alloc := context.allocator, loc := #caller_location) -> (res : map[string]Attribute_info) {
	
	context.allocator = alloc;

	count : i32;
	max_length : i32;
	gl.GetProgramiv(auto_cast program_id, gl.ACTIVE_ATTRIBUTES, &count);
	gl.GetProgramiv(auto_cast program_id, gl.ACTIVE_ATTRIBUTE_MAX_LENGTH, &max_length);

	res = make(map[string]Attribute_info);

	for i in 0..<count {
		
		name_buf : []u8 = make([]u8, max_length + 2);
		defer delete(name_buf);

		name_len : i32;
		size : i32; // size of the variable
		
		shader_type : Attribute_type;

		gl.GetActiveAttrib(auto_cast program_id, auto_cast i, auto_cast len(name_buf), &name_len, &size, auto_cast &shader_type, cast([^]u8)raw_data(name_buf));
		assert(size == 1, "size is not 1, I have missunderstood something...");

		name : string = strings.clone_from_bytes(name_buf[:name_len]);
		fmt.assertf(utils.is_enum_valid(shader_type), "uniform %s is not a supported type. OpenGL type : %v", name, cast(gl.GL_Enum)shader_type, loc = loc);
		res[name] = Attribute_info{location = get_attribute_location(program_id, name), attrib_type = auto_cast shader_type};
	}

	return;
}

get_shader_uniforms :: proc(program_id : Shader_program_id, alloc := context.allocator, loc := #caller_location) -> (res : map[string]Uniform_info) {

	context.allocator = alloc;

	count : i32;
	max_length : i32;
	gl.GetProgramiv(auto_cast program_id, gl.ACTIVE_UNIFORMS, &count);
	gl.GetProgramiv(auto_cast program_id, gl.ACTIVE_UNIFORM_MAX_LENGTH, &max_length);

	res = make(map[string]Uniform_info);
	
	for i in 0..<count {

		name_buf : []u8 = make([]u8, max_length + 2);
		defer delete(name_buf);

		name_len : i32;
		size : i32; // size of the variable
		shader_type : Uniform_type;

		gl.GetActiveUniform(auto_cast program_id, auto_cast i, auto_cast len(name_buf), &name_len, &size, auto_cast &shader_type, cast([^]u8)raw_data(name_buf));

		name : string = strings.clone_from_bytes(name_buf[:name_len]);

		if strings.has_suffix(name, "[0]") {
			assert(size != 1, "It is an array with size 1?, so it is an array?");
			
			//strip [0]
			delete(name);
			name = strings.clone_from_bytes(name_buf[:name_len-3]);
		}
		else {
			assert(size == 1, "It is not an array?, but the size is not 1?");
		}

		fmt.assertf(utils.is_enum_valid(shader_type), "uniform %s is not a supported type. OpenGL type : %v", name, cast(gl.GL_Enum)shader_type, loc = loc);
		res[name] = Uniform_info{location = get_uniform_location(program_id, name), uniform_type = auto_cast shader_type, array_size = size};
	}

	return;
}

//////////////////////////////

get_attribute_location :: proc(shader_id : Shader_program_id, attrib_name : string) -> Attribute_id {
	return auto_cast gl.GetAttribLocation(auto_cast shader_id, fmt.ctprintf(attrib_name));
}

get_uniform_location :: proc(shader_id : Shader_program_id, uniform_name : string) -> Uniform_id {
	return auto_cast gl.GetUniformLocation(auto_cast shader_id, fmt.ctprintf(uniform_name));
}

/////////////

set_uniform_array :: proc(using uniform : Uniform_info, value : $T, loc := #caller_location) {
	
	assert(array_size != 0, "array_size is 0, you are doing something wrong", loc = loc);
	
	when T == []f32 {
		fmt.assertf(uniform_type == .float, "Value passed was float, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform1fv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == [][2]f32 {
		fmt.assertf(uniform_type == .vec2, "Value passed was float_vec2, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform2fv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == [][3]f32 {
		fmt.assertf(uniform_type == .vec3, "Value passed was float_vec3, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform3fv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == [][4]f32 {
		fmt.assertf(uniform_type == .vec4, "Value passed was float_vec4, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform4fv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == []i32 {
		fmt.assertf(uniform_type == .int, "Value passed was int32, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform1iv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == [][2]i32 {
		fmt.assertf(uniform_type == .ivec2, "Value passed was int32_vec2, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform2iv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == [][3]i32 {
		fmt.assertf(uniform_type == .ivec3, "Value passed was int32_vec3, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform3iv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == [][4]i32 {
		fmt.assertf(uniform_type == .ivec4, "Value passed was int32_vec4, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		gl.Uniform4iv(auto_cast location, auto_cast len(value), &value[0][0]);
	}
	else when T == []matrix[4,4]f32 {
		fmt.assertf(uniform_type == .mat4, "Value passed was mat4, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		assert(array_size == auto_cast len(value), "GLSL array length does not match the passed arguments", loc = loc);
		value : matrix[4,4]f32 = value;
		gl.UniformMatrix4fv(auto_cast location, auto_cast len(value), false, &value[0][0]);
	}
	else {
		fmt.panicf("Unsupported uniform array type %v", type_info_of(T), loc = loc);
	}
}

// Set shader value uniform
set_uniform_single :: proc(using uniform : Uniform_info, value : $T, loc := #caller_location) {

	when T == f32 {
		fmt.assertf(uniform_type == .float, "Value passed was float, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform1f(auto_cast location, value);
	}
	else when T == [2]f32 {
		fmt.assertf(uniform_type == .vec2, "Value passed was float_vec2, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform2f(auto_cast location, value.x, value.y);
	}
	else when T == [3]f32 {
		fmt.assertf(uniform_type == .vec3, "Value passed was float_vec3, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform3f(auto_cast location, value.x, value.y, value.z);
	}
	else when T == [4]f32 {
		fmt.assertf(uniform_type == .vec4, "Value passed was float_vec4, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform4f(auto_cast location, value.x, value.y, value.z, value.w);
	}
	else when T == i32 {
		fmt.assertf(uniform_type == .int, "Value passed was int32, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform1i(auto_cast location, value);
	}
	else when T == [2]i32 {
		fmt.assertf(uniform_type == .ivec2, "Value passed was int32_vec2, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform2i(auto_cast location, value.x, value.y);
	}
	else when T == [3]i32 {
		fmt.assertf(uniform_type == .ivec3, "Value passed was int32_vec3, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform3i(auto_cast location, value.x, value.y, value.z);
	}
	else when T == [4]i32 {
		fmt.assertf(uniform_type == .ivec4, "Value passed was int32_vec4, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		gl.Uniform4i(auto_cast location, value.x, value.y, value.z, value.w);
	}
	else when T == matrix[4,4]f32 {
		fmt.assertf(uniform_type == .mat4, "Value passed was mat4, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		value : matrix[4,4]f32 = value;
		gl.UniformMatrix4fv(auto_cast location, 1, false, cast([^]f32) &value[0][0]);
	}
	else {
		fmt.panicf("Unsupported uniform type %v, is it defined as an array in GLSL?", type_info_of(T), loc = loc);
	}
}

set_uniform_sampler :: proc(using uniform : Uniform_info, slot : Texture_slot, value : $T, loc := #caller_location) {
	
	when T == Texture2D {
		fmt.assertf(uniform_type == .sampler_2d, "Value passed was sampler_2d, but shader uniform type differs as it is type %v", uniform_type, loc = loc);
		
		assert(cast(int)slot < 32);
		assert(cast(int)slot < len(texture_locations));

		gl.ActiveTexture(gl.TEXTURE0 + cast(u32)slot);
		gl.BindTexture(gl.TEXTURE_2D, auto_cast value.id);
		gl.Uniform1i(auto_cast location, cast(i32)slot); //TODO set activeTextureSlot
	}
	else {
		fmt.panicf("Unsupported texture uniform type %v", type_info_of(T), loc = loc);
	}

}

/*
// Set shader value uniform sampler
void rlSetUniformSampler(int locIndex, unsigned int textureId)
{
#if defined(GRAPHICS_API_OPENGL_33) || defined(GRAPHICS_API_OPENGL_ES2)
    // Check if texture is already active

    for (int i = 0; i < RL_DEFAULT_BATCH_MAX_TEXTURE_UNITS; i++) if (RLGL.State.activeTextureId[i] == textureId) return;

    // Register a new active texture for the internal batch system
    // NOTE: Default texture is always activated as GL_TEXTURE0
    for (int i = 0; i < RL_DEFAULT_BATCH_MAX_TEXTURE_UNITS; i++)
    {
        if (RLGL.State.activeTextureId[i] == 0)
        {
            gl.Uniform1i(locIndex, 1 + i);              // Activate new texture unit
            RLGL.State.activeTextureId[i] = textureId; // Save texture id for binding on drawing
            break;
        }
    }
#endif
}
*/

//////////////////////////////

compile_shader :: proc(destination : ^map[string]$T, name, source : string, $shader_type : Shader_type, loc := #caller_location) {

	source_vertex_shader :: proc(shader_id : Shader_vertex_id, shader_source : string, loc := #caller_location) {
		shader_sources : [1]cstring = { fmt.ctprintf("%s",shader_source) };
		gl.ShaderSource(auto_cast shader_id, 1, auto_cast &shader_sources, nil);
	}

	source_fragment_shader :: proc(shader_id : Shader_fragment_id, shader_source : string, loc := #caller_location) {
		shader_sources : [1]cstring = { fmt.ctprintf("%s",shader_source) };
		gl.ShaderSource(auto_cast shader_id, 1, auto_cast &shader_sources, nil);
	}

	_compile_shader :: proc (shader_id : $TT, shader_name : string, loc := #caller_location) {
		gl.CompileShader(auto_cast shader_id);

		success : i32;
		gl.GetShaderiv(auto_cast shader_id, gl.COMPILE_STATUS, &success);

		if success == 0 {
			err_info : [1024]u8;
			gl.GetShaderInfoLog(auto_cast shader_id, 1024, nil, auto_cast &err_info);

			when T == Shader_vertex_id {
				extension := "vs";
			}
			else when T == Shader_fragment_id {
				extension := "fs";
			}

			fmt.panicf("shader complication failed for shader : %s.%v of type %v\n Error : %s\n", shader_name, extension, type_info_of(TT), strings.clone_from_bytes(err_info[:]), loc = loc);
		}
	}

	shader_id : T;

	when shader_type == .vertex_shader {
		assert(T == Shader_vertex_id, "Are you compiling a vertex or fragment shader?", loc = loc);
		shader_id = load_vertex_shader();
		source_vertex_shader(shader_id, source);
		_compile_shader(shader_id, name, loc);
	}
	else when shader_type == .fragment_shader {
		assert(T == Shader_fragment_id, "Are you compiling a vertex or fragment shader?", loc = loc);
		shader_id = load_fragment_shader();
		source_fragment_shader(shader_id, source);
		_compile_shader(shader_id, name, loc);
	}
	else {
		unreachable();
	}

	destination[name] = shader_id;
}

attach_vertex_shader :: proc(shader_program : Shader_program_id, vertex_shader : Shader_vertex_id) {
	gl.AttachShader(auto_cast shader_program, auto_cast vertex_shader);
}

attach_fragment_shader :: proc(shader_program : Shader_program_id, fragment_shader : Shader_fragment_id) {
	gl.AttachShader(auto_cast shader_program, auto_cast fragment_shader);
}

link_program :: proc(shader_program : Shader_program_id, vs_name : string, fs_name : string, loc := #caller_location) {
	gl.LinkProgram(auto_cast shader_program);

	success : i32;
	gl.GetProgramiv(auto_cast shader_program, gl.LINK_STATUS, &success);
	if success == 0 {
		err_info : [1024]u8;
		gl.GetProgramInfoLog(auto_cast shader_program, 1024, nil, auto_cast &err_info);
		fmt.panicf("shader linking failed for shader : %s.vs / %s.fs\n loc : %v\n Error : %s\n", vs_name, fs_name, loc, strings.clone_from_bytes(err_info[:]));
	}
}

/////////////////////////////////////////////////////////////////////////////////

set_viewport :: proc(x : i32, y : i32, width : i32, height : i32) {
	assert(gl.Viewport != nil, "gl.Viewport not loaded")
    gl.Viewport(x, y, width, height);
}

enable_transparency :: proc(use : bool) {
	if use {
		gl.Enable(gl.BLEND);
		gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
	}
	else {
		gl.Disable(gl.BLEND);
	}
}

/////////////////////////////////////////////////////////////////////////////////

blit_frame_buffer :: proc(width, height : i32, loc := #caller_location) {
	gl.BlitFramebuffer(0, 0, width, height, 0, 0, width, height, gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT, gl.NEAREST);
}

attach_framebuffer_color :: proc(fbo_id : Frame_buffer_id, tex_id : Texture_id, use_render_buffer : bool) {
	
	gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast fbo_id);

	if use_render_buffer {
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, auto_cast tex_id); //TODO allow more attachment places.
	}
	else {
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, auto_cast tex_id, 1);  //TODO allow more attachment places.
	}

	//TODO cube maps FramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + attachType, GL_TEXTURE_CUBE_MAP_POSITIVE_X + texType, texId, mipLevel);
}

attach_framebuffer_depth :: proc(fbo_id : Frame_buffer_id, depth_attach_id : Depth_attachment) {

	gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast fbo_id);

	if ren_id, ok := depth_attach_id.(Render_buffer_id); ok {
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, auto_cast ren_id);
	}
	else if tex_id, ok := depth_attach_id.(Texture_id); ok {
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, auto_cast tex_id, 1);
	}
	else {
		panic("AHHGHH");
	}

}

attach_framebuffer_stencil :: proc(fbo_id : Frame_buffer_id, tex_id : Texture_id, use_render_buffer : bool) {

	gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast fbo_id);

	if use_render_buffer {
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.RENDERBUFFER, auto_cast tex_id);
	}
	else {
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.TEXTURE_2D, auto_cast tex_id, 1);
	}

}

verify_render_texture :: proc(using render_tex : Render_texture) -> bool {
	
	gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast id);
	
    status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER);

    if (status != gl.FRAMEBUFFER_COMPLETE) {

        switch (status) {
            case gl.FRAMEBUFFER_UNSUPPORTED:
				fmt.printf("Framebuffer is unsupported\n Frame buffer : %#v\n", render_tex);
            case gl.FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
				fmt.printf("Framebuffer has incomplete attachment\n Frame buffer : %#v\n", render_tex);
            case gl.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
				fmt.printf("Framebuffer has a missing attachment\n Frame buffer : %#v\n", render_tex);
            case:
        }
    }

    return status == gl.FRAMEBUFFER_COMPLETE;
}

/////////////////////////////////////////////////////////////////////////////////

// Textures data management

get_frame_buffer_depth_info :: proc(id : Frame_buffer_id) -> (depth_type, depth_id : i32) {
    gl.BindFramebuffer(gl.FRAMEBUFFER, auto_cast id); 
    gl.GetFramebufferAttachmentParameteriv(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &depth_type);
    gl.GetFramebufferAttachmentParameteriv(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &depth_id);
	return;
}


