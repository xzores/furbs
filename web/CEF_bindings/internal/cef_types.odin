package cef_internal

import "core:c"

/*
// Bring in platform-specific definitions.
#if defined(OS_WIN)
#include "include/internal/cef_types_win.h"
#elif defined(OS_MAC)
#include "include/internal/cef_types_mac.h"
#elif defined(OS_LINUX)
#include "include/internal/cef_types_linux.h"
#endif
*/

// 32-bit ARGB color value, not premultiplied. The color components are always
// in a known order. Equivalent to the SkColor type.
cef_color :: c.uint32_t;

/// Log severity levels.
Log_severity :: enum u32 {
	/// Default logging (currently INFO logging).
	LOGSEVERITY_DEFAULT,

	/// Verbose logging.
	LOGSEVERITY_VERBOSE,

	/// DEBUG logging.
	LOGSEVERITY_DEBUG = LOGSEVERITY_VERBOSE,

	/// INFO logging.
	LOGSEVERITY_INFO,

	/// WARNING logging.
	LOGSEVERITY_WARNING,

	/// ERROR logging.
	LOGSEVERITY_ERROR,

	/// FATAL logging.
	LOGSEVERITY_FATAL,

	/// Disable logging to file for all messages, and to stderr for messages with
	/// severity less than FATAL.
	LOGSEVERITY_DISABLE = 99
};

/// Log items prepended to each log line.
Log_items :: enum u32 {
	/// Prepend the default list of items.
	LOG_ITEMS_DEFAULT = 0,

	/// Prepend no items.
	LOG_ITEMS_NONE = 1,

	/// Prepend the process ID.
	LOG_ITEMS_FLAG_PROCESS_ID = 1 << 1,

	/// Prepend the thread ID.
	LOG_ITEMS_FLAG_THREAD_ID = 1 << 2,

	/// Prepend the timestamp.
	LOG_ITEMS_FLAG_TIME_STAMP = 1 << 3,

	/// Prepend the tickcount.
	LOG_ITEMS_FLAG_TICK_COUNT = 1 << 4,

};

/// Represents the state of a setting.
State :: enum u32 {
	/// Use the default state for the setting.
	STATE_DEFAULT = 0,

	/// Enable or allow the setting.
	STATE_ENABLED,

	/// Disable or disallow the setting.
	STATE_DISABLED,
};

// Initialization settings. Specify NULL or 0 to get the recommended default values. Many of these and other settings can also configured using command-line switches.
Settings :: struct {
	// Size of this structure.
	size: c.size_t,

	// Set to true (1) to disable the sandbox for sub-processes. See cef_sandbox_win.h for requirements to enable the sandbox on Windows. Also configurable using the "no-sandbox" command-line switch.
	no_sandbox: c.int,

	// The path to a separate executable that will be launched for sub-processes. If this value is empty on Windows or Linux then the main process executable will be used. If this value is empty on macOS then a helper executable must exist at "Contents/Frameworks/<app> Helper.app/Contents/MacOS/<app> Helper" in the top-level app bundle. See the comments on CefExecuteProcess() for details. If this value is non-empty then it must be an absolute path. Also configurable using the "browser-subprocess-path" command-line switch.
	browser_subprocess_path: cef_string,

	// The path to the CEF framework directory on macOS. If this value is empty then the framework must exist at "Contents/Frameworks/Chromium Embedded Framework.framework" in the top-level app bundle. If this value is non-empty then it must be an absolute path. Also configurable using the "framework-dir-path" command-line switch.
	framework_dir_path: cef_string,

	// The path to the main bundle on macOS. If this value is empty then it defaults to the top-level app bundle. If this value is non-empty then it must be an absolute path. Also configurable using the "main-bundle-path" command-line switch.
	main_bundle_path: cef_string,

	// Set to true (1) to have the browser process message loop run in a separate thread. If false (0) then the CefDoMessageLoopWork() function must be called from your application message loop. This option is only supported on Windows and Linux.
	multi_threaded_message_loop: c.int,

	// Set to true (1) to control browser process main (UI) thread message pump scheduling via the CefBrowserProcessHandler::OnScheduleMessagePumpWork() callback. This option is recommended for use in combination with the CefDoMessageLoopWork() function in cases where the CEF message loop must be integrated into an existing application message loop (see additional comments and warnings on CefDoMessageLoopWork). Enabling this option is not recommended for most users; leave this option disabled and use either the CefRunMessageLoop() function or multi_threaded_message_loop if possible.
	external_message_pump: c.int,

	// Set to true (1) to enable windowless (off-screen) rendering support. Do not enable this value if the application does not use windowless rendering as it may reduce rendering performance on some systems.
	windowless_rendering_enabled: c.int,

	// Set to true (1) to disable configuration of browser process features using standard CEF and Chromium command-line arguments. Configuration can still be specified using CEF data structures or via the CefApp::OnBeforeCommandLineProcessing() method.
	command_line_args_disabled: c.int,

	// The directory where data for the global browser cache will be stored on disk. If this value is non-empty then it must be an absolute path that is either equal to or a child directory of CefSettings.root_cache_path. If this value is empty then browsers will be created in "incognito mode" where in-memory caches are used for storage and no profile-specific data is persisted to disk (installation-specific data will still be persisted in root_cache_path). HTML5 databases such as localStorage will only persist across sessions if a cache path is specified. Can be overridden for individual CefRequestContext instances via the CefRequestContextSettings.cache_path value. Any child directory value will be ignored and the "default" profile (also a child directory) will be used instead.
	cache_path: cef_string,

	// The root directory for installation-specific data and the parent directory for profile-specific data. All CefSettings.cache_path and CefRequestContextSettings.cache_path values must have this parent directory in common. If this value is empty and CefSettings.cache_path is non-empty then it will default to the CefSettings.cache_path value. Any non-empty value must be an absolute path. If both values are empty then the default platform-specific directory will be used ("~/.config/cef_user_data" directory on Linux, "~/Library/Application Support/CEF/User Data" directory on MacOS, "AppData\\Local\\CEF\\User Data" directory under the user profile directory on Windows). Use of the default directory is not recommended in production applications (see below). Multiple application instances writing to the same root_cache_path directory could result in data corruption. A process singleton lock based on the root_cache_path value is therefore used to protect against this. This singleton behavior applies to all CEF-based applications using version 120 or newer. You should customize root_cache_path for your application and implement CefBrowserProcessHandler::OnAlreadyRunningAppRelaunch, which will then be called on any app relaunch with the same root_cache_path value. Failure to set the root_cache_path value correctly may result in startup crashes or other unexpected behaviors (for example, the sandbox blocking read/write access to certain files).
	root_cache_path: cef_string,

	// To persist session cookies (cookies without an expiry date or validity interval) by default when using the global cookie manager set this value to true (1). Session cookies are generally intended to be transient and most Web browsers do not persist them. A |cache_path| value must also be specified to enable this feature. Also configurable using the "persist-session-cookies" command-line switch. Can be overridden for individual CefRequestContext instances via the CefRequestContextSettings.persist_session_cookies value.
	persist_session_cookies: c.int,

	// Value that will be returned as the User-Agent HTTP header. If empty the default User-Agent string will be used. Also configurable using the "user-agent" command-line switch.
	user_agent: cef_string,

	// Value that will be inserted as the product portion of the default User-Agent string. If empty the Chromium product version will be used. If |userAgent| is specified this value will be ignored. Also configurable using the "user-agent-product" command-line switch.
	user_agent_product: cef_string,

	// The locale string that will be passed to WebKit. If empty the default locale of "en-US" will be used. This value is ignored on Linux where locale is determined using environment variable parsing with the precedence order: LANGUAGE, LC_ALL, LC_MESSAGES and LANG. Also configurable using the "lang" command-line switch.
	locale: cef_string,

	// The directory and file name to use for the debug log. If empty a default log file name and location will be used. On Windows and Linux a "debug.log" file will be written in the main executable directory. On MacOS a "~/Library/Logs/[app name]_debug.log" file will be written where [app name] is the name of the main app executable. Also configurable using the "log-file" command-line switch.
	log_file: cef_string,

	// The log severity. Only messages of this severity level or higher will be logged. When set to DISABLE no messages will be written to the log file, but FATAL messages will still be output to stderr. Also configurable using the "log-severity" command-line switch with a value of "verbose", "info", "warning", "error", "fatal" or "disable".
	Log_severity: Log_severity,

	// The log items prepended to each log line. If not set the default log items will be used. Also configurable using the "log-items" command-line switch with a value of "none" for no log items, or a comma-delimited list of values "pid", "tid", "timestamp" or "tickcount" for custom log items.
	log_items: Log_items,

	// Custom flags that will be used when initializing the V8 JavaScript engine. The consequences of using custom flags may not be well tested. Also configurable using the "js-flags" command-line switch.
	javascript_flags: cef_string,

	// The fully qualified path for the resources directory. If this value is empty the *.pak files must be located in the module directory on Windows/Linux or the app bundle Resources directory on MacOS. If this value is non-empty then it must be an absolute path. Also configurable using the "resources-dir-path" command-line switch.
	resources_dir_path: cef_string,

	// The fully qualified path for the locales directory. If this value is empty the locales directory must be located in the module directory. If this value is non-empty then it must be an absolute path. This value is ignored on MacOS where pack files are always loaded from the app bundle Resources directory. Also configurable using the "locales-dir-path" command-line switch.
	locales_dir_path: cef_string,

	// Set to a value between 1024 and 65535 to enable remote debugging on the specified port. Also configurable using the "remote-debugging-port" command-line switch. Specifying 0 via the command-line switch will result in the selection of an ephemeral port and the port number will be printed as part of the WebSocket endpoint URL to stderr. If a cache directory path is provided the port will also be written to the <cache-dir>/DevToolsActivePort file. Remote debugging can be accessed by loading the chrome://inspect page in Google Chrome. Port numbers 9222 and 9229 are discoverable by default. Other port numbers may need to be configured via "Discover network targets" on the Devices tab.
	remote_debugging_port: c.int,

	// The number of stack trace frames to capture for uncaught exceptions. Specify a positive value to enable the CefRenderProcessHandler::OnUncaughtException() callback. Specify 0 (default value) and OnUncaughtException() will not be called. Also configurable using the "uncaught-exception-stack-size" command-line switch.
	uncaught_exception_stack_size: c.int,

	// Background color used for the browser before a document is loaded and when no document color is specified. The alpha component must be either fully opaque (0xFF) or fully transparent (0x00). If the alpha component is fully opaque then the RGB components will be used as the background color. If the alpha component is fully transparent for a windowed browser then the default value of opaque white be used. If the alpha component is fully transparent for a windowless (off-screen) browser then transparent painting will be enabled.
	background_color: cef_color,

	// Comma delimited ordered list of language codes without any whitespace that will be used in the "Accept-Language" HTTP request header and "navigator.language" JS attribute. Can be overridden for individual CefRequestContext instances via the CefRequestContextSettings.accept_language_list value.
	accept_language_list: cef_string,

	// Comma delimited list of schemes supported by the associated CefCookieManager. If |cookieable_schemes_exclude_defaults| is false (0) the default schemes ("http", "https", "ws" and "wss") will also be supported. Not specifying a |cookieable_schemes_list| value and setting |cookieable_schemes_exclude_defaults| to true (1) will disable all loading and saving of cookies. These settings will only impact the global CefRequestContext. Individual CefRequestContext instances can be configured via the CefRequestContextSettings.cookieable_schemes_list and CefRequestContextSettings.cookieable_schemes_exclude_defaults values.
	cookieable_schemes_list: cef_string,
	cookieable_schemes_exclude_defaults: c.int,

	// Specify an ID to enable Chrome policy management via Platform and OS-user policies. On Windows, this is a registry key like "SOFTWARE\\Policies\\Google\\Chrome". On MacOS, this is a bundle ID like "com.google.Chrome". On Linux, this is an absolute directory path like "/etc/opt/chrome/policies". Only supported with Chrome style. See https://support.google.com/chrome/a/answer/9037717 for details. Chrome Browser Cloud Management integration, when enabled via the "enable-chrome-browser-cloud-management" command-line flag, will also use the specified ID. See https://support.google.com/chrome/a/answer/9116814 for details.
	chrome_policy_id: cef_string,

	// Specify an ID for an ICON resource that can be loaded from the main executable and used when creating default Chrome windows such as DevTools and Task Manager. If unspecified the default Chromium ICON (IDR_MAINFRAME [101]) will be loaded from libcef.dll. Only supported with Chrome style on Windows.
	chrome_app_icon_id: c.int,

	// Specify whether signal handlers must be disabled on POSIX systems.
	disable_signal_handlers: c.int,
}

// Request context initialization settings. Specify NULL or 0 to get the recommended default values.
Request_context_settings :: struct {
	// Size of this structure.
	size: c.size_t,

	// Directory where cache data for this request context will be stored on disk. If non-empty it must be an absolute path equal to or a child of CefSettings.root_cache_path. If empty, browsers run in "incognito mode" (in-memory caches; no profile data persisted, though installation-specific data may still use root_cache_path). HTML5 databases persist across sessions only if cache_path is specified. To share the global browser cache/config, set this to CefSettings.cache_path.
	cache_path: cef_string,

	// Persist session cookies (no expiry/validity interval) by default when using the global cookie manager (1 = true). Typically session cookies are transient and not persisted. Can be set globally via CefSettings.persist_session_cookies. Ignored if cache_path is empty or matches CefSettings.cache_path.
	persist_session_cookies: c.int,

	// Comma-delimited ordered list of language codes (no whitespace) used for the "Accept-Language" header and navigator.language. Can be set globally via CefSettings.accept_language_list. If all values are empty then "en-US,en" will be used. Ignored if cache_path matches CefSettings.cache_path.
	accept_language_list: cef_string,

	// Comma-delimited list of schemes supported by the associated CefCookieManager. If cookieable_schemes_exclude_defaults is 0, default schemes ("http", "https", "ws", "wss") are also supported. Not specifying cookieable_schemes_list and setting cookieable_schemes_exclude_defaults to 1 disables all cookie load/save. Both values are ignored if cache_path matches CefSettings.cache_path.
	cookieable_schemes_list: cef_string,
	cookieable_schemes_exclude_defaults: c.int,
}

