package vrtql_websockets

import "core:c"

//------------------------------------------------------------------------------
// Socket Callbacks
//------------------------------------------------------------------------------

// Handshake callback, called after connect but before non-blocking
Socket_hs : #type proc(s: ^Socket) -> bool

// Disconnect callback, called on abnormal disconnect/read/write error
Socket_dh : #type proc(s: ^Socket)

//------------------------------------------------------------------------------
// Socket Struct
//------------------------------------------------------------------------------
Socket :: struct {
	sockfd: c.int,        // Socket file descriptor
	ssl: ^SSL,            // SSL connection instance
	buffer: ^vws_buffer,  // Receive buffer
	timeout: c.int,       // Timeout in milliseconds
	data: cstring,        // User-defined data
	hs: Socket_hs,        // Handshake callback
	disconnect: Socket_dh,// Disconnect handler
	flush: bool,          // Force writes to poll until flush (default true)
}

//------------------------------------------------------------------------------
// Foreign Imports
//------------------------------------------------------------------------------
@(link_prefix="vws_", default_calling_convention="c")
foreign vws {
	// Lifecycle
	socket_new   :: proc() -> ^Socket ---
	socket_free  :: proc(s: ^Socket) ---
	socket_ctor  :: proc(s: ^Socket) -> ^Socket ---
	socket_dtor  :: proc(s: ^Socket) ---

	// Connection
	socket_connect      :: proc(s: ^Socket, host: cstring, port: c.int, ssl: bool) -> bool ---
	socket_set_timeout  :: proc(s: ^Socket, sec: c.int) -> bool ---
	socket_set_nonblocking :: proc(sockfd: c.int) -> bool ---
	socket_disconnect   :: proc(s: ^Socket) ---
	socket_is_connected :: proc(s: ^Socket) -> bool ---
	socket_close        :: proc(s: ^Socket) ---

	// IO
	socket_read  :: proc(s: ^Socket) -> c.ssize_t ---
	socket_write :: proc(s: ^Socket, data: ^u8, size: c.size_t) -> c.ssize_t ---

	// Addr info
	socket_addr_info :: proc(addr: ^sockaddr, host: ^^u8, port: ^c.int) -> bool ---
}
