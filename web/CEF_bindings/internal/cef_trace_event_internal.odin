package cef_internal

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

// See include/base/cef_trace_event.h for macros and intended usage.

// Functions for tracing counters and functions; called from macros.
// - |category| string must have application lifetime (static or literal). They
//	 may not include "(quotes) chars.
// - |argX_name|, |argX_val|, |valueX_name|, |valeX_val| are optional parameters
//	 and represent pairs of name and values of arguments
// - |id| is used to disambiguate counters with the same name, or match async
//	 trace events

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	trace_event_instant :: proc (category: cstring, name: cstring, arg1_name: cstring, arg1_val: u64, arg2_name: cstring, arg2_val: u64) ---
	trace_event_begin :: proc (category: cstring, name: cstring, arg1_name: cstring, arg1_val: u64, arg2_name: cstring, arg2_val: u64) ---
	trace_event_end :: proc (category: cstring, name: cstring, arg1_name: cstring, arg1_val: u64, arg2_name: cstring, arg2_val: u64) ---
	trace_counter :: proc (category: cstring, name: cstring, value1_name: cstring, value1_val: u64, value2_name: cstring, value2_val: u64) ---
	trace_counter_id :: proc (category: cstring, name: cstring, id: u64, value1_name: cstring, value1_val: u64, value2_name: cstring, value2_val: u64) ---
	trace_event_async_begin :: proc (category: cstring, name: cstring, id: u64, arg1_name: cstring, arg1_val: u64, arg2_name: cstring, arg2_val: u64) ---
	trace_event_async_step_into :: proc (category: cstring, name: cstring, id: u64, step: u64, arg1_name: cstring, arg1_val: u64) ---
	trace_event_async_step_past :: proc (category: cstring, name: cstring, id: u64, step: u64, arg1_name: cstring, arg1_val: u64) ---
	trace_event_async_end :: proc (category: cstring, name: cstring, id: u64, arg1_name: cstring, arg1_val: u64, arg2_name: cstring, arg2_val: u64) ---
}
