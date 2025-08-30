package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

Process_message :: struct {
	base: base_ref_counted,
	
	/// Returns true (1) if this object is valid. Do not call any other functions
	/// if this function returns false (0).
	is_valid: proc "system" (self: ^Process_message) -> b32,
	
	/// Returns true (1) if the values of this object are read-only. Some APIs may
	/// expose read-only objects.
	is_read_only: proc "system" (self: ^Process_message) -> b32,
	
	/// Returns a writable copy of this object. Returns nullptr when message
	/// contains a shared memory region.
	copy: proc "system" (self: ^Process_message) -> ^Process_message,
	
	// Returns the message name.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_name: proc "system" (self: ^Process_message) -> cef_string_userfree,

	/// Returns the list of arguments. Returns nullptr when message contains a
	/// shared memory region.
	get_argument_list: proc "system" (self: ^Process_message) -> ^cef_list_value,
	
	/// Returns the shared memory region. Returns nullptr when message contains an
	/// argument list.
	get_shared_memory_region: proc "system" (self: ^Process_message) -> ^Shared_memory_region,
}

@(default_calling_convention="system", link_prefix = "cef_", require_results)
foreign lib {
	/// Create a new cef_process_message_t object with the specified name.
	process_message_create :: proc(name: ^cef_string) -> ^Process_message ---
} 