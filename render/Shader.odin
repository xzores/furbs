package render;

import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:slice"
import "core:os"
import "core:time"
import "core:path/filepath"
import "core:log"

import "gl"

import glgl "gl/OpenGL"
import ex_defs "../../user_defs"

Shader_file_error :: enum {
	invalid_path,
	failed_fileopen,
}

Shader_invalid_attribute :: struct {
	invalid : enum {illigal_name, illigal_placement},
	required_placement : i32,
	attrib_name : string,
}

Shader_invalid_uniform :: struct {
	invalid : enum {illigal_name},
	uniform_name : string,
}

Shader_preprocessor_error :: struct {
	msg : string,
	line : int,
}

destroy_shader_preprocessor_error :: proc(e : ^Shader_preprocessor_error) {
	delete(e.msg);
	e^ = {};
}

destroy_shader_compilation_error :: proc(e : ^gl.Compilation_error) {
	delete(e.msg);
	e^ = {};
}

destroy_shader_invalid_attribute_error :: proc(e : ^Shader_invalid_attribute) {
	delete(e.attrib_name);
	e^ = {};
}

destroy_shader_invalid_uniform_error :: proc(e : ^Shader_invalid_uniform) {
	delete(e.uniform_name);
	e^ = {};
}

Shader_load_error :: union {
	Shader_file_error,
	Shader_preprocessor_error,
	gl.Compilation_error,
	Shader_invalid_attribute,
	Shader_invalid_uniform,
}

