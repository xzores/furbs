package cef_internal

/// Describes how to interpret the components of a pixel.
color_type :: enum u32 {
	/// RGBA with 8 bits per pixel (32bits total).
	COLOR_TYPE_RGBA_8888,

	/// BGRA with 8 bits per pixel (32bits total).
	COLOR_TYPE_BGRA_8888,
}

