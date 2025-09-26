package vrtql_websockets

import "core:c"

//------------------------------------------------------------------------------
// Client Side
//------------------------------------------------------------------------------

// Out-of-band message callback
Rpc_ob : #type proc(rpc: ^Rpc, m: ^Msg)

// Reconnect callback
Rpc_reconnect : #type proc(rpc: ^Rpc) -> bool

// RPC environment (client side)
Rpc :: struct {
	cnx: ^vws_cnx,        // WebSocket connection
	retries: u8,          // Number of retries on timeout (default 5)
	out_of_band: Rpc_ob,  // Handler for out-of-band messages
	reconnect: Rpc_reconnect, // Handler for reconnect
	val: ^vws_buffer,     // Data from last response
	data: rawptr,         // User-defined data
}

//------------------------------------------------------------------------------
// Server Side
//------------------------------------------------------------------------------

// Forward map alias
Rpc_map :: struct { /* underlying sc_map_sv, provided by C */ }

// RPC module
Rpc_module :: struct {
	name: cstring,     // Module name
	calls: Rpc_map,    // Map of RPC calls (name → proc)
	data: rawptr,      // User-defined data
}

// RPC environment
Rpc_env :: struct {
	data: rawptr,           // User-defined data
	module: ^Rpc_module,    // Reference to current module
}

// RPC call type
Rpc_call : #type proc(e: ^Rpc_env, m: ^Msg) -> ^Msg

// RPC system
Rpc_system :: struct {
	modules: Rpc_map,    // Map of modules (name → module instance)
}

//------------------------------------------------------------------------------
// Foreign imports
//------------------------------------------------------------------------------
@(link_prefix="vrtql_", default_calling_convention="c")
foreign vrtql {
	// Client
	rpc_new       :: proc(cnx: ^vws_cnx) -> ^Rpc ---
	rpc_free      :: proc(rpc: ^Rpc) ---
	rpc_tag       :: proc(length: u16) -> ^u8 ---
	rpc_exec      :: proc(rpc: ^Rpc, req: ^Msg) -> ^Msg ---
	rpc_invoke    :: proc(rpc: ^Rpc, req: ^Msg) -> bool ---

	// Server: modules
	rpc_module_new   :: proc(name: cstring) -> ^Rpc_module ---
	rpc_module_free  :: proc(m: ^Rpc_module) ---
	rpc_module_set   :: proc(m: ^Rpc_module, n: cstring, c: Rpc_call) ---
	rpc_module_get   :: proc(m: ^Rpc_module, n: cstring) -> Rpc_call ---

	// Server: system
	rpc_system_new   :: proc() -> ^Rpc_system ---
	rpc_system_free  :: proc(s: ^Rpc_system) ---
	rpc_system_set   :: proc(s: ^Rpc_system, m: ^Rpc_module) ---
	rpc_system_get   :: proc(s: ^Rpc_system, n: cstring) -> ^Rpc_module ---

	// Service
	rpc_reply        :: proc(req: ^Msg) -> ^Msg ---
	rpc_service      :: proc(s: ^Rpc_system, e: ^Rpc_env, m: ^Msg) -> ^Msg ---
}
