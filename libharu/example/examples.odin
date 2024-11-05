package libharu_examples;

import haru ".."
import "core:testing"

import "base:runtime"

@(test)
save_a_pdf :: proc(t : ^testing.T) {

	error_function : haru.Error_Handler : proc "c" (error_no : haru.STATUS, detail_no : haru.STATUS, user_data : rawptr) {
		context = (cast(^runtime.Context)user_data)^;
	}
	
	//This context trick will only work if the context is not destroyed, be aware!
	haru.New(error_function, &context);
	
}
