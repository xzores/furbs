package tracy_wrap

import "core:c"
import "core:mem"

import "tracy"

TRACY_ENABLE		:: #config(TRACY_ENABLE, false)
TRACY_CALLSTACK	 :: #config(TRACY_CALLSTACK, 5)
TRACY_HAS_CALLSTACK :: #config(TRACY_HAS_CALLSTACK, true)

when TRACY_ENABLE {
	
	init :: tracy.init
	destroy :: tracy.destroy

	//Structs
	SourceLocationData :: tracy.SourceLocationData;
	ZoneCtx			:: tracy.ZoneCtx;
	ProfiledAllocatorData :: tracy.ProfiledAllocatorData;
		
	// NOTE: These automatically calls ZoneEnd() at end of scope.
	Zone   :: tracy.Zone
	ZoneN  :: tracy.ZoneN
	//ZoneC  :: tracy.ZoneC
	//ZoneNC :: tracy.ZoneNC

	// Dummy aliases to match C API (only difference is the `depth` parameter,
	// which we declare as optional for the non-S procs.)
	ZoneS   :: tracy.ZoneS
	ZoneNS  :: tracy.ZoneNS
	//ZoneCS  :: tracy.ZoneCS
	//ZoneNCS :: tracy.ZoneNCS

	ZoneText  :: tracy.ZoneText
	ZoneName  :: tracy.ZoneName
	ZoneColor :: tracy.ZoneColor
	ZoneValue :: tracy.ZoneValue

	// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
	ZoneBegin :: tracy.ZoneBegin
	// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
	ZoneEnd :: tracy.ZoneEnd

	// Memory profiling
	// (See allocator.odin for an implementation of an Odin custom allocator using memory profiling.)
	Alloc		:: tracy.Alloc
	Free		 :: tracy.Free
	SecureAlloc  :: tracy.SecureAlloc
	SecureFree   :: tracy.SecureFree
	AllocN	   :: tracy.AllocN
	FreeN		:: tracy.FreeN
	SecureAllocN :: tracy.SecureAllocN
	SecureFreeN  :: tracy.SecureFreeN

	// Dummy aliases to match C API (only difference is the `depth` parameter,
	// which we declare as optional for the non-S procs.)
	AllocS		:: tracy.Alloc
	FreeS		 :: tracy.Free
	SecureAllocS  :: tracy.SecureAlloc
	SecureFreeS   :: tracy.SecureFree
	AllocNS	   :: tracy.AllocN
	FreeNS		:: tracy.FreeN
	SecureAllocNS :: tracy.SecureAllocN
	SecureFreeNS  :: tracy.SecureFreeN

	// Frame markup
	FrameMark	  :: tracy.FrameMark
	FrameMarkStart :: tracy.FrameMarkStart
	FrameMarkEnd   :: tracy.FrameMarkEnd
	FrameImage	 :: tracy.FrameImage

	// Plots and messages
	Plot	   :: tracy.Plot
	PlotF	  :: tracy.PlotF
	PlotI	  :: tracy.PlotI
	PlotConfig :: tracy.PlotConfig
	Message	:: tracy.Message
	MessageC   :: tracy.MessageC
	AppInfo	:: tracy.AppInfo

	SetThreadName :: tracy.SetThreadName

	// Connection status
	IsConnected :: tracy.IsConnected

	// Fibers
	FiberEnter :: tracy.FiberEnter
	FiberLeave :: tracy.FiberLeave

	//Allocator
	MakeProfiledAllocator :: tracy.MakeProfiledAllocator

} else {

	init :: proc() {}
	destroy :: proc() {}
	
	SourceLocationData 		:: struct {};
	ZoneCtx					:: struct {};
	TracyPlotFormatEnum		:: struct {};
	ProfiledAllocatorData 	:: struct {};
	
	Zone   :: proc(active := true, color := [4]u8{}, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { return {}; }; 
	ZoneN  :: proc(name: string, active := true, color := [4]u8{}, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { return {}; };
	//ZoneC  :: proc(color: u32, active := true, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { return {}; };
	//ZoneNC :: proc(name: string, color: u32, active := true, depth: i32 = TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) { return {}; }; 
	
	ZoneText  :: proc(ctx: ZoneCtx, text: string) {}
	ZoneName  :: proc(ctx: ZoneCtx, name: string) {}
	ZoneColor :: proc(ctx: ZoneCtx, color: u32)   {}
	ZoneValue :: proc(ctx: ZoneCtx, value: u64)   {}
	ZoneBegin :: proc(active: bool, depth: i32, loc := #caller_location) -> (ctx: ZoneCtx) { return {}; }
	ZoneEnd :: proc(ctx: ZoneCtx) {}
	
	Alloc		:: proc(ptr: rawptr, size: c.size_t, depth: i32 = TRACY_CALLSTACK)					{}
	Free		 :: proc(ptr: rawptr, depth: i32 = TRACY_CALLSTACK)									{}
	SecureAlloc  :: proc(ptr: rawptr, size: c.size_t, depth: i32 = TRACY_CALLSTACK)					{}
	SecureFree   :: proc(ptr: rawptr, depth: i32 = TRACY_CALLSTACK)									{}
	AllocN	   :: proc(ptr: rawptr, size: c.size_t, name: cstring, depth: i32 = TRACY_CALLSTACK) 	{}
	FreeN		:: proc(ptr: rawptr, name: cstring, depth: i32 = TRACY_CALLSTACK)				 	{}
	SecureAllocN :: proc(ptr: rawptr, size: c.size_t, name: cstring, depth: i32 = TRACY_CALLSTACK) 	{}
	SecureFreeN  :: proc(ptr: rawptr, name: cstring, depth: i32 = TRACY_CALLSTACK)				 	{}
	
	AllocS		:: Alloc
	FreeS		 :: Free
	SecureAllocS  :: SecureAlloc
	SecureFreeS   :: SecureFree
	AllocNS	   :: AllocN
	FreeNS		:: FreeN
	SecureAllocNS :: SecureAllocN
	SecureFreeNS  :: SecureFreeN
	
	FrameMark	  :: proc(name: cstring = nil)							 {}
	FrameMarkStart :: proc(name: cstring)								   {}
	FrameMarkEnd   :: proc(name: cstring)								   {}
	FrameImage	 :: proc(image: rawptr, w, h: u16, offset: u8, flip: i32) {}

	Plot	   :: proc(name: cstring, value: f64) {}
	PlotF	  :: proc(name: cstring, value: f32) {}
	PlotI	  :: proc(name: cstring, value: i64) {}
	PlotConfig :: proc(name: cstring, type:  TracyPlotFormatEnum, step, fill: b32, color: u32) {}
	Message	:: proc(txt: string)			   {}
	MessageC   :: proc(txt: string, color: u32)   {}
	AppInfo	:: proc(name: string)			  {}

	SetThreadName :: proc(name: cstring) {}

	IsConnected :: proc() -> bool { return false; }
	
	FiberEnter :: proc(name: cstring) {}
	FiberLeave :: proc()			  {}
	
	MakeProfiledAllocator :: proc(self: ^ProfiledAllocatorData, callstack_size: i32 = TRACY_CALLSTACK, secure: b32 = false, backing_allocator := context.allocator) -> mem.Allocator { return context.allocator; }
}