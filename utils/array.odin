package utils;

import "base:runtime"
import "base:intrinsics"
import "core:slice"
import "core:math/rand"

insert_ordered :: proc(arr: ^$A/[dynamic]$E, e: E) -> (index: int, err: runtime.Allocator_Error) where intrinsics.type_is_ordered(E) #optional_allocator_error {
	return insert_ordered_by(arr, e, slice.cmp_proc(E));
}

insert_ordered_by :: proc(arr: ^$A/[dynamic]$E, e: E, cmp: proc(E, E) -> slice.Ordering) -> (index: int, err: runtime.Allocator_Error) #optional_allocator_error {
	index, _ = slice.binary_search_by(arr[:], e, cmp);
	_, err = inject_at(arr, index, e);
	return
}

@require_results
make_2d_slice :: proc(#any_int y, x: int, $T: typeid, allocator := context.allocator, loc := #caller_location) -> (res: [][]T) {
	assert(x > 0 && y > 0)
	context.allocator = allocator
	
	backing := make([]T, x * y, loc = loc);
	res	  = make([][]T, y, loc = loc);

	for i in 0..<y {
		res[i] = backing[x * i:][:x]
	}
	return
}

delete_2d_slice :: proc(slice: [][]$T, allocator := context.allocator) {
	delete(slice[0], allocator)
	delete(slice,	allocator)
}

randomize_slice :: proc (v : []$T, range_low : f64 = -1, range_upper : f64 = 1) where intrinsics.type_is_numeric(T) {
	for &e in v {
		e = cast(T)rand.float64_range(range_low, range_upper);
	}
}

@require_results
make_3d_slice :: proc(#any_int x, y, z: int, $T: typeid, allocator := context.allocator, loc := #caller_location) -> (res: [][][]T) {
	assert(x > 0 && y > 0)
	context.allocator = allocator
	
	res	= make([][][]T, y, loc = loc);
	
	for &r in res {
		r = make_2d_slice(y, z, T, loc = loc);
	}
	
	return
}

delete_3d_slice :: proc(slice: [][][]$T, allocator := context.allocator) {
	for r in slice {
		delete_2d_slice(r, allocator);
	}
	delete(slice);
}