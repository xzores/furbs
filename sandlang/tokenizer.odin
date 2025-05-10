#+feature dynamic-literals
package sand_lang;

@(private)
Tokenize_result :: struct {
	tokens : []Token,
	errors : []Error,
	allocator : vmem.Arena,
	dummy_ptr : ^int,
}

//TODO first line is TITLE line 
@(private, require_results)
tokenize :: proc (_filename : string, _content : string, backing_allocator := context.allocator, loc := #caller_location) -> Tokenize_result {
	
	Tokenizer :: struct {
		filename : string,
		content : []rune,	//NOTE this is not a string, it is a list of runes, which are 4 wide.
		is_done : bool,
		current_rune : int,
		current_line : int,
		current_rune_on_line : int,
		r : rune,
		
		tokens : [dynamic]Token,
		errors : [dynamic]Error,
		
		allocator : vmem.Arena `fmt:"-"`,
	}
	
	source, was_allocation := strings.replace_all(_content, "\r\n", "\n");
	
	defer {
		if was_allocation {
			delete(source);
		}
	}
	
	area_alloca : vmem.Arena;
	e := vmem.arena_init_growing(&area_alloca);	
	assert(e == nil, "failed to allocate memeory");
	
	allocator := vmem.arena_allocator(&area_alloca);
	context.allocator = mem.panic_allocator();
	
	t : Tokenizer = {
		_filename,
		string_to_runes_and_add_space(source, context.temp_allocator), //utf8.string_to_runes(source),
		false,
		-1,
		1,
		-1,
		0,
		make([dynamic]Token, context.temp_allocator),
		make([dynamic]Error, context.temp_allocator),
		area_alloca,
	};
	
	next_rune :: proc (using t : ^Tokenizer) {
		
		if t.current_rune < len(t.content)-1 {
			t.current_rune += 1;
			t.current_rune_on_line += 1;
		}
		else {
			t.is_done = true;
		}
		
		if t.current_rune < len(t.content)-1 {
			r = t.content[t.current_rune];
		}
		else {
			r = '\n';
		}
	}
	
	peek_next :: proc (using t : ^Tokenizer) -> rune{
		return t.content[t.current_rune + 1];
	}
	
	emit_token :: proc (using t : ^Tokenizer, token : Token, loc := #caller_location) {
		log.debugf("Emitting : %v", token.value, location = loc);
		append(&t.tokens, token, loc);
		assert(token.value != nil)
	}
	
	emit_error :: proc (using t : ^Tokenizer, msg : string, begin_rune, end_token : int, args: ..any, loc := #caller_location) {
		
		err_msg := fmt.aprintf(msg, ..args, allocator = vmem.arena_allocator(&t.allocator));
				
		runes := t.content[begin_rune:end_token];
		token := utf8.runes_to_string(runes, context.temp_allocator);
		log.error(fmt.tprintf("%v(%v) Tokenize error : %v, got '%s'", t.filename, t.current_line, err_msg, token), location = loc);
		append(&t.errors, Error{err_msg, t.current_line, begin_rune, end_token});
		next_rune(t); // move forward
	}
	
	is_done :: proc (using t : ^Tokenizer) -> bool {
		return t.is_done
	}
	
	next_rune(&t);
	for !is_done(&t) {
		
		if strings.is_space(t.r) {
			//ignore white spaces
			if is_done(&t) || t.r == '\n' {	//only handle new lines
				t.current_line += 1;
				t.current_rune_on_line = -1;
			}
			next_rune(&t);
		}
		else if unicode.is_digit(t.r) || (t.r == '.' && unicode.is_digit(peek_next(&t))) || (t.r == '-' && (unicode.is_digit(peek_next(&t)) || peek_next(&t) == '.')) {
			//entering a int or float litereal
			begin_rune := t.current_rune;
			is_float := false;
			mult := 1;
			
			for !is_done(&t) {
				
				if begin_rune == t.current_rune && t.r == '-' {
					begin_rune = t.current_rune;
					mult = -1;
					next_rune(&t);
				}
				else if t.r == '.' {
					if is_float {
						for !(strings.is_space(t.r) || is_done(&t)) {
							next_rune(&t);
						}
						end_rune := t.current_rune;
						emit_error(&t, "A litereal contains more then one '.'", begin_rune, end_rune);
						break;
					}
					is_float = true;
					next_rune(&t);
				}
				else if is_done(&t) || strings.is_space(t.r) || is_operator(t.r) || is_delimiter(t.r) || t.r == ';' {
					end_rune := t.current_rune;
							
					string_value : string = utf8.runes_to_string(t.content[begin_rune:end_rune], context.temp_allocator);
					
					if is_float || true {
						value, ok := parse_float(string_value); //f64
						value *= cast(f64)mult;
						fmt.assertf(ok, "Internal error failed to parse float litereal : %v", string_value);
						emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_rune}, value});
						//log.debugf("parsing value : %v", value);
						break;
					}
					else { //TODO we currently only do floats? is that ok?
						value, ok := parse_int(string_value); //i64
						value *= mult;
						fmt.assertf(ok, "Internal error failed to parse int litereal : %v", string_value);
						emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_rune}, value});
						break;
					}
				}
				else if t.r == 'E' || t.r == 'e' {
					
					end_digits := t.current_rune;
					begin_exp := t.current_rune + 1;
					is_exp_negative := false;
					
					//always include the one directly after an e
					next_rune(&t);
					if t.r == '+' {
						//valid
						next_rune(&t);
						begin_exp = t.current_rune;
					}
					else if t.r == '-' {
						//valid, note negative and skip to next rune
						is_exp_negative = true;
						next_rune(&t);
						begin_exp = t.current_rune;
					}
					else if unicode.is_digit(t.r) {
						//ok, dont to anything
					}
					else {
						//not ok,
					}
					
					//parse the last part
					for !is_done(&t) {
						if is_done(&t) || strings.is_space(t.r) || is_operator(t.r) || is_delimiter(t.r) {
											
							
							string_value : string = utf8.runes_to_string(t.content[begin_rune:end_digits], context.temp_allocator);
							exp_val_runes := t.content[begin_exp:t.current_rune];
							
							last_non_letter : int = t.current_rune;
							
							for r, i in exp_val_runes {
								if unicode.is_letter(r) {
									last_non_letter = begin_exp + i;
									break;
								}
							}
							
							exponent_value : string = utf8.runes_to_string(t.content[begin_exp:last_non_letter], context.temp_allocator);
							
							postfix_mult : f64 = 1;
							
							if last_non_letter != t.current_rune {
					 			postfix := utf8.runes_to_string(t.content[last_non_letter:t.current_rune], context.temp_allocator);
								ok : bool;
								postfix_mult, ok = parse_number_postfix(postfix)
								assert(ok);
							}
							
							//TODO, we could in the exponent just subtract, but that requires moving the parse_postfix logic out a level, which might be ok. 
							//We could also make it more genreal, by simply always parsing the last postfix individually.
							
							exp, exp_ok := strconv.parse_f64(exponent_value);
							fmt.assertf(exp_ok, "Internal error failed to parse float litereal exponent : %v %v(%v)", exponent_value, t.filename, t.current_line);
							if is_exp_negative {
								exp *= -1;
							}
							
							multiplier := math.pow(10, exp);
							
							value, ok := parse_float(string_value); //f64
							fmt.assertf(ok, "Internal error failed to parse float litereal : %v", string_value);
							emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_digits}, value * multiplier * postfix_mult});
							break;
						}
						else {
							next_rune(&t);
						}
					}
					break;
				}
				else if unicode.is_digit(t.r) || unicode.is_letter(t.r) {
					//contine, dont do anything
					next_rune(&t);
				}
				else {
					for !(strings.is_space(t.r) || is_done(&t)) {
						next_rune(&t);
					}
					end_rune := t.current_rune;
					emit_error(&t, "A litereal contains illigal charactor %v", begin_rune, end_rune, t.r);
					break;
				}
			}
		}
		else if unicode.is_letter(t.r) || t.r == '_' {
			//entering identifier
			begin_rune := t.current_rune;
			for !is_done(&t) {
				next_rune(&t);
				
				if unicode.is_letter(t.r) || unicode.is_digit(t.r) || t.r == '_' {
					//contiue, these are legal charactors
				}
				else if is_done(&t) || unicode.is_space(t.r) || is_operator(t.r) || is_delimiter(t.r) || t.r == ';'  {
					//legal exit condition
					end_rune := t.current_rune;
					string_value : string = utf8.runes_to_string(t.content[begin_rune:end_rune], context.temp_allocator); //This is now owned by the token.
					emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_rune}, cast(Identifier)strings.clone(string_value, allocator, loc = loc)});
					break;
				}
				else {
					end_rune := t.current_rune+1;
					assert(end_rune >= begin_rune);
					emit_error(&t, "A Identifier contains illigal charactor", begin_rune, end_rune);
					break;
				}
			}
		}
		else if t.r == ';' {
			begin_rune := t.current_rune;
			emit_token(&t, Token {t.current_line, {begin_rune, begin_rune+1}, Semicolon{}})
			next_rune(&t);
		}
		else if is_operator(t.r) && t.r == '/' && is_operator(peek_next(&t)) && peek_next(&t) == '/' {
			//enter a comment
			for !is_done(&t) {
				
				if t.r == '\n' {
					break;
				}
				
				//fmt.printf("ignoreing : %v\n", t.r);
				
				next_rune(&t);
			}
		}
		else if is_operator(t.r) {
			begin_rune := t.current_rune;
			next_rune(&t);
			
			for !is_done(&t) {
				
				break_out := false;
				
				if t.current_rune < len(t.content) {
					//Look ahead if we find a valid operator continue
					next_string_value : string = utf8.runes_to_string(t.content[begin_rune:t.current_rune+1], context.temp_allocator);
					op, ok := parse_opeartor(next_string_value);
					if ok {
						next_rune(&t)
					}
					else {
						break_out = true;
					}
				}
				
				if break_out {
					//emit now					
					end_rune := t.current_rune;
					string_value : string = utf8.runes_to_string(t.content[begin_rune:end_rune], context.temp_allocator); 
					log.debugf("emitting : '%v', %v", string_value, break_out)
					op, ok := parse_opeartor(string_value);
					assert(ok)
					emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_rune}, op})
					break;
				}
			}
		}
		else if is_delimiter(t.r) {
			begin_rune := t.current_rune;
			next_rune(&t);
			end_rune := t.current_rune;
			string_value : string = utf8.runes_to_string(t.content[begin_rune:end_rune], context.temp_allocator);
			delimiter, ok := parse_delimiter(string_value);
			
			if ok {
				emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_rune}, delimiter});
			}
			else {
				fmt.panicf("No such delimiter : %v", string_value);
				//emit_error(&t, "No such delimiter", begin_rune, end_rune);
			}
		}
		else if t.r == '"' {
			//This is a string litereal
			next_rune(&t);
			begin_rune := t.current_rune;
			for !is_done(&t) {
				end_rune := t.current_rune;
				
				if (t.r == '"') {
					string_value : string = utf8.runes_to_string(t.content[begin_rune:end_rune], context.temp_allocator); 
					lit : String_litereal = cast(String_litereal) strings.clone(string_value, allocator, loc = loc);
					
					emit_token(&t, Token{t.current_line, [2]int{begin_rune, end_rune}, lit}); //The string is owned by the token
					//log.debugf("found string litereal value : %v", string_value);
					next_rune(&t);
					break;
				}
				next_rune(&t);
			}
		}
		else {
			emit_error(&t, "illigal charactor", t.current_rune, t.current_rune+1);
		}
	}
	
	emit_token(&t, Token{t.current_line, {t.current_rune, t.current_rune}, End_of_file{}})
	
	return Tokenize_result{
		slice.clone(t.tokens[:], allocator),
		slice.clone(t.errors[:], allocator),
		area_alloca,
		new(int, backing_allocator),
	};
}

