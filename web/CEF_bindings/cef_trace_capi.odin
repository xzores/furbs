package odin_cef

import "core:c"

/// Implement this structure to receive notification when tracing has completed. The functions of this structure will be called on the browser process UI
/// thread.
/// NOTE: This struct is allocated client-side.
end_tracing_callback :: struct {
	/// Base structure.
	base: base_ref_counted,
	
	/// Called after all processes have sent their trace data. |tracing_file| is the path at which tracing data was written. The client is responsible for
	/// deleting |tracing_file|.
	on_end_tracing_complete: proc "system" (self: ^end_tracing_callback, tracing_file: ^cef_string),
}

/// Start tracing events on all processes. Tracing is initialized asynchronously and |callback| will be executed on the UI thread after initialization is
/// complete.
/// If begin_tracing was called previously, or if a end_tracing_async call is pending, begin_tracing will fail and return false (0).
/// |categories| is a comma-delimited list of category wildcards. A category can have an optional '-' prefix to make it an excluded category. Having both
/// included and excluded categories in the same list is not supported.
/// Examples: - "test_MyTest*"
/// - "test_MyTest*,test_OtherStuff"
/// - "-excluded_category1,-excluded_category2"
/// This function must be called on the browser process UI thread.
begin_tracing :: proc "system" (categories: ^cef_string, callback: ^Completion_callback) -> b32

/// Stop tracing events on all processes.
/// This function will fail and return false (0) if a previous call to
/// end_tracing_async is already pending or if begin_tracing was not called.
/// |tracing_file| is the path at which tracing data will be written and |callback| is the callback that will be executed once all processes have
/// sent their trace data. If |tracing_file| is NULL a new temporary file path
/// will be used. If |callback| is NULL no trace data will be written.
/// This function must be called on the browser process UI thread.
end_tracing :: proc "system" (tracing_file: ^cef_string, callback: ^end_tracing_callback) -> b32

/// Returns the current system trace time or, if none is defined, the current high-res time. Can be used by clients to synchronize with the time
/// information in trace events.
///
now_from_system_trace_time :: proc "system" () -> i64 