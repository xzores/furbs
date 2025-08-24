package utils

import "base:runtime"
import "core:sync"
import "core:mem"
import "core:fmt"

Tracking_Allocator_Entry :: struct {
	memory:    rawptr,
	size:      int,
	alignment: int,
	mode:      mem.Allocator_Mode,
	err:       mem.Allocator_Error,
	location:  runtime.Source_Code_Location,
}

Tracking_Allocator_Bad_Free_Entry :: struct {
	memory:   rawptr,
	location: runtime.Source_Code_Location,
}

Tracking_Allocator :: struct {
	backing:           	mem.Allocator,
	self_location:		runtime.Source_Code_Location,
	allocation_map:    	map[rawptr]Tracking_Allocator_Entry,
	bad_free_array:    	[dynamic]Tracking_Allocator_Bad_Free_Entry,
	mutex:             	sync.Mutex,
	clear_on_free_all:	bool,

	total_memory_allocated:   i64,
	total_allocation_count:   i64,
	total_memory_freed:       i64,
	total_free_count:         i64,
	peak_memory_allocated:    i64,
	current_memory_allocated: i64,
}

tracking_allocator_init :: proc(t: ^Tracking_Allocator, backing_allocator: mem.Allocator, internals_allocator := context.allocator, loc := #caller_location) {
	t.backing = backing_allocator
	t.allocation_map.allocator = internals_allocator
	t.bad_free_array.allocator = internals_allocator
	t.self_location = loc
	
	if .Free_All in mem.query_features(t.backing) {
		t.clear_on_free_all = true
	}
}

tracking_allocator_destroy :: proc(t: ^Tracking_Allocator) {
	delete(t.allocation_map)
	delete(t.bad_free_array)
}

// Clear only the current allocation data while keeping the totals intact.
tracking_allocator_clear :: proc(t: ^Tracking_Allocator) {
	sync.mutex_lock(&t.mutex)
	clear(&t.allocation_map)
	clear(&t.bad_free_array)
	t.current_memory_allocated = 0
	sync.mutex_unlock(&t.mutex)
}

// Reset all of a Tracking Allocator's allocation data back to zero.
tracking_allocator_reset :: proc(t: ^Tracking_Allocator) {
	sync.mutex_lock(&t.mutex)
	clear(&t.allocation_map)
	clear(&t.bad_free_array)
	t.total_memory_allocated = 0
	t.total_allocation_count = 0
	t.total_memory_freed = 0
	t.total_free_count = 0
	t.peak_memory_allocated = 0
	t.current_memory_allocated = 0
	sync.mutex_unlock(&t.mutex)
}

@(require_results)
tracking_allocator :: proc(data: ^Tracking_Allocator) -> mem.Allocator {
	return mem.Allocator{
		data = data,
		procedure = tracking_allocator_proc,
	}
}

tracking_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                                size, alignment: int,
                                old_memory: rawptr, old_size: int, loc := #caller_location) -> (result: []byte, err: mem.Allocator_Error) {
	
	track_alloc :: proc(data: ^Tracking_Allocator, entry: ^Tracking_Allocator_Entry) {
		data.total_memory_allocated += i64(entry.size)
		data.total_allocation_count += 1
		data.current_memory_allocated += i64(entry.size)
		if data.current_memory_allocated > data.peak_memory_allocated {
			data.peak_memory_allocated = data.current_memory_allocated
		}
	}

	track_free :: proc(data: ^Tracking_Allocator, entry: ^Tracking_Allocator_Entry) {
		data.total_memory_freed += i64(entry.size)
		data.total_free_count += 1
		data.current_memory_allocated -= i64(entry.size)
	}

	data := (^Tracking_Allocator)(allocator_data)

	sync.mutex_guard(&data.mutex)

	if mode == .Query_Info {
		info := (^mem.Allocator_Query_Info)(old_memory)
		if info != nil && info.pointer != nil {
			if entry, ok := data.allocation_map[info.pointer]; ok {
				info.size = entry.size
				info.alignment = entry.alignment
			}
			info.pointer = nil
		}

		return
	}

	if mode == .Free && old_memory != nil && old_memory not_in data.allocation_map {
		append(&data.bad_free_array, Tracking_Allocator_Bad_Free_Entry{
			memory = old_memory,
			location = loc,
		})
	} else {
		result = data.backing.procedure(data.backing.data, mode, size, alignment, old_memory, old_size, data.self_location) or_return
	}
	result_ptr := raw_data(result)

	if data.allocation_map.allocator.procedure == nil {
		data.allocation_map.allocator = context.allocator
	}

	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		data.allocation_map[result_ptr] = Tracking_Allocator_Entry{
			memory = result_ptr,
			size = size,
			mode = mode,
			alignment = alignment,
			err = err,
			location = loc,
		}
		track_alloc(data, &data.allocation_map[result_ptr])
	case .Free:
		if old_memory != nil && old_memory in data.allocation_map {
			track_free(data, &data.allocation_map[old_memory])
		}
		delete_key(&data.allocation_map, old_memory)
	case .Free_All:
		if data.clear_on_free_all {
			clear_map(&data.allocation_map)
			data.current_memory_allocated = 0
		}
	case .Resize, .Resize_Non_Zeroed:
		if old_memory != nil && old_memory in data.allocation_map {
			track_free(data, &data.allocation_map[old_memory])
		}
		if old_memory != result_ptr {
			delete_key(&data.allocation_map, old_memory)
		}
		data.allocation_map[result_ptr] = Tracking_Allocator_Entry{
			memory = result_ptr,
			size = size,
			mode = mode,
			alignment = alignment,
			err = err,
			location = loc,
		}
		track_alloc(data, &data.allocation_map[result_ptr])

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Free_All, .Resize, .Query_Features, .Query_Info}
		}
		return nil, nil

	case .Query_Info:
		unreachable()
	}

	return
}

tracking_print_memory_result :: proc(using a : ^Tracking_Allocator) -> (found_leak : bool) {
	
	found_leak = false;
	
	if len(allocation_map) == 0 {
		fmt.printf("\t%sNo leaks found%s\n", GREEN, RESET);
	}
	else {

		leaks := make(map[runtime.Source_Code_Location]u32);
		defer delete(leaks);
		
		fmt.printf("\t%sThe following leaks where found:%s\n", ON_RED, RESET);
		for p, entry in allocation_map {
			leaks[entry.location] += 1;
			found_leak = true;
		}
		
		fmt.printf(RED);
		for loc, cnt in leaks {
			fmt.printf("\t\tcnt : %v, \tloc : %v\n", cnt, loc);
		}
		fmt.printf(RESET);
	}

	if len(bad_free_array) == 0 {
		fmt.printf("\t%sNo bad frees where found%s\n", GREEN, RESET);
	}
	else {
		
		fmt.printf("\t%sThe bad frees where found:%s\n", ON_RED, RESET);
		fmt.printf(RED);
		for bf in bad_free_array {
			fmt.printf("\t\tbad_free : %v\n", bf.location);
		}
		fmt.printf(RESET);
	}
	fmt.printf("\n");
	
	return found_leak;
}