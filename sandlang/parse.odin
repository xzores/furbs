#+feature dynamic-literals
package sand_lang;

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

/////////////////////////////////////////////////////////////////////////// Expression ///////////////////////////////////////////////////////////////////////////

Call :: struct {
	called : string,		  // Function name (or reference to a Function)
	args   : []^Expression,	// List of arguments (expressions)
}

Assignment :: struct {
	lhs : string,   // The left-hand side (e.g., variable)
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
	power, 		// e.g, a ^ b
	//abs_modulo,   // e.g., a %% b
	//logical_and,  // e.g., a && b
	//logical_or,   // e.g., a || b
	//bitwise_and,  // e.g., a & b
	//bitwise_or,   // e.g., a | b
	//bitwise_xor,  // e.g., a ^ b
	//shift_left,   // e.g., a << b
	//shift_right,  // e.g., a >> b
	and, 			//e.g, a && b
	or, 			//e.g, a || b
	equals,	   // e.g., a == b
	not_equals,   // e.g., a != b
	greater_than, // e.g., a > b
	less_than,	// e.g., a < b
	greater_eq,   // e.g., a >= b
	less_eq,	  // e.g., a <= b
	
	//A fake opeartor
	comma,
}

Binary_operator :: struct {
	op	  : Binary_operator_kind, 
	left : ^Expression,	  // The expression being operated on
	right : ^Expression,	  // The expression being operated on
}

Float_literal :: struct {
	value : f64,  // Could be int, float, string, bool, etc.
}

Int_literal :: struct {
	value : int,  // Could be int, float, string, bool, etc.
}

Boolean_literal :: struct {
	value : bool,  // Could be int, float, string, bool, etc.
}

Expression :: union {
	Call,
	Assignment,
	Unary_operator,
	Binary_operator,
	Float_literal,
	Int_literal,
	Boolean_literal,
	String_litereal,
	Variable_exp,
}

