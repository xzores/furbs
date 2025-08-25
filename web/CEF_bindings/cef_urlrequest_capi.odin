package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

/// Structure used to make a URL request. URL requests are not associated with a browser instance so no client callbacks will be executed. URL requests
/// can be created on any valid CEF thread in either the browser or render
/// process. Once created the functions of the URL request object must be
/// accessed on the same thread that created it.
/// NOTE: This struct is allocated DLL-side.
Url_request :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns the request object used to create this URL request. The returned object is read-only and should not be modified.
	get_request: proc "system" (self: ^Url_request) -> ^Request,

	/// Returns the client.
	get_client: proc "system" (self: ^Url_request) -> ^Url_request_client,

	/// Returns the request status.
	get_request_status: proc "system" (self: ^Url_request) -> Url_request_status,

	/// Returns the request error if status is UR_CANCELED or UR_FAILED, or 0 otherwise.
	get_request_error: proc "system" (self: ^Url_request) -> cef_errorcode,

	/// Returns the response, or NULL if no response information is available. Response information will only be available after the upload has
	/// completed. The returned object is read-only and should not be modified.
	get_response: proc "system" (self: ^Url_request) -> ^Response,

	/// Returns true (1) if the response body was served from the cache. This includes responses for which revalidation was required.
	response_was_cached: proc "system" (self: ^Url_request) -> b32,

	/// Cancel the request.
	cancel: proc "system" (self: ^Url_request),
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Create a new URL request that is not associated with a specific browser or frame.
	// Use Frame_t::CreateURLRequest instead if you want the request to have this association,
	// in which case it may be handled differently.
	// Behavior notes:
	//	 - May be intercepted by CefResourceRequestHandler or CefSchemeHandlerFactory.
	//	 - POST data may contain only a single element of type PDE_TYPE_FILE or PDE_TYPE_BYTES.
	//	 - If Request_context is empty the global request context will be used.
	// The |request| object will be marked read-only after this call.
	urlrequest_create :: proc "system" (
		request: ^Request,
		client: ^Url_request_client,
		Request_context: ^Request_context,
	) -> ^Url_request ---
}

/// Structure that should be implemented by the Url_request client. The functions of this structure will be called on the same thread that created
/// the request unless otherwise documented.
/// NOTE: This struct is allocated client-side.
Url_request_client :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Notifies the client that the request has completed. Use the Url_request::get_request_status function to determine if the request
	/// was successful or not.
	on_request_complete: proc "system" (self: ^Url_request_client, request: ^Url_request),

	/// Notifies the client of upload progress. |current| denotes the number of bytes sent so far and |total| is the total size of uploading data (or -1
	/// if chunked upload is enabled). This function will only be called if the
	/// UR_FLAG_REPORT_UPLOAD_PROGRESS flag is set on the request.
	on_upload_progress: proc "system" (self: ^Url_request_client, request: ^Url_request, current: i64, total: i64),

	/// Notifies the client of download progress. |current| denotes the number of bytes received up to the call and |total| is the expected total size of
	/// the response (or -1 if not determined).
	on_download_progress: proc "system" (self: ^Url_request_client, request: ^Url_request, current: i64, total: i64),

	/// Called when some part of the response is read. |data| contains the current bytes received since the last call. This function will not be called if
	/// the UR_FLAG_NO_DOWNLOAD_DATA flag is set on the request.
	on_download_data: proc "system" (self: ^Url_request_client, request: ^Url_request, data: rawptr, data_length: c.size_t),

	/// Called on the IO thread when the browser needs credentials from the user. |isProxy| indicates whether the host is a proxy server. |host| contains
	/// the hostname and |port| contains the port number. Return true (1) to
	/// continue the request and call auth_callback::cont() when the
	/// authentication information is available. If the request has an associated
	/// browser/frame then returning false (0) will result in a call to
	/// get_auth_credentials on the Request_handler associated with that
	/// browser, and eventual cancellation of the request if the browser
	/// returns false (0). Return false (0) to cancel the request
	/// immediately. This function will only be called for requests initiated from
	/// the browser process.
	get_auth_credentials: proc "system" (self: ^Url_request_client, isProxy: b32, host: ^cef_string, port: c.int, realm: ^cef_string, scheme: ^cef_string, callback: ^auth_callback) -> b32,
} 