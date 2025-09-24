package furbs_network_websocket_interface;

import "core:c"
import "base:runtime"
import "core:strings"
import "core:log"
import "core:mem"

import "libws"

websocket_allocator : runtime.Allocator;
websocket_logger : runtime.Logger;

init :: proc (alloc := context.allocator, logger := context.logger) {

	websocket_allocator = alloc;
	websocket_logger = logger;

	hooks := libws.Hooks {
		/** Custom malloc function. */
		malloc_fn = proc "c" (size: c.size_t) -> rawptr {
			context = restore_context();
			res, err := mem.alloc(auto_cast size);
			assert_contextless(err == nil);
			return res;
		},

		/**  Custom free function. */
		free_fn = proc "c" (ptr: rawptr) {
			context = restore_context();
			mem.free(ptr);
		}
	}

	libws.init_hooks(&hooks);
}


restore_context :: proc "contextless" () -> runtime.Context {
	assert_contextless(websocket_allocator != {});
	context = runtime.default_context();

	context.allocator = websocket_allocator;
	context.logger = websocket_logger;
	
	return context;
}