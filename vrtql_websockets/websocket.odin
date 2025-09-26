package vrtql_websockets

import "core:c"

//------------------------------------------------------------------------------
// Frame
//------------------------------------------------------------------------------
Fs_t :: enum u32 {
	incomplete,
	complete,
	error,
}

Frame_type :: enum u32 {
	continuation = 0x0,
	text         = 0x1,
	binary       = 0x2,
	close        = 0x8,
	ping         = 0x9,
	pong         = 0xA,
}

Frame :: struct {
	fin:    u8,      // Final frame
	opcode: u8,      // Frame type
	mask:   u8,      // Payload masked
	offset: u32,     // Position in frame
	size:   u64,     // Payload size
	data:   ^u8,     // Payload data
}

//------------------------------------------------------------------------------
// Message
//------------------------------------------------------------------------------
Ws_msg :: struct {
	opcode: u8,         // Interpretation of payload
	data: ^Vws_buffer,  // Payload buffer
}

//------------------------------------------------------------------------------
// Connection
//------------------------------------------------------------------------------
Process_frame : #type proc(cnx: ^Ws_cnx, f: ^Frame)
Cnx_disconnect : #type proc(cnx: ^Ws_cnx)

Url_data :: struct {
	href:     cstring,
	protocol: cstring,
	host:     cstring,
	auth:     cstring,
	hostname: cstring,
	pathname: cstring,
	search:   cstring,
	path:     cstring,
	hash:     cstring,
	query:    cstring,
	port:     cstring,
}

Ws_cnx :: struct {
	base: Socket,           // Underlying socket
	flags: u64,             // State flags
	url: ^Url_data,         // Server URL
	key: cstring,           // WebSocket key
	queue: sc_queue_ptr,    // Incoming frames queue
	process: Process_frame, // Frame callback
	disconnect: Cnx_disconnect, // Disconnect callback
	data: cstring,          // User data
}

//------------------------------------------------------------------------------
// Foreign Imports
//------------------------------------------------------------------------------
@(link_prefix="vws_", default_calling_convention="c")
foreign vws {
	// Frames
	frame_new     :: proc(data: ^u8, size: c.size_t, oc: u8) -> ^Frame ---
	frame_free    :: proc(frame: ^Frame) ---
	serialize     :: proc(f: ^Frame) -> ^Vws_buffer ---
	deserialize   :: proc(data: ^u8, size: c.size_t, f: ^Frame, consumed: ^c.size_t) -> Fs_t ---
	generate_close_frame :: proc() -> ^Vws_buffer ---
	generate_pong_frame  :: proc(ping_data: ^u8, size: c.size_t) -> ^Vws_buffer ---
	dump_websocket_frame :: proc(data: ^u8, size: c.size_t) ---

	// Messages
	msg_new  :: proc() -> ^Ws_msg ---
	msg_free :: proc(msg: ^Ws_msg) ---

	// Connections
	accept_key          :: proc(key: cstring) -> cstring ---
	connect             :: proc(c: ^Ws_cnx, uri: cstring) -> bool ---
	reconnect           :: proc(c: ^Ws_cnx) -> bool ---
	disconnect          :: proc(c: ^Ws_cnx) ---
	cnx_new             :: proc() -> ^Ws_cnx ---
	cnx_free            :: proc(c: ^Ws_cnx) ---
	cnx_is_connected    :: proc(c: ^Ws_cnx) -> bool ---
	cnx_set_server_mode :: proc(c: ^Ws_cnx) ---
	cnx_ingress         :: proc(c: ^Ws_cnx) -> c.ssize_t ---

	// Messaging API
	frame_send_text   :: proc(c: ^Ws_cnx, text: cstring) -> c.ssize_t ---
	frame_send_binary :: proc(c: ^Ws_cnx, data: ^u8, size: c.size_t) -> c.ssize_t ---
	frame_send_data   :: proc(c: ^Ws_cnx, data: ^u8, size: c.size_t, oc: c.int) -> c.ssize_t ---
	frame_send        :: proc(c: ^Ws_cnx, f: ^Frame) -> c.ssize_t ---

	msg_send_text   :: proc(c: ^Ws_cnx, text: cstring) -> c.ssize_t ---
	msg_send_binary :: proc(c: ^Ws_cnx, data: ^u8, size: c.size_t) -> c.ssize_t ---
	msg_send_data   :: proc(c: ^Ws_cnx, data: ^u8, size: c.size_t, oc: c.int) -> c.ssize_t ---

	msg_recv   :: proc(c: ^Ws_cnx) -> ^Ws_msg ---
	msg_pop    :: proc(c: ^Ws_cnx) -> ^Ws_msg ---
	frame_recv :: proc(c: ^Ws_cnx) -> ^Frame ---
}
