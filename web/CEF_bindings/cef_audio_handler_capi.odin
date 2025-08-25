package odin_cef

import "core:c"

/// Implement this structure to handle audio events.
/// NOTE: This struct is allocated client-side.
///
Audio_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called on the UI thread to allow configuration of audio stream parameters. Return true (1) to proceed with audio stream capture, or false (0) to
	/// cancel it. All members of |params| can optionally be configured here, but
	/// they are also pre-filled with some sensible defaults.
	get_audio_parameters: proc "system" (self: ^Audio_handler, browser: ^Browser, params: ^Audio_parameters) -> b32,

	/// Called on a browser audio capture thread when the browser starts streaming audio. on_audio_stream_stopped will always be called after
	/// on_audio_stream_started; both functions may be called multiple times for the
	/// same browser. |params| contains the audio parameters like sample rate and
	/// channel layout. |channels| is the number of channels.
	on_audio_stream_started: proc "system" (self: ^Audio_handler, browser: ^Browser, params: ^Audio_parameters, channels: c.int),

	/// Called on the audio stream thread when a PCM packet is received for the stream. |data| is an array representing the raw PCM data as a floating
	/// point type, i.e. 4-byte value(s). |frames| is the number of frames in the
	/// PCM packet. |pts| is the presentation timestamp (in milliseconds since the
	/// Unix Epoch) and represents the time at which the decompressed packet
	/// should be presented to the user. Based on |frames| and the
	/// |channel_layout| value passed to on_audio_stream_started you can calculate
	/// the size of the |data| array in bytes.
	on_audio_stream_packet: proc "system" (self: ^Audio_handler, browser: ^Browser, data: ^[^]f32, frames: c.int, pts: i64),

	/// Called on the UI thread when the stream has stopped. on_audio_stream_stopped will always be called after on_audio_stream_started; both functions may be
	/// called multiple times for the same stream.
	on_audio_stream_stopped: proc "system" (self: ^Audio_handler, browser: ^Browser),

	/// Called on the UI or audio stream thread when an error occurred. During the stream creation phase this callback will be called on the UI thread while
	/// in the capturing phase it will be called on the audio stream thread. The
	/// stream will be stopped immediately.
	on_audio_stream_error: proc "system" (self: ^Audio_handler, browser: ^Browser, message: ^cef_string),
} 