package vendor_gl;

#assert(size_of(bool) == size_of(u8))

import "base:runtime"
import "core:fmt"

Error_Enum :: enum {
	NO_ERROR = NO_ERROR,
	INVALID_VALUE = INVALID_VALUE,
	INVALID_ENUM = INVALID_ENUM,
	INVALID_OPERATION = INVALID_OPERATION,
	INVALID_FRAMEBUFFER_OPERATION = INVALID_FRAMEBUFFER_OPERATION,
	OUT_OF_MEMORY = OUT_OF_MEMORY,
	STACK_UNDERFLOW = STACK_UNDERFLOW,
	STACK_OVERFLOW = STACK_OVERFLOW,
	// TODO: What if the return enum is invalid?
}

capture_error_callback_type :: #type proc (runtime.Source_Code_Location, any, Error_Enum, []any, runtime.Source_Code_Location);
capture_error_callback : capture_error_callback_type = nil;

capture_gl_callback_type :: #type proc (runtime.Source_Code_Location, any, []any, runtime.Source_Code_Location);
capture_gl_callback : capture_gl_callback_type = nil;

when GL_DEBUG {
	debug_helper :: proc"c"(from_loc: runtime.Source_Code_Location, ret_val : any, args: ..any, loc := #caller_location) {
		context = runtime.default_context()

		if capture_gl_callback != nil {
			capture_gl_callback(from_loc, ret_val, args, loc);
		}
		
		// There can be multiple errors, so we're required to continuously call glGetError until there are no more errors
		for i := 0; /**/; i += 1 {
			err := cast(Error_Enum)impl_GetError();
			if err == .NO_ERROR { break }
			
			if capture_error_callback != nil {
				capture_error_callback(from_loc, ret_val, err, args, loc);
			}
			else {
				fmt.printf("%d: glGetError() returned GL_%v\n", i, err)
				fmt.printf("	from: gl%s(", loc.procedure);
				for arg, i in args {
					if i != 0 {
						fmt.printf(", ");
					}
					fmt.printf("%v", arg);
				}
				fmt.printf(")\n");
				
				// add location
				fmt.printf("	in:   %s(%d:%d)\n", from_loc.file_path, from_loc.line, from_loc.column)
			}
		}
	}
}