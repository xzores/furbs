package cef_internal

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

/// Represents a wall clock time in UTC. Values are not guaranteed to be
/// monotonically non-decreasing and are subject to large amounts of skew.
/// Time is stored internally as microseconds since the Windows epoch (1601).
/// This is equivalent of Chromium `base::Time` (see base/time/time.h).
Basetime :: struct {
	val: i64,
}

/// Time information. Values should always be in UTC.
Time :: struct {
	/// Four or five digit year "2007" (1601 to 30827 on Windows, 1970 to 2038 on
	/// 32-bit POSIX)
	year: c.int,

	/// 1-based month (values 1 = January, etc.)
	month: c.int,

	/// 0-based day of week (0 = Sunday, etc.)
	day_of_week: c.int,

	/// 1-based day of month (1-31)
	day_of_month: c.int,

	/// Hour within the current day (0-23)
	hour: c.int,

	/// Minute within the current hour (0-59)
	minute: c.int,

	/// Second within the current minute (0-59 plus leap seconds which may take
	/// it up to 60).
	second: c.int,

	/// Milliseconds within the current second (0-999)
	millisecond: c.int,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Converts time to/from time_t. Returns true (1) on success and false
	/// (0) on failure.
	time_to_timet :: proc (cef_time: ^Time, time: ^c.int64_t) -> c.int ---
	time_from_timet :: proc (time: c.int64_t, cef_time: ^Time) -> c.int ---

	/// Converts time to/from a double which is the number of seconds since
	/// epoch (Jan 1, 1970). Webkit uses this format to represent time. A value of 0
	/// means "not initialized". Returns true (1) on success and false (0) on
	/// failure.
	time_to_doublet :: proc (cef_time: ^Time, time: ^f64) -> c.int ---
	time_from_doublet :: proc (time: f64, cef_time: ^Time) -> c.int ---

	/// Retrieve the current system time. Returns true (1) on success and false (0)
	/// on failure.
	time_now :: proc (cef_time: ^Time) -> c.int ---

	/// Retrieve the current system time.
	base_time_now :: proc () -> Basetime ---

	/// Retrieve the delta in milliseconds between two time values. Returns true (1)
	/// on success and false (0) on failure.
	time_delta :: proc (cef_time1: ^Time, cef_time2: ^Time, delta: ^i64) -> c.int ---

	/// Converts time to base_time. Returns true (1) on success and
	/// false (0) on failure.
	time_to_base_time :: proc (from: ^Time, to: ^Basetime) -> c.int ---

	/// Converts base_time to time. Returns true (1) on success and false (0) on
	/// failure.
	time_from_base_time :: proc (from: Basetime, to: ^Time) -> c.int ---
}
