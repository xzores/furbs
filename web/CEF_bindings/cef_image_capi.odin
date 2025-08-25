package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Color type enum
cef_color_type_t :: enum c.int {
	/// RGBA with 8 bits per pixel (32bits total).
	COLOR_TYPE_RGBA_8888,

	/// BGRA with 8 bits per pixel (32bits total).
	COLOR_TYPE_BGRA_8888,

	COLOR_TYPE_NUM_VALUES,
}

// Alpha type enum
cef_alpha_type_t :: enum c.int {
	/// No transparency. The alpha component is ignored.
	ALPHA_TYPE_OPAQUE,

	/// Transparency with pre-multiplied alpha component.
	ALPHA_TYPE_PREMULTIPLIED,

	/// Transparency with post-multiplied alpha component.
	ALPHA_TYPE_POSTMULTIPLIED,
}

Image :: struct {
	base: base_ref_counted,
	
	is_empty: proc "system" (self: ^Image) -> b32,
	is_same: proc "system" (self: ^Image, that: ^Image) -> b32,
	add_bitmap: proc "system" (self: ^Image, scale_factor: f32, pixel_width: c.int, pixel_height: c.int, color_type: cef_color_type_t, alpha_type: cef_alpha_type_t, pixel_data: rawptr, pixel_data_size: c.size_t) -> b32,
	add_png: proc "system" (self: ^Image, scale_factor: f32, png_data: rawptr, png_data_size: c.size_t) -> b32,
	add_jpeg: proc "system" (self: ^Image, scale_factor: f32, jpeg_data: rawptr, jpeg_data_size: c.size_t) -> b32,
	get_width: proc "system" (self: ^Image) -> c.size_t,
	get_height: proc "system" (self: ^Image) -> c.size_t,
	has_representation: proc "system" (self: ^Image, scale_factor: f32) -> b32,
	remove_representation: proc "system" (self: ^Image, scale_factor: f32) -> b32,
	get_representation_info: proc "system" (self: ^Image, scale_factor: f32, actual_scale_factor: ^f32, pixel_width: ^c.int, pixel_height: ^c.int) -> b32,
	get_as_bitmap: proc "system" (self: ^Image, scale_factor: f32, color_type: cef_color_type_t, alpha_type: cef_alpha_type_t, pixel_width: ^c.int, pixel_height: ^c.int) -> ^cef_binary_value,
	get_as_png: proc "system" (self: ^Image, scale_factor: f32, with_transparency: b32, pixel_width: ^c.int, pixel_height: ^c.int) -> ^cef_binary_value,
	get_as_jpeg: proc "system" (self: ^Image, scale_factor: f32, quality: c.int, pixel_width: ^c.int, pixel_height: ^c.int) -> ^cef_binary_value,
}

@(default_calling_convention="system")
foreign lib {
	cef_image_create :: proc() -> ^Image ---
} 