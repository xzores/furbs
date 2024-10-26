package utils;

import "base:runtime"

import "core:debug/trace"

import "pdb"

global_trace_ctx: trace.Context;

@(require_results)
init_stack_trace :: proc () -> runtime.Assertion_Failure_Proc {
	trace.init(&global_trace_ctx);
		
	when ODIN_OS == .Windows && ODIN_DEBUG {
		pdb.SetUnhandledExceptionFilter(pdb.dump_stack_trace_on_exception);
	}
	
	return debug_trace_assertion_failure_proc;
}

destroy_stack_trace :: proc () {
	trace.destroy(&global_trace_ctx);
}

debug_trace_assertion_failure_proc : runtime.Assertion_Failure_Proc : proc(prefix, message: string, loc := #caller_location) -> ! {
	runtime.print_caller_location(loc)
	runtime.print_string(" ")
	runtime.print_string(prefix)
	if len(message) > 0 {
		runtime.print_string(": ")
		runtime.print_string(message)
	}
	runtime.print_byte('\n')

	ctx := &global_trace_ctx
	if !trace.in_resolve(ctx) {
		buf: [64]trace.Frame
		runtime.print_string("Debug Trace:\n")
		frames := trace.frames(ctx, 1, buf[:])
		for f, i in frames {
			fl := trace.resolve(ctx, f, context.temp_allocator)
			if fl.loc.file_path == "" && fl.loc.line == 0 {
				continue
			}
			runtime.print_caller_location(fl.loc)
			runtime.print_string(" - frame ")
			runtime.print_int(i)
			runtime.print_byte('\n')
		}
	}
	runtime.trap()
}