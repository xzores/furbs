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
	
	is_valid: proc "system" (self: ^Process_message) -> b32,
	is_read_only: proc "system" (self: ^Process_message) -> b32,
	copy: proc "system" (self: ^Process_message) -> ^Process_message,
	get_name: proc "system" (self: ^Process_message) -> cef_string_userfree,
	get_argument_list: proc "system" (self: ^Process_message) -> ^cef_list_value,
	get_shared_memory_region: proc "system" (self: ^Process_message) -> ^Shared_memory_region,
}

@(default_calling_convention="system", link_prefix = "cef_", require_results)
foreign lib {
	process_message_create :: proc(name: ^cef_string) -> ^Process_message ---
} 