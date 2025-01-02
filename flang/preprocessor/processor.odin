package flang_preproccesor;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:path/slashpath"

import "../token"

File_load :: struct{collection : string, file : string, from : string};

//inserts, replaces and removes tokens
preproces :: proc (tokens : ^[dynamic]token.Token, filepath : string) -> (new_files_to_load : []File_load) {
	
	next_token :: proc (tokens : ^[dynamic]token.Token, cur_tok : ^int) -> (tok : token.Token, done : bool) {
		
		if cur_tok^ == len(tokens) - 1 {
			done = true;
		}
		
		cur_tok^ += 1;
		tok = tokens[cur_tok^ - 1];
		return;
	}
	
	to_load : [dynamic]File_load;
	
	done := false;
	cur_tok : int;
	t_next : token.Token;
	
	for !done {
		t : token.Token;
		t, done = next_token(tokens, &cur_tok);
		
		if tok, ok := t.type.(token.Preprocessor_token); ok {
			
			#partial switch tok.type {
				case ._include:
					
					t_next, done = next_token(tokens, &cur_tok);
					
					_, is_string_lit := t_next.type.(token.String_literal);
					fmt.assertf(is_string_lit, "There must be a string literal after an #include, found %#v\n", t_next);
					
					collection : string;
					filename : string;
					
					include_file := t_next.origin.source[1:len(t_next.origin.source)-1];
					
					current : strings.Builder;
					strings.builder_init(&current);
					defer strings.builder_destroy(&current);
					
					found_collection : bool;
					
					for c in include_file {
						if c == ':' {
							if found_collection {
								fmt.panicf("A collection specifier was already found, there can only be one ':' in an include path. Token : %v\n", tok);
							}
							found_collection = true;
							collection = strings.clone(strings.to_string(current));
							strings.builder_reset(&current);
							
						} else {
							strings.write_rune(&current, c);
						}
					}
					filename = strings.clone(strings.to_string(current));
					
					{ //Check that the nexxt token is a semicolon
						t_next, done = next_token(tokens, &cur_tok);
						_, is_semicolon := t_next.type.(token.Semicolon);
						fmt.assertf(is_semicolon, "There must be a ';' after the string literal after an #include, found %#v\n", t_next);
					}
					
					append(&to_load, File_load{collection, filename, filepath});
					
				case:
					panic("TODO");
			}
		}
	}
	
	return to_load[:];
}
