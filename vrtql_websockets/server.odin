package vrtql_websockets

import "core:c"

//------------------------------------------------------------------------------
// Address Pool
//------------------------------------------------------------------------------
Address_pool :: struct {
	slots: [^]uintptr,     // Array of addresses
	capacity: u32,         // Total slots
	count: u32,            // Used slots
	last_used_index: u32,  // Last index to optimize search
	growth_factor: u16,    // Growth factor
}

//------------------------------------------------------------------------------
// Server State Flags
//------------------------------------------------------------------------------
@(private="file")
Svr_state_enum :: enum u32 {
	close        = 10,
	auth         = 11,
	unauth       = 12,
	peer         = 13,
	http         = 14,
	peer_connect = 15,
	trusted      = 16,
}
Svr_state :: bit_set[Svr_state_enum; u32]

//------------------------------------------------------------------------------
// Connection ID
//------------------------------------------------------------------------------
Cid :: struct {
	key: i64,
	addr: sockaddr_storage,
	flags: u64,
	plane: u16,
	data: rawptr,
}

//------------------------------------------------------------------------------
// Connection Info
//------------------------------------------------------------------------------
Cinfo :: struct {
	server: ^Tcp_svr,
	cnx: ^Svr_cnx,
	cid: Cid,
}

//------------------------------------------------------------------------------
// Peer
//------------------------------------------------------------------------------
Peer_state :: enum u32 {
	closed      = 1,
	connected   = 2,
	pending     = 3,
	reconnected = 4,
	failed      = 5,
}

Peer_connect : #type proc(p: ^Peer) -> c.int

Peer :: struct {
	host: cstring,
	port: c.int,
	info: Cinfo,
	state: Peer_state,
	sockfd: c.int,
	connect: Peer_connect,
	data: rawptr,
}

//------------------------------------------------------------------------------
// Thread Context
//------------------------------------------------------------------------------
Thread_ctx_ctor : #type proc(data: rawptr) -> rawptr
Thread_ctx_dtor : #type proc(data: rawptr)

Thread_ctx :: struct {
	ctor: Thread_ctx_ctor,
	ctor_data: rawptr,
	dtor: Thread_ctx_dtor,
	data: rawptr,
}

//------------------------------------------------------------------------------
// Server Data & Queue
//------------------------------------------------------------------------------
Svr_data :: struct {
	cid: Cid,
	size: c.size_t,
	data: ^u8,
	flags: u64,
	server: ^Tcp_svr,
}

Svr_queue :: struct {
	buffer: [^]^Svr_data,
	size: c.int,
	capacity: c.int,
	head: c.int,
	tail: c.int,
	mutex: uv_mutex_t,
	cond: uv_cond_t,
	state: u8,
	name: cstring,
}

//------------------------------------------------------------------------------
// Connection
//------------------------------------------------------------------------------
Svr_cnx :: struct {
	server: ^Tcp_svr,
	handle: ^uv_stream_t,
	http: ^Http_msg,
	upgraded: bool,
	cid: Cid,
	data: ^u8,
	format: Msg_format,
}

//------------------------------------------------------------------------------
// Server Callbacks
//------------------------------------------------------------------------------
Svr_loop_cb        : #type proc(data: rawptr)
Svr_data_lost_cb   : #type proc(data: ^Svr_data, ctx: rawptr)
Svr_cnx_open_cb    : #type proc(cnx: ^Svr_cnx) -> bool
Svr_cnx_close_cb   : #type proc(cnx: ^Svr_cnx)
Tcp_svr_connect    : #type proc(c: ^Svr_cnx)
Tcp_svr_disconnect : #type proc(c: ^Svr_cnx)
Tcp_svr_read       : #type proc(c: ^Svr_cnx, n: c.ssize_t, b: ^uv_buf_t)
Tcp_svr_process    : #type proc(t: ^Svr_data, data: rawptr)

//------------------------------------------------------------------------------
// TCP Server
//------------------------------------------------------------------------------
Tcp_svr_state :: enum u32 {
	running  = 0,
	halting  = 1,
	halted   = 2,
}

Tcp_svr :: struct {
	state: u8,
	wakeup: ^uv_async_t,
	loop: ^uv_loop_t,
	requests: Svr_queue,
	responses: Svr_queue,
	backlog: c.int,
	pool_size: c.int,
	threads: ^uv_thread_t,
	cpool: ^Address_pool,
	on_connect: Tcp_svr_connect,
	on_disconnect: Tcp_svr_disconnect,
	on_read: Tcp_svr_read,
	on_data_in: Tcp_svr_process,
	on_data_out: Tcp_svr_process,
	worker_ctor: Thread_ctx_ctor,
	worker_ctor_data: rawptr,
	worker_dtor: Thread_ctx_dtor,
	loop_cb: Svr_loop_cb,
	shutdown_cb: Svr_loop_cb,
	cnx_open_cb: Svr_cnx_open_cb,
	cnx_close_cb: Svr_cnx_close_cb,
	data_lost_cb: Svr_data_lost_cb,
	trace: u8,
	inetd_mode: u8,
	peers: ^vws_kvs,
	peer_timeout: u32,
	peer_timer: ^uv_timer_t,
}