Variable_exp :: struct {
	//Leaf
	variable_name : string,
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Import_statement :: struct {
	to_import : string,
	import_as : string,
}

@(private)
parse :: proc (file_location : string, state : ^Sand_state, tokens : []Token) -> []Error {
	
	parse_res := parse_scope(file_location, state, tokens, state.global_scope);
	defer destroy_errors(parse_res.errors);
	defer destroy_import_statements(parse_res.imports);
	
	for imp in parse_res.imports {
		//as := strings.clone(imp.import_as);
		//state.import
		//log.warnf("TODO import callback : %v", as);
		//state.imports[as] = Import_space{};
	}
	
	if len(parse_res.instructions) != 0 {
		err := make([]Error, 1);
		err[0] = Error{"You may not have runable code in the global state", 1, 0, 0}
		return err;
	}

/*
	for name, func in parse_res.scope.functions {
		state.global_scope.functions[name] = func;
	}
	delete(parse_res.scope.functions);
	
	for name, stct in parse_res.scope.structs {
		state.global_scope.structs[name] = stct;
	}
	delete(parse_res.scope.structs);
*/

	assert(parse_res.scope.parent == nil)
	
	return clone_errors(parse_res.errors);
}

@(private)
Parse_result :: struct {
	scope : ^Scope,
	instructions : []Instruction,
	imports : []Import_statement,
	errors : []Error,
}

@(private, require_results)
parse_scope :: proc (file_location : string, state : ^Sand_state, tokens : []Token, scope : ^Scope, loc := #caller_location) -> (Parse_result) {
	
	Parser :: struct {
		filename : string,
		tokens : []Token, //just a view
		current_token : int,
		is_done : bool,
		t : Token,
		
		scope : ^Scope,
		instructions : [dynamic]Instruction,	//An instruction is a simple add or multiply or function call, only one thing at a time.
		imports : [dynamic]Import_statement,
		errors : [dynamic]Error,
	}
	
	p : Parser = {
		file_location,
		tokens,
		-1,
		false,
		{},
		scope,
		make([dynamic]Instruction),
		make([dynamic]Import_statement),
		make([dynamic]Error),
	};
	
	if len(tokens) == 0 {
		return Parse_result {
			p.scope,
			p.instructions[:],
			p.imports[:],
			p.errors[:],
		}
	}
	
	next_token :: proc (p : ^Parser, loc := #caller_location) {
		assert(len(p.tokens) != 0, "tokens are nil", loc)
		if p.is_done {
			return;
		}
		if p.current_token < len(p.tokens)-1 {
			p.current_token += 1;
			if p.current_token == len(p.tokens)-1 {
				p.is_done = true;
			}
		}
		p.t = p.tokens[p.current_token];
		//log.debugf("found token : %v", p.t);
	}
	
	peek_token :: proc (p : ^Parser) -> Token {
		return p.tokens[p.current_token + 1];
	}
	
	emit_function :: proc (p : ^Parser, name : string, func : Function) {
		assert(!(name in p.scope.functions));
		p.scope.functions[name] = func;
	}
	
	emit_struct :: proc (p : ^Parser, name : string, s : Struct) {
		assert(!(name in p.scope.structs));
		p.scope.structs[name] = s;
	}
	
	emit_instruction :: proc (p : ^Parser, inst : Instruction) {
		append(&p.instructions, inst);
	}
	
	//import_name is the name which overrides to_import default name
	emit_import :: proc (p : ^Parser, import_name : string, to_import : string) {
		
		append(&p.imports, Import_statement{
			to_import,
			import_name,
		});
		
	}
	
	expect :: proc (p : ^Parser, expected_value : Token_type) -> (ok : bool){
		
		if p.t.value != expected_value {
			return false;
		}
		
		return true;
	}
	
	emit_error :: proc (p : ^Parser, msg : string, args: ..any, loc := #caller_location) {
		err_msg := fmt.aprintf(msg, ..args);
		
		current_line := p.t.line_number;
		
		log.error(fmt.tprintf("%v(%v) Parser error : %v", p.filename, current_line, err_msg), location = loc);
		append(&p.errors, Error{err_msg, current_line, -1, -1});
		next_token(p); // move forward
	}
	
	instructize_exp :: proc (p : ^Parser, emit_exp : ^Expression, loc := #caller_location) {
		assert(emit_exp != nil, "emit_exp is nil", loc)
		
		switch exp in emit_exp {
			case Assignment: {
				
				//Go though rhs and calculate the result, place it in reg0
				instructize_exp(p, exp.rhs);
				
				emit_instruction(p, Store_inst{
					strings.clone(exp.lhs),
					0,
				});
			}
			case Binary_operator: {
			
				instructize_exp(p, exp.left);
				emit_instruction(p, Push_inst{}); //temp storage
				
				assert(exp.right != nil, )
				instructize_exp(p, exp.right);
				emit_instruction(p, Move_inst{
					2,
				});
				
				emit_instruction(p, Pop_inst{1}); //temp storage
				
				emit_instruction(p, Binary_inst {
					exp.op,
				});
			}
			case Unary_operator: {
				
				instructize_exp(p, exp.operand);
				emit_instruction(p, Move_inst{
					1,
				});
			
				emit_instruction(p, Unary_inst{
					exp.op,
				})
			}
			case Boolean_literal: {
				emit_instruction(p, Set_inst{
					exp.value,
					0,
				})
			}
			case Float_literal: {
				emit_instruction(p, Set_inst{
					exp.value,
					0,
				})
			}
			case Int_literal: {
				emit_instruction(p, Set_inst{
					exp.value,
					0,
				})
			}
			case String_litereal: {
				emit_instruction(p, Set_inst{
					strings.clone(cast(string)exp),
					0,
				})
			}
			case Call: {
				panic("TODO");
			}
			case Variable_exp: {
				emit_instruction(p, Load_inst{
					strings.clone(exp.variable_name),
					0,
				})
			}
		}
		
	}
	
	is_done :: proc (p : ^Parser) -> bool {
		return p.is_done;
	}
	
	resolve_type :: proc (p : ^Parser, type_name : string) -> (Sand_type) {
		res : Sand_type = nil;
		
		switch type_name {
			case "f64":
				res = ._f64;
			case "bool":
				res = ._bool;
			case "string":
				res = ._string;
			case "int":
				res = ._int;
		}
		
		if res == nil {
			fmt.panicf("TODO check structs, got %v", type_name);
		}
		
		return res;
	}
	
	
	parse_variable_list :: proc (p : ^Parser, body_tokens : []Token, loc := #caller_location) -> []Variable_entry {
		
		what : enum {
			mname,
			colon,
			mtype,
			comma,
		}
		
		members := make([dynamic]Variable_entry);
		
		mem_name : string;
		mem_type : string;
		
		for bt in body_tokens {
			switch what {
				case .mname:
					//expect a name
					assert(mem_name == "");
					
					#partial switch val in bt.value {
						case Identifier:
							mem_name = cast(string)val
						case:
							emit_error(p, "there is a missing type in struct definition");
							return {}; //TODO cleanup
					}
					what = .colon;
				
				case .colon: 
					expect(p, Semicolon{})
					what = .mtype;
					
				case .mtype:
					//expect a mtype
					assert(mem_type == "");
						
					#partial switch val in bt.value {
						case Identifier:
							mem_type = cast(string)val
						case:
							emit_error(p, "there is a missing type in struct definition");
							return {}; //TODO cleanup
					}
					what = .comma;
					
					//emit the name and type
					append(&members, Variable_entry{strings.clone(mem_name, loc = loc), Sand_type{}}, loc = loc); //TODO real type instead of nothing
					mem_name = "";
					mem_type = "";
				case .comma:
					//expect a comma
					expect(p, Operator.comma)
					what = .mname;
			}
		}
		
		if what == .colon {
			emit_error(p, "there is a missing ':' in struct definition");
		}
		
		if what == .mtype {
			emit_error(p, "there is a missing type in struct definition");
		}
		
		return members[:];
	}
	
	parse_expression :: proc (p : ^Parser, exp_tokens : []Token, loc := #caller_location) -> ^Expression {
		
		//log.debugf("parse_expression got : %v", exp_tokens);
		
		Exp_parser :: struct {
				
			tokens : []Token, //just a view
			current_token : int,
			is_done : bool,
			t : Token,
			
			lhs : ^Expression,
		}
		
		e : Exp_parser = {
			exp_tokens,
			-1,
			false,
			{},
			nil,
		};
		
		is_done :: proc (e : ^Exp_parser) -> bool {
			return e.is_done;
		}
		
		next_token :: proc (e : ^Exp_parser) {
			if e.is_done {
				return;
			}
			if e.current_token < len(e.tokens)-1 {
				e.current_token += 1;
				if e.current_token == len(e.tokens) {
					e.is_done = true;
				}
			}
			
			e.t = e.tokens[e.current_token];
		}
		
		peek_token :: proc (e : ^Exp_parser) -> Token {
			
			return e.tokens[e.current_token + 1];
		}
		
		is_binary_operator :: proc (operator : Operator) -> bool {
			
			#partial switch operator {
				case .and, .add, .equality, .divide, .greater_or_equal, .greater_than, .less_or_equal, .less_than, .minus, .modulo, .multiply, .non_equal, .or, .power:
					return true;
				case:
					return false;
			}
			
			unreachable();
		}
		
		as_binary_operator :: proc (operator : Operator) -> Binary_operator_kind {
			
			#partial switch operator {
				case .add:
					return .add;
					
				case .and:
					return .and;
					
				case .equality:
					return .equals;
			
				case .divide:
					return .divide;

				case .greater_or_equal:
					return .greater_eq
					
				case .greater_than:
					return .greater_than;

				case .less_or_equal:
					return .less_eq
				
				case .less_than:
					return .less_than;

				case .minus:
					return .subtract;
				
				case .modulo:
					return .modulo;

				case .multiply:
					return .multiply;

				case .non_equal:
					return .not_equals;

				case .or:
					return .or;
				
				case .power:
					return .power;
					
				case:
					panic("TODO");
			}
			
			unreachable()
		} 
		
		for tok in exp_tokens {
			//fmt.printf("e : %#v, exp_tokens : %v\n", e, exp_tokens);
			
			switch t in tok.value {
				
				case Delimiter, End_of_file, Semicolon: {
					emit_error(p, "Unexpected token %v in expression", t);
					return {};
				}
				
				case f64: {
					if e.lhs != nil {
						emit_error(p, "cannot resolve expression, there seems to be missing an operator");
						return {};
					}
					
					exp := new(Expression);
					exp^ = Float_literal{t};
					
					e.lhs = exp;
					next_token(&e);
				}
				case int: {
					if e.lhs != nil {
						emit_error(p, "cannot resolve expression, there seems to be missing an operator");
						return {};
					}
					exp := new(Expression);
					exp^ = Int_literal{t};
					
					e.lhs = exp
					next_token(&e);
				}
				case Identifier: {
					if e.lhs != nil {
						emit_error(p, "cannot resolve expression, there seems to be missing an operator");
						return {};
					}
					
					exp := new(Expression);
					exp^ = Variable_exp{strings.clone(cast(string)t, loc = loc)};
					
					e.lhs = exp
					
					next_token(&e);
				}
				case String_litereal: {
					if e.lhs != nil {
						emit_error(p, "cannot resolve expression, there seems to be missing an operator");
						return {};
					}
					
					exp := new(Expression);
					exp^ = cast(String_litereal)strings.clone(cast(string)t);
					
					e.lhs = exp
					
					next_token(&e);
				}
				case Operator: {
					
					if is_binary_operator(t) {
						//it is a binary operator						
						
						if e.lhs == nil {
							emit_error(p, "Operator %v missing lhs", t);
							return {};
						}
						
						lhs := e.lhs;
						rhs := parse_expression(p, e.tokens[e.current_token+2:]); //parse the rest.
						assert(rhs != nil)
						
						exp := new(Expression);
						exp^ = Binary_operator {
							as_binary_operator(t),
							lhs,	  // The expression being operated on
							rhs,	  // The expression being operated on
						};
						
						return exp;
					}
					else {
						fmt.panicf("TODO : %v", t);
					}
				}
				case: {
					next_token(&e);
					fmt.panicf("Bad case exp_tokens : %v", exp_tokens);
				}
			}
		}
		
		fmt.assertf(e.lhs != nil, "tokens was : %v", exp_tokens)
		
		return e.lhs;
	}
	
	next_token(&p);
	for !is_done(&p) {
		
		switch t in p.t.value {
			case Delimiter: {
				emit_error(&p, "Invalid placement of delimiter")
			}
			case f64: {
				emit_error(&p, "Invalid placement of f64 litereal")	
			}	
			case Identifier: {
				
				if t in keywords {
					
					next_token(&p) 
					
					switch t {
						case "import":
							
							import_name : string;
							
							#partial switch v1 in p.t.value {
								case String_litereal: {
									//ok, just go to the place where we find the import
									import_name = cast(string)v1;
								}
								case Identifier: {
									//This is a rename
									import_name = cast(string)v1;
									next_token(&p);
								}
								case:
									emit_error(&p, "unexpected %v", v1);
							}
							
							#partial switch v1 in p.t.value {
								case String_litereal: {
									//could be a "for something in something_else"
									log.infof("Importing : '%v' as '%v'", v1, import_name)
									
									emit_import(&p, strings.clone(import_name), strings.clone(cast(string)v1));
									
									//expect the following token to be ;
									next_token(&p);
									if _, ok := p.t.value.(Semicolon); !ok {
										emit_error(&p, "Expected a semicolon, got %v", p.t.value);
									}
								}
								case:
									emit_error(&p, "unexpected %v", v1);
							}
							
						case "for":
							#partial switch v1 in p.t.value {
								case Identifier: {
									//could be a "for something in something_else"
									panic("TODO for");
								}
								case: 
									emit_error(&p, "unexpected %v", v1);
							}
							
						case "if":
							panic("TODO");
					}
					
					continue;	
				}
				
				next_token(&p);
				
				Lhs_assignment :: struct {
					assign_to : Identifier, //how to i represent indexing?
				}
				
				Variable_declation :: struct {
					name : Identifier,
					type : Sand_type,
					also_assign : bool,
				}
				
				Struct_definition :: struct {
					struct_name : Identifier,
				}
				
				Proc_definition :: struct {
					proc_name : Identifier,
				}
				
				what : union {
					Lhs_assignment,
					Variable_declation,
					Struct_definition,
					Proc_definition,
				} = nil;
				
				switch v1 in p.t.value {
					case Identifier, String_litereal, Semicolon, int, f64, End_of_file: {
						emit_error(&p, "unexpected token %v", v1);
					}
					case Delimiter: {
						//this could be a function call, or assignment to an array
						
						switch v1 {
							case .bracket_begin, .bracket_end, .comma, .sqaure_end, .paren_end: {
								emit_error(&p, "Unexpected delimiter : %v", v1)
							}
							case .paren_begin: {
								//it is a function call
								
								//consume the ( and find the corrisponding )
								next_token(&p);
								begin_args := p.current_token;
								
								paren_cnt := 1;
								//Find the corrisponding }
								for paren_cnt != 0 {
									
									if p.t.value == Delimiter.paren_begin {
										paren_cnt += 1;
									}
									else if p.t.value == Delimiter.paren_end {
										paren_cnt -= 1;
									}
									else if _, ok := p.t.value.(End_of_file); ok {
										emit_error(&p, "found end of file, expected ')'");
										break;
									}
									
									//fmt.printf("Token : %v\n", p.t);
									next_token(&p);
								}
								end_args := p.current_token-1;
								
								args := make([dynamic]^Expression);
								defer {
									for a in args {
										destroy_expression(a);
									}
									delete(args);
								}
								
								if begin_args != end_args {
									exp := parse_expression(&p, p.tokens[begin_args:end_args]);
									
									//Go though and extract the array from bwteen ","
									if bo, ok := exp.(Binary_operator); bo.op == .comma {
										panic("TODO handle multiple arguments in function call");
									}
									
									append(&args, exp);			
								}
								
								expect(&p, Semicolon{});
								
								for e in args[:] {
									instructize_exp(&p, e);
									
									//The expressions result in place in reg0, we push this to the stack so that we can later call with what is on the stack.
									emit_instruction(&p, Push_inst{});
								}
								
								//find func
								func, ok := find_func(p.scope, cast(string)t);
								
								if ok {
									switch f in func {
										case Function_sand:
											emit_instruction(&p, Call_inst{
												f.call,
											});
										
										case Function_odin:
											panic("TODO");
									}
								}
								else {
									emit_error(&p, "No such function '%v', scope : %#v", t, p.scope.parent);
									break;
								}
								
							}
							case .sqaure_begin: {
								//this is assignment to array
								panic("TODO");
							}
						}
						
					}
					case Operator: {
						//This could be an assignment "=" or a "+=" thing
						
						switch v1 {
							case .comma, .not, .power, .multiply, .divide, .modulo, .non_equal, .equality, .less_or_equal, .greater_or_equal, .less_than, .greater_than, .and, .or, .return_arrow: {
								emit_error(&p, "Unexpected operator : %v", v1)
							}
							case .dot: {
								//could be an assingment to the something.something_else
								panic("TODO");
							}
							case .assign: {
								//IT is an assignment
								what = Lhs_assignment {
									assign_to = t,
								};
								
								log.warnf("TODO, the 'variable.something[0].something_else[4]' cannot be assigned to yet");
							}
							case .minus: {
								panic("TODO");
							}
							case .add: {
								panic("TODO");
							}
							case .colon: {
								//This is some sort of definition
								
								next_token(&p);
								
								switch v2 in p.t.value {
									case Delimiter, End_of_file, f64, int, Semicolon, String_litereal:
										//Thse are not valid
										emit_error(&p, "Unexpected : %v", v1)
										
									case Operator: {
										//this could be antoher semicolon, this is a proc or struct definition
										
										#partial switch v2 {
											case .assign: {
												//we are trying to do an untyped assign
												panic("todo, this feature is missing");
											}
											case .colon: {
												//this is a proc or struct definition
												
												next_token(&p);
												
												#partial switch v3 in p.t.value {
													case Identifier:
														
														switch v3 {
															case "struct":{
																//emit a struct
																what = Struct_definition {
																	t,
																}
															}
															case "proc": {
																//emit a function
																what = Proc_definition {
																	t,
																}
															}
															case: 
																emit_error(&p, "after :: must be 'struct' or 'proc'");	
														}
													case: 
														emit_error(&p, "unexpected %v", v3)
												}
												
											}
										}
									}
									case Identifier: {
										//This is the type
										
										next_token(&p);
										
										#partial switch v4 in p.t.value {
											case Semicolon: {
												//ok just emit the declaration
												what = Variable_declation {
													t,
													resolve_type(&p, cast(string)v2),
													false,
												}
											}
											case Operator: {
												//this is a variable typed declaration with an assignment
												#partial switch v4 {
													case .assign:
														//ok emit the declaration
														what = Variable_declation {
															t,
															resolve_type(&p, cast(string)v2),
															true,
														}
													case:
														emit_error(&p, "unexpected %v", v4);
												}
											}
											case:
												emit_error(&p, "unexpected %v", v4);
										}
										
									}	
								}
							}
							case .unknown: {
								panic("!?!?!");
							}
						}
					}
				}
				
				//log.debugf("skipping over %v", p.t)
				next_token(&p);
				
				emit_exp : ^Expression;
				defer destroy_expression(emit_exp);
				
				switch w in what {
					
					case Lhs_assignment: {
						panic("TODO LHS assignment");
					}
					case Variable_declation: {
						
						emit_instruction(&p, Declare_inst{
							strings.clone(cast(string)w.name),
							-1,
							w.type,
						});
						
						//If we also assign, find the next ; and then parse that expression
						if w.also_assign {
							begin_exp := p.current_token;
							
							for !is_done(&p) {
								
								if _, ok := p.t.value.(Semicolon); ok {
									break;
								}
								next_token(&p)
							}
							
							end_exp := p.current_token;	
							
							rhs_exp := parse_expression(&p, p.tokens[begin_exp:end_exp]);						
							assert(rhs_exp != nil, "rhs_exp is nil")
							
							emit_exp = new(Expression);
							emit_exp^ = Assignment {
								strings.clone(cast(string)w.name),
								rhs_exp,
							};
						}
						
					}
					case Struct_definition: {
						expect(&p, Delimiter.bracket_begin);
						next_token(&p);
						begin_body := p.current_token;
						
						backet_cnt := 1;
						
						//Find the corrisponding }
						for backet_cnt != 0 {
							
							if p.t.value == Delimiter.bracket_begin {
								backet_cnt += 1;
							}
							else if p.t.value == Delimiter.bracket_end {
								backet_cnt -= 1;
							}
							else if _, ok := p.t.value.(End_of_file); ok {
								emit_error(&p, "found end of file, expected '}'");
							}
							
							next_token(&p);
						}
						end_body := p.current_token-1;
						
						//log.debugf("Found struct scope : %#v", p.tokens[begin_body:end_body]);
						
						struct_members := parse_variable_list(&p, p.tokens[begin_body:end_body]);
						
						emit_struct(&p, strings.clone(cast(string)w.struct_name), Struct{
							strings.clone(cast(string)w.struct_name),
							{struct_members},
						})
					}
					case Proc_definition: {
						
						//parse the parame list 
						expect(&p, Delimiter.paren_begin);
						next_token(&p);
						begin_args := p.current_token;
						
						paren_cnt := 1;
						//Find the corrisponding }
						for paren_cnt != 0 {
							
							if p.t.value == Delimiter.paren_begin {
								paren_cnt += 1;
							}
							else if p.t.value == Delimiter.paren_end {
								paren_cnt -= 1;
							}
							else if _, ok := p.t.value.(End_of_file); ok {
								emit_error(&p, "found end of file, expected ')'");
								break;
							}
							
							//fmt.printf("Token : %v\n", p.t);
							next_token(&p);
						}
						end_args := p.current_token-1;
						
						arguments := parse_variable_list(&p, p.tokens[begin_args:end_args]);
						
						return_type : Sand_type = nil;
						
						if op, ok := p.t.value.(Operator); ok {
							if op == .return_arrow {
								//Parse the return value
								next_token(&p);
								
								if iden, ok := p.t.value.(Identifier); ok {
									
									return_type = resolve_type(&p, cast(string)iden);
									next_token(&p);
								}
								else {
									emit_error(&p, "Expected identifier after ->");
									break;
								}
							}
							//dont to anything, just expect a bracket
						}
						
						//parse function body
						expect(&p, Delimiter.bracket_begin);
						next_token(&p);
						begin_body := p.current_token;
						
						backet_cnt := 1;
						
						//Find the corrisponding }
						for backet_cnt != 0 {
							
							if p.t.value == Delimiter.bracket_begin {
								backet_cnt += 1;
							}
							else if p.t.value == Delimiter.bracket_end {
								backet_cnt -= 1;
							}
							else if _, ok := p.t.value.(End_of_file); ok {
								emit_error(&p, "found end of file, expected '}'");
								break;
							}
							
							//fmt.printf("Token : %v\n", p.t);
							next_token(&p);
						}
						end_body := p.current_token-1;
						
						//log.debugf("Found function body : %#v", p.tokens[begin_body:end_body]);
						
						instructions : [dynamic]Instruction;
						
						for arg in arguments {
							append(&instructions, Declare_inst{
								strings.clone(arg.name),
								-1,
								arg.type,
							});
							append(&instructions, Pop_inst{
								0
							});
							append(&instructions, Store_inst{
								strings.clone(arg.name),
								0,
							});
						}
						
						res := parse_scope(file_location, state, p.tokens[begin_body:end_body], p.scope);
						defer destroy_errors(res.errors);
						defer destroy_import_statements(res.imports);
						defer delete(res.instructions);
						
						for inst in res.instructions {
							append(&instructions, inst);
						}
						
						if len(res.imports) != 0 {
							emit_error(&p, "function %v contains import statements, these are only allowed in the global state", t);
						}
						
						//This way we clone all the error and copy them to the parent parser and then deletes the slice
						cerrors := clone_errors(res.errors);
						defer delete(cerrors);
						
						for err in cerrors {
							append(&p.errors, err);
						}
						
						new_callable := new(Callable_function);
						
						new_callable^ = Callable_function{
							arguments,
							return_type,
							instructions[:],
						}
						
						append(&state.functions, new_callable)
						
						func := Function_sand {
							res.scope,
							new_callable,
						}
						
						emit_function(&p, strings.clone(cast(string)w.proc_name), func);
					}
				}
				
				//there are 3 registers, assign register (reg0), and then two rhs registers reg1 and reg2
				//there is a store and load command, these assign to
				if emit_exp != nil {
					
					//now walk the tree and do the instrucitons
					instructize_exp(&p, emit_exp);
				}	
			}
			case int: {
				emit_error(&p, "Invalid placement of int litereal")	
			}
			case Operator: {
				emit_error(&p, "Invalid placement of operator litereal")
			}
			case Semicolon: {
				//This is ignored
				next_token(&p);
			}
			case String_litereal: {
				emit_error(&p, "Invalid placement of string litereal")
			}
			case End_of_file: {
				log.infof("Reached end if file : %v", file_location);
				break;
			}
		}
	}
	
	return Parse_result {
		p.scope,
		p.instructions[:],
		p.imports[:],
		p.errors[:],
	}
	
}

