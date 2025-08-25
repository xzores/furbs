package odin_cef

import "core:c"

/// Implement this structure to receive string values asynchronously.
/// NOTE: This struct is allocated client-side.
///
string_visitor :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Method that will be executed.
	visit: proc "system" (self: ^string_visitor, string: ^cef_string),
} 