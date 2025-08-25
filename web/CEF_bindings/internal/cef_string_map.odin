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
string_map_impl :: distinct rawptr
string_map :: ^string_map_impl

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Allocate a new string map.
	string_map_alloc :: proc () -> string_map ---

	/// Return the number of elements in the string map.
	string_map_size :: proc (m: string_map) -> c.size_t ---

	/// Return the value assigned to the specified key.
	string_map_find :: proc (m: string_map, key: ^cef_string, value: ^cef_string) -> c.int ---

	/// Return the key at the specified zero-based string map index.
	string_map_key :: proc (m: string_map, index: c.size_t, key: ^cef_string) -> c.int ---

	/// Return the value at the specified zero-based string map index.
	string_map_value :: proc (m: string_map, index: c.size_t, value: ^cef_string) -> c.int ---

	/// Append a new key/value pair at the end of the string map. If the key exists,
	/// overwrite the existing value with a new value w/o changing the pair order.
	string_map_append :: proc (m: string_map, key: ^cef_string, value: ^cef_string) -> c.int ---

	/// Clear the string map.
	string_map_clear :: proc (m: string_map) ---

	/// Free the string map.
	string_map_free :: proc (m: string_map) ---
}
