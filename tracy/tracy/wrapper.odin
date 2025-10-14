package tracy

import "core:c"
import "core:strings"

TRACY_ENABLE        :: #config(TRACY_ENABLE, false)
TRACY_CALLSTACK     :: #config(TRACY_CALLSTACK, 5)
TRACY_HAS_CALLSTACK :: #config(TRACY_HAS_CALLSTACK, true)

SourceLocationData :: ___tracy_source_location_data
ZoneCtx            :: ___tracy_c_zone_context


//init and destroy
init :: ___tracy_startup_profiler
destroy :: ___tracy_shutdown_profiler

// Zone markup

// NOTE: These automatically calls ZoneEnd() at end of scope.
@(deferred_out=ZoneEnd) Zone   :: #force_inline proc(active := true, color := [4]u8{}, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { when TRACY_ENABLE { ctx = ZoneBegin(active, depth, color, loc) } return } 
@(deferred_out=ZoneEnd) ZoneN  :: #force_inline proc(name: string, active := true, color := [4]u8{}, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { when TRACY_ENABLE { ctx = ZoneBegin(active, depth, color, loc); ZoneName(ctx, name) } return } 
//@(deferred_out=ZoneEnd) ZoneC  :: #force_inline proc(color: u32, active := true, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { when TRACY_ENABLE { ctx = ZoneBegin(active, depth, loc); ZoneColor(ctx, color) } return } 
//@(deferred_out=ZoneEnd) ZoneNC :: #force_inline proc(name: string, color: u32, active := true, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { when TRACY_ENABLE { ctx = ZoneBegin(active, depth, loc); ZoneName(ctx, name); ZoneColor(ctx, color) } return } 

// Dummy aliases to match C API (only difference is the `depth` parameter,
// which we declare as optional for the non-S procs.)
ZoneS   :: Zone
ZoneNS  :: ZoneN

ZoneText  :: #force_inline proc(ctx: ZoneCtx, text: string) { ___tracy_emit_zone_text(ctx, _sl(text)) }
ZoneName  :: #force_inline proc(ctx: ZoneCtx, name: string) { ___tracy_emit_zone_name(ctx, _sl(name)) }
ZoneColor :: #force_inline proc(ctx: ZoneCtx, color: u32)   { ___tracy_emit_zone_color(ctx, color)    }
ZoneValue :: #force_inline proc(ctx: ZoneCtx, value: u64)   { ___tracy_emit_zone_value(ctx, value)    }

// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
ZoneBegin :: proc(active: bool, depth: i32, color : [4]u8, loc := #caller_location) -> (ctx: ZoneCtx) {
	when TRACY_ENABLE {
		/* From manual, page 46:
		     The variable representing an allocated source location is of an opaque type.
		     After it is passed to one of the zone begin functions, its value cannot be
		     reused (the variable is consumed). You must allocate a new source location for
		     each zone begin event, even if the location data would be the same as in the
		     previous instance.
		*/
		id := ___tracy_alloc_srcloc(u32(loc.line), _sl(loc.file_path), _sl(loc.procedure), color)
		when TRACY_HAS_CALLSTACK {
			ctx = ___tracy_emit_zone_begin_alloc_callstack(id, depth, b32(active))
		} else {
			ctx = ___tracy_emit_zone_begin_alloc(id, b32(active))
		}
	}
	return
}

// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
ZoneEnd :: #force_inline proc(ctx: ZoneCtx) { ___tracy_emit_zone_end(ctx) }

// Memory profiling
// (See allocator.odin for an implementation of an Odin custom allocator using memory profiling.)
Alloc        :: #force_inline proc(ptr: rawptr, size: c.size_t, depth: i32 = TRACY_CALLSTACK)                { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_alloc_callstack(ptr, size, depth, false)             } else { ___tracy_emit_memory_alloc(ptr, size, false)             } }
Free         :: #force_inline proc(ptr: rawptr, depth: i32 = TRACY_CALLSTACK)                                { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_free_callstack(ptr, depth, false)                    } else { ___tracy_emit_memory_free(ptr, false)                    } }
SecureAlloc  :: #force_inline proc(ptr: rawptr, size: c.size_t, depth: i32 = TRACY_CALLSTACK)                { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_alloc_callstack(ptr, size, depth, true)              } else { ___tracy_emit_memory_alloc(ptr, size, true)              } }
SecureFree   :: #force_inline proc(ptr: rawptr, depth: i32 = TRACY_CALLSTACK)                                { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_free_callstack(ptr, depth, true)                     } else { ___tracy_emit_memory_free(ptr, true)                     } }
AllocN       :: #force_inline proc(ptr: rawptr, size: c.size_t, name: cstring, depth: i32 = TRACY_CALLSTACK) { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_alloc_callstack_named(ptr, size, depth, false, name) } else { ___tracy_emit_memory_alloc_named(ptr, size, false, name) } }
FreeN        :: #force_inline proc(ptr: rawptr, name: cstring, depth: i32 = TRACY_CALLSTACK)                 { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_free_callstack_named(ptr, depth, false, name)        } else { ___tracy_emit_memory_free_named(ptr, false, name)        } }
SecureAllocN :: #force_inline proc(ptr: rawptr, size: c.size_t, name: cstring, depth: i32 = TRACY_CALLSTACK) { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_alloc_callstack_named(ptr, size, depth, true, name)  } else { ___tracy_emit_memory_alloc_named(ptr, size, true, name)  } }
SecureFreeN  :: #force_inline proc(ptr: rawptr, name: cstring, depth: i32 = TRACY_CALLSTACK)                 { when TRACY_HAS_CALLSTACK { ___tracy_emit_memory_free_callstack_named(ptr, depth, true, name)         } else { ___tracy_emit_memory_free_named(ptr, true, name)         } }

