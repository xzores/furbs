package wslay

import "core:c"

// Error codes (negative in C, so i32)
Error :: enum i32 {
	err_want_read            = -100,
	err_want_write           = -101,
	err_proto                = -200,
	err_invalid_argument     = -300,
	err_invalid_callback     = -301,
	err_no_more_msg          = -302,
	err_callback_failure     = -400,
	err_wouldblock           = -401,
	err_nomem                = -500,
}

// RFC6455 status codes
Status_code :: enum u32 {
	normal_closure           = 1000,
	going_away               = 1001,
	protocol_error           = 1002,
	unsupported_data         = 1003,
	no_status_rcvd           = 1005,
	abnormal_closure         = 1006,
	invalid_frame_payload    = 1007,
	policy_violation         = 1008,
	message_too_big          = 1009,
	mandatory_ext            = 1010,
	internal_server_error    = 1011,
	tls_handshake            = 1015,
}

// IO flags (bitmask-friendly)
Io_flags :: enum u32 {
	msg_more = 1,
}

// Frame opcodes (RFC6455)
Opcode :: enum u32 {
	continuation_frame = 0x0,
	text_frame         = 0x1,
	binary_frame       = 0x2,
	connection_close   = 0x8,
	ping               = 0x9,
	pong               = 0xA,
}

// Helper to test if an opcode is control (== 1) or not (== 0)
is_ctrl_frame :: proc(opcode: u8) -> bool {
	return ((opcode >> 3) & 1) != 0
}

// RSV helpers (rsv is ((RSV1<<2)|(RSV2<<1)|RSV3))
RSV_NONE  : u8 : 0
RSV1_BIT  : u8 : (1 << 2)
RSV2_BIT  : u8 : (1 << 1)
RSV3_BIT  : u8 : (1 << 0)

get_rsv1 :: proc(rsv: u8) -> bool { return ((rsv >> 2) & 1) != 0 }
get_rsv2 :: proc(rsv: u8) -> bool { return ((rsv >> 1) & 1) != 0 }
get_rsv3 :: proc(rsv: u8) -> bool { return (rsv & 1) != 0 }

// -------- Frame-layer callbacks & structs --------

// send(data, length, flags, user_data) -> bytes_sent (0 treated as error)
Frame_send_callback : #type proc(data: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
// recv(buf, length, flags, user_data) -> bytes_filled (0 treated as error)
Frame_recv_callback : #type proc(buf: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
// genmask(buf, length, user_data) -> 0 on success, -1 on error
Frame_genmask_callback : #type proc(buf: ^u8, length: c.size_t, user_data: rawptr) -> c.int

Frame_callbacks :: struct {
	send_callback    : Frame_send_callback,
	recv_callback    : Frame_recv_callback,
	genmask_callback : Frame_genmask_callback,
}

// IOCB for framing
Frame_iocb :: struct {
	fin            : u8,          // 1 if final fragment
	rsv            : u8,          // reserved bits ((rsv1<<2)|(rsv2<<1)|rsv3)
	opcode         : u8,          // 4-bit opcode
	payload_length : u64,         // [0, 2^63-1]
	mask           : u8,          // 1 if masked
	data           : ^u8,         // payload slice start
	data_length    : c.size_t,    // bytes from data to send
}

// Opaque contexts
Frame_context  :: distinct struct{}
Event_context  :: distinct struct{}

// -------- Event-layer callbacks & structs --------

// Message-received (complete message)
Event_on_msg_recv_arg :: struct {
	rsv          : u8,        // ((rsv1<<2)|(rsv2<<1)|rsv3)
	opcode       : u8,
	msg          : ^u8,       // may be nil if no-buffering
	msg_length   : c.size_t,  // 0 when no-buffering for non-control frames
	status_code  : u16,       // set iff opcode==connection_close; 0 if none
}
Event_on_msg_recv_callback : #type proc(ctx: ^Event_context, arg: ^Event_on_msg_recv_arg, user_data: rawptr) -> void

// Frame receive start
Event_on_frame_recv_start_arg :: struct {
	fin            : u8,
	rsv            : u8,
	opcode         : u8,
	payload_length : u64,
}
Event_on_frame_recv_start_callback : #type proc(ctx: ^Event_context, arg: ^Event_on_frame_recv_start_arg, user_data: rawptr) -> void

// Frame receive chunk
Event_on_frame_recv_chunk_arg :: struct {
	data        : ^u8,
	data_length : c.size_t,
}
Event_on_frame_recv_chunk_callback : #type proc(ctx: ^Event_context, arg: ^Event_on_frame_recv_chunk_arg, user_data: rawptr) -> void

// Frame receive end
Event_on_frame_recv_end_callback : #type proc(ctx: ^Event_context, user_data: rawptr) -> void

// Event-layer IO + hooks
Event_recv_callback    : #type proc(ctx: ^Event_context, buf: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
Event_send_callback    : #type proc(ctx: ^Event_context, data: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
Event_genmask_callback : #type proc(ctx: ^Event_context, buf: ^u8, length: c.size_t, user_data: rawptr) -> c.int