@(private)
destroy_import_statements :: proc (imports : []Import_statement) {
	
	for imp in imports {
		delete(imp.to_import);
		delete(imp.import_as);
	}
	delete(imports);
}

@(private)
destroy_parse_result :: proc (res : Parse_result) {
	
	destroy_errors(res.errors);
	
	destroy_import_statements(res.imports);
	
	for a in res.instructions {
		
	}
	
	destroy_scope(res.scope);
	
}

@(private, require_results)
make_scope :: proc (parent : ^Scope) -> ^Scope {
	
	s := new(Scope);
	s^ = Scope{
		parent,
		make(map[string]Function),
		make(map[string]Struct),
	};
	
	return s;
}

@(private)
destroy_function :: proc (func : Function, loc := #caller_location) {
	
	switch f in func {
		case Function_sand:
			destroy_scope(f.local_scope);
		case Function_odin:
			//nothing
	}
}

Destroy_callable_function :: proc (func : ^Callable_function) {
	
	for arg in func.arguments {
		delete(arg.name);
	}
	delete(func.arguments);
	
	for instruction in func.instructions {
		switch v in instruction {
			case Binary_inst, Move_inst, Pop_inst, Push_inst, Unary_inst:
				//nothing
			case Declare_inst:
				delete(v.name);
			case Call_inst:
				//not owed by call_inst.
			case Call_odin_inst:
				//Not owned???
			case Load_inst:
				delete(v.variable_name);
			case Store_inst:
				delete(v.variable_name);
			case Set_inst:
				destroy_sand_value(v.val);
			
		}
	}
	
	delete(func.instructions);
	free(func);
}

