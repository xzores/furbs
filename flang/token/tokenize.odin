package flang_tokenizer;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:c"
import "core:strconv"

Location :: struct {
	file : string,
	line : int,
	source : string, //This is a view //created as a pointer by a raw_string
}

Unknown_token_type :: struct {};

Comment :: struct {};

Multi_line_comment :: struct {};

//Want to handle : and :: and := 
//Handle @

Arithmetic_operators :: struct {
	type: enum {
		division,
		negation,
		addition,
		multiply,
		power_of,
	},
};

Logical_operator :: struct {};
Comparison_operator :: struct {};
Bitwise_operator :: struct {};
Assignment_operator :: struct {}; //TODO assign or assign and declare.
Unitary_operator :: struct {};
Semicolon :: struct{};
Colon :: struct{};
Proc_return_operator :: struct{};
Comma :: struct {};
Dot :: struct {};

Annotation_type :: enum {
	none = 0,
	
	//For rasterization
	vertex,
	fragment,
	
	//Tesselation
	tesselation_control,
	tesselation_valuation,
	
	//Compute shader
	compute,
	
	//Raytrace
	trace_raygen,
	trace_intersect,
	trace_anyhit,
	trace_closesthit,
	trace_miss,
	trace_callable,
	trace_task,
	trace_mesh,
}

Annotation :: struct {
	type: Annotation_type,
};

Brackets_type :: enum {
	round_brackets,		// ( and )
	sqaure_brackets,	// [ and ]
	curly_braces, 		// { and }
}

Brackets_kind :: enum {
	begin,
	end,
};

Brackets_origin :: struct{char_index : int, token_index : int};

Parenthesis :: struct {
	kind : Brackets_kind,
	type : Brackets_type,
	//complement_token : Brackets_origin,
};

Identifier :: struct {}

Integer_literal :: struct {
	value : i128,
}

String_literal :: struct {}

Float_literal :: struct {
	value : f64,
}

Boolean_literal :: struct {
    value : bool,
}

Character_literal :: struct {
    value : rune, // 'rune' is often used to represent a single character
}

Nil_literal :: struct {}

Hexadecimal_literal :: struct {
    value : i128, // The actual value is still an integer, but it's parsed from hexadecimal format
}

Binary_literal :: struct {
    value : i128, // The value is stored as an integer, parsed from binary
}

Preprocessor_token_type :: enum {
	_define,
	_undefine,
	
	_if,
	_ifdef,
	_ifnotdef,
	_else,
	_elif,
	_endif,
	
	_include,
	_extension,
	_version,
	_target_lang,
	_target_lang_version,
	
	_line,
	_file,
	_error,
}

Preprocessor_token :: struct {
	type : Preprocessor_token_type,
}

Storage_qualifiers :: enum {
	attribute,	//Input of the fragment shader
	varying,	//The output of the vertex shader and input of the fragment shader.
	frag_out,	//The output of the fragment shader.
	uniform,	//Same as a uniform in GLSL
	sampler,	//Same as a uniform sampler in GLSL
	local,		//Used for compute shader "shared" memeory
	storage, 	//SSBO
}

Qualifier  :: struct {
	type : Storage_qualifiers,
}

/*
Control_flow_tokens :: struct {
	type : enum {
		_if,
		_else,
		_for,
		_while,
		_do,
		_switch,
		_case,
		_default,
		_break,
		_continue,
		_return,
		_discard,
	}
}
*/

Token_type :: union {
	Unknown_token_type,
	
	Comment,
	Multi_line_comment,
	
	Preprocessor_token,
	
	Annotation,
	Qualifier,
	
	Parenthesis,
	Arithmetic_operators,
	Logical_operator,
	Comparison_operator,
	Bitwise_operator,
	Assignment_operator,
	Unitary_operator,
	
	Semicolon,	
	Colon,
	Comma,
	Dot,
	
	Proc_return_operator,
	
	Identifier,
	
	Integer_literal,
	String_literal,
	Float_literal,
	Boolean_literal,
	Character_literal,
	Nil_literal,
	Hexadecimal_literal,
	Binary_literal,
}

Token :: struct {
	origin : Location,
	type : Token_type,
}

