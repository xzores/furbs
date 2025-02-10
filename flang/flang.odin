package flang;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:path/filepath"
import "core:log"

import "token"
import "parser"
import "final"

File_load :: token.File_load;

Shader_file :: struct {
	full_path : string,
	source_code : string,
	
	stage : enum {
		source,
		tokenized,
		lexed,
		preprocessed,
		parsed,
	},
	
	tokens : [dynamic]token.Token,
}

Shader_context :: struct {
	sources : map[string]Shader_file,
	defines : map[string]token.Token_type,
	
	final_state : final.State,
	finalized : bool, 
}

create_context :: proc (loc := #caller_location) -> ^Shader_context {
	
	source_files := make(map[string]Shader_file);
	
	s := new(Shader_context, loc = loc);
	
	s^ = Shader_context {
		source_files,
		nil,
		{},
		false,
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

//This will keep going unstil there are no more uknown tokens left or the unknown tokens cannot be determined. 
lex :: proc (s : ^Shader_context) {
	
	//create tokens
	tokenize :: proc(s : ^Shader_context) {
		
		for file, &source in s.sources {
			if source.stage < .tokenized {
				
				assert(len(source.tokens) == 0, "");
				
				err : string
				source.tokens, err = token.tokenize(source.source_code, file);
				source.stage = .tokenized;
				
				if err != "" {
					panic(err);
				}
			}
		}
	}
	
	//inserts, replaces and removes tokens
	preproces :: proc (s : ^Shader_context) {
		
		to_load := make([dynamic]token.File_load);
		defer delete(to_load);
		
		for source_file, &source in s.sources {
			
			if source.stage < .preprocessed {
				new_loads := token.preproces(&source.tokens, source_file); //Uses temp alloc
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

parse_and_check :: proc (s : ^Shader_context) {
	//Contruct the AST.
	//There is an AST, it does not error even if invalid, the user may change the AST.
	
	tokens_sources : [dynamic][dynamic]token.Token;
	defer delete(tokens_sources); //This does not delete the token stirngs and such onlt the arrays.
	
	for _, source in s.sources {
		append(&tokens_sources, source.tokens);
	}
	
	res_state, errs := parser.parse(tokens_sources[:]);
	
	if len(errs) != 0 {
		msg := strings.builder_make();
		defer strings.builder_destroy(&msg);
		strings.write_string(&msg, "Found parser errors:");
		
		for e in errs {
			strings.write_string(&msg, "\tError at ");
			strings.write_string(&msg, e.token.source);
			strings.write_string(&msg, " in ");
			strings.write_string(&msg, e.token.file);
			strings.write_string(&msg, "(");
			strings.write_int(&msg, e.token.line);
			strings.write_string(&msg, ")");
			strings.write_string(&msg, " : ");
			strings.write_string(&msg, e.message);
			strings.write_string(&msg, "\n");
		}
		
		log.errorf(strings.to_string(msg));
	}
	
	//type_resolve and such.
	//The AST can return errors here and will check compatility with the target.
	type_errs : []final.Error;
	s.final_state, type_errs = final.finalize(res_state);
	if len(type_errs) == 0 {
		s.finalized = true;
	}
	else {
		panic("error msgs")
	}
}

//For embedded and webGL
emit_glsl_300ES :: proc () {
	//Emit the glsl
}

emit_glsl_330 :: proc (con : ^Shader_context) {
	//Emit the glsl
	log.warnf("Outputted vertex shader :\n%v", final.emit_glsl(con.final_state, .vertex, 330));
	log.warnf("Outputted fragment shader :\n%v", final.emit_glsl(con.final_state, .fragment, 330));
}

emit_glsl_450 :: proc (con : Shader_context) {
	//Emit the glsl
}

emit_spriv_100 :: proc () {
	//Emit the spriv
}

emit_odin :: proc () {
	//Emit the odin
}

emit_flang :: proc () {
	//Emit the flang
}

