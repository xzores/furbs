package cef_internal

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

/// CEF string multimaps are a set of key/value string pairs. More than one value can be assigned to a single key.
///
string_multimap_impl :: distinct rawptr
string_multimap :: ^string_multimap_impl

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Allocate a new string multimap.
	string_multimap_alloc :: proc () -> string_multimap ---

	/// Return the number of elements in the string multimap.
	string_multimap_size :: proc (m: string_multimap) -> c.size_t ---

	/// Return the number of values with the specified key.
	string_multimap_find_count :: proc (m: string_multimap, key: ^cef_string) -> c.size_t ---

	/// Return the value_index-th value with the specified key.
	string_multimap_enumerate :: proc (m: string_multimap, key: ^cef_string, value_index: c.size_t, value: ^cef_string) -> c.int ---

	/// Return the key at the specified zero-based string multimap index.
	string_multimap_key :: proc (m: string_multimap, index: c.size_t, key: ^cef_string) -> c.int ---

	/// Return the value at the specified zero-based string multimap index.
	string_multimap_value :: proc (m: string_multimap, index: c.size_t, value: ^cef_string) -> c.int ---

	/// Append a new key/value pair at the end of the string multimap.
	string_multimap_append :: proc (m: string_multimap, key: ^cef_string, value: ^cef_string) -> c.int ---

	/// Clear the string multimap.
	string_multimap_clear :: proc (m: string_multimap) ---

	/// Free the string multimap.
	string_multimap_free :: proc (m: string_multimap) ---
}
