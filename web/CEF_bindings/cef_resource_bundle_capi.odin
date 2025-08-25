package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_scale_factor_t :: enum c.int {
	SCALE_FACTOR_NONE = 0,
	SCALE_FACTOR_100P = 1,
	SCALE_FACTOR_125P = 2,
	SCALE_FACTOR_133P = 3,
	SCALE_FACTOR_150P = 4,
	SCALE_FACTOR_180P = 5,
	SCALE_FACTOR_200P = 6,
	SCALE_FACTOR_250P = 7,
	SCALE_FACTOR_300P = 8,
}

cef_resource_bundle_t :: struct {
	base: base_ref_counted,
	
	get_localized_string: proc "system" (self: ^cef_resource_bundle_t, string_id: c.int) -> cef_string_userfree,
	get_data_resource: proc "system" (self: ^cef_resource_bundle_t, resource_id: c.int) -> ^cef_binary_value,
	get_data_resource_for_scale: proc "system" (self: ^cef_resource_bundle_t, resource_id: c.int, scale_factor: cef_scale_factor_t) -> ^cef_binary_value,
} 