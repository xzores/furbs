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

image_convert_png_and_denoise :: proc (imgs : []string, loc := #caller_location) {
	
	image_promt_python_code := #load("python/image_convert.py", string);
	
	stdout := run_python_code(image_promt_python_code, imgs);
}

// Configuration struct for image processing
Image_Process_Config :: struct {
	image_path:      string `json:"image_path"`,
	prompt:          string `json:"prompt"`,
	use_llava:       bool   `json:"use_llava"`,
	openai_api_key:  string `json:"openai_api_key"`,
	model:           string `json:"model"`,
	max_tokens:      int    `json:"max_tokens"`,
}

promt_image_and_string :: proc (img_path : string, prompt : string, open_ai_key : string, open_ai_model := "gpt-4-vision-preview", use_local : bool = false, max_tokens : int = 2048, loc := #caller_location) -> string {
	
	// Create configuration for JSON
	config := Image_Process_Config {
		image_path     = img_path,
		prompt         = prompt,
		use_llava      = use_local,
		openai_api_key = open_ai_key,
		model          = open_ai_model,
		max_tokens     = max_tokens,
	};
	
	// Call Python script with JSON config
	stdout := run_python_script_with_json("image_promt_python.py", config, loc);
	
	s_res := "";
	
	{
		s_res = string(stdout);
	}
	
	return s_res;
}
