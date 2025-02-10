package flang_parser;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:log"
import "core:slice"
import "core:path/slashpath"

import "../token"

Token :: token.Token;
Storage_qualifiers :: token.Storage_qualifiers;
Annotation_type :: token.Annotation_type;
Semicolon :: token.Semicolon;
Identifier :: token.Identifier;
Location :: token.Location;

Parameter_info :: struct {
	name : string,
	type : string,
	type_type : Type_type,
	default_value : string, //if "" there is no default value.
	default_value_type : Type_type,
}

Struct_member_info :: struct {
	name : string,
	type : string,
	type_type : Type_type,
	location : Location,
}

Struct_info :: struct {
	name : string,
	members : []Struct_member_info,
	location : token.Location,
}

Global_info :: struct {
	name : string,
	
	type : string,
	type_type : Type_type,
	
	qualifier : Storage_qualifiers,
	
	is_unsized_array : bool,
	sized_array_length : int,
	
	location : token.Location,
}

Function_body_info :: struct {
	//??
	block : Block,
}

Function_info :: struct {
	name : string,
	annotation : Annotation_type,
	
	inputs : []Parameter_info,
	output : string,
	output_type : Type_type,
	
	body_start_token : int,
	body_end_token : int,
	
	body : Function_body_info,
	
	compute_dim : [3]int,
	location : token.Location,
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Primitive_kind :: enum {
	_bool,	//b8
	_i32,	//i32
	_u32,	//u32
	_f32,	//f32
	_f64, 	//f64
	
	// Vector Types
	_vec2,	   // GLSL 1.00+ 
	_vec3,	   // GLSL 1.00+ 
	_vec4,	   // GLSL 1.00+ 
	_ivec2,	  // GLSL 1.30+ 
	_ivec3,	  // GLSL 1.30+
	_ivec4,	  // GLSL 1.30+ 
	_uvec2,	  // GLSL 1.30+ 
	_uvec3,	  // GLSL 1.30+
	_uvec4,	  // GLSL 1.30+
	_bvec2,	  // GLSL 1.00+
	_bvec3,	  // GLSL 1.00+
	_bvec4,	  // GLSL 1.00+
	_dvec2,	   // GLSL 4.00+
	_dvec3,	   // GLSL 4.00+
	_dvec4,	   // GLSL 4.00+
	
	// Matrix Types
	_mat2,	   // GLSL 1.10+
	_mat3,	   // GLSL 1.10+
	_mat4,	   // GLSL 1.10+
	_mat2x3,	 // GLSL 1.50+
	_mat2x4,	 // GLSL 1.50+
	_mat3x2,	 // GLSL 1.50+
	_mat3x4,	 // GLSL 1.50+
	_mat4x2,	 // GLSL 1.50+
	_mat4x3,	 // GLSL 1.50+
	
	_dmat2,	   // GLSL 4.0+
	_dmat3,	   // GLSL 4.0+
	_dmat4,	   // GLSL 4.0+
	_dmat2x3,	 // GLSL 4.0+
	_dmat2x4,	 // GLSL 4.0+
	_dmat3x2,	 // GLSL 4.0+
	_dmat3x4,	 // GLSL 4.0+
	_dmat4x2,	 // GLSL 4.0+
	_dmat4x3,	 // GLSL 4.0+
}

Sampler_kind :: enum {
	_sampler1D,			   // GLSL 1.10
	_sampler2D,			   // GLSL 1.10
	_sampler3D,			   // GLSL 1.10
	_sampler1D_depth,		 // GLSL 1.10
	_sampler2D_depth,		 // GLSL 1.10
	_sampler_cube,			// GLSL 1.10
	_sampler2D_array,		 // GLSL 1.50
	_sampler2_multi,		  // GLSL 3.20
	_sampler_buffer,		  // GLSL 3.10
	// _samplerCubeArray,	 // GLSL 4.00 (commented out for being too new and weird)

	_sampler1D_int,		   // GLSL 1.30
	_sampler2D_int,		   // GLSL 1.30
	_sampler3D_int,		   // GLSL 1.30
	_sampler_cube_int,		// GLSL 1.30
	_sampler2D_array_int,	 // GLSL 3.00
	_sampler2_multi_int,	  // GLSL 3.20
	_sampler_buffer_int,	  // GLSL 3.10
	// _sampler_cube_array_int,// GLSL 4.00 (commented out for being too new and weird)

	_sampler1D_uint,		  // GLSL 1.30
	_sampler2D_uint,		  // GLSL 1.30
	_sampler3D_uint,		  // GLSL 1.30
	_sampler_cube_uint,	   // GLSL 1.30
	_sampler2D_array_uint,	// GLSL 3.00
	_sampler2_multi_uint,	 // GLSL 3.20
	_sampler_buffer_uint,	 // GLSL 3.10
	// _sampler_cube_array_uint// GLSL 4.00 (commented out for being too new and weird)
};

Type_type :: union {
	Primitive_kind,
	Sampler_kind,
	^Struct_info,
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Parse_error :: struct {
	message : string,
	token : token.Location,
}

State_infos :: struct {
	globals : [dynamic]^Global_info,
	functions : [dynamic]^Function_info,
	structs : [dynamic]^Struct_info,
}

@(private="file")
State_token :: struct {
	errors : [dynamic]Parse_error,
	tokens : []Token,
	done : bool,
	cur_tok : int,
	t_next : Token,
}

@(private="file")
State :: struct {
	using _ : State_infos,
	using _ : State_token,
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

tprint_parse_error :: proc (err : Parse_error) -> string {
	return fmt.tprintf("%v(%v) Parse error : %v, got '%v'", err.token.file, err.token.line, err.message, err.token.source);	
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@require_results
parse :: proc (_tokens : [][dynamic]Token) -> (State_infos, []Parse_error) {
	
	//////////////////// PARSE GLOBALS, FUNCTIONS DECLARATION AND STRUCTS ////////////////////
	
	file_states : [dynamic]State;
	defer {
		for s in file_states {
			destroy_state(s);
		}
		delete(file_states);
	}
	
	//First parse, this will turn tokens into variables and expressions and such for globals, functions and structs.
	for __tokens in _tokens {
		using state : State;
		state.tokens = __tokens[:];
		
		for !done {
			t : Token;
			t, done = next_token(&state);
			
			#partial switch v in t.type {
				
				case token.Comment, token.Multi_line_comment: {
					//TODO, we want to add the comments to the GLSL files too! thing before should be before and on the same line on the same line.
					panic("Comments are not handled here");
				}
				case token.Qualifier: {
					t_next, done = next_token(&state);
					global_name : string;
					type_name : string;
					is_unsized_array : bool;
					sized_array_length : int = 1;
					location := t_next.origin;
					
					if _, ok := t_next.type.(token.Identifier); ok {
						global_name = t_next.origin.source;
					}
					else {
						emit_error1(&state, "Expected identifier (name) in global declaration.", t_next);
						continue;
					}
					
					t_next, done = next_token(&state); 
					if _, ok := t_next.type.(token.Colon); ok {
					} else {
						emit_error1(&state, "Expected ':' after identifer (name) in global declaration.", t_next);
						continue;
					} 
					
					t_next, done = next_token(&state);
					if p, ok := t_next.type.(token.Sqaure_begin); ok {
						
						t_next, done = next_token(&state);
						
						if p, ok := t_next.type.(token.Sqaure_end); ok {
							//unsized
							is_unsized_array = true;
							t_next, done = next_token(&state);
						}
						else if i, ok := t_next.type.(token.Integer_literal); ok {
							//Sized array
							sized_array_length = cast(int)i.value;
							
							t_next, done = next_token(&state);
							if  p, ok := t_next.type.(token.Sqaure_end); ok {
							} else {
								emit_error1(&state, "Expected a closing ']' in global declaration.", t_next);
								continue;
							}
							
							t_next, done = next_token(&state);
						}
						else {
							emit_error1(&state, "Expected a identifier (type) or '[' after ':' in global declaration.", t_next);
							continue;
						}
						
					}
					if tn, ok := t_next.type.(token.Identifier); ok {
						type_name = t_next.origin.source;
					}
					else {
						emit_error1(&state, "Expected a identifier (type) or '[' after ':' in global declaration.", t_next);
						continue;
					}
					
					t_next, done = next_token(&state);
					if _, ok := t_next.type.(token.Semicolon); ok {
					} else {
						emit_error1(&state, "Expected a ';' at the end of global declaration.", t_next);
						continue;
					}
					
					assert(v.type != nil);
					append(&globals, new_clone(Global_info{
						global_name,		//name
						type_name,			//type
						nil,				//type_type
						v.type,				//qualifier
						is_unsized_array,	//is_unsized_array
						sized_array_length,	//sized_array_length
						location,			//location
					}));
				}
				case token.Identifier: {
					
					t_next = t;
					res, failed := parse_struct_or_proc(&state);
					
					switch &r in res {
						
						case Function_info: {
							append(&functions, new_clone(r));
						}
						case Struct_info: {
							append(&structs, new_clone(r));
						}
					}
				}
				case token.Annotation: {
					
					compute_dim : [3]int;
					
					t_next, done = next_token(&state);
					if v.type == .compute {
						used_comma_sperator : bool = false;
						
						if p, ok := t_next.type.(token.Paren_begin); ok {	
						} else {
							emit_error1(&state, "Expected '(' after compute annotation.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state);
						if i, ok := t_next.type.(token.Integer_literal); ok {
							compute_dim.x = cast(int)i.value;
						}
						else {
							emit_error1(&state, "Expected integer literal, so that the format is @compute(x,y,z), failed at x.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state);
						if _, ok := t_next.type.(token.Comma); ok {
							used_comma_sperator = true;
							t_next, done = next_token(&state);
						}
						
						if i, ok := t_next.type.(token.Integer_literal); ok {
							compute_dim.y = cast(int)i.value;
						}
						else {
							emit_error1(&state, "Expected integer literal, so that the format is @compute(x,y,z), failed at y.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state);
						if _, ok := t_next.type.(token.Comma); ok {
							if !used_comma_sperator { 
								emit_error1(&state, "Expected no ',' sperator. The @compute annotation must use all commas or all spaces for sperator, they may not be mixed.", t_next);
								continue;
							}
							t_next, done = next_token(&state);
						}
						else {
							if used_comma_sperator {
								emit_error1(&state, "Expected a ',' sperator. The @compute annotation must use all commas or all spaces for sperator, they may not be mixed.", t_next);
								continue;
							}
						}
						
						if i, ok := t_next.type.(token.Integer_literal); ok {
							compute_dim.z = cast(int)i.value;
						}
						else {
							emit_error1(&state, "Expected integer literal, so that the format is @compute(x,y,z), failed at z.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state);
						if p, ok := t_next.type.(token.Paren_end); ok {
						} else {
							emit_error1(&state, "Expected ')' in @compute annotation.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state);
					}
					
					res, failed := parse_struct_or_proc(&state);
					
					if failed {
						emit_error1(&state, "Failed to parse struct or procedure", t);
						continue;
					}
					
					switch &r in res {
						
						case Function_info: {
							
							r.compute_dim = compute_dim;
							r.annotation = v.type;
							
							assert(r.location != {}, "location is nil");
							append(&functions, new_clone(r));
							
						}
						case Struct_info: {
							emit_error1(&state, "Expected procedure after annotation, but recived struct definition.", t);
							continue;
						}
					}
				}
				case: {
					
					if t == {} {
						continue;
					}
					
					emit_error1(&state, "Unexpected token!", t);
					continue;
				}
			}
		}
		
		//log.logf(.Info, "Found globals : %#v\n", globals);
		//log.logf(.Info, "Found functions : %#v\n", functions);
		//log.logf(.Info, "Found structs : %#v\n", structs);
		
		append(&file_states, state);
	}
	
	//////////////////////////////////////// RESOLVE TYPES ////////////////////////////////////////
	
	//This is the secound pass, where we resolve all types for globals, functions and structs.
	errs : [dynamic]Parse_error;	
	existing_names : map[string]token.Location; //for all structs, globlas and functions.
	state2 : State_infos;
	{
		using state2;
		//////////////////// MERGE THE SOURCES, resolve struct types ////////////////////		
		
		////// FIND ALL STRUCT NAMES //////	
		existing_structs : map[string]token.Location;
		
		{//Check for name collision
			
			for state in file_states {
				for s in state.structs {
					
					if s.name in existing_structs || s.name in existing_names {
						other := existing_structs[s.name];
						emit_error2(&errs, s.location, "Names collide at %v(%v) and ", other.file, other.line);
						continue;
					}
					else if is_name_buildin(s.name) {
						other := existing_structs[s.name];
						emit_error2(&errs, s.location, "Name collides with buildin type");
						continue;
					}
					else {
						existing_structs[s.name] = s.location;
						existing_names[s.name] = s.location;
					}
				}
			}
		}
		
		{/////////// FIND STRUCT DEPENDENCIES AND PARSE STRUCTS ///////////
			unparsed_structs : map[string]^Struct_info;
			defer delete(unparsed_structs);
			
			parsed_structs : map[string]^Struct_info; //This is here for faster lookups
			defer delete(parsed_structs);
			
			for state in file_states {
				for s in state.structs {
					unparsed_structs[s.name] = s;
				}
			}
			
			known_structs : map[string]token.Location;
			
			last_len := -1;
			for last_len != len(unparsed_structs) { //Keep going until we can remove no more structs.
				
				last_len = len(unparsed_structs);
				
				for key, unparsed in unparsed_structs {
					
					all_types_resolved : bool = true;
					
					for &member in unparsed.members {
						
						resolved_type : Type_type;
						
						btype := resolve_type_from_type_name({}, member.type);
						
						if btype != nil {
							//Set the type
							resolved_type = btype;
						}
						else {
							if member.type in existing_structs {
								//Aha the struct includes another struct
								
								if member.type in parsed_structs {
									//Then we can finish it
									resolved_type = parsed_structs[member.type];
								}
								else {
									//Come back later when the struct is known.
									//That do nothing
									resolved_type = nil;
								}
							}
							else {
								//Could not resolve type
								emit_error2(&errs, unparsed.location, fmt.tprintf("The member %v has an unknown type %v.", member.name, member.type));
								return {}, errs[:];
							}
						}
						
						if resolved_type == nil {
							all_types_resolved = false;
							break;
						}
						
						member.type_type = resolved_type; //Place the resolved type on the type.
					}
					
					if all_types_resolved {
						delete_key(&unparsed_structs, key);
						append(&state2.structs, unparsed);
						parsed_structs[unparsed.name] = unparsed;
					}
				}
			}
			
			if len(unparsed_structs) != 0 {
				for name, unparsed in unparsed_structs {
					emit_error2(&errs, unparsed.location, "Found structs with circular dependencies!");
				}
				return {}, errs[:];
			}
		}
		
		{/////////// GLOBALS ///////////
			//Check if names collides with any struct names and if they collide with any other global name in the same file.
			for state in file_states {
				local_existing_global_names : map[string]token.Location; //in same file
				defer delete(local_existing_global_names);
				
				for g in state.globals {
					if g.name in existing_names {
						
						emit_error2(&errs, g.location, "Global name '%s' collides with struct name", g.name);
						return {}, errs[:];
					}
					if g.name in local_existing_global_names {
						
						emit_error2(&errs, g.location, "Global name '%s' collides with other global in same file, this is not allowed. Names may only collide if they are not in the same file.", g.name);
						return {}, errs[:];
					}
					
					local_existing_global_names[g.name] = g.location;
				}
			}
			
			parsed_globals : map[string]^Global_info;
			
			//Then merge the globals, their name may collide, but should be same type if they do.		
			for state in file_states {
				for g in state.globals {
					
					if g.name in existing_names {
						assert(g.name in parsed_globals);
						other := parsed_globals[g.name];
						if g.is_unsized_array != other.is_unsized_array || g.qualifier != other.qualifier || g.sized_array_length != g.sized_array_length {
							emit_error2(&errs, g.location, "Global name '%s' collides with other global but does not share the same type", g.name);
							continue;
						}
					}
					
					existing_names[g.name] = g.location;
					
					type := resolve_type_from_type_name(state2, g.type);
					
					if type == nil {
						emit_error2(&errs, g.location, "Type '%v' is not valid", g.type);
					}
					
					g.type_type = type;
					
					assert(g.qualifier != nil);
					parsed_globals[g.name] = g;
					append(&state2.globals, g);
				}
			}
		}
		
		{ /////////// FUNCTION HEADERS ///////////
			
			//Then merge functions, they may not collide.
			for state in file_states {
				for f in state.functions {
					
					//Check some stuff about the function.
					#partial switch f.annotation {
						case .custom: {
							emit_error2(&errs, f.location, "Custom annotations not supported. The annotation must be one of the following %#v\n", type_info_of(token.Annotation));
							continue;
						}
						case .none: {
							
						}
						case: {
							if len(f.inputs) != 0 {
								emit_error2(&errs, f.location, "The method '%v' with annotation '%v' may not have input parameters", f.name, f.annotation);
								continue;
							}
							else if f.output != "" {
								emit_error2(&errs, f.location, "The method '%v' with annotation '%v' may not have a return value", f.name, f.annotation);
								continue;
							}
							else if f.name in existing_names {
								emit_error2(&errs, f.location, "The procedure '%v' collides with other procedure.", f.name, f.annotation);
								continue;
							}
						}
					}
					
					for &input, i in f.inputs {
											
						input.type_type = resolve_type_from_type_name(state2, input.type);
						input.default_value_type = resolve_type_from_type_name(state2, input.default_value);
						
						log.warnf("input.type_type : %v", input.type_type);
						
						if input.type_type == nil {
							emit_error2(&errs, f.location, "The parameter '%v' has an unknown type '%v'", input.name, f.name, input.type);
						}
					}
					
					output : Type_type;
					
					if f.output != "" {	
						output = resolve_type_from_type_name(state2, f.output);
						
						if output == nil {
							emit_error2(&errs, f.location, "The return type '%v' is unknown", f.output);
						}
					}
					
					f.output_type = output;
					
					existing_names[f.name] = f.location;
					append(&state2.functions, f);
				}
			}
		}
	}
	
	{ //Parse function body
		using state2;
		
		for state in file_states {
			for &f in state.functions {
				
				assert(f.name in existing_names);
				
				body := parse_block(state.tokens[f.body_start_token:f.body_end_token], &errs);
				f.body = body;
			}
		}
	}
	
	if len(errs) == 0 {
		//fmt.printf("Parsed : %#v\n", state2);
	}
	
	return state2, errs[:];
}

destroy_parse_errors :: proc (errs : []Parse_error) {
	
	for e in errs {
		delete(e.message);
	}
	delete(errs);
}

@(private="file")
destroy_state :: proc (using s : State, loc := #caller_location) {
	delete(globals, loc = loc);	
	delete(functions, loc = loc);
	delete(structs, loc = loc);
}

@(private="file")
is_name_buildin :: proc (name : string) -> (bool) {
	
	if _, ok := reflect.enum_from_name(Primitive_kind, fmt.tprintf("_%v", name)); ok {
		return true;
	}
	
	if _, ok := reflect.enum_from_name(Sampler_kind, fmt.tprintf("_%v", name)); ok {
		return true;
	}
	
	return false;
}

@(private="file")
resolve_type_from_type_name :: proc (state : State_infos, identifier : string) -> Type_type {
	
	for t in reflect.enum_fields_zipped(Primitive_kind) {
		if t.name[1:] == identifier {
			p := cast(Primitive_kind)t.value;
			return Type_type(p);
		}
	}
	
	for t in reflect.enum_fields_zipped(Sampler_kind) {
		if t.name[1:] == identifier {
			p := cast(Sampler_kind)t.value;
			return Type_type(p);
		}
	}
	
	for s in state.structs {
		if s.name == identifier {
			return Type_type(s);
		}
	}
	
	return nil;
}

@(private="file")
next_token :: proc (using state : ^State_token) -> (tok : Token, is_done : bool) {
	
	if cur_tok == len(tokens) - 1 {
		is_done = true;
	}
	
	if cur_tok > len(tokens) - 1 {
		return {}, true;
	}
	
	cur_tok += 1;
	tok = tokens[cur_tok - 1];
	
	{ //If we are about to return a comment, then don't skip ahead.
		_, is_comment := tok.type.(token.Comment);
		_, is_multi_comment := tok.type.(token.Multi_line_comment);
		
		if is_comment || is_multi_comment {
			tok, is_done = next_token(state);
		}
	}
	
	return;
}

@(private="file")
emit_error1 :: proc (state : ^State_token, msg : string, tok : token.Token, loc := #caller_location) {
	
	msg := strings.clone(msg);

	append(&state.errors, Parse_error{msg, tok.origin});
	
	log.error(tprint_parse_error(Parse_error{msg, tok.origin}), location = loc);
	
	is_done : bool;
	t_next : Token;
	
	for !is_done {
		t_next, is_done = next_token(state);
		_, ok := t_next.type.(Semicolon);
		if ok {
			return;
		}
	}
}

@(private="file")
emit_error2 :: proc (errs : ^[dynamic]Parse_error, origin : token.Location, msg : string, args: ..any, loc := #caller_location) {
	
	err_msg : string;
	if len(args) != 0 {
		err_msg = fmt.tprintf(msg, ..args);
	}
	else {
		err_msg = msg;
	}
	
	log.error(tprint_parse_error(Parse_error{err_msg, origin}), location = loc);
	append(errs, Parse_error{err_msg, origin});
}

@(private="file")
parse_struct_or_proc :: proc (using state : ^State) -> (res : union {Function_info, Struct_info}, failed : bool) {
	
	name : string; //Proc or struct name.
	origin := t_next.origin;
	
	if iden, ok := t_next.type.(Identifier); ok {
		name = t_next.origin.source;
	}
	else {
		emit_error1(state, "Expected identifier (name) after annotation.", t_next);
		return {}, true;
	}
	
	t_next, done = next_token(state);
	if iden, ok := t_next.type.(token.Colon); ok {	
	} else {
		emit_error1(state, "Expected ':' after procedure/struct name.", t_next);
		return {}, true;
	}
	
	t_next, done = next_token(state);
	if iden, ok := t_next.type.(token.Colon); ok {	
	} else {
		emit_error1(state, "Expected a second ':' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
		return {}, true;
	}
	
	is_proc : bool;
	
	t_next, done = next_token(state);
	if iden, ok := t_next.type.(Identifier); ok {
		if t_next.origin.source == "proc" {
			is_proc = true;
		}
		else if t_next.origin.source == "struct" {
			is_proc = false;
		}
		else {
		
			emit_error1(state, "Expected 'proc' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
			return {}, true;
		}
	} else {
		emit_error1(state, "Expected 'proc' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
		return {}, true;
	}
	
	if is_proc {
		
		inputs : [dynamic]Parameter_info;
		return_type : string;
		
		function_body_start_token_index : int;
		function_body_end_token_index : int;
		
		t_next, done = next_token(state);
		if p, ok := t_next.type.(token.Paren_begin); ok {
		} else {
			emit_error1(state, "Expected '(' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
			return {}, true;
		}
		
		is_done : bool = false;
		
		for !is_done {	
			
			t_next, done = next_token(state);
			if p, ok := t_next.type.(token.Paren_end); ok {
				is_done = true;
			}
			else {
				input_name : string;
				input_type : string;
				
				if _, ok := t_next.type.(token.Identifier); ok {
					input_name = t_next.origin.source;
				}
				else {
					emit_error1(state, "Expected identifer (parameter name)", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state);
				if _, ok := t_next.type.(token.Colon); ok {
				} else {
					emit_error1(state, fmt.tprintf("Expected ':' after parameter name %v.", input_name), t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state);
				if _, ok := t_next.type.(token.Identifier); ok {
					input_type = t_next.origin.source;
				}
				else {
					emit_error1(state, "Expected identifier (type) after ':'.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state);
				if _, ok := t_next.type.(token.Comma); ok {
				}
				else if  p, ok := t_next.type.(token.Paren_end); ok {
					is_done = true;
				}else {
					emit_error1(state, "Expected ',' or '}' after function parameter.", t_next);
					return {}, true;
				}
				
				append(&inputs, Parameter_info{input_name, input_type, nil, "", nil});
			}
		}
		
		t_next, done = next_token(state);
		if _, ok := t_next.type.(token.Proc_return_operator); ok {
			t_next, done = next_token(state);
			if _, ok := t_next.type.(token.Identifier); ok {
				return_type = t_next.origin.source;
			}
			t_next, done = next_token(state);
		}
		
		if p, ok := t_next.type.(token.Curly_begin); ok {
			//TODO no return value, process function body later.
			
			function_body_start_token_index = cur_tok;
			start_curly_token := t_next;
			
			curly_count : int = 1;
			for curly_count != 0 && !done {
				t_next, done = next_token(state);
				if p, ok := t_next.type.(token.Curly_begin); ok {
					curly_count += 1;
				}
				else if p, ok := t_next.type.(token.Curly_end); ok {
					curly_count -= 1;
				}
			}
			
			if curly_count != 0 {
				emit_error1(state, "Missing closing }", start_curly_token);
				return {}, true;
			}
			
			function_body_end_token_index = cur_tok-1;
		}
		else {
			emit_error1(state, "Expected '{' or '->' to fulfill format 'function_name :: proc(...) -> return_type {...}' in function declaration. The '-> return_type' part is optional.", t_next);
			return {}, true;
		}
		
		return Function_info{
			name,
			nil,	//annotation is set by caller
			inputs[:],
			return_type,
			nil,	//return type_type is resolved by caller
			function_body_start_token_index,
			function_body_end_token_index,
			{},		//Body is parsed later by caller.
			{},		//compute_dim is set by caller
			origin,
		}, false;
	}
	else {
		
		t_next, done = next_token(state);
		if p, ok := t_next.type.(token.Curly_begin); ok {
		}
		else {
			emit_error1(state, "Expected '{' after 'struct'.", t_next);
			return {}, true;
		}
		
		is_done : bool = false;
		struct_members : [dynamic]Struct_member_info;
		
		for !is_done {	
			t_next, done = next_token(state);
			member_start_token := t_next;
			if p, ok := t_next.type.(token.Curly_end); ok {
				is_done = true;
			}
			else {
				//something1 : u32,
				member_name : string;
				member_type : string;
				
				if iden, ok := t_next.type.(Identifier); ok {
					member_name = t_next.origin.source;	
				}
				else {
					emit_error1(state, "Expected identifier (name) for struct member.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state);
				if _, ok := t_next.type.(token.Colon); ok {
				} else {
					emit_error1(state, "Expected ':' after struct member name.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state);
				if iden, ok := t_next.type.(Identifier); ok {
					member_type = t_next.origin.source;	
				}
				else {
					emit_error1(state, "Expected identifier (type) after ':' for struct member.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state);
				if iden, ok := t_next.type.(token.Comma); ok {
				} else if p, ok := t_next.type.(token.Curly_end); ok {
					is_done = true;
				}
				else {
					emit_error1(state, "Expected seperator ',' or end of struct '}'.", t_next);
					return {}, true;
				}
				
				append(&struct_members, Struct_member_info{
					member_name,
					member_type,
					nil,						//Type resolved by caller
					member_start_token.origin,
				});
			}
		}
		
		assert(origin != {}, "location is nil");
		return Struct_info{
			name,
			struct_members[:],
			origin,
		}, false;
	}
	
	unreachable();
}






















//////////////////////////////////////// BLOCK PARSING ////////////////////////////////////////

Variable_declaration :: struct {
	lhs : string, //the name
	type : Type_type, //This can be resolved at this stage, because all types have been parsed.
	rhs : Maybe(Expression),
}

Call :: struct {
	called : string,		  // Function name (or reference to a Function)
	args   : []^Expression,	// List of arguments (expressions)
}

Assignment :: struct {
	lhs : ^Expression,   // The left-hand side (e.g., variable)
	rhs : ^Expression,   // The right-hand side (e.g., value or expression)
}

Unary_operator_kind :: enum {
	negation,	 // e.g., -a
	inversion,	// e.g., !a
	bitwise_not,  // e.g., ~a
}

Unary_operator :: struct {
	op	  : Unary_operator_kind,	// Operator like "-", "++", "!"
	operand : ^Expression,	  // The expression being operated on
}

Binary_operator_kind :: enum {
	add,		  // e.g., a + b
	subtract,	 // e.g., a - b
	multiply,	 // e.g., a * b
	divide,	   // e.g., a / b
	modulo,	   // e.g., a % b
	abs_modulo,   // e.g., a %% b
	logical_and,  // e.g., a && b
	logical_or,   // e.g., a || b
	bitwise_and,  // e.g., a & b
	bitwise_or,   // e.g., a | b
	bitwise_xor,  // e.g., a ^ b
	shift_left,   // e.g., a << b
	shift_right,  // e.g., a >> b
	equals,	   // e.g., a == b
	not_equals,   // e.g., a != b
	greater_than, // e.g., a > b
	less_than,	// e.g., a < b
	greater_eq,   // e.g., a >= b
	less_eq,	  // e.g., a <= b
}

Binary_operator :: struct {
	op	  : Binary_operator_kind, 
	left : ^Expression,	  // The expression being operated on
	right : ^Expression,	  // The expression being operated on
}

Return :: struct {
	value : Maybe(^Expression),
}

If :: struct {
	condition : Expression,	  // Condition to evaluate
	then_body : []^Statement,	 // Block of statements for the true branch
	else_body : Maybe([]^Statement),  // Optional else block
}

For :: struct { //Also used as a while
	init	  : Maybe(^Statement), // Initialization (e.g., Declaration or Assignment)
	condition : Maybe(Expression), // Loop condition
	increment : Maybe(Expression), // Increment step
	body	  : []Statement,	   // Loop body
}

Float_literal :: struct {
	value : f64,  // Could be int, float, string, bool, etc.
}

Int_literal :: struct {
	value : i128,  // Could be int, float, string, bool, etc.
}

Boolean_literal :: struct {
	value : bool,  // Could be int, float, string, bool, etc.
}

Variable :: struct {
	name : string,
	//scope : Maybe(Scope),  // Optional reference to the variable's scope
}

Expression :: union {
	Call,
	Assignment,
	Unary_operator,
	Binary_operator,
	Float_literal,
	Int_literal,
	Boolean_literal,
	Variable,
}

Statement :: struct {
	type : union {
		Variable_declaration,
		Expression, //Not legal but handled for better error messages
		Return,
		If,
		For,
		Block,
	},
	location : Location,
}

Symbol :: struct {}

Scope :: struct {
	parent	 : ^Scope,			  // Link to the parent scope (or `nil` if it's the global scope)
	symbols	: map[string]Symbol,   // Map from variable/function names to their metadata (Symbol)
}

Block :: struct {
	statements : []Statement,  // Ordered list of statements
	scope	  : Scope,		// Scope associated with the block
}

//Can handle 0 tokens, so passing 0 tokens is valid (TODO : not tested)
@(private="file")
parse_block :: proc (_tokens : []token.Token, errs : ^[dynamic]Parse_error) -> Function_body_info {
	
	using state : State_token;
	state.tokens = _tokens;
	
	block : Block;
	
	statements : [dynamic]Statement;
	
	for !done {
		t_next, done = next_token(&state);
		original_token := t_next;
		
		#partial switch t in t_next.type {
			
			case token.Identifier:
				//This is an assignment or declaration or control flow statement
				if t_next.origin.source == "if" {
					panic("TODO");
				}
				else if t_next.origin.source == "for" {
					panic("TODO");
				}
				else if t_next.origin.source == "break" {
					panic("TODO");
				}
				else if t_next.origin.source == "continue" {
					panic("TODO");
				}
				else if t_next.origin.source == "return" {
					
					expression_start_token := state.cur_tok;
					expression_end_token : int = -1;
					
					ok : bool;
					for !ok && !done {
						_, ok = t_next.type.(token.Semicolon);
						expression_end_token = state.cur_tok;
						if !ok {
							t_next, done = next_token(&state);
						}
					}
					
					if expression_end_token == -1 {
						emit_error2(errs, original_token.origin, "Missing ';' after return statement");
						continue;
					} else if expression_start_token != expression_end_token-1 {
						expression_tokens := state.tokens[expression_start_token:expression_end_token-1];
						expressions, err := parse_expression(expression_tokens);
						
						if err != {} {
							emit_error2(errs, err.token, err.message);
							continue;
						}
						
						if len(expressions) > 1 {
							emit_error2(errs, err.token, "There may only be one return value, this might change in the future, todo.");
							continue;
						}
						
						//Successfully parsed the expression
						append(&statements, Statement{Return{expressions[0]}, original_token.origin});
					}
					
				}
				else {
					//fmt.printf("handling token : %v", original_token);
				}
				
			case:
				//emit_error2(errs, t_next.origin, "Illegal token");
				//continue;
		}
	}
	
	block.statements = statements[:];
	
	return {block};
}

@(private="file")
Syntax_node :: struct {
	value : union{
		^Expression,
		Unary_operator_kind,
		Binary_operator_kind,
	},
	origin : Location,
}

//Must have at least one token
@(private="file")
parse_expression :: proc (_tokens : []token.Token) -> ([]^Expression, Parse_error) {
	assert(len(_tokens) >= 1, "Must have at least one token");
	
	using state : State_token;
	state.tokens = _tokens;
	
	//log.infof("Parse expression tokens : %#v", _tokens);
	
	syntax_nodes : [dynamic]Syntax_node;
	res : [dynamic]^Expression;
	
	first_token := _tokens[0];
	
	@require_results
	parse_syntax_nodes :: proc (syntax_nodes : []Syntax_node) -> (^Expression, Parse_error){
		
		if len(syntax_nodes) == 0 {
			//fmt.panicf("did not find any syntax nodes, syntax_nodes was: %#v", syntax_nodes);
			return {}, {};
		}
		
		//Handle unary first
		{
			
		}
		
		//Then handle binary operators
		res, err := parse_syntex_nodes_to_ast(syntax_nodes[:], max_precedence);
		
		if err != {} {
			return nil, err;
		}
		
		return res, {};
	}
	
	@require_results
	parse_default :: proc (using state : ^State_token, syntax_nodes : ^[dynamic]Syntax_node, res : ^[dynamic]^Expression, this_token, first_token : Token) -> Parse_error {
				
		#partial switch t in this_token.type {
			
			case token.Identifier: {
				this_exp := new(Expression);
				this_exp^ = Variable{this_token.origin.source};
				
				t_next, done = next_token(state);
				if done {
					append(syntax_nodes, Syntax_node{this_exp, this_token.origin});
					return {};
				}
				#partial switch v in t_next.type {
					case token.Paren_begin: {
						//This will be a function call
						
						parameters_start_token := state.cur_tok;
						parameters_end_token : int = -1;
						
						paren_cnt := 1;
						for (paren_cnt != 0) && !done {
							t_next, done = next_token(state);
							_, found_begin := t_next.type.(token.Paren_begin);
							if found_begin {
								paren_cnt += 1;
							}
							_, found_end := t_next.type.(token.Paren_end);
							if found_end {
								paren_cnt -= 1;
							}
							
							parameters_end_token = state.cur_tok;
						}
						
						assert(parameters_end_token != -1);
						
						parameter_tokens := state.tokens[parameters_start_token:parameters_end_token-1];
						params, err := parse_expression(parameter_tokens);
						
						if err != {} {
							return err;
						}
						
						exp := new(Expression);
						exp^ = Call{
							first_token.origin.source,
							params, 
						};
						
						append(syntax_nodes, Syntax_node{exp, t_next.origin});
					}
					case token.Addition_operator: {
						append(syntax_nodes, Syntax_node{this_exp, this_token.origin});
						append(syntax_nodes, Syntax_node{Binary_operator_kind.add, t_next.origin});
					}
					case token.Multiply_operator: {
						append(syntax_nodes, Syntax_node{this_exp, this_token.origin});
						append(syntax_nodes, Syntax_node{Binary_operator_kind.multiply, t_next.origin});
					}
					case token.Comma:{
						return parse_default(state, syntax_nodes, res, this_token, first_token);
					}
					case token.Semicolon:{
						fmt.panicf("Semicolon ';' is not allowed in an expression, got :", state.tokens);
					}
					case: {
						fmt.panicf("TODO %v", t_next);
					}
				}
			}
			case token.Paren_begin: {
				
				subexpression_start_token := state.cur_tok;
				subexpression_end_token : int = -1;
				
				paren_cnt := 1;
				for (paren_cnt != 0) && !done {
					t_next, done = next_token(state);
					_, found_begin := t_next.type.(token.Paren_begin);
					if found_begin {
						paren_cnt += 1;
					}
					_, found_end := t_next.type.(token.Paren_end);
					if found_end {
						paren_cnt -= 1;
					}
					subexpression_end_token = state.cur_tok;
				}
				
				subexpression_tokens := state.tokens[subexpression_start_token:subexpression_end_token-1];
				exps, err := parse_expression(subexpression_tokens);
				
				if err != {} {
					return err;
				}
				
				assert(len(exps) == 1);
				append(syntax_nodes, Syntax_node{exps[0], t_next.origin});
			}
			case token.Integer_literal: {
				
				//fmt.printf("Integer_literal was %v\n", original_token.);
				
				exp := new(Expression);
				exp^ = Int_literal{
					t.value, 
				};
				
				append(syntax_nodes, Syntax_node{exp, t_next.origin});
			}
			case token.Addition_operator: {
				append(syntax_nodes, Syntax_node{Binary_operator_kind.add, t_next.origin});
			}
			case token.Multiply_operator: {
				append(syntax_nodes, Syntax_node{Binary_operator_kind.multiply, t_next.origin});
			}
			case token.Comma: {
				
				exp, err := parse_syntax_nodes(syntax_nodes[:]);
				
				if err != {} {
					return err;
				}
				
				append(res, exp);
				clear(syntax_nodes);
			}
			case token.Semicolon:
				fmt.panicf("Semicolon ';' is not allowed in an expression, got : %#v", state.tokens);
			case: {
				return Parse_error{
					"Failed to parse expression",
					t_next.origin, 
				};
			}
		}
		
		return {};
	}
	
	//GO though tokensd find "syntax_nodes"	
	for !done {
		t_next, done = next_token(&state);
		
		//fmt.printf("original_token : %v\n", original_token);
		//assert(original_token.origin.source != "4");
		err := parse_default(&state, &syntax_nodes, &res, t_next, first_token);
		
		if err != {}{
			return nil, err;
		}
	}
	
	exp, err := parse_syntax_nodes(syntax_nodes[:]);
	
	if err != {} {
		return nil, err;
	}
	
	append(&res, exp);
	
	return res[:], {};
}

max_precedence :: 6;
precedence_table := [Binary_operator_kind]int {
	.multiply		= 6,	// e.g., a * b
	.divide		  	= 6,	// e.g., a / b
	.modulo		  	= 6,	// e.g., a % b
	.abs_modulo	  	= 6,	// e.g., a /% b
	
	.add			= 5,	// e.g., a + b
	.subtract		= 5,	// e.g., a - b

	.shift_left	  	= 4,	// e.g., a << b
	.shift_right	= 4,	// e.g., a >> b
	
	.bitwise_and	= 3,	// e.g., a & b
	.bitwise_xor	= 3,	// e.g., a ^ b
	.bitwise_or	  	= 3,   // e.g., a | b

	.logical_and	= 2,   // e.g., a && b
	.logical_or	  	= 2,   // e.g., a || b
	
	.greater_than	= 1,	// e.g., a > b
	.less_than	   	= 1,	// e.g., a < b
	.greater_eq	  	= 1,	// e.g., a >= b
	.less_eq		= 1,	// e.g., a <= b
	.equals		  	= 1,	// e.g., a == b
	.not_equals	  	= 1,	// e.g., a != b
}

//This implementation is not the best, might rework.
@(private="file")
parse_syntex_nodes_to_ast :: proc (syntax_nodes : []Syntax_node, precedence : int) -> (^Expression, Parse_error) {
	assert(len(syntax_nodes) != 0, "syntax_nodes is 0");
	
	{
		new_syntax_nodes : [dynamic]Syntax_node;
		defer delete(new_syntax_nodes);
		
		for i := 0; i < len(syntax_nodes); i += 1 {
		
			s := syntax_nodes[i];
			
			switch v in s.value {
				case ^Expression: {
					
					if len(new_syntax_nodes) != 0 {
						if v, ok := new_syntax_nodes[len(new_syntax_nodes)-1].value.(^Expression); ok {
							fmt.panicf("There are two expressions in a row, syntax_nodes : %#v", syntax_nodes);
						}
					}
					
					//Do nothing
					append(&new_syntax_nodes, s);
				}
				case Binary_operator_kind: {
					
					assert(precedence_table[v] <= precedence);
					if precedence_table[v] == precedence {
						//Do the thing
						
						lhs : ^Expression;
						rhs : ^Expression;
						
						if len(new_syntax_nodes) == 0 {
							return nil, Parse_error{
								"Missing left side of binary operator",
								s.origin, 
							};
						}
						lhs_node := pop(&new_syntax_nodes); //Undo adding the last expression
						if l, ok := lhs_node.value.(^Expression); ok {
							lhs = l;	
						}
						else {
							return nil, Parse_error{
								fmt.tprintf("Expected an expression to the left of binary operator %v", s.origin.source),
								lhs_node.origin, 
							};
						}
						
						i += 1;
						if len(syntax_nodes) < i {
							return nil, Parse_error{
								"Missing right side of binary operator",
								s.origin, 
							};
						}						
						rhs_node := syntax_nodes[i];
						if r, ok := lhs_node.value.(^Expression); ok {
							rhs = r;
						}
						else {
							if len(new_syntax_nodes) <= i {
								return nil, Parse_error{
									fmt.tprintf("Expected an expression to the right of binary operator %v", s.origin.source),
									rhs_node.origin, 
								};
							}
						}
						
						assert(lhs != nil);
						assert(rhs != nil);
						exp := new(Expression)
						exp^ = Binary_operator {
							v,
							lhs,
							rhs,
						}
						
						append(&new_syntax_nodes, Syntax_node{exp, s.origin});
					}
					else {
						append(&new_syntax_nodes, s);
					}
				}			
				case Unary_operator_kind: {
					panic("did not expect unary operator");
				}
			}
		}
		
		if (precedence == 0 || len(new_syntax_nodes) == 1) {
			fmt.assertf(len(new_syntax_nodes) == 1, "there is more(or less) then one resulting expression! new_syntax_nodes : %#v\nsyntax_nodes : %#v", new_syntax_nodes, syntax_nodes);
			if e, ok := new_syntax_nodes[0].value.(^Expression); ok {
				return e, {};
			}
			else {
				panic("Did not evalue to an expression");
			}
		}
		else {
			return parse_syntex_nodes_to_ast(new_syntax_nodes[:], precedence-1);
		}
	}
	
	unreachable();
}