// Browser initialization settings. Specify NULL or 0 for recommended defaults. Consequences of custom values may not be well tested. Many of these and other settings can also be configured using command-line switches.
Browser_settings :: struct {
	// Size of this structure.
	size: c.size_t,

	// Max frames-per-second for CefRenderHandler::OnPaint in windowless mode. Min 1, max 60 (default 30). Can be changed dynamically via CefBrowserHost::SetWindowlessFrameRate.
	windowless_frame_rate: c.int,

	// BEGIN values that map to WebPreferences settings.

	// Font settings.
	standard_font_family:	 cef_string,
	fixed_font_family:		cef_string,
	serif_font_family:		cef_string,
	sans_serif_font_family: cef_string,
	cursive_font_family:	cef_string,
	fantasy_font_family:	cef_string,
	default_font_size:			c.int,
	default_fixed_font_size:	c.int,
	minimum_font_size:			c.int,
	minimum_logical_font_size:	c.int,

	// Default encoding for Web content. If empty "ISO-8859-1" will be used. Also configurable via "default-encoding".
	default_encoding: cef_string,

	// Controls loading of fonts from remote sources. Also configurable via "disable-remote-fonts".
	remote_fonts: State,

	// Controls whether JavaScript can be executed. Also configurable via "disable-javascript".
	javascript: State,

	// Controls whether JavaScript can close windows not opened via JavaScript. Also configurable via "disable-javascript-close-windows".
	javascript_close_windows: State,

	// Controls whether JavaScript can access the clipboard. Also configurable via "disable-javascript-access-clipboard".
	javascript_access_clipboard: State,

	// Controls whether DOM pasting via execCommand("paste") is supported. Requires javascript_access_clipboard. Also configurable via "disable-javascript-dom-paste".
	javascript_dom_paste: State,

	// Controls whether image URLs will be loaded from the network. Cached images may still render. Also configurable via "disable-image-loading".
	image_loading: State,

	// Controls whether standalone images will be shrunk to fit the page. Also configurable via "image-shrink-standalone-to-fit".
	image_shrink_standalone_to_fit: State,

	// Controls whether text areas can be resized. Also configurable via "disable-text-area-resize".
	text_area_resize: State,

	// Controls whether the tab key can advance focus to links. Also configurable via "disable-tab-to-links".
	tab_to_links: State,

	// Controls whether local storage can be used. Also configurable via "disable-local-storage".
	local_storage: State,

	// Controls whether databases can be used. Also configurable via "disable-databases".
	databases: State,

	// Controls whether WebGL can be used (requires HW support). Also configurable via "disable-webgl".
	webgl: State,

	// END values that map to WebPreferences settings.

	// Background color before document load and when no document color is specified. Alpha must be 0xFF (opaque) or 0x00 (transparent). Transparent for windowed uses CefSettings.background_color; transparent for windowless enables transparent painting.
	background_color: cef_color,

	// Controls whether the Chrome status bubble will be used. Only supported with Chrome style. See https://www.chromium.org/user-experience/status-bubble/
	chrome_status_bubble: State,

	// Controls whether the Chrome zoom bubble will be shown when zooming. Only supported with Chrome style.
	chrome_zoom_bubble: State,
}

/// Return value types.
cef_return_value :: enum u32 {
	/// Cancel immediately.
	RV_CANCEL = 0,

	/// Continue immediately.
	RV_CONTINUE,

	/// Continue asynchronously (usually via a callback).
	RV_CONTINUE_ASYNC,
};

// URL component parts.
Urlparts :: struct {
	// Size of this structure.
	size: c.size_t,

	// Complete URL specification.
	spec: cef_string,

	// Scheme component without the colon (e.g., "http").
	scheme: cef_string,

	// User name component.
	username: cef_string,

	// Password component.
	password: cef_string,

	// Host component: hostname, IPv4, or IPv6 literal in brackets (e.g., "[2001:db8::1]").
	host: cef_string,

	// Port number component.
	port: cef_string,

	// Origin = scheme + host + port (no user/pass; path replaced with "/" and nothing after). Empty for non-standard URLs.
	origin: cef_string,

	// Path component including the first '/' after the host.
	path: cef_string,

	// Query string component (everything after '?').
	query: cef_string,

	// Fragment/hash identifier (everything after '#').
	fragment: cef_string,
}

/// Cookie priority values.
Cookie_priority :: enum i32 {
	CEF_COOKIE_PRIORITY_LOW = -1,
	CEF_COOKIE_PRIORITY_MEDIUM = 0,
	CEF_COOKIE_PRIORITY_HIGH = 1,
};

/// Cookie same site values.
Cookie_same_site :: enum u32 {
	CEF_COOKIE_SAME_SITE_UNSPECIFIED,
	CEF_COOKIE_SAME_SITE_NO_RESTRICTION,
	CEF_COOKIE_SAME_SITE_LAX_MODE,
	CEF_COOKIE_SAME_SITE_STRICT_MODE,
};

// Cookie information.
cef_cookie :: struct {
	// Size of this structure.
	size: c.size_t,

	// Cookie name.
	name: cef_string,

	// Cookie value.
	value: cef_string,

	// If empty, a host cookie is created instead of a domain cookie. Domain cookies are stored with a leading "." and are visible to sub-domains; host cookies are not.
	domain: cef_string,

	// If non-empty, only URLs at or below this path receive the cookie.
	path: cef_string,

	// If true, cookie is sent only for HTTPS requests.
	secure: c.int,

	// If true, cookie is sent only for HTTP requests.
	httponly: c.int,

	// Creation date (auto-populated on creation).
	creation: Basetime,

	// Last access date (auto-populated on access).
	last_access: Basetime,

	// Expiration date is valid only if has_expires is true.
	has_expires: c.int,
	expires: Basetime,

	// SameSite attribute.
	same_site: Cookie_same_site,

	// Priority attribute.
	priority: Cookie_priority,
}

// Process termination status values.
Termination_status :: enum u32 {
	/// Non-zero exit status.
	TS_ABNORMAL_TERMINATION,

	/// SIGKILL or task manager kill.
	TS_PROCESS_WAS_KILLED,

	/// Segmentation fault.
	TS_PROCESS_CRASHED,

	/// Out of memory. Some platforms may use TS_PROCESS_CRASHED instead.
	TS_PROCESS_OOM,

	/// Child process never launched.
	TS_LAUNCH_FAILED,

	/// On Windows, the OS terminated the process due to code integrity failure.
	TS_INTEGRITY_FAILURE,
};

/// Path key values.
Path_key :: enum u32 {
	/// Current directory.
	PK_DIR_CURRENT,

	/// Directory containing PK_FILE_EXE.
	PK_DIR_EXE,

	/// Directory containing PK_FILE_MODULE.
	PK_DIR_MODULE,

	/// Temporary directory.
	PK_DIR_TEMP,

	/// Path and filename of the current executable.
	PK_FILE_EXE,

	/// Path and filename of the module containing the CEF code (usually the
	/// libcef module).
	PK_FILE_MODULE,

	/// "Local Settings\Application Data" directory under the user profile
	/// directory on Windows.
	PK_LOCAL_APP_DATA,

	/// "Application Data" directory under the user profile directory on Windows
	/// and "~/Library/Application Support" directory on MacOS.
	PK_USER_DATA,

	/// Directory containing application resources. Can be configured via
	/// CefSettings.resources_dir_path.
	PK_DIR_RESOURCES,
};

/// Storage types.
Storage_type :: enum u32 {
	ST_LOCALSTORAGE = 0,
	ST_SESSIONSTORAGE,
};

cef_errorcode :: enum u32 {
	ERR_NONE,
}

/// Supported certificate status code values. See net\cert\cert_status_flags.h
/// for more information. CERT_STATUS_NONE is new in CEF because we use an
/// enum while cert_status_flags.h uses a typedef and static const variables.
//This is translated from a bit_set to an enum and then cert_status is used instead (gives better odin compatability)
Cef_cert_status_enum :: enum u32 {
	CERT_STATUS_NONE = 0,
	CERT_STATUS_COMMON_NAME_INVALID = 0,
	CERT_STATUS_DATE_INVALID = 1,
	CERT_STATUS_AUTHORITY_INVALID = 2,
	// 3 is reserved for ERR_CERT_CONTAINS_ERRORS (not useful with WinHTTP).
	CERT_STATUS_NO_REVOCATION_MECHANISM = 4,
	CERT_STATUS_UNABLE_TO_CHECK_REVOCATION = 5,
	CERT_STATUS_REVOKED = 6,
	CERT_STATUS_INVALID = 7,
	CERT_STATUS_WEAK_SIGNATURE_ALGORITHM = 8,
	// 9 was used for CERT_STATUS_NOT_IN_DNS
	CERT_STATUS_NON_UNIQUE_NAME = 10,
	CERT_STATUS_WEAK_KEY = 11,
	// 12 was used for CERT_STATUS_WEAK_DH_KEY
	CERT_STATUS_PINNED_KEY_MISSING = 13,
	CERT_STATUS_NAME_CONSTRAINT_VIOLATION = 14,
	CERT_STATUS_VALIDITY_TOO_LONG = 15,

	// Bits 16 to 31 are for non-error statuses.
	CERT_STATUS_IS_EV = 16,
	CERT_STATUS_REV_CHECKING_ENABLED = 17,
	// Bit 18 was CERT_STATUS_IS_DNSSEC
	CERT_STATUS_SHA1_SIGNATURE_PRESENT = 19,
	CERT_STATUS_CT_COMPLIANCE_FAILED = 20,
};

Cert_status :: bit_set[Cef_cert_status_enum];

/// Process result codes. This is not a comprehensive list, as result codes might also include platform-specific crash values (Posix signal or Windows
/// hardware exception), or internal-only implementation values.
///
/// Process result codes. This is not a comprehensive list, as result codes might also include platform-specific crash values (Posix signal or Windows
/// hardware exception), or internal-only implementation values.
///
Result_code :: enum u32 {
	// The following values should be kept in sync with Chromium's
	// content::ResultCode type.
	RESULT_CODE_NORMAL_EXIT,

	/// Process was killed by user or system.
	RESULT_CODE_KILLED,

	/// Process hung.
	RESULT_CODE_HUNG,

	/// A bad message caused the process termination.
	RESULT_CODE_KILLED_BAD_MESSAGE,

	/// The GPU process exited because initialization failed.
	RESULT_CODE_GPU_DEAD_ON_ARRIVAL,

	// The following values should be kept in sync with Chromium's
	// chrome::ResultCode type. Unused chrome values are excluded.
	RESULT_CODE_CHROME_FIRST,

	/// The process is of an unknown type.
	RESULT_CODE_BAD_PROCESS_TYPE = 6,

	/// A critical chrome file is missing.
	RESULT_CODE_MISSING_DATA = 7,

	/// Command line parameter is not supported.
	RESULT_CODE_UNSUPPORTED_PARAM = 13,

	/// The profile was in use on another host.
	RESULT_CODE_PROFILE_IN_USE = 21,

	/// Failed to pack an extension via the command line.
	RESULT_CODE_PACK_EXTENSION_ERROR = 22,

	/// The browser process exited early by passing the command line to another
	/// running browser.
	RESULT_CODE_NORMAL_EXIT_PROCESS_NOTIFIED = 24,

	/// A browser process was sandboxed. This should never happen.
	RESULT_CODE_INVALID_SANDBOX_STATE = 31,

	/// Cloud policy enrollment failed or was given up by user.
	RESULT_CODE_CLOUD_POLICY_ENROLLMENT_FAILED = 32,

	/// The GPU process was terminated due to context lost.
	RESULT_CODE_GPU_EXIT_ON_CONTEXT_LOST = 34,

	/// An early startup command was executed and the browser must exit.
	RESULT_CODE_NORMAL_EXIT_PACK_EXTENSION_SUCCESS = 36,

	/// The browser process exited because system resources are exhausted. The
	/// system state can't be recovered and will be unstable.
	RESULT_CODE_SYSTEM_RESOURCE_EXHAUSTED = 37,

	/// The browser process exited because it was re-launched without elevation.
	RESULT_CODE_NORMAL_EXIT_AUTO_DE_ELEVATED = 38,

	/// Upon encountering a commit failure in a process, PartitionAlloc terminated
	/// another process deemed less important.
	RESULT_CODE_TERMINATED_BY_OTHER_PROCESS_ON_COMMIT_FAILURE = 39,

	RESULT_CODE_CHROME_LAST = 40,

	// The following values should be kept in sync with Chromium's
	// sandbox::TerminationCodes type.
	RESULT_CODE_SANDBOX_FATAL_FIRST = 7006,

	/// Windows sandbox could not set the integrity level.
	RESULT_CODE_SANDBOX_FATAL_INTEGRITY = RESULT_CODE_SANDBOX_FATAL_FIRST,

	/// Windows sandbox could not lower the token.
	RESULT_CODE_SANDBOX_FATAL_DROPTOKEN,

	/// Windows sandbox failed to flush registry handles.
	RESULT_CODE_SANDBOX_FATAL_FLUSHANDLES,

	/// Windows sandbox failed to forbid HCKU caching.
	RESULT_CODE_SANDBOX_FATAL_CACHEDISABLE,

	/// Windows sandbox failed to close pending handles.
	RESULT_CODE_SANDBOX_FATAL_CLOSEHANDLES,

	/// Windows sandbox could not set the mitigation policy.
	RESULT_CODE_SANDBOX_FATAL_MITIGATION,

	/// Windows sandbox exceeded the job memory limit.
	RESULT_CODE_SANDBOX_FATAL_MEMORY_EXCEEDED,

	/// Windows sandbox failed to warmup.
	RESULT_CODE_SANDBOX_FATAL_WARMUP,

	// Windows sandbox broker terminated in shutdown.
	RESULT_CODE_SANDBOX_FATAL_BROKER_SHUTDOWN_HUNG,

	RESULT_CODE_SANDBOX_FATAL_LAST,

	RESULT_CODE_NUM_VALUES,
}

/// The manner in which a link click should be opened. These constants match their equivalents in Chromium's window_open_disposition.h and should not be
/// renumbered.
///
/// The manner in which a link click should be opened. These constants match their equivalents in Chromium's window_open_disposition.h and should not be
/// renumbered.
///
Window_open_disposition :: enum u32 {
	WOD_UNKNOWN,

	/// Current tab. This is the default in most cases.
	WOD_CURRENT_TAB,

	/// Indicates that only one tab with the url should exist in the same window.
	WOD_SINGLETON_TAB,

	/// Shift key + Middle mouse button or meta/ctrl key while clicking.
	WOD_NEW_FOREGROUND_TAB,

	/// Middle mouse button or meta/ctrl key while clicking.
	WOD_NEW_BACKGROUND_TAB,

	/// New popup window.
	WOD_NEW_POPUP,

	/// Shift key while clicking.
	WOD_NEW_WINDOW,

	/// Alt key while clicking.
	WOD_SAVE_TO_DISK,

	/// New off-the-record (incognito) window.
	WOD_OFF_THE_RECORD,

	/// Special case error condition from the renderer.
	WOD_IGNORE_ACTION,

	/// Activates an existing tab containing the url, rather than navigating.
	/// This is similar to SINGLETON_TAB, but searches across all windows from
	/// the current profile and anonymity (instead of just the current one);
	/// closes the current tab on switching if the current tab was the NTP with
	/// no session history; and behaves like CURRENT_TAB instead of
	/// NEW_FOREGROUND_TAB when no existing tab is found.
	WOD_SWITCH_TO_TAB,

	/// Creates a new document picture-in-picture window showing a child WebView.
	WOD_NEW_PICTURE_IN_PICTURE,

	WOD_NUM_VALUES,
}

