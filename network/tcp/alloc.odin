package furbs_network_tcp_interface;

import "core:c"
import "base:runtime"
import "core:strings"
import "core:log"
import "core:mem"

tcp_allocator : runtime.Allocator;
tcp_logger : runtime.Logger;

//set to nil for default
init :: proc (alloc : runtime.Allocator, logger : runtime.Logger) {

	tcp_allocator = alloc;
	tcp_logger = logger;
}

destroy :: proc () {
	//currently does nothing.
}

@(require_results)
restore_context :: proc "contextless" () -> runtime.Context {
	assert_contextless(tcp_allocator != {});
	context = runtime.default_context();

	context.allocator = tcp_allocator;
	context.logger = tcp_logger;

	return context;
}

//Shallow copy
@(private, require_results)
reverse_map :: proc (to_reverse : map[$A]$B, loc := #caller_location) -> map[B]A {

	reversed := make(map[B]A, loc = loc);

	for k, v in to_reverse {
		reversed[v] = k;
	}

	return reversed;
}
