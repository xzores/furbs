package websocket_libws;

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:strings"

import "../libwebsockets"

when ODIN_OS == .Windows { 
	@(extra_linker_flags="/NODEFAULTLIB:MSVCRT /IGNORE:4217")
	foreign import libws {
		"libs/windows/libws.lib",
	}
}
when ODIN_OS == .Linux {
	foreign import libws "libs/linux/libws.a"
} 
when ODIN_OS == .Darwin {
	foreign import libws "libs/mac/libws.a"
}

main :: proc () {
	fmt.printfln("begin");
	
	hooks := Hooks{
		proc "c" (size: c.size_t) -> rawptr {
			context = runtime.default_context();
			res, err := mem.alloc(auto_cast size);
			assert(err == nil);
			return res;
		},
		proc "c" (ptr: rawptr) {
			context = runtime.default_context();
			mem.free(ptr);
		},
	};

	init_hooks(&hooks);



	fmt.printfln("done");
}

Ws :: libwebsockets.Lws;
Ws_client :: libwebsockets.Lws_client;
Lws_context :: libwebsockets.Lws_context;

Event :: enum i32 {
	LIBWS_EVENT_CONNECTION_ERROR,
	LIBWS_EVENT_CONNECTED,
	LIBWS_EVENT_SENT,
	LIBWS_EVENT_RECEIVED,
	LIBWS_EVENT_CLOSED
};

Callback :: proc "c" (client: Ws_client, event: Event, user: rawptr) -> c.int

Connect_options :: struct {
	/* Libwebsockets context. */
	ws_context : Lws_context,

	/* Host to connect to. */
	host : cstring,
	
	/* Port to connect to. */
	port : c.int,
	
	/* Path to connect to. */
	path : cstring,
	
	/* Callback to receive events. */
	callback : Callback,         // int (*)(ws_client*, ws_event, void*)
	
	/* Size of user data allocated per client. */
	per_client_data_size : c.size_t,
};

Listen_options :: struct {
	/* Libwebsockets context. */
	ws_context : Lws_context,

	/* Port to listen to or 0. */
	port : c.int,
	
	/* Callback to receive events. */
	callback : Callback,         // int (*)(ws_client*, ws_event, void*)
	
	/* Size of user data allocated per client. */
	per_client_data_size : c.size_t,
};

/** Struct for custom hooks configuration. */
Hooks :: struct
{
	/** Custom malloc function. */
	malloc_fn : proc "c" (size: c.size_t) -> rawptr,

	/**  Custom free function. */
	free_fn   : proc "c" (ptr: rawptr)
};


@(link_prefix = "ws_", require_results, default_calling_convention="c")
foreign libws {
	// Register custom hooks.
	// struct ws_hooks hooks = { malloc, free };
	// ws_init_hooks(&hooks);
    init_hooks :: proc (hooks : ^Hooks) ---;

    // Connect to a server.
    // Fill Connect_options (ctx, host, port, path, callback, per_client_data_size).
    // Returns Ws on success, nil on failure.
    connect :: proc (options : ^Connect_options) -> Ws ---;

    // Start a server listener.
    // Fill Listen_options (ctx, port, callback, per_client_data_size).
    // Returns Ws on success, nil on failure.
    listen :: proc (options : ^Listen_options) -> Ws ---;

    // Close and delete a websocket (client or server).
    delete :: proc (ws : Ws) ---;

    // Get the port this websocket is connected to / listening on.
    get_port :: proc (ws : Ws) -> c.int ---;

    // Get client at index [0..get_num_clients()-1]; returns nil if out of range.
    get_client :: proc (ws : Ws, index : c.size_t) -> Ws_client ---;

    // Number of connected clients on this websocket (server side).
    get_num_clients :: proc (ws : Ws) -> c.size_t ---;

    // Get the parent websocket handle from a client handle.
    get_websocket :: proc (client : Ws_client) -> Ws ---;

    // Send bytes to a client: ws_send(client, buf, size).
    send :: proc (client : Ws_client, buf : rawptr, size : c.size_t) ---;

    // Receive bytes from a client into buf (up to size). Returns bytes read; 0 = none.
    receive :: proc (client : Ws_client, buf : rawptr, size : c.size_t) -> c.size_t ---;
}