// Dummy aliases to match C API (only difference is the `depth` parameter,
// which we declare as optional for the non-S procs.)
AllocS        :: Alloc
FreeS         :: Free
SecureAllocS  :: SecureAlloc
SecureFreeS   :: SecureFree
AllocNS       :: AllocN
FreeNS        :: FreeN
SecureAllocNS :: SecureAllocN
SecureFreeNS  :: SecureFreeN

// Frame markup
FrameMark      :: #force_inline proc(name: cstring = nil)                             { ___tracy_emit_frame_mark(name) }
FrameMarkStart :: #force_inline proc(name: cstring)                                   { ___tracy_emit_frame_mark_start(name) }
FrameMarkEnd   :: #force_inline proc(name: cstring)                                   { ___tracy_emit_frame_mark_end(name) }
FrameImage     :: #force_inline proc(image: rawptr, w, h: u16, offset: u8, flip: i32) { ___tracy_emit_frame_image(image, w, h, offset, flip) }

// Plots and messages
Plot       :: #force_inline proc(name: cstring, value: f64) { ___tracy_emit_plot(name, value) }
PlotF      :: #force_inline proc(name: cstring, value: f32) { ___tracy_emit_plot_float(name, value) }
PlotI      :: #force_inline proc(name: cstring, value: i64) { ___tracy_emit_plot_int(name, value) }
PlotConfig :: #force_inline proc(name: cstring, type:  TracyPlotFormatEnum, step, fill: b32, color: u32) { ___tracy_emit_plot_config(name, type, step, fill, color) }
Message    :: #force_inline proc(txt: string)               { ___tracy_emit_message(_sl(txt), TRACY_CALLSTACK when TRACY_HAS_CALLSTACK else 0) }
MessageC   :: #force_inline proc(txt: string, color: u32)   { ___tracy_emit_message(_sl(txt), TRACY_CALLSTACK when TRACY_HAS_CALLSTACK else 0) }
AppInfo    :: #force_inline proc(name: string)              { ___tracy_emit_message_appinfo(_sl(name)) }

SetThreadName :: #force_inline proc(name: cstring) { ___tracy_set_thread_name(name) }

// Connection status
IsConnected :: #force_inline proc() -> bool { return cast(bool)___tracy_connected() when TRACY_ENABLE else false }

// Fibers
FiberEnter :: #force_inline proc(name: cstring) { ___tracy_fiber_enter(name) }
FiberLeave :: #force_inline proc()              { ___tracy_fiber_leave() }

// GPU zones
// These are also available but no higher level wrapper provided.
/*
	___tracy_emit_gpu_zone_begin
	___tracy_emit_gpu_zone_begin_callstack
	___tracy_emit_gpu_zone_begin_alloc
	___tracy_emit_gpu_zone_begin_alloc_callstack
	___tracy_emit_gpu_zone_end
	___tracy_emit_gpu_time
	___tracy_emit_gpu_new_context
	___tracy_emit_gpu_context_name
	___tracy_emit_gpu_calibration

	___tracy_emit_gpu_zone_begin_serial
	___tracy_emit_gpu_zone_begin_callstack_serial
	___tracy_emit_gpu_zone_begin_alloc_serial
	___tracy_emit_gpu_zone_begin_alloc_callstack_serial
	___tracy_emit_gpu_zone_end_serial
	___tracy_emit_gpu_time_serial
	___tracy_emit_gpu_new_context_serial
	___tracy_emit_gpu_context_name_serial
	___tracy_emit_gpu_calibration_serial
*/

// Helper for passing cstring+length to Tracy functions.
@(private="file") _sl :: proc(s: string) -> (cstring, c.size_t) {
	return cstring(raw_data(s)), c.size_t(len(s))
}