//------------------------------------------------------------------------------
// WebSocket Server
//------------------------------------------------------------------------------
Svr_process_frame   : #type proc(s: ^Svr_cnx, f: ^Frame)
Svr_process_msg     : #type proc(s: ^Svr, c: Cid, m: ^Ws_msg, ctx: rawptr)
Svr_http_read       : #type proc(c: ^Svr_cnx) -> c.int
Svr_process_http_req: #type proc(s: ^Svr, c: Cid, m: ^Http_msg, ctx: rawptr) -> bool

Svr :: struct {
	base: Tcp_svr,
	on_frame_in: Svr_process_frame,
	on_frame_out: Svr_process_frame,
	on_http_read: Svr_http_read,
	process_http: Svr_process_http_req,
	on_msg_in: Svr_process_msg,
	on_msg_out: Svr_process_msg,
	process_ws: Svr_process_msg,
	send: Svr_process_msg,
}

//------------------------------------------------------------------------------
// VRTQL Message Server
//------------------------------------------------------------------------------
Vrtql_svr_process_msg : #type proc(s: ^Svr, c: Cid, m: ^Msg, ctx: rawptr)

Msg_svr :: struct {
	base: Svr,
	on_msg_in: Vrtql_svr_process_msg,
	on_msg_out: Vrtql_svr_process_msg,
	process: Vrtql_svr_process_msg,
	send: Vrtql_svr_process_msg,
	dispatch: Vrtql_svr_process_msg,
	data: rawptr,
}

//------------------------------------------------------------------------------
// Foreign imports
//------------------------------------------------------------------------------
@(link_prefix="vws_", default_calling_convention="c")
foreign vws {
	// Address pool
	address_pool_new    :: proc(initial_size: c.int, growth_factor: c.int) -> ^Address_pool ---
	address_pool_free   :: proc(pool: ^^Address_pool) ---
	address_pool_resize :: proc(pool: ^Address_pool) ---
	address_pool_set    :: proc(pool: ^Address_pool, address: uintptr) -> i64 ---
	address_pool_get    :: proc(pool: ^Address_pool, index: i64) -> uintptr ---
	address_pool_remove :: proc(pool: ^Address_pool, index: i64) ---

	// CID
	cid_clear :: proc(cid: ^Cid) ---
	cid_valid :: proc(cid: ^Cid) -> bool ---

	// Server data
	svr_data_new :: proc(s: ^Tcp_svr, cid: Cid, b: ^^vws_buffer) -> ^Svr_data ---
	svr_data_own :: proc(s: ^Tcp_svr, cid: Cid, data: ^u8, size: c.size_t) -> ^Svr_data ---
	svr_data_free:: proc(t: ^Svr_data) ---

	// TCP server
	tcp_svr_new          :: proc(pool_size: c.int, backlog: c.int, queue_size: c.int) -> ^Tcp_svr ---
	tcp_svr_free         :: proc(s: ^Tcp_svr) ---
	tcp_svr_wakeup       :: proc(s: ^Tcp_svr) ---
	tcp_svr_run          :: proc(server: ^Tcp_svr, host: cstring, port: c.int) -> c.int ---
	tcp_svr_is_running   :: proc(server: ^Tcp_svr) -> bool ---
	tcp_svr_inetd_run    :: proc(server: ^Tcp_svr, sockfd: c.int) -> c.int ---
	tcp_svr_inetd_stop   :: proc(server: ^Tcp_svr) ---
	tcp_svr_peers_online :: proc(server: ^Tcp_svr) -> bool ---
	tcp_svr_send         :: proc(data: ^Svr_data) -> c.int ---
	tcp_svr_close        :: proc(s: ^Tcp_svr, cid: Cid) ---
	tcp_svr_uv_close     :: proc(server: ^Tcp_svr, handle: ^uv_handle_t) ---
	tcp_svr_stop         :: proc(server: ^Tcp_svr) ---
	tcp_svr_state        :: proc(s: ^Tcp_svr) -> u8 ---
	tcp_svr_peer_add     :: proc(s: ^Tcp_svr, h: cstring, p: c.int, fn: Peer_connect, d: rawptr) -> ^Peer ---
	tcp_svr_peer_remove  :: proc(s: ^Tcp_svr, h: cstring, p: c.int) ---
	tcp_svr_peer_connect :: proc(s: ^Tcp_svr, peer: ^Peer) -> bool ---
	tcp_svr_peer_disconnect :: proc(s: ^Tcp_svr, peer: ^Peer) ---
	tcp_svr_peer_timeout :: proc(s: ^Tcp_svr) ---

	// WebSocket server
	svr_new :: proc(pool_size: c.int, backlog: c.int, queue_size: c.int) -> ^Svr ---
	svr_free:: proc(s: ^Svr) ---
	svr_run :: proc(server: ^Svr, host: cstring, port: c.int) -> c.int ---

	// Message server
	msg_svr_new   :: proc(pool_size: c.int, backlog: c.int, queue_size: c.int) -> ^Msg_svr ---
	msg_svr_free  :: proc(s: ^Msg_svr) ---
	msg_svr_ctor  :: proc(server: ^Msg_svr, num_threads: c.int, backlog: c.int, queue_size: c.int) -> ^Msg_svr ---
	msg_svr_dtor  :: proc(s: ^Msg_svr) ---
	msg_svr_run   :: proc(server: ^Msg_svr, host: cstring, port: c.int) -> c.int ---
}
