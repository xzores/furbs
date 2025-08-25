package odin_cef

import "core:c"

// Implement to handle menu model events. Called on the browser UI thread unless noted.
// NOTE: This struct is allocated client-side.
Menu_model_delegate :: struct {
	// Base structure.
	base: base_ref_counted,

	// Perform the action associated with |command_id| and optional |event_flags|.
	execute_command: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
		command_id: c.int,
		event_flags: Event_flags,
	),

	// Called when the user moves the mouse outside the menu and over the owning window.
	mouse_outside_menu: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
		screen_point: ^cef_point,
	),

	// Unhandled open submenu keyboard command. |is_rtl| is true (1) for RTL menus.
	unhandled_open_submenu: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
		is_rtl: c.int,
	),

	// Unhandled close submenu keyboard command. |is_rtl| is true (1) for RTL menus.
	unhandled_close_submenu: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
		is_rtl: c.int,
	),

	// The menu is about to show.
	menu_will_show: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
	),

	// The menu has closed.
	menu_closed: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
	),

	// Optionally modify a menu item label. Return true (1) if |label| was modified.
	format_label: proc "system" (
		self: ^Menu_model_delegate,
		menu_model: ^Menu_model,
		label: ^cef_string,
	) -> c.int,
}
