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
}

Global_info :: struct {
	name : string,
	qualifier : Storage_qualifiers,
	
	is_unsized_array : bool,
	sized_array_length : int,
}

Function_info :: struct {
	name : string,
	annotation : Annotation_type,
	
	inputs : []Variable_info,
	output : string,
	
	body_start_token : int,
	body_end_token : int,
	
	compute_dim : [3]int,
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Buildin_type :: enum {
	//??
}

Type_type :: struct {
	//????
	val : union{Buildin_type, Struct},
}

Struct_member :: struct {
	offset : int,
	size : int,
	type : Type_type,
}

//////////// Parsed version of info ////////////
Struct_data :: struct { //without the name, name is stored in map
	members : map[string]Struct_member,
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
	input_parameters : []Function_parameter,
	output : Type_type,
	function_body : Function_body,
}

Global_data :: struct {
	
}

Struct :: ^Struct_data;
Function :: ^Function_data;
Function_body :: ^Function_body_data;
Global :: ^Global_data;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

tprint_parse_error :: proc (err : Parse_error) -> string {
	return fmt.tprintf("%v(%v) Parse error : %v, got token '%v'", err.token.origin.file, err.token.origin.line, err.message, err.token.origin.source);	
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Perser_result :: struct {
	
}

Parse_error :: struct {
	message : string,
	token : Token,	
}

State :: struct {
	globals : [dynamic]Global_info,
	functions : [dynamic]Function_info,
	structs : [dynamic]Struct_info,
	errors : [dynamic]Parse_error,
	
	done : bool,
	cur_tok : int,
	t_next : Token,
}

destroy_state :: proc (using s : State) {
	delete(globals);
	
	for f in functions {
		delete(f.inputs);
	}
	
	delete(functions);
	delete(structs);
}

@require_results
parse1 :: proc (tokens : [dynamic]Token) -> (State, []Parse_error) {
	
	//////////////////// PARSE GLOBALS, FUNCTIONS DECLARATION AND STRUCTS ////////////////////
	
	state : State;
	{
		using state;
		defer destroy_state(state);
		
		for !done {
			t : Token;
			t, done = next_token(&state, tokens);
			
			#partial switch v in t.type {
				
				case token.Comment, token.Multi_line_comment: {
					//TODO, we want to add the comments to the GLSL files too! thing before should be before and on the same line on the same line.
					panic("Comments are not handled here");
				}
				case token.Qualifier: {
					t_next, done = next_token(&state, tokens);
					global_name : string;
					type_name : string;
					is_unsized_array : bool;
					sized_array_length : int = 1;
					
					if _, ok := t_next.type.(token.Identifier); ok {
						global_name = t_next.origin.source;
					}
					else {
						emit_error(&state, tokens, "Expected identifier (name) in global declaration.", t_next);
						continue;
					}
					
					t_next, done = next_token(&state, tokens);
					if _, ok := t_next.type.(token.Colon); ok {
					} else {
						emit_error(&state, tokens, "Expected ':' after identifer (name) in global declaration.", t_next);
						continue;
					}
					
					t_next, done = next_token(&state, tokens);
					if p, ok := t_next.type.(token.Parenthesis); ok {
						if p.kind == .begin && p.type == .sqaure_brackets {
							t_next, done = next_token(&state, tokens);
							
							if p, ok := t_next.type.(token.Parenthesis); ok {
								//unsized
								if p.kind == .end && p.type == .sqaure_brackets {
									is_unsized_array = true;
								}
								else {
									emit_error(&state, tokens, "Expected a ']' after '[' or integer literal in global declaration.", t_next);
									continue;
								}
								
								t_next, done = next_token(&state, tokens);
							}
							else if i, ok := t_next.type.(token.Integer_literal); ok {
								//Sized array
								sized_array_length = cast(int)i.value;
								
								t_next, done = next_token(&state, tokens);
								if p, ok := t_next.type.(token.Parenthesis); ok {
									if p.kind == .end && p.type == .sqaure_brackets {
									} else {
										emit_error(&state, tokens, "Expected a closing ']' in global declaration.", t_next);
										continue;
									}
								}
								t_next, done = next_token(&state, tokens);
							}
							else {
								emit_error(&state, tokens, "Expected a identifier (type) or '[' after ':' in global declaration.", t_next);
								continue;
							}
						}
						else {
							emit_error(&state, tokens, "Expected a identifier (type) or '[' after ':' in global declaration.", t_next);
							continue;
						}
						
					}
					if _, ok := t_next.type.(token.Identifier); ok {
						//This is a type, we check for known types.
						//TODO
					}
					else {
						emit_error(&state, tokens, "Expected a identifier (type) or '[' after ':' in global declaration.", t_next);
						continue;
					}
					
					t_next, done = next_token(&state, tokens);
					if _, ok := t_next.type.(token.Semicolon); ok {
					} else {
						emit_error(&state, tokens, "Expected a ';' at the end of global declaration.", t_next);
						continue;
					}
					
					append(&globals, Global_info{
						global_name,
						v.type,
						is_unsized_array,
						sized_array_length,
					})
				}
				case token.Identifier: {
					
					t_next = t;
					res, failed := parse_struct_or_proc(&state, tokens);
					
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
					
					t_next, done = next_token(&state, tokens);
					if v.type == .compute {
						used_comma_sperator : bool = false;
						
						if p, ok := t_next.type.(token.Parenthesis); ok {
							if p.kind == .begin && p.type == .round_brackets {
								//Correct
							} else {
								emit_error(&state, tokens, "Expected '(' after compute annotation.", t_next);
								continue;
							}
						}
						
						t_next, done = next_token(&state, tokens);
						if i, ok := t_next.type.(token.Integer_literal); ok {
							compute_dim.x = cast(int)i.value;
						}
						else {
							emit_error(&state, tokens, "Expected integer literal, so that the format is @compute(x,y,z), failed at x.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state, tokens);
						if _, ok := t_next.type.(token.Comma); ok {
							used_comma_sperator = true;
							t_next, done = next_token(&state, tokens);
						}
						
						if i, ok := t_next.type.(token.Integer_literal); ok {
							compute_dim.y = cast(int)i.value;
						}
						else {
							emit_error(&state, tokens, "Expected integer literal, so that the format is @compute(x,y,z), failed at y.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state, tokens);
						if _, ok := t_next.type.(token.Comma); ok {
							if !used_comma_sperator {
								emit_error(&state, tokens, "Expected no ',' sperator. The @compute annotation must use all commas or all spaces for sperator, they may not be mixed.", t_next);
								continue;
							}
							t_next, done = next_token(&state, tokens);
						}
						else {
							if used_comma_sperator {
								emit_error(&state, tokens, "Expected a ',' sperator. The @compute annotation must use all commas or all spaces for sperator, they may not be mixed.", t_next);
								continue;
							}
						}
						
						if i, ok := t_next.type.(token.Integer_literal); ok {
							compute_dim.z = cast(int)i.value;
						}
						else {
							emit_error(&state, tokens, "Expected integer literal, so that the format is @compute(x,y,z), failed at z.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state, tokens);
						if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .end && p.type == .round_brackets {
						} else {
							emit_error(&state, tokens, "Expected ')' in @compute annotation.", t_next);
							continue;
						}
						
						t_next, done = next_token(&state, tokens);
					}
					
					res, failed := parse_struct_or_proc(&state, tokens);
					
					if failed {
						continue;
					}
					
					switch &r in res {
						
						case Function_info: {
							
							r.compute_dim = compute_dim;
							r.annotation = v.type;
							
							append(&functions, r);
							
						}
						case Struct_info: {
							emit_error(&state, tokens, "Expected procedure after annotation, but recived struct definition.", t);
							continue;
						}
					}
				}
				case: {
					
					if t == {} {
						continue;
					}
					
					emit_error(&state, tokens, "Unexpected token!", t);
					continue;
				}
			}
		}
		
		log.logf(.Info, "Found globals : %#v\n", globals);
		log.logf(.Info, "Found functions : %#v\n", functions);
		log.logf(.Info, "Found structs : %#v\n", structs);
	}
	
	return state, state.errors[:];
}

parse2 :: proc (states : []State) -> ([]Parse_error) {
	
	emit_error(&state, tokens, "Expected identifier (name) in global declaration.", t_next);
	
	//////////////////// MERGE THE SOURCES, resolve struct types ////////////////////
	
	errs : [dynamic]Parse_error;
	
	parsed_structs : map[string]Struct;
	
	{
		existing_structs : map[string]struct{};
		
		for state in states {
			for s in state.structs {
				
				if s.name in existing_structs {
					emit_error(&state, tokens, "Expected identifier (name) in global declaration.", t_next);
				}
			
				existing_structs[s.name] = {};
			}
		}
		
		//First do structs so can determine the type of everything and gives errors on wrong types.
		
		//Then merge the globals, thye may collide, but should same type.
		
		//Then merge functions, they may not collide.
	}
	
	return errs[:];
}

//TODO
parse3 :: proc (tokens : [dynamic]Token) -> ([]Parse_error) {
	
	////////////////// PROCESS FUNCTION BODY ////////////////////
	{
		//At this point, the types of globals, and advaliable structs are known, so finding a type can be resolved immetiatly.
		
		//What should this be an AST?
	}
}

destroy_parse_res :: proc (res : Perser_result, errs : []Parse_error) {
	
	for e in errs {
		delete(e.message);
	}
	delete(errs);
}


@(private="file")
next_token :: proc (using state : ^State, tokens : [dynamic]Token) -> (tok : Token, is_done : bool) {
	
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
			tok, is_done = next_token(state, tokens);
		}
	}
	
	return;
}
	
@(private="file")
emit_error :: proc (state : ^State, tokens : [dynamic]Token, msg : string, tok : token.Token, loc := #caller_location) {
	
	msg := strings.clone(msg);

	append(&state.errors, Parse_error{msg, tok});
	
	log.error(tprint_parse_error(Parse_error{msg, tok}), location = loc);
	
	is_done : bool;
	t_next : Token;
	
	for !is_done {
		t_next, is_done = next_token(state, tokens);
		_, ok := t_next.type.(Semicolon);
		if ok {
			return;
		}
	}
}

@(private="file")
parse_struct_or_proc :: proc (using state : ^State, tokens : [dynamic]Token) -> (res : union {Function_info, Struct_info}, failed : bool) {
	
	name : string; //Proc or struct name.

	if iden, ok := t_next.type.(Identifier); ok {
		name = t_next.origin.source;
	}
	else {
		emit_error(state, tokens, "Expected identifier (name) after annotation.", t_next);
		return {}, true;
	}
	
	t_next, done = next_token(state, tokens);
	if iden, ok := t_next.type.(token.Colon); ok {	
	} else {
		emit_error(state, tokens, "Expected ':' after procedure/struct name.", t_next);
		return {}, true;
	}
	
	t_next, done = next_token(state, tokens);
	if iden, ok := t_next.type.(token.Colon); ok {	
	} else {
		emit_error(state, tokens, "Expected a second ':' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
		return {}, true;
	}
	
	is_proc : bool;
	
	t_next, done = next_token(state, tokens);
	if iden, ok := t_next.type.(Identifier); ok {
		if t_next.origin.source == "proc" {
			is_proc = true;
		}
		else if t_next.origin.source == "struct" {
			is_proc = false;
		}
		else {
		
			emit_error(state, tokens, "Expected 'proc' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
			return {}, true;
		}
	} else {
		emit_error(state, tokens, "Expected 'proc' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
		return {}, true;
	}
	
	if is_proc {
		
		inputs : [dynamic]Variable_info;
		return_type : string;
		
		function_body_start_token_index : int;
		function_body_end_token_index : int;
		
		t_next, done = next_token(state, tokens);
		if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .begin && p.type == .round_brackets {
		} else {
			emit_error(state, tokens, "Expected '(' to fulfill format 'function_name :: proc(...) {...}' in function declaration.", t_next);
			return {}, true;
		}
		
		is_done : bool = false;
		
		for !is_done {	
			
			t_next, done = next_token(state, tokens);
			if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .end && p.type == .round_brackets {
				is_done = true;
			}
			else {
				input_name : string;
				input_type : string;
				
				if _, ok := t_next.type.(token.Identifier); ok {
					input_name = t_next.origin.source;
				}
				else {
					emit_error(state, tokens, "Expected identifer (parameter name)", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state, tokens);
				if _, ok := t_next.type.(token.Colon); ok {
				} else {
					emit_error(state, tokens, fmt.tprintf("Expected ':' after parameter name %v.", input_name), t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state, tokens);
				if _, ok := t_next.type.(token.Identifier); ok {
					input_type = t_next.origin.source;
				}
				else {
					emit_error(state, tokens, "Expected identifier (type) after ':'.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state, tokens);
				if _, ok := t_next.type.(token.Comma); ok {
				}
				else if  p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .end && p.type == .round_brackets {
					is_done = true;
				}else {
					emit_error(state, tokens, "Expected ',' or '}' after function parameter.", t_next);
					return {}, true;
				}
				
				append(&inputs, Variable_info{input_name, input_type});
			}
		}
	
		t_next, done = next_token(state, tokens);
		if _, ok := t_next.type.(token.Proc_return_operator); ok {
			t_next, done = next_token(state, tokens);
			if _, ok := t_next.type.(token.Identifier); ok {
				return_type = t_next.origin.source;
			}
			t_next, done = next_token(state, tokens);
		}
		
		if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .begin && p.type == .curly_braces {
			//TODO no return value, process function body later.
			
			function_body_start_token_index = cur_tok;
			start_curly_token := t_next;
			
			curly_count : int = 1;
			for curly_count != 0 && !done {
				t_next, done = next_token(state, tokens);
				if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .begin && p.type == .curly_braces {
					curly_count += 1;
				}
				else if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .end && p.type == .curly_braces {
					curly_count -= 1;
				}
			}
			
			if curly_count != 0 {
				emit_error(state, tokens, "Missing closing }", start_curly_token);
				return {}, true;
			}
			
			function_body_end_token_index = cur_tok;
		}
		else {
			emit_error(state, tokens, "Expected '{' or '->' to fulfill format 'function_name :: proc(...) -> return_type {...}' in function declaration. The '-> return_type' part is optional.", t_next);
			return {}, true;
		}
		
		return Function_info{
			name = name,
			annotation = nil,
			
			inputs = inputs[:],
			output = return_type,
			
			body_start_token = function_body_start_token_index,
			body_end_token = function_body_end_token_index,
			
			compute_dim = {},
		}, false;
	}
	else {
		
		t_next, done = next_token(state, tokens);
		if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .begin && p.type == .curly_braces {
		}
		else {
			emit_error(state, tokens, "Expected '{' after 'struct'.", t_next);
			return {}, true;
		}
		
		is_done : bool = false;
		struct_members : [dynamic]Struct_member_info;
		
		for !is_done {	
			t_next, done = next_token(state, tokens);
			if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .end && p.type == .curly_braces {
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
					emit_error(state, tokens, "Expected identifier (name) for struct member.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state, tokens);
				if _, ok := t_next.type.(token.Colon); ok {
				} else {
					emit_error(state, tokens, "Expected ':' after struct member name.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state, tokens);
				if iden, ok := t_next.type.(Identifier); ok {
					member_type = t_next.origin.source;	
				}
				else {
					emit_error(state, tokens, "Expected identifier (type) after ':' for struct member.", t_next);
					return {}, true;
				}
				
				t_next, done = next_token(state, tokens);
				if iden, ok := t_next.type.(token.Comma); ok {
				} else if p, ok := t_next.type.(token.Parenthesis); ok && p.kind == .end && p.type == .curly_braces {
					is_done = true;
				}
				else {
					emit_error(state, tokens, "Expected seperator ',' or end of struct '}'.", t_next);
					return {}, true;
				}
				
				append(&struct_members, Struct_member_info{member_name, member_type});
			}
		}
		
		return Struct_info{
			name,
			struct_members[:],
		}, false;
	}
	
	unreachable();
}