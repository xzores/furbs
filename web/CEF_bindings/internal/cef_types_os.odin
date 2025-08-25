package cef_internal

import "core:c"


/// Structure containing shared texture common metadata.
/// For documentation on each field, please refer to
/// src/media/base/video_frame_metadata.h for actual details.
Accelerated_paint_info_common :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Timestamp of the frame in microseconds since capture start.
	timestamp: c.uint64_t,

	/// The full dimensions of the video frame.
	coded_size: cef_size,

	/// The visible area of the video frame.
	visible_rect: cef_rect,

	/// The region of the video frame that the capturer would like to populate.
	content_rect: cef_rect,

	/// Full size of the source frame.
	source_size: cef_size,

	/// Updated area of frame, can be considered as the `dirty` area.
	capture_update_rect: cef_rect,

	/// May reflect where the frame's contents originate from if region
	/// capture is used internally.
	region_capture_rect: cef_rect,

	/// The incremental counter of the frame.
	capture_counter: c.uint64_t,

	/// Optional flag of capture_update_rect
	has_capture_update_rect: c.uint8_t,

	/// Optional flag of region_capture_rect
	has_region_capture_rect: c.uint8_t,

	/// Optional flag of source_size
	has_source_size: c.uint8_t,

	/// Optional flag of capture_counter
	has_capture_counter: c.uint8_t,
}



