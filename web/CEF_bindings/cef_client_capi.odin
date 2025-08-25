package odin_cef

import "core:c"


/// Implement this structure to provide handler implementations.
/// NOTE: This struct is allocated client-side.
Client :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Return the handler for audio rendering events.
	get_audio_handler: proc "system" (self: ^Client) -> ^Audio_handler,

	/// Return the handler for commands. If no handler is provided the default implementation will be used.
	get_command_handler: proc "system" (self: ^Client) -> ^Command_handler,

	/// Return the handler for context menus. If no handler is provided the default implementation will be used.
	get_context_menu_handler: proc "system" (self: ^Client) -> ^Context_menu_handler,

	/// Return the handler for dialogs. If no handler is provided the default implementation will be used.
	get_dialog_handler: proc "system" (self: ^Client) -> ^Dialog_handler,

	/// Return the handler for browser display state events.
	get_Display_handler: proc "system" (self: ^Client) -> ^Display_handler,

	/// Return the handler for download events. If no handler is returned downloads will not be allowed.
	get_Download_handler: proc "system" (self: ^Client) -> ^Download_handler,

	/// Return the handler for drag events.
	get_drag_handler: proc "system" (self: ^Client) -> ^Drag_handler,

	/// Return the handler for find result events.
	get_find_handler: proc "system" (self: ^Client) -> ^Find_handler,

	/// Return the handler for focus events.
	get_focus_handler: proc "system" (self: ^Client) -> ^Focus_handler,

	/// Return the handler for events related to frame lifespan. This function will be called once during browser creation and the result
	/// will be cached for performance reasons.
	get_frame_handler: proc "system" (self: ^Client) -> ^Frame_handler,

	/// Return the handler for permission requests.
	get_permission_handler: proc "system" (self: ^Client) -> ^Permission_handler,

	/// Return the handler for JavaScript dialogs. If no handler is provided the default implementation will be used.
	get_jsdialog_handler: proc "system" (self: ^Client) -> ^Jsdialog_handler,

	/// Return the handler for keyboard events.
	get_keyboard_handler: proc "system" (self: ^Client) -> ^Keyboard_handler,

	/// Return the handler for browser life span events.
	get_life_span_handler: proc "system" (self: ^Client) -> ^Life_span_handler,

	/// Return the handler for browser load status events.
	get_load_handler: proc "system" (self: ^Client) -> ^Load_handler,

	/// Return the handler for printing on Linux. If a print handler is not provided then printing will not be supported on the Linux platform.
	get_print_handler: proc "system" (self: ^Client) -> ^Print_handler,

	/// Return the handler for off-screen rendering events.
	get_render_handler: proc "system" (self: ^Client) -> ^Render_handler,

	/// Return the handler for browser request events.
	get_request_handler: proc "system" (self: ^Client) -> ^Request_handler,

	/// Called when a new message is received from a different process. Return true (1) if the message was handled or false (0) otherwise. Do not
	/// keep a reference to |message| outside of this callback.
	on_process_message_received: proc "system" (self: ^Client, browser: ^Browser, frame: ^Frame, source_process: cef_process_id, message: ^Process_message) -> b32,
} 