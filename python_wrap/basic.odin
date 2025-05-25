package python_wrap;

import "base:runtime"
import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:fmt"
import "core:encoding/json"
import "core:mem"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:io"
import "core:strings"
import "core:c/libc"
import "core:strconv"

@private
run_python_code :: proc (code : string, args : ..any) -> []u8 {
	
	new_code, was_allocation := strings.replace_all(fmt.tprintf(code, ..args), "\"", "'")
	
	defer {
		if was_allocation {
			delete(new_code);
		}
	}
	
	commands := [?]string {
		"python",
		"-c",
		fmt.tprintf("%v", new_code),
	}
	
	File :: struct {
		impl:   rawptr,
		stream: io.Stream,
		fstat:  os2.Fstat_Callback,
	}
	
	fstat_callback : os2.Fstat_Callback : proc (f: ^os2.File, allocator: runtime.Allocator) -> (os2.File_Info, os2.Error){
		
		log.errorf("Fstat called!");
		
		return {}, nil,	
	}
	
	std_out := os2.File {
		fstat = os2.Fstat_Callback {}
	}
	
	process : os2.Process_Desc = {
		sys_attr = os2.Process_Attributes{},
		working_dir = os.get_current_directory(),
		command = commands[:],
		env = nil,
		stderr = nil,
		stdout = nil,
		stdin = nil,
	};
	
	state, stdout, stderr, err := os2.process_exec(process, context.allocator);
	defer delete(stderr);
	assert(err == nil);
	
	if len(stderr) != 0 {
		log.errorf(string(stderr));
		log.errorf("err : %v", err);
	}
	
	return stdout;
}