destroy_shader_error :: proc(e : ^Shader_load_error) {

	switch se in e {
		case Shader_file_error: 
			//Nothing to do
		case Shader_preprocessor_error:
			destroy_shader_preprocessor_error(&se);
		case gl.Compilation_error:
			destroy_shader_compilation_error(&se);
		case Shader_invalid_attribute:
			destroy_shader_invalid_attribute_error(&se);
		case Shader_invalid_uniform:
			destroy_shader_invalid_uniform_error(&se);
	}
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

Shader_load_desc :: struct {
	path : string,
	time_stamp : time.Time,
}

Shader :: struct {
	id : Shader_program_id,                 					// Shader program id
	name : string,
	loaded : Maybe(Shader_load_desc),
	attribute_locations : [Attribute_location]Attribute_info, 	// Shader locations array (MAX_SHADER_LOCATIONS)
	uniform_locations : [Uniform_location]Uniform_info,
	texture_locations : [Texture_location]Uniform_info,
}

Uniform_odin_type :: union {
	f32,
	[2]f32,
	[3]f32,
	[4]f32,
	i32,
	[2]i32,
	[3]i32,
	[4]i32,
	u32,
	[2]u32,
	[3]u32,
	[4]u32,
	matrix[2,2]f32,
	matrix[3,3]f32,
	matrix[4,4]f32,
	//matrix[2,3]f32,
	//matrix[3,2]f32,
	//matrix[2,4]f32,
	//matrix[4,2]f32,
	//matrix[3,4]f32,
	//matrix[4,3]f32,
}

Texture_odin_type :: union {
	//Texture1D,
	Texture2D,
	//Texture3D,
	//CubeMap,
	//Texture2DArray,
}

init_shaders :: proc() {

	state.loaded_shaders = make([dynamic]^Shader);
	e : Shader_load_error;

	state.default_shader, e = load_shader_from_src("default_shader.glsl", #load("default_shader.glsl"), nil);
	
	if e != nil {
		panic("Failed to load default shader!, this is internal bad error");
	}

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

@(private)
bind_shader :: proc(shader : ^Shader) {
	gl.bind_shader_program(shader.id);
	state.bound_shader = shader;
}

@(private)
unbind_shader :: proc(shader : ^Shader) {
	gl.unbind_shader_program();
	state.bound_shader = nil;
}

set_uniform :: proc(shader : ^Shader, uniform : Uniform_location, value : Uniform_odin_type, loc := #caller_location) {
	using glgl;

	value := value;
	
	if !shader.uniform_locations[uniform].active {
		return;
	}
	
	when ODIN_DEBUG {
		odin_type :=  reflect.union_variant_type_info(value).id;
		bind_type := gl.odin_type_to_uniform_type(odin_type);
		target_type := shader.uniform_locations[uniform].uniform_type;
		fmt.assertf(target_type == bind_type, "Cannot bind a uniform of type %v to a %v.", target_type, bind_type,loc = loc);
	}

	u_loc : i32 = cast(i32) shader.uniform_locations[uniform].location;

	switch &v in value {
		case f32:
			Uniform1f(u_loc, v);
		case [2]f32:
			Uniform2f(u_loc, v.x, v.y);
		case [3]f32:
			Uniform3f(u_loc, v.x, v.y, v.z);
		case [4]f32:
			Uniform4f(u_loc, v.x, v.y, v.z, v.w);

		case i32:
			Uniform1i(u_loc, v);
		case [2]i32:
			Uniform2i(u_loc, v.x, v.y);
		case [3]i32:
			Uniform3i(u_loc, v.x, v.y, v.z);
		case [4]i32:
			Uniform4i(u_loc, v.x, v.y, v.z, v.w);

		case u32:
			Uniform1ui(u_loc, v);
		case [2]u32:
			Uniform2ui(u_loc, v.x, v.y);
		case [3]u32:
			Uniform3ui(u_loc, v.x, v.y, v.z);
		case [4]u32:
			Uniform4ui(u_loc, v.x, v.y, v.z, v.w);

		case matrix[2,2]f32:
			UniformMatrix2fv(u_loc, 1, false, &v[0,0]);
		case matrix[3,3]f32:
			UniformMatrix3fv(u_loc, 1, false, &v[0,0]);
		case matrix[4,4]f32:
			UniformMatrix4fv(u_loc, 1, false, &v[0,0]);

	}
}

set_texture :: proc(location : Texture_location, value : Texture_odin_type, loc := #caller_location) {

	switch v in value {
		case nil:
			gl.active_bind_texture_2D(0, cast(i32)location);
		case Texture2D:
			gl.active_bind_texture_2D(v.id, cast(i32)location);
		case:
			panic("TODO");
	}
}

//You must destoy the error. (if it is there)
@(require_results)
run_preprocessor :: proc (using preprocessor : ^Preprocessor, shader_name : string, src : string, path : string) -> (vertex_src : string, fragment_src : string, err : Maybe(Shader_preprocessor_error)) {
	using strings;

	err = nil;

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
					err = Shader_preprocessor_error{
						msg = fmt.aprintf("The shader '%v' failed the preprocessor stage. The error at line %i is : includes may only be the first char in a line. (if you try to do '#version something', you should not as this is done by the preprocessor)", shader_name, line),
						line = line,
					};
					return;
				}
				else if c == '@' {
					err = Shader_preprocessor_error{
						msg = fmt.aprintf("The shader '%v' failed the preprocessor stage. The error at line %i is : tags may only be the first char in a line. (did you make a space?)", shader_name, line),
						line = line,
					};
					return;
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
					err = Shader_preprocessor_error{
						msg = fmt.aprintf("The shader '%v' failed the preprocessor stage. The error at line %i is : found a '#', but it was not '#include', you should not define #version this is done by the preprocessor.", shader_name, line),
						line = line,
					};
					return;
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

					log.debugf("found include identifier : %v", file_identifier);
					if (path == "") {
						err = Shader_preprocessor_error{
							msg = fmt.aprintf("The shader %s cannot #include if it do not have a path. Only shaders loaded from a path may #include", shader_name),
							line = line,
						};
						return;
					}
					
					file_info, info_ok := os.stat(path);
					defer os.file_info_delete(file_info);
					if info_ok != 0 {
						err = Shader_preprocessor_error{
							msg = fmt.aprintf("Something is very wrong the shader %s loaded from no longer exists...", shader_name, path),
							line = line,
						};
						return;
					}
					
					include_path := fmt.tprintf("%s/%s", filepath.dir(path, context.temp_allocator), file_identifier);
					data, ok := os.read_entire_file_from_filename(include_path);
					defer delete(data);

					if !ok {
						err = Shader_preprocessor_error{
							msg = fmt.aprintf("Could not load file %s", include_path),
							line = line,
						};
						return;
					}

					include_src := string(data);
					
					log.debugf("Will pass the following src : \n%v", include_src);

					target = .all;
					
					_, _, err = run_preprocessor(preprocessor, fmt.tprintf("%s/%s", shader_name, file_identifier), include_src, include_path);
					if err != nil {
						return;
					}

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
					log.debugf("found define : %v", def);

					if def in state.shader_defines {
						write_target(preprocessor, state.shader_defines[def]);
					}
					else {
						err = Shader_preprocessor_error{
							msg = fmt.aprintf("The define '%v' is not a part of shader defines : %#v.", def, state.shader_defines),
							line = line,
						};
						return;
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
					log.debugf("found tag @vertex");
					target = .target_vertex;
				}
				else if to_string(current_identifier) == fragment {
					log.debugf("found tag @fragment");
					target = .target_fragment;
				}
				else {
					//fmt.tprintf("tag found, but was invalid. The tag : '%v'. It must be @vertex or @fragment", to_string(current_identifier))
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

	return to_string(vertex_builder), to_string(fragment_builder), nil;
}

//You must destoy the error. (if it is there)
@(require_results)
load_shader_from_path :: proc(path : string, loc := #caller_location) -> (shader : ^Shader, err : Shader_load_error) {

	file, f_err := os.stat(path);
	defer os.file_info_delete(file);
	
	if f_err != 0 {
		log.errorf("Failed to reload shader from shader file : %s. The path is likely invalid.", path);
		return nil, .invalid_path;
	}
	
	data, ok := os.read_entire_file_from_filename(path);
	defer delete(data);

	if !ok {
		log.errorf("Could not reload shader from file : %s. The content is likely used by another program.", path);
		return nil, .failed_fileopen;
	}
	
	return load_shader_from_src(file.name, string(data), Shader_load_desc{strings.clone(path), time.now()});
}

//You must destoy the error. (if it is there)
@(require_results)
load_shader_from_src :: proc(name : string, combined_src : string, loaded : Maybe(Shader_load_desc), loc := #caller_location) -> (shader : ^Shader, err : Shader_load_error) {
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
	
	path := "";

	if l, ok := loaded.?; ok {
		path = l.path;
	}
	
	vertex_src, fragment_src, pre_err := run_preprocessor(&preprocessor, name, combined_src, path);
	if e, ok := pre_err.?; ok {
		log.errorf(e.msg);
		free(shader);
		if l, ok := loaded.?; ok {
			delete(l.path);
		}
		return nil, e;
	}

	// Preprocessor done //
	
	//TODO pass though glslang (aka glsl_validator)
	
	// Now load the shader program by opengl //
	shader_id, comp_err := load_shader_program(name, vertex_src, fragment_src);
	
	if e, ok := comp_err.?; ok {
		free(shader);		
		if l, ok := loaded.?; ok {
			delete(l.path);
		}
		return nil, e;
	}

	attrib_names : map[string]Attribute_location;
	defer delete(attrib_names);
	uniform_names : map[string]Uniform_location;
	defer delete(uniform_names);
	texture_names : map[string]Texture_location;
	defer delete(texture_names);

	//Load attributes into attrib_names
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
	
	//Load uniforms into uniform_names
	texture_enums := reflect.enum_fields_zipped(Texture_location);
	for enum_field, i in texture_enums {
		name := enum_field.name;
		value : Texture_location = auto_cast enum_field.value;
		texture_names[name] = value;
	}

	/////////
	
	whitelisted_attrib_names : map[string]bool = {
		"gl_VertexID" = true,
		"gl_InstanceID" = true,
		"gl_DrawID" = true,
		"gl_BaseVertex" = true,
		"gl_BaseInstance" = true,
	};

	defer delete(whitelisted_attrib_names);
	
	for a_name, attrib in get_shader_attributes(shader_id, context.temp_allocator, loc) {
		
		if !(a_name in attrib_names) && !(a_name in whitelisted_attrib_names) {
			free(shader);
			gl.unload_shader_program(shader_id);
			if l, ok := loaded.?; ok {
				delete(l.path);
			}
			log.errorf("Shader %s contains illigal attribute \"%s\"", name, a_name);
			return nil, Shader_invalid_attribute{.illigal_name, 0, strings.clone(a_name)};
		}
		
		value := attrib_names[a_name];
		shader.attribute_locations[value] = attrib;
		if attrib.location != cast(Attribute_id)value && !(a_name in whitelisted_attrib_names) {
			free(shader);
			gl.unload_shader_program(shader_id);
			if l, ok := loaded.?; ok {
				delete(l.path);
			}
			log.errorf("The attribute '%v' has an invalid placement, use 'layout(location = %v)' in shader : %v to fix", a_name, cast(int)value, name);
			return nil, Shader_invalid_attribute{.illigal_placement, cast(i32)value, strings.clone(a_name)};
		};
	}
	
	for u_name, uniform in get_shader_uniforms(shader_id, context.temp_allocator, loc) {

		if (u_name in uniform_names) {
			value := uniform_names[u_name];
			shader.uniform_locations[value] = uniform;
		}
		else if (u_name in texture_names) {
			value : Texture_location = texture_names[u_name];
			shader.texture_locations[value] = uniform;
			gl.bind_shader_program(shader_id);
			glgl.Uniform1i(uniform.location, cast(i32)value); //The uniform will always be bound to this texture slot. Static assignment.
			gl.unbind_shader_program();
		}
		else {
			free(shader);
			gl.unload_shader_program(shader_id);
			if l, ok := loaded.?; ok {
				delete(l.path);
			}
			log.errorf("Shader %s contains illigal uniform/texture \"%s\"", name, u_name);
			return nil, Shader_invalid_uniform{.illigal_name, strings.clone(u_name)};
		}
	}

	shader.id = shader_id;
	shader.name = fmt.aprint(name);
	shader.loaded = loaded;
	
	append(&state.loaded_shaders, shader);
	
	return shader, nil;
}

unload_shader :: proc(shader : ^Shader, loc := #caller_location) {

	if l, ok := shader.loaded.?; ok {
		assert(l.path != "");
		delete(l.path);
	}

	gl.unload_shader_program(shader.id);
	delete(shader.name);

	index, found := slice.linear_search(state.loaded_shaders[:], shader);

	if !found {
		panic("The shader you are trying to unload is not a loaded shader (did you already delete it?)", loc = loc);
	}

	unordered_remove(&state.loaded_shaders, index)

	free(shader);
}

reload_shader :: proc (shader : ^Shader) {
	
	if load, ok := shader.loaded.?; ok {
		assert(load.path != "");

		file, err := os.stat(load.path);
		defer os.file_info_delete(file);
		
		if time.duration_seconds(time.diff(file.modification_time, load.time_stamp)) > 0 {
			log.infof("The shader %v, is up to date. skipping reloading", shader.name);
			return; //The last load is newer then the modified file, so we do not need to reload.
		}

		//The acctual reloading
		new_shader, new_err := load_shader_from_path(load.path);

		if new_err != nil {
			log.errorf("Failed to reload shader %v", shader.name);
			switch e in new_err {
				case Shader_file_error:
					log.errorf("Could not open/load file, err : %v", e);
				case Shader_preprocessor_error:
					log.errorf(e.msg);
					delete(e.msg);
				case gl.Compilation_error:
					log.errorf(e.msg);
					delete(e.msg);
				case Shader_invalid_attribute:
					log.errorf("Skipping recompiling shader as shader %s contains invalid attribute \"%s\"", shader.name, e.attrib_name);
					delete(e.attrib_name);
				case Shader_invalid_uniform:
					log.errorf("Skipping recompiling shader as shader %s contains invalid uniform \"%s\"", shader.name, e.uniform_name);
					delete(e.uniform_name);
			}

			return;
		}

		//We swap the shaders and then unload the old shader (called new_shader after this operation)
		new_shader^, shader^ = shader^, new_shader^;
		unload_shader(new_shader);
		log.infof("Reloaded shader %v", shader.name);
	}
	else {
		log.infof("The shader %v, is not a loaded shader. skipping reloading", shader.name);
	}
}

reload_shaders :: proc () {
	for shader in state.loaded_shaders {
		reload_shader(shader)
	}
}