@(private)
destroy_scope :: proc (to_destroy : ^Scope, loc := #caller_location) {
	
	assert(to_destroy != nil, "scope is nil");
	
	for n, f in to_destroy.functions {
		delete(n);
		destroy_function(f, loc);
	}
	delete(to_destroy.functions);
	
	for n, s in to_destroy.structs {
		delete(n);
		delete(s.name, loc = loc);
		destroy_struct_body(s.body);
	}
	delete(to_destroy.structs)
	
	free(to_destroy);
}

@(private)
destroy_struct_body :: proc (to_destroy : Struct_body) {
	
	for member in to_destroy.members {
		delete(member.name);
	}
	delete(to_destroy.members);
}

@(private)
destroy_expression :: proc (to_destroy : ^Expression) {
	
	if to_destroy == nil {
		return;
	}
	
	switch val in to_destroy {
		case Int_literal, Float_literal, Boolean_literal:
			//nothing
		case Assignment:
			delete(val.lhs)
			destroy_expression(val.rhs);
		case Binary_operator:
			destroy_expression(val.left);
			destroy_expression(val.right);
		case Call:
			panic("TODO")
		case String_litereal:
			delete(cast(string)val);
		case Variable_exp:
			delete(cast(string)val.variable_name);
		case Unary_operator:
			destroy_expression(val.operand);
	}
	
	free(to_destroy);
}

@(private)
destroy_sand_value :: proc (to_destroy : Sand_value) {
	
}

@(private)
find_func :: proc (scope : ^Scope, func_name : string) -> (f : Function, ok : bool) {
	
	if func_name in scope.functions {
		return scope.functions[func_name], true;
	}
	
	if scope.parent != nil {
		return find_func(scope.parent, func_name);
	}
	
	return {}, false;
}

keywords : map[Identifier]struct{} = {
	"import" = {},
	"for" = {},
	"if" = {},	
};
