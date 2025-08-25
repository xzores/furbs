package odin_cef

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

import "core:c"

// -----------------------------------------------------------------------------
// Browser
// -----------------------------------------------------------------------------
// Structure used to represent a browser. When used in the browser process the
// functions of this structure may be called on any thread unless otherwise
// indicated in the comments. When used in the render process the functions of
// this structure may only be called on the main thread.
//
// NOTE: The original C struct is allocated DLL-side.
// -----------------------------------------------------------------------------
Browser :: struct {
	// Base structure.
	base: base_ref_counted,

	// True if this object is currently valid. This will return false (0) after
	// life_span_handler.OnBeforeClose is called.
	is_valid: proc "system" (self: ^Browser) -> c.int,

	// Returns the browser host object. Browser process only.
	get_host: proc "system" (self: ^Browser) -> ^Browser_host,

	// Returns true (1) if the browser can navigate backwards.
	can_go_back: proc "system" (self: ^Browser) -> c.int,
	// Navigate backwards.
	go_back: proc "system" (self: ^Browser),

	// Returns true (1) if the browser can navigate forwards.
	can_go_forward: proc "system" (self: ^Browser) -> c.int,
	// Navigate forwards.
	go_forward: proc "system" (self: ^Browser),

	// Returns true (1) if the browser is currently loading.
	is_loading: proc "system" (self: ^Browser) -> c.int,

	// Reload the current page.
	reload: proc "system" (self: ^Browser),

	// Reload the current page ignoring any cached data.
	reload_ignore_cache: proc "system" (self: ^Browser),

	// Stop loading the page.
	stop_load: proc "system" (self: ^Browser),

	// Returns the globally unique identifier for this browser. This value is
	// also used as the tabId for extension APIs.
	get_identifier: proc "system" (self: ^Browser) -> c.int,

	// Returns true (1) if this object is pointing to the same handle as |that|.
	is_same: proc "system" (self: ^Browser, that: ^Browser) -> c.int,

	// Returns true (1) if the browser is a popup.
	is_popup: proc "system" (self: ^Browser) -> c.int,

	// Returns true (1) if a document has been loaded in the browser.
	has_document: proc "system" (self: ^Browser) -> c.int,

	// Returns the main (top-level) frame for the browser.
	// Browser process: valid until after life_span_handler.OnBeforeClose.
	// Renderer process: may return NULL if main frame is hosted in a different
	// renderer process (e.g. cross-origin sub-frames). The main frame object
	// can change during cross-origin navigation or re-navigation after renderer
	// process termination (crash, etc).
	get_main_frame: proc "system" (self: ^Browser) -> ^Frame,

	// Returns the focused frame for the browser.
	get_focused_frame: proc "system" (self: ^Browser) -> ^Frame,

	// Returns the frame with the specified identifier, or NULL if not found.
	get_frame_by_identifier: proc "system" (self: ^Browser, identifier: ^cef_string) -> ^Frame,

	// Returns the frame with the specified name, or NULL if not found.
	get_frame_by_name: proc "system" (self: ^Browser, name: ^cef_string) -> ^Frame,

	// Returns the number of frames that currently exist.
	get_frame_count: proc "system" (self: ^Browser) -> c.size_t,

	// Returns the identifiers of all existing frames.
	get_frame_identifiers: proc "system" (self: ^Browser, identifiers: string_list),

	// Returns the names of all existing frames.
	get_frame_names: proc "system" (self: ^Browser, names: string_list),
}

// -----------------------------------------------------------------------------
// Run_file_dialog_callback
// -----------------------------------------------------------------------------
// Callback structure for Browser_host.run_file_dialog.
// The function will be called on the browser process UI thread.
// NOTE: The original C struct is allocated client-side.
// -----------------------------------------------------------------------------
Run_file_dialog_callback :: struct {
	base: base_ref_counted,

	// Called asynchronously after the file dialog is dismissed. |file_paths|
	// will be a single value or a list of values depending on the dialog mode.
	// If the selection was cancelled |file_paths| will be NULL.
	on_file_dialog_dismissed: proc "system" (self: ^Run_file_dialog_callback, file_paths: string_list),
}

