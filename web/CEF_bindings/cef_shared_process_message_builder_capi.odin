package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_shared_process_message_builder_t :: struct {
	base: base_ref_counted,
	
	is_valid: proc "system" (self: ^cef_shared_process_message_builder_t) -> b32,
	size: proc "system" (self: ^cef_shared_process_message_builder_t) -> c.size_t,
	memory: proc "system" (self: ^cef_shared_process_message_builder_t) -> rawptr,
	build: proc "system" (self: ^cef_shared_process_message_builder_t) -> ^Process_message,
}

