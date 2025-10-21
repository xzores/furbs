package neural_network

import "base:runtime"
import "core:slice"
import "core:fmt"
import "core:encoding/json"
import "core:log"
import "core:os"
import "core:strings"
import "core:strconv"

import "../utils"

Tensor_data_type :: enum {
	boolean,
	int8,
	uint8,
	int16,
	int32,
	int64,
	float16,
	brain_float16,
	float32,
	float64,
}

Any_tensor :: struct {
	data_type : Tensor_data_type,
	shape : []int,
	data  : []u8 `fmt:"-"`, // raw bytes; you can cast this later based on dtype
}

tensor_as_f32 :: proc(t: Any_tensor) -> utils.Tensor(f32) {
	assert(t.data_type == .float32);
	return utils.Tensor(f32){t.shape, slice.reinterpret([]f32, t.data)};
}

Model_config :: struct {
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

Safe_tensor_header_entry :: struct {
	//something that the name translates to here??
	name : string,
	data_offsets : [2]i64,
	shape : []int,
	d_type : Tensor_data_type,
}

Safe_tensor_header :: struct {
	meta_data : struct {
		format : string,
	},
	entries : []Safe_tensor_header_entry,
}

Safe_tensor :: struct {
	header : Safe_tensor_header,
	tensors : map[string]Any_tensor,
	owns_tersor_data : bool,
}

Safetensor_layer :: struct {
	name: string,
	weight: Any_tensor,
	bias: Any_tensor,
}

@(require_results)
load_configuration_from_content :: proc (content : []byte, alloc := context.allocator) -> Model_config {
	
	log.debugf("Content : %v", string(content))

	config : Model_config;
	err := json.unmarshal(content, &config, allocator = alloc);
	assert(err == nil);
	
	return config;	
}

@(require_results)
load_configuration_from_filename :: proc (file_name : string) -> Model_config {
	
	content, ok := os.read_entire_file_from_filename(file_name);
	assert(ok);
	
	return load_configuration_from_content(content);
}

load_configuration :: proc{load_configuration_from_content, load_configuration_from_filename};

//if copy_tensor_mem is false then it will keep a refence into the memeory, which is faster to load, but requires that you dont free the content
@(require_results)
load_safetensors_from_content :: proc(contents : []u8, copy_tensor_mem : bool) -> Safe_tensor {
	
	// Read the first 8 bytes (u64 little-endian) for header size
	assert(len(contents) >= 8)
	header_size : u64 = (transmute(^u64)&contents[0])^;

	// Read the JSON header
	header_bytes := contents[8:header_size+8]
	
	header_json := string(header_bytes[:])
	header_data, jerr := json.parse(header_bytes, allocator = context.temp_allocator)
	if jerr != nil {
		log.error("failed to parse headder json");
		return {} // handle JSON parse error
	}

	safe_header : Safe_tensor_header;
	main_obj := header_data.(json.Object);
	entries : [dynamic]Safe_tensor_header_entry;

	for name, val in main_obj {
		if name == "__metadata__" {
			safe_header.meta_data.format = val.(json.Object)["format"].(json.String);
		}
		else {
			//parse the name 
			//something := parse_safetensor_name(name);
			
			e : Safe_tensor_header_entry

			as_int :: proc (val : json.Value) -> i64 {
				#partial switch v in val {
					case json.Float: {
						return auto_cast v
					}
					case json.Integer: {
						return v;
					}
				}
				unreachable()
			}
			
			e.name = strings.clone(name);

			found_dtype, found_offsets, found_shape : bool;
			for d_name, d_val in val.(json.Object) {
				switch d_name {
					case "data_offsets": {
						a := d_val.(json.Array);
						e.data_offsets = {as_int(a[0]), as_int(a[1])}
						found_offsets = true;
					}
					case "shape": {
						s_shape := d_val.(json.Array);
						shape := make([]int, len(s_shape))
						for s_val, i in s_shape {
							shape[i] = auto_cast as_int(s_val)
						}
						e.shape = shape;
						found_shape = true;
					}
					case "dtype": {
						data_type := d_val.(json.String);
						d_type : Tensor_data_type;
						switch data_type {
							case "BOOL": {
								d_type = .boolean;
							}
							case "U8": {
								d_type = .uint8
							}
							case "I8": {
								d_type = .int8
							}
							case "I16": {
								d_type = .int16
							}
							case "I32": {
								d_type = .int32
							}
							case "I64": {
								d_type = .int64
							}
							case "F16": {
								d_type = .float16
							}
							case "BF16": {
								d_type = .brain_float16
							}
							case "F32": {
								d_type = .float32
							}
							case "F64": {
								d_type = .float64
							}
						}
						e.d_type = d_type;
						found_dtype = true;
					}
				}
			}

			assert(found_dtype)
			assert(found_offsets)
			assert(found_shape)

			append(&entries, e);
		}
	}
	
	safe_header.entries = entries[:];

	st : Safe_tensor;

	//load_tensors
	for e in safe_header.entries {
		t : Any_tensor;

		t.shape = e.shape;
		t.data_type = e.d_type;
		if copy_tensor_mem {
			t.data = slice.clone(contents[e.data_offsets[0]:e.data_offsets[1]]);
		}
		else {
			t.data = contents[e.data_offsets[0]:e.data_offsets[1]];
		}

		st.tensors[e.name] = t;
	}

	//parsed_header : map[string]map[string]string
	//log.debugf("header_data : %#v\n", safe_header);
	
	return st;
}

