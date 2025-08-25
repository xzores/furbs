package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

/// Structure used to represent drag data. The functions of this structure may
/// be called on any thread.

/// NOTE: This struct is allocated DLL-side.
Drag_data :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns a copy of the current object.
	clone: proc "system" (self: ^Drag_data) -> ^Drag_data,

	/// Returns true (1) if this object is read-only.
	is_read_only: proc "system" (self: ^Drag_data) -> c.int,

	/// Returns true (1) if the drag data is a link.
	is_link: proc "system" (self: ^Drag_data) -> c.int,

	/// Returns true (1) if the drag data is a text or html fragment.
	is_fragment: proc "system" (self: ^Drag_data) -> c.int,

	/// Returns true (1) if the drag data is a file.
	is_file: proc "system" (self: ^Drag_data) -> c.int,

	/// Return the link URL that is being dragged.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_link_url: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Return the title associated with the link being dragged.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_link_title: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Return the metadata associated with the link being dragged.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_link_metadata: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Return the plain text fragment that is being dragged.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_fragment_text: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Return the text/html fragment that is being dragged.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_fragment_html: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Return the base URL that the fragment came from.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_fragment_base_url: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Return the name of the file that is being dragged out of the browser
	/// window.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_file_name: proc "system" (self: ^Drag_data) -> cef_string_userfree,

	/// Write the contents of the file being dragged out of the browser window
	/// into |writer|. Returns the number of bytes sent to |writer|. If the
	/// size of the file is unknown set |max_size| to -1 and the read will
	/// continue until the file is exhausted.
	get_file_contents: proc "system" (self: ^Drag_data, writer: ^Stream_writer) -> c.size_t,

	/// Retrieve the list of file names that are being dragged into the browser
	/// window.
	get_file_names: proc "system" (self: ^Drag_data, names: string_list) -> c.int,

	/// Retrieve the list of file paths that are being dragged into the browser
	/// window.
	get_file_paths: proc "system" (self: ^Drag_data, paths: string_list) -> c.int,

	/// Set the link URL that is being dragged.
	set_link_url: proc "system" (self: ^Drag_data, url: ^cef_string),

	/// Set the title associated with the link being dragged.
	set_link_title: proc "system" (self: ^Drag_data, title: ^cef_string),

	/// Set the metadata associated with the link being dragged.
	set_link_metadata: proc "system" (self: ^Drag_data, data: ^cef_string),

	/// Set the plain text fragment that is being dragged.
	set_fragment_text: proc "system" (self: ^Drag_data, text: ^cef_string),

	/// Set the text/html fragment that is being dragged.
	set_fragment_html: proc "system" (self: ^Drag_data, html: ^cef_string),

	/// Set the base URL that the fragment came from.
	set_fragment_base_url: proc "system" (self: ^Drag_data, base_url: ^cef_string),

	/// Reset the file contents. You should do this before calling
	/// Browser_host_t::DragTargetDragEnter as the web view does not allow us
	/// to drag in this kind of data.
	reset_file_contents: proc "system" (self: ^Drag_data),

	/// Add a file that is being dragged into the webview.
	add_file: proc "system" (self: ^Drag_data, path: ^cef_string, display_name: ^cef_string),

	/// Clear list of filenames.
	clear_filenames: proc "system" (self: ^Drag_data),

	/// Get the image representation of drag data. May return NULL if no image
	/// representation is available.
	get_image: proc "system" (self: ^Drag_data) -> ^Image,

	/// Get the image hotspot (drag start location relative to image dimensions).
	get_image_hotspot: proc "system" (self: ^Drag_data) -> cef_point,

	/// Returns true (1) if an image representation of drag data is available.
	has_image: proc "system" (self: ^Drag_data) -> c.int,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Create a new Drag_data object.
	drag_data_create :: proc () -> ^Drag_data ---
}