@require_results
tokenize :: proc (_source_code : string, _filename : string) -> [dynamic]Token {
	
	Tokenizer :: struct {
		
		source_code : string `fmt:"-"`,
		filename : string `fmt:"-"`,
		tokens : [dynamic]Token `fmt:"-"`,
		
		state : enum {
			default,
			
			in_slash,
			in_line_comment,
			in_multi_comment,
			in_star_multi_comment,
			
			in_annotation,
			in_qualifier,
			in_identifier,
			
			in_preprocessor_directive,
						
			in_string_literal,
			in_number_literal, //Common for floats and integers, we don't know if is one or the other.
			in_float_literal, //If there is a . we know we are in a float.
			in_dash,
		},
		
		//last_bracket_begin : [Brackets_type][dynamic]Brackets_origin, //move to parser
		
		token_start_line : int,
		current_line : int,
		
		token_begin : int,
		current_index : int,
	}
	
	is_brackets :: proc (c : rune) -> bool {
		return c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}';
	}
	
	get_brackets_type :: proc (c : rune) -> Brackets_type {
		switch c {
			case '(', ')':
				return .round_brackets;
			case '[', ']':
				return .sqaure_brackets;
			case '{', '}':
				return .curly_braces;
		}
		
		return nil;
	}
	
	get_brackets_kind :: proc (c : rune) -> Brackets_kind {
		switch c {
			case '{', '[', '(':
				return .begin;
			case ')', ']', '}':
				return .end;
		}
		
		return nil;
	}
	
	emit_token :: proc (using t : ^Tokenizer, include_char : bool, type : Token_type) {
		
		length := t.current_index - t.token_begin;
		
		if include_char {
			length += 1;
		}
		
		source_code_raw := transmute(runtime.Raw_String)source_code;
		string_ref := runtime.Raw_String{&source_code_raw.data[t.token_begin], length};
		
		origin_location : Location = {filename, t.token_start_line, transmute(string)string_ref};
		token := Token{origin_location, type};
		append(&tokens, token);
		
		token_begin = current_index;
	}
	
	default_behavior :: proc (using t : ^Tokenizer, c : rune, i : int) {
		switch c {
			case '/':
				state = .in_slash;
				token_begin = i;
				token_start_line = current_line;
			case '\n':
				token_begin = i;
			case ' ', '\t':
				token_begin = i;
			case '@':
				token_begin = i;
				state = .in_annotation;
				token_start_line = current_line;
			case '"':
				token_begin = i;
				state = .in_string_literal;
				token_start_line = current_line;
			case ';':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Semicolon{});
			case ':':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Colon{});
			case '$':
				token_begin = i;
				state = .in_qualifier;
				token_start_line = current_line;
			case '-':
				token_begin = i;
				state = .in_dash;
				token_start_line = current_line;
			case '+':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Arithmetic_operators{.addition});
			case '^':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Arithmetic_operators{.power_of});
			case '*':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Arithmetic_operators{.multiply});
			case '=':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Assignment_operator{});
			case ',':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Comma{});
			case '.':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Dot{});
			case '#':
				token_begin = i;
				token_start_line = current_line;
				state = .in_preprocessor_directive;
			case '(', ')', '[', ']', '{', '}':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Parenthesis{get_brackets_kind(c), get_brackets_type(c)});
			case:
				if unicode.is_letter(c) || c == '_' {
					token_begin = i;
					token_start_line = current_line;
					state = .in_identifier;
				}
				else if unicode.is_digit(c) {
					token_begin = i;
					token_start_line = current_line;
					state = .in_number_literal;
				}
				else {
					fmt.panicf("invalid lexeme %v\n", c);
				}
		}
	}
	
	using t : Tokenizer = {
		source_code = _source_code,
		filename = _filename,
	};
	
	current_line = 1;
	
	for c, i in source_code {
		current_index = i;
		if c == '\n' {
			current_line += 1;
		}
		
		switch state {
			case .default:
				default_behavior(&t, c, i);
			
			case .in_slash:
				switch c {
					case '/': 
						state = .in_line_comment;
					case '*':
						state = .in_multi_comment;
					case:
						emit_token(&t, false, Arithmetic_operators{.division});
						state = .default;
						if unicode.is_letter(c) || c == '_' {
							token_begin = i;
							state = .in_identifier;
						}
				}
			
			case .in_line_comment:
				switch c {
					case '\n':
						emit_token(&t, false, Comment{});
						state = .default;
				}
			
			case .in_multi_comment: 
				switch c {
					case '*': 
						state = .in_star_multi_comment;
				}
			
			case .in_star_multi_comment: 
				switch c {
					case '/':
						emit_token(&t, true, Multi_line_comment{});
						state = .default;
					case:
						state = .in_multi_comment;
				}
			
			case .in_annotation: 
				if unicode.is_letter(c) || c == '_' || unicode.is_digit(c) {
					//keep extending the annotation
				} else {
					annotation_name : string;
					{
						source_code_raw := transmute(runtime.Raw_String)source_code;
						string_ref := runtime.Raw_String{&source_code_raw.data[t.token_begin + 1], t.current_index - t.token_begin - 1};	
						annotation_name = transmute(string)string_ref;
					}
					
					annotation_type, ok := reflect.enum_from_name(Annotation_type, annotation_name);
					if !ok {
						fmt.panicf("Could not evaluate to the \"%v\" to any of the following %#v", annotation_name, reflect.enum_field_names(Annotation_type));
					}
					
					emit_token(&t, false, Annotation{annotation_type});
					token_begin = i;
					state = .default;
					default_behavior(&t, c, i);
				}
			
			case .in_qualifier:
				if unicode.is_letter(c) || c == '_' || unicode.is_digit(c) {
					//keep extending the qualifier
				} else {
					
					qualifier_name : string;
					{
						source_code_raw := transmute(runtime.Raw_String)source_code;
						string_ref := runtime.Raw_String{&source_code_raw.data[t.token_begin + 1], t.current_index - t.token_begin - 1};	
						qualifier_name = transmute(string)string_ref;
					}
					
					qualifier_type, ok := reflect.enum_from_name(Storage_qualifiers, qualifier_name);
					if !ok {
						fmt.panicf("Could not evaluate to the \"%v\" to any of the following %#v", qualifier_name, reflect.enum_field_names(Storage_qualifiers));
					}
					
					emit_token(&t, false, Qualifier{qualifier_type});
					token_begin = i;
					state = .default;
					default_behavior(&t, c, i);
				}
				
			case .in_identifier:
				if unicode.is_letter(c) || c == '_' || unicode.is_digit(c) {
					//keep extending the identifier	
				}
				else {
					emit_token(&t, false, Identifier{});
					token_begin = i;
					state = .default;
					default_behavior(&t, c, i);
				}
				
			case .in_string_literal:
				switch c {
					case '"':
						emit_token(&t, true, String_literal{});
						token_begin = i;
						state = .default;
				}
			
			case .in_number_literal:
				
				if unicode.is_digit(c) || c == '_' {
					//keep adding to the digit
				}
				else if c == '.' {
					state = .in_float_literal;
				}
				else {
					
					number_string : string;
					{
						source_code_raw := transmute(runtime.Raw_String)source_code;
						string_ref := runtime.Raw_String{&source_code_raw.data[t.token_begin], t.current_index - t.token_begin};	
						number_string = transmute(string)string_ref;
					}
					
					number, ok := strconv.parse_i128_of_base(number_string, 10);
					if !ok {
						fmt.panicf("Internal error could not parse int : %v", number_string);
					}
					
					emit_token(&t, false, Integer_literal{number});
					token_begin = i;
					state = .default;
					default_behavior(&t, c, i);
				}
			
			case .in_float_literal:
				if unicode.is_digit(c) || c == '_' {
					//keep adding to the digit
				}
				else if c == '.' {
					fmt.panicf("only a single '.' is allowed in float literal.");
				}
				else {
					
					number_string : string;
					{
						source_code_raw := transmute(runtime.Raw_String)source_code;
						string_ref := runtime.Raw_String{&source_code_raw.data[t.token_begin], t.current_index - t.token_begin};	
						number_string = transmute(string)string_ref;
					}
					
					number, ok := strconv.parse_f64(number_string);
					if !ok {
						fmt.panicf("Internal error could not parse float : %v", number_string);
					}
					
					emit_token(&t, false, Float_literal{number});
					token_begin = i;
					state = .default;
					default_behavior(&t, c, i);
				}
			
			case .in_dash:
				switch c {
					case '>':
						emit_token(&t, true, Proc_return_operator{});
						token_begin = i;
						state = .default;
					case:
						emit_token(&t, true, Arithmetic_operators{.negation});
						token_begin = i;
						state = .default;
						default_behavior(&t, c, i);
				}
			
			case .in_preprocessor_directive:
				if unicode.is_letter(c) || c == '_' || unicode.is_digit(c) {
					//keep adding to directive
				}
				else {
					
					prepros_string : string;
					{
						source_code_raw := transmute(runtime.Raw_String)source_code;
						string_ref := runtime.Raw_String{&source_code_raw.data[t.token_begin + 1], t.current_index - t.token_begin - 1};	
						prepros_string = fmt.tprintf("_%s", transmute(string)string_ref);
					}
						
					prepros, ok := reflect.enum_from_name(Preprocessor_token_type, prepros_string);
					if !ok {
						fmt.panicf("Internal error could not parse preprocessor directive : %v", prepros_string);
					}
					
					emit_token(&t, false, Preprocessor_token{prepros});
					token_begin = i;
					state = .default;
					default_behavior(&t, c, i);
				}
		}
		
		if c != '\n' {
			//fmt.printf("rune : %v, tokenizer : %v\n", c, t);
		}
	}
	
	return t.tokens;
}
