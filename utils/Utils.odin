package utils;

import rl "vendor:raylib"

TRACY_ENABLE :: #config(TRACY_ENABLE, false);
LOCK_DEBUG :: #config(LOCK_DEBUG, false);
MEM_DEBUG :: #config(MEM_DEBUG, false);

Pair :: struct(A : typeid, B : typeid) {
	a : A,
	b : B,
}
