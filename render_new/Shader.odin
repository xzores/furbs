package render;

import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:slice"
import "core:os"
import "core:path/filepath"

import "gl"

Shader :: struct {
	id : Shader_program_id,                 					// Shader program id
	name : string,
	attribute_locations : [Attribute_location]Attribute_info, 	// Shader locations array (MAX_SHADER_LOCATIONS)
	uniform_locations : [Uniform_location]Uniform_info,
}

init_shaders :: proc() {

	state.loaded_shaders = make([dynamic]^Shader);

	state.default_shader = load_shader_from_src("default_shader", #load("default_shader.glsl"), "");

	//TODO look at glValidateProgram 
}

destroy_shaders :: proc() {

	unload_shader(state.default_shader);
	state.default_shader = {};

	if len(state.loaded_shaders) != 0 {
		panic("not all shaders have been unloaded");
	}

	delete(state.loaded_shaders);
	state.loaded_shaders = {};
}

get_shader :: proc(name : string) -> ^Shader {
	return {};
}

get_default_shader :: proc() -> ^Shader {

	return state.default_shader;
}

Preprocessor_state :: enum {
	no_state,
	in_comment,
	in_code,
	potential_include,
	include_identifier,
	potential_define,
	potential_tag,
}

Preprocessor_target :: enum {
	no_target,
	target_vertex,
	target_fragment,
	all,
}

Preprocessor :: struct {
	vertex_builder : strings.Builder,
	fragment_builder : strings.Builder,
	
	target : Preprocessor_target,

	current_identifier : strings.Builder,
	
	p_state : Preprocessor_state,

	do_write : bool,

	line : int,
}

bind_shader :: proc(shader : ^Shader) {
	gl.use_program(shader.id);
}

run_preprocessor :: proc (using preprocessor : ^Preprocessor, shader_name : string, src : string, path : string) -> (vertex_src : string, fragment_src : string){
	using strings;

	write_target_rune :: proc (using preprocessor : ^Preprocessor, val : string) {
		if target == .target_vertex || target == .all {
			write_string(&vertex_builder, val);
		}
		if preprocessor.target == .target_fragment || target == .all {
			write_string(&fragment_builder, val);
		}
	}

	write_target_string :: proc (using preprocessor : ^Preprocessor, val : rune) {
		if target == .target_vertex || target == .all {
			write_rune(&vertex_builder, val);
		}
		if preprocessor.target == .target_fragment || target == .all {
			write_rune(&fragment_builder, val);
		}
	}

	write_target :: proc {write_target_rune, write_target_string};

	for c in src {

		//fmt.printf("p_state : '%v'\n", p_state)
		//fmt.printf("current_identifier : '%v'\n", to_string(current_identifier))

		switch p_state {
			case .no_state:
				do_write = false;
				if c == '/' {
					if to_string(current_identifier) == "/" {
						p_state = .in_comment;
					}
				}
				else if c == '#' {
					p_state = .potential_include;
				}
				else if c == '@' {
					p_state = .potential_tag;
				}
				else if c == '$' {
					p_state = .potential_define;
					builder_reset(&current_identifier);
				}
				else {
					do_write = true;
					p_state = .in_code;
				}
			case .in_comment:
				do_write = false;
				if c == '\n' {
					p_state = .no_state;
				}
			case .in_code:

				do_write = true;

				if c == '\n' {
					p_state = .no_state;
				}
				else if c == '#' {
					fmt.panicf("The shader '%v' failed the preprocessor stage. The error at line %i is : includes may only be the first char in a line. (if you try to do '#version something', you should not as this is done by the preprocessor)", shader_name, line);
				}
				else if c == '@' {
					fmt.panicf("The shader '%v' failed the preprocessor stage. The error at line %i is : tags may only be the first char in a line. (did you make a space?)", shader_name, line);
				}
				else if c == '$' {
					p_state = .potential_define;
					builder_reset(&current_identifier);
					do_write = false;
				}
			case .potential_include:
				
				do_write = false;

				s := to_string(current_identifier);
				include :=  "#include";
				
				if s != include[:len(s)] {
					fmt.panicf("The shader '%v' failed the preprocessor stage. The error at line %i is : found a '#', but it was not '#include', you should not define #version this is done by the preprocessor.", shader_name, line);
				}
				if c == ' ' {
					p_state = .include_identifier;
				}
			case .include_identifier: {
				
				do_write = false;

				if c == '\n' || c == ' ' {
					p_state = .no_state;
					file_identifier := to_string(current_identifier);

					if file_identifier[0] == '"' {
						file_identifier = file_identifier[1:];
					}
					
					if file_identifier[len(file_identifier) - 1] == '"' {
						file_identifier = file_identifier[:len(file_identifier) - 1];
					}

					fmt.printf("found include identifier : %v\n", file_identifier);
					if (path == "") {
						fmt.panicf("The shader %s cannot #include if it do not have a path. Only shaders loaded from a path may #include", shader_name);
					}
					
					file_info, info_ok := os.stat(path);
					if info_ok != 0 {
						fmt.panicf("Something is very wrong the shader %s loaded from no longer exists...", shader_name, path);
					}
					
					include_path := fmt.tprintf("%s/%s", filepath.dir(path), file_identifier);
					data, ok := os.read_entire_file_from_filename(include_path);
					defer delete(data);

					if !ok {
						fmt.panicf("Could not load file %s", include_path);
					}

					include_src := string(data);
					
					fmt.printf("Will pass the following src : \n%v\n", include_src);

					target = .all;
					run_preprocessor(preprocessor, fmt.tprintf("%s/%s", shader_name, file_identifier), include_src, include_path);
					target = .no_target;
				}
			}
			case .potential_define:
				
				do_write = false;

				s := to_string(current_identifier);
				if s[0] == '$' {
					builder_reset(&current_identifier);
				}
				if c == '$' {
					def := to_string(current_identifier);
					fmt.printf("found define : %v\n", def);

					if def in state.shader_defines {
						write_target(preprocessor, state.shader_defines[def]);
					}
					else {
						fmt.panicf("The define '%v' is not a part of shader defines : %#v.", def, state.shader_defines);
					}

					p_state = .in_code;
				}
			case .potential_tag:
				
				do_write = false;
				
				//TODO
				//write to the target, @vertex sets the vertex shader as the target
				vertex := "@vertex";
				fragment := "@fragment";

				if to_string(current_identifier) == vertex {
					fmt.printf("found tag @vertex\n");
					target = .target_vertex;
				}
				else if to_string(current_identifier) == fragment {
					fmt.printf("found tag @fragment\n");
					target = .target_fragment;
				}
				else {
					//fmt.panicf("tag found, but was invalid. The tag : '%v'. It must be @vertex or @fragment", to_string(current_identifier))
				}

				if c == '\n' {
					p_state = .no_state;
				}
		}
		
		strings.write_rune(&current_identifier, c);

		if c == ' ' || c == ')' || c == '(' || c == '+' || c == '-' || c == '*' {
			builder_reset(&current_identifier);
		}

		if c == '\n' {
			builder_reset(&current_identifier);
			line += 1;
		}

		if do_write {
			write_target(preprocessor, c);
		}
	}

	return to_string(vertex_builder), to_string(fragment_builder);
}

load_shader_from_path :: proc(path : string, loc := #caller_location) -> (shader : ^Shader) {

	file, err := os.stat(path);

	if err != 0 {
		fmt.panicf("Failed to open shader file : %s", path);
	}
	
	data, ok := os.read_entire_file_from_filename(path);
	defer delete(data);

	if !ok {
		fmt.panicf("Could not load shader from file : %s", path);
	}

	return load_shader_from_src(file.name, string(data), path, loc);
}

load_shader_from_src :: proc(name : string, combined_src : string, path : string = "", loc := #caller_location) -> (shader : ^Shader) {
	using gl;

	shader = new(Shader);

	//the preprocessor for the shaders.
	preprocessor : Preprocessor = {
		vertex_builder = strings.builder_make(),
		fragment_builder = strings.builder_make(),

		current_identifier = strings.builder_make(),
		p_state = .no_state,

		line = 1,
	}
	defer {
		strings.builder_destroy(&preprocessor.vertex_builder);
		strings.builder_destroy(&preprocessor.fragment_builder);
		strings.builder_destroy(&preprocessor.current_identifier);
	}

	strings.write_string(&preprocessor.vertex_builder, "#version 330 core\n");
	strings.write_string(&preprocessor.fragment_builder, "#version 330 core\n");
	
	run_preprocessor(&preprocessor, name, combined_src, path);

	// Preprocessor done //
	
	vertex_src : string = strings.to_string(preprocessor.vertex_builder);
	fragment_src : string  = strings.to_string(preprocessor.fragment_builder); 
	
	//TODO pass though glslang (aka glsl_validator)

	shader_id, err := load_shader_program(name, vertex_src, fragment_src);

	shader.id = shader_id;
	shader.name = fmt.aprint("default_shader");

	if err {
		panic("failed to compile shader");
	}

	attrib_names : map[string]Attribute_location;
	uniform_names : map[string]Uniform_location;

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

	for a_name, attrib in get_shader_attributes(shader_id, context.temp_allocator, loc) {
		
		if !(a_name in attrib_names) && !(a_name in whitelisted_attrib_names) {
			fmt.panicf("Shader %s contains illigal attribute \"%s\"\n", name, a_name, loc = loc);
		}
		
		value := attrib_names[a_name];
		fmt.assertf(attrib.location == cast(Attribute_id)value, "The attribute '%v' has an invalid placement, use 'layout(location = %v)' in shader : %v to fix", a_name, cast(int)value, name, loc = loc);
		shader.attribute_locations[value] = attrib;
	}
	
	for u_name, uniform in get_shader_uniforms(shader_id, context.temp_allocator, loc) {

		if !(u_name in uniform_names) {
			fmt.panicf("Shader %s contains illigal uniform \"%s\"\n", name, u_name, loc = loc);
		}
		
		value := uniform_names[u_name];
		fmt.assertf(uniform.location == cast(Uniform_id)value, "The uniform '%v' has an invalid placement, use 'layout(location = %v)' in shader : %v to fix", u_name, cast(int)value, name, loc = loc);
		shader.uniform_locations[value] = uniform;
	}
	
	append(&state.loaded_shaders, shader)

	return shader;
}

unload_shader :: proc(shader : ^Shader, loc := #caller_location) {

	gl.unload_shader_program(shader.id);
	delete(shader.name);

	index, found := slice.linear_search(state.loaded_shaders[:], shader);

	if !found {
		panic("The shader you are trying to unload is not a loaded shader (did you already delete it?)", loc = loc);
	}

	unordered_remove(&state.loaded_shaders, index)

	free(shader);
}