@(private)
destroy_token_res :: proc (res : ^Tokenize_result) {
	free(res.dummy_ptr);
	vmem.arena_destroy(&res.allocator);
}

import "core:mem"
import vmem "core:mem/virtual"
import "core:math"
import "core:unicode"
import "core:unicode/utf8"
import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:log"
import "core:slice"
import "core:reflect"

Operator :: enum {
	comma = ',',
	dot = '.',
	assign = '=',	
	minus = '-',
	not = '!',
	power = '^',			//^
	multiply = '*',
	divide = '/',
	modulo = '%',
	add = '+',
	equality = 258,			//==
	non_equal = 259,		//!=
	less_or_equal = 260,	//<=
	greater_or_equal = 261, //>=
	less_than = '<', 		
	greater_than = '>',
	and = 262, 				//&&
	or = 263, 				//||
	colon = ':',
	return_arrow = 264, 	//->
	
	unknown = 256,
}

@(private)
is_operator :: proc (r : rune) -> bool {

	s, ok := reflect.enum_name_from_value(cast(Operator)r)
	
	if ok {
		return true;
	}
	
	return false;
}

@(private)
parse_opeartor :: proc (s : string) -> (op : Operator, ok : bool) {
	switch s {
		case ",":
			return .comma, true;
		case ".":
			return .dot, true;
		case "=":
			return .assign, true;			
		case "-":
			return .minus, true;
		case "!":
			return .not, true;
		case "^":
			return .power, true;
		case "*":
			return .multiply, true;
		case "/":
			return .divide, true;
		case "%":
			return .modulo, true;
		case "+":
			return .add, true;
		case "==":
			return .equality, true;
		case "!=":
			return .non_equal, true;
		case "<=":
			return .less_or_equal, true;
		case ">=":
			return .greater_or_equal, true;
		case ">":
			return .greater_than, true;
		case "<":
			return .less_than, true;
		case "&&":
			return .and, true;
		case "||":
			return .or, true;
		case ":":
			return .colon, true;
		case "->":
			return .return_arrow, true;
		case:
			return nil, false;
	}
}

