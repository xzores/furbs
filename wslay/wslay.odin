package wslay

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "lib/wslay.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "lib/wslay.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "lib/wslay.dylib"
}

// ---------- Errors ----------

Error :: enum i32 {
	want_read          = -100,
	want_write         = -101,
	proto              = -200,
	invalid_argument   = -300,
	invalid_callback   = -301,
	no_more_msg        = -302,
	callback_failure   = -400,
	wouldblock         = -401,
	nomem              = -500,
}

// ---------- RFC6455 status codes ----------

Status_code :: enum u32 {
	normal_closure              = 1000,
	going_away                  = 1001,
	protocol_error              = 1002,
	unsupported_data            = 1003,
	no_status_rcvd              = 1005,
	abnormal_closure            = 1006,
	invalid_frame_payload_data  = 1007,
	policy_violation            = 1008,
	message_too_big             = 1009,
	mandatory_ext               = 1010,
	internal_server_error       = 1011,
	tls_handshake               = 1015,
}

// ---------- I/O flags (bit_set) ----------

@(private="file")
Io_flag_enum :: enum u32 {
	// bit positions
	msg_more = 0,
}

Io_flags :: bit_set[Io_flag_enum; u32]

// ---------- Frame callbacks ----------

Frame_send_cb      :: #type proc "c" (data: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
Frame_recv_cb      :: #type proc "c" (buf: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
Frame_genmask_cb   :: #type proc "c" (buf: ^u8, length: c.size_t, user_data: rawptr) -> c.int

Frame_callbacks :: struct {
	send_callback:     Frame_send_cb,
	recv_callback:     Frame_recv_cb,
	genmask_callback:  Frame_genmask_cb,
}

// ---------- Opcodes ----------

Opcode :: enum u32 {
	continuation_frame   = 0x0,
	text_frame           = 0x1,
	binary_frame         = 0x2,
	connection_close     = 0x8,
	ping                 = 0x9,
	pong                 = 0xA,
}

// ---------- RSV helpers (from macros) ----------

RSV_NONE : u8 : 0
RSV1_BIT : u8 : 1 << 2
RSV2_BIT : u8 : 1 << 1
RSV3_BIT : u8 : 1 << 0

wslay_is_ctrl_frame :: proc (opcode: u8) -> bool {
	return ((opcode >> 3) & 1) != 0
}

wslay_get_rsv1 :: proc (rsv: u8) -> bool {
	return ((rsv >> 2) & 1) != 0
}

wslay_get_rsv2 :: proc (rsv: u8) -> bool {
	return ((rsv >> 1) & 1) != 0
}

wslay_get_rsv3 :: proc (rsv: u8) -> bool {
	return (rsv & 1) != 0
}

// ---------- Frame IO control block ----------

Frame_iocb :: struct {
	// 1 for final frame, 0 otherwise
	fin: u8,

	// reserved bits: rsv = ((RSV1 << 2) | (RSV2 << 1) | RSV3)
	rsv: u8,

	// 4-bit opcode
	opcode: u8,

	// payload length [0, 2**63-1]
	payload_length: u64,

	// 1 if masked, 0 otherwise
	mask: u8,

	// payload slice pointer (library-owned for recv path)
	data: ^u8,

	// bytes in `data`
	data_length: c.size_t,
}

// ---------- Opaque contexts ----------

Frame_context :: struct {}
Event_context :: struct {}

Frame_context_ptr :: ^Frame_context
Event_context_ptr :: ^Event_context

// ---------- Event recv message arg ----------

Event_on_msg_recv_arg :: struct {
	// reserved bits: rsv = (RSV1 << 2) | (RSV2 << 1) | RSV3
	rsv: u8,

	// opcode
	opcode: u8,

	// received message (library-owned buffer)
	msg: ^u8,

	// message length
	msg_length: c.size_t,

	// status code iff opcode == connection_close, else 0
	status_code: u16,
}

// ---------- Event callbacks ----------

Event_on_msg_recv_cb :: #type proc "c" (ctx: Event_context_ptr, arg: ^Event_on_msg_recv_arg, user_data: rawptr)

Event_on_frame_recv_start_arg :: struct {
	// 1 for final frame, or 0
	fin: u8,
	// reserved bits
	rsv: u8,
	// opcode of the frame
	opcode: u8,
	// payload length of this frame
	payload_length: u64,
}

Event_on_frame_recv_start_cb :: #type proc "c" (ctx: Event_context_ptr, arg: ^Event_on_frame_recv_start_arg, user_data: rawptr)

Event_on_frame_recv_chunk_arg :: struct {
	// chunk of payload data
	data: ^u8,
	// length of data
	data_length: c.size_t,
}

Event_on_frame_recv_chunk_cb :: #type proc "c" (ctx: Event_context_ptr, arg: ^Event_on_frame_recv_chunk_arg, user_data: rawptr)
Event_on_frame_recv_end_cb   :: #type proc "c" (ctx: Event_context_ptr, user_data: rawptr)

Event_recv_cb     :: #type proc "c" (ctx: Event_context_ptr, buf: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
Event_send_cb     :: #type proc "c" (ctx: Event_context_ptr, data: ^u8, length: c.size_t, flags: c.int, user_data: rawptr) -> c.ssize_t
Event_genmask_cb  :: #type proc "c" (ctx: Event_context_ptr, buf: ^u8, length: c.size_t, user_data: rawptr) -> c.int