/// "Verb" of a drag-and-drop operation as negotiated between the source and destination. These constants match their equivalents in WebCore's
/// DragActions.h and should not be renumbered.
///
/// "Verb" of a drag-and-drop operation as negotiated between the source and destination. These constants match their equivalents in WebCore's
/// DragActions.h and should not be renumbered.
///
Drag_operations_mask :: enum u32 {
	DRAG_OPERATION_NONE = 0,
	DRAG_OPERATION_COPY = 1,
	DRAG_OPERATION_LINK = 2,
	DRAG_OPERATION_GENERIC = 4,
	DRAG_OPERATION_PRIVATE = 8,
	DRAG_OPERATION_MOVE = 16,
	DRAG_OPERATION_DELETE = 32,
	DRAG_OPERATION_EVERY = max(u32), // UINT_MAX equivalent
}

/// Input mode of a virtual keyboard. These constants match their equivalents in Chromium's text_input_mode.h and should not be renumbered.
/// See https://html.spec.whatwg.org/#input-modalities:-the-inputmode-attribute
///
/// Input mode of a virtual keyboard. These constants match their equivalents in Chromium's text_input_mode.h and should not be renumbered.
/// See https://html.spec.whatwg.org/#input-modalities:-the-inputmode-attribute
///
Text_input_mode :: enum u32 {
	TEXT_INPUT_MODE_DEFAULT,
	TEXT_INPUT_MODE_NONE,
	TEXT_INPUT_MODE_TEXT,
	TEXT_INPUT_MODE_TEL,
	TEXT_INPUT_MODE_URL,
	TEXT_INPUT_MODE_EMAIL,
	TEXT_INPUT_MODE_NUMERIC,
	TEXT_INPUT_MODE_DECIMAL,
	TEXT_INPUT_MODE_SEARCH,

	TEXT_INPUT_MODE_NUM_VALUES,
}

/// V8 property attribute values.
V8_property_attribute :: enum u32 {
	/// Writeable, Enumerable, Configurable
	V8_PROPERTY_ATTRIBUTE_NONE = 0,

	/// Not writeable
	V8_PROPERTY_ATTRIBUTE_READONLY = 1 << 0,

	/// Not enumerable
	V8_PROPERTY_ATTRIBUTE_DONTENUM = 1 << 1,

	/// Not configurable
	V8_PROPERTY_ATTRIBUTE_DONTDELETE = 1 << 2
}

/// Post data elements may represent either bytes or files.
/// Post data elements may represent either bytes or files.
Postdataelement_type :: enum u32 {
	PDE_TYPE_EMPTY = 0,
	PDE_TYPE_BYTES,
	PDE_TYPE_FILE,

	PDE_TYPE_NUM_VALUES,
}

/// Resource type for a request. These constants match their equivalents in Chromium's ResourceType and should not be renumbered.
///
/// Resource type for a request. These constants match their equivalents in Chromium's ResourceType and should not be renumbered.
///
Resource_type :: enum u32 {
	/// Top level page.
	RT_MAIN_FRAME = 0,

	/// Frame or iframe.
	RT_SUB_FRAME,

	/// CSS stylesheet.
	RT_STYLESHEET,

	/// External script.
	RT_SCRIPT,

	/// Image (jpg/gif/png/etc).
	RT_IMAGE,

	/// Font.
	RT_FONT_RESOURCE,

	/// Some other subresource. This is the default type if the actual type is
	/// unknown.
	RT_SUB_RESOURCE,

	/// Object (or embed) tag for a plugin, or a resource that a plugin requested.
	RT_OBJECT,

	/// Media resource.
	RT_MEDIA,

	/// Main resource of a dedicated worker.
	RT_WORKER,

	/// Main resource of a shared worker.
	RT_SHARED_WORKER,

	/// Explicitly requested prefetch.
	RT_PREFETCH,

	/// Favicon.
	RT_FAVICON,

	/// XMLHttpRequest.
	RT_XHR,

	/// A request for a "<ping>".
	RT_PING,

	/// Main resource of a service worker.
	RT_SERVICE_WORKER,

	/// A report of Content Security Policy violations.
	RT_CSP_REPORT,

	/// A resource that a plugin requested.
	RT_PLUGIN_RESOURCE,

	/// A main-frame service worker navigation preload request.
	RT_NAVIGATION_PRELOAD_MAIN_FRAME = 19,

	/// A sub-frame service worker navigation preload request.
	RT_NAVIGATION_PRELOAD_SUB_FRAME,

	RT_NUM_VALUES,
}

/// Transition type for a request. Made up of one source value and 0 or more qualifiers.
///
/// Transition type for a request. Made up of one source value and 0 or more qualifiers.
///
Transition_type :: enum u32 {
	/// Source is a link click or the JavaScript window.open function. This is
	/// also the default value for requests like sub-resource loads that are not
	/// navigations.
	TT_LINK,

	/// Source is some other "explicit" navigation. This is the default value for
	/// navigations where the actual type is unknown. See also
	/// TT_DIRECT_LOAD_FLAG.
	TT_EXPLICIT,

	/// User got to this page through a suggestion in the UI (for example, via the
	/// destinations page). Chrome style only.
	TT_AUTO_BOOKMARK,

	/// Source is a subframe navigation. This is any content that is automatically
	/// loaded in a non-toplevel frame. For example, if a page consists of several
	/// frames containing ads, those ad URLs will have this transition type.
	/// The user may not even realize the content in these pages is a separate
	/// frame, so may not care about the URL.
	TT_AUTO_SUBFRAME,

	/// Source is a subframe navigation explicitly requested by the user that will
	/// generate new navigation entries in the back/forward list. These are
	/// probably more important than frames that were automatically loaded in
	/// the background because the user probably cares about the fact that this
	/// link was loaded.
	TT_MANUAL_SUBFRAME,

	/// User got to this page by typing in the URL bar and selecting an entry
	/// that did not look like a URL.	For example, a match might have the URL
	/// of a Google search result page, but appear like "Search Google for ...".
	/// These are not quite the same as EXPLICIT navigations because the user
	/// didn't type or see the destination URL. Chrome style only.
	/// See also TT_KEYWORD.
	TT_GENERATED,

	/// This is a toplevel navigation. This is any content that is automatically
	/// loaded in a toplevel frame.	For example, opening a tab to show the ASH
	/// screen saver, opening the devtools window, opening the NTP after the safe
	/// browsing warning, opening web-based dialog boxes are examples of
	/// AUTO_TOPLEVEL navigations. Chrome style only.
	TT_AUTO_TOPLEVEL,

	/// Source is a form submission by the user. NOTE: In some situations
	/// submitting a form does not result in this transition type. This can happen
	/// if the form uses a script to submit the contents.
	TT_FORM_SUBMIT,

	/// Source is a "reload" of the page via the Reload function or by re-visiting
	/// the same URL. NOTE: This is distinct from the concept of whether a
	/// particular load uses "reload semantics" (i.e. bypasses cached data).
	TT_RELOAD,

	/// The url was generated from a replaceable keyword other than the default
	/// search provider. If the user types a keyword (which also applies to
	/// tab-to-search) in the omnibox this qualifier is applied to the transition
	/// type of the generated url. TemplateURLModel then may generate an
	/// additional visit with a transition type of TT_KEYWORD_GENERATED against
	/// the url 'http://' + keyword. For example, if you do a tab-to-search
	/// against wikipedia the generated url has a transition qualifer of
	/// TT_KEYWORD, and TemplateURLModel generates a visit for 'wikipedia.org'
	/// with a transition type of TT_KEYWORD_GENERATED. Chrome style only.
	TT_KEYWORD,

	/// Corresponds to a visit generated for a keyword. See description of
	/// TT_KEYWORD for more details. Chrome style only.
	TT_KEYWORD_GENERATED,

	TT_NUM_VALUES,

	/// General mask defining the bits used for the source values.
	TT_SOURCE_MASK = 0xFF,

	/// Qualifiers.
	/// Any of the core values above can be augmented by one or more qualifiers.
	/// These qualifiers further define the transition.

	/// Attempted to visit a URL but was blocked.
	TT_BLOCKED_FLAG = 0x00800000,

	/// Used the Forward or Back function to navigate among browsing history.
	/// Will be ORed to the transition type for the original load.
	TT_FORWARD_BACK_FLAG = 0x01000000,

	/// Loaded a URL directly via CreateBrowser, LoadURL or LoadRequest.
	TT_DIRECT_LOAD_FLAG = 0x02000000,

	/// User is navigating to the home page. Chrome style only.
	TT_HOME_PAGE_FLAG = 0x04000000,

	/// The transition originated from an external application; the exact
	/// definition of this is embedder dependent. Chrome style only.
	TT_FROM_API_FLAG = 0x08000000,

	/// The beginning of a navigation chain.
	TT_CHAIN_START_FLAG = 0x10000000,

	/// The last transition in a redirect chain.
	TT_CHAIN_END_FLAG = 0x20000000,

	/// Redirects caused by JavaScript or a meta refresh tag on the page.
	TT_CLIENT_REDIRECT_FLAG = 0x40000000,

	/// Redirects sent from the server by HTTP headers.
	TT_SERVER_REDIRECT_FLAG = 0x80000000,

	/// Used to test whether a transition involves a redirect.
	TT_IS_REDIRECT_MASK = 0xC0000000,

	/// General mask defining the bits used for the qualifiers.
	TT_QUALIFIER_MASK = 0xFFFFFF00,
}

///½
/// Flags used to customize the behavior of CefURLRequest.
///
/// Flags used to customize the behavior of CefURLRequest.
Urlrequest_flags :: enum u32 {
	/// Default behavior.
	UR_FLAG_NONE = 0,

	/// If set the cache will be skipped when handling the request. Setting this
	/// value is equivalent to specifying the "Cache-Control: no-cache" request
	/// header. Setting this value in combination with UR_FLAG_ONLY_FROM_CACHE
	/// will cause the request to fail.
	UR_FLAG_SKIP_CACHE = 1 << 0,

	/// If set the request will fail if it cannot be served from the cache (or
	/// some equivalent local store). Setting this value is equivalent to
	/// specifying the "Cache-Control: only-if-cached" request header. Setting
	/// this value in combination with UR_FLAG_SKIP_CACHE or UR_FLAG_DISABLE_CACHE
	/// will cause the request to fail.
	UR_FLAG_ONLY_FROM_CACHE = 1 << 1,

	/// If set the cache will not be used at all. Setting this value is equivalent
	/// to specifying the "Cache-Control: no-store" request header. Setting this
	/// value in combination with UR_FLAG_ONLY_FROM_CACHE will cause the request
	/// to fail.
	UR_FLAG_DISABLE_CACHE = 1 << 2,

	/// If set user name, password, and cookies may be sent with the request, and
	/// cookies may be saved from the response.
	UR_FLAG_ALLOW_STORED_CREDENTIALS = 1 << 3,

	/// If set upload progress events will be generated when a request has a body.
	UR_FLAG_REPORT_UPLOAD_PROGRESS = 1 << 4,

	/// If set the CefURLRequestClient::OnDownloadData method will not be called.
	UR_FLAG_NO_DOWNLOAD_DATA = 1 << 5,

	/// If set 5XX redirect errors will be propagated to the observer instead of
	/// automatically re-tried. This currently only applies for requests
	/// originated in the browser process.
	UR_FLAG_NO_RETRY_ON_5XX = 1 << 6,

	/// If set 3XX responses will cause the fetch to halt immediately rather than
	/// continue through the redirect.
	UR_FLAG_STOP_ON_REDIRECT = 1 << 7,
}

/// Flags that represent CefURLRequest status.
/// Flags that represent CefURLRequest status.
Url_request_status :: enum u32 {
	/// Unknown status.
	UR_UNKNOWN,

	/// Request succeeded.
	UR_SUCCESS,

	/// An IO request is pending, and the caller will be informed when it is
	/// completed.
	UR_IO_PENDING,

	/// Request was canceled programatically.
	UR_CANCELED,

	/// Request failed for some reason.
	UR_FAILED,

	UR_NUM_VALUES,
}

/// Structure representing a draggable region.
///
Draggable_region :: struct {
	/// Bounds of the region.
	bounds: cef_rect,

	/// True (1) this this region is draggable and false (0) otherwise.
	draggable: c.int,
}

/// Existing process IDs.
/// Existing process IDs.
cef_process_id :: enum u32 {
	/// Browser process.
	PID_BROWSER,
	/// Renderer process.
	PID_RENDERER,
}

/// Existing thread IDs.
/// Existing thread IDs.
cef_thread_id :: enum u32 {
	// BROWSER PROCESS THREADS -- Only available in the browser process.

	/// The main thread in the browser. This will be the same as the main
	/// application thread if CefInitialize() is called with a
	/// CefSettings.multi_threaded_message_loop value of false. Do not perform
	/// blocking tasks on this thread. All tasks posted after
	/// CefBrowserProcessHandler::OnContextInitialized() and before CefShutdown()
	/// are guaranteed to run. This thread will outlive all other CEF threads.
	TID_UI,

	/// Used for blocking tasks like file system access where the user won't
	/// notice if the task takes an arbitrarily long time to complete. All tasks
	/// posted after CefBrowserProcessHandler::OnContextInitialized() and before
	/// CefShutdown() are guaranteed to run.
	TID_FILE_BACKGROUND,

	/// Used for blocking tasks like file system access that affect UI or
	/// responsiveness of future user interactions. Do not use if an immediate
	/// response to a user interaction is expected. All tasks posted after
	/// CefBrowserProcessHandler::OnContextInitialized() and before CefShutdown()
	/// are guaranteed to run.
	/// Examples:
	/// - Updating the UI to reflect progress on a long task.
	/// - Loading data that might be shown in the UI after a future user
	///	 interaction.
	TID_FILE_USER_VISIBLE,

	/// Used for blocking tasks like file system access that affect UI
	/// immediately after a user interaction. All tasks posted after
	/// CefBrowserProcessHandler::OnContextInitialized() and before CefShutdown()
	/// are guaranteed to run.
	/// Example: Generating data shown in the UI immediately after a click.
	TID_FILE_USER_BLOCKING,

	/// Used to launch and terminate browser processes.
	TID_PROCESS_LAUNCHER,

	/// Used to process IPC and network messages. Do not perform blocking tasks on
	/// this thread. All tasks posted after
	/// CefBrowserProcessHandler::OnContextInitialized() and before CefShutdown()
	/// are guaranteed to run.
	TID_IO,

	// RENDER PROCESS THREADS -- Only available in the render process.

	/// The main thread in the renderer. Used for all WebKit and V8 interaction.
	/// Tasks may be posted to this thread after
	/// CefRenderProcessHandler::OnWebKitInitialized but are not guaranteed to
	/// run before sub-process termination (sub-processes may be killed at any
	/// time without warning).
	TID_RENDERER,

	TID_NUM_VALUES,
}

