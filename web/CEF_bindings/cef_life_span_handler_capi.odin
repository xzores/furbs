package odin_cef

import "core:c"

/// Implement this structure to handle events related to browser lifespan. The functions of this structure will be called on the UI thread unless otherwise
/// indicated.
/// NOTE: This struct is allocated client-side.
Life_span_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called on the UI thread before a new popup browser is created. The |browser| and |frame| values represent the source of the popup request
	/// (opener browser and frame). The |popup_id| value uniquely identifies the
	/// popup in the context of the opener browser. The |target_url| and
	/// |target_frame_name| values indicate where the popup browser should
	/// navigate and may be NULL if not specified with the request. The
	/// |target_disposition| value indicates where the user intended to open the
	/// popup (e.g. current tab, new tab, etc). The |user_gesture| value will be
	/// true (1) if the popup was opened via explicit user gesture (e.g. clicking
	/// a link) or false (0) if the popup opened automatically (e.g. via the
	/// DomContentLoaded event). The |popupFeatures| structure contains additional
	/// information about the requested popup window. To allow creation of the
	/// popup browser optionally modify |windowInfo|, |client|, |settings| and
	/// |no_javascript_access| and return false (0). To cancel creation of the
	/// popup browser return true (1). The |client| and |settings| values will
	/// default to the source browser's values. If the |no_javascript_access|
	/// value is set to false (0) the new browser will not be scriptable and may
	/// not be hosted in the same renderer process as the source browser. Any
	/// modifications to |windowInfo| will be ignored if the parent browser is
	/// wrapped in a browser_view. The |extra_info| parameter provides an
	/// opportunity to specify extra information specific to the created popup
	/// browser that will be passed to
	/// Render_process_handler::on_browser_created() in the render process.
	/// If popup browser creation succeeds then on_after_created will be called for the new popup browser. If popup browser creation fails, and if the opener
	/// browser has not yet been destroyed, then on_before_popup_aborted will be
	/// called for the opener browser. See on_before_popup_aborted documentation for
	/// additional details.
	on_before_popup: proc "system" (self: ^Life_span_handler, browser: ^Browser, frame: ^Frame, popup_id: c.int,
		target_url: ^cef_string, target_frame_name: ^cef_string, target_disposition: Window_open_disposition, user_gesture: b32,
		popupFeatures: ^Popup_features, windowInfo: ^Window_info, client: ^^Client, settings: ^Browser_settings, extra_info: ^^cef_dictionary_value, no_javascript_access: ^b32) -> b32,

	/// Called on the UI thread if a new popup browser is aborted. This only occurs if the popup is allowed in on_before_popup and creation fails before
	/// on_after_created is called for the new popup browser. The |browser| value is
	/// the source of the popup request (opener browser). The |popup_id| value
	/// uniquely identifies the popup in the context of the opener browser, and is
	/// the same value that was passed to on_before_popup.
	/// Any client state associated with pending popups should be cleared in on_before_popup_aborted, on_after_created of the popup browser, or
	/// on_before_close of the opener browser. on_before_close of the opener browser
	/// may be called before this function in cases where the opener is closing
	/// during popup creation, in which case Browser_host::is_valid will
	/// return false (0) in this function.
	on_before_popup_aborted: proc "system" (self: ^Life_span_handler, browser: ^Browser, popup_id: c.int),

	/// Called on the UI thread before a new DevTools popup browser is created. The |browser| value represents the source of the popup request. Optionally
	/// modify |windowInfo|, |client|, |settings| and |extra_info| values. The
	/// |client|, |settings| and |extra_info| values will default to the source
	/// browser's values. Any modifications to |windowInfo| will be ignored if the
	/// parent browser is Views-hosted (wrapped in a browser_view).
	/// The |extra_info| parameter provides an opportunity to specify extra information specific to the created popup browser that will be passed to
	/// Render_process_handler::on_browser_created() in the render process.
	/// The existing |extra_info| object, if any, will be read-only but may be
	/// replaced with a new object.
	/// Views-hosted source browsers will create Views-hosted DevTools popups unless |use_default_window| is set to to true (1). DevTools popups can be
	/// blocked by returning true (1) from command_handler::on_chrome_command
	/// for IDC_DEV_TOOLS. Only used with Chrome style.
	on_before_dev_tools_popup: proc "system" (self: ^Life_span_handler, browser: ^Browser, windowInfo: ^Window_info,
		 client: ^^Client,settings: ^Browser_settings, extra_info: ^^cef_dictionary_value, use_default_window: ^b32),

	/// Called after a new browser is created. It is now safe to begin performing actions with |browser|. Frame_handler callbacks related to initial
	/// main frame creation will arrive before this callback. See
	/// Frame_handler documentation for additional usage information.
	on_after_created: proc "system" (self: ^Life_span_handler, browser: ^Browser),

	/// Called when an Alloy style browser is ready to be closed, meaning that the close has already been initiated and that JavaScript unload handlers have
	/// already executed or should be ignored. This may result directly from a
	/// call to Browser_host::[try_]close_browser() or indirectly if the
	/// browser's top-level parent window was created by CEF and the user attempts
	/// to close that window (by clicking the 'X', for example). do_close() will
	/// not be called if the browser's host window/view has already been destroyed
	/// (via parent window/view hierarchy tear-down, for example), as it is no
	/// longer possible to customize the close behavior at that point.
	/// An application should handle top-level parent window close notifications by calling Browser_host::try_close_browser() or
	/// Browser_host::close_browser(false (0)) instead of allowing the window
	/// to close immediately (see the examples below). This gives CEF an
	/// opportunity to process JavaScript unload handlers and optionally cancel
	/// the close before do_close() is called.
	/// When windowed rendering is enabled CEF will create an internal child window/view to host the browser. In that case returning false (0) from
	/// do_close() will send the standard close notification to the browser's top-
	/// level parent window (e.g. WM_CLOSE on Windows, performClose: on OS X,
	/// "delete_event" on Linux or window_delegate::can_close() callback
	/// from Views).
	/// When windowed rendering is disabled there is no internal window/view and returning false (0) from do_close() will cause the browser object to be
	/// destroyed immediately.
	/// If the browser's top-level parent window requires a non-standard close notification then send that notification from do_close() and return true
	/// (1). You are still required to complete the browser close as soon as
	/// possible (either by calling [try_]close_browser() or by proceeding with
	/// window/view hierarchy tear-down), otherwise the browser will be left in a
	/// partially closed state that interferes with proper functioning. Top-level
	/// windows created on the browser process UI thread can alternately call
	/// Browser_host::is_ready_to_be_closed() in the close handler to check
	/// close status instead of relying on custom do_close() handling. See
	/// documentation on that function for additional details.
	/// The life_span_handler::on_before_close() function will be called after do_close() (if do_close() is called) and immediately before the
	/// browser object is destroyed. The application should only exit after
	/// on_before_close() has been called for all existing browsers.
	do_close: proc "system" (self: ^Life_span_handler, browser: ^Browser) -> b32,

	/// Called just before a browser is destroyed. Release all references to the browser object and do not attempt to execute any functions on the browser
	/// object (other than is_valid, get_identifier or is_same) after this callback
	/// returns. Frame_handler callbacks related to final main frame
	/// destruction, and on_before_popup_aborted callbacks for any pending popups,
	/// will arrive after this callback and browser::is_valid will return
	/// false (0) at that time. Any in-progress network requests associated with
	/// |browser| will be aborted when the browser is destroyed, and
	/// Resource_request_handler callbacks related to those requests may
	/// still arrive on the IO thread after this callback. See Frame_handler
	/// and do_close() documentation for additional usage information.
	on_before_close: proc "system" (self: ^Life_span_handler, browser: ^Browser),
} 