package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_display_t :: struct {
	base: base_ref_counted,
	
	get_id: proc "system" (self: ^cef_display_t) -> c.int64_t,
	get_display_id: proc "system" (self: ^cef_display_t) -> c.int64_t,
	get_device_scale_factor: proc "system" (self: ^cef_display_t) -> f64,
	convert_rect_to_pixels: proc "system" (self: ^cef_display_t, rect: ^cef_rect) -> cef_rect,
	convert_rect_from_pixels: proc "system" (self: ^cef_display_t, rect: ^cef_rect) -> cef_rect,
	get_bounds: proc "system" (self: ^cef_display_t) -> cef_rect,
	get_work_area: proc "system" (self: ^cef_display_t) -> cef_rect,
	get_rotation: proc "system" (self: ^cef_display_t) -> c.int,
	get_color_depth: proc "system" (self: ^cef_display_t) -> c.int,
	get_bits_per_component: proc "system" (self: ^cef_display_t) -> c.int,
	get_monochrome: proc "system" (self: ^cef_display_t) -> b32,
	get_is_internal: proc "system" (self: ^cef_display_t) -> b32,
	get_is_primary: proc "system" (self: ^cef_display_t) -> b32,
	get_device_scale_factor: proc "system" (self: ^cef_display_t) -> f64,
	convert_rect_to_pixels: proc "system" (self: ^cef_display_t, rect: ^cef_rect) -> cef_rect,
	convert_rect_from_pixels: proc "system" (self: ^cef_display_t, rect: ^cef_rect) -> cef_rect,
	get_bounds: proc "system" (self: ^cef_display_t) -> cef_rect,
	get_work_area: proc "system" (self: ^cef_display_t) -> cef_rect,
	get_rotation: proc "system" (self: ^cef_display_t) -> c.int,
	get_color_depth: proc "system" (self: ^cef_display_t) -> c.int,
	get_bits_per_component: proc "system" (self: ^cef_display_t) -> c.int,
	get_monochrome: proc "system" (self: ^cef_display_t) -> b32,
	get_is_internal: proc "system" (self: ^cef_display_t) -> b32,
	get_is_primary: proc "system" (self: ^cef_display_t) -> b32,
} 