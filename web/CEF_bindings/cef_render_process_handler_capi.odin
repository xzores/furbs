package odin_cef

import "core:c"

// Implement render process callbacks. Called on the render-process main thread unless noted.
// NOTE: This struct is allocated client-side.
Render_process_handler :: struct {
	// Base structure.
	base: base_ref_counted,

	// After WebKit has been initialized.
	on_web_kit_initialized: proc "system" (self: ^Render_process_handler),

	// After a browser has been created. |extra_info| is optional read-only data from creation sites.
	on_browser_created: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
		extra_info: ^cef_dictionary_value, // stays cef_dictionary_value
	),

	// Before a browser is destroyed.
	on_browser_destroyed: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
	),

	// Handler for load status events.
	get_load_handler: proc "system" (self: ^Render_process_handler) -> ^Load_handler,

	// Immediately after the V8 context for a frame has been created.
	on_context_created: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
		frame: ^Frame,
		_context: ^V8_context,
	),

	// Immediately before the V8 context for a frame is released.
	on_context_released: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
		frame: ^Frame,
		_context: ^V8_context,
	),

	// Global uncaught exceptions in a frame. Enable via cef_settings.uncaught_exception_stack_size > 0.
	on_uncaught_exception: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
		frame: ^Frame,
		_context: ^V8_context,
		exception: ^V8_exception,
		stackTrace: ^V8_stack_trace,
	),

	// When a new node in the browser gets focus. |node| may be nil.
	on_focused_node_changed: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
		frame: ^Frame,
		node: ^Dom_node,
	),

	// Message received from a different process. Return 1 if handled.
	on_process_message_received: proc "system" (
		self: ^Render_process_handler,
		browser: ^Browser,
		frame: ^Frame,
		source_process: cef_process_id,
		message: ^Process_message,
	) -> c.int,
}