// -----------------------------------------------------------------------------
// Navigation_entry_visitor
// -----------------------------------------------------------------------------
// Callback structure for Browser_host.get_navigation_entries.
// The function will be called on the browser process UI thread.
// NOTE: The original C struct is allocated client-side.
// -----------------------------------------------------------------------------
Navigation_entry_visitor :: struct {
	base: base_ref_counted,

	// Method that will be executed. Do not keep a reference to |entry| outside
	// of this callback. Return true (1) to continue visiting entries or false
	// (0) to stop. |current| is true (1) if this entry is the currently loaded
	// navigation entry. |index| is the 0-based index of this entry and |total|
	// is the total number of entries.
	visit: proc "system" (
		self: ^Navigation_entry_visitor,
		entry: ^Navigation_entry,
		current: c.int,
		index: c.int,
		total: c.int,
	) -> c.int,
}

// -----------------------------------------------------------------------------
// Pdf_print_callback
// -----------------------------------------------------------------------------
// Callback structure for Browser_host.print_to_pdf.
// The function will be called on the browser process UI thread.
// NOTE: The original C struct is allocated client-side.
// -----------------------------------------------------------------------------
Pdf_print_callback :: struct {
	base: base_ref_counted,

	// Method that will be executed when the PDF printing has completed. |path|
	// is the output path. |ok| will be true (1) if printing completed
	// successfully or false (0) otherwise.
	on_pdf_print_finished: proc "system" (self: ^Pdf_print_callback, path: ^cef_string, ok: c.int),
}

// -----------------------------------------------------------------------------
// Download_image_callback
// -----------------------------------------------------------------------------
// Callback structure for Browser_host.download_image.
// The function will be called on the browser process UI thread.
// NOTE: The original C struct is allocated client-side.
// -----------------------------------------------------------------------------
Download_image_callback :: struct {
	base: base_ref_counted,

	// Method that will be executed when the image download has completed.
	// |image_url| is the URL that was downloaded and |http_status_code| is the
	// resulting HTTP status code. |image| is the resulting image, possibly at
	// multiple scale factors, or NULL if the download failed.
	on_download_image_finished: proc "system" (
		self: ^Download_image_callback,
		image_url: ^cef_string,
		http_status_code: c.int,
		image: ^Image,
	),
}

