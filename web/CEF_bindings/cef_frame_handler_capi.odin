package odin_cef

import "core:c"

/// Implement this structure to handle events related to frame lifespan. The order of callbacks is:
/// (1) During initial Browser_host creation and navigation of the main frame:
/// - Frame_handler::on_frame_created => The initial main frame object has
///	 been created. Any commands will be queued until the frame is attached.
/// - Frame_handler::on_main_frame_changed => The initial main frame object
///	 has been assigned to the browser.
/// - life_span_handler::on_after_created => The browser is now valid and
///	 can be used.
/// - Frame_handler::on_frame_attached => The initial main frame object is
///	 now connected to its peer in the renderer process. Commands can be routed.
/// (2) During further Browser_host navigation/loading of the main frame	 and/or sub-frames:
/// - Frame_handler::on_frame_created => A new main frame or sub-frame
///	 object has been created. Any commands will be queued until the frame is
///	 attached.
/// - Frame_handler::on_frame_attached => A new main frame or sub-frame
///	 object is now connected to its peer in the renderer process. Commands can
///	 be routed.
/// - Frame_handler::on_frame_detached => An existing main frame or sub-
///	 frame object has lost its connection to the renderer process. If multiple
///	 objects are detached at the same time then notifications will be sent for
///	 any sub-frame objects before the main frame object. Commands can no longer
///	 be routed and will be discarded.
/// - Frame_handler::on_frame_destroyed => An existing main frame or sub-frame
///	 object has been destroyed.
/// - Frame_handler::on_main_frame_changed => A new main frame object has
///	 been assigned to the browser. This will only occur with cross-origin
///	 navigation or re-navigation after renderer process termination (due to
///	 crashes, etc).
/// (3) During final Browser_host destruction of the main frame: - Frame_handler::on_frame_detached => Any sub-frame objects have lost
///	 their connection to the renderer process. Commands can no longer be routed
///	 and will be discarded.
/// - Frame_handler::on_frame_destroyed => Any sub-frame objects have been
///	 destroyed.
/// - life_span_handler::on_before_close => The browser has been destroyed.
/// - Frame_handler::on_frame_detached => The main frame object have lost
///	 its connection to the renderer process. Notifications will be sent for any
///	 sub-frame objects before the main frame object. Commands can no longer be
///	 routed and will be discarded.
/// - Frame_handler::on_frame_destroyed => The main frame object has been
///	 destroyed.
/// - Frame_handler::on_main_frame_changed => The final main frame object has
///	 been removed from the browser.
/// Special handling applies for cross-origin loading on creation/navigation of sub-frames, and cross-origin loading on creation of new popup browsers. A
/// temporary frame will first be created in the parent frame's renderer
/// process. This temporary frame will never attach and will be discarded after
/// the real cross-origin frame is created in the new/target renderer process.
/// The client will receive creation callbacks for the temporary frame, followed
/// by cross-origin navigation callbacks (2) for the transition from the
/// temporary frame to the real frame. The temporary frame will not receive or
/// execute commands during this transitional period (any sent commands will be
/// discarded).
/// When the main frame navigates to a different origin the on_main_frame_changed callback (2) will be executed with the old and new main frame objects.
/// Callbacks will not be executed for placeholders that may be created during pre-commit navigation for sub-frames that do not yet exist in the renderer
/// process. Placeholders will have frame::get_identifier() == -4.
/// The functions of this structure will be called on the UI thread unless otherwise indicated.
/// NOTE: This struct is allocated client-side.
Frame_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when a new frame is created. This will be the first notification that references |frame|. Any commands that require transport to the
	/// associated renderer process (LoadRequest, SendProcessMessage, GetSource,
	/// etc.) will be queued. The queued commands will be sent before
	/// on_frame_attached or discarded before on_frame_destroyed if the frame never
	/// attaches.
	on_frame_created: proc "system" (self: ^Frame_handler, browser: ^Browser, frame: ^Frame),

	/// Called when an existing frame is destroyed. This will be the last notification that references |frame| and frame::is_valid() will
	/// return false (0) for |frame|. If called during browser destruction and
	/// after life_span_handler::on_before_close() then
	/// browser::is_valid() will return false (0) for |browser|. Any queued
	/// commands that have not been sent will be discarded before this callback.
	on_frame_destroyed: proc "system" (self: ^Frame_handler, browser: ^Browser, frame: ^Frame),

	/// Called when a frame can begin routing commands to/from the associated renderer process. |reattached| will be true (1) if the frame was re-
	/// attached after exiting the BackForwardCache or after encountering a
	/// recoverable connection error. Any queued commands will now have been
	/// dispatched. This function will not be called for temporary frames created
	/// during cross-origin navigation.
	on_frame_attached: proc "system" (self: ^Frame_handler, browser: ^Browser, frame: ^Frame, reattached: b32),

	/// Called when a frame loses its connection to the renderer process. This may occur when a frame is destroyed, enters the BackForwardCache, or
	/// encounters a rare connection error. In the case of frame destruction this
	/// call will be followed by a (potentially async) call to on_frame_destroyed.
	/// If frame destruction is occuring synchronously then
	/// frame::is_valid() will return false (0) for |frame|. If called
	/// during browser destruction and after
	/// life_span_handler::on_before_close() then browser::is_valid()
	/// will return false (0) for |browser|. If, in the non-destruction case, the
	/// same frame later exits the BackForwardCache or recovers from a connection
	/// error then there will be a follow-up call to on_frame_attached. This
	/// function will not be called for temporary frames created during cross-
	/// origin navigation.
	on_frame_detached: proc "system" (self: ^Frame_handler, browser: ^Browser, frame: ^Frame),

	/// Called when the main frame changes due to (a) initial browser creation, (b) final browser destruction, (c) cross-origin navigation or (d) re-
	/// navigation after renderer process termination (due to crashes, etc).
	/// |old_frame| will be NULL and |new_frame| will be non-NULL when a main
	/// frame is assigned to |browser| for the first time. |old_frame| will be
	/// non-NULL and |new_frame| will be NULL when a main frame is removed from
	/// |browser| for the last time. Both |old_frame| and |new_frame| will be non-
	/// NULL for cross-origin navigations or re-navigation after renderer process
	/// termination. This function will be called after on_frame_created() for
	/// the new frame and before on_frame_destroyed() for the old frame.
	on_main_frame_changed: proc "system" (self: ^Frame_handler, browser: ^Browser, old_frame: ^Frame, new_frame: ^Frame),
} 