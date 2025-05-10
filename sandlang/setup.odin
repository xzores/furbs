package sand_lang;

import "core:os"
import "core:log"

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
	//TODO IDK
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
	Set_inst,
}

Function :: struct {
	arguments : []Variable_entry,
	local_scope : ^Scope,
	instructions : []Instruction,
}

Import_space :: struct {
	name : string,
	functions : map[string]Function,
}

Scope :: struct {
	parent : ^Scope,
	
	functions : map[string]Function,
	structs : map[string]Struct,
}

Sand_state :: struct {
	imports : map[string]Import_space,
	global_scope : ^Scope,
}

Variable :: struct {
	name : string,
	index : int,
}

@(require_results)
init :: proc () -> ^Sand_state {
	
	new_state := new(Sand_state);
	
	new_state^ = Sand_state {
		make(map[string]Import_space),
		nil,
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

call_func :: proc (state : ^Sand_state, func_name : string, args : ..any) -> (ok : bool) {
	
	
	if !(func_name in state.global_scope.functions) {
		log.errorf("No function is named %v", func_name);
		return false;
	}
	
	func := state.global_scope.functions[func_name];
	
	if len(func.arguments) != len(args) {
		log.errorf("Mismatch in number of arguments : %v (caller) vs %v (callee)", len(func.arguments), len(args));
	}
	
	interp_state := make_interp();
	
	
	
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
	
	delete(state.imports);
	
	destroy_scope(state.global_scope);
	
	free(state);
}