package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Structure representing print settings.
// NOTE: This struct is allocated DLL-side.
Print_settings :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if this object is valid. Do not call other functions if 0.
	is_valid: proc "system" (self: ^Print_settings) -> c.int,

	// Returns 1 if values are read-only (some APIs expose read-only objects).
	is_read_only: proc "system" (self: ^Print_settings) -> c.int,

	// Set the page orientation.
	set_orientation: proc "system" (self: ^Print_settings, landscape: c.int),

	// Returns 1 if orientation is landscape.
	is_landscape: proc "system" (self: ^Print_settings) -> c.int,

	// Set printer printable area in device units. Some platforms already provide flipped area; set landscape_needs_flip=0 there to avoid double flipping.
	set_printer_printable_area: proc "system" (
		self: ^Print_settings,
		physical_size_device_units: ^cef_size,
		printable_area_device_units: ^cef_rect,
		landscape_needs_flip: c.int,
	),

	// Set the device name.
	set_device_name: proc "system" (self: ^Print_settings, name: ^cef_string),

	// Get the device name. Result must be freed with cef_string_userfree_free().
	get_device_name: proc "system" (self: ^Print_settings) -> cef_string_userfree,

	// Set/Get DPI (dots per inch).
	set_dpi: proc "system" (self: ^Print_settings, dpi: c.int),
	get_dpi: proc "system" (self: ^Print_settings) -> c.int,

	// Set the page ranges.
	set_page_ranges: proc "system" (self: ^Print_settings, rangesCount: c.size_t, ranges: [^]cef_range),

	// Number of page ranges that currently exist.
	get_page_ranges_count: proc "system" (self: ^Print_settings) -> c.size_t,

	// Retrieve the page ranges.
	get_page_ranges: proc "system" (self: ^Print_settings, rangesCount: ^c.size_t, ranges: ^cef_range),

	// Set whether only the selection will be printed / query it.
	set_selection_only: proc "system" (self: ^Print_settings, selection_only: c.int),
	is_selection_only:	proc "system" (self: ^Print_settings) -> c.int,

	// Set whether pages will be collated / query it.
	set_collate:	proc "system" (self: ^Print_settings, collate: c.int),
	will_collate: proc "system" (self: ^Print_settings) -> c.int,

	// Set/Get color model.
	set_color_model: proc "system" (self: ^Print_settings, model: Color_model),
	get_color_model: proc "system" (self: ^Print_settings) -> Color_model,

	// Set/Get number of copies.
	set_copies: proc "system" (self: ^Print_settings, copies: c.int),
	get_copies: proc "system" (self: ^Print_settings) -> c.int,

	// Set/Get duplex mode.
	set_duplex_mode: proc "system" (self: ^Print_settings, mode: Duplex_mode),
	get_duplex_mode: proc "system" (self: ^Print_settings) -> Duplex_mode,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Create a new Print_settings_t object.
	print_settings_create :: proc "system" () -> ^Print_settings ---
}
