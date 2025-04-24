package walker;

import "core:log"
import "core:fmt"

//walker_type could be rune or token
Walker :: struct(Walker_type : typeid, Out_type : typeid, errors : typeid) {
	to_walk : []Walker_type,
	is_done : bool,
	current : int,
	
	output : [dynamic]Out_type,
	errors : [dynamic]Error_type,
}

make_walker :: proc (to_walk : []$Walker_type, $Out_type : typeid, $Error_type : typeid, allocator := context.allocator) -> Walker(Walker_type, Out_type, Error_type) {
	return Walker(Walker_type){to_walk, make([dynamic]Error_type, allocator), false, 0};
}

/////////////////////// Functions to use ///////////////////////

is_done :: proc (w : ^Walker($Walker_type, $Out_type, $Error_type)) -> bool {
	// Check if we have reached the end of the sequence for both runes and tokens
	if w.current >= len(w.to_walk) {
		return true
	}
	
	return false
}

here :: proc (w : ^Walker($Walker_type, $Out_type, $Error_type)) -> Walker_type {
	if w.current < len(w.to_walk) {
		return w.to_walk[w.current];
	}
}

next :: proc (w : ^Walker($Walker_type, $Out_type, $Error_type)) {
	// Move to the next rune or token in the sequence
	w.current += 1
}

peek_next :: proc (w : ^Walker($Walker_type, $Out_type, $Error_type)) -> Walker_type {
	// Peek at the next rune or token
	if w.current + 1 < len(to_wwalk.to_walk) {
		return w.to_walk[w.current + 1]
	}
	return {}; // Return a default "empty" value
}

emit :: proc (w : ^Walker($Walker_type, $Out_type, $Error_type), out : Out_type, loc := #caller_location) {
	append(&w, out, loc);
}

emit_error :: proc (w : ^Walker($Walker_type, $Out_type, $Error_type), err : Error_type, loc := #caller_location) {
	append(&t.errors, err);
}