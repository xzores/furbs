package sand_lang;

Interp_state :: struct {
	
	regs : [3]Sand_value,
	
	stack : [dynamic]Sand_value,
	
	instructions : [dynamic]Instruction,
	
	
	
}

@(private, require_results)
make_interp :: proc () -> ^Interp_state {
	
}

