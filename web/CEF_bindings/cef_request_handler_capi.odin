package odin_cef

import "core:c"

/// Callback structure used to select a client certificate for authentication.
/// NOTE: This struct is allocated DLL-side.
///
select_client_certificate_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Chooses the specified certificate for client certificate authentication. NULL value means that no client certificate should be used.
	select: proc "system" (self: ^select_client_certificate_callback, cert: ^X509_certificate),
}

/// Implement this structure to handle events related to browser requests. The functions of this structure will be called on the thread indicated.
/// NOTE: This struct is allocated client-side.
Request_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called on the UI thread before browser navigation. Return true (1) to cancel the navigation or false (0) to allow the navigation to proceed. The
	/// |request| object cannot be modified in this callback.
	/// Load_handler::on_loading_state_change will be called twice in all
	/// cases. If the navigation is allowed Load_handler::on_load_start and
	/// Load_handler::on_load_end will be called. If the navigation is
	/// canceled Load_handler::on_load_error will be called with an
	/// |errorCode| value of ERR_ABORTED. The |user_gesture| value will be true
	/// (1) if the browser navigated via explicit user gesture (e.g. clicking a
	/// link) or false (0) if it navigated automatically (e.g. via the
	/// DomContentLoaded event).
	on_before_browse: proc "system" (self: ^Request_handler, browser: ^Browser, frame: ^Frame, request: ^Request, user_gesture: b32, is_redirect: b32) -> b32,

	/// Called on the UI thread before on_before_browse in certain limited cases where navigating a new or different browser might be desirable. This
	/// includes user-initiated navigation that might open in a special way (e.g.
	/// links clicked via middle-click or ctrl + left-click) and certain types of
	/// cross-origin navigation initiated from the renderer process (e.g.
	/// navigating the top-level frame to/from a file URL). The |browser| and
	/// |frame| values represent the source of the navigation. The
	/// |target_disposition| value indicates where the user intended to navigate
	/// the browser based on standard Chromium behaviors (e.g. current tab, new
	/// tab, etc). The |user_gesture| value will be true (1) if the browser
	/// navigated via explicit user gesture (e.g. clicking a link) or false (0) if
	/// it navigated automatically (e.g. via the DomContentLoaded event). Return
	/// true (1) to cancel the navigation or false (0) to allow the navigation to
	/// proceed in the source browser's top-level frame.
	on_open_urlfrom_tab: proc "system" (self: ^Request_handler, browser: ^Browser, frame: ^Frame, target_url: ^cef_string, target_disposition: Window_open_disposition, user_gesture: b32) -> b32,

	/// Called on the browser process IO thread before a resource request is initiated. The |browser| and |frame| values represent the source of the
	/// request. |request| represents the request contents and cannot be modified
	/// in this callback. |is_navigation| will be true (1) if the resource request
	/// is a navigation. |is_download| will be true (1) if the resource request is
	/// a download. |request_initiator| is the origin (scheme + domain) of the
	/// page that initiated the request. Set |disable_default_handling| to true
	/// (1) to disable default handling of the request, in which case it will need
	/// to be handled via Resource_request_handler::get_resource_handler or it
	/// will be canceled. To allow the resource load to proceed with default
	/// handling return NULL. To specify a handler for the resource return a
	/// Resource_request_handler object. If this callback returns NULL the
	/// same function will be called on the associated
	/// request_context_handler, if any.
	get_resource_request_handler: proc "system" (self: ^Request_handler, browser: ^Browser, frame: ^Frame, request: ^Request, is_navigation: b32, is_download: b32, request_initiator: ^cef_string, disable_default_handling: ^b32) -> ^Resource_request_handler,

	/// Called on the IO thread when the browser needs credentials from the user. |origin_url| is the origin making this authentication request. |isProxy|
	/// indicates whether the host is a proxy server. |host| contains the hostname
	/// and |port| contains the port number. |realm| is the realm of the challenge
	/// and may be NULL. |scheme| is the authentication scheme used, such as
	/// "basic" or "digest", and will be NULL if the source of the request is an
	/// FTP server. Return true (1) to continue the request and call
	/// auth_callback::cont() either in this function or at a later time
	/// when the authentication information is available. Return false (0) to
	/// cancel the request immediately.
	get_auth_credentials: proc "system" (self: ^Request_handler, browser: ^Browser, origin_url: ^cef_string, isProxy: b32, host: ^cef_string, port: c.int, realm: ^cef_string, scheme: ^cef_string, callback: ^auth_callback) -> b32,

	/// Called on the UI thread to handle requests for URLs with an invalid SSL certificate. Return true (1) and call callback functions either in
	/// this function or at a later time to continue or cancel the request. Return
	/// false (0) to cancel the request immediately. If
	/// cef_settings.ignore_certificate_errors is set all invalid certificates
	/// will be accepted without calling this function.
	on_certificate_error: proc "system" (self: ^Request_handler, browser: ^Browser, cert_error: cef_errorcode, request_url: ^cef_string, ssl_info: ^ssl_info, callback: ^cef_callback) -> b32,

	/// Called on the UI thread when a client certificate is being requested for authentication. Return false (0) to use the default behavior.	If the
	/// |certificates| list is not NULL the default behavior will be to display a
	/// dialog for certificate selection. If the |certificates| list is NULL then
	/// the default behavior will be not to show a dialog and it will continue
	/// without using any certificate. Return true (1) and call
	/// select_client_certificate_callback::select either in this function
	/// or at a later time to select a certificate. Do not call select or call it
	/// with NULL to continue without using any certificate. |isProxy| indicates
	/// whether the host is an HTTPS proxy or the origin server. |host| and |port|
	/// contains the hostname and port of the SSL server. |certificates| is the
	/// list of certificates to choose from; this list has already been pruned by
	/// Chromium so that it only contains certificates from issuers that the
	/// server trusts.
	on_select_client_certificate: proc "system" (self: ^Request_handler, browser: ^Browser, isProxy: b32, host: ^cef_string, port: c.int, certificatesCount: c.size_t, certificates: ^^X509_certificate, callback: ^select_client_certificate_callback) -> b32,

	/// Called on the browser process UI thread when the render view associated with |browser| is ready to receive/handle IPC messages in the render
	/// process.
	on_render_view_ready: proc "system" (self: ^Request_handler, browser: ^Browser),

	/// Called on the browser process UI thread when the render process is unresponsive as indicated by a lack of input event processing for at least
	/// 15 seconds. Return false (0) for the default behavior which is an
	/// indefinite wait with Alloy style or display of the "Page unresponsive"
	/// dialog with Chrome style. Return true (1) and don't execute the callback
	/// for an indefinite wait without display of the Chrome style dialog. Return
	/// true (1) and call unresponsive_process_callback::wait either in this
	/// function or at a later time to reset the wait timer, potentially
	/// triggering another call to this function if the process remains
	/// unresponsive. Return true (1) and call
	/// unresponsive_process_callback::terminate either in this function or
	/// at a later time to terminate the unresponsive process, resulting in a call
	/// to on_render_process_terminated. on_render_process_responsive will be called if
	/// the process becomes responsive after this function is called. This
	/// functionality depends on the hang monitor which can be disabled by passing
	/// the `--disable-hang-monitor` command-line flag.
	on_render_process_unresponsive: proc "system" (self: ^Request_handler, browser: ^Browser, callback: ^unresponsive_process_callback) -> b32,

	/// Called on the browser process UI thread when the render process becomes responsive after previously being unresponsive. See documentation on
	/// on_render_process_unresponsive.
	on_render_process_responsive: proc "system" (self: ^Request_handler, browser: ^Browser),

	/// Called on the browser process UI thread when the render process terminates unexpectedly. |status| indicates how the process terminated. |error_code|
	/// and |error_string| represent the error that would be displayed in Chrome's
	/// "Aw, Snap!" view. Possible |error_code| values include cef_resultcode
	/// non-normal exit values and platform-specific crash values (for example, a
	/// Posix signal or Windows hardware exception).
	on_render_process_terminated: proc "system" (self: ^Request_handler, browser: ^Browser, status: Termination_status, error_code: c.int, error_string: ^cef_string),

	/// Called on the browser process UI thread when the window.document object of the main frame has been created.
	on_document_available_in_main_frame: proc "system" (self: ^Request_handler, browser: ^Browser),
} 