/// Thread priority values listed in increasing order of importance.
/// Thread priority values listed in increasing order of importance.
Thread_priority :: enum u32 {
	/// Suitable for threads that shouldn't disrupt high priority work.
	TP_BACKGROUND,

	/// Default priority level.
	TP_NORMAL,

	/// Suitable for threads which generate data for the display (at ~60Hz).
	TP_DISPLAY,

	/// Suitable for low-latency, glitch-resistant audio.
	TP_REALTIME_AUDIO,

	TP_NUM_VALUES,
}

/// Message loop types. Indicates the set of asynchronous events that a message loop can process.
///
/// Message loop types. Indicates the set of asynchronous events that a message loop can process.
///
Message_loop_type :: enum u32 {
	/// Supports tasks and timers.
	ML_TYPE_DEFAULT,

	/// Supports tasks, timers and native UI events (e.g. Windows messages).
	ML_TYPE_UI,

	/// Supports tasks, timers and asynchronous IO events.
	ML_TYPE_IO,

	ML_NUM_VALUES,
}

/// Windows COM initialization mode. Specifies how COM will be initialized for a new thread.
///
/// Windows COM initialization mode. Specifies how COM will be initialized for a new thread.
///
Com_init_mode :: enum u32 {
	/// No COM initialization.
	COM_INIT_MODE_NONE,

	/// Initialize COM using single-threaded apartments.
	COM_INIT_MODE_STA,

	/// Initialize COM using multi-threaded apartments.
	COM_INIT_MODE_MTA,
}

/// Supported value types.
/// Supported value types.
cef_value_type :: enum u32 {
	VTYPE_INVALID,
	VTYPE_NULL,
	VTYPE_BOOL,
	VTYPE_INT,
	VTYPE_DOUBLE,
	VTYPE_STRING,
	VTYPE_BINARY,
	VTYPE_DICTIONARY,
	VTYPE_LIST,

	VTYPE_NUM_VALUES,
}

/// Supported JavaScript dialog types.
/// Supported JavaScript dialog types.
Jsdialog_type :: enum u32 {
	JSDIALOGTYPE_ALERT,
	JSDIALOGTYPE_CONFIRM,
	JSDIALOGTYPE_PROMPT,

	JSDIALOGTYPE_NUM_VALUES,
}

/// Screen information used when window rendering is disabled. This structure is passed as a parameter to CefRenderHandler::GetScreenInfo and should be
/// filled in by the client.
///
/// Screen information used when window rendering is disabled. This structure is passed as a parameter to CefRenderHandler::GetScreenInfo and should be
/// filled in by the client.
///
Screen_info :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Device scale factor. Specifies the ratio between physical and logical
	/// pixels.
	device_scale_factor: f32,

	/// The screen depth in bits per pixel.
	depth: c.int,

	/// The bits per color component. This assumes that the colors are balanced
	/// equally.
	depth_per_component: c.int,

	/// This can be true for black and white printers.
	is_monochrome: c.int,

	/// This is set from the rcMonitor member of MONITORINFOEX, to whit:
	///	 "A RECT structure that specifies the display monitor rectangle,
	///	 expressed in virtual-screen coordinates. Note that if the monitor
	///	 is not the primary display monitor, some of the rectangle's
	///	 coordinates may be negative values."
	//
	/// The |rect| and |available_rect| properties are used to determine the
	/// available surface for rendering popup views.
	rect: cef_rect,

	/// This is set from the rcWork member of MONITORINFOEX, to whit:
	///	 "A RECT structure that specifies the work area rectangle of the
	///	 display monitor that can be used by applications, expressed in
	///	 virtual-screen coordinates. Windows uses this rectangle to
	///	 maximize an application on the monitor. The rest of the area in
	///	 rcMonitor contains system windows such as the task bar and side
	///	 bars. Note that if the monitor is not the primary display monitor,
	///	 some of the rectangle's coordinates may be negative values".
	//
	/// The |rect| and |available_rect| properties are used to determine the
	/// available surface for rendering popup views.
	available_rect: cef_rect,
}

/// Linux window properties, such as X11's WM_CLASS or Wayland's app_id. Those are passed to CefWindowDelegate, so the client can set them
/// for the CefWindow's top-level. Thus, allowing window managers to correctly
/// display the application's information (e.g., icons).
///
/// Linux window properties, such as X11's WM_CLASS or Wayland's app_id. Those are passed to CefWindowDelegate, so the client can set them
/// for the CefWindow's top-level. Thus, allowing window managers to correctly
/// display the application's information (e.g., icons).
///
linux_window_properties :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Main window's Wayland's app_id
	wayland_app_id: cef_string,

	/// Main window's WM_CLASS_CLASS in X11
	wm_class_class: cef_string,

	/// Main window's WM_CLASS_NAME in X11
	wm_class_name: cef_string,

	/// Main window's WM_WINDOW_ROLE in X11
	wm_role_name: cef_string,
}

/// Supported menu IDs. Non-English translations can be provided for the IDS_MENU_* strings in CefResourceBundleHandler::GetLocalizedString().
///
/// Supported menu IDs. Non-English translations can be provided for the IDS_MENU_* strings in CefResourceBundleHandler::GetLocalizedString().
///
menu_id :: enum u32 {
	// Navigation.
	MENU_ID_BACK = 100,
	MENU_ID_FORWARD = 101,
	MENU_ID_RELOAD = 102,
	MENU_ID_RELOAD_NOCACHE = 103,
	MENU_ID_STOPLOAD = 104,

	// Editing.
	MENU_ID_UNDO = 110,
	MENU_ID_REDO = 111,
	MENU_ID_CUT = 112,
	MENU_ID_COPY = 113,
	MENU_ID_PASTE = 114,
	MENU_ID_PASTE_MATCH_STYLE = 115,
	MENU_ID_DELETE = 116,
	MENU_ID_SELECT_ALL = 117,

	// Miscellaneous.
	MENU_ID_FIND = 130,
	MENU_ID_PRINT = 131,
	MENU_ID_VIEW_SOURCE = 132,

	// Spell checking word correction suggestions.
	MENU_ID_SPELLCHECK_SUGGESTION_0 = 200,
	MENU_ID_SPELLCHECK_SUGGESTION_1 = 201,
	MENU_ID_SPELLCHECK_SUGGESTION_2 = 202,
	MENU_ID_SPELLCHECK_SUGGESTION_3 = 203,
	MENU_ID_SPELLCHECK_SUGGESTION_4 = 204,
	MENU_ID_SPELLCHECK_SUGGESTION_LAST = 204,
	MENU_ID_NO_SPELLING_SUGGESTIONS = 205,
	MENU_ID_ADD_TO_DICTIONARY = 206,

	// Custom menu items originating from the renderer process.
	MENU_ID_CUSTOM_FIRST = 220,
	MENU_ID_CUSTOM_LAST = 250,

	// All user-defined menu IDs should come between MENU_ID_USER_FIRST and
	// MENU_ID_USER_LAST to avoid overlapping the Chromium and CEF ID ranges
	// defined in the tools/gritsettings/resource_ids file.
	MENU_ID_USER_FIRST = 26500,
	MENU_ID_USER_LAST = 28500,
}

/// Mouse button types.
mouse_button_type :: enum u32 {
	MBT_LEFT = 0,
	MBT_MIDDLE,
	MBT_RIGHT,
}

/// Structure representing mouse event information.
/// Structure representing mouse event information.
Mouse_event :: struct {
	/// X coordinate relative to the left side of the view.
	x: c.int,

	/// Y coordinate relative to the top side of the view.
	y: c.int,

	/// Bit flags describing any pressed modifier keys. See
	/// Event_flags for values.
	modifiers: Event_flags,
}

/// Touch points states types.
/// Touch points states types.
touch_event_type :: enum u32 {
	TET_RELEASED = 0,
	TET_PRESSED,
	TET_MOVED,
	TET_CANCELLED
}

/// The device type that caused the event.
/// The device type that caused the event.
pointer_type :: enum u32 {
	POINTER_TYPE_TOUCH = 0,
	POINTER_TYPE_MOUSE,
	POINTER_TYPE_PEN,
	POINTER_TYPE_ERASER,
	POINTER_TYPE_UNKNOWN
}

/// Structure representing touch event information.
/// Structure representing touch event information.
Touch_event :: struct {
	/// Id of a touch point. Must be unique per touch, can be any number except
	/// -1. Note that a maximum of 16 concurrent touches will be tracked; touches
	/// beyond that will be ignored.
	id: c.int,

	/// X coordinate relative to the left side of the view.
	x: f32,

	/// Y coordinate relative to the top side of the view.
	y: f32,

	/// X radius in pixels. Set to 0 if not applicable.
	radius_x: f32,

	/// Y radius in pixels. Set to 0 if not applicable.
	radius_y: f32,

	/// Rotation angle in radians. Set to 0 if not applicable.
	rotation_angle: f32,

	/// The normalized pressure of the pointer input in the range of [0,1].
	/// Set to 0 if not applicable.
	pressure: f32,

	/// The state of the touch point. Touches begin with one TET_PRESSED event
	/// followed by zero or more TET_MOVED events and finally one
	/// TET_RELEASED or TET_CANCELLED event. Events not respecting this
	/// order will be ignored.
	type: touch_event_type,

	/// Bit flags describing any pressed modifier keys. See
	/// Event_flags for values.
	modifiers: Event_flags,

	/// The device type that caused the event.
	pointer_type: pointer_type,
}

/// Paint element types.
Paint_element_type :: enum u32 {
	PET_VIEW = 0,
	PET_POPUP,
}

/// Supported event bit flags.
Event_flags :: enum u32 {
	EVENTFLAG_NONE = 0,
	EVENTFLAG_CAPS_LOCK_ON = 1 << 0,
	EVENTFLAG_SHIFT_DOWN = 1 << 1,
	EVENTFLAG_CONTROL_DOWN = 1 << 2,
	EVENTFLAG_ALT_DOWN = 1 << 3,
	EVENTFLAG_LEFT_MOUSE_BUTTON = 1 << 4,
	EVENTFLAG_MIDDLE_MOUSE_BUTTON = 1 << 5,
	EVENTFLAG_RIGHT_MOUSE_BUTTON = 1 << 6,
	/// Mac OS-X command key.
	EVENTFLAG_COMMAND_DOWN = 1 << 7,
	EVENTFLAG_NUM_LOCK_ON = 1 << 8,
	EVENTFLAG_IS_KEY_PAD = 1 << 9,
	EVENTFLAG_IS_LEFT = 1 << 10,
	EVENTFLAG_IS_RIGHT = 1 << 11,
	EVENTFLAG_ALTGR_DOWN = 1 << 12,
	EVENTFLAG_IS_REPEAT = 1 << 13,
	EVENTFLAG_PRECISION_SCROLLING_DELTA = 1 << 14,
	EVENTFLAG_SCROLL_BY_PAGE = 1 << 15,
}

/// Supported menu item types.
Menu_item_type :: enum u32 {
	MENUITEMTYPE_NONE,
	MENUITEMTYPE_COMMAND,
	MENUITEMTYPE_CHECK,
	MENUITEMTYPE_RADIO,
	MENUITEMTYPE_SEPARATOR,
	MENUITEMTYPE_SUBMENU,
}


/// Supported context menu type flags.
Context_menu_type_flags :: enum u32 {
	/// No node is selected.
	CM_TYPEFLAG_NONE = 0,
	/// The top page is selected.
	CM_TYPEFLAG_PAGE = 1 << 0,
	/// A subframe page is selected.
	CM_TYPEFLAG_FRAME = 1 << 1,
	/// A link is selected.
	CM_TYPEFLAG_LINK = 1 << 2,
	/// A media node is selected.
	CM_TYPEFLAG_MEDIA = 1 << 3,
	/// There is a textual or mixed selection that is selected.
	CM_TYPEFLAG_SELECTION = 1 << 4,
	/// An editable element is selected.
	CM_TYPEFLAG_EDITABLE = 1 << 5,
}

/// Supported context menu media types. These constants match their equivalents
/// in Chromium's ContextMenuDataMediaType and should not be renumbered.
Context_menu_media_type :: enum u32 {
	/// No special node is in context.
	CM_MEDIATYPE_NONE,
	/// An image node is selected.
	CM_MEDIATYPE_IMAGE,
	/// A video node is selected.
	CM_MEDIATYPE_VIDEO,
	/// An audio node is selected.
	CM_MEDIATYPE_AUDIO,
	/// An canvas node is selected.
	CM_MEDIATYPE_CANVAS,
	/// A file node is selected.
	CM_MEDIATYPE_FILE,
	/// A plugin node is selected.
	CM_MEDIATYPE_PLUGIN,

	CM_MEDIATYPE_NUM_VALUES,
}


/// Supported context menu media state bit flags. These constants match their
/// equivalents in Chromium's ContextMenuData::MediaFlags and should not be
/// renumbered.
Context_menu_media_state_flags :: enum u32 {
	CM_MEDIAFLAG_NONE = 0,
	CM_MEDIAFLAG_IN_ERROR = 1 << 0,
	CM_MEDIAFLAG_PAUSED = 1 << 1,
	CM_MEDIAFLAG_MUTED = 1 << 2,
	CM_MEDIAFLAG_LOOP = 1 << 3,
	CM_MEDIAFLAG_CAN_SAVE = 1 << 4,
	CM_MEDIAFLAG_HAS_AUDIO = 1 << 5,
	CM_MEDIAFLAG_CAN_TOGGLE_CONTROLS = 1 << 6,
	CM_MEDIAFLAG_CONTROLS = 1 << 7,
	CM_MEDIAFLAG_CAN_PRINT = 1 << 8,
	CM_MEDIAFLAG_CAN_ROTATE = 1 << 9,
	CM_MEDIAFLAG_CAN_PICTURE_IN_PICTURE = 1 << 10,
	CM_MEDIAFLAG_PICTURE_IN_PICTURE = 1 << 11,
	CM_MEDIAFLAG_CAN_LOOP = 1 << 12,
}

/// Supported context menu edit state bit flags. These constants match their
/// equivalents in Chromium's ContextMenuDataEditFlags and should not be
/// renumbered.
Context_menu_edit_state_flags :: enum u32 {
	CM_EDITFLAG_NONE = 0,
	CM_EDITFLAG_CAN_UNDO = 1 << 0,
	CM_EDITFLAG_CAN_REDO = 1 << 1,
	CM_EDITFLAG_CAN_CUT = 1 << 2,
	CM_EDITFLAG_CAN_COPY = 1 << 3,
	CM_EDITFLAG_CAN_PASTE = 1 << 4,
	CM_EDITFLAG_CAN_DELETE = 1 << 5,
	CM_EDITFLAG_CAN_SELECT_ALL = 1 << 6,
	CM_EDITFLAG_CAN_TRANSLATE = 1 << 7,
	CM_EDITFLAG_CAN_EDIT_RICHLY = 1 << 8,
}