when ODIN_OS == .Windows {
	
	// Windows handle aliases.

	// Actually HCURSOR
	Cursor_handle         :: rawptr
	// Actually MSG*
	Event_handle          :: rawptr
	// Actually HWND
	Window_handle         :: rawptr
	// Actually HANDLE
	Shared_texture_handle :: rawptr

	// -----------------------------------------------------------------------------
	// CefExecuteProcess arguments (Windows)
	// -----------------------------------------------------------------------------
	/// Structure representing CefExecuteProcess arguments.
	Main_args :: struct {
		/// HINSTANCE for the current process.
		instance: rawptr, // HINSTANCE
	}

	// -----------------------------------------------------------------------------
	// Window information (Windows)
	// -----------------------------------------------------------------------------
	/// Structure representing window information.
	Window_info :: struct {
		/// Size of this structure.
		size: c.size_t,

		// Standard parameters required by CreateWindowEx()
		ex_style: c.ulong,            // DWORD
		window_name: cef_string,
		style: c.ulong,               // DWORD
		bounds: cef_rect,
		parent_window: Window_handle,
		menu: rawptr,             // HMENU

		/// See long description in CEF docs.
		windowless_rendering_enabled: c.int,
		/// Only valid with windowless_rendering_enabled; Windows D3D11.
		shared_texture_enabled: c.int,
		/// Allow issuing BeginFrame via CefBrowserHost::SendExternalBeginFrame.
		external_begin_frame_enabled: c.int,

		/// Handle for the new browser window. Only used with windowed rendering.
		window: Window_handle,
		
		/// Alloy forced if windowless; otherwise per cef_runtime_style.
		runtime_style: Runtime_style,
	}

	// -----------------------------------------------------------------------------
	// Accelerated paint info (Windows)
	// -----------------------------------------------------------------------------
	/// Shared texture info for OnAcceleratedPaint; resources released on return.
	Accelerated_paint_info :: struct {
		/// Size of this structure.
		size: c.size_t,

		/// Shared texture handle (no keyed mutex).
		shared_texture_handle: Shared_texture_handle,

		/// Pixel format of the texture.
		format: color_type,

		/// Extra common info.
		extra: Accelerated_paint_info_common,
	}
}
else when ODIN_OS == .Darwin {
	// -----------------------------------------------------------------------------
	// Handle types (macOS)
	// -----------------------------------------------------------------------------

	/// Actually NSCursor*
	Cursor_handle  :: rawptr
	/// Actually NSEvent*
	Event_handle   :: rawptr
	/// Actually NSView*
	Window_handle  :: rawptr
	/// Actually IOSurface*
	Shared_texture_handle :: rawptr


	// -----------------------------------------------------------------------------
	// CefExecuteProcess arguments (macOS)
	// -----------------------------------------------------------------------------

	/// Structure representing CefExecuteProcess arguments.
	Main_args :: struct {
		argc: c.int,     // int
		argv: ^^u8,      // char**
	}


	// -----------------------------------------------------------------------------
	// Window information (macOS)
	// -----------------------------------------------------------------------------

	/// Class representing window information.
	Window_info :: struct {
		/// Size of this structure.
		size: c.size_t,

		window_name: cef_string,

		/// Initial window bounds.
		bounds: cef_rect,

		/// Create the view initially hidden.
		hidden: c.int,

		/// NSView pointer for the parent view.
		parent_view: cef_window_handle,

		/// Use windowless (off-screen) rendering.
		windowless_rendering_enabled: c.int,

		/// Enable shared textures (valid only with windowless).
		shared_texture_enabled: c.int,

		/// Allow issuing BeginFrame from the client application.
		external_begin_frame_enabled: c.int,

		/// NSView pointer for the new browser view (windowed rendering only).
		view: cef_window_handle,

		/// Runtime style (Alloy forced if windowless or parent_view provided).
		runtime_style: cef_runtime_style,
	}


	// -----------------------------------------------------------------------------
	// Accelerated paint info (macOS)
	// -----------------------------------------------------------------------------

	/// Shared texture info for OnAcceleratedPaint; resources released on return.
	Accelerated_paint_info :: struct {
		/// Size of this structure.
		size: c.size_t,

		/// Handle for the shared texture IOSurface.
		shared_texture_io_surface: cef_shared_texture_handle,

		/// Pixel format of the texture.
		format: cef_color_type,

		/// Extra common info.
		extra: cef_accelerated_paint_info_common,
	}
}
else when ODIN_OS == .Linux {

	// -----------------------------------------------------------------------------
	// X11 / non-X11 handles (Linux)
	// -----------------------------------------------------------------------------

	// Define this from your build system when targeting X11:
	// CEF_X11 :: true
	when CEF_X11 {
		// XEvent* is treated as an opaque pointer here.
		Cursor_handle  :: c.ulong;
		Event_handle   :: rawptr;
	} else {
		Cursor_handle  :: rawptr;
		Event_handle   :: rawptr;
	}

	// Always an XID on Linux.
	Window_handle :: c.ulong

	// Opaque XDisplay handle alias (XDisplay*).
	XDisplay :: rawptr

	// When on X11, expose cef_get_xdisplay.
	when CEF_X11 {
		@(default_calling_convention = "c", link_prefix = "cef_", require_results)
		foreign lib {
			/// Return the singleton X11 display shared with Chromium.
			/// Must only be accessed on the browser process UI thread.
			get_xdisplay :: proc "system" () -> XDisplay ---
		}
	}


	// -----------------------------------------------------------------------------
	// CefExecuteProcess arguments (Linux)
	// -----------------------------------------------------------------------------

	Main_args :: struct {
		argc: c.int,   // int
		argv: ^^u8,    // char**
	}


	// -----------------------------------------------------------------------------
	// Window information (Linux)
	// -----------------------------------------------------------------------------

	Window_info :: struct {
		/// Size of this structure.
		size: c.size_t,

		/// Initial window title (set before mapping if non-empty).
		window_name: cef_string,

		/// Initial window bounds.
		bounds: cef_rect,

		/// Parent window handle (XID).
		parent_window: cef_window_handle,

		/// Use windowless (off-screen) rendering.
		windowless_rendering_enabled: c.int,

		/// Enable shared textures (valid only with windowless; currently Win/D3D11).
		shared_texture_enabled: c.int,

		/// Allow issuing external BeginFrame from the client.
		external_begin_frame_enabled: c.int,

		/// New browser window handle (windowed rendering only).
		window: cef_window_handle,

		/// Runtime style (Alloy forced if windowless).
		runtime_style: cef_runtime_style,
	}


	// -----------------------------------------------------------------------------
	// Accelerated paint (Linux)
	// -----------------------------------------------------------------------------

	// Plane info (sync with native_pixmap_handle.h).
	Accelerated_paint_native_pixmap_plane :: struct {
		/// Stride and byte offset/size for mapped access.
		stride: u32,
		offset: u64,
		size:   u64,

		/// File descriptor for the underlying memory object (usually dmabuf).
		fd: c.int,
	}

	// Max planes for accelerated paint.
	Accelerated_Paint_Max_Planes :: 4

	/// Shared texture info for OnAcceleratedPaint; resources released on return.
	Accelerated_paint_info :: struct {
		/// Size of this structure.
		size: c.size_t,

		/// Planes of the shared texture (e.g., dmabufs).
		planes: [Accelerated_Paint_Max_Planes]Accelerated_paint_native_pixmap_plane,

		/// Plane count.
		plane_count: c.int,

		/// Modifier for use with EGL driver.
		modifier: u64,

		/// Pixel format of the texture.
		format: cef_color_type,

		/// Extra common info.
		extra: cef_accelerated_paint_info_common,
	}

}
else {
	#panic("Unsupported OS for CEF");
}