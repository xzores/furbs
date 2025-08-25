package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

Resource_bundle_handler :: struct {
	base: base_ref_counted,
	
	get_localized_string: proc "system" (self: ^Resource_bundle_handler, string_id: c.int, string: ^cef_string) -> b32,
	get_data_resource: proc "system" (self: ^Resource_bundle_handler, resource_id: c.int, data: ^^cef_binary_value) -> b32,
	get_data_resource_for_scale: proc "system" (self: ^Resource_bundle_handler, resource_id: c.int, scale_factor: cef_scale_factor_t, data: ^^cef_binary_value) -> b32,
} 