// -----------------------------------------------------------------------------
// Browser_host
// -----------------------------------------------------------------------------
// Structure used to represent the browser process aspects of a browser.
// The functions of this structure can only be called in the browser process.
// They may be called on any thread in that process unless otherwise indicated.
// NOTE: The original C struct is allocated DLL-side.
// -----------------------------------------------------------------------------
Browser_host :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns the hosted browser object.
	get_browser: proc "system" (self: ^Browser_host) -> ^Browser,

	// Request that the browser close. Closing a browser is a multi-stage process
	// that may complete either synchronously or asynchronously, and involves
	// callbacks such as life_span_handler.DoClose (Alloy style only),
	// life_span_handler.OnBeforeClose, and a top-level window close handler
	// (e.g. window_delegate.CanClose or platform-specific equivalent).
	// Using try_close_browser() instead of close_browser() is recommended for
	// most use cases. See life_span_handler.do_close() docs for details.
	//
	// If |force_close| is false (0) JavaScript unload handlers, if any, may be
	// fired and the close may be delayed or canceled by the user. If
	// |force_close| is true (1) the user will not be prompted and close proceeds
	// immediately (possibly asynchronously).
	//
	// If close is delayed and not canceled the default behavior is to call the
	// top-level window close handler once the browser is ready to be closed.
	// This can be changed for Alloy style by implementing do_close(). Use
	// is_ready_to_be_closed() on the UI thread to detect mandatory close events.
	close_browser: proc "system" (self: ^Browser_host, force_close: c.int),

	// Helper for closing a browser. Similar to close_browser(false) but returns
	// a boolean indicating immediate close status. Call from a top-level window
	// close handler and return the result to indicate if the window should
	// proceed closing. Returns false (0) if close will be delayed (e.g. unload
	// handlers pending) or true (1) if close will proceed immediately (possibly
	// asynchronously). Must be called on the UI thread.
	try_close_browser: proc "system" (self: ^Browser_host) -> c.int,

	// Returns true (1) if the browser is ready to be closed (close initiated and
	// unload handlers have executed or should be ignored). Use from top-level
	// window close handlers to distinguish cancelable vs mandatory close events.
	// Must be called on the UI thread.
	is_ready_to_be_closed: proc "system" (self: ^Browser_host) -> c.int,

	// Set whether the browser is focused.
	set_focus: proc "system" (self: ^Browser_host, focus: c.int),

	// Retrieve the window handle (if any) for this browser. If this browser is
	// wrapped in a Browser_view call on the UI thread to get the top-level
	// native window handle.
	get_window_handle: proc "system" (self: ^Browser_host) -> Window_handle,

	// Retrieve the window handle (if any) of the browser that opened this
	// browser. Returns NULL for non-popup browsers or if wrapped in a
	// Browser_view. Useful for custom modal handling.
	get_opener_window_handle: proc "system" (self: ^Browser_host) -> Window_handle,

	// Retrieve the unique identifier of the browser that opened this browser.
	// Returns 0 for non-popup browsers.
	get_opener_identifier: proc "system" (self: ^Browser_host) -> c.int,

	// Returns true (1) if this browser is wrapped in a Browser_view.
	has_view: proc "system" (self: ^Browser_host) -> c.int,

	// Returns the client for this browser.
	get_client: proc "system" (self: ^Browser_host) -> ^Client,

	// Returns the request context for this browser.
	get_request_context: proc "system" (self: ^Browser_host) -> ^Request_context,

	// Returns true (1) if this browser can execute the specified zoom command.
	// UI thread only.
	can_zoom: proc "system" (self: ^Browser_host, command: Zoom_command) -> c.int,

	// Execute a zoom command. If called on the UI thread the change is immediate;
	// otherwise it will be applied asynchronously on the UI thread.
	zoom: proc "system" (self: ^Browser_host, command: Zoom_command),

	// Get the default zoom level. UI thread only.
	get_default_zoom_level: proc "system" (self: ^Browser_host) -> f64,

	// Get the current zoom level. UI thread only.
	get_zoom_level: proc "system" (self: ^Browser_host) -> f64,

	// Change the zoom level to the specified value. Specify 0.0 to reset to
	// default. If called on the UI thread the change is immediate; otherwise it
	// will be applied asynchronously on the UI thread.
	set_zoom_level: proc "system" (self: ^Browser_host, zoomLevel: f64),

	// Call to run a file chooser dialog. Only a single file chooser may be
	// pending at a time. |mode| is the dialog type. |title| is the dialog title
	// (NULL for default). |default_file_path| is initially selected path.
	// |accept_filters| restricts selectable file types and may include:
	// (a) lower-cased MIME types ("text/*", "image/*"),
	// (b) file extensions (".txt", ".png"),
	// (c) "Description|.ext1;.ext2" combos.
	// |callback| executes after dismissal or immediately if another dialog is
	// pending. Initiated asynchronously on the UI thread.
	run_file_dialog: proc "system" (
		self: ^Browser_host,
		mode: File_dialog_mode,
		title: ^cef_string,
		default_file_path: ^cef_string,
		accept_filters: string_list,
		callback: ^Run_file_dialog_callback,
	),

	// Download the file at |url| using Download_handler.
	start_download: proc "system" (self: ^Browser_host, url: ^cef_string),

	// Download |image_url| and execute |callback| on completion with images
	// received from the renderer. If |is_favicon| is true (1) then cookies are
	// not sent/accepted. Images with DIP size > |max_image_size| are filtered.
	// Versions at different scale factors may be downloaded up to the system
	// maximum. If no images <= |max_image_size| then the smallest image is
	// resized to |max_image_size| and returned as the only result. 0 means
	// unlimited. If |bypass_cache| is true (1) the URL is requested from server
	// even if present in cache.
	download_image: proc "system" (
		self: ^Browser_host,
		image_url: ^cef_string,
		is_favicon: c.int,
		max_image_size: u32,
		bypass_cache: c.int,
		callback: ^Download_image_callback,
	),

	// Print the current browser contents.
	print: proc "system" (self: ^Browser_host),

	// Print the current browser contents to the PDF file at |path| and execute
	// |callback| on completion. Caller deletes |path| when done. On Linux you
	// must implement Print_handler.get_pdf_paper_size for PDF printing.
	print_to_pdf: proc "system" (
		self: ^Browser_host,
		path: ^cef_string,
		settings: ^Pdf_print_settings,
		callback: ^Pdf_print_callback,
	),

	// Search for |searchText|. |forward| searches forward/backward. |matchCase|
	// toggles case-sensitivity. |findNext| indicates first vs follow-up search.
	// Search restarts if |searchText| or |matchCase| change. Search stops if
	// |searchText| is NULL. If client provides Find_handler via Client.get_find_handler,
	// it will receive find results.
	find: proc "system" (
		self: ^Browser_host,
		searchText: ^cef_string,
		forward: c.int,
		matchCase: c.int,
		findNext: c.int,
	),

	// Cancel all active searches.
	stop_finding: proc "system" (self: ^Browser_host, clearSelection: c.int),

	// Open DevTools in its own browser. If already open it will be focused and
	// |windowInfo|, |client|, |settings| are ignored. If |inspect_element_at| is
	// non-NULL the element at (x,y) will be inspected. |windowInfo| is ignored
	// if this browser is wrapped in a Browser_view.
	show_dev_tools: proc "system" (
		self: ^Browser_host,
		windowInfo: ^Window_info,
		client: ^Client,
		settings: ^Browser_settings,
		inspect_element_at: ^cef_point,
	),

	// Explicitly close the associated DevTools browser, if any.
	close_dev_tools: proc "system" (self: ^Browser_host),

	// Returns true (1) if an associated DevTools browser exists. UI thread only.
	has_dev_tools: proc "system" (self: ^Browser_host) -> c.int,

	// Send a DevTools protocol function call message. |message| must be a UTF8
	// JSON dict containing "id" (int), "function" (string) and optional "params"
	// (dict). Returns true (1) if called on UI thread and submitted for
	// validation; false (0) otherwise. Validation is async; malformed messages
	// may be discarded without notification. Prefer execute_dev_tools_method for
	// structured formatting.
	//
	// Every valid function call yields an async function result or error message
	// referencing the sent "id". Events are received while notifications are
	// enabled (e.g. between "Page.enable" and "Page.disable"). All messages are
	// delivered to observers added via add_dev_tools_message_observer.
	//
	// Does not require an active DevTools front-end or remote-debugging
	// session. Other sessions continue to function independently; global state
	// changes may not reflect in other UIs. Communication can be logged via
	// `--devtools-protocol-log-file=<path>`.
	send_dev_tools_message: proc "system" (self: ^Browser_host, message: rawptr, message_size: c.size_t) -> c.int,

	// Execute a DevTools protocol function call (structured). |message_id| is a
	// unique incremental id (0 for auto-assign). |method| is the function name.
	// |params| are optional parameters. Returns assigned id if called on UI
	// thread and submitted for validation, otherwise 0.
	execute_dev_tools_method: proc "system" (
		self: ^Browser_host,
		message_id: c.int,
		method: ^cef_string,
		params: ^cef_dictionary_value,
	) -> c.int,

	// Add an observer for DevTools protocol messages (results and events). The
	// observer remains registered until the returned Registration is destroyed.
	add_dev_tools_message_observer: proc "system" (self: ^Browser_host, observer: ^Dev_tools_message_observer) -> ^Registration,

	// Retrieve a snapshot of current navigation entries. If |current_only| is
	// true (1) only the current entry is sent; otherwise all entries are sent.
	get_navigation_entries: proc "system" (self: ^Browser_host, visitor: ^Navigation_entry_visitor, current_only: c.int),

	// If a misspelled word is currently selected in an editable node, replace
	// it with the specified |word|.
	replace_misspelling: proc "system" (self: ^Browser_host, word: ^cef_string),

	// Add the specified |word| to the spelling dictionary.
	add_word_to_dictionary: proc "system" (self: ^Browser_host, word: ^cef_string),

	// Returns true (1) if window rendering is disabled.
	is_window_rendering_disabled: proc "system" (self: ^Browser_host) -> c.int,

	// Notify that the widget has been resized. The browser will call
	// Render_handler.get_view_rect then On_paint asynchronously with updated
	// regions. Only used with window rendering disabled.
	was_resized: proc "system" (self: ^Browser_host),

	// Notify that the browser has been hidden or shown. Layout and On_paint
	// notifications stop when hidden. Only used with window rendering disabled.
	was_hidden: proc "system" (self: ^Browser_host, hidden: c.int),

	// Notify that screen information has changed. Updated info is sent to the
	// renderer for CSS/JS metrics (deviceScaleFactor, screenX/Y, outerWidth/Height).
	// See CEF GeneralUsage.md coordinate systems notes.
	//
	// Used with:
	// (a) windowless rendering, and
	// (b) windowed rendering with external (client-provided) root window.
	//
	// Windowless: browser will call Render_handler.get_screen_info,
	// get_root_screen_rect and get_view_rect (simulates moving/resizing root or
	// changing display).
	//
	// Windowed: browser will call Display_handler.get_root_window_screen_rect
	// and use associated display properties.
	notify_screen_info_changed: proc "system" (self: ^Browser_host),

	// Invalidate the view. Browser will call Render_handler.on_paint
	// asynchronously. Only used when window rendering is disabled.
	invalidate: proc "system" (self: ^Browser_host, type: Paint_element_type),

	// Issue a BeginFrame request to Chromium. Only valid when
	// Window_info.external_begin_frame_enabled is true (1).
	send_external_begin_frame: proc "system" (self: ^Browser_host),

	// Send a key event to the browser.
	send_key_event: proc "system" (self: ^Browser_host, event: ^Key_event),

	// Send a mouse click event. Coordinates are relative to the upper-left of
	// the view.
	send_mouse_click_event: proc "system" (
		self: ^Browser_host,
		event: ^Mouse_event,
		type: mouse_button_type,
		mouseUp: c.int,
		clickCount: c.int,
	),

	// Send a mouse move event. Coordinates are relative to the upper-left of
	// the view.
	send_mouse_move_event: proc "system" (self: ^Browser_host, event: ^Mouse_event, mouseLeave: c.int),

	// Send a mouse wheel event. Coordinates are relative to the upper-left of
	// the view. |deltaX|/|deltaY| are movement deltas. To scroll inside select
	// popups with window rendering disabled implement Render_handler.get_screen_point
	// properly.
	send_mouse_wheel_event: proc "system" (self: ^Browser_host, event: ^Mouse_event, deltaX: c.int, deltaY: c.int),

	// Send a touch event for a windowless browser.
	send_touch_event: proc "system" (self: ^Browser_host, event: ^Touch_event),

	// Send a capture lost event to the browser.
	send_capture_lost_event: proc "system" (self: ^Browser_host),

	// Notify that the window hosting the browser is about to be moved or resized.
	// Windows and Linux only.
	notify_move_or_resize_started: proc "system" (self: ^Browser_host),

	// Returns the maximum FPS that Render_handler.on_paint will be called for a
	// windowless browser. Actual FPS may be lower. Min 1, Max 60 (default 30).
	// UI thread only.
	get_windowless_frame_rate: proc "system" (self: ^Browser_host) -> c.int,

	// Set the maximum FPS for Render_handler.on_paint with windowless rendering.
	// Min 1, Max 60 (default 30). Can also be set at creation via
	// Browser_settings.windowless_frame_rate.
	set_windowless_frame_rate: proc "system" (self: ^Browser_host, frame_rate: c.int),

	// Begins/updates IME composition. |text| optional inserted text.
	// |underlines| optional underlined ranges. |replacement_range| optional
	// existing text range to replace. |selection_range| optional selection range
	// after insertion/replacement. May be called multiple times as composition
	// changes. When done call ime_cancel_composition or ime_commit_text /
	// ime_finish_composing_text. Only used with window rendering disabled.
	ime_set_composition: proc "system" (
		self: ^Browser_host,
		text: ^cef_string,
		underlinesCount: c.size_t,
		underlines: ^Composition_underline,
		replacement_range: ^cef_range,
		selection_range: ^cef_range,
	),

	// Completes composition by optionally inserting |text|. |replacement_range|
	// optional existing text to replace. |relative_cursor_pos| positions cursor
	// relative to current position. Only used on macOS for those values.
	// Windowless only.
	ime_commit_text: proc "system" (
		self: ^Browser_host,
		text: ^cef_string,
		replacement_range: ^cef_range,
		relative_cursor_pos: c.int,
	),

	// Completes composition by applying the current composition node contents.
	// If |keep_selection| is false (0) any selection is discarded. Windowless only.
	ime_finish_composing_text: proc "system" (self: ^Browser_host, keep_selection: c.int),

	// Cancels composition and discards composition node contents. Windowless only.
	ime_cancel_composition: proc "system" (self: ^Browser_host),

	// Drag-and-drop (windowless):
	// Call when mouse enters view during a drag. |drag_data| should NOT contain
	// file contents (remove via Drag_data.reset_file_contents if needed).
	drag_target_drag_enter: proc "system" (
		self: ^Browser_host,
		drag_data: ^Drag_data,
		event: ^Mouse_event,
		allowed_ops: Drag_operations_mask,
	),

	// Call while mouse moves during drag (after enter, before leave/drop).
	drag_target_drag_over: proc "system" (self: ^Browser_host, event: ^Mouse_event, allowed_ops: Drag_operations_mask),

	// Call when mouse leaves the view (after enter).
	drag_target_drag_leave: proc "system" (self: ^Browser_host),

	// Call when user drops (after enter). The object being dropped is the same
	// |drag_data| passed to drag_target_drag_enter.
	drag_target_drop: proc "system" (self: ^Browser_host, event: ^Mouse_event),

	// Call when drag started by Render_handler.start_dragging has ended (drop or
	// cancel). If the web view is both source and target, call all DragTarget*
	// before DragSource* methods. Windowless only.
	drag_source_ended_at: proc "system" (self: ^Browser_host, x: c.int, y: c.int, op: Drag_operations_mask),

	// Call when drag started by Render_handler.start_dragging has completed. May
	// be called immediately to cancel (without calling drag_source_ended_at).
	// If both source and target, call all DragTarget* before DragSource*.
	// Windowless only.
	drag_source_system_drag_ended: proc "system" (self: ^Browser_host),

	// Returns the current visible navigation entry. UI thread only.
	get_visible_navigation_entry: proc "system" (self: ^Browser_host) -> ^Navigation_entry,

	// Set accessibility state for all frames. If State.Default then accessibility
	// is disabled by default and can be controlled via command-line switches
	// ("force-renderer-accessibility"/"disable-renderer-accessibility"). If
	// State.Enabled then accessibility is enabled. If State.Disabled then it is
	// completely disabled.
	//
	// Windowed browsers: Enabled in Complete mode (Chromium kAccessibilityModeComplete)
	// and Chromium manages platform accessibility objects.
	//
	// Windowless browsers: Enabled in TreeOnly mode (Chromium kAccessibilityModeWebContentsOnly).
	// Renderer accessibility is enabled; full tree computed; events delivered to
	// Accessibility_handler; platform accessibility objects are not created.
	set_accessibility_state: proc "system" (self: ^Browser_host, accessibility_state: State),

	// Enable notifications of auto resize via Display_handler.on_auto_resize.
	// Disabled by default. |min_size| and |max_size| define allowed range.
	set_auto_resize_enabled: proc "system" (
		self: ^Browser_host,
		enabled: c.int,
		min_size: ^cef_size,
		max_size: ^cef_size,
	),

	// Set whether the browser's audio is muted.
	set_audio_muted: proc "system" (self: ^Browser_host, mute: c.int),

	// Returns true (1) if the browser's audio is muted. UI thread only.
	is_audio_muted: proc "system" (self: ^Browser_host) -> c.int,

	// Returns true (1) if the renderer is currently in browser fullscreen (via
	// JS Fullscreen API). UI thread only.
	is_fullscreen: proc "system" (self: ^Browser_host) -> c.int,

	// Request exit from browser fullscreen. With Alloy style call in response to
	// user action (e.g. macOS green button via window_delegate.on_window_fullscreen_transition
	// or ESC via keyboard_handler.on_pre_key_event). With Chrome style standard
	// exit actions are handled internally; new user actions can call this.
	// Set |will_cause_resize| true (1) if exiting will cause a view resize.
	exit_fullscreen: proc "system" (self: ^Browser_host, will_cause_resize: c.int),

	// Returns true (1) if a Chrome command is supported and enabled. Use a
	// version-safe mapping of command IDC names to numeric ids. UI thread only.
	// Chrome style only.
	can_execute_chrome_command: proc "system" (self: ^Browser_host, command_id: c.int) -> c.int,

	// Execute a Chrome command. |disposition| indicates intended command target.
	// Chrome style only.
	execute_chrome_command: proc "system" (self: ^Browser_host, command_id: c.int, disposition: Window_open_disposition),

	// Returns true (1) if the render process is currently unresponsive, indicated
	// by lack of input processing for at least 15 seconds. To receive state
	// change notifications and optionally handle it, implement
	// Request_handler.on_render_process_unresponsive. UI thread only.
	is_render_process_unresponsive: proc "system" (self: ^Browser_host) -> c.int,

	// Returns the runtime style for this browser (ALLOY or CHROME).
	get_runtime_style: proc "system" (self: ^Browser_host) -> Runtime_style,
}

