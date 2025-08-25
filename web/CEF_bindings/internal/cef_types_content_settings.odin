package cef_internal

import "core:c"

// Supported content setting types. Some are platform-specific or Chrome-style only.
// Keep in sync with Chromium's ContentSettingsType.
Content_setting_types :: enum c.int {
	// Governs whether cookies are enabled by the user in the context. May be overridden by other settings.
	// Do NOT read this directly to decide cookie enablement; use the CookieSettings API instead.
	CEF_CONTENT_SETTING_TYPE_COOKIES,

	CEF_CONTENT_SETTING_TYPE_IMAGES,
	CEF_CONTENT_SETTING_TYPE_JAVASCRIPT,

	// Governs both popups and unwanted redirects (tab-unders, framebusting).
	CEF_CONTENT_SETTING_TYPE_POPUPS,

	CEF_CONTENT_SETTING_TYPE_GEOLOCATION,
	CEF_CONTENT_SETTING_TYPE_NOTIFICATIONS,
	CEF_CONTENT_SETTING_TYPE_AUTO_SELECT_CERTIFICATE,
	CEF_CONTENT_SETTING_TYPE_MIXEDSCRIPT,
	CEF_CONTENT_SETTING_TYPE_MEDIASTREAM_MIC,
	CEF_CONTENT_SETTING_TYPE_MEDIASTREAM_CAMERA,
	CEF_CONTENT_SETTING_TYPE_PROTOCOL_HANDLERS,
	CEF_CONTENT_SETTING_TYPE_DEPRECATED_PPAPI_BROKER,
	CEF_CONTENT_SETTING_TYPE_AUTOMATIC_DOWNLOADS,

	// Advanced device-specific MIDI functions (SysEx may change device persistent state).
	CEF_CONTENT_SETTING_TYPE_MIDI_SYSEX,

	CEF_CONTENT_SETTING_TYPE_SSL_CERT_DECISIONS,
	CEF_CONTENT_SETTING_TYPE_PROTECTED_MEDIA_IDENTIFIER,
	CEF_CONTENT_SETTING_TYPE_APP_BANNER,
	CEF_CONTENT_SETTING_TYPE_SITE_ENGAGEMENT,
	CEF_CONTENT_SETTING_TYPE_DURABLE_STORAGE,
	CEF_CONTENT_SETTING_TYPE_USB_CHOOSER_DATA,
	CEF_CONTENT_SETTING_TYPE_BLUETOOTH_GUARD,
	CEF_CONTENT_SETTING_TYPE_BACKGROUND_SYNC,
	CEF_CONTENT_SETTING_TYPE_AUTOPLAY,
	CEF_CONTENT_SETTING_TYPE_IMPORTANT_SITE_INFO,
	CEF_CONTENT_SETTING_TYPE_PERMISSION_AUTOBLOCKER_DATA,
	CEF_CONTENT_SETTING_TYPE_ADS,

	// Stores metadata for subresource filter UI decisions.
	CEF_CONTENT_SETTING_TYPE_ADS_DATA,

	// MIDI standard (instruments/computers/devices communication).
	CEF_CONTENT_SETTING_TYPE_MIDI,

	// Cache of password protection verdicts per origin.
	CEF_CONTENT_SETTING_TYPE_PASSWORD_PROTECTION,

	// Engagement data for media for a specific origin.
	CEF_CONTENT_SETTING_TYPE_MEDIA_ENGAGEMENT,

	// Whether site can play audible sound (doesn't block playback; just mutes user-facing sound).
	CEF_CONTENT_SETTING_TYPE_SOUND,

	// Client hints the origin requested the browser remember; sent on subsequent requests.
	CEF_CONTENT_SETTING_TYPE_CLIENT_HINTS,

	// Generic Sensor API (ambient-light, accelerometer, gyroscope, magnetometer).
	CEF_CONTENT_SETTING_TYPE_SENSORS,

	// Permission to respond to accessibility events (deprecated in M131).
	CEF_CONTENT_SETTING_TYPE_DEPRECATED_ACCESSIBILITY_EVENTS,

	// Allow a website to install a payment handler.
	CEF_CONTENT_SETTING_TYPE_PAYMENT_HANDLER,

	// Whether sites can ask for permission to access USB devices. Specific device grants are under USB_CHOOSER_DATA.
	CEF_CONTENT_SETTING_TYPE_USB_GUARD,

	// Background Fetch permission context placeholder (no stored data).
	CEF_CONTENT_SETTING_TYPE_BACKGROUND_FETCH,

	// Counts user dismissals of intent picker UI without choosing an option.
	CEF_CONTENT_SETTING_TYPE_INTENT_PICKER_DISPLAY,

	// Allow website to detect user idle/active state.
	CEF_CONTENT_SETTING_TYPE_IDLE_DETECTION,

	// Serial ports access: guard (ask-permission) and chooser data (granted ports).
	CEF_CONTENT_SETTING_TYPE_SERIAL_GUARD,
	CEF_CONTENT_SETTING_TYPE_SERIAL_CHOOSER_DATA,

	// Periodic Background Sync permission context placeholder (not registered).
	CEF_CONTENT_SETTING_TYPE_PERIODIC_BACKGROUND_SYNC,

	// Whether sites can ask for Bluetooth scanning permission.
	CEF_CONTENT_SETTING_TYPE_BLUETOOTH_SCANNING,

	// HID devices access: guard and chooser data.
	CEF_CONTENT_SETTING_TYPE_HID_GUARD,
	CEF_CONTENT_SETTING_TYPE_HID_CHOOSER_DATA,

	// Wake Lock API (screen/system).
	CEF_CONTENT_SETTING_TYPE_WAKE_LOCK_SCREEN,
	CEF_CONTENT_SETTING_TYPE_WAKE_LOCK_SYSTEM,

	// Legacy SameSite cookie behavior (disables Lax-by-default, None-requires-Secure, Schemeful Same-Site).
	CEF_CONTENT_SETTING_TYPE_LEGACY_COOKIE_ACCESS,

	// Allow sites to ask to save changes to original files via File System Access API.
	CEF_CONTENT_SETTING_TYPE_FILE_SYSTEM_WRITE_GUARD,

	// Allow data exchange with NFC devices.
	CEF_CONTENT_SETTING_TYPE_NFC,

	// Permissions for particular Bluetooth devices.
	CEF_CONTENT_SETTING_TYPE_BLUETOOTH_CHOOSER_DATA,

	// Full system clipboard access (sanitized read w/o gesture; unsanitized read/write with gesture).
	CEF_CONTENT_SETTING_TYPE_CLIPBOARD_READ_WRITE,

	// Always allowed in permissions layer; no associated prefs.
	CEF_CONTENT_SETTING_TYPE_CLIPBOARD_SANITIZED_WRITE,

	// Cache of Safe Browsing real-time URL check verdicts per origin.
	CEF_CONTENT_SETTING_TYPE_SAFE_BROWSING_URL_CHECK_DATA,

	// WebXR AR/VR sessions.
	CEF_CONTENT_SETTING_TYPE_VR,
	CEF_CONTENT_SETTING_TYPE_AR,

	// Allow reading files/directories selected via File System Access API.
	CEF_CONTENT_SETTING_TYPE_FILE_SYSTEM_READ_GUARD,

	// First-party storage in third-party context (Storage Access API). In parallel with cookie rules.
	CEF_CONTENT_SETTING_TYPE_STORAGE_ACCESS,

	// Whether site can control camera movements (no direct camera access).
	CEF_CONTENT_SETTING_TYPE_CAMERA_PAN_TILT_ZOOM,

	// Screen Enumeration/Detail: detailed multi-screen info and placement.
	CEF_CONTENT_SETTING_TYPE_WINDOW_MANAGEMENT,

	// Private network requests by insecure websites (API >= 13800 uses *_DEPRECATED name).
	CEF_CONTENT_SETTING_TYPE_INSECURE_PRIVATE_NETWORK_DEPRECATED,

	// Low-level local fonts access via Local Fonts Access API.
	CEF_CONTENT_SETTING_TYPE_LOCAL_FONTS,

	// Per-origin state for permission auto-revocation.
	CEF_CONTENT_SETTING_TYPE_PERMISSION_AUTOREVOCATION_DATA,

	// Per-origin last picked directory for File System Access API.
	CEF_CONTENT_SETTING_TYPE_FILE_SYSTEM_LAST_PICKED_DIRECTORY,

	// Controls access to getDisplayMedia API.
	CEF_CONTENT_SETTING_TYPE_DISPLAY_CAPTURE,

	// Permissions metadata for File System Access API; meaningful with extended permission opt-in.
	CEF_CONTENT_SETTING_TYPE_FILE_SYSTEM_ACCESS_CHOOSER_DATA,

	// Grant for relying party to request identity info from IdPs (FedCM). Associated with relying party origin.
	CEF_CONTENT_SETTING_TYPE_FEDERATED_IDENTITY_SHARING,

	// Whether to use V8 optimized JIT for JavaScript.
	CEF_CONTENT_SETTING_TYPE_JAVASCRIPT_JIT,

	// Allow loading over HTTP (HTTPS-First bypass allowlist) by hostname.
	CEF_CONTENT_SETTING_TYPE_HTTP_ALLOWED,

	// Metadata related to form fill (e.g., whether autofill occurred).
	CEF_CONTENT_SETTING_TYPE_FORMFILL_METADATA,

	// Indicates active federated sign-in session (obsolete Nov 2023).
	CEF_CONTENT_SETTING_TYPE_DEPRECATED_FEDERATED_IDENTITY_ACTIVE_SESSION,

	// Auto-darken web content.
	CEF_CONTENT_SETTING_TYPE_AUTO_DARK_WEB_CONTENT,

	// Request desktop site instead of mobile.
	CEF_CONTENT_SETTING_TYPE_REQUEST_DESKTOP_SITE,

	// Allow signing into website via FedCM API.
	CEF_CONTENT_SETTING_TYPE_FEDERATED_IDENTITY_API,

	// Notification interactions per origin (90 days, aggregated weekly).
	CEF_CONTENT_SETTING_TYPE_NOTIFICATION_INTERACTIONS,

	// Last reduced accept-language negotiated for an origin.
	CEF_CONTENT_SETTING_TYPE_REDUCED_ACCEPT_LANGUAGE,

	// Origin blocklist from notification permission review.
	CEF_CONTENT_SETTING_TYPE_NOTIFICATION_PERMISSION_REVIEW,

	// Private network device permissions.
	CEF_CONTENT_SETTING_TYPE_PRIVATE_NETWORK_GUARD,
	CEF_CONTENT_SETTING_TYPE_PRIVATE_NETWORK_CHOOSER_DATA,

	// Observed IdP-SignIn-Status header indicating user signed into IdP.
	CEF_CONTENT_SETTING_TYPE_FEDERATED_IDENTITY_IDENTITY_PROVIDER_SIGNIN_STATUS,

	// Revoked permissions for unused sites.
	CEF_CONTENT_SETTING_TYPE_REVOKED_UNUSED_SITE_PERMISSIONS,

	// Page-level storage access.
	CEF_CONTENT_SETTING_TYPE_TOP_LEVEL_STORAGE_ACCESS,

	// Opt-in to FedCM auto re-authentication.
	CEF_CONTENT_SETTING_TYPE_FEDERATED_IDENTITY_AUTO_REAUTHN_PERMISSION,

	// User explicitly registered a site as an identity provider.
	CEF_CONTENT_SETTING_TYPE_FEDERATED_IDENTITY_IDENTITY_PROVIDER_REGISTRATION,

	// Enable anti-abuse functionality.
	CEF_CONTENT_SETTING_TYPE_ANTI_ABUSE,

	// Enable third-party storage partitioning.
	CEF_CONTENT_SETTING_TYPE_THIRD_PARTY_STORAGE_PARTITIONING,

	// HTTPS-First Mode enabled on hostname.
	CEF_CONTENT_SETTING_TYPE_HTTPS_ENFORCED,

	// Enable getAllScreensMedia API.
	CEF_CONTENT_SETTING_TYPE_ALL_SCREEN_CAPTURE,

	// Per-origin metadata for cookie controls.
	CEF_CONTENT_SETTING_TYPE_COOKIE_CONTROLS_METADATA,

	// Temporary 3PC access grants via user-behavior heuristics.
	CEF_CONTENT_SETTING_TYPE_TPCD_HEURISTICS_GRANTS,

	// 3PC access grants via component-updated metadata.
	CEF_CONTENT_SETTING_TYPE_TPCD_METADATA_GRANTS,

	// 3PC access grants via deprecation trial.
	CEF_CONTENT_SETTING_TYPE_TPCD_TRIAL,

	// Page-level 3PC deprecation trial grants (lifetime of the serving page).
	CEF_CONTENT_SETTING_TYPE_TOP_LEVEL_TPCD_TRIAL,

	// First-party origin trial to enable 3PC deprecation (top-level).
	CEF_CONTENT_SETTING_TYPE_TOP_LEVEL_TPCD_ORIGIN_TRIAL,

	// Auto-enter Picture-in-Picture.
	CEF_CONTENT_SETTING_TYPE_AUTO_PICTURE_IN_PICTURE,

	// Persist file/directory permissions between visits (FSA extended permission).
	CEF_CONTENT_SETTING_TYPE_FILE_SYSTEM_ACCESS_EXTENDED_PERMISSION,

	// Eligibility for restoring FSA persistent permissions prompt.
	CEF_CONTENT_SETTING_TYPE_FILE_SYSTEM_ACCESS_RESTORE_PERMISSION,

	// Allow a capturing tab to scroll/zoom the captured tab.
	CEF_CONTENT_SETTING_TYPE_CAPTURED_SURFACE_CONTROL,

	// Smart Card API access: guard and data.
	CEF_CONTENT_SETTING_TYPE_SMART_CARD_GUARD,
	CEF_CONTENT_SETTING_TYPE_SMART_CARD_DATA,

	// Web Printing API access.
	CEF_CONTENT_SETTING_TYPE_WEB_PRINTING,

	// Auto-enter HTML Fullscreen without transient activation.
	CEF_CONTENT_SETTING_TYPE_AUTOMATIC_FULLSCREEN,

	// Allow web app to prompt installation of sub apps.
	CEF_CONTENT_SETTING_TYPE_SUB_APP_INSTALLATION_PROMPTS,

	// Enumerate audio output devices.
	CEF_CONTENT_SETTING_TYPE_SPEAKER_SELECTION,

	// Direct Sockets API access.
	CEF_CONTENT_SETTING_TYPE_DIRECT_SOCKETS,

	// Keyboard Lock API (capture OS/browser-handled keys).
	CEF_CONTENT_SETTING_TYPE_KEYBOARD_LOCK,

	// Pointer Lock API (exclusive mouse input; hide cursor).
	CEF_CONTENT_SETTING_TYPE_POINTER_LOCK,

	// Auto-revoked notification permissions from abusive sites.
	CEF_CONTENT_SETTING_TYPE_REVOKED_ABUSIVE_NOTIFICATION_PERMISSIONS,

	// Tracking protection per site:
	//	 BLOCK (default): protections enabled; ALLOW: protections disabled.
	CEF_CONTENT_SETTING_TYPE_TRACKING_PROTECTION,

	// Allow returning system audio track from getDisplayMedia without picker (WebUI only).
	CEF_CONTENT_SETTING_TYPE_DISPLAY_MEDIA_SYSTEM_AUDIO,

	// Higher-tier V8 optimizers for JavaScript.
	CEF_CONTENT_SETTING_TYPE_JAVASCRIPT_OPTIMIZER,

	// Storage Access Headers persistent origin trial (scoped appropriately).
	// ALLOW: attach headers / enable behavior; BLOCK (default): no effect.
	CEF_CONTENT_SETTING_TYPE_STORAGE_ACCESS_HEADER_ORIGIN_TRIAL,

	// WebXR Hand Tracking permission.
	CEF_CONTENT_SETTING_TYPE_HAND_TRACKING,

	// User opt-in allowing web apps to install other web apps.
	CEF_CONTENT_SETTING_TYPE_WEB_APP_INSTALLATION,

	// Direct Sockets API private network access.
	CEF_CONTENT_SETTING_TYPE_DIRECT_SOCKETS_PRIVATE_NETWORK_ACCESS,

	// Legacy cookie scope handling vs origin-bound cookies.
	CEF_CONTENT_SETTING_TYPE_LEGACY_COOKIE_SCOPE,

	// Added in API 13400: suspicious notifications allowlisted by user; Controlled Frame API access.
	CEF_CONTENT_SETTING_TYPE_ARE_SUSPICIOUS_NOTIFICATIONS_ALLOWLISTED_BY_USER,
	CEF_CONTENT_SETTING_TYPE_CONTROLLED_FRAME,

	// Added in API 13500: revoked notification permissions of disruptive sites.
	CEF_CONTENT_SETTING_TYPE_REVOKED_DISRUPTIVE_NOTIFICATION_PERMISSIONS,

	// Added in API 13600: whether site may make local network requests.
	CEF_CONTENT_SETTING_TYPE_LOCAL_NETWORK_ACCESS,

	// Added in API 13800: on-device speech recognition languages downloaded; initialized translations; suspicious notification IDs.
	CEF_CONTENT_SETTING_TYPE_ON_DEVICE_SPEECH_RECOGNITION_LANGUAGES_DOWNLOADED,
	CEF_CONTENT_SETTING_TYPE_INITIALIZED_TRANSLATIONS,
	CEF_CONTENT_SETTING_TYPE_SUSPICIOUS_NOTIFICATION_IDS,

	CEF_CONTENT_SETTING_TYPE_NUM_VALUES,
}

// Supported content setting values. Keep in sync with Chromium's ContentSetting.
Content_setting_values :: enum c.int {
	CEF_CONTENT_SETTING_VALUE_DEFAULT,
	CEF_CONTENT_SETTING_VALUE_ALLOW,
	CEF_CONTENT_SETTING_VALUE_BLOCK,
	CEF_CONTENT_SETTING_VALUE_ASK,
	CEF_CONTENT_SETTING_VALUE_SESSION_ONLY,
	CEF_CONTENT_SETTING_VALUE_DETECT_IMPORTANT_CONTENT,

	CEF_CONTENT_SETTING_VALUE_NUM_VALUES,
}
