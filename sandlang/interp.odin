package sand_lang;

import "core:strings"
import "core:log"
import "core:math"
import "core:fmt"

interpret :: proc (interp : ^Interp_state, func : ^Callable_function, loc := #caller_location) -> (ok : bool){
	
	error : bool = false;
	
	/*
	if len(func.args) > len(interp.stack) {
		error = true;
		log.errorf("Not enough arguments %v vs %v", len(func.args), len(interp.stack));
		return false;
	}
	*/
	
	push_scope(interp);
	
	for instruction in func.instructions {
		
		switch inst in instruction {
			case Declare_inst:{
				cur_scope := interp.scope_stack[len(interp.scope_stack)-1];
				if inst.name in cur_scope.variables {
					error = true;
					log.errorf("Variable %v has already been declared", inst.name);
					break;
				}
				
				name := inst.name;
				set_variable(interp, name, Runtime_value{nil, inst.type});
			}
			case Load_inst:{
				if !is_variable(interp, inst.variable_name) {
					error = true;
					log.errorf("Variable %v does not exists", inst.variable_name);
					break;
				}
				interp.regs[inst.reg] = get_variable(interp, inst.variable_name).val;
			}
			case Store_inst:{
				if !is_variable(interp, inst.variable_name) {
					error = true;
					log.errorf("Variable %v does not exists", inst.variable_name);
					break;
				}
				v := get_variable(interp, inst.variable_name);
				v.val = interp.regs[inst.reg]
				set_variable(interp, inst.variable_name, v);
			}
			case Move_inst:{
				interp.regs[inst.target_reg] = interp.regs[0];
			}
			case Push_inst:{
				append(&interp.stack, interp.regs[0], loc = loc);
			}	
			case Pop_inst:{
				interp.regs[inst.target] = pop(&interp.stack)
			}	
			case Binary_inst:{
				switch inst.op {
					case .comma: {
						panic("Comma is not a runtime binray instruction");
					}
					case .add: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v booleans", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation was %v vs %v", inst.op, v1, interp.regs[2]);
									break;
								}
								interp.regs[0] = v1 + v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 + v2;
							}
						}
					}
					case .subtract: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v booleans", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 - v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 - v2;
							}
						}
					}
					case .multiply: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v booleans", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 * v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 * v2;
							}
						}
					}
					case .divide: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v booleans", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 / v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 / v2;
							}
						}
					}
					case .modulo: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v booleans", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								error = true;
								log.errorf("Cannot %v floats", inst.op);
								break;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 % v2;
							}
						}
					}
					case .power: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v booleans", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = math.pow(v1, v2);
							}
							case int: {
								error = true;
								log.errorf("Cannot %v ints", inst.op);
								break;
							}
						}
					}
					case .and: {
						switch v1 in interp.regs[1] {
							case bool: {
								v2, ok := interp.regs[2].(bool);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 && v2;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								error = true;
								log.errorf("Cannot %v floats", inst.op);
								break;
							}
							case int: {
								error = true;
								log.errorf("Cannot %v ints", inst.op);
								break;
							}
						}
					}
					case .or: {
						switch v1 in interp.regs[1] {
							case bool: {
								v2, ok := interp.regs[2].(bool);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 || v2;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								error = true;
								log.errorf("Cannot %v floats", inst.op);
								break;
							}
							case int: {
								error = true;
								log.errorf("Cannot %v ints", inst.op);
								break;
							}
						}
					}
					case .equals: {
						switch v1 in interp.regs[1] {
							case bool: {
								v2, ok := interp.regs[2].(bool);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 == v2;
							}
							case string: {
								v2, ok := interp.regs[2].(string);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 == v2;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 == v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 == v2;
							}
						}
					}
					case .not_equals: {
						switch v1 in interp.regs[1] {
							case bool: {
								v2, ok := interp.regs[2].(bool);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 != v2;
							}
							case string: {
								v2, ok := interp.regs[2].(string);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 != v2;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 != v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 != v2;
							}
						}
					}
					case .greater_than: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v bools", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 > v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 > v2;
							}
						}
					}
					case .less_than: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v bools", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 < v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 < v2;
							}
						}
					}
					case .greater_eq: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v bools", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 >= v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 >= v2;
							}
						}
					}
					case .less_eq: {
						switch v1 in interp.regs[1] {
							case bool: {
								error = true;
								log.errorf("Cannot %v bools", inst.op);
								break;
							}
							case string: {
								error = true;
								log.errorf("Cannot %v strings", inst.op);
								break;
							}	
							case f64: {
								v2, ok := interp.regs[2].(f64);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 <= v2;
							}
							case int: {
								v2, ok := interp.regs[2].(int);
								if !ok {
									error = true;
									log.errorf("Must be same type for %v operation", inst.op);
									break;
								}
								interp.regs[0] = v1 <= v2;
							}
						}
					}
					
				}
			}
			case Unary_inst:{
				panic("TODO");
			}
			case Call_inst:{
				
				//pop end of stack and add to args
				if !interpret(interp, inst.func) {
					error = true;
					log.errorf("Function called %v failed", inst.func);
					break;
				}
			}
			case Call_odin_inst:{
				panic("TODO");
			}
			case Set_inst:{
				interp.regs[inst.target_reg] = inst.val;
			}
		}
		
		log.infof("stack : %v\t regs : %v\t after %v\t", interp.stack, interp.regs, instruction);
		
	}
	
	pop_scope(interp);
	
	return !error;
}

@(private)
destroy_interp :: proc (interp : ^Interp_state) {
	assert(len(interp.stack) == 0, "stack length must be 0");
	
	delete(interp.stack);
	delete(interp.scope_stack);
	free(interp);
}

@private
Runtime_value :: struct {
	val : Sand_value,
	type : Sand_type,
}

@private
Runtime_scope :: struct {
	variables : map[string]Runtime_value,
}

@private
Interp_state :: struct {
	
	regs : [3]Sand_value,
	stack : [dynamic]Sand_value,
	
	scope_stack : [dynamic]Runtime_scope,
}

@private
push_scope :: proc (state : ^Interp_state) {
	
	append(&state.scope_stack, Runtime_scope {
		make(map[string]Runtime_value),
	});
}

pop_scope :: proc (state : ^Interp_state) {
	
	rt_scope := pop(&state.scope_stack);
	delete(rt_scope.variables);
}


@(private, require_results)
make_interp :: proc (global_scope : ^Scope) -> ^Interp_state {
	
	new_state := new(Interp_state);
	
	new_state^ = {
		{},
		make([dynamic]Sand_value),
		make([dynamic]Runtime_scope),
	}
	
	push_scope(new_state);
	
	return new_state;
}

@private
is_variable :: proc (state : ^Interp_state, var_name : string) -> bool {
	
	#reverse for cur in state.scope_stack {
		if (var_name in cur.variables) {
			return true;
		}
	}
	
	return false;
}

@private
get_variable :: proc (state : ^Interp_state, var_name : string) -> Runtime_value {
	
	#reverse for cur in state.scope_stack {
		if (var_name in cur.variables) {
			return cur.variables[var_name];
		}
	}
	
	unreachable();
}

@private
set_variable :: proc (state : ^Interp_state, var_name : string, value : Runtime_value) {
	
	state.scope_stack[len(state.scope_stack)-1].variables[var_name] = value;
}