/// Supported quick menu state bit flags.
Quick_menu_edit_state_flags :: enum u32 {
	QM_EDITFLAG_NONE = 0,
	QM_EDITFLAG_CAN_ELLIPSIS = 1 << 0,
	QM_EDITFLAG_CAN_CUT = 1 << 1,
	QM_EDITFLAG_CAN_COPY = 1 << 2,
	QM_EDITFLAG_CAN_PASTE = 1 << 3,
}

/// Key event types.
Key_event_type :: enum u32 {
	/// Notification that a key transitioned from "up" to "down".
	KEYEVENT_RAWKEYDOWN = 0,

	/// Notification that a key was pressed. This does not necessarily correspond
	/// to a character depending on the key and language. Use KEYEVENT_CHAR for
	/// character input.
	KEYEVENT_KEYDOWN,

	/// Notification that a key was released.
	KEYEVENT_KEYUP,

	/// Notification that a character was typed. Use this for text input. Key
	/// down events may generate 0, 1, or more than one character event depending
	/// on the key, locale, and operating system.
	KEYEVENT_CHAR
}

/// Structure representing keyboard event information.
Key_event :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// The type of keyboard event.
	type: Key_event_type,

	/// Bit flags describing any pressed modifier keys. See
	/// Event_flags for values.
	modifiers: Event_flags,

	/// The Windows key code for the key event. This value is used by the DOM
	/// specification. Sometimes it comes directly from the event (i.e. on
	/// Windows) and sometimes it's determined using a mapping function. See
	/// WebCore/platform/chromium/KeyboardCodes.h for the list of values.
	windows_key_code: c.int,

	/// The actual key code genenerated by the platform.
	native_key_code: c.int,

	/// Indicates whether the event is considered a "system key" event (see
	/// http://msdn.microsoft.com/en-us/library/ms646286(VS.85).aspx for details).
	/// This value will always be false on non-Windows platforms.
	is_system_key: c.int,

	/// The character generated by the keystroke.
	character: u16,

	/// Same as |character| but unmodified by any concurrently-held modifiers
	/// (except shift). This is useful for working out shortcut keys.
	unmodified_character: u16,

	/// True if the focus is currently on an editable field on the page. This is
	/// useful for determining if standard key events should be intercepted.
	focus_on_editable_field: c.int,
}

/// Focus sources.
Focus_source :: enum u32 {
	/// The source is explicit navigation via the API (LoadURL(), etc).
	FOCUS_SOURCE_NAVIGATION,
	/// The source is a system-generated focus event.
	FOCUS_SOURCE_SYSTEM,

	FOCUS_SOURCE_NUM_VALUES,
}

/// Navigation types.
Navigation_type :: enum u32 {
	NAVIGATION_LINK_CLICKED,
	NAVIGATION_FORM_SUBMITTED,
	NAVIGATION_BACK_FORWARD,
	NAVIGATION_RELOAD,
	NAVIGATION_FORM_RESUBMITTED,
	NAVIGATION_OTHER,
	NAVIGATION_NUM_VALUES,
}


/// Supported XML encoding types. The parser supports ASCII, ISO-8859-1, and
/// UTF16 (LE and BE) by default. All other types must be translated to UTF8
/// before being passed to the parser. If a BOM is detected and the correct
/// decoder is available then that decoder will be used automatically.
Xml_encoding_type :: enum u32 {
	XML_ENCODING_NONE,
	XML_ENCODING_UTF8,
	XML_ENCODING_UTF16LE,
	XML_ENCODING_UTF16BE,
	XML_ENCODING_ASCII,
	XML_ENCODING_NUM_VALUES,
}

/// XML node types.
/// XML node types.
Xml_node_type :: enum u32 {
	XML_NODE_UNSUPPORTED,
	XML_NODE_PROCESSING_INSTRUCTION,
	XML_NODE_DOCUMENT_TYPE,
	XML_NODE_ELEMENT_START,
	XML_NODE_ELEMENT_END,
	XML_NODE_ATTRIBUTE,
	XML_NODE_TEXT,
	XML_NODE_CDATA,
	XML_NODE_ENTITY_REFERENCE,
	XML_NODE_WHITESPACE,
	XML_NODE_COMMENT,
	XML_NODE_NUM_VALUES,
}

/// Popup window features.
Popup_features :: struct {
	/// Size of this structure.
	size: c.size_t,

	x: c.int,
	xSet: c.int,
	y: c.int,
	ySet: c.int,
	width: c.int,
	widthSet: c.int,
	height: c.int,
	heightSet: c.int,

	/// True (1) if browser interface elements should be hidden.
	isPopup: c.int,
}

/// DOM document types.
Dom_document_type :: enum u32 {
	DOM_DOCUMENT_TYPE_UNKNOWN,
	DOM_DOCUMENT_TYPE_HTML,
	DOM_DOCUMENT_TYPE_XHTML,
	DOM_DOCUMENT_TYPE_PLUGIN,
	DOM_DOCUMENT_TYPE_NUM_VALUES,
}

/// DOM event category flags.
Dom_event_category :: enum u32 {
	DOM_EVENT_CATEGORY_UNKNOWN = 0x0,
	DOM_EVENT_CATEGORY_UI = 0x1,
	DOM_EVENT_CATEGORY_MOUSE = 0x2,
	DOM_EVENT_CATEGORY_MUTATION = 0x4,
	DOM_EVENT_CATEGORY_KEYBOARD = 0x8,
	DOM_EVENT_CATEGORY_TEXT = 0x10,
	DOM_EVENT_CATEGORY_COMPOSITION = 0x20,
	DOM_EVENT_CATEGORY_DRAG = 0x40,
	DOM_EVENT_CATEGORY_CLIPBOARD = 0x80,
	DOM_EVENT_CATEGORY_MESSAGE = 0x100,
	DOM_EVENT_CATEGORY_WHEEL = 0x200,
	DOM_EVENT_CATEGORY_BEFORE_TEXT_INSERTED = 0x400,
	DOM_EVENT_CATEGORY_OVERFLOW = 0x800,
	DOM_EVENT_CATEGORY_PAGE_TRANSITION = 0x1000,
	DOM_EVENT_CATEGORY_POPSTATE = 0x2000,
	DOM_EVENT_CATEGORY_PROGRESS = 0x4000,
	DOM_EVENT_CATEGORY_XMLHTTPREQUEST_PROGRESS = 0x8000,
}

/// DOM event processing phases.
Dom_event_phase :: enum u32 {
	DOM_EVENT_PHASE_UNKNOWN,
	DOM_EVENT_PHASE_CAPTURING,
	DOM_EVENT_PHASE_AT_TARGET,
	DOM_EVENT_PHASE_BUBBLING,
	DOM_EVENT_PHASE_NUM_VALUES,
}

/// DOM node types.
Dom_node_type :: enum u32 {
	DOM_NODE_TYPE_UNSUPPORTED,
	DOM_NODE_TYPE_ELEMENT,
	DOM_NODE_TYPE_ATTRIBUTE,
	DOM_NODE_TYPE_TEXT,
	DOM_NODE_TYPE_CDATA_SECTION,
	DOM_NODE_TYPE_PROCESSING_INSTRUCTIONS,
	DOM_NODE_TYPE_COMMENT,
	DOM_NODE_TYPE_DOCUMENT,
	DOM_NODE_TYPE_DOCUMENT_TYPE,
	DOM_NODE_TYPE_DOCUMENT_FRAGMENT,
	DOM_NODE_TYPE_NUM_VALUES,
}

/// DOM form control types. Should be kept in sync with Chromium's
/// blink::mojom::FormControlType type.
Dom_form_control_type :: enum u32 {
	DOM_FORM_CONTROL_TYPE_UNSUPPORTED,
	DOM_FORM_CONTROL_TYPE_BUTTON_BUTTON,
	DOM_FORM_CONTROL_TYPE_BUTTON_SUBMIT,
	DOM_FORM_CONTROL_TYPE_BUTTON_RESET,
	DOM_FORM_CONTROL_TYPE_BUTTON_POPOVER,
	DOM_FORM_CONTROL_TYPE_FIELDSET,
	DOM_FORM_CONTROL_TYPE_INPUT_BUTTON,
	DOM_FORM_CONTROL_TYPE_INPUT_CHECKBOX,
	DOM_FORM_CONTROL_TYPE_INPUT_COLOR,
	DOM_FORM_CONTROL_TYPE_INPUT_DATE,
	DOM_FORM_CONTROL_TYPE_INPUT_DATETIME_LOCAL,
	DOM_FORM_CONTROL_TYPE_INPUT_EMAIL,
	DOM_FORM_CONTROL_TYPE_INPUT_FILE,
	DOM_FORM_CONTROL_TYPE_INPUT_HIDDEN,
	DOM_FORM_CONTROL_TYPE_INPUT_IMAGE,
	DOM_FORM_CONTROL_TYPE_INPUT_MONTH,
	DOM_FORM_CONTROL_TYPE_INPUT_NUMBER,
	DOM_FORM_CONTROL_TYPE_INPUT_PASSWORD,
	DOM_FORM_CONTROL_TYPE_INPUT_RADIO,
	DOM_FORM_CONTROL_TYPE_INPUT_RANGE,
	DOM_FORM_CONTROL_TYPE_INPUT_RESET,
	DOM_FORM_CONTROL_TYPE_INPUT_SEARCH,
	DOM_FORM_CONTROL_TYPE_INPUT_SUBMIT,
	DOM_FORM_CONTROL_TYPE_INPUT_TELEPHONE,
	DOM_FORM_CONTROL_TYPE_INPUT_TEXT,
	DOM_FORM_CONTROL_TYPE_INPUT_TIME,
	DOM_FORM_CONTROL_TYPE_INPUT_URL,
	DOM_FORM_CONTROL_TYPE_INPUT_WEEK,
	DOM_FORM_CONTROL_TYPE_OUTPUT,
	DOM_FORM_CONTROL_TYPE_SELECT_ONE,
	DOM_FORM_CONTROL_TYPE_SELECT_MULTIPLE,
	DOM_FORM_CONTROL_TYPE_TEXT_AREA,
	DOM_FORM_CONTROL_TYPE_NUM_VALUES,
}

/// Supported file dialog modes.
File_dialog_mode :: enum u32 {
	/// Requires that the file exists before allowing the user to pick it.
	FILE_DIALOG_OPEN,

	/// Like Open, but allows picking multiple files to open.
	FILE_DIALOG_OPEN_MULTIPLE,

	/// Like Open, but selects a folder to open.
	FILE_DIALOG_OPEN_FOLDER,

	/// Allows picking a nonexistent file, and prompts to overwrite if the file
	/// already exists.
	FILE_DIALOG_SAVE,

	FILE_DIALOG_NUM_VALUES,
}

/// Print job color mode values.
Color_model :: enum u32 {
	COLOR_MODEL_UNKNOWN,
	COLOR_MODEL_GRAY,
	COLOR_MODEL_COLOR,
	COLOR_MODEL_CMYK,
	COLOR_MODEL_CMY,
	COLOR_MODEL_KCMY,
	COLOR_MODEL_CMY_K,	// CMY_K represents CMY+K.
	COLOR_MODEL_BLACK,
	COLOR_MODEL_GRAYSCALE,
	COLOR_MODEL_RGB,
	COLOR_MODEL_RGB16,
	COLOR_MODEL_RGBA,
	COLOR_MODEL_COLORMODE_COLOR,							// Used in samsung printer ppds.
	COLOR_MODEL_COLORMODE_MONOCHROME,				 // Used in samsung printer ppds.
	COLOR_MODEL_HP_COLOR_COLOR,							 // Used in HP color printer ppds.
	COLOR_MODEL_HP_COLOR_BLACK,							 // Used in HP color printer ppds.
	COLOR_MODEL_PRINTOUTMODE_NORMAL,					// Used in foomatic ppds.
	COLOR_MODEL_PRINTOUTMODE_NORMAL_GRAY,		 // Used in foomatic ppds.
	COLOR_MODEL_PROCESSCOLORMODEL_CMYK,			 // Used in canon printer ppds.
	COLOR_MODEL_PROCESSCOLORMODEL_GREYSCALE,	// Used in canon printer ppds.
	COLOR_MODEL_PROCESSCOLORMODEL_RGB,				// Used in canon printer ppds
	COLOR_MODEL_NUM_VALUES,
}

/// Print job duplex mode values.
Duplex_mode :: enum u32 {
	DUPLEX_MODE_UNKNOWN = 0xFFFFFFFF, // -1 equivalent
	DUPLEX_MODE_SIMPLEX,
	DUPLEX_MODE_LONG_EDGE,
	DUPLEX_MODE_SHORT_EDGE,
	DUPLEX_MODE_NUM_VALUES,
}

/// Cursor type values.
Cursor_type :: enum u32 {
	CT_POINTER,
	CT_CROSS,
	CT_HAND,
	CT_IBEAM,
	CT_WAIT,
	CT_HELP,
	CT_EASTRESIZE,
	CT_NORTHRESIZE,
	CT_NORTHEASTRESIZE,
	CT_NORTHWESTRESIZE,
	CT_SOUTHRESIZE,
	CT_SOUTHEASTRESIZE,
	CT_SOUTHWESTRESIZE,
	CT_WESTRESIZE,
	CT_NORTHSOUTHRESIZE,
	CT_EASTWESTRESIZE,
	CT_NORTHEASTSOUTHWESTRESIZE,
	CT_NORTHWESTSOUTHEASTRESIZE,
	CT_COLUMNRESIZE,
	CT_ROWRESIZE,
	CT_MIDDLEPANNING,
	CT_EASTPANNING,
	CT_NORTHPANNING,
	CT_NORTHEASTPANNING,
	CT_NORTHWESTPANNING,
	CT_SOUTHPANNING,
	CT_SOUTHEASTPANNING,
	CT_SOUTHWESTPANNING,
	CT_WESTPANNING,
	CT_MOVE,
	CT_VERTICALTEXT,
	CT_CELL,
	CT_CONTEXTMENU,
	CT_ALIAS,
	CT_PROGRESS,
	CT_NODROP,
	CT_COPY,
	CT_NONE,
	CT_NOTALLOWED,
	CT_ZOOMIN,
	CT_ZOOMOUT,
	CT_GRAB,
	CT_GRABBING,
	CT_MIDDLE_PANNING_VERTICAL,
	CT_MIDDLE_PANNING_HORIZONTAL,
	CT_CUSTOM,
	CT_DND_NONE,
	CT_DND_MOVE,
	CT_DND_COPY,
	CT_DND_LINK,
	CT_NUM_VALUES,
}

/// Structure representing cursor information. |buffer| will be
/// |size.width|*|size.height|*4 bytes in size and represents a BGRA image with
/// an upper-left origin.
Cursor_info :: struct {
	hotspot: cef_point,
	image_scale_factor: f32,
	buffer: rawptr,
	size: cef_size,
}

