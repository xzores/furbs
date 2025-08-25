package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Supports creation and modification of menus. Use MENU_ID_USER_FIRST..MENU_ID_USER_LAST for custom IDs.
// Accessible only on the browser process UI thread.
// NOTE: This struct is allocated DLL-side.
Menu_model :: struct {
	// Base structure.
	base: base_ref_counted,

	// True if this menu is a submenu.
	is_sub_menu: proc "system" (self: ^Menu_model) -> c.int,

	// Clear the menu. Returns 1 on success.
	clear: proc "system" (self: ^Menu_model) -> c.int,

	// Number of items in this menu.
	get_count: proc "system" (self: ^Menu_model) -> c.size_t,

	// Add items.
	add_separator:  proc "system" (self: ^Menu_model) -> c.int,
	add_item:       proc "system" (self: ^Menu_model, command_id: c.int, label: ^cef_string) -> c.int,
	add_check_item: proc "system" (self: ^Menu_model, command_id: c.int, label: ^cef_string) -> c.int,
	add_radio_item: proc "system" (self: ^Menu_model, command_id: c.int, label: ^cef_string, group_id: c.int) -> c.int,
	add_sub_menu:   proc "system" (self: ^Menu_model, command_id: c.int, label: ^cef_string) -> ^Menu_model,

	// Insert items at index.
	insert_separator_at:  proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	insert_item_at:       proc "system" (self: ^Menu_model, index: c.size_t, command_id: c.int, label: ^cef_string) -> c.int,
	insert_check_item_at: proc "system" (self: ^Menu_model, index: c.size_t, command_id: c.int, label: ^cef_string) -> c.int,
	insert_radio_item_at: proc "system" (self: ^Menu_model, index: c.size_t, command_id: c.int, label: ^cef_string, group_id: c.int) -> c.int,
	insert_sub_menu_at:   proc "system" (self: ^Menu_model, index: c.size_t, command_id: c.int, label: ^cef_string) -> ^Menu_model,

	// Remove by command_id or index.
	remove:    proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	remove_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,

	// Lookups.
	get_index_of:     proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	get_command_id_at:proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	set_command_id_at:proc "system" (self: ^Menu_model, index: c.size_t, command_id: c.int) -> c.int,

	// Labels (free returned strings with cef_string_userfree_free).
	get_label:    proc "system" (self: ^Menu_model, command_id: c.int) -> cef_string_userfree,
	get_label_at: proc "system" (self: ^Menu_model, index: c.size_t) -> cef_string_userfree,
	set_label:    proc "system" (self: ^Menu_model, command_id: c.int, label: ^cef_string) -> c.int,
	set_label_at: proc "system" (self: ^Menu_model, index: c.size_t, label: ^cef_string) -> c.int,

	// Item type.
	get_type:    proc "system" (self: ^Menu_model, command_id: c.int) -> Menu_item_type,
	get_type_at: proc "system" (self: ^Menu_model, index: c.size_t) -> Menu_item_type,

	// Group IDs.
	get_group_id:    proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	get_group_id_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	set_group_id:    proc "system" (self: ^Menu_model, command_id: c.int, group_id: c.int) -> c.int,
	set_group_id_at: proc "system" (self: ^Menu_model, index: c.size_t, group_id: c.int) -> c.int,

	// Submenus.
	get_sub_menu:    proc "system" (self: ^Menu_model, command_id: c.int) -> ^Menu_model,
	get_sub_menu_at: proc "system" (self: ^Menu_model, index: c.size_t) -> ^Menu_model,

	// Visibility.
	is_visible:    proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	is_visible_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	set_visible:   proc "system" (self: ^Menu_model, command_id: c.int, visible: c.int) -> c.int,
	set_visible_at:proc "system" (self: ^Menu_model, index: c.size_t, visible: c.int) -> c.int,

	// Enabled.
	is_enabled:    proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	is_enabled_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	set_enabled:   proc "system" (self: ^Menu_model, command_id: c.int, enabled: c.int) -> c.int,
	set_enabled_at:proc "system" (self: ^Menu_model, index: c.size_t, enabled: c.int) -> c.int,

	// Checked (check/radio items).
	is_checked:    proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	is_checked_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	set_checked:   proc "system" (self: ^Menu_model, command_id: c.int, checked: c.int) -> c.int,
	set_checked_at:proc "system" (self: ^Menu_model, index: c.size_t, checked: c.int) -> c.int,

	// Keyboard accelerators.
	has_accelerator:    proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	has_accelerator_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	set_accelerator:    proc "system" (self: ^Menu_model, command_id: c.int, key_code: c.int, shift_pressed: c.int, ctrl_pressed: c.int, alt_pressed: c.int) -> c.int,
	set_accelerator_at: proc "system" (self: ^Menu_model, index: c.size_t, key_code: c.int, shift_pressed: c.int, ctrl_pressed: c.int, alt_pressed: c.int) -> c.int,
	remove_accelerator: proc "system" (self: ^Menu_model, command_id: c.int) -> c.int,
	remove_accelerator_at: proc "system" (self: ^Menu_model, index: c.size_t) -> c.int,
	get_accelerator:    proc "system" (self: ^Menu_model, command_id: c.int, key_code: ^c.int, shift_pressed: ^c.int, ctrl_pressed: ^c.int, alt_pressed: ^c.int) -> c.int,
	get_accelerator_at: proc "system" (self: ^Menu_model, index: c.size_t, key_code: ^c.int, shift_pressed: ^c.int, ctrl_pressed: ^c.int, alt_pressed: ^c.int) -> c.int,

	// Colors.
	set_color:    proc "system" (self: ^Menu_model, command_id: c.int, color_type: Menu_color_type, color: cef_color) -> c.int,
	set_color_at: proc "system" (self: ^Menu_model, index: c.int, color_type: Menu_color_type, color: cef_color) -> c.int,
	get_color:    proc "system" (self: ^Menu_model, command_id: c.int, color_type: Menu_color_type, color: ^cef_color) -> c.int,
	get_color_at: proc "system" (self: ^Menu_model, index: c.int, color_type: Menu_color_type, color: ^cef_color) -> c.int,

	// Fonts (description format: "<FAMILY_LIST>,[STYLES] <SIZE>px").
	set_font_list:    proc "system" (self: ^Menu_model, command_id: c.int, font_list: ^cef_string) -> c.int,
	set_font_list_at: proc "system" (self: ^Menu_model, index: c.int, font_list: ^cef_string) -> c.int,
}


/// Create a new MenuModel with the specified |delegate|.
@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	menu_model_create :: proc "system" (delegate: ^Menu_model_delegate) -> ^Menu_model ---
}
