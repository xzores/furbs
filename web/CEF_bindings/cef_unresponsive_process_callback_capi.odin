package odin_cef

import "core:c"

/// Callback structure for asynchronous handling of an unresponsive process.
/// NOTE: This struct is allocated DLL-side.
unresponsive_process_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Reset the timeout for the unresponsive process.
	wait: proc "system" (self: ^unresponsive_process_callback),

	/// Terminate the unresponsive process.
	terminate: proc "system" (self: ^unresponsive_process_callback),
} 