Event_callbacks :: struct {
	recv_callback:                    Event_recv_cb,
	send_callback:                    Event_send_cb,
	genmask_callback:                 Event_genmask_cb,
	on_frame_recv_start_callback:     Event_on_frame_recv_start_cb,
	on_frame_recv_chunk_callback:     Event_on_frame_recv_chunk_cb,
	on_frame_recv_end_callback:       Event_on_frame_recv_end_cb,
	on_msg_recv_callback:             Event_on_msg_recv_cb,
}

// ---------- Event message structs ----------

Event_msg :: struct {
	opcode: u8,
	msg:    ^u8,
	msg_length: c.size_t,
}

// "source" union for fragmented messages
Msg_source :: union {
	c.int,
	rawptr,
}

Event_fragmented_msg_cb :: #type proc "c" (
	ctx: Event_context_ptr,
	buf: ^u8,
	length: c.size_t,
	source: ^Msg_source,
	eof: ^c.int,
	user_data: rawptr,
) -> c.ssize_t

Event_fragmented_msg :: struct {
	opcode: u8,
	source: Msg_source,
	read_callback: Event_fragmented_msg_cb,
}

// ---------- Foreign functions ----------
@(link_prefix="wslay_", require_results, default_calling_convention="c")
foreign lib {
	// Frame context
	frame_context_init  :: proc (out_ctx: ^^Frame_context, callbacks: ^Frame_callbacks, user_data: rawptr) -> c.int ---
	frame_context_free  :: proc (ctx: ^Frame_context) ---
	
	// Frame send/recv/write
	frame_send          :: proc (ctx: ^Frame_context, iocb: ^Frame_iocb) -> c.ssize_t ---
	frame_write         :: proc (ctx: ^Frame_context, iocb: ^Frame_iocb, buf: ^u8, buflen: c.size_t, pwpayloadlen: ^c.size_t) -> c.ssize_t ---
	frame_recv          :: proc (ctx: ^Frame_context, iocb: ^Frame_iocb) -> c.ssize_t ---

	// Event context (server/client)
	event_context_server_init :: proc (out_ctx: ^^Event_context, callbacks: ^Event_callbacks, user_data: rawptr) -> c.int ---
	event_context_client_init :: proc (out_ctx: ^^Event_context, callbacks: ^Event_callbacks, user_data: rawptr) -> c.int ---
	event_context_free        :: proc (ctx: ^Event_context) ---
	
	// Event config
	event_config_set_allowed_rsv_bits     :: proc (ctx: ^Event_context, rsv: u8) ---
	event_config_set_no_buffering         :: proc (ctx: ^Event_context, val: c.int) ---
	event_config_set_max_recv_msg_length  :: proc (ctx: ^Event_context, val: u64) ---
	event_config_set_callbacks            :: proc (ctx: ^Event_context, callbacks: ^Event_callbacks) ---

	// Event I/O (send/recv/write)
	event_recv   :: proc (ctx: ^Event_context) -> c.int ---
	event_send   :: proc (ctx: ^Event_context) -> c.int ---
	event_write  :: proc (ctx: ^Event_context, buf: ^u8, buflen: c.size_t) -> c.ssize_t ---

	// Queueing
	event_queue_msg                :: proc (ctx: ^Event_context, arg: ^Event_msg) -> c.int ---
	event_queue_msg_ex             :: proc (ctx: ^Event_context, arg: ^Event_msg, rsv: u8) -> c.int ---
	event_queue_fragmented_msg     :: proc (ctx: ^Event_context, arg: ^Event_fragmented_msg) -> c.int ---
	event_queue_fragmented_msg_ex  :: proc (ctx: ^Event_context, arg: ^Event_fragmented_msg, rsv: u8) -> c.int ---
	event_queue_close              :: proc (ctx: ^Event_context, status_code: u16, reason: ^u8, reason_length: c.size_t) -> c.int ---

	// Error + wants
	event_set_error     :: proc (ctx: ^Event_context, val: c.int) ---
	event_want_read     :: proc (ctx: ^Event_context) -> c.int ---
	event_want_write    :: proc (ctx: ^Event_context) -> c.int ---

	// Shutdown / enable state
	event_shutdown_read         :: proc (ctx: ^Event_context) ---
	event_shutdown_write        :: proc (ctx: ^Event_context) ---
	event_get_read_enabled      :: proc (ctx: ^Event_context) -> c.int ---
	event_get_write_enabled     :: proc (ctx: ^Event_context) -> c.int ---

	// Close state + codes
	event_get_close_received            :: proc (ctx: ^Event_context) -> c.int ---
	event_get_close_sent                :: proc (ctx: ^Event_context) -> c.int ---
	event_get_status_code_received      :: proc (ctx: ^Event_context) -> u16 ---
	event_get_status_code_sent          :: proc (ctx: ^Event_context) -> u16 ---

	// Queue stats
	event_get_queued_msg_count   :: proc (ctx: ^Event_context) -> c.size_t ---
	event_get_queued_msg_length  :: proc (ctx: ^Event_context) -> c.size_t ---
}

// ---------- Convenience notes ----------
//
// - When setting Io_flags for send/write callbacks, use bit_set ops:
//     flags: Io_flags
//     flags |= {.msg_more}
//   And pass as `c.int(flags)` to C callbacks if needed.
//
// - Switch guidance from your spec applies when you write any Odin-side logic
//   around opcodes/unions, but this header is just FFI surface, so no switches here.
