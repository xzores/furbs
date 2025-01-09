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

Division_operator :: struct {};
Negation_operator :: struct {};
Addition_operator :: struct {};
Multiply_operator :: struct {};
Power_of_operator :: struct {};

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
	
	custom, //TODO 
	
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

Paren_begin :: struct {};
Paren_end :: struct {};

Sqaure_begin :: struct {};
Sqaure_end :: struct {};

Curly_begin :: struct {};
Curly_end :: struct {};

Identifier :: struct {};

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
	
	Division_operator,
	Negation_operator,
	Addition_operator,
	Multiply_operator,
	Power_of_operator,

	Paren_begin,
	Paren_end,
	Sqaure_begin,
	Sqaure_end,
	Curly_begin,
	Curly_end,
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

//The caller owns the returned values
@require_results
tokenize :: proc (_source_code : string, _filename : string) -> (toks : [dynamic]Token, err : string) {
	
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
	
	@require_results
	default_behavior :: proc (using t : ^Tokenizer, c : rune, i : int) -> string{
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
				emit_token(t, true, Addition_operator{});
			case '^':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Power_of_operator{});
			case '*':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Multiply_operator{});
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
			case '(':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Paren_begin{});
			case ')':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Paren_end{});
			case '[':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Sqaure_begin{});
			case ']':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Sqaure_end{});
			case '{':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Curly_begin{});
			case '}':
				token_begin = i;
				token_start_line = current_line;
				emit_token(t, true, Curly_end{});
			
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
					delete(t.tokens);
					return fmt.aprintf("invalid lexeme '%v' at line %v\n", c, current_line);
				}
		}
		
		return "";
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
				if e := default_behavior(&t, c, i); e != "" {
					return t.tokens, e;
				}
			
			case .in_slash:
				switch c {
					case '/': 
						state = .in_line_comment;
					case '*':
						state = .in_multi_comment;
					case:
						emit_token(&t, false, Division_operator{});
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
					if e := default_behavior(&t, c, i); e != "" {
						return t.tokens, e;
					}
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
					if e := default_behavior(&t, c, i); e != "" {
						return t.tokens, e;
					}
				}
				
			case .in_identifier:
				if unicode.is_letter(c) || c == '_' || unicode.is_digit(c) {
					//keep extending the identifier	
				}
				else {
					emit_token(&t, false, Identifier{});
					token_begin = i;
					state = .default;
					if e := default_behavior(&t, c, i); e != "" {
						return t.tokens, e;
					}
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
					if e := default_behavior(&t, c, i); e != "" {
						return t.tokens, e;
					}
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
					if e := default_behavior(&t, c, i); e != "" {
						return t.tokens, e;
					}
				}
			
			case .in_dash:
				switch c {
					case '>':
						emit_token(&t, true, Proc_return_operator{});
						token_begin = i;
						state = .default;
					case: {
						emit_token(&t, true, Negation_operator{});
						token_begin = i;
						state = .default;
						if e := default_behavior(&t, c, i); e != "" {
							return t.tokens, e;
						}
					}
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
					if e := default_behavior(&t, c, i); e != "" {
						return t.tokens, e;
					}
				}
		}
	}
	
	return t.tokens, "";
}
