package odin_cef

import "core:c"

/// Implement this structure to receive accessibility notification when accessibility events have been registered. The functions of this structure
/// will be called on the UI thread.
/// NOTE: This struct is allocated client-side.
accessibility_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called after renderer process sends accessibility tree changes to the browser process.
	on_accessibility_tree_change: proc "system" (self: ^accessibility_handler, value: ^cef_value),

	/// Called after renderer process sends accessibility location changes to the browser process.
	on_accessibility_location_change: proc "system" (self: ^accessibility_handler, value: ^cef_value),
} 