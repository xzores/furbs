package odin_cef

import "core:c"

// Callback structure used for continuation of custom context menu display.
// NOTE: This struct is allocated DLL-side.
Run_context_menu_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Complete context menu display by selecting |command_id| and |event_flags|.
	cont:	 proc "system" (self: ^Run_context_menu_callback, command_id: c.int, event_flags: Event_flags),

	// Cancel context menu display.
	cancel: proc "system" (self: ^Run_context_menu_callback),
}

// Callback structure used for continuation of custom quick menu display.
// NOTE: This struct is allocated DLL-side.
Run_quick_menu_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Complete quick menu display by selecting |command_id| and |event_flags|.
	cont:	 proc "system" (self: ^Run_quick_menu_callback, command_id: c.int, event_flags: Event_flags),

	// Cancel quick menu display.
	cancel: proc "system" (self: ^Run_quick_menu_callback),
}

// Implement this structure to handle context menu events. Called on the UI thread.
// NOTE: This struct is allocated client-side.
Context_menu_handler :: struct {
	// Base structure.
	base: base_ref_counted,

	// Before a context menu is displayed. |params| describes state. |model| has default menu; modify/clear to customize.
	on_before_context_menu: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
		params: ^Context_menu_params,
		model: ^Menu_model,
	),

	// Allow custom display of the context menu. Return 1 to handle and execute |callback| with selected command id; 0 for default.
	run_context_menu: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
		params: ^Context_menu_params,
		model: ^Menu_model,
		callback: ^Run_context_menu_callback,
	) -> c.int,

	// Execute a command selected from the context menu. Return 1 if handled, 0 for default.
	on_context_menu_command: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
		params: ^Context_menu_params,
		command_id: c.int,
		event_flags: Event_flags,
	) -> c.int,

	// Called when the context menu is dismissed.
	on_context_menu_dismissed: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
	),

	// Custom display of the quick menu for a windowless browser. Return 1 to handle and execute |callback|; 0 to cancel.
	run_quick_menu: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
		location: ^cef_point,
		size: ^cef_size,
		edit_state_flags: Quick_menu_edit_state_flags,
		callback: ^Run_quick_menu_callback,
	) -> c.int,

	// Execute a command selected from the quick menu. Return 1 if handled, 0 for default.
	on_quick_menu_command: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
		command_id: c.int,
		event_flags: Event_flags,
	) -> c.int,

	// Called when the quick menu is dismissed.
	on_quick_menu_dismissed: proc "system" (
		self: ^Context_menu_handler,
		browser: ^Browser,
		frame: ^Frame,
	),
}

// Provides information about the context menu state. UI thread only.
// NOTE: This struct is allocated DLL-side.
Context_menu_params :: struct {
	// Base structure.
	base: base_ref_counted,

	// Mouse X/Y where the menu was invoked (relative to RenderView origin).
	get_xcoord: proc "system" (self: ^Context_menu_params) -> c.int,
	get_ycoord: proc "system" (self: ^Context_menu_params) -> c.int,

	// Flags representing the node type.
	get_type_flags: proc "system" (self: ^Context_menu_params) -> Context_menu_type_flags,

	// URL values (results must be freed with cef_string_userfree_free()).
	get_link_url:				 proc "system" (self: ^Context_menu_params) -> cef_string_userfree,
	get_unfiltered_link_url:	proc "system" (self: ^Context_menu_params) -> cef_string_userfree,
	get_source_url:			 proc "system" (self: ^Context_menu_params) -> cef_string_userfree,

	// True if invoked on an image with non-NULL contents.
	has_image_contents: proc "system" (self: ^Context_menu_params) -> c.int,

	// Title/alt text if invoked on an image. (free with cef_string_userfree_free)
	get_title_text: proc "system" (self: ^Context_menu_params) -> cef_string_userfree,

	// Top-level page URL and subframe URL/charset. (free with cef_string_userfree_free)
	get_page_url:	 proc "system" (self: ^Context_menu_params) -> cef_string_userfree,
	get_frame_url:	proc "system" (self: ^Context_menu_params) -> cef_string_userfree,
	get_frame_charset:proc "system" (self: ^Context_menu_params) -> cef_string_userfree,

	// Media type and supported actions (if invoked on a media element).
	get_media_type:		proc "system" (self: ^Context_menu_params) -> Context_menu_media_type,
	get_media_state_flags: proc "system" (self: ^Context_menu_params) -> Context_menu_media_state_flags,

	// Selection text and misspelled word. (free with cef_string_userfree_free)
	get_selection_text: proc "system" (self: ^Context_menu_params) -> cef_string_userfree,
	get_misspelled_word:proc "system" (self: ^Context_menu_params) -> cef_string_userfree,

	// True if suggestions exist; fills |suggestions| with spell-check suggestions.
	get_dictionary_suggestions: proc "system" (self: ^Context_menu_params, suggestions: string_list) -> c.int,

	// True if invoked on an editable node / with spell-check enabled.
	is_editable:			 proc "system" (self: ^Context_menu_params) -> c.int,
	is_spell_check_enabled:	proc "system" (self: ^Context_menu_params) -> c.int,

	// Actions supported by the editable node (if any).
	get_edit_state_flags: proc "system" (self: ^Context_menu_params) -> Context_menu_edit_state_flags,

	// True if the context menu contains items specified by the renderer process.
	is_custom_menu: proc "system" (self: ^Context_menu_params) -> c.int,
}
