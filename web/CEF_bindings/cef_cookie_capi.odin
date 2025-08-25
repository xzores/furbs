package odin_cef

import "core:c"

/// Structure used for managing cookies. The functions of this structure may be called on any thread unless otherwise indicated.
/// NOTE: This struct is allocated DLL-side.
Cookie_manager :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Visit all cookies on the UI thread. The returned cookies are ordered by longest path, then by earliest creation date. Returns false (0) if cookies
	/// cannot be accessed.
	visit_all_cookies: proc "system" (self: ^Cookie_manager, visitor: ^Cookie_visitor) -> b32,

	/// Visit a subset of cookies on the UI thread. The results are filtered by the given url scheme, host, domain and path. If |includeHttpOnly| is true
	/// (1) HTTP-only cookies will also be included in the results. The returned
	/// cookies are ordered by longest path, then by earliest creation date.
	/// Returns false (0) if cookies cannot be accessed.
	visit_url_cookies: proc "system" (self: ^Cookie_manager, url: ^cef_string, includeHttpOnly: b32, visitor: ^Cookie_visitor) -> b32,

	/// Sets a cookie given a valid URL and explicit user-provided cookie attributes. This function expects each attribute to be well-formed. It
	/// will check for disallowed characters (e.g. the ';' character is disallowed
	/// within the cookie value attribute) and fail without setting the cookie if
	/// such characters are found. If |callback| is non-NULL it will be executed
	/// asnychronously on the UI thread after the cookie has been set. Returns
	/// false (0) if an invalid URL is specified or if cookies cannot be accessed.
	set_cookie: proc "system" (self: ^Cookie_manager, url: ^cef_string, cookie: ^cef_cookie, callback: ^Set_cookie_callback) -> b32,

	/// Delete all cookies that match the specified parameters. If both |url| and |cookie_name| values are specified all host and domain cookies matching
	/// both will be deleted. If only |url| is specified all host cookies (but not
	/// domain cookies) irrespective of path will be deleted. If |url| is NULL all
	/// cookies for all hosts and domains will be deleted. If |callback| is non-
	/// NULL it will be executed asnychronously on the UI thread after the cookies
	/// have been deleted. Returns false (0) if a non-NULL invalid URL is
	/// specified or if cookies cannot be accessed. Cookies can alternately be
	/// deleted using the Visit*Cookies() functions.
	delete_cookies: proc "system" (self: ^Cookie_manager, url: ^cef_string, cookie_name: ^cef_string, callback: ^Delete_cookies_callback) -> b32,

	/// Flush the backing store (if any) to disk. If |callback| is non-NULL it will be executed asnychronously on the UI thread after the flush is
	/// complete. Returns false (0) if cookies cannot be accessed.
	flush_store: proc "system" (self: ^Cookie_manager, callback: ^Completion_callback) -> b32,
}

/// Returns the global cookie manager. By default data will be stored at cef_settings.cache_path if specified or in memory otherwise. If |callback|
/// is non-NULL it will be executed asnychronously on the UI thread after the
/// manager's storage has been initialized. Using this function is equivalent to
/// calling Request_context::get_global_context()->get_default_cookie_manager().
///
get_global_manager :: proc "system" (callback: ^Completion_callback) -> ^Cookie_manager

/// Structure to implement for visiting cookie values. The functions of this structure will always be called on the UI thread.
/// NOTE: This struct is allocated client-side.
Cookie_visitor :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Method that will be called once for each cookie. |count| is the 0-based index for the current cookie. |total| is the total number of cookies. Set
	/// |deleteCookie| to true (1) to delete the cookie currently being visited.
	/// Return false (0) to stop visiting cookies. This function may never be
	/// called if no cookies are found.
	visit: proc "system" (self: ^Cookie_visitor, cookie: ^cef_cookie, count: c.int, total: c.int, deleteCookie: ^c.int) -> b32,
}

/// Structure to implement to be notified of asynchronous completion via Cookie_manager::set_cookie().
/// NOTE: This struct is allocated client-side.
Set_cookie_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Method that will be called upon completion. |success| will be true (1) if the cookie was set successfully.
	on_complete: proc "system" (self: ^Set_cookie_callback, success: b32),
}

/// Structure to implement to be notified of asynchronous completion via Cookie_manager::delete_cookies().
/// NOTE: This struct is allocated client-side.
Delete_cookies_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Method that will be called upon completion. |num_deleted| will be the number of cookies that were deleted or -1 if unknown.
	on_complete: proc "system" (self: ^Delete_cookies_callback, num_deleted: c.int),
} 