package render;

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:reflect"

import glfw "vendor:glfw"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

import "../utils"

Shader :: struct {
	id : Shader_program_id,                 					// Shader program id
	name : string,				
	attribute_locations : [Attribute_location]Attribute_info, 	// Shader locations array (MAX_SHADER_LOCATIONS)
	uniform_locations : [Uniform_location]Uniform_info,
}

//Will load all shaders into memory.
init_shaders :: proc(using s : Render_state($U,$A), loc := #caller_location) {
	
	assert(len(loaded_vertex_shaders) == 0, "Shaders has already been loaded", loc = loc);
	assert(len(loaded_fragment_shaders) == 0, "Shaders has already been loaded", loc = loc);

	fmt.printf("Loading all shaders from source : %s\n", shader_folder_location);

	if get_max_supported_attributes() <= len(Attribute_location) {
		fmt.panicf("Not enough supported attribute locations for shader\n PLEASE contact developers!", loc = loc);
	}
	
	////
	vertex_shaders_code 	:= utils.load_all_as_txt(shader_folder_location, "vs", alloc = context.temp_allocator);
	for name, source in vertex_shaders_code {
		assert(name != "_internal_gui", "_internal_gui is reserved for internal use", loc = loc)
		assert(name != "_internal_opague", "_internal_opague is reserved for internal use", loc = loc)
		assert(name != "_internal_transparent", "_internal_transparent is reserved for internal use", loc = loc)

		compile_shader(&loaded_vertex_shaders, name, source, .vertex_shader);
	}

	fragment_shaders_code 	:= utils.load_all_as_txt(shader_folder_location, "fs", alloc = context.temp_allocator);
	for name, source in fragment_shaders_code {
		assert(name != "_internal_gui", "_internal_gui is reserved for internal use", loc = loc)
		assert(name != "_internal_opague", "_internal_opague is reserved for internal use", loc = loc)
		assert(name != "_internal_transparent", "_internal_transparent is reserved for internal use", loc = loc)
		
		compile_shader(&loaded_fragment_shaders, name, source, .fragment_shader);
	}

	fmt.printf("loaded_vertex_shaders : %#v\n", loaded_vertex_shaders);
	fmt.printf("loaded_fragment_shaders : %#v\n", loaded_fragment_shaders);

}

destroy_shaders :: proc(using s : Render_state($U,$A)) {

	for name, vs in loaded_vertex_shaders {	
		unload_vertex_shader(vs);
	}

	for name, fs in loaded_fragment_shaders {	
		unload_fragment_shader(fs);
	}

	delete(loaded_vertex_shaders);
	delete(loaded_fragment_shaders);
}

/////////////////

load_shader :: proc(using s : Render_state($U,$A), using shader : ^Shader, vs_name : string, fs_name : string, loc := #caller_location) {

	//TODO cache the result, requires opengl 4.1 so we will only do it if the extension is supported.
	//use glGetString(GL_VERSION);
	
	shader.id = load_program();

	vertex_shader : Shader_vertex_id;
	fragment_shader : Shader_fragment_id;

	fmt.assertf(vs_name in loaded_vertex_shaders, "The vertex shader : %v does not exists in\n %#v\n loaded from : %v\n", vs_name, loaded_vertex_shaders, loc = loc);
	vertex_shader = loaded_vertex_shaders[vs_name];

	fmt.assertf(fs_name in loaded_fragment_shaders, "The vertex shader : %v does not exists in\n %#v\n loaded from : %v\n", fs_name, loaded_fragment_shaders, loc = loc);
	fragment_shader = loaded_fragment_shaders[fs_name];

	attach_vertex_shader(shader.id, vertex_shader);
	attach_fragment_shader(shader.id, fragment_shader);
	link_program(shader.id, vs_name, fs_name); // this checks for errors

	///////////////////
	
	shader.name = fmt.aprintf("%s / %s", vs_name, fs_name);

	///////////////////

	for &e in shader.attribute_locations {
		e.location = -1;
	}

	for &e in shader.uniform_locations {
		e.location = -1;
	}

	attrib_names := make(map[string]Attribute_location);
	defer delete(attrib_names);

	uniform_names := make(map[string]Uniform_location);
	defer delete(uniform_names);

	attrib_enums := reflect.enum_fields_zipped(Attribute_location);
	for enum_field, i in attrib_enums { 
		name := enum_field.name;
		value : Attribute_location = auto_cast enum_field.value;
		attrib_names[name] = value;
	}

	//Load uniforms into uniform_names
	uniform_enums := reflect.enum_fields_zipped(Uniform_location);
	for enum_field, i in uniform_enums {
		name := enum_field.name;
		value : Uniform_location = auto_cast enum_field.value;
		uniform_names[name] = value;
	}

	/////////

	whitelisted_attrib_names : map[string]bool = {
		"gl_VertexID" = true,
		"gl_InstanceID" = true,
		"gl_DrawID" = true,
		"gl_BaseVertex" = true,
		"gl_BaseInstance" = true,
	};

	for name, attrib in get_shader_attributes(shader.id, context.temp_allocator, loc) {
		
		if !(name in attrib_names) && !(name in whitelisted_attrib_names) {
			fmt.panicf("Shader %s / %s includes illigal attribute \"%s\"\n", vs_name, fs_name, name, loc = loc);
		}
		
		value := attrib_names[name];
		shader.attribute_locations[value] = attrib;
	}
	
	for name, uniform in get_shader_uniforms(shader.id, context.temp_allocator, loc) {

		if !(name in uniform_names) {
			fmt.panicf("Shader %s / %s includes illigal uniform \"%s\"\n", vs_name, fs_name, name);
		}

		value := uniform_names[name];
		shader.uniform_locations[value] = uniform;
	}

	/////////

	//fmt.printf("%s.vs / %s.fs : shader.attribute_locations : %#v\n shader.uniform_locations : %#v\n", vs_name, fs_name, shader.attribute_locations, shader.uniform_locations);
}