// -----------------------------------------------------------------------------
// Browser creation helpers
// -----------------------------------------------------------------------------
@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Create a new browser using the window parameters specified by |windowInfo|.
	// All values are copied internally and the actual window (if any) is created
	// on the UI thread. If |request_context| is NULL the global request context
	// will be used. Can be called on any browser process thread and will not
	// block. Optional |extra_info| specifies extra information specific to the
	// created browser that is passed to render_process_handler.on_browser_created
	// in the render process.
	browser_host_create_browser :: proc (
		windowInfo: ^Window_info,
		client: ^Client,
		url: ^cef_string,
		settings: ^Browser_settings,
		extra_info: ^cef_dictionary_value,
		request_context: ^Request_context,
	) -> c.int ---

	// Create a new browser using the window parameters specified by |windowInfo|.
	// If |request_context| is NULL the global request context will be used.
	// Can only be called on the browser process UI thread. Optional |extra_info|
	// specifies extra information specific to the created browser that is passed
	// to render_process_handler.on_browser_created in the render process.
	browser_host_create_browser_sync :: proc (
		windowInfo: ^Window_info,
		client: ^Client,
		url: ^cef_string,
		settings: ^Browser_settings,
		extra_info: ^cef_dictionary_value,
		request_context: ^Request_context,
	) -> ^Browser ---

	// Returns the browser (if any) with the specified identifier.
	browser_host_get_browser_by_identifier :: proc (browser_id: c.int) -> ^Browser ---
}