Delimiter :: enum {
	comma = ',',
	paren_begin = '(',
	paren_end = ')',
	bracket_begin = '{',
	bracket_end = '}',
	sqaure_begin = '[',
	sqaure_end = ']',
}

@(private)
is_delimiter :: proc (r : rune) -> bool {
	buf : [1]rune = {r};
	s := utf8.runes_to_string(buf[:], context.temp_allocator);
	
	//fmt.printf("Checking : '%s', r is : '%v', buf is : '%v'\n", s, r, buf);
	
	_, ok := parse_delimiter(s);
	return ok;
}

@(private)
parse_delimiter :: proc (s: string) -> (op : Delimiter, ok : bool) {
	switch s {
		case "(":
			return .paren_begin, true;
		case ")":
			return .paren_end, true;
		case "{":
			return .bracket_begin, true;
		case "}":
			return .bracket_end, true;
		case:
			return nil, false;
	}
}

Semicolon :: struct {};
End_of_file :: struct {};

Identifier :: distinct string;
String_litereal :: distinct string;
Untyped_number :: struct {
	origin : string,
}
Token_type :: union {
	Delimiter,			//like ( or ,
	Operator,			//like + or **
	Identifier,			//Identifier			//Any name
	String_litereal, 	//String litereal, like a path
	int, 				//Integer_literal	//An int like 2
	f64,				//A float like 31.2341
	//Untyped_number,		//Untyped number
	Semicolon,
	End_of_file,
};