Event_callbacks :: struct {
	recv_callback                  : Event_recv_callback,
	send_callback                  : Event_send_callback,
	genmask_callback               : Event_genmask_callback,
	on_frame_recv_start_callback   : Event_on_frame_recv_start_callback,
	on_frame_recv_chunk_callback   : Event_on_frame_recv_chunk_callback,
	on_frame_recv_end_callback     : Event_on_frame_recv_end_callback,
	on_msg_recv_callback           : Event_on_msg_recv_callback,
}

// Outbound message (non-fragmented)
Event_msg :: struct {
	opcode     : u8,
	msg        : ^u8,
	msg_length : c.size_t,
}

// Source for fragmented message production
// (C union { int fd; void* data; } — choose one)
Event_msg_source :: union {
	c.int,
	rawptr,
}

// Read callback for fragmented message source.
// Store up to 'length' bytes into 'buf'. Set *eof to 1 on end.
// Return bytes produced, 0 if no data available yet, or -1 on error
// (and then call set_error(err_callback_failure)).
Event_fragmented_msg_callback : #type proc(
	ctx: ^Event_context, buf: ^u8, length: c.size_t,
	source: ^Event_msg_source, eof: ^c.int, user_data: rawptr,
) -> c.ssize_t

// Fragmented (streamed) message description
Event_fragmented_msg :: struct {
	opcode        : u8,
	source        : Event_msg_source,
	read_callback : Event_fragmented_msg_callback,
}

// -------- Foreign (C FFI) --------

@(link_prefix = "wslay_", default_calling_convention = "c")
foreign wslay {
	// Frame context lifecycle
	frame_context_init  :: proc(ctx: ^^Frame_context, callbacks: ^Frame_callbacks, user_data: rawptr) -> c.int
	frame_context_free  :: proc(ctx: ^Frame_context) -> void

	// Frame I/O
	frame_send          :: proc(ctx: ^Frame_context, iocb: ^Frame_iocb) -> c.ssize_t
	frame_write         :: proc(ctx: ^Frame_context, iocb: ^Frame_iocb, buf: ^u8, buf_length: c.size_t, pw_payload_length: ^c.size_t) -> c.ssize_t
	frame_recv          :: proc(ctx: ^Frame_context, iocb: ^Frame_iocb) -> c.ssize_t

	// Event context lifecycle (server/client)
	event_context_server_init :: proc(ctx: ^^Event_context, callbacks: ^Event_callbacks, user_data: rawptr) -> c.int
	event_context_client_init :: proc(ctx: ^^Event_context, callbacks: ^Event_callbacks, user_data: rawptr) -> c.int
	event_context_free        :: proc(ctx: ^Event_context) -> void

	// Event config
	event_config_set_allowed_rsv_bits     :: proc(ctx: ^Event_context, rsv: u8) -> void
	event_config_set_no_buffering         :: proc(ctx: ^Event_context, val: c.int) -> void
	event_config_set_max_recv_msg_length  :: proc(ctx: ^Event_context, val: u64) -> void
	event_config_set_callbacks            :: proc(ctx: ^Event_context, callbacks: ^Event_callbacks) -> void

	// Event recv/send/write
	event_recv  :: proc(ctx: ^Event_context) -> c.int
	event_send  :: proc(ctx: ^Event_context) -> c.int
	event_write :: proc(ctx: ^Event_context, buf: ^u8, buf_length: c.size_t) -> c.ssize_t

	// Queueing
	event_queue_msg       :: proc(ctx: ^Event_context, arg: ^Event_msg) -> c.int
	event_queue_msg_ex    :: proc(ctx: ^Event_context, arg: ^Event_msg, rsv: u8) -> c.int
	event_queue_fragmented_msg    :: proc(ctx: ^Event_context, arg: ^Event_fragmented_msg) -> c.int
	event_queue_fragmented_msg_ex :: proc(ctx: ^Event_context, arg: ^Event_fragmented_msg, rsv: u8) -> c.int
	event_queue_close     :: proc(ctx: ^Event_context, status_code: u16, reason: ^u8, reason_length: c.size_t) -> c.int

	// Error/reporting and flow control
	event_set_error            :: proc(ctx: ^Event_context, val: c.int) -> void
	event_want_read            :: proc(ctx: ^Event_context) -> c.int
	event_want_write           :: proc(ctx: ^Event_context) -> c.int
	event_shutdown_read        :: proc(ctx: ^Event_context) -> void
	event_shutdown_write       :: proc(ctx: ^Event_context) -> void
	event_get_read_enabled     :: proc(ctx: ^Event_context) -> c.int
	event_get_write_enabled    :: proc(ctx: ^Event_context) -> c.int
	event_get_close_received   :: proc(ctx: ^Event_context) -> c.int
	event_get_close_sent       :: proc(ctx: ^Event_context) -> c.int
	event_get_status_code_received :: proc(ctx: ^Event_context) -> u16
	event_get_status_code_sent     :: proc(ctx: ^Event_context) -> u16
	event_get_queued_msg_count     :: proc(ctx: ^Event_context) -> c.size_t
	event_get_queued_msg_length    :: proc(ctx: ^Event_context) -> c.size_t
}
