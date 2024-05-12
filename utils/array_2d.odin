package utils;

@require_results
make_2d_slice :: proc(#any_int y, x: int, $T: typeid, allocator := context.allocator, loc := #caller_location) -> (res: [][]T, backing : []T) {
    assert(x > 0 && y > 0)
    context.allocator = allocator
	
    backing = make([]T, x * y, loc = loc);
    res      = make([][]T, y, loc = loc);

    for i in 0..<y {
        res[i] = backing[x * i:][:x]
    }
    return
}

delete_2d_slice :: proc(slice: [][]$T, allocator := context.allocator) {
    delete(slice[0], allocator)
    delete(slice,    allocator)
}