Token :: struct {
	
	line_number : int,
	range : [2]int,
	
	value : Token_type,
}

Error :: struct {
	msg : string,
	line : int,
	begin_rune : int,
	end_rune : int,
}

@(private)
string_to_runes_and_add_space :: proc (s: string, allocator := context.allocator) -> (runes: []rune) {
	n := utf8.rune_count_in_string(s)
	runes = make([]rune, n + 1, allocator)
	
	i := 0
	for r in s {
		runes[i] = r
		i += 1
	}
	runes[len(runes)-1] = ' ';
	
	return
}

@private
parse_number_postfix :: proc (s: string) -> (mult : f64, ok : bool) {
	
	get_first_three_runes :: proc(s: string) -> string {
		buf: [12]u8; // Max 3 runes × up to 4 bytes per UTF-8 rune
		i: int = 0;
		r_cnt := 0;
		
		for r_cnt := 0; r_cnt < 3; r_cnt+=1 {
			codepoint := utf8.rune_at(s, r_cnt);
			width := utf8.rune_size(codepoint);
			bytes := transmute([4]u8)codepoint;
			for j in 0..<width {
				buf[i+j] = bytes[j];
			}
			i += width;
		}

		return string(buf[:i]);
	}
	
	if utf8.rune_count(s) >= 3 {
		
		three_letter := get_first_three_runes(s);
		
		switch three_letter {
			case "Meg":
				return pow(10, 6), true;
			case "Mil", "mil":
				return 25.4 * pow(10, -6), true;
		}
		
	}
	
	if len(s) < 1 {
		return 1, false;
	}
	
	first_letter := utf8.rune_at(s, 0);
	
	pow :: math.pow_f64;
	
	switch first_letter {
		case 'T', 't':
			return pow(10, 12), true;
		case 'G', 'g':
			return pow(10, 9), true;
		case 'K', 'k':
			return pow(10, 3), true;
		case 'm':
			return pow(10, -3), true;
		case 'u':
			return pow(10, -6), true;
		case 'n':
			return pow(10, -9), true;
		case 'p':
			return pow(10, -12), true;
		case 'f':
			return pow(10, -15), true;
		case 'a':
			return pow(10, -18), true;
	}
	
	return 1, false;
}

