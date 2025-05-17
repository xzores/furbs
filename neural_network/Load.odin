package nerual_network;

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

import "../utils"

ModelConfig :: struct {
    activation_function        		: string,   // e.g. "gelu_new"
    attention_probs_dropout_prob	: f32,     // e.g. 0.1
    attn_pdrop                 		: f32,      // e.g. 0.1
    bos_token_id               		: int,      // e.g. 98
    embd_pdrop                 		: f32,      // e.g. 0.1
    eos_token_id               		: int,      // e.g. 98
    gradient_checkpointing     		: bool,     // e.g. false
    hidden_act                 		: string,   // e.g. "gelu"
    hidden_dropout_prob        		: f32,      // e.g. 0.1
    initializer_range          		: f32,      // e.g. 0.02
    intermediate_size          		: int,      // e.g. 37
    layer_norm_epsilon         		: f32,      // e.g. 1e-5
    model_type                 		: string,   // e.g. "gpt2"
    n_ctx                      		: int,      // e.g. 512
    n_embd                     		: int,      // e.g. 32
    n_head                     		: int,      // e.g. 4
    n_inner                    		: Maybe(int),     // e.g. null → optional
    n_layer                    		: int,      // e.g. 5
    n_positions                		: int,      // e.g. 512
    pad_token_id               		: int,      // e.g. 98
    resid_pdrop                		: f32,      // e.g. 0.1
    scale_attn_weights         		: bool,     // e.g. true
    summary_activation         		: Maybe(string),  // e.g. null → optional
    summary_first_dropout      		: f32,      // e.g. 0.1
    summary_proj_to_labels     		: bool,     // e.g. true
    summary_type               		: string,   // e.g. "cls_index"
    summary_use_proj           		: bool,     // e.g. true
    transformers_version       		: string,   // e.g. "4.11.0.dev0"
    type_vocab_size            		: int,      // e.g. 16
    use_cache                  		: bool,     // e.g. true
    vocab_size                 		: int,      // e.g. 1000
}

Safe_tensor :: struct {
	
}

load_configuration_from_content :: proc (content : []byte) -> ModelConfig {
	
	config : ModelConfig;
	err := json.unmarshal(content, &config, );
	assert(err == nil);
	
	return config;	
}

load_configuration_from_filename :: proc (file_name : string) -> ModelConfig {
	
	content, ok := os.read_entire_file_from_filename(file_name);
	assert(ok);
	
	return load_configuration_from_content(content);
}

load_configuration :: proc{load_configuration_from_content, load_configuration_from_filename};

load_safetensors_from_filehandle :: proc(file : os.Handle) -> Safe_tensor {
	
	s := os.stream_from_handle(file);
	cnt : int;
	err : io.Error;
	
	// Read the first 8 bytes (u64 little-endian) for header size
	header_size_bytes : [8]u8;
	cnt, err = io.read(s, header_size_bytes[:]);
	if err != nil || cnt != 8 {
		return {} // handle error properly
	}
	
	header_size : int = (transmute(^int)(&header_size_bytes[0]))^;
	
	// Read the JSON header
	header_bytes := make([]u8, int(header_size))
	cnt, err = io.read(s, header_bytes[:])
	if err != nil {
		return {} // handle error properly
	}
	
	header_json := string(header_bytes[:])
	header_data, jerr := json.parse(header_bytes)
	if jerr != nil {
		return {}// handle JSON parse error
	}
	
	fmt.printf("header_data : %#v\n", header_data);
	
	/*
	// Example access to tensors
	for key, value in header_data {
		if key == "__metadata__" {
			continue
		}
		/*
		tensor_info := value.(map[string]interface{})
		dtype := tensor_info["dtype"].(string)
		shape := tensor_info["shape"].([]interface{})
		data_offsets := tensor_info["data_offsets"].([]interface{})

		start := strconv.atoi(data_offsets[0].(string))  // or cast directly if numeric
		end := strconv.atoi(data_offsets[1].(string))

		size := end - start
		data := make([]u8, size)

		file.seek(int(start), os.SeekStart)
		_, err = file.read(data)
		if err != nil {
			return // handle error properly
		}
		*/
		
		// Now `data` holds the raw bytes of the tensor
		// You would interpret them based on `dtype` and `shape`
	}
	*/
	
	return {};
}

load_safetensors_from_filename :: proc(filename : string) -> Safe_tensor {

	file, err := os.open(filename)
	if err != nil {
		return {} // handle error properly
	}
	defer os.close(file)

	return load_safetensors(file);

}

load_safetensors :: proc {load_safetensors_from_filehandle, load_safetensors_from_filename};

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
