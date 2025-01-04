package flang;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:path/filepath"

import "token"
import "preprocessor"
import "parser"

File_load :: preprocessor.File_load;

Shader_file :: struct {
	full_path : string,
	source_code : string,
	
	stage : enum {
		source,
		tokenized,
		lexed,
		preprocessed,
		parsed,
		//TODO maybe a final stage?
	},
	
	tokens : [dynamic]token.Token,
}

Shader_context :: struct {
	sources : map[string]Shader_file,
	defines : map[string]token.Token_type,
}

create_context :: proc (loc := #caller_location) -> ^Shader_context {
	
	source_files := make(map[string]Shader_file);
	
	s := new(Shader_context, loc = loc);
	
	s^ = Shader_context {
		source_files,
		nil,
	}
	
	return s;
}

destroy_contrext :: proc (con : ^Shader_context) {
	
	for d, _ in con.defines {
		delete(d);
	}
	delete(con.defines);
	
	for _, s in con.sources {
		
		delete(s.full_path);
		delete(s.source_code);
		delete(s.tokens);
	}
	
	delete(con.sources);
	
	free(con);
}

create_context_from_file :: proc (filename : string, loc := #caller_location) -> ^Shader_context {
		
	source_code, vert_ok := os.read_entire_file_from_filename(filename);
	defer delete(source_code);
	
	return create_context_from_string(string(source_code), filename, loc);
}

//makes a copy of the source code and filename
create_context_from_string :: proc (source_code : string, file_path : string, loc := #caller_location) -> ^Shader_context {
	
	con := create_context(loc);
	
	add_shader_from_string(con, source_code, file_path);
	
	return con;
}

add_shader_from_string :: proc (con : ^Shader_context, source_code : string, file_path : string) {
	
	s_code, alloc := strings.replace_all(source_code, "\r\n", "\n");
	
	if !alloc {
		s_code = strings.clone(source_code);
	}
	_file_path := strings.clone(file_path);
	
	fmt.printf("adding source to shader from file : %v\n", file_path);
	con.sources[_file_path] = {_file_path, s_code, .source, nil};
}

Variable_type :: struct {
	type: enum {
		_nil,          // Placeholder for uninitialized or undefined types
		
		// Scalar Types
		_float,        // Single-precision floating-point
		_double,       // Double-precision floating-point
		_bool,         // Boolean
		_int,          // Signed integer
		_uint,         // Unsigned integer

		// Vector Types
		_vec2,         // 2-component vector of float
		_vec3,         // 3-component vector of float
		_vec4,         // 4-component vector of float
		_ivec2,        // 2-component vector of int
		_ivec3,        // 3-component vector of int
		_ivec4,        // 4-component vector of int
		_uvec2,        // 2-component vector of unsigned int
		_uvec3,        // 3-component vector of unsigned int
		_uvec4,        // 4-component vector of unsigned int
		_bvec2,        // 2-component vector of bool
		_bvec3,        // 3-component vector of bool
		_bvec4,        // 4-component vector of bool
		_dvec2,        // 2-component vector of double
		_dvec3,        // 3-component vector of double
		_dvec4,        // 4-component vector of double

		// Matrix Types
		_mat2,         // 2x2 matrix of float
		_mat3,         // 3x3 matrix of float
		_mat4,         // 4x4 matrix of float
		_mat2x3,       // 2x3 matrix of float
		_mat2x4,       // 2x4 matrix of float
		_mat3x2,       // 3x2 matrix of float
		_mat3x4,       // 3x4 matrix of float
		_mat4x2,       // 4x2 matrix of float
		_mat4x3,       // 4x3 matrix of float

		// Sampler Types (For textures)
		_sampler1D,          // 1D texture sampler
		_sampler2D,          // 2D texture sampler
		_sampler3D,          // 3D texture sampler
		_samplerCube,        // Cubemap texture sampler
		_sampler1DArray,     // Array of 1D textures
		_sampler2DArray,     // Array of 2D textures
		_samplerBuffer,      // Buffer texture sampler
		_sampler2DRect,      // Rectangular 2D texture
		_samplerCubeArray,   // Array of cubemaps
		_sampler2DMS,        // Multisampled 2D texture
		_sampler2DMSArray,   // Array of multisampled 2D textures

		// Integer Sampler Types
		_isampler1D,         // 1D integer texture sampler
		_isampler2D,         // 2D integer texture sampler
		_isampler3D,         // 3D integer texture sampler
		_isamplerCube,       // Cubemap integer texture sampler
		_isampler1DArray,    // Array of 1D integer textures
		_isampler2DArray,    // Array of 2D integer textures
		_isamplerBuffer,     // Buffer integer texture sampler

		// Unsigned Integer Sampler Types
		_usampler1D,         // 1D unsigned integer texture sampler
		_usampler2D,         // 2D unsigned integer texture sampler
		_usampler3D,         // 3D unsigned integer texture sampler
		_usamplerCube,       // Cubemap unsigned integer texture sampler
		_usampler1DArray,    // Array of 1D unsigned integer textures
		_usampler2DArray,    // Array of 2D unsigned integer textures
		_usamplerBuffer,     // Buffer unsigned integer texture sampler

		// Image Types (For image load/store operations)
		_image1D,            // 1D image
		_image2D,            // 2D image
		_image3D,            // 3D image
		_imageCube,          // Cubemap image
		_imageBuffer,        // Buffer image
		_image1DArray,       // Array of 1D images
		_image2DArray,       // Array of 2D images
		_image2DMS,          // Multisampled 2D image
		_image2DMSArray,     // Array of multisampled 2D images

		// Integer Image Types
		_iimage1D,           // 1D integer image
		_iimage2D,           // 2D integer image
		_iimage3D,           // 3D integer image
		_iimageCube,         // Cubemap integer image
		_iimageBuffer,       // Buffer integer image

		// Unsigned Integer Image Types
		_uimage1D,           // 1D unsigned integer image
		_uimage2D,           // 2D unsigned integer image
		_uimage3D,           // 3D unsigned integer image
		_uimageCube,         // Cubemap unsigned integer image
		_uimageBuffer,       // Buffer unsigned integer image

		// Special Types
		_struct,             // User-defined struct
		_array,              // Array of any type
	},
};

