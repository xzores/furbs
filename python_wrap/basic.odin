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
run_python_script_with_json :: proc (script_name : string, config : any, loc := #caller_location) -> []u8 {
	
	// Create temporary JSON config file
	temp_config_file := fmt.aprintf("temp_config_%d.json", rand.int31(), allocator = context.temp_allocator);
	
	// Marshal config to JSON
	json_data, marshal_err := json.marshal(config, allocator = context.temp_allocator);
	if marshal_err != nil {
		log.errorf("Failed to marshal config to JSON: %v", marshal_err, location = loc);
		return {};
	}
	
	// Write JSON to temporary file
	write_success := os.write_entire_file(temp_config_file, json_data);
	if !write_success {
		log.errorf("Failed to write temporary config file: %s", temp_config_file, location = loc);
		return {};
	}
	defer os.remove(temp_config_file); // Clean up temp file
	
	// Prepare Python script path
	script_path := fmt.aprintf("python/%s", script_name, allocator = context.temp_allocator);
	
	commands := [?]string {
		"python",
		script_path,
		temp_config_file,
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
	
	if err != nil {
		log.errorf("Process execution failed: %v", err, location = loc);
		return {};
	}
	
	if len(stderr) != 0 {
		log.errorf(string(stderr), location = loc);
	}
	
	return stdout;
}

// Legacy function for backward compatibility - now calls the new JSON-based function
@private  
run_python_code :: proc (path : string, args : ..any, loc := #caller_location) -> []u8 {
	log.warnf("run_python_code is deprecated, use run_python_script_with_json instead", location = loc);
	return {};
}