unload_shader :: proc(using s : Render_state($U,$A), shader : ^Shader) {
	//TODO
	panic("TODO");
}

//////////////////

get_default_gui_shader :: proc(using s : Render_state($U,$A)) -> (shader : Shader) {
	
	vertex_source_gui_shader := `
	#version 330 core

	layout (location = 0) in vec3 position;
	layout (location = 1) in vec2 texcoord;

	out vec2 frag_texcoord; 

	uniform mat4 mvp;

	void main()
	{
		frag_texcoord = texcoord;
		gl_Position = mvp * vec4(position, 1.0);
	};
	`;

	fragment_source_gui_shader := `
	#version 330 core

	in vec2 frag_texcoord;
	out vec4 final_color;

	uniform sampler2D texture_diffuse;
	uniform vec4 col_diffuse = vec4(1,1,1,1); 

	void main()
	{
		vec4 texelColor = texture(texture_diffuse, frag_texcoord); 
		final_color = col_diffuse * texelColor; //
	}
	`;

	compile_shader(&loaded_vertex_shaders, 		"_internal_gui", vertex_source_gui_shader, 		.vertex_shader);
	compile_shader(&loaded_fragment_shaders, 	"_internal_gui", fragment_source_gui_shader, 	.fragment_shader);

	load_shader(&shader, "_internal_gui", "_internal_gui");

	return;
}

get_default_text_shader :: proc(using s : Render_state($U,$A)) -> (shader : Shader) {
	
	vertex_source_gui_shader := `
	#version 330 core

	layout (location = 0) in vec3 position;

	out vec2 frag_texcoord; 

	uniform vec2 texcoords[4];
	uniform mat4 mvp;

	void main()
	{
		frag_texcoord = texcoords[gl_VertexID];
		gl_Position = mvp * vec4(position, 1.0);
	};
	`;

	fragment_source_gui_shader := `
	#version 330 core

	in vec2 frag_texcoord;

	out vec4 final_color;

	uniform sampler2D texture_diffuse;
	uniform vec4 col_diffuse = vec4(1,1,1,1);

	void main()
	{
		vec4 texelColor = vec4(1, 1, 1, texture(texture_diffuse, frag_texcoord).r); 
		final_color = col_diffuse * texelColor; //
	}
	`;

	compile_shader(&loaded_vertex_shaders, 		"_internal_text", vertex_source_gui_shader, 		.vertex_shader);
	compile_shader(&loaded_fragment_shaders, 	"_internal_text", fragment_source_gui_shader, 		.fragment_shader);
	
	load_shader(&shader, "_internal_text", "_internal_text");

	return;
}
//////////////////

//Shader must be bound before this is called.
place_uniform :: proc(using s : Render_state($U,$A), shader : Shader, uniform_loc : Uniform_location, value : $T, loc := #caller_location) {
	
	//TODO check that shader is the currently bound shader.
	//TODO this should be bound to uniform block and there should be at least 12 uniforms blocks advaliable, so we can assert by using "GL_MAX_VERTEX_UNIFORM_BLOCKS"
	//Then we bind the UBO to the shader when we draw, this is faster because many shaders share many uniforms.

	uniform_info := shader.uniform_locations[uniform_loc];

	if uniform_info.location == -1 {
		return;
	}

	fmt.assertf(uniform_info.uniform_type != .invalid, "Shader uniform type is %v, but the location is : %v for shader : %s", uniform_info.uniform_type, uniform_info.location, shader.name, loc = loc);

	if uniform_loc in texture_locations {
		//it is a texture
		set_uniform_sampler(uniform_info, texture_locations[uniform_loc], value, loc = loc);
	} else if uniform_info.array_size != 1 {
		set_uniform_array(uniform_info, value, loc = loc);
	} else {
		set_uniform_single(uniform_info, value, loc = loc);
	}
}

bind_shader :: proc(using s : Render_state($U,$A), shader : Shader, loc := #caller_location) {
	
	assert(bound_camera != {}, "A camera must be bound when binding a shader", loc = loc);
	assert(shader.id != 0, "Shader is not initizalized", loc = loc);

	enable_shader(shader.id, loc = loc);

	place_uniform(shader, .prj_mat, prj_mat);
	place_uniform(shader, .inv_prj_mat, inv_prj_mat);

	place_uniform(shader, .view_mat, view_mat);
	place_uniform(shader, .inv_view_mat, inv_view_mat);
	
}

unbind_shader :: proc(using s : Render_state($U,$A), shader : Shader, loc := #caller_location){
	assert(bound_camera != {}, "A camera must first be unbound after the shader is unbound", loc = loc);
	disable_shader(shader.id);
}