@(require_results)
load_safetensors_from_filehandle :: proc(file : os.Handle) -> Safe_tensor {
	data, ok := os.read_entire_file(file);
	assert(ok);
	defer delete(data);

	return load_safetensors_from_content(data, true);
}

@(require_results)
load_safetensors_from_filename :: proc(filename : string) -> Safe_tensor {
	data, ok := os.read_entire_file(filename);
	assert(ok);
	defer delete(data);

	return load_safetensors_from_content(data, true);

}

load_safetensors :: proc {load_safetensors_from_content, load_safetensors_from_filehandle, load_safetensors_from_filename}

// find layers from a collection of named tensors
// if ok false, then the naming convention does not match expected and it must be done manually.
@require_results
safetensors_layers :: proc(tensors: map[string]Any_tensor, alloc := context.allocator) -> (layers : map[string]Safetensor_layer, ok : bool) {
	layers = make(map[string]Safetensor_layer, allocator=alloc)

	for name, t in tensors {
		parts := strings.split(name, ".")
		if len(parts) < 2 {
			panic("How to handle?");
		}
		
		// parameter type = last token
		param_name := parts[len(parts)-1]
		layer_name := strings.join(parts[:len(parts)-1], ".", context.temp_allocator)

		l := layers[layer_name]
		if l.name == "" {
			l.name = strings.clone(layer_name[:strings.last_index(name, ".")]);
		}

		// assign weight or bias
		switch param_name {
			case "weight": {
				l.weight = t
			}
			case "bias": {
				l.bias = t
			}
			case: {
				fmt.panicf("TODO : %v", param_name)
			}
		}

		layers[layer_name] = l
	}

	for name, l in layers {
		fmt.assertf(len(l.weight.shape) != 0, "layer %v has no biases, layer : %v", name, l.weight.shape);
	}

	return layers, true;
}

Module :: union {
	Transformer,
}

safetensor_parse_transformer :: proc () {

}

