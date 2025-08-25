package odin_cef

import "core:c"

/// Implement this structure to handle events related to browser load status. The functions of this structure will be called on the browser process UI
/// thread or render process main thread (TID_RENDERER).
/// NOTE: This struct is allocated client-side.
Load_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when the loading state has changed. This callback will be executed twice -- once when loading is initiated either programmatically or by user
	/// action, and once when loading is terminated due to completion,
	/// cancellation of failure. It will be called before any calls to on_load_start
	/// and after all calls to on_load_error and/or on_load_end.
	on_loading_state_change: proc "system" (self: ^Load_handler, browser: ^Browser, isLoading: b32, canGoBack: b32, canGoForward: b32),

	/// Called after a navigation has been committed and before the browser begins loading contents in the frame. The |frame| value will never be NULL --
	/// call the is_main() function to check if this frame is the main frame.
	/// |transition_type| provides information about the source of the navigation
	/// and an accurate value is only available in the browser process. Multiple
	/// frames may be loading at the same time. Sub-frames may start or continue
	/// loading after the main frame load has ended. This function will not be
	/// called for same page navigations (fragments, history state, etc.) or for
	/// navigations that fail or are canceled before commit. For notification of
	/// overall browser load status use on_loading_state_change instead.
	on_load_start: proc "system" (self: ^Load_handler, browser: ^Browser, frame: ^Frame, transition_type: Transition_type),

	/// Called when the browser is done loading a frame. The |frame| value will never be NULL -- call the is_main() function to check if this frame is the
	/// main frame. Multiple frames may be loading at the same time. Sub-frames
	/// may start or continue loading after the main frame load has ended. This
	/// function will not be called for same page navigations (fragments, history
	/// state, etc.) or for navigations that fail or are canceled before commit.
	/// For notification of overall browser load status use on_loading_state_change
	/// instead.
	on_load_end: proc "system" (self: ^Load_handler, browser: ^Browser, frame: ^Frame, httpStatusCode: c.int),

	/// Called when a navigation fails or is canceled. This function may be called by itself if before commit or in combination with on_load_start/on_load_end if
	/// after commit. |errorCode| is the error code number, |errorText| is the
	/// error text and |failedUrl| is the URL that failed to load. See
	/// net\base\net_error_list.h for complete descriptions of the error codes.
	on_load_error: proc "system" (self: ^Load_handler, browser: ^Browser, frame: ^Frame, errorCode: cef_errorcode, errorText: ^cef_string, failedUrl: ^cef_string),
} 