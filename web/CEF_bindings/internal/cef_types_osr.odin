package cef_internal

import "core:c"

/// Structure containing shared texture common metadata. For documentation on each field, please refer to
/// src/media/base/video_frame_metadata.h for actual details.
///
accelerated_paint_info_common :: struct {
	/// Size of this structure.
	size: c.size_t,

	/// Timestamp of the frame in microseconds since capture start.
	timestamp: u64,

	/// The full dimensions of the video frame.
	coded_size: cef_size,

	/// The visible area of the video frame.
	visible_rect: cef_rect,

	/// The region of the video frame that capturer would like to populate.
	content_rect: cef_rect,

	/// Full size of the source frame.
	source_size: cef_size,

	/// Updated area of frame, can be considered as the `dirty` area.
	capture_update_rect: cef_rect,

	/// May reflects where the frame's contents originate from if region capture is used internally.
	region_capture_rect: cef_rect,

	/// The increamental counter of the frame.
	capture_counter: u64,

	/// Optional flag of capture_update_rect
	has_capture_update_rect: u8,

	/// Optional flag of region_capture_rect
	has_region_capture_rect: u8,

	/// Optional flag of source_size
	has_source_size: u8,

	/// Optional flag of capture_counter
	has_capture_counter: u8,
}
