package cef_internal

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

/// CEF string maps are a set of key/value string pairs.
string_list_impl :: distinct rawptr
string_list :: ^string_list_impl

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Allocate a new string map.
	string_list_alloc :: proc () -> string_list ---

	/// Return the number of elements in the string list.
	string_list_size :: proc (list: string_list) -> c.size_t ---

	/// Retrieve the value at the specified zero-based string list index. Returns true (1) if the value was successfully retrieved.
	string_list_value :: proc (list: string_list, index: c.size_t, value: ^cef_string) -> c.int ---

	/// Append a new value at the end of the string list.
	string_list_append :: proc (list: string_list, value: ^cef_string) ---

	/// Clear the string list.
	string_list_clear :: proc (list: string_list) ---

	/// Free the string list.
	string_list_free :: proc (list: string_list) ---

	/// Creates a copy of an existing string list.
	string_list_copy :: proc (list: string_list) -> string_list ---
}
