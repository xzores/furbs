package odin_cef

import "core:c"

// Implement this structure to handle events related to commands. Called on the UI thread.
// NOTE: This struct is allocated client-side.
Command_handler :: struct {
	// Base structure.
	base: base_ref_counted,

	// Execute a Chrome command triggered via menu selection or keyboard shortcut.
	// Use cef_id_for_command_id_name() to map IDC names to numeric |command_id|.
	// |disposition| describes the intended command target.
	// Return 1 if handled, 0 for default. For context menus this is called after
	// Context_menu_handler_t::OnContextMenuCommand. (Chrome style only.)
	on_chrome_command: proc "system" (
		self: ^Command_handler,
		browser: ^Browser,
		command_id: c.int,
		disposition: Window_open_disposition,
	) -> c.int,

	// Should a Chrome app menu item be visible? Only called for items visible by default. (Chrome style only.)
	is_chrome_app_menu_item_visible: proc "system" (
		self: ^Command_handler,
		browser: ^Browser,
		command_id: c.int,
	) -> c.int,

	// Should a Chrome app menu item be enabled? Only called for items enabled by default. (Chrome style only.)
	is_chrome_app_menu_item_enabled: proc "system" (
		self: ^Command_handler,
		browser: ^Browser,
		command_id: c.int,
	) -> c.int,

	// During browser creation: should a Chrome page action icon be visible? (Chrome style only.)
	is_chrome_page_action_icon_visible: proc "system" (
		self: ^Command_handler,
		icon_type: Chrome_page_action_icon_type,
	) -> c.int,

	// During browser creation: should a Chrome toolbar button be visible? (Chrome style only.)
	is_chrome_toolbar_button_visible: proc "system" (
		self: ^Command_handler,
		button_type: Chrome_toolbar_button_type,
	) -> c.int,
}