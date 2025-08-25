package cef_internal

/// CEF supports both a Chrome runtime style (based on the Chrome UI layer) and an Alloy runtime style (based on the Chromium content layer). Chrome style
/// provides the full Chrome UI and browser functionality whereas Alloy style
/// provides less default browser functionality but adds additional client
/// callbacks and support for windowless (off-screen) rendering. The style type
/// is individually configured for each window/browser at creation time and
/// different styles can be mixed during runtime. For additional comparative
/// details on runtime styles see
/// https://bitbucket.org/chromiumembedded/cef/wiki/Architecture.md#markdown-header-cef3
/// Windowless rendering will always use Alloy style. Windowed rendering with a default window or client-provided parent window can configure the style via
/// CefWindowInfo.runtime_style. Windowed rendering with the Views framework can
/// configure the style via CefWindowDelegate::GetWindowRuntimeStyle and
/// CefBrowserViewDelegate::GetBrowserRuntimeStyle. Alloy style Windows with the
/// Views framework can host only Alloy style BrowserViews but Chrome style
/// Windows can host both style BrowserViews. Additionally, a Chrome style
/// Window can host at most one Chrome style BrowserView but potentially
/// multiple Alloy style BrowserViews. See CefWindowInfo.runtime_style
/// documentation for any additional platform-specific limitations.
///
Runtime_style :: enum u32 {
	/// Use the default style. See above documentation for exceptions.
	RUNTIME_STYLE_DEFAULT,

	/// Use Chrome style.
	RUNTIME_STYLE_CHROME,

	/// Use Alloy style.
	RUNTIME_STYLE_ALLOY,
}
