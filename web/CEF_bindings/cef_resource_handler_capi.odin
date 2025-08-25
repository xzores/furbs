package odin_cef;

import "core:c"

// Callback for asynchronous continuation of cef_resource_handler_t::skip().
// NOTE: This struct is allocated DLL-side.
Resource_skip_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Continue skip(). If bytes_skipped > 0 more skipping may occur; if <= 0 the request fails with ERR_REQUEST_RANGE_NOT_SATISFIABLE.
	cont: proc "system" (self: ^Resource_skip_callback, bytes_skipped: c.int64_t),
}

// Callback for asynchronous continuation of cef_resource_handler_t::read().
// NOTE: This struct is allocated DLL-side.
Resource_read_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Continue read(). 0 => complete; >0 => read() again; <0 => fail with error code = bytes_read.
	cont: proc "system" (self: ^Resource_read_callback, bytes_read: c.int),
}

// Custom request handler. Functions are called on the IO thread unless noted.
// NOTE: This struct is allocated client-side.
Resource_handler :: struct {
	// Base structure.
	base: base_ref_counted,

	// Open the response stream.
	// - handle_request=1 & return 1: handle immediately.
	// - handle_request=0 & return 1: decide later; call |callback| to continue/cancel.
	// - handle_request=1 & return 0: cancel immediately.
	// For backwards compat you may set handle_request=0 & return 0 to trigger process_request().
	open: proc "system" (
		self: ^Resource_handler,
		request: ^Request,
		handle_request: ^c.int,
		callback: ^cef_callback,
	) -> c.int,

	// DEPRECATED. Begin processing the request; call callback::cont() when headers are available. Return 0 to cancel.
	process_request: proc "system" (
		self: ^Resource_handler,
		request: ^Request,
		callback: ^cef_callback,
	) -> c.int,

	// Provide response headers.
	// - If length unknown: *response_length = -1 and read() until it returns 0.
	// - If known: set positive length and read() until done.
	// - To redirect: set |redirectUrl| or set redirect status + Location header on |response|.
	// - On setup error: response.set_error(...).
	get_response_headers: proc "system" (
		self: ^Resource_handler,
		response: ^Response,
		response_length: ^c.int64_t,
		redirectUrl: ^cef_string,
	),

	// Skip response data for Range requests.
	// - Immediate: set *bytes_skipped and return 1.
	// - Async: set *bytes_skipped=0, return 1, then callback.cont(...) when ready.
	// - Failure: set *bytes_skipped < 0 and return 0.
	skip: proc "system" (
		self: ^Resource_handler,
		bytes_to_skip: c.int64_t,
		bytes_skipped: ^c.int64_t,
		callback: ^Resource_skip_callback,
	) -> c.int,

	// Read response data.
	// - Immediate: copy up to bytes_to_read into data_out, set *bytes_read, return 1.
	// - Async: keep data_out pointer valid, set *bytes_read=0, return 1, then callback.cont(...) when ready.
	// - Complete: set *bytes_read=0 and return 0.
	// - Failure: set *bytes_read < 0 and return 0.
	read: proc "system" (
		self: ^Resource_handler,
		data_out: rawptr,
		bytes_to_read: c.int,
		bytes_read: ^c.int,
		callback: ^Resource_read_callback,
	) -> c.int,

	// DEPRECATED. Use skip/read instead.
	read_response: proc "system" (
		self: ^Resource_handler,
		data_out: rawptr,
		bytes_to_read: c.int,
		bytes_read: ^c.int,
		callback: ^cef_callback,
	) -> c.int,

	// Request processing has been canceled.
	cancel: proc "system" (self: ^Resource_handler),
}
