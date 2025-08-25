package odin_cef

import "core:c"

/// Callback structure used to asynchronously continue a download.
/// NOTE: This struct is allocated DLL-side.
///
before_download_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Call to continue the download. Set |download_path| to the full file path for the download including the file name or leave blank to use the
	/// suggested name and the default temp directory. Set |show_dialog| to true
	/// (1) if you do wish to show the default "Save As" dialog.
	cont: proc "system" (self: ^before_download_callback, download_path: ^cef_string, show_dialog: b32),
}

/// Callback structure used to asynchronously cancel a download.
/// NOTE: This struct is allocated DLL-side.
///
download_item_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Call to cancel the download.
	cancel: proc "system" (self: ^download_item_callback),

	/// Call to pause the download.
	pause: proc "system" (self: ^download_item_callback),

	/// Call to resume the download.
	resume: proc "system" (self: ^download_item_callback),
}

/// Structure used to handle file downloads. The functions of this structure will called on the browser process UI thread.
/// NOTE: This struct is allocated client-side.
Download_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called before a download begins in response to a user-initiated action (e.g. alt + link click or link click that returns a `Content-Disposition:
	/// attachment` response from the server). |url| is the target download URL
	/// and |request_function| is the target function (GET, POST, etc). Return
	/// true (1) to proceed with the download or false (0) to cancel the download.
	can_download: proc "system" (self: ^Download_handler, browser: ^Browser, url: ^cef_string, request_method: ^cef_string) -> b32,

	/// Called before a download begins. |suggested_name| is the suggested name for the download file. Return true (1) and execute |callback| either
	/// asynchronously or in this function to continue or cancel the download.
	/// Return false (0) to proceed with default handling (cancel with Alloy
	/// style, download shelf with Chrome style). Do not keep a reference to
	/// |Download_item| outside of this function.
	on_before_download: proc "system" (self: ^Download_handler, browser: ^Browser, Download_item: ^Download_item, suggested_name: ^cef_string, callback: ^before_download_callback) -> b32,

	/// Called when a download's status or progress information has been updated. This may be called multiple times before and after on_before_download().
	/// Execute |callback| either asynchronously or in this function to cancel the
	/// download if desired. Do not keep a reference to |Download_item| outside of
	/// this function.
	on_download_updated: proc "system" (self: ^Download_handler, browser: ^Browser, Download_item: ^Download_item, callback: ^download_item_callback),
} 