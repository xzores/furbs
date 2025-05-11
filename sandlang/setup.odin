package sand_lang;

import "base:runtime"
import "base:intrinsics"

import "core:os"
import "core:log"
import "core:strings"
import "core:fmt"
import "core:reflect"

Sand_type :: enum {
	invalid,
	_f64,
	_int,
	_bool,
	_string,
}

Sand_value :: union {
	f64,
	int,
	bool,
	string,
}

Variable_entry :: struct{
	name : string,
	type : Sand_type
}

Variable_declaration :: struct {
	name : string,
	type : Sand_type,
	value : Expression,
}

Struct_body :: struct {
	members : []Variable_entry,
}

Struct :: struct {
	name : string,
	body : Struct_body,
}

//Declares a new variable in a map
Declare_inst :: struct {
	name : string,
	arr_size : int,	//-1 is no array? or is 1 no array?, no -1 as 1 might be an array of size 1.
	type : Sand_type,
}

//Moves from a reg into the variable name
Store_inst :: struct {
	variable_name : string,
	reg : int,
}

//Load into a register
Load_inst :: struct {
	variable_name : string,
	reg : int, //which register to load into
}

//reg0 will become reg1 + reg2
Binary_inst :: struct {
	op : Binary_operator_kind,
}

Unary_inst :: struct {
	op : Unary_operator_kind,
}

//Move the reg0 to another reg
Move_inst :: struct {
	target_reg : int,
}

//Put a hardcoded value to target reg
Set_inst :: struct {
	val : Sand_value,
	target_reg : int,
}

//Push reg0 to the stack
Push_inst :: struct {
	
}

//Pop from the stack and place in target reg
Pop_inst :: struct {
	target : int,
}

Call_inst :: struct {
	func : ^Callable_function,
}

Call_odin_inst :: struct {
	//IDK	
}

Instruction :: union {
	Declare_inst,
	Store_inst,
	Load_inst,
	Move_inst,
	Push_inst,	//Push a value to the stack
	Pop_inst,	//Pop a value from the stack
	Binary_inst,
	Unary_inst,
	Call_inst,
	Call_odin_inst,
	Set_inst,
}

Function_sand :: struct {
	local_scope : ^Scope,	
	call : ^Callable_function, //This is not owned by the function, but by the sand state
	//instructions : []Instruction,
	//odin_func : rawptr, //HOw to handle odin function
}

Function_odin :: proc([]Sand_value) -> Sand_value;

Function :: union {
	Function_sand,
	Function_odin,
}

Import_space :: struct {
	name : string,
	functions : map[string]Function_sand,
}

Scope :: struct {
	parent : ^Scope,
	
	functions : map[string]Function,
	structs : map[string]Struct,
}

Callable_function :: struct {
	arguments : []Variable_entry,
	return_type : Sand_type,
	instructions : []Instruction `fmt:"-"`,
}

Sand_state :: struct {
	imports : map[string]Import_space,
	functions : [dynamic]^Callable_function,
	global_scope : ^Scope,
	user_data : rawptr,
}

Variable :: struct {
	name : string,
	index : int,
}

@(require_results)
init :: proc (user_data : rawptr) -> ^Sand_state {
	
	new_state := new(Sand_state);
	
	new_state^ = Sand_state {
		make(map[string]Import_space),
		make([dynamic]^Callable_function),
		make_scope(nil),
		user_data,
	}
	
	//TODO
	
	return new_state;
}

@(require_results)
add_file :: proc (state : ^Sand_state, file_location : string) -> []Error {
	
	content, ok := os.read_entire_file_from_filename(file_location);
	assert(ok, "Failed to load file! this is a hard error");
	defer delete(content);
	
	errs := add_file_content(state, file_location, string(content));
	
	return errs;
}

@(require_results)
add_file_content :: proc (state : ^Sand_state, file_location : string, contents : string) -> []Error {
	
	tok := tokenize(file_location, contents);
	defer destroy_token_res(&tok);
	log.infof("Tokenized file: %v", file_location);
	
	if len(tok.errors) != 0 {
		log.errorf("Tokenizer finished with error : %#v", tok.errors);
		return clone_errors(tok.errors);
	}
	
	for t in tok.tokens {
		log.debugf("%v", t);
	}
	
	errors := parse(file_location, state, tok.tokens);
	
	return nil;
	
}

expose_func :: proc (state : ^Sand_state, func_name : string, my_proc : Function_odin) {
	
	assert(!(func_name in state.global_scope.functions));
	map_insert(&state.global_scope.functions, strings.clone(func_name), my_proc);
}

call_func :: proc (state : ^Sand_state, func_name : string, args : ..any) -> (ok : bool) {
	
	if !(func_name in state.global_scope.functions) {
		log.errorf("No function is named %v", func_name);
		return false;
	}
	
	_func := state.global_scope.functions[func_name];
	
	switch func in _func {
		case Function_sand: {
			if len(func.call.arguments) != len(args) {
				log.errorf("Mismatch in number of arguments : %v (caller) vs %v (callee)", len(func.call.arguments), len(args));
			}
			
			interp_state := make_interp(state.global_scope);
			defer destroy_interp(interp_state)
			
			for arg in args {
				panic("TODO")
				//interpret(interp_state, );
			}
			
			interpret(interp_state, func.call);
		}
		case Function_odin: {
			panic("TODO");
		}
	}
	
	return ;
}

destroy :: proc (state : ^Sand_state) {
	
	for name, imp in state.imports {
		delete(name);
		delete(imp.name);
		for name, func in imp.functions {
			delete(name);
			destroy_function(func);
		}
		delete(imp.functions);
	}
	
	for callable in state.functions {
		Destroy_callable_function(callable);
	}
	delete(state.functions);
	
	delete(state.imports);
	
	destroy_scope(state.global_scope);
	
	free(state);
}