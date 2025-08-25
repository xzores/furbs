package odin_cef

import "core:c"

/// Callback structure used for asynchronous continuation of authentication requests.
/// NOTE: This struct is allocated DLL-side.
auth_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Continue the authentication request.
	cont: proc "system" (self: ^auth_callback, username: ^cef_string, password: ^cef_string),

	/// Cancel the authentication request.
	cancel: proc "system" (self: ^auth_callback),
} 