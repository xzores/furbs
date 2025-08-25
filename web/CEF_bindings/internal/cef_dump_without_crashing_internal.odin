package cef_internal

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// This function allows for generating of crash dumps with a throttling mechanism, preventing frequent dumps from being generated in a short period of time from the same location. It should only be called after CefInitialize has been successfully called. The |function_name|, |file_name|, and |line_number| parameters specify the origin location of the dump. The |mseconds_between_dumps| is an interval between consecutive dumps in milliseconds from the same location. Returns true (1) if the dump was successfully generated, false otherwise. For detailed behavior, usage instructions, and considerations, refer to the documentation of DumpWithoutCrashing in base/debug/dump_without_crashing.h.
	dump_without_crashing :: proc (
		mseconds_between_dumps: c.longlong,
		function_name: cstring,
		file_name: cstring,
		line_number: c.int,
	) -> c.int ---

	// This function allows for generating of crash dumps without any throttling constraints.
	// It should also only be called after CefInitialize has been successfully called.
	// Returns true (1) if the dump was successfully generated, false otherwise. For detailed behavior, usage instructions, and considerations, refer to the documentation of DumpWithoutCrashingUnthrottled in base/debug/dump_without_crashing.h. Removed in API version 13500. Use dump_without_crashing() instead.
	dump_without_crashing_unthrottled :: proc () -> c.int ---
}
