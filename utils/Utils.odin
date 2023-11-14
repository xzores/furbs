package utils;

import rl "vendor:raylib"

TRACY_ENABLE :: #config(TRACY_ENABLE, false);
LOCK_DEBUG :: #config(LOCK_DEBUG, false);
MEM_DEBUG :: #config(MEM_DEBUG, false);

Pair :: struct(A : typeid, B : typeid) {
	a : A,
	b : B,
}

@(require_results)
is_number :: proc (codepoint : rune) -> bool {

	switch codepoint {
		case '0'..='9':
			return true;
		case:
			return false;
	}
}