package odin_cef

import "core:c"

/// Generic callback structure used for asynchronous continuation.
/// NOTE: This struct is allocated DLL-side.
///
cef_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Continue processing.
	cont: proc "system" (self: ^cef_callback),

	/// Cancel processing.
	cancel: proc "system" (self: ^cef_callback),
}

/// Generic callback structure used for asynchronous completion.
/// NOTE: This struct is allocated client-side.
///
Completion_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Method that will be called once the task is complete.
	on_complete: proc "system" (self: ^Completion_callback),
} 