/// URI unescape rules passed to CefURIDecode().
Uri_unescape_rule :: enum u32 {
	/// Don't unescape anything at all.
	UU_NONE = 0,

	/// Don't unescape anything special, but all normal unescaping will happen.
	/// This is a placeholder and can't be combined with other flags (since it's
	/// just the absence of them). All other unescape rules imply "normal" in
	/// addition to their special meaning. Things like escaped letters, digits,
	/// and most symbols will get unescaped with this mode.
	UU_NORMAL = 1 << 0,

	/// Convert %20 to spaces. In some places where we're showing URLs, we may
	/// want this. In places where the URL may be copied and pasted out, then
	/// you wouldn't want this since it might not be interpreted in one piece
	/// by other applications.
	UU_SPACES = 1 << 1,

	/// Unescapes '/' and '\\'. If these characters were unescaped, the resulting
	/// URL won't be the same as the source one. Moreover, they are dangerous to
	/// unescape in strings that will be used as file paths or names. This value
	/// should only be used when slashes don't have special meaning, like data
	/// URLs.
	UU_PATH_SEPARATORS = 1 << 2,

	/// Unescapes various characters that will change the meaning of URLs,
	/// including '%', '+', '&', '#'. Does not unescape path separators.
	/// If these characters were unescaped, the resulting URL won't be the same
	/// as the source one. This flag is used when generating final output like
	/// filenames for URLs where we won't be interpreting as a URL and want to do
	/// as much unescaping as possible.
	UU_URL_SPECIAL_CHARS_EXCEPT_PATH_SEPARATORS = 1 << 3,

	/// URL queries use "+" for space. This flag controls that replacement.
	UU_REPLACE_PLUS_WITH_SPACE = 1 << 4,
}

/// Options that can be passed to CefParseJSON.
Json_parser_options :: enum u32 {
	/// Parses the input strictly according to RFC 4627. See comments in
	/// Chromium's base/json/json_reader.h file for known limitations/
	/// deviations from the RFC.
	JSON_PARSER_RFC = 0,

	/// Allows commas to exist after the last element in structures.
	JSON_PARSER_ALLOW_TRAILING_COMMAS = 1 << 0,
}

/// Options that can be passed to CefWriteJSON.
Json_writer_options :: enum u32 {
	/// Default behavior.
	JSON_WRITER_DEFAULT = 0,

	/// This option instructs the writer that if a Binary value is encountered,
	/// the value (and key if within a dictionary) will be omitted from the
	/// output, and success will be returned. Otherwise, if a binary value is
	/// encountered, failure will be returned.
	JSON_WRITER_OMIT_BINARY_VALUES = 1 << 0,

	/// This option instructs the writer to write doubles that have no fractional
	/// part as a normal integer (i.e., without using exponential notation
	/// or appending a '.0') as long as the value is within the range of a
	/// 64-bit int.
	JSON_WRITER_OMIT_DOUBLE_TYPE_PRESERVATION = 1 << 1,

	/// Return a slightly nicer formatted json string (pads with whitespace to
	/// help with readability).
	JSON_WRITER_PRETTY_PRINT = 1 << 2,
}

/// Margin type for PDF printing.
Pdf_print_margin_type :: enum u32 {
	/// Default margins of 1cm (~0.4 inches).
	PDF_PRINT_MARGIN_DEFAULT,

	/// No margins.
	PDF_PRINT_MARGIN_NONE,

	/// Custom margins using the |margin_*| values from pdf_print_settings_t.
	PDF_PRINT_MARGIN_CUSTOM,
}

/// Structure representing PDF print settings. These values match the parameters
/// supported by the DevTools Page.printToPDF function. See
/// https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-printToPDF
Pdf_print_settings :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Set to true (1) for landscape mode or false (0) for portrait mode.
	landscape: c.int,

	/// Set to true (1) to print background graphics.
	print_background: c.int,

	/// The percentage to scale the PDF by before printing (e.g. .5 is 50%).
	/// If this value is less than or equal to zero the default value of 1.0
	/// will be used.
	scale: f64,

	/// Output paper size in inches. If either of these values is less than or
	/// equal to zero then the default paper size (letter, 8.5 x 11 inches) will
	/// be used.
	paper_width: f64,
	paper_height: f64,

	/// Set to true (1) to prefer page size as defined by css. Defaults to false
	/// (0), in which case the content will be scaled to fit the paper size.
	prefer_css_page_size: c.int,

	/// Margin type.
	margin_type: Pdf_print_margin_type,

	/// Margins in inches. Only used if |margin_type| is set to
	/// PDF_PRINT_MARGIN_CUSTOM.
	margin_top: f64,
	margin_right: f64,
	margin_bottom: f64,
	margin_left: f64,

	/// Paper ranges to print, one based, e.g., '1-5, 8, 11-13'. Pages are printed
	/// in the document order, not in the order specified, and no more than once.
	/// Defaults to empty string, which implies the entire document is printed.
	/// The page numbers are quietly capped to actual page count of the document,
	/// and ranges beyond the end of the document are ignored. If this results in
	/// no pages to print, an error is reported. It is an error to specify a range
	/// with start greater than end.
	page_ranges: cef_string,

	/// Set to true (1) to display the header and/or footer. Modify
	/// |header_template| and/or |footer_template| to customize the display.
	display_header_footer: c.int,

	/// HTML template for the print header. Only displayed if
	/// |display_header_footer| is true (1). Should be valid HTML markup with
	/// the following classes used to inject printing values into them:
	/// - date: formatted print date
	/// - title: document title
	/// - url: document location
	/// - pageNumber: current page number
	/// - totalPages: total pages in the document
	/// For example, "<span class=title></span>" would generate a span containing
	/// the title.
	header_template: cef_string,

	/// HTML template for the print footer. Only displayed if
	/// |display_header_footer| is true (1). Uses the same format as
	/// |header_template|.
	footer_template: cef_string,

	/// Set to true (1) to generate tagged (accessible) PDF.
	generate_tagged_pdf: c.int,

	/// Set to true (1) to generate a document outline.
	generate_document_outline: c.int,
}

/// Supported UI scale factors for the platform. SCALE_FACTOR_NONE is used for
/// density independent resources such as string, html/js files or an image that
/// can be used for any scale factors (such as wallpapers).
Scale_factor :: enum u32 {
	SCALE_FACTOR_NONE,
	SCALE_FACTOR_100P,
	SCALE_FACTOR_125P,
	SCALE_FACTOR_133P,
	SCALE_FACTOR_140P,
	SCALE_FACTOR_150P,
	SCALE_FACTOR_180P,
	SCALE_FACTOR_200P,
	SCALE_FACTOR_250P,
	SCALE_FACTOR_300P,
	SCALE_FACTOR_NUM_VALUES,
}

/// Policy for how the Referrer HTTP header value will be sent during
/// navigation. If the `--no-referrers` command-line flag is specified then the
/// policy value will be ignored and the Referrer value will never be sent. Must
/// be kept synchronized with net::Url_request::ReferrerPolicy from Chromium.
Referrer_policy :: enum u32 {
	/// Clear the referrer header if the header value is HTTPS but the request
	/// destination is HTTP. This is the default behavior.
	REFERRER_POLICY_CLEAR_REFERRER_ON_TRANSITION_FROM_SECURE_TO_INSECURE,
	REFERRER_POLICY_DEFAULT =
			REFERRER_POLICY_CLEAR_REFERRER_ON_TRANSITION_FROM_SECURE_TO_INSECURE,

	/// A slight variant on CLEAR_REFERRER_ON_TRANSITION_FROM_SECURE_TO_INSECURE:
	/// If the request destination is HTTP, an HTTPS referrer will be cleared. If
	/// the request's destination is cross-origin with the referrer (but does not
	/// downgrade), the referrer's granularity will be stripped down to an origin
	/// rather than a full URL. Same-origin requests will send the full referrer.
	REFERRER_POLICY_REDUCE_REFERRER_GRANULARITY_ON_TRANSITION_CROSS_ORIGIN,

	/// Strip the referrer down to an origin when the origin of the referrer is
	/// different from the destination's origin.
	REFERRER_POLICY_ORIGIN_ONLY_ON_TRANSITION_CROSS_ORIGIN,

	/// Never change the referrer.
	REFERRER_POLICY_NEVER_CLEAR_REFERRER,

	/// Strip the referrer down to the origin regardless of the redirect location.
	REFERRER_POLICY_ORIGIN,

	/// Clear the referrer when the request's referrer is cross-origin with the
	/// request's destination.
	REFERRER_POLICY_CLEAR_REFERRER_ON_TRANSITION_CROSS_ORIGIN,

	/// Strip the referrer down to the origin, but clear it entirely if the
	/// referrer value is HTTPS and the destination is HTTP.
	REFERRER_POLICY_ORIGIN_CLEAR_ON_TRANSITION_FROM_SECURE_TO_INSECURE,

	/// Always clear the referrer regardless of the request destination.
	REFERRER_POLICY_NO_REFERRER,

	/// Always the last value in this enumeration.
	REFERRER_POLICY_NUM_VALUES,
}

/// Return values for CefResponseFilter::Filter().
Response_filter_status :: enum u32 {
	/// Some or all of the pre-filter data was read successfully but more data is
	/// needed in order to continue filtering (filtered output is pending).
	RESPONSE_FILTER_NEED_MORE_DATA,

	/// Some or all of the pre-filter data was read successfully and all available
	/// filtered output has been written.
	RESPONSE_FILTER_DONE,

	/// An error occurred during filtering.
	RESPONSE_FILTER_ERROR
}

/// Describes how to interpret the alpha component of a pixel.
Alpha_type :: enum u32 {
	/// No transparency. The alpha component is ignored.
	ALPHA_TYPE_OPAQUE,

	/// Transparency with pre-multiplied alpha component.
	ALPHA_TYPE_PREMULTIPLIED,

	/// Transparency with post-multiplied alpha component.
	ALPHA_TYPE_POSTMULTIPLIED,
}

/// Text style types. Should be kepy in sync with gfx::TextStyle.
Text_style :: enum u32 {
	TEXT_STYLE_BOLD,
	TEXT_STYLE_ITALIC,
	TEXT_STYLE_STRIKE,
	TEXT_STYLE_DIAGONAL_STRIKE,
	TEXT_STYLE_UNDERLINE,
	TEXT_STYLE_NUM_VALUES,
}

/// Specifies where along the axis the CefBoxLayout child views should be laid
/// out. Should be kept in sync with Chromium's views::LayoutAlignment type.
Axis_alignment :: enum u32 {
	/// Child views will be left/top-aligned.
	AXIS_ALIGNMENT_START,

	/// Child views will be center-aligned.
	AXIS_ALIGNMENT_CENTER,

	/// Child views will be right/bottom-aligned.
	AXIS_ALIGNMENT_END,

	/// Child views will be stretched to fit.
	AXIS_ALIGNMENT_STRETCH,

	AXIS_ALIGNMENT_NUM_VALUES,
}

/// Settings used when initializing a CefBoxLayout.
Box_layout_settings :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// If true (1) the layout will be horizontal, otherwise the layout will be
	/// vertical.
	horizontal: c.int,

	/// Adds additional horizontal space between the child view area and the host
	/// view border.
	inside_border_horizontal_spacing: c.int,

	/// Adds additional vertical space between the child view area and the host
	/// view border.
	inside_border_vertical_spacing: c.int,

	/// Adds additional space around the child view area.
	inside_border_insets: cef_insets,

	/// Adds additional space between child views.
	between_child_spacing: c.int,

	/// Specifies where along the main axis the child views should be laid out.
	main_axis_alignment: Axis_alignment,

	/// Specifies where along the cross axis the child views should be laid out.
	cross_axis_alignment: Axis_alignment,

	/// Minimum cross axis size.
	minimum_cross_axis_size: c.int,

	/// Default flex for views when none is specified via CefBoxLayout methods.
	/// Using the preferred size as the basis, free space along the main axis is
	/// distributed to views in the ratio of their flex weights. Similarly, if the
	/// views will overflow the parent, space is subtracted in these ratios. A
	/// flex of 0 means this view is not resized. Flex values must not be
	/// negative.
	default_flex: c.int,
}

/// Specifies the button display state.
Button_state :: enum u32 {
	BUTTON_STATE_NORMAL,
	BUTTON_STATE_HOVERED,
	BUTTON_STATE_PRESSED,
	BUTTON_STATE_DISABLED,
	BUTTON_STATE_NUM_VALUES,
}

/// Specifies the horizontal text alignment mode.
Horizontal_alignment :: enum u32 {
	/// Align the text's left edge with that of its display area.
	HORIZONTAL_ALIGNMENT_LEFT,

	/// Align the text's center with that of its display area.
	HORIZONTAL_ALIGNMENT_CENTER,

	/// Align the text's right edge with that of its display area.
	HORIZONTAL_ALIGNMENT_RIGHT,
}

/// Specifies how a menu will be anchored for non-RTL languages. The opposite
/// position will be used for RTL languages.
Menu_anchor_position :: enum u32 {
	MENU_ANCHOR_TOPLEFT,
	MENU_ANCHOR_TOPRIGHT,
	MENU_ANCHOR_BOTTOMCENTER,
	MENU_ANCHOR_NUM_VALUES,
}

/// Supported color types for menu items.
Menu_color_type :: enum u32 {
	MENU_COLOR_TEXT,
	MENU_COLOR_TEXT_HOVERED,
	MENU_COLOR_TEXT_ACCELERATOR,
	MENU_COLOR_TEXT_ACCELERATOR_HOVERED,
	MENU_COLOR_BACKGROUND,
	MENU_COLOR_BACKGROUND_HOVERED,
	MENU_COLOR_NUM_VALUES,
}

/// Supported SSL version values. See net/ssl/ssl_connection_status_flags.h
/// for more information.
Ssl_version :: enum u32 {
	/// Unknown SSL version.
	SSL_CONNECTION_VERSION_UNKNOWN,
	SSL_CONNECTION_VERSION_SSL2,
	SSL_CONNECTION_VERSION_SSL3,
	SSL_CONNECTION_VERSION_TLS1,
	SSL_CONNECTION_VERSION_TLS1_1,
	SSL_CONNECTION_VERSION_TLS1_2,
	SSL_CONNECTION_VERSION_TLS1_3,
	SSL_CONNECTION_VERSION_QUIC,
	SSL_CONNECTION_VERSION_NUM_VALUES,
}

/// Supported SSL content status flags. See content/public/common/Ssl_status.h
/// for more information.
Ssl_content_status :: enum u32 {
	SSL_CONTENT_NORMAL_CONTENT = 0,
	SSL_CONTENT_DISPLAYED_INSECURE_CONTENT = 1 << 0,
	SSL_CONTENT_RAN_INSECURE_CONTENT = 1 << 1,
}

