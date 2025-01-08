package flang_parser;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:log"
import "core:path/slashpath"

import "../token"

Token :: token.Token;
Storage_qualifiers :: token.Storage_qualifiers;
Annotation_type :: token.Annotation_type;
Semicolon :: token.Semicolon;
Identifier :: token.Identifier;
Location :: token.Location;

Variable_info :: struct {
	name : string,
	type : string,
}

Struct_member_info :: struct {
	name : string,
	type : string,
}

Struct_info :: struct {
	name : string,
	
	members : []Struct_member_info,
	location : token.Location,
}

Global_info :: struct {
	name : string,
	type : string,
	qualifier : Storage_qualifiers,
	
	is_unsized_array : bool,
	sized_array_length : int,
	location : token.Location,
}

Function_info :: struct {
	name : string,
	annotation : Annotation_type,
	
	inputs : []Variable_info,
	output : string,
	
	body_start_token : int,
	body_end_token : int,
	
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
	_vec2,       // GLSL 1.00+ 
	_vec3,       // GLSL 1.00+ 
	_vec4,       // GLSL 1.00+ 
	_vec2i,      // GLSL 1.30+ 
	_vec3i,      // GLSL 1.30+
	_vec4i,      // GLSL 1.30+ 
	_vec2u,      // GLSL 1.30+ 
	_vec3u,      // GLSL 1.30+
	_vec4u,      // GLSL 1.30+
	_vec2b,      // GLSL 1.00+
	_vec3b,      // GLSL 1.00+
	_vec4b,      // GLSL 1.00+
	_vec2d,       // GLSL 4.00+
	_vec3d,       // GLSL 4.00+
	_vec4d,       // GLSL 4.00+
	
	// Matrix Types
	_mat2,       // GLSL 1.10+
	_mat3,       // GLSL 1.10+
	_mat4,       // GLSL 1.10+
	_mat2x3,     // GLSL 1.50+
	_mat2x4,     // GLSL 1.50+
	_mat3x2,     // GLSL 1.50+
	_mat3x4,     // GLSL 1.50+
	_mat4x2,     // GLSL 1.50+
	_mat4x3,     // GLSL 1.50+
	
	_mat2d,       // GLSL 4.0+
	_mat3d,       // GLSL 4.0+
	_mat4d,       // GLSL 4.0+
	_mat2x3d,     // GLSL 4.0+
	_mat2x4d,     // GLSL 4.0+
	_mat3x2d,     // GLSL 4.0+
	_mat3x4d,     // GLSL 4.0+
	_mat4x2d,     // GLSL 4.0+
	_mat4x3d,     // GLSL 4.0+
}

Sampler_kind :: enum {
    _sampler1D,               // GLSL 1.10
    _sampler2D,               // GLSL 1.10
    _sampler3D,               // GLSL 1.10
    _sampler1D_depth,         // GLSL 1.10
    _sampler2D_depth,         // GLSL 1.10
    _sampler_cube,            // GLSL 1.10
    _sampler2D_array,         // GLSL 1.50
    _sampler2_multi,          // GLSL 3.20
    _sampler_buffer,          // GLSL 3.10
    // _samplerCubeArray,     // GLSL 4.00 (commented out for being too new and weird)

    _sampler1D_int,           // GLSL 1.30
    _sampler2D_int,           // GLSL 1.30
    _sampler3D_int,           // GLSL 1.30
    _sampler_cube_int,        // GLSL 1.30
    _sampler2D_array_int,     // GLSL 3.00
    _sampler2_multi_int,      // GLSL 3.20
    _sampler_buffer_int,      // GLSL 3.10
    // _sampler_cube_array_int,// GLSL 4.00 (commented out for being too new and weird)

    _sampler1D_uint,          // GLSL 1.30
    _sampler2D_uint,          // GLSL 1.30
    _sampler3D_uint,          // GLSL 1.30
    _sampler_cube_uint,       // GLSL 1.30
    _sampler2D_array_uint,    // GLSL 3.00
    _sampler2_multi_uint,     // GLSL 3.20
    _sampler_buffer_uint,     // GLSL 3.10
    // _sampler_cube_array_uint// GLSL 4.00 (commented out for being too new and weird)
};

Type_type :: union {
	Primitive_kind,
	Sampler_kind,
	Struct,
}

Struct_member :: struct {
	name : string,
	type : Type_type,
}

//////////// Parsed version of info ////////////
Struct_data :: struct { //without the name, name is stored in map
	members : [dynamic]Struct_member,
	location : token.Location,
}

Global_data :: struct {
	type : Type_type,
	qualifier : Storage_qualifiers,
	is_unsized_array : bool,
	sized_array_length : int,
	location : token.Location,
}

