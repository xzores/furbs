package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// A Window is a top-level widget in the Views hierarchy. By default it has a non-client area with title bar, icon and buttons that supports moving and resizing.
// All size/position values are DIP unless noted. Call methods on the browser-process UI thread unless noted.
// NOTE: This struct is allocated DLL-side.
cef_window :: struct {
	// Base structure.
	base: cef_panel,

	// Show the Window.
	show: proc "system" (self: ^cef_window),

	// Show as a browser modal dialog relative to |browser_view| (which must belong to the parent returned by window delegate).
	show_as_browser_modal_dialog: proc "system" (self: ^cef_window, browser_view: ^Browser_view),

	// Hide the Window.
	hide: proc "system" (self: ^cef_window),

	// Size to |size| and center in the current display.
	center_window: proc "system" (self: ^cef_window, size: ^cef_size),

	// Close the Window.
	close: proc "system" (self: ^cef_window),

	// Returns 1 if the Window has been closed.
	is_closed: proc "system" (self: ^cef_window) -> c.int,

	// Activate (assumes it exists and is visible).
	activate: proc "system" (self: ^cef_window),

	// Deactivate, making the next Window in Z-order active.
	deactivate: proc "system" (self: ^cef_window),

	// Returns whether this is the currently active Window.
	is_active: proc "system" (self: ^cef_window) -> c.int,

	// Bring this Window to the top.
	bring_to_top: proc "system" (self: ^cef_window),

	// Set always-on-top state.
	set_always_on_top: proc "system" (self: ^cef_window, on_top: c.int),

	// Returns whether always-on-top is set.
	is_always_on_top: proc "system" (self: ^cef_window) -> c.int,

	// Maximize / Minimize / Restore.
	maximize: proc "system" (self: ^cef_window),
	minimize: proc "system" (self: ^cef_window),
	restore:	proc "system" (self: ^cef_window),

	// Set fullscreen state. Window delegate OnWindowFullscreenTransition will be notified.
	set_fullscreen: proc "system" (self: ^cef_window, fullscreen: c.int),

	// Query maximized / minimized / fullscreen.
	is_maximized:	proc "system" (self: ^cef_window) -> c.int,
	is_minimized:	proc "system" (self: ^cef_window) -> c.int,
	is_fullscreen: proc "system" (self: ^cef_window) -> c.int,

	// View that currently has focus in this Window (or nil).
	get_focused_view: proc "system" (self: ^cef_window) -> ^cef_view,

	// Set/Get Window title. get_title result must be freed with cef_string_userfree_free().
	set_title: proc "system" (self: ^cef_window, title: ^cef_string),
	get_title: proc "system" (self: ^cef_window) -> cef_string_userfree,

	// Set/Get 16x16 Window icon (title bar) and larger App icon (task switcher, etc.).
	set_window_icon:	 proc "system" (self: ^cef_window, image: ^cef_image),
	get_window_icon:	 proc "system" (self: ^cef_window) -> ^cef_image,
	set_window_app_icon: proc "system" (self: ^cef_window, image: ^cef_image),
	get_window_app_icon: proc "system" (self: ^cef_window) -> ^cef_image,

	// Add an overlay View with absolute positioning and high z-order.
	// See doc for docking behavior and activation. Overlays are hidden by default.
	add_overlay_view: proc "system" (
		self: ^cef_window,
		view: ^cef_view,
		docking_mode: cef_docking_mode_t,
		can_activate: c.int,
	) -> ^cef_overlay_controller,

	// Show a menu with contents |menu_model| at |screen_point| with |anchor_position|.
	show_menu: proc "system" (
		self: ^cef_window,
		menu_model: ^Menu_model,
		screen_point: ^cef_point,
		anchor_position: cef_menu_anchor_position_t,
	),

	// Cancel the currently showing menu, if any.
	cancel_menu: proc "system" (self: ^cef_window),

	// Display that most closely intersects this Window’s bounds (may be nil if not displayed).
	get_display: proc "system" (self: ^cef_window) -> ^cef_display,

	// Client-area bounds in screen coordinates.
	get_client_area_bounds_in_screen: proc "system" (self: ^cef_window) -> cef_rect,

	// Set regions where mouse events will be intercepted to support drag operations.
	// Pass a null vector (regionsCount=0, regions=nil) to clear. Bounds are in window coords.
	set_draggable_regions: proc "system" (
		self: ^cef_window,
		regionsCount: c.size_t,
		regions: [^]cef_draggable_region_t,
	),

	// Platform window handle.
	get_window_handle: proc "system" (self: ^cef_window) -> cef_window_handle_t,

	// Simulate input (primarily for testing).
	send_key_press:	proc "system" (self: ^cef_window, key_code: c.int, event_flags: c.uint32_t),
	send_mouse_move: proc "system" (self: ^cef_window, screen_x: c.int, screen_y: c.int),
	send_mouse_events: proc "system" (
		self: ^cef_window,
		button: cef_mouse_button_type_t,
		mouse_down: c.int,
		mouse_up: c.int,
	),

	// Set/remove keyboard accelerators.
	set_accelerator: proc "system" (
		self: ^cef_window,
		command_id: c.int,
		key_code: c.int,
		shift_pressed: c.int,
		ctrl_pressed: c.int,
		alt_pressed: c.int,
		high_priority: c.int,
	),
	remove_accelerator:		 proc "system" (self: ^cef_window, command_id: c.int),
	remove_all_accelerators:	proc "system" (self: ^cef_window),

	// Override a standard theme color or add a custom color for |color_id|.
	set_theme_color: proc "system" (self: ^cef_window, color_id: c.int, color: cef_color),

	// Trigger OnThemeChanged for each View in this Window’s hierarchy (does not reset theme colors).
	// Do not call from window/view theme-change callbacks.
	theme_changed: proc "system" (self: ^cef_window),

	// Runtime style for this Window (ALLOY or CHROME).
	get_runtime_style: proc "system" (self: ^cef_window) -> cef_runtime_style_t,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Create a new Window.
	window_create_top_level :: proc "system" (delegate: ^cef_window_delegate) -> ^cef_window ---
}
