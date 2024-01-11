package render;

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:reflect"

import glfw "vendor:glfw"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

import "../utils"

Shader :: struct (U, A : typeid) {
	id : Shader_program_id,                 					// Shader program id
	name : string,
	attribute_locations : [A]Attribute_info, 	// Shader locations array (MAX_SHADER_LOCATIONS)
	uniform_locations : [U]Uniform_info,
}

//Will load all shaders into memory.
init_shaders :: proc(using s : ^Render_state($U,$A), loc := #caller_location) {
	
	assert(len(loaded_vertex_shaders) == 0, "Shaders has already been loaded", loc = loc);
	assert(len(loaded_fragment_shaders) == 0, "Shaders has already been loaded", loc = loc);

	fmt.printf("Loading all shaders from source : %s\n", shader_folder_location);

	if get_max_supported_attributes(s) <= len(A) {
		fmt.panicf("Not enough supported attribute locations for shader\n PLEASE contact developers!", loc = loc);
	}
	
	////
	vertex_shaders_code 	:= utils.load_all_as_txt(shader_folder_location, "vs", alloc = context.temp_allocator);
	for name, source in vertex_shaders_code {
		assert(name != "_internal_gui", "_internal_gui is reserved for internal use", loc = loc)
		assert(name != "_internal_opague", "_internal_opague is reserved for internal use", loc = loc)
		assert(name != "_internal_transparent", "_internal_transparent is reserved for internal use", loc = loc)

		compile_shader(s, &loaded_vertex_shaders, name, source, .vertex_shader);
	}

	fragment_shaders_code 	:= utils.load_all_as_txt(shader_folder_location, "fs", alloc = context.temp_allocator);
	for name, source in fragment_shaders_code {
		assert(name != "_internal_gui", "_internal_gui is reserved for internal use", loc = loc)
		assert(name != "_internal_opague", "_internal_opague is reserved for internal use", loc = loc)
		assert(name != "_internal_transparent", "_internal_transparent is reserved for internal use", loc = loc)
		
		compile_shader(s, &loaded_fragment_shaders, name, source, .fragment_shader);
	}

	fmt.printf("loaded_vertex_shaders : %#v\n", loaded_vertex_shaders);
	fmt.printf("loaded_fragment_shaders : %#v\n", loaded_fragment_shaders);

}

destroy_shaders :: proc(using s : ^Render_state($U,$A), loc := #caller_location) {

	for name, vs in loaded_vertex_shaders {	
		unload_vertex_shader(s, vs);
	}

	for name, fs in loaded_fragment_shaders {	
		unload_fragment_shader(s, fs);
	}

	delete(loaded_vertex_shaders);
	delete(loaded_fragment_shaders);
}

/////////////////