Parameter_data :: struct {
	name : string,
	type : Type_type,
	//TODO default value
}

Function_body_data :: struct {
	//??
}

Function_parameter :: struct {
	name : string,
	type : Type_type,
	default_value : Maybe(any),
}

Function_data :: struct {
	annotation : Annotation_type,
	
	inputs : []Parameter_data,
	output : Type_type,
	
	function_body : Function_body_data,
	
	compute_dim : [3]int,
	location : token.Location,
}

Struct :: ^Struct_data;
Function :: ^Function_data;
Global :: ^Global_data;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

tprint_parse_error :: proc (err : Parse_error) -> string {
	return fmt.tprintf("%v(%v) Parse error : %v, got '%v'", err.token.file, err.token.line, err.message, err.token.source);	
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Perser_result :: struct {
	
}

Parse_error :: struct {
	message : string,
	token : token.Location,
}

@require_results
parse :: proc (_tokens : [][dynamic]Token) -> ([]Parse_error) {
	
	//////////////////// PARSE GLOBALS, FUNCTIONS DECLARATION AND STRUCTS ////////////////////
	
	states : [dynamic]State;
	defer {
		for s in states {
			destroy_state(s);
		}
		delete(states);
	}
	
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
					
					append(&globals, Global_info{
						global_name,
						type_name,
						v.type,
						is_unsized_array,
						sized_array_length,
						location,
					})
				}
				case token.Identifier: {
					
					t_next = t;
					res, failed := parse_struct_or_proc(&state);
					
					switch &r in res {
						
						case Function_info: {
							append(&functions, r);
						}
						case Struct_info: {
							append(&structs, r);
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
						continue;
					}
					
					switch &r in res {
						
						case Function_info: {
							
							r.compute_dim = compute_dim;
							r.annotation = v.type;
							
							assert(r.location != {}, "location is nil");
							append(&functions, r);
							
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
		
		append(&states, state);
	}
	
	errs := make([dynamic]Parse_error);
	
	existing_names : map[string]token.Location; //for all structs, globlas and functions.	
	
	state2 : State2;
	{
		using state2;
		//////////////////// MERGE THE SOURCES, resolve struct types ////////////////////		
		
		////// FIND ALL STRUCT NAMES //////	
		existing_structs : map[string]token.Location;
		
		buildin_names := get_buildin_names();
		
		{//Check for name collision
			
			for state in states {
				for s in state.structs {
					
					if s.name in existing_structs || s.name in existing_names {
						other := existing_structs[s.name];
						emit_error2(&errs, s.location, "Names collide at %v(%v) and ", other.file, other.line);
						//return errs[:];
					}
					else if s.name in buildin_names  {
						other := existing_structs[s.name];
						emit_error2(&errs, s.location, "Name collides with buildin type");
						//return errs[:];
					}
					else {
						existing_structs[s.name] = s.location;
						existing_names[s.name] = s.location;
					}
				}
			}
		}
		
		{/////////// FIND STRUCT DEPENDENCIES AND PARSE STRUCTS ///////////
			unparsed_structs : map[string]Struct_info;
			
			for state in states {
				for s in state.structs {
					unparsed_structs[s.name] = s;
				}
			}
			
			known_structs : map[string]token.Location;
			
			last_len := -1;
			for last_len != len(unparsed_structs) { //Keep going until we can remove no more structs.
				
				last_len = len(unparsed_structs);
				
				for key, unparsed in unparsed_structs {
					
					new_struct : Struct = new(Struct_data);
					new_struct.location = unparsed.location;
					
					all_types_resolved : bool = true;
					
					for member in unparsed.members {
						
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
								return errs[:];
							}
						}
						
						if resolved_type == nil {
							all_types_resolved = false;
							break;
						}
						
						append(&new_struct.members, Struct_member {
							name = member.name,
							type = resolved_type,
						});
					}
					
					if all_types_resolved {
						delete_key(&unparsed_structs, key);
						parsed_structs[unparsed.name] = new_struct;
					}
				}
			}
			
			if len(unparsed_structs) != 0 {
				for name, unparsed in unparsed_structs {
					emit_error2(&errs, unparsed.location, "Found structs with circular dependencies!");
				}
				return errs[:];
			}
		}
		
		/////////// GLOBALS ///////////
		//Check if names collides with any struct names and if they collide with any other global name in the same file.
		for state in states {
			local_existing_global_names : map[string]token.Location; //in same file
			defer delete(local_existing_global_names);
			
			for g in state.globals {
				if g.name in existing_names {
					
					emit_error2(&errs, g.location, "Global name '%s' collides with struct name", g.name);
					return errs[:];
				}
				if g.name in local_existing_global_names {
					
					emit_error2(&errs, g.location, "Global name '%s' collides with other global in same file, this is not allowed. Names may only collide if they are not in the same file.", g.name);
					return errs[:];
				}
				
				local_existing_global_names[g.name] = g.location;
			}
		}
		
		//Then merge the globals, their name may collide, but should be same type if they do.		
		for state in states {
			for g in state.globals {
				
				if g.name in existing_names {
					other := parsed_globals[g.name];
					if g.is_unsized_array != other.is_unsized_array || g.qualifier != other.qualifier || g.sized_array_length != g.sized_array_length {
						emit_error2(&errs, g.location, "Global name '%s' collides with other global but does not share the same type", g.name);
						return errs[:];
					}
				}
				
				existing_names[g.name] = g.location;
				
				new_global := new(Global_data);
				
				type := resolve_type_from_type_name(state2, g.type);
				
				if type == nil {
					emit_error2(&errs, g.location, "Type '%v' is not valid", g.type);
				}
				
				new_global^ = Global_data {
					type = type,
					qualifier = g.qualifier,
					is_unsized_array = g.is_unsized_array,
					sized_array_length = g.sized_array_length,
					location = g.location,
				}
				
				parsed_globals[g.name] = new_global;
			}
		}
		
		//Then merge functions, they may not collide.
		for state in states {
			for f in state.functions {
				
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
						else if f.name in parsed_functions {
							emit_error2(&errs, f.location, "The method '%v' with annotation '%v' may not have a return value", f.name, f.annotation);
							continue;
						}
					}
				}
				
				inputs := make([]Parameter_data, len(f.inputs));
				
				for input, i in f.inputs {
					
					inp : Parameter_data = {
						input.name,
						resolve_type_from_type_name(state2, input.type),
					}
					
					if inp.type == nil {
						emit_error2(&errs, f.location, "The parameter '%v' has an unknown type '%v'", input.name, f.name, input.type);
					}
					
					inputs[i] = inp;
				}
				
				output : Type_type;
				
				if f.output != "" {	
					output = resolve_type_from_type_name(state2, f.output);
					
					if output == nil {
						emit_error2(&errs, f.location, "The return type '%v' is unknown", f.output);
					}
				}
				
				func := new(Function_data); 
				func^ = Function_data {
					f.annotation,
					inputs,
					output,
					{}, //Will be found later.
					f.compute_dim,
					f.location,
				}
				
				parsed_functions[f.name] = func;
				existing_names[f.name] = f.location;
			}
		}
	}
	
	{ //Parse function body
		using state2;
		
		for state in states {
			for f in state.functions {
				
				assert(f.name in existing_names);
				assert(f.name in parsed_functions);
				
				body := parse_block(state.tokens[f.body_start_token:f.body_end_token], &errs);
				
			}
		}
	}
	
	
	if len(errs) == 0 {
		fmt.printf("Parsed : %#v\n", state2);
	}
	
	return errs[:];
}

