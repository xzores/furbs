package odin_cef

import "core:c"

/// Callback structure used for asynchronous continuation of media access permission requests.
/// NOTE: This struct is allocated DLL-side.
media_access_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Call to allow or deny media access. If this callback was initiated in response to a getUserMedia (indicated by
	/// CEF_MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE and/or
	/// CEF_MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE being set) then
	/// |allowed_permissions| must match |required_permissions| passed to
	/// on_request_media_access_permission.
	cont: proc "system" (self: ^media_access_callback, allowed_permissions: u32),

	/// Cancel the media access request.
	cancel: proc "system" (self: ^media_access_callback),
}

/// Callback structure used for asynchronous continuation of permission prompts.
/// NOTE: This struct is allocated DLL-side.
///
permission_prompt_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Complete the permissions request with the specified |result|.
	cont: proc "system" (self: ^permission_prompt_callback, result: Permission_request_result),
}

/// Implement this structure to handle events related to permission requests. The functions of this structure will be called on the browser process UI
/// thread.
/// NOTE: This struct is allocated client-side.
Permission_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when a page requests permission to access media. |requesting_origin| is the URL origin requesting permission.
	/// |requested_permissions| is a combination of values from
	/// cef_media_access_permission_types that represent the requested
	/// permissions. Return true (1) and call media_access_callback
	/// functions either in this function or at a later time to continue or cancel
	/// the request. Return false (0) to proceed with default handling. With
	/// Chrome style, default handling will display the permission request UI.
	/// With Alloy style, default handling will deny the request. This function
	/// will not be called if the "--enable-media-stream" command-line switch is
	/// used to grant all permissions.
		on_request_media_access_permission: proc "system" (self: ^Permission_handler, browser: ^Browser, frame: ^Frame, requesting_origin: ^cef_string, requested_permissions: u32, callback: ^media_access_callback) -> b32,

	/// Called when a page should show a permission prompt. |prompt_id| uniquely identifies the prompt. |requesting_origin| is the URL origin requesting
	/// permission. |requested_permissions| is a combination of values from
	/// cef_permission_request_types that represent the requested permissions.
	/// Return true (1) and call permission_prompt_callback::cont either
	/// in this function or at a later time to continue or cancel the request.
	/// Return false (0) to proceed with default handling. With Chrome style,
	/// default handling will display the permission prompt UI. With Alloy style,
	/// default handling is CEF_PERMISSION_RESULT_IGNORE.
	on_show_permission_prompt: proc "system" (self: ^Permission_handler, browser: ^Browser, prompt_id: u64, requesting_origin: ^cef_string, requested_permissions: u32, callback: ^permission_prompt_callback) -> b32,

	/// Called when a permission prompt handled via on_show_permission_prompt is dismissed. |prompt_id| will match the value that was passed to
	/// on_show_permission_prompt. |result| will be the value passed to
	/// permission_prompt_callback::cont or CEF_PERMISSION_RESULT_IGNORE
	/// if the dialog was dismissed for other reasons such as navigation, browser
	/// closure, etc. This function will not be called if on_show_permission_prompt
	/// returned false (0) for |prompt_id|.
	on_dismiss_permission_prompt: proc "system" (self: ^Permission_handler, browser: ^Browser, prompt_id: u64, result: Permission_request_result),
} 