load_shader :: proc(using s : ^Render_state($U,$A), shader : ^Shader(U, A), vs_name : string, fs_name : string, loc := #caller_location) {

	//TODO cache the result, requires opengl 4.1 so we will only do it if the extension is supported.
	//use glGetString(GL_VERSION);
	
	shader.id = load_program(s);

	vertex_shader : Shader_vertex_id;
	fragment_shader : Shader_fragment_id;

	fmt.assertf(vs_name in loaded_vertex_shaders, "The vertex shader : %v does not exists in\n %#v\n loaded from : %v\n", vs_name, loaded_vertex_shaders, loc = loc);
	vertex_shader = loaded_vertex_shaders[vs_name];

	fmt.assertf(fs_name in loaded_fragment_shaders, "The vertex shader : %v does not exists in\n %#v\n loaded from : %v\n", fs_name, loaded_fragment_shaders, loc = loc);
	fragment_shader = loaded_fragment_shaders[fs_name];

	attach_vertex_shader(s, shader.id, vertex_shader);
	attach_fragment_shader(s, shader.id, fragment_shader);
	link_program(s, shader.id, vs_name, fs_name); // this checks for errors

	///////////////////
	
	shader.name = fmt.aprintf("%s / %s", vs_name, fs_name);

	///////////////////

	for &e in shader.attribute_locations {
		e.location = -1;
	}

	for &e in shader.uniform_locations {
		e.location = -1;
	}

	attrib_names := make(map[string]A);
	defer delete(attrib_names);

	uniform_names := make(map[string]U);
	defer delete(uniform_names);

	attrib_enums := reflect.enum_fields_zipped(A);
	for enum_field, i in attrib_enums { 
		name := enum_field.name;
		value : A = auto_cast enum_field.value;
		attrib_names[name] = value;
	}

	//Load uniforms into uniform_names
	uniform_enums := reflect.enum_fields_zipped(U);
	for enum_field, i in uniform_enums {
		name := enum_field.name;
		value : U = auto_cast enum_field.value;
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

	for name, attrib in get_shader_attributes(s, shader.id, context.temp_allocator, loc) {
		
		if !(name in attrib_names) && !(name in whitelisted_attrib_names) {
			fmt.panicf("Shader %s / %s includes illigal attribute \"%s\"\n", vs_name, fs_name, name, loc = loc);
		}
		
		value := attrib_names[name];
		shader.attribute_locations[value] = attrib;
	}
	
	for name, uniform in get_shader_uniforms(s, shader.id, context.temp_allocator, loc) {

		if !(name in uniform_names) {
			fmt.panicf("Shader %s / %s includes illigal uniform \"%s\"\n", vs_name, fs_name, name);
		}

		value := uniform_names[name];
		shader.uniform_locations[value] = uniform;
	}

	/////////

	//fmt.printf("%s.vs / %s.fs : shader.attribute_locations : %#v\n shader.uniform_locations : %#v\n", vs_name, fs_name, shader.attribute_locations, shader.uniform_locations);

}

unload_shader :: proc(s : ^Render_state($U,$A), using shader : ^Shader(U, A)) {
	//unload_program(shader.id);
	delete(shader.name);
}

//////////////////
@(require_results)
get_default_shader :: proc(using s : ^Render_state($U,$A), loc := #caller_location) -> Shader(U, A) {
	
	assert(s.render_has_been_init == true, "The renderer has not been inited");

	when ODIN_DEBUG {
		assert(s.opengl_version != .invalid, "it seems that opengl is not loaded correctly, (did you forget to create a window)", loc = loc);
	}

	if s.default_shader == {} {
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

		uniform sampler2D diffuse_texture;
		uniform vec4 diffuse_color = vec4(1,1,1,1); 

		void main()
		{
			vec4 texelColor = texture(diffuse_texture, frag_texcoord); 
			final_color = diffuse_color * texelColor; //
		}
		`;

		//TODO what if callled multiable times.
		compile_shader(s, &loaded_vertex_shaders, 		"_internal_gui", vertex_source_gui_shader, 		.vertex_shader);
		compile_shader(s, &loaded_fragment_shaders, 	"_internal_gui", fragment_source_gui_shader, 	.fragment_shader);

		load_shader(s, &s.default_shader, "_internal_gui", "_internal_gui");
	}

	return s.default_shader;
}

//////////////////

//Shader must be bound before this is called.
place_uniform :: proc(using s : ^Render_state($U,$A), shader : Shader(U, A), uniform_loc : U, value : $T, loc := #caller_location) {
	//TODO check that shader is the currently bound shader.
	//TODO this should be bound to uniform block and there should be at least 12 uniforms blocks advaliable, so we can assert by using "GL_MAX_VERTEX_UNIFORM_BLOCKS"
	//Then we bind the UBO to the shader when we draw, this is faster because many shaders share many uniforms.

	uniform_info := shader.uniform_locations[uniform_loc];

	if uniform_info.location == -1 {
		return;
	}

	fmt.assertf(uniform_info.uniform_type != .invalid, "Shader uniform type is %v, but the location is : %v for shader : %s", uniform_info.uniform_type, uniform_info.location, shader.name, loc = loc);

	if  is_sampler(shader.uniform_locations[uniform_loc].uniform_type) { //uniform_loc in texture_locations
		fmt.assertf(uniform_loc in s.texture_locations, "%v is a sampler, but does not have a texture slot", uniform_loc, loc = loc);
		//it is a texture
		set_uniform_sampler(s, uniform_info, s.texture_locations[uniform_loc], value, loc = loc);
	} else if uniform_info.array_size != 1 {
		set_uniform_array(s, uniform_info, value, loc = loc);
	} else {
		set_uniform_single(s, uniform_info, value, loc = loc);
	}
}

@(private)
bind_shader :: proc(using s : ^Render_state($U,$A), shader : Shader(U, A), loc := #caller_location) {
	
	when ODIN_DEBUG {
		assert(bound_camera != {}, "A camera must be bound when binding a shader", loc = loc);
		assert(shader.id != 0, "Shader is not initizalized", loc = loc);
	}

	enable_shader(s, shader.id, loc = loc);

	place_uniform(s, shader, U.prj_mat, prj_mat);
	place_uniform(s, shader, U.inv_prj_mat, inv_prj_mat);

	place_uniform(s, shader, U.view_mat, view_mat);
	place_uniform(s, shader, U.inv_view_mat, inv_view_mat);
	
}

@(private)
unbind_shader :: proc(using s : ^Render_state($U,$A), shader : Shader(U, A), loc := #caller_location){
	assert(bound_camera != {}, "A camera must first be unbound after the shader is unbound", loc = loc);
	disable_shader(s, shader.id);
}