destroy_parse_errors :: proc (errs : []Parse_error) {
	
	for e in errs {
		delete(e.message);
	}
	delete(errs);
}

State_infos :: struct {
	globals : [dynamic]Global_info,
	functions : [dynamic]Function_info,
	structs : [dynamic]Struct_info,
}

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

@(private="file")
State2 :: struct {
	parsed_structs : map[string]Struct,
	parsed_globals  :  map[string]Global,
	parsed_functions :  map[string]Function,
}

@(private="file")
destroy_state :: proc (using s : State, loc := #caller_location) {
	delete(globals, loc = loc);
	
	for f in functions {
		delete(f.inputs, loc = loc);
	}
	
	delete(functions, loc = loc);
	delete(structs, loc = loc);
}

@(private="file")
get_buildin_names :: proc () -> (types : map[string]struct{}) {
	
	for t in reflect.enum_fields_zipped(Primitive_kind) {
		types[t.name[1:]] = {};
	}
	
	for t in reflect.enum_fields_zipped(Sampler_kind) {
		types[t.name[1:]] = {};
	}
	
	return;
}

@(private="file")
resolve_type_from_type_name :: proc (state : State2, identifier : string) -> Type_type {
	
	for t in reflect.enum_fields_zipped(Primitive_kind) {
		if t.name[1:] == identifier {
			return cast(Primitive_kind)t.value;
		}
	}
	
	for t in reflect.enum_fields_zipped(Sampler_kind) {
		if t.name[1:] == identifier {
			return cast(Sampler_kind)t.value;
		}
	}
	
	for name, s in state.parsed_structs {
		if name == identifier {
			return s;
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
		
		inputs : [dynamic]Variable_info;
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
				
				append(&inputs, Variable_info{input_name, input_type});
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
			nil,
			inputs[:],
			return_type,
			function_body_start_token_index,
			function_body_end_token_index,
			{},
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
				
				append(&struct_members, Struct_member_info{member_name, member_type});
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
    called : string,          // Function name (or reference to a Function)
    args   : []Expression,    // List of arguments (expressions)
}

Assignment :: struct {
    lhs : ^Expression,   // The left-hand side (e.g., variable)
    rhs : ^Expression,   // The right-hand side (e.g., value or expression)
}

Unary_operator_kind :: enum {
    negation,     // e.g., -a
    inversion,    // e.g., !a
    bitwise_not,  // e.g., ~a
    increment,    // e.g., ++a or a++
    decrement,    // e.g., --a or a--
}

Unary_operator :: struct {
	op      : Unary_operator_kind,    // Operator like "-", "++", "!"
    operand : ^Expression,      // The expression being operated on
}

Binary_operator_kind :: enum {
    add,          // e.g., a + b
    subtract,     // e.g., a - b
    multiply,     // e.g., a * b
    divide,       // e.g., a / b
    modulo,       // e.g., a % b
    logical_and,  // e.g., a && b
    logical_or,   // e.g., a || b
    bitwise_and,  // e.g., a & b
    bitwise_or,   // e.g., a | b
    bitwise_xor,  // e.g., a ^ b
    shift_left,   // e.g., a << b
    shift_right,  // e.g., a >> b
    equals,       // e.g., a == b
    not_equals,   // e.g., a != b
    greater_than, // e.g., a > b
    less_than,    // e.g., a < b
    greater_eq,   // e.g., a >= b
    less_eq,      // e.g., a <= b
}

Binary_operator :: struct {
	op      : Binary_operator_kind, 
    operand1 : ^Expression,      // The expression being operated on
	operand2 : ^Expression,      // The expression being operated on
}

Return :: struct {
	value : Maybe(^Expression),
}

If :: struct {
    condition : Expression,      // Condition to evaluate
    then_body : []^Statement,     // Block of statements for the true branch
    else_body : Maybe([]^Statement),  // Optional else block
}

For :: struct { //Also used as a while
    init      : Maybe(^Statement), // Initialization (e.g., Declaration or Assignment)
    condition : Maybe(Expression), // Loop condition
    increment : Maybe(Expression), // Increment step
    body      : []Statement,       // Loop body
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
	scope : Maybe(Scope),  // Optional reference to the variable's scope
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

Statement :: union {
	Variable_declaration,
	Expression, //Not legal but handled for better error messages
	Return,
	If,
	For,
	Block,
}

Symbol :: struct {}

Scope :: struct {
    parent     : ^Scope,              // Link to the parent scope (or `nil` if it's the global scope)
    symbols    : map[string]Symbol,   // Map from variable/function names to their metadata (Symbol)
}

Block :: struct {
    statements : []Statement,  // Ordered list of statements
    scope      : Scope,        // Scope associated with the block
}

@(private="file")
parse_block :: proc (_tokens : []token.Token, errs : ^[dynamic]Parse_error) -> Function_body_data {
	
	using state : State_token;
	state.tokens = _tokens;
	
	block : Block;
	
	t_next, done = next_token(&state);
	for !done {
		defer t_next, done = next_token(&state);
		
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
				else if t_next.origin.source == "return" {
					
					t_next, done = next_token(&state);
					
					expression_start_token := state.cur_tok-1;
					expression_end_token : int = -1;
					
					_, ok := t_next.type.(token.Semicolon)
					for !ok && !done {
						_, ok := t_next.type.(token.Semicolon);
						expression_end_token = state.cur_tok;
						t_next, done = next_token(&state);
					}
					
					if expression_end_token == -1 {
						emit_error2(errs, original_token.origin, "Missing ';' after return statement");
						continue;
					}
					
					expression_tokens := state.tokens[expression_start_token:expression_end_token];
					fmt.printf("found expression tokens: %#v\n", expression_tokens);
					expression := parse_expression(expression_tokens, errs);
					
					if expression == nil {
						emit_error2(errs, t_next.origin, "Invalid expression for ");
					}
				}
				else {
					
				}
				
			case:
				emit_error2(errs, t_next.origin, "Illegal token");
				continue;
		}
	}
	
	return {};
}

@(private="file")
parse_expression :: proc (_tokens : []token.Token, errs : ^[dynamic]Parse_error) -> ^Expression {
	
	
}