/// Configuration options for registering a custom scheme.
/// These values are used when calling AddCustomScheme.
Scheme_options :: enum u32 {
	SCHEME_OPTION_NONE = 0,

	/// If SCHEME_OPTION_STANDARD is set the scheme will be treated as a
	/// standard scheme. Standard schemes are subject to URL canonicalization and
	/// parsing rules as defined in the Common Internet Scheme Syntax RFC 1738
	/// Section 3.1 available at http://www.ietf.org/rfc/rfc1738.txt
	//
	/// In particular, the syntax for standard scheme URLs must be of the form:
	/// <pre>
	///	[scheme]://[username]:[password]@[host]:[port]/[url-path]
	/// </pre> Standard scheme URLs must have a host component that is a fully
	/// qualified domain name as defined in Section 3.5 of RFC 1034 [13] and
	/// Section 2.1 of RFC 1123. These URLs will be canonicalized to
	/// "scheme://host/path" in the simplest case and
	/// "scheme://username:password@host:port/path" in the most explicit case. For
	/// example, "scheme:host/path" and "scheme:///host/path" will both be
	/// canonicalized to "scheme://host/path". The origin of a standard scheme URL
	/// is the combination of scheme, host and port (i.e., "scheme://host:port" in
	/// the most explicit case).
	//
	/// For non-standard scheme URLs only the "scheme:" component is parsed and
	/// canonicalized. The remainder of the URL will be passed to the handler as-
	/// is. For example, "scheme:///some%20text" will remain the same.
	/// Non-standard scheme URLs cannot be used as a target for form submission.
	SCHEME_OPTION_STANDARD = 1 << 0,

	/// If SCHEME_OPTION_LOCAL is set the scheme will be treated with the same
	/// security rules as those applied to "file" URLs. Normal pages cannot link
	/// to or access local URLs. Also, by default, local URLs can only perform
	/// XMLHttpRequest calls to the same URL (origin + path) that originated the
	/// request. To allow XMLHttpRequest calls from a local URL to other URLs with
	/// the same origin set the CefSettings.file_access_from_file_urls_allowed
	/// value to true (1). To allow XMLHttpRequest calls from a local URL to all
	/// origins set the CefSettings.universal_access_from_file_urls_allowed value
	/// to true (1).
	SCHEME_OPTION_LOCAL = 1 << 1,

	/// If SCHEME_OPTION_DISPLAY_ISOLATED is set the scheme can only be
	/// displayed from other content hosted with the same scheme. For example,
	/// pages in other origins cannot create iframes or hyperlinks to URLs with
	/// the scheme. For schemes that must be accessible from other schemes don't
	/// set this, set SCHEME_OPTION_CORS_ENABLED, and use CORS
	/// "Access-Control-Allow-Origin" headers to further restrict access.
	SCHEME_OPTION_DISPLAY_ISOLATED = 1 << 2,

	/// If SCHEME_OPTION_SECURE is set the scheme will be treated with the
	/// same security rules as those applied to "https" URLs. For example, loading
	/// this scheme from other secure schemes will not trigger mixed content
	/// warnings.
	SCHEME_OPTION_SECURE = 1 << 3,

	/// If SCHEME_OPTION_CORS_ENABLED is set the scheme can be sent CORS
	/// requests. This value should be set in most cases where
	/// SCHEME_OPTION_STANDARD is set.
	SCHEME_OPTION_CORS_ENABLED = 1 << 4,

	/// If SCHEME_OPTION_CSP_BYPASSING is set the scheme can bypass Content-
	/// Security-Policy (CSP) checks. This value should not be set in most cases
	/// where SCHEME_OPTION_STANDARD is set.
	SCHEME_OPTION_CSP_BYPASSING = 1 << 5,

	/// If SCHEME_OPTION_FETCH_ENABLED is set the scheme can perform Fetch API
	/// requests.
	SCHEME_OPTION_FETCH_ENABLED = 1 << 6,
}

/// Structure representing a range.
cef_range :: struct {
	from: u32,
	to: u32,
}

/// Composition underline style.
Composition_underline_style :: enum u32 {
	CUS_SOLID,
	CUS_DOT,
	CUS_DASH,
	CUS_NONE,
	CUS_NUM_VALUES,
}

/// Structure representing IME composition underline information. This is a thin
/// wrapper around Blink's WebCompositionUnderline class and should be kept in
/// sync with that.
Composition_underline :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Underline character range.
	range: cef_range,

	/// Text color.
	color: cef_color,

	/// Background color.
	background_color: cef_color,

	/// Set to true (1) for thick underline.
	thick: c.int,

	/// Style.
	style: Composition_underline_style,
}

/// Enumerates the various representations of the ordering of audio channels.
/// Must be kept synchronized with media::ChannelLayout from Chromium.
/// See media\base\channel_layout.h
Channel_layout :: enum u32 {
	CHANNEL_LAYOUT_NONE,
	CHANNEL_LAYOUT_UNSUPPORTED,

	/// Front C
	CHANNEL_LAYOUT_MONO,

	/// Front L, Front R
	CHANNEL_LAYOUT_STEREO,

	/// Front L, Front R, Back C
	CHANNEL_LAYOUT_2_1,

	/// Front L, Front R, Front C
	CHANNEL_LAYOUT_SURROUND,

	/// Front L, Front R, Front C, Back C
	CHANNEL_LAYOUT_4_0,

	/// Front L, Front R, Side L, Side R
	CHANNEL_LAYOUT_2_2,

	/// Front L, Front R, Back L, Back R
	CHANNEL_LAYOUT_QUAD,

	/// Front L, Front R, Front C, Side L, Side R
	CHANNEL_LAYOUT_5_0,

	/// Front L, Front R, Front C, LFE, Side L, Side R
	CHANNEL_LAYOUT_5_1,

	/// Front L, Front R, Front C, Back L, Back R
	CHANNEL_LAYOUT_5_0_BACK,

	/// Front L, Front R, Front C, LFE, Back L, Back R
	CHANNEL_LAYOUT_5_1_BACK,

	/// Front L, Front R, Front C, Back L, Back R, Side L, Side R
	CHANNEL_LAYOUT_7_0,

	/// Front L, Front R, Front C, LFE, Back L, Back R, Side L, Side R
	CHANNEL_LAYOUT_7_1,

	/// Front L, Front R, Front C, LFE, Front LofC, Front RofC, Side L, Side R
	CHANNEL_LAYOUT_7_1_WIDE,

	/// Front L, Front R
	CHANNEL_LAYOUT_STEREO_DOWNMIX,

	/// Front L, Front R, LFE
	CHANNEL_LAYOUT_2POINT1,

	/// Front L, Front R, Front C, LFE
	CHANNEL_LAYOUT_3_1,

	/// Front L, Front R, Front C, LFE, Back C
	CHANNEL_LAYOUT_4_1,

	/// Front L, Front R, Front C, Back C, Side L, Side R
	CHANNEL_LAYOUT_6_0,

	/// Front L, Front R, Front LofC, Front RofC, Side L, Side R
	CHANNEL_LAYOUT_6_0_FRONT,

	/// Front L, Front R, Front C, Back L, Back R, Back C
	CHANNEL_LAYOUT_HEXAGONAL,

	/// Front L, Front R, Front C, LFE, Back C, Side L, Side R
	CHANNEL_LAYOUT_6_1,

	/// Front L, Front R, Front C, LFE, Back L, Back R, Back C
	CHANNEL_LAYOUT_6_1_BACK,

	/// Front L, Front R, LFE, Front LofC, Front RofC, Side L, Side R
	CHANNEL_LAYOUT_6_1_FRONT,

	/// Front L, Front R, Front C, Front LofC, Front RofC, Side L, Side R
	CHANNEL_LAYOUT_7_0_FRONT,

	/// Front L, Front R, Front C, LFE, Back L, Back R, Front LofC, Front RofC
	CHANNEL_LAYOUT_7_1_WIDE_BACK,

	/// Front L, Front R, Front C, Back L, Back R, Back C, Side L, Side R
	CHANNEL_LAYOUT_OCTAGONAL,

	/// Channels are not explicitly mapped to speakers.
	CHANNEL_LAYOUT_DISCRETE,

	/// Deprecated, but keeping the enum value for UMA consistency.
	/// Front L, Front R, Front C. Front C contains the keyboard mic audio. This
	/// layout is only intended for input for WebRTC. The Front C channel
	/// is stripped away in the WebRTC audio input pipeline and never seen outside
	/// of that.
	CHANNEL_LAYOUT_STEREO_AND_KEYBOARD_MIC,

	/// Front L, Front R, LFE, Side L, Side R
	CHANNEL_LAYOUT_4_1_QUAD_SIDE,

	/// Actual channel layout is specified in the bitstream and the actual channel
	/// count is unknown at Chromium media pipeline level (useful for audio
	/// pass-through mode).
	CHANNEL_LAYOUT_BITSTREAM,

	/// Front L, Front R, Front C, LFE, Side L, Side R,
	/// Front Height L, Front Height R, Rear Height L, Rear Height R
	/// Will be represented as six channels (5.1) due to eight channel limit
	/// kMaxConcurrentChannels
	CHANNEL_LAYOUT_5_1_4_DOWNMIX,

	/// Front C, LFE
	CHANNEL_LAYOUT_1_1,

	/// Front L, Front R, LFE, Back C
	CHANNEL_LAYOUT_3_1_BACK,

	CHANNEL_NUM_VALUES,
}

/// Structure representing the audio parameters for setting up the audio handler.
///
Audio_parameters :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Layout of the audio channels
	channel_layout: Channel_layout,

	/// Sample rate
	sample_rate: c.int,

	/// Number of frames per buffer
	frames_per_buffer: c.int,
}

/// Result codes for CefMediaRouter::CreateRoute. Should be kept in sync with Chromium's media_router::mojom::RouteRequestResultCode type.
///
Media_route_create_result :: enum u32 {
	MRCR_UNKNOWN_ERROR,
	MRCR_OK,
	MRCR_TIMED_OUT,
	MRCR_ROUTE_NOT_FOUND,
	MRCR_SINK_NOT_FOUND,
	MRCR_INVALID_ORIGIN,
	MRCR_OFF_THE_RECORD_MISMATCH_DEPRECATED,
	MRCR_NO_SUPPORTED_PROVIDER,
	MRCR_CANCELLED,
	MRCR_ROUTE_ALREADY_EXISTS,
	MRCR_DESKTOP_PICKER_FAILED,
	MRCR_ROUTE_ALREADY_TERMINATED,
	MRCR_REDUNDANT_REQUEST,
	MRCR_USER_NOT_ALLOWED,
	MRCR_NOTIFICATION_DISABLED,
	MRCR_NUM_VALUES,
}

/// Connection state for a MediaRoute object. Should be kept in sync with Chromium's blink::mojom::PresentationConnectionState type.
///
Media_route_connection_state :: enum u32 {
	MRCS_UNKNOWN = 0xFFFFFFFF, // -1 equivalent
	MRCS_CONNECTING,
	MRCS_CONNECTED,
	MRCS_CLOSED,
	MRCS_TERMINATED,
	MRCS_NUM_VALUES,
}

/// Icon types for a MediaSink object. Should be kept in sync with Chromium's media_router::SinkIconType type.
///
Media_sink_icon_type :: enum u32 {
	MSIT_CAST,
	MSIT_CAST_AUDIO_GROUP,
	MSIT_CAST_AUDIO,
	MSIT_MEETING,
	MSIT_HANGOUT,
	MSIT_EDUCATION,
	MSIT_WIRED_DISPLAY,
	MSIT_GENERIC,
	MSIT_NUM_VALUES,
}

/// Device information for a MediaSink object.
Media_sink_device_info :: struct {
	/// Size of this structure.
	size: c.size_t,

	ip_address: cef_string,
	port: c.int,
	model_name: cef_string,
}

/// Represents commands available to TextField. Should be kept in sync with Chromium's views::TextField::MenuCommands type.
///
Text_field_commands :: enum u32 {
	TFC_UNKNOWN,
	TFC_CUT,
	TFC_COPY,
	TFC_PASTE,
	TFC_SELECT_ALL,
	TFC_SELECT_WORD,
	TFC_UNDO,
	TFC_DELETE,
	TFC_NUM_VALUES,
}

/// Chrome toolbar types.
Chrome_toolbar_type :: enum u32 {
	CTT_UNKNOWN,
	CTT_NONE,
	CTT_NORMAL,
	CTT_LOCATION,
	CTT_NUM_VALUES,
}

/// Chrome page action icon types. Should be kept in sync with Chromium's PageActionIconType type.
///
Chrome_page_action_icon_type :: enum u32 {
	CPAIT_BOOKMARK_STAR,
	CPAIT_CLICK_TO_CALL,
	CPAIT_COOKIE_CONTROLS,
	CPAIT_FILE_SYSTEM_ACCESS,
	CPAIT_FIND,
	CPAIT_MEMORY_SAVER,
	CPAIT_INTENT_PICKER,
	CPAIT_LOCAL_CARD_MIGRATION,
	CPAIT_MANAGE_PASSWORDS,
	CPAIT_PAYMENTS_OFFER_NOTIFICATION,
	CPAIT_PRICE_TRACKING,
	CPAIT_PWA_INSTALL,
	CPAIT_QR_CODE_GENERATOR_DEPRECATED,
	CPAIT_READER_MODE_DEPRECATED,
	CPAIT_SAVE_AUTOFILL_ADDRESS,
	CPAIT_SAVE_CARD,
	CPAIT_SEND_TAB_TO_SELF_DEPRECATED,
	CPAIT_SHARING_HUB,
	CPAIT_SIDE_SEARCH_DEPRECATED,
	CPAIT_SMS_REMOTE_FETCHER,
	CPAIT_TRANSLATE,
	CPAIT_VIRTUAL_CARD_ENROLL,
	CPAIT_VIRTUAL_CARD_INFORMATION,
	CPAIT_ZOOM,
	CPAIT_SAVE_IBAN,
	CPAIT_MANDATORY_REAUTH,
	CPAIT_PRICE_INSIGHTS,
	CPAIT_READ_ANYTHING_DEPRECATED,
	CPAIT_PRODUCT_SPECIFICATIONS,
	CPAIT_LENS_OVERLAY,
	CPAIT_DISCOUNTS,
	CPAIT_OPTIMIZATION_GUIDE,
	CPAIT_COLLABORATION_MESSAGING,
	CPAIT_CHANGE_PASSWORD,
	CPAIT_LENS_OVERLAY_HOMEWORK,
	CPAIT_NUM_VALUES,
}

/// Chrome toolbar button types. Should be kept in sync with CEF's internal ToolbarButtonType type.
///
Chrome_toolbar_button_type :: enum u32 {
	CTBT_CAST,
	CTBT_DOWNLOAD_DEPRECATED,
	CTBT_SEND_TAB_TO_SELF_DEPRECATED,
	CTBT_SIDE_PANEL,
	CTBT_NUM_VALUES,
}