//This will keep going unstil there are no more uknown tokens left or the unknown tokens cannot be determined. 
lex :: proc (s : ^Shader_context) {
	
	//create tokens
	tokenize :: proc(s : ^Shader_context) {
		
		for file, &source in s.sources {
			if source.stage < .tokenized {
				
				assert(len(source.tokens) == 0, "");
				
				source.tokens = token.tokenize(source.source_code, file);
				source.stage = .tokenized;
			}
		}
	}
	
	//inserts, replaces and removes tokens
	preproces :: proc (s : ^Shader_context) {
		
		to_load := make([dynamic]File_load);
		defer delete(to_load);
		
		for source_file, &source in s.sources {
			
			if source.stage < .preprocessed {
				new_loads := preprocessor.preproces(&source.tokens, source_file); //Uses temp alloc
				defer delete(new_loads);
				source.stage = .preprocessed;
				
				for l in new_loads {
					append(&to_load, l);
				}
			}
		}
		
		if len(to_load) != 0 {
			//load new files and tokenize and preprocess them.
			
			for l in to_load {
				
				if l.collection == "" {
					
					rel_path := filepath.dir(l.from, context.temp_allocator);
					filename := fmt.tprintf("%v/%v", filepath.clean(rel_path, context.temp_allocator), l.file);
					
					source_code, ok := os.read_entire_file_from_filename(filename);
					fmt.assertf(ok, "Failed to load file %v\n", filename);
					defer delete(source_code);
					
					add_shader_from_string(s, string(source_code), filename);
					
					fmt.printf("loading file : %v\n", filename);
				}
				else {
					panic("TODO collection not handled.");
				}
			}
		}
	}
	
	//find out what i variable names and what is not.
	tokenize(s);
	preproces(s);
	
	is_done := true;
	
	for source_file, source in s.sources {
		if source.stage != .preprocessed {
			is_done = false;
		}
	}
	
	if !is_done {
		lex(s);
	}
	
}

parse :: proc (s : ^Shader_context) {
	//Contruct the AST.
	//There is an AST, it does not error even if invalid, the user may change the AST.
	
	for _, source in s.sources {
		res, errs := parser.parse(source.tokens);
		parser.destroy_parse_res(res,errs);
	}
	
	
} 

finalize :: proc () {
	//type_resolve and such.
	//The AST can return errors here and will check compatility with the target.
	
	
}


//For embedded and webGL
emit_glsl_300ES :: proc () {
	//Emit the glsl
}

emit_glsl_330 :: proc () {
	//Emit the glsl
}

emit_glsl_450 :: proc () {
	//Emit the glsl
}

emit_spriv_100 :: proc () {
	//Emit the spriv
}

emit_odin :: proc () {
	//Emit the odin
}