//assumes this format for the name: <top_module>.<sub_module>.<layer_index>.<sub_component>.<param_name> 
//connects all submodules with a increamenting layer_index togerther
//and groups all wights and biases
@require_results
map_safetensor_modules :: proc(config : Model_config, layers: map[string]Safetensor_layer, alloc := context.allocator) -> (module : Module, missing : []string) {
	context.allocator = alloc;

	miss := make([dynamic]string)
	
	for name in layers {
		append(&miss, name);
	}
	
	transformer : Transformer;
	decoders : map[i64]Decoder;

	for name, graph_layer in layers {
		parts := strings.split(name, ".", context.temp_allocator)
		if len(parts) < 2 {
			continue
		}
		
		switch parts[0] {
			case "transformer": {
				if len(parts) < 2 || len(parts) > 5 {
					log.warnf("expected 3 or 4 dots in transformer found : %v, parts: %v", len(parts), parts)
					continue
				}
				
				switch parts[1] {
					case "wte": {
						// Root input node, connects to first transformer block
						transformer.wte = graph_layer.weight
						assert(graph_layer.bias.data == nil, "did not expect bias on token embedding")
						assert(slice.contains(miss[:], name))
						unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
					}
					case "wpe": {
						// Adds to token embeddings (parallel edge into first layer)
						transformer.wpe = graph_layer.weight;
						assert(graph_layer.bias.data == nil, "did not expect bias on postional embedding")
						assert(slice.contains(miss[:], name))
						unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
					}
					case "ln_f": {
						// Connects from last transformer block output
						transformer.ln_f.weight = graph_layer.weight;
						transformer.ln_f.bias = graph_layer.bias;
						assert(slice.contains(miss[:], name))
						unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
					}
					case "lm_head": {
						// Final output layer, connects after ln_f, maps from vectors to vocabulary logits
						transformer.lm_head = graph_layer.weight;
						assert(graph_layer.bias.data == nil, "did not expect bias on language-modeling head")
						assert(slice.contains(miss[:], name))
						unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
					}
					case: {
						layer_index, ok := strconv.parse_i64(parts[2])
						if ok {
							sub_block_name := strings.join({parts[1], parts[2]}, ".", context.temp_allocator);
							log.warnf("sub_block : %v", sub_block_name)
							
							sub_block := decoders[layer_index];
							sub_block.self_attn.causal = true
							
							switch parts[3] {
								case "ln_1", "norm1": {
									//Pre-attention LayerNorm — input to attention
									sub_block.ln_1.bias = graph_layer.bias
									sub_block.ln_1.weight = graph_layer.weight
									assert(slice.contains(miss[:], name))
									unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
								}
								case "ln_2", "norm2": {
									//Pre-MLP LayerNorm — input to MLP
									sub_block.ln_2.bias = graph_layer.bias
									sub_block.ln_2.weight = graph_layer.weight
									assert(slice.contains(miss[:], name))
									unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
								}
								case "attn": {
									switch parts[4] {
										case "c_attn": {
											// QKV linear projection (main attention input op)
											sub_block.self_attn.qkv_proj.weight = graph_layer.weight
           									sub_block.self_attn.qkv_proj.bias   = graph_layer.bias
											assert(slice.contains(miss[:], name))
											unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
										}
										case "c_proj": {
											// Output projection from attention (ends attention subpath)
											sub_block.self_attn.out_proj.weight = graph_layer.weight
           									sub_block.self_attn.out_proj.bias   = graph_layer.bias
											assert(slice.contains(miss[:], name))
											unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
										}
									}
								}
								case "mlp": {
									switch parts[4] {
										case "c_fc", "fc1": {
											// First feed-forward linear (expansion)
											sub_block.ff.c_fc.weight = graph_layer.weight
            								sub_block.ff.c_fc.bias   = graph_layer.bias
											assert(slice.contains(miss[:], name))
											unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
										}
										case "c_proj", "fc2": {
											// Second feed-forward linear (compression)
											sub_block.ff.c_proj.weight = graph_layer.weight
           									sub_block.ff.c_proj.bias   = graph_layer.bias
											assert(slice.contains(miss[:], name))
											unordered_remove(&miss, slice.linear_search(miss[:], name) or_else -1)
										}
									}
								}
								case "resid_add": {
									// Logical residual add (connects skip from input to output)
									panic("todo");
								}
							}

							decoders[layer_index] = sub_block;
						}
						else {
							log.warn("could not parse : %v", name)
							continue;
						}
					}
				}
			}
			/*
			case "decoder": {
				
			}
			case "encoder": {
				
			}
			case "model": {
				
			}
			case "visual": {
				
			}
			case "unet": {
				
			}
			case "vae": {
				
			}
			case "flow": {
				
			}
			case "posterior_flow": {
				
			}
			case "text_encoder": {
				
			}
			case "audio_encoder": {
				
			}
			case "clip": {
				
			}
			case "adapter": {
				
			}
			case "language_model": {
				
			}
			case "lora": {
				
			}*/
			case: {
				fmt.panicf("TODO, : %v", parts);
			}
		}

	}

	transformer.blocks = make([]Transformer_block, len(decoders))

	for index, d in decoders {
		transformer.blocks[index] = d;
	}
	
	log.debugf("transformer : %#v, miss : %#v", transformer, miss)
	
	return transformer, miss[:]
}

/*
found transformer.h.4.mlp.c_fc : ([32, 128], [128]))
found transformer.h.2.ln_1 : ([32], [32]))
found transformer.h.1.attn.c_attn : ([32, 96], [96]))
found transformer.h.1.ln_2 : ([32], [32]))
found transformer.h.2.mlp.c_fc : ([32, 128], [128]))
found transformer.h.4.ln_1 : ([32], [32]))
found transformer.h.1.mlp.c_fc : ([32, 128], [128]))
found transformer.h.3.attn.c_proj : ([32, 32], [32]))
found transformer.h.3.ln_2 : ([32], [32]))
found transformer.h.0.ln_1 : ([32], [32]))
found transformer.h.1.ln_1 : ([32], [32]))
found transformer.h.2.mlp.c_proj : ([128, 32], [32]))
found transformer.h.4.mlp.c_proj : ([128, 32], [32]))
found transformer.h.0.attn.c_attn : ([32, 96], [96]))
found transformer.ln_f : ([32], [32]))
found transformer.h.4.ln_2 : ([32], [32]))
found transformer.h.2.attn.c_attn : ([32, 96], [96]))
found transformer.h.2.ln_2 : ([32], [32]))
found transformer.h.0.mlp.c_proj : ([128, 32], [32]))
found transformer.h.4.attn.c_proj : ([32, 32], [32]))
found transformer.h.0.ln_2 : ([32], [32]))
found transformer.h.1.mlp.c_proj : ([128, 32], [32]))
found transformer.h.3.mlp.c_proj : ([128, 32], [32]))
found transformer.wpe : ([512, 32], []))
found transformer.h.3.attn.c_attn : ([32, 96], [96]))
found transformer.h.4.attn.c_attn : ([32, 96], [96]))
found transformer.h.3.ln_1 : ([32], [32]))
found transformer.wte : ([1000, 32], []))
found transformer.h.0.attn.c_proj : ([32, 32], [32]))
found transformer.h.2.attn.c_proj : ([32, 32], [32]))
found transformer.h.3.mlp.c_fc : ([32, 128], [128]))
found transformer.h.0.mlp.c_fc : ([32, 128], [128]))
found transformer.h.1.attn.c_proj : ([32, 32], [32]))
*/