//Parses floats with post-fix like 1.0u
@private
parse_float :: proc (s : string) -> (val : f64, ok : bool) {
	base_str := s;
	suffix_start := -1;
	exponent_start := -1;
	
	// Find where the numeric part ends and postfix begins
	for i := 0; i < len(s); {
		r, size := utf8.decode_rune(s[i:]) // decode a rune from UTF-8
		
		if unicode.is_letter(r) {
			suffix_start = i;
			break;
		}
		
		i += size // move forward by the number of bytes the rune took
	}
	
	if suffix_start == -1 {
		val, ok = strconv.parse_f64(s);
		return val, ok;
	}
	
	num_str := s[:suffix_start];
	suffix := s[suffix_start:];
	
	if s[suffix_start] == 'e' || s[suffix_start] == 'E' {
		
		//mult, mult_ok := parse_number_postfix(suffix);
		
		return 0, false;
	}
	else {
		num_ok : bool;
		val, num_ok = strconv.parse_f64(num_str);
		if !num_ok {
			return 0, false;
		}
		
		mult, mult_ok := parse_number_postfix(suffix);
		if !mult_ok {
			return 0, false;
		}
		
		return val * mult, true;
	}
}

//Parses floats with post-fix like 1k
@private
parse_int :: proc(s : string) -> (val : int, ok : bool) {
	suffix_start := -1;

	for i in 0..<len(s) {
		if !(s[i] >= '0' && s[i] <= '9') {
			suffix_start = i;
			break;
		}
	}

	if suffix_start == -1 {
		val64, ok := strconv.parse_int(s);
		return int(val64), ok;
	}

	num_str := s[:suffix_start];
	suffix := s[suffix_start:];

	val64, num_ok := strconv.parse_int(num_str);
	if !num_ok {
		return 0, false;
	}
	
	mult, mult_ok := parse_number_postfix(suffix);
	if !mult_ok {
		return 0, false;
	}

	return int(f64(val64) * mult), true;
}

@private
clone_errors :: proc (errors : []Error) -> []Error {
	
	_errors := make([]Error, len(errors));
	
	for e, i in errors {
		_errors[i] = Error{strings.clone(e.msg), e.line, e.begin_rune, e.end_rune};
	}
	
	return _errors;
}

@private
destroy_errors :: proc (errors : []Error) {
	
	for e in errors {
		delete(e.msg);
	}	
	delete(errors);
}