package neural_network

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

Any_tensor :: struct {
	data_type : string,
	shape : []int,
	data  : []u8, // raw bytes; you can cast this later based on dtype
}

tensor_as_f32 :: proc(t: Any_tensor) -> utils.Tensor(f32) {
	assert(t.data_type == "F32" || t.data_type == "f32")
	return utils.Tensor(f32){t.shape, slice.reinterpret([]f32, t.data)};
}


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
	tensors: map[string]Tensor,
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
		log.error("failed to read headder json");
		return {} // handle error properly
	}
	
	header_json := string(header_bytes[:])
	header_data, jerr := json.parse(header_bytes)
	if jerr != nil {
		log.error("failed to parse headder json");
		return {} // handle JSON parse error
	}
	
	log.debugf("header_data : %#v\n", header_data);

	tensors := make(map[string]Tensor)
	
	for entry in header_val.object {
		name := entry.key
		if name == "__metadata__" {
			continue
		}

		tensor_info := entry.value.object

		dtype_val := tensor_info["dtype"]
		shape_val := tensor_info["shape"]
		offsets_val := tensor_info["data_offsets"]

		dtype := dtype_val.string
		shape := make([]int, len(shape_val.array))
		for i, dim in shape_val.array {
			shape[i] = int(dim.integer)
		}

		start := int(offsets_val.array[0].integer)
		end := int(offsets_val.array[1].integer)

		size := end - start
		data := make([]u8, size)

		_, err := os.seek(file, start, os.SeekStart)
		if err != nil {
			log.printfln("Seek failed: %v", err)
			return {}
		}
		n, err := os.read(file, data)
		if err != nil || n != size {
			log.printfln("Failed to read tensor %v: %v", name, err)
			return {}
		}

		tensors[name] = Tensor{
			data_type = dtype,
			shape = shape,
			data  = data,
		}
	}

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
