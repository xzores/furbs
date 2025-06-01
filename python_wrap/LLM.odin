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

tokenize_string :: proc (to_tokenize : string, tokenizer_path : string, loc := #caller_location) -> []int {
	
	tokenize_python_code := #load("python/tokenize.py", string);
	
	stdout := run_python_code(tokenize_python_code, to_tokenize, tokenizer_path);
	
	s_res := "";
	
	{
		res1, _ := strings.remove_all(string(stdout), "[", context.temp_allocator);
		res2, _ := strings.remove_all(res1, "]", context.temp_allocator);
		res3, _ := strings.remove_all(res2, " ", context.temp_allocator);
		res4, _ := strings.remove_all(res3, "\n", context.temp_allocator);
		res5, _ := strings.remove_all(res4, "\r", context.temp_allocator);
		s_res = res5;
	}
	
	split_res := strings.split(s_res, ",", context.temp_allocator);
	
	tokens := make([]int, len(split_res));
	
	for sr, i in split_res {
		val, ok := strconv.parse_int(sr);
		fmt.assertf(ok, "failed to parse : '%v'", sr, loc = loc);
		tokens[i] = val;
	}
	
	fmt.printf("\n stdout : %v,\n", tokens);
	
	return tokens;
}

inference_model :: proc (model_path : string, tokens : []int) -> []u8 {
	log.debugf("inferencing model : %v", model_path);
	
	inference_model_python_code := #load("python/image_convert.py", string);
	
	stdout := run_python_code(inference_model_python_code, model_path, model_path, tokens);
	
	/*
	s_res := "";
	
	{
		res1, _ := strings.remove_all(string(stdout), "[", context.temp_allocator);
		res2, _ := strings.remove_all(res1, "]", context.temp_allocator);
		res3, _ := strings.remove_all(res2, " ", context.temp_allocator);
		res4, _ := strings.remove_all(res3, "\n", context.temp_allocator);
		res5, _ := strings.remove_all(res4, "\r", context.temp_allocator);
		s_res = res5;
	}
	
	split_res := strings.split(s_res, ",", context.temp_allocator);
	
	data := make([]u8, len(split_res));
	
	for sr, i in split_res {
		val, ok := strconv.parse_int(sr);
		fmt.assertf(ok, "failed to parse : '%v'", sr);
		data[i] = auto_cast val;
	}
	
	fmt.printf("data : %v", data);
	*/
	//fmt.printf("stdout : %v", stdout);
	
	shapes_len := (transmute(^i32)&stdout[0])^;
	
	fmt.printfln("shapes len : %v", shapes_len);
	
	header := make([dynamic]u8);
	
	for o in stdout {
		if o == '>' {
			break;
		}
		append(&header, o);
	}
	
	tensor, ok := os.read_entire_file_from_filename("output_tensor.bin");
	fmt.printf("header : %v \n\n %v", string(header[:]), slice.reinterpret([]i32, stdout));
	
	return stdout;
}

