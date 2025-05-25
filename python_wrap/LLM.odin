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

@(private)
tokenize_python_code := 
`from deepseek_tokenizer import ds_token

input = "%v"
tokenizer_path = "%v"

res = ""

if (tokenizer_path != ""):
	# Load the tokenizer from the specified path
	tokenizer = ds_token.from_pretrained(tokenizer_path);
	# Encode text and print result
	res = tokenizer.encode(input)

else:
	# Encode text
	res = ds_token.encode(input)


print(res)
`

tokenize_string :: proc (to_tokenize : string, tokenizer_path : string, loc := #caller_location) -> []int {
		
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

@private
inference_model_python_code := 
`import torch
from transformers import AutoModel
import numpy as np
import sys

# Define the model architecture (replace with the correct model type)
model = AutoModel.from_pretrained('%v')  # or specify the exact model class

# Load the state dictionary
model.load_state_dict(torch.load('%v/pytorch_model.bin', weights_only=True), strict=False)

# Set the model to evaluation mode
model.eval()

# Example input (replace with your actual input)
input_tensor = torch.tensor([%v])  # Replace with actual input data

# Run inference
with torch.no_grad():  # Disable gradient tracking during inference
    output = model(input_tensor)

tensor = output.last_hidden_state.cpu().numpy()

# Step 1: Prepend the length of the shape (number of dimensions)
shape = np.array(tensor.shape, dtype=np.int32)
shape_length = np.array([len(tensor.shape)], dtype=np.int32)  # Length of shape

# Combine the length and shape into a single array
shape_with_length = np.concatenate([shape_length, shape])

# Step 2: Write the combined shape data (length + shape) as binary
shape_with_length.tofile(sys.stdout.buffer)

# Writing raw binary data to stdout
#tensor.astype(np.float32).tofile(sys.stdout.buffer)
`

inference_model :: proc (model_path : string, tokens : []int) -> []u8 {
	log.debugf("inferencing model : %v", model_path);
	
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

