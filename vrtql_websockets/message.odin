package vrtql_websockets

import "core:c"

// Message format (C int → enum u32)
Msg_format :: enum u32 {
	mpack_format,
	json_format,
}

// Message state flags (values 1–10 reserved in C, here exposed as bit positions).
@(private="file")
Msg_state_enum :: enum u32 {
	valid    = 1,
	priority = 2,
	irq      = 3,
}
Msg_state :: bit_set[Msg_state_enum; u32]

// Represents a message with routing, headers, and content
Msg :: struct {
	routing: ^vws_kvs,       // Routing key/value map
	headers: ^vws_kvs,       // Header fields
	content: ^vws_buffer,    // Message content buffer
	flags:   u64,            // State flags
	format:  Msg_format,     // Message format
	data:    rawptr,         // User-defined pointer
}

// Foreign imports
@(link_prefix="vrtql_", default_calling_convention="c")
foreign vrtql {
	// Lifecycle
	msg_new              :: proc() -> ^Msg ---
	msg_free             :: proc(msg: ^Msg) ---
	msg_copy             :: proc(original: ^Msg) -> ^Msg ---

	// Debug/dump
	msg_dump             :: proc(m: ^Msg) ---
	msg_repr             :: proc(msg: ^Msg) -> ^vws_buffer ---

	// Headers
	msg_get_header       :: proc(msg: ^Msg, key: cstring) -> cstring ---
	msg_set_header       :: proc(msg: ^Msg, key: cstring, value: cstring) ---
	msg_clear_header     :: proc(msg: ^Msg, key: cstring) ---
	msg_clear_headers    :: proc(msg: ^Msg) ---

	// Routing
	msg_get_routing      :: proc(msg: ^Msg, key: cstring) -> cstring ---
	msg_set_routing      :: proc(msg: ^Msg, key: cstring, value: cstring) ---
	msg_clear_routing    :: proc(msg: ^Msg, key: cstring) ---
	msg_clear_routings   :: proc(msg: ^Msg) ---

	// Content
	msg_get_content      :: proc(msg: ^Msg) -> cstring ---
	msg_get_content_size :: proc(msg: ^Msg) -> c.size_t ---
	msg_set_content      :: proc(msg: ^Msg, value: cstring) ---
	msg_set_content_binary :: proc(msg: ^Msg, value: cstring, size: c.size_t) ---
	msg_clear_content    :: proc(msg: ^Msg) ---

	// Clearing
	msg_clear            :: proc(msg: ^Msg) ---
	msg_is_empty         :: proc(msg: ^Msg) -> bool ---

	// Serialization
	msg_serialize        :: proc(msg: ^Msg) -> ^vws_buffer ---
	msg_deserialize      :: proc(msg: ^Msg, data: ^u8, length: c.size_t) -> bool ---

	// Networking
	msg_send             :: proc(c: ^vws_cnx, msg: ^Msg) -> c.ssize_t ---
	msg_recv             :: proc(c: ^vws_cnx) -> ^Msg ---
}
