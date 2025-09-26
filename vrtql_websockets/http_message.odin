package vrtql_websockets

import "core:c"

// Represents an HTTP request/response parse state.
// - parser/settings come from llhttp
// - headers/url/body/field/value are library buffers/maps
// - headers_complete/done indicate parse milestones
Http_msg :: struct {
	parser: ^llhttp_t,
	settings: ^llhttp_settings_t,

	// A map storing header fields
	headers: ^vws_kvs,

	// URL and body buffers
	url: ^vws_buffer,
	body: ^vws_buffer,

	// Placeholders used while parsing headers
	field: ^vws_buffer,
	value: ^vws_buffer,

	// Flags
	headers_complete: bool,
	done: bool,
}

// Foreign imports (C ABI). We expose clean Odin names while linking to the
// original vws_* symbols from the library.
@(link_prefix="vws_", default_calling_convention="c")
foreign vws {
	// Create a new HTTP message parser.
	// mode must be HTTP_REQUEST or HTTP_RESPONSE
	http_msg_new :: proc(mode: c.int) -> ^Http_msg ---

	// Parse data into the HTTP message.
	// Returns number of bytes parsed, or negative on error.
	http_msg_parse :: proc(req: ^Http_msg, data: cstring, size: c.size_t) -> c.int ---

	// Free resources associated with the message.
	http_msg_free :: proc(req: ^Http_msg) ---

	// Accessors
	http_msg_content_length :: proc(m: ^Http_msg) -> u64 ---
	http_msg_version_major  :: proc(m: ^Http_msg) -> u64 ---
	http_msg_version_minor  :: proc(m: ^Http_msg) -> u64 ---
	http_msg_errno          :: proc(m: ^Http_msg) -> u64 ---
	http_msg_status_code    :: proc(m: ^Http_msg) -> u8  ---
	http_msg_status_string  :: proc(m: ^Http_msg) -> cstring ---
	http_msg_method_string  :: proc(m: ^Http_msg) -> cstring ---
}
