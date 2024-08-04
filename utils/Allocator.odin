package utils;

import "core:c"
import "core:fmt"
import "core:mem"
import "core:sync"
import "base:runtime"
import "core:os"

tracking_allcoators : [dynamic]Pair(^mem.Tracking_Allocator, int);
tracking_allcoators_allocator : mem.Allocator;

init_tracking_allocators :: proc (alloc := context.allocator) {
	tracking_allcoators_allocator = alloc;
	tracking_allcoators = make([dynamic]Pair(^mem.Tracking_Allocator, int), allocator = alloc);
}

make_tracking_allocator :: proc(backing_alloc := context.allocator, internals_allocator := context.allocator,
									tracker_res : ^^mem.Tracking_Allocator = nil) -> mem.Allocator {

	tracker := new(mem.Tracking_Allocator, tracking_allcoators_allocator);
	mem.tracking_allocator_init(tracker, backing_alloc, internals_allocator);
	
	append(&tracking_allcoators, Pair(^mem.Tracking_Allocator, int){tracker, sync.current_thread_id()});
	
	tracker_res^ = tracker; //Return the optinal result.
	
	return  mem.tracking_allocator(tracker);
}

Investigator_Allocator_Entry :: struct {
	current_usage : int,
	peak_usage : int,
}

Investigator_Allocator :: struct {
	backing:		   	mem.Allocator,
	total_usage_current:int,
	total_usage_peak: 	int,
	allocation_map:		map[runtime.Source_Code_Location]map[int]Investigator_Allocator_Entry,
	mutex:			 	sync.Recursive_Mutex,
}

investigator_allocator_init :: proc(t: ^Investigator_Allocator, backing_allocator: mem.Allocator, internals_allocator := context.allocator) {
	t.backing = backing_allocator
	t.allocation_map.allocator = internals_allocator;
}

investigator_allocator_destroy :: proc(t: ^Investigator_Allocator) {

	for thread_id, &thread_map in t.allocation_map {
		delete(thread_map);
	}
	
	delete(t.allocation_map)
}

investigator_allocator_clear :: proc(t: ^Investigator_Allocator) {
	sync.recursive_mutex_lock(&t.mutex);
	for thread_id, &thread_map in t.allocation_map {
		clear(&thread_map);
	}
	clear(&t.allocation_map);
	sync.recursive_mutex_unlock(&t.mutex);
}


@(require_results)
investigator_allocator :: proc(data: ^Investigator_Allocator) -> mem.Allocator {
	return mem.Allocator{
		data = data,
		procedure = investigator_allocator_proc,
	}
}

investigator_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int,
								old_memory: rawptr, old_size: int, loc := #caller_location) -> (result: []byte, err: mem.Allocator_Error) {
	data := (^Investigator_Allocator)(allocator_data)

	sync.recursive_mutex_lock(&data.mutex);
	defer sync.recursive_mutex_unlock(&data.mutex);

	result = data.backing.procedure(data.backing.data, mode, size, alignment, old_memory, old_size, loc) or_return;

	result_ptr := raw_data(result)

	if data.allocation_map.allocator.procedure == nil {
		data.allocation_map.allocator = context.allocator
	}

	cur_thread_id := sync.current_thread_id();

	if !(loc in data.allocation_map) {
		data.allocation_map[loc] = make(map[int]Investigator_Allocator_Entry, 1, data.backing);
		(&data.allocation_map[loc]).allocator = data.backing;
	}
	if !(cur_thread_id in data.allocation_map[loc]) {
		(&data.allocation_map[loc])[cur_thread_id] = Investigator_Allocator_Entry{};
	}

	entry : ^Investigator_Allocator_Entry = &data.allocation_map[loc][cur_thread_id];

	switch mode {
		case .Alloc, .Alloc_Non_Zeroed:
			entry.current_usage += size;
			data.total_usage_current += size;
		case .Free:
			entry.current_usage -= size;
			data.total_usage_current -= size;
		case .Free_All:
			panic("investigator cannot free all", loc);
		case .Resize, .Resize_Non_Zeroed:
			entry.current_usage += size - old_size;
			data.total_usage_current += size - old_size;
		case .Query_Features:
			panic("investigator cannot Query_Features", loc);
		case .Query_Info:
			panic("investigator cannot Query_Info", loc);
	}

	if entry.current_usage > entry.peak_usage {
		entry.peak_usage = entry.current_usage;
	}

	if data.total_usage_current > data.total_usage_peak {
		data.total_usage_peak = data.total_usage_current;
	}

	return
}



//////////////////////////// printers /////////////////////////////////

Megabyte :: cast(f64)runtime.Megabyte;

print_investigator_memory_results :: proc(using self: Investigator_Allocator, single_limit := 10 * runtime.Megabyte, region_limit := 100 * runtime.Megabyte) {

	fmt.printf("Investigator memory results:\n");

	fmt.printf("\tTotal current ussage 	: %f MB\n",  cast(f64)total_usage_current / Megabyte);
	fmt.printf("\tTotal peak ussage 	: %f MB\n", cast(f64)total_usage_peak / Megabyte);

	for location, entry in allocation_map {
		
		current : int = 0;
		peak 	: int = 0;


		for thread, allocation in entry {
			current += allocation.current_usage;
			peak 	+= allocation.peak_usage;
		}

		if peak > single_limit || peak > region_limit || current < 0{
			fmt.printf("\t\tFor location : %v\n", location);
		}
		
		if peak > single_limit{
			fmt.printf("\t\t\tOverall current ussage 	: %f MB\n", cast(f64)current / Megabyte);
			fmt.printf("\t\t\tOverall peak ussage 	: %f MB\n", cast(f64)peak / Megabyte);
		}

		for thread, allocation in entry {
			if peak > region_limit {
					fmt.printf("\t\t\t\tThread : %i \t current allocation : %f MB, \tpeak allocation : %f MB\n", thread, cast(f64)allocation.current_usage / Megabyte, cast(f64)allocation.peak_usage / Megabyte);
			}
			if allocation.current_usage < 0 {
				fmt.printf("\t\t\t\tInvalid freed : %i, from thread : at location : %v\n", thread, location);
			}
		}
	}
	
	fmt.printf("Concluding investigator memory results.\n");
}

print_tracking_memory_results :: proc() -> (found_leak : bool) {
		
	found_leak = false;
	
	fmt.printf("%sTracking memory results:%s\n", BLUE, RESET);
	for t in tracking_allcoators {
		using t.a;
		fmt.printf("%sThread : %i%s\n", BLUE, t.b, RESET);
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
	}
	
	fmt.printf("Concluding tracking memory results.\n");

	return;
}

destroy_tracking_allocators :: proc() -> (found_leak : bool) {

	for t in tracking_allcoators {
		mem.tracking_allocator_destroy(t.a);
		free(t.a);
	}

	return;
}