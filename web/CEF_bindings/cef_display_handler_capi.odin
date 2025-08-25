package odin_cef

import "core:c"

/// Implement this structure to handle events related to browser display state. The functions of this structure will be called on the UI thread.
/// NOTE: This struct is allocated client-side.
Display_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when a frame's address has changed.
	on_address_change: proc "system" (self: ^Display_handler, browser: ^Browser, frame: ^Frame, url: ^cef_string),

	/// Called when the page title changes.
	on_title_change: proc "system" (self: ^Display_handler, browser: ^Browser, title: ^cef_string),

	/// Called when the page icon changes.
	on_favicon_urlchange: proc "system" (self: ^Display_handler, browser: ^Browser, icon_urls: string_list),

	/// Called when web content in the page has toggled fullscreen mode. If |fullscreen| is true (1) the content will automatically be sized to fill
	/// the browser content area. If |fullscreen| is false (0) the content will
	/// automatically return to its original size and position. With Alloy style
	/// the client is responsible for triggering the fullscreen transition (for
	/// example, by calling window::set_fullscreen when using Views). With
	/// Chrome style the fullscreen transition will be triggered automatically.
	/// The window_delegate::on_window_fullscreen_transition function will be
	/// called during the fullscreen transition for notification purposes.
	on_fullscreen_mode_change: proc "system" (self: ^Display_handler, browser: ^Browser, fullscreen: b32),

	/// Called when the browser is about to display a tooltip. |text| contains the text that will be displayed in the tooltip. To handle the display of the
	/// tooltip yourself return true (1). Otherwise, you can optionally modify
	/// |text| and then return false (0) to allow the browser to display the
	/// tooltip. When window rendering is disabled the application is responsible
	/// for drawing tooltips and the return value is ignored.
	on_tooltip: proc "system" (self: ^Display_handler, browser: ^Browser, text: ^cef_string) -> b32,

	/// Called when the browser receives a status message. |value| contains the text that will be displayed in the status message.
	on_status_message: proc "system" (self: ^Display_handler, browser: ^Browser, value: ^cef_string),

	/// Called to display a console message. Return true (1) to stop the message from being output to the console.
	on_console_message: proc "system" (self: ^Display_handler, browser: ^Browser, level: Log_severity, message: ^cef_string, source: ^cef_string, line: c.int) -> b32,

	/// Called when auto-resize is enabled via Browser_host::set_auto_resize_enabled and the contents have auto-
	/// resized. |new_size| will be the desired size in DIP coordinates. Return
	/// true (1) if the resize was handled or false (0) for default handling.
	on_auto_resize: proc "system" (self: ^Display_handler, browser: ^Browser, new_size: ^cef_size) -> b32,

	/// Called when the overall page loading progress has changed. |progress| ranges from 0.0 to 1.0.
	on_loading_progress_change: proc "system" (self: ^Display_handler, browser: ^Browser, progress: f64),

	/// Called when the browser's cursor has changed. If |type| is CT_CUSTOM then |custom_cursor_info| will be populated with the custom cursor information.
	/// Return true (1) if the cursor change was handled or false (0) for default
	/// handling.
	on_cursor_change: proc "system" (self: ^Display_handler, browser: ^Browser, cursor: Cursor_handle, type: Cursor_type, custom_cursor_info: ^Cursor_info) -> b32,

	/// Called when the browser's access to an audio and/or video source has changed.
	on_media_access_change: proc "system" (self: ^Display_handler, browser: ^Browser, has_video_access: b32, has_audio_access: b32),

	/// Called when JavaScript is requesting new bounds via window.moveTo/By() or window.resizeTo/By(). |new_bounds| are in DIP screen coordinates.
	/// With Views-hosted browsers |new_bounds| are the desired bounds for the containing window and may be passed directly to
	/// window::set_bounds. With external (client-provided) parent on macOS
	/// and Windows |new_bounds| are the desired frame bounds for the containing
	/// root window. With other non-Views browsers |new_bounds| are the desired
	/// bounds for the browser content only unless the client implements either
	/// Display_handler::get_root_window_screen_rect for windowed browsers or
	/// Render_handler::get_window_screen_rect for windowless browsers. Clients
	/// may expand browser content bounds to window bounds using OS-specific or
	/// display functions.
	/// Return true (1) if this function was handled or false (0) for default handling. Default move/resize behavior is only provided with Views-hosted
	/// Chrome style browsers.
	on_contents_bounds_change: proc "system" (self: ^Display_handler, browser: ^Browser, new_bounds: ^cef_rect) -> b32,

	/// Called to retrieve the external (client-provided) root window rectangle in screen DIP coordinates. Only called for windowed browsers on Windows and
	/// Linux. Return true (1) if the rectangle was provided. Return false (0) to
	/// use the root window bounds on Windows or the browser content bounds on
	/// Linux. For additional usage details see
	/// Browser_host::notify_screen_info_changed.
	get_root_window_screen_rect: proc "system" (self: ^Display_handler, browser: ^Browser, rect: ^cef_rect) -> b32,
} 