/// Docking modes supported by CefWindow::AddOverlay.
Docking_mode :: enum u32 {
	DOCKING_MODE_TOP_LEFT,
	DOCKING_MODE_TOP_RIGHT,
	DOCKING_MODE_BOTTOM_LEFT,
	DOCKING_MODE_BOTTOM_RIGHT,
	DOCKING_MODE_CUSTOM,
	DOCKING_MODE_NUM_VALUES,
}

/// Show states supported by CefWindowDelegate::GetInitialShowState.
Show_state :: enum u32 {
	// Show the window as normal.
	SHOW_STATE_NORMAL,

	// Show the window as minimized.
	SHOW_STATE_MINIMIZED,

	// Show the window as maximized.
	SHOW_STATE_MAXIMIZED,

	// Show the window as fullscreen.
	SHOW_STATE_FULLSCREEN,

	// Show the window as hidden (no dock thumbnail).
	// Only supported on MacOS.
	SHOW_STATE_HIDDEN,

	SHOW_STATE_NUM_VALUES,
}

/// Values indicating what state of the touch handle is set.
Touch_handle_state_flags :: enum u32 {
	THS_FLAG_NONE = 0,
	THS_FLAG_ENABLED = 1 << 0,
	THS_FLAG_ORIENTATION = 1 << 1,
	THS_FLAG_ORIGIN = 1 << 2,
	THS_FLAG_ALPHA = 1 << 3,
}

Touch_handle_state :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Touch handle id. Increments for each new touch handle.
	touch_handle_id: c.int,

	/// Combination of touch_handle_state_flags values indicating what state
	/// is set.
	flags: u32,

	/// Enabled state. Only set if |flags| contains THS_FLAG_ENABLED.
	enabled: c.int,

	/// Orientation state. Only set if |flags| contains THS_FLAG_ORIENTATION.
	orientation: Horizontal_alignment,
	mirror_vertical: c.int,
	mirror_horizontal: c.int,

	/// Origin state. Only set if |flags| contains THS_FLAG_ORIGIN.
	origin: cef_point,

	/// Alpha state. Only set if |flags| contains THS_FLAG_ALPHA.
	alpha: f32,
}

/// Media access permissions used by OnRequestMediaAccessPermission.
Media_access_permission_types :: enum u32 {
	/// No permission.
	MEDIA_PERMISSION_NONE = 0,

	/// Device audio capture permission.
	MEDIA_PERMISSION_DEVICE_AUDIO_CAPTURE = 1 << 0,

	/// Device video capture permission.
	MEDIA_PERMISSION_DEVICE_VIDEO_CAPTURE = 1 << 1,

	/// Desktop audio capture permission.
	MEDIA_PERMISSION_DESKTOP_AUDIO_CAPTURE = 1 << 2,

	/// Desktop video capture permission.
	MEDIA_PERMISSION_DESKTOP_VIDEO_CAPTURE = 1 << 3,
}

/// Permission types used with OnShowPermissionPrompt. Some types are platform-specific or only supported with Chrome style. Should be kept
/// in sync with Chromium's permissions::RequestType type.
///
Permission_request_types :: enum u32 {
	PERMISSION_TYPE_NONE = 0,
	PERMISSION_TYPE_AR_SESSION = 1 << 0,
	PERMISSION_TYPE_CAMERA_PAN_TILT_ZOOM = 1 << 1,
	PERMISSION_TYPE_CAMERA_STREAM = 1 << 2,
	PERMISSION_TYPE_CAPTURED_SURFACE_CONTROL = 1 << 3,
	PERMISSION_TYPE_CLIPBOARD = 1 << 4,
	PERMISSION_TYPE_TOP_LEVEL_STORAGE_ACCESS = 1 << 5,
	PERMISSION_TYPE_DISK_QUOTA = 1 << 6,
	PERMISSION_TYPE_LOCAL_FONTS = 1 << 7,
	PERMISSION_TYPE_GEOLOCATION = 1 << 8,
	PERMISSION_TYPE_HAND_TRACKING = 1 << 9,
	PERMISSION_TYPE_IDENTITY_PROVIDER = 1 << 10,
	PERMISSION_TYPE_IDLE_DETECTION = 1 << 11,
	PERMISSION_TYPE_MIC_STREAM = 1 << 12,
	PERMISSION_TYPE_MIDI_SYSEX = 1 << 13,
	PERMISSION_TYPE_MULTIPLE_DOWNLOADS = 1 << 14,
	PERMISSION_TYPE_NOTIFICATIONS = 1 << 15,
	PERMISSION_TYPE_KEYBOARD_LOCK = 1 << 16,
	PERMISSION_TYPE_POINTER_LOCK = 1 << 17,
	PERMISSION_TYPE_PROTECTED_MEDIA_IDENTIFIER = 1 << 18,
	PERMISSION_TYPE_REGISTER_PROTOCOL_HANDLER = 1 << 19,
	PERMISSION_TYPE_STORAGE_ACCESS = 1 << 20,
	PERMISSION_TYPE_VR_SESSION = 1 << 21,
	PERMISSION_TYPE_WEB_APP_INSTALLATION = 1 << 22,
	PERMISSION_TYPE_WINDOW_MANAGEMENT = 1 << 23,
	PERMISSION_TYPE_FILE_SYSTEM_ACCESS = 1 << 24,
	PERMISSION_TYPE_LOCAL_NETWORK_ACCESS = 1 << 25,
}

/// Permission request results.
Permission_request_result :: enum u32 {
	/// Accept the permission request as an explicit user action.
	PERMISSION_RESULT_ACCEPT,

	/// Deny the permission request as an explicit user action.
	PERMISSION_RESULT_DENY,

	/// Dismiss the permission request as an explicit user action.
	PERMISSION_RESULT_DISMISS,

	/// Ignore the permission request. If the prompt remains unhandled (e.g.
	/// OnShowPermissionPrompt returns false and there is no default permissions
	/// UI) then any related promises may remain unresolved.
	PERMISSION_RESULT_IGNORE,

	PERMISSION_RESULT_NUM_VALUES,
}

/// Certificate types supported by CefTestServer::CreateAndStart. The matching certificate file must exist in the "net/data/ssl/certificates" directory.
/// See CefSetDataDirectoryForTests() for related configuration.
///
Test_cert_type :: enum u32 {
	/// Valid certificate using the IP (127.0.0.1). Loads the "ok_cert.pem" file.
	TEST_CERT_OK_IP,

	/// Valid certificate using the domain ("localhost"). Loads the
	/// "localhost_cert.pem" file.
	TEST_CERT_OK_DOMAIN,

	/// Expired certificate. Loads the "expired_cert.pem" file.
	TEST_CERT_EXPIRED,

	TEST_CERT_NUM_VALUES,
}

/// Preferences type passed to CefBrowserProcessHandler::OnRegisterCustomPreferences.
///
Preferences_type :: enum u32 {
	/// Global preferences registered a single time at application startup.
	PREFERENCES_TYPE_GLOBAL,

	/// Request context preferences registered each time a new CefRequestContext
	/// is created.
	PREFERENCES_TYPE_REQUEST_CONTEXT,

	PREFERENCES_TYPE_NUM_VALUES,
}

/// Download interrupt reasons. Should be kept in sync with Chromium's download::DownloadInterruptReason type.
///
Download_interrupt_reason :: enum u32 {
	DOWNLOAD_INTERRUPT_REASON_NONE = 0,

	/// Generic file operation failure.
	DOWNLOAD_INTERRUPT_REASON_FILE_FAILED = 1,

	/// The file cannot be accessed due to security restrictions.
	DOWNLOAD_INTERRUPT_REASON_FILE_ACCESS_DENIED = 2,

	/// There is not enough room on the drive.
	DOWNLOAD_INTERRUPT_REASON_FILE_NO_SPACE = 3,

	/// The directory or file name is too long.
	DOWNLOAD_INTERRUPT_REASON_FILE_NAME_TOO_LONG = 5,

	/// The file is too large for the file system to handle.
	DOWNLOAD_INTERRUPT_REASON_FILE_TOO_LARGE = 6,

	/// The file contains a virus.
	DOWNLOAD_INTERRUPT_REASON_FILE_VIRUS_INFECTED = 7,

	/// The file was in use. Too many files are opened at once. We have run out of
	/// memory.
	DOWNLOAD_INTERRUPT_REASON_FILE_TRANSIENT_ERROR = 10,

	/// The file was blocked due to local policy.
	DOWNLOAD_INTERRUPT_REASON_FILE_BLOCKED = 11,

	/// An attempt to check the safety of the download failed due to unexpected
	/// reasons. See http://crbug.com/153212.
	DOWNLOAD_INTERRUPT_REASON_FILE_SECURITY_CHECK_FAILED = 12,

	/// An attempt was made to seek past the end of a file in opening
	/// a file (as part of resuming a previously interrupted download).
	DOWNLOAD_INTERRUPT_REASON_FILE_TOO_SHORT = 13,

	/// The partial file didn't match the expected hash.
	DOWNLOAD_INTERRUPT_REASON_FILE_HASH_MISMATCH = 14,

	/// The source and the target of the download were the same.
	DOWNLOAD_INTERRUPT_REASON_FILE_SAME_AS_SOURCE = 15,

	// Network errors.

	/// Generic network failure.
	DOWNLOAD_INTERRUPT_REASON_NETWORK_FAILED = 20,

	/// The network operation timed out.
	DOWNLOAD_INTERRUPT_REASON_NETWORK_TIMEOUT = 21,

	/// The network connection has been lost.
	DOWNLOAD_INTERRUPT_REASON_NETWORK_DISCONNECTED = 22,

	/// The server has gone down.
	DOWNLOAD_INTERRUPT_REASON_NETWORK_SERVER_DOWN = 23,

	/// The network request was invalid. This may be due to the original URL or a
	/// redirected URL:
	/// - Having an unsupported scheme.
	/// - Being an invalid URL.
	/// - Being disallowed by policy.
	DOWNLOAD_INTERRUPT_REASON_NETWORK_INVALID_REQUEST = 24,

	// Server responses.

	/// The server indicates that the operation has failed (generic).
	DOWNLOAD_INTERRUPT_REASON_SERVER_FAILED = 30,

	/// The server does not support range requests.
	/// Internal use only:	must restart from the beginning.
	DOWNLOAD_INTERRUPT_REASON_SERVER_NO_RANGE = 31,

	/// The server does not have the requested data.
	DOWNLOAD_INTERRUPT_REASON_SERVER_BAD_CONTENT = 33,

	/// Server didn't authorize access to resource.
	DOWNLOAD_INTERRUPT_REASON_SERVER_UNAUTHORIZED = 34,

	/// Server certificate problem.
	DOWNLOAD_INTERRUPT_REASON_SERVER_CERT_PROBLEM = 35,

	/// Server access forbidden.
	DOWNLOAD_INTERRUPT_REASON_SERVER_FORBIDDEN = 36,

	/// Unexpected server response. This might indicate that the responding server
	/// may not be the intended server.
	DOWNLOAD_INTERRUPT_REASON_SERVER_UNREACHABLE = 37,

	/// The server sent fewer bytes than the content-length header. It may
	/// indicate that the connection was closed prematurely, or the Content-Length
	/// header was invalid. The download is only interrupted if strong validators
	/// are present. Otherwise, it is treated as finished.
	DOWNLOAD_INTERRUPT_REASON_SERVER_CONTENT_LENGTH_MISMATCH = 38,

	/// An unexpected cross-origin redirect happened.
	DOWNLOAD_INTERRUPT_REASON_SERVER_CROSS_ORIGIN_REDIRECT = 39,

	// User input.

	/// The user canceled the download.
	DOWNLOAD_INTERRUPT_REASON_USER_CANCELED = 40,

	/// The user shut down the browser.
	/// Internal use only:	resume pending downloads if possible.
	DOWNLOAD_INTERRUPT_REASON_USER_SHUTDOWN = 41,

	// Crash.

	/// The browser crashed.
	/// Internal use only:	resume pending downloads if possible.
	DOWNLOAD_INTERRUPT_REASON_CRASH = 50,
}

/// Specifies the gesture commands.
Gesture_command :: enum u32 {
	GESTURE_COMMAND_BACK,
	GESTURE_COMMAND_FORWARD,
}

/// Specifies the zoom commands supported by CefBrowserHost::Zoom.
Zoom_command :: enum u32 {
	ZOOM_COMMAND_OUT,
	ZOOM_COMMAND_RESET,
	ZOOM_COMMAND_IN,
}

/// Specifies the color variants supported by CefRequestContext::SetChromeThemeColor.
///
Color_variant :: enum u32 {
	COLOR_VARIANT_SYSTEM,
	COLOR_VARIANT_LIGHT,
	COLOR_VARIANT_DARK,
	COLOR_VARIANT_TONAL_SPOT,
	COLOR_VARIANT_NEUTRAL,
	COLOR_VARIANT_VIBRANT,
	COLOR_VARIANT_EXPRESSIVE,
	COLOR_VARIANT_NUM_VALUES,
}

/// Specifies the task type variants supported by CefTaskManager. Should be kept in sync with Chromium's task_manager::Task::Type type.
///
Task_type :: enum u32 {
	TASK_TYPE_UNKNOWN,
	/// The main browser process.
	TASK_TYPE_BROWSER,
	/// A graphics process.
	TASK_TYPE_GPU,
	/// A Linux zygote process.
	TASK_TYPE_ZYGOTE,
	/// A browser utility process.
	TASK_TYPE_UTILITY,
	/// A normal WebContents renderer process.
	TASK_TYPE_RENDERER,
	/// An extension or app process.
	TASK_TYPE_EXTENSION,
	/// A browser plugin guest process.
	TASK_TYPE_GUEST,
	/// A plugin process.
	TASK_TYPE_PLUGIN,
	/// A sandbox helper process
	TASK_TYPE_SANDBOX_HELPER,
	/// A dedicated worker running on the renderer process.
	TASK_TYPE_DEDICATED_WORKER,
	/// A shared worker running on the renderer process.
	TASK_TYPE_SHARED_WORKER,
	/// A service worker running on the renderer process.
	TASK_TYPE_SERVICE_WORKER,

	TASK_TYPE_NUM_VALUES,
}

/// Structure representing task information provided by CefTaskManager.
Task_info :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// The task ID.
	id: i64,
	/// The task type.
	type: Task_type,
	/// Set to true (1) if the task is killable.
	is_killable: c.int,
	/// The task title.
	title: cef_string,
	/// The CPU usage of the process on which the task is running. The value is
	/// in the range zero to number_of_processors * 100%.
	cpu_usage: f64,
	/// The number of processors available on the system.
	number_of_processors: c.int,
	/// The memory footprint of the task in bytes. A value of -1 means no valid
	/// value is currently available.
	memory: i64,
	/// The GPU memory usage of the task in bytes. A value of -1 means no valid
	/// value is currently available.
	gpu_memory: i64,
	/// Set to true (1) if this task process' GPU resource count is inflated
	/// because it is counting other processes' resources (e.g, the GPU process
	/// has this value set to true because it is the aggregate of all processes).
	is_gpu_memory_inflated: c.int,
}
