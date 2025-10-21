package neural_network

import "core:strings"
import "core:fmt"
import "core:log"
import "core:strconv"

Linear_params :: struct {
	weight: Any_tensor,
	bias:   Maybe(Any_tensor),
}

Layer_norm_params :: struct {
	weight: Any_tensor, // gamma
	bias:   Any_tensor, // beta
}

/*
Attention_head :: struct {
	c_attn : Linear_params,	//calculates qkv
	c_proj : Linear_params,	//The final linear layer at the output after concat
	
	//These are appended to the K vector added after the computed Q, K, V projections, right before you compute attention.
	bias_k: Maybe(Any_tensor), 
	bias_v: Maybe(Any_tensor),
}

Multiheaded_attention :: struct {
	heads: []Attention_head,        // This needs to be split when loading from a safetensor
	out_proj_bias: Maybe(Any_tensor), // shared bias added once
	causal : bool, // true for decoder self-attn; false for encoder
}
*/

//TODO replace this with Attention_head and Multiheaded_attention when we know this works.
Multiheaded_attention :: struct {
	// Combined projections as stored in GPT-style checkpoints
	qkv_proj : Linear_params,   // from attn.c_attn.{weight,bias}  shape: [hidden, 3*hidden]
	out_proj : Linear_params,   // from attn.c_proj.{weight,bias}  shape: [hidden, hidden]

	// Runtime behavior
	causal   : bool,           // true for decoder self-attn; false for encoder/cross

	// Optional extras (rare in GPT; present in some impls)
	bias_k   : Maybe(Any_tensor),
	bias_v   : Maybe(Any_tensor),
}

FeedForward :: struct {
	c_fc   : Linear_params,   // first linear (expand)
	c_proj : Linear_params,   // second linear (compress)
}

//inputed is position embedded vectors, output is a continues vector of inputs
Encoder :: struct {
	// before attention
	ln_1      : Layer_norm_params,

	//first pass though a multiheaded attention
	attention : Multiheaded_attention,

	//then a add norm layer
	ln_2      : Layer_norm_params,           // before feed-forward

	//Then a feed forward
	ff : FeedForward,
}

/* Decoder only diagram
Embeddings (wte [+ wpe])
	│
h.0:  LN1 → SelfAttn → +resid → LN2 → MLP → +resid
	│
h.1:  (same)
	│
...
	│
h.4:  (same)
	│
LN_f → lm_head → logits

This matches a decoder only block:
Transformer :: struct {
	wte -> wpe,
	for each layer {
		ln_1 -> self_attn -> ln_2 -> cross_attn -> ln_3 -> ff
	}
	ln_f -> lm_head
}
*/

//inputed is position embedded vectors, output is a continues vector of inputs
Decoder :: struct {
	ln_1       : Layer_norm_params,          // before self attention
	self_attn  : Multiheaded_attention,    // causal self attention
	ln_2       : Layer_norm_params,          // before cross attention
	cross_attn : Multiheaded_attention,    // attends to encoder output
	ln_3       : Layer_norm_params,          // before feed-forward
	ff         : FeedForward,              // MLP
}

Transformer_block :: union {
	Encoder,
	Decoder,
}

Transformer :: struct {
	//Word/token embeddings
	wte : Any_tensor,

	//Word/position embeddings
	wpe : Maybe(Any_tensor),

	//a list of blocks
	blocks : []Transformer_block,

	//Final layer normalization
	ln_f : Layer_norm_params,

	//projection back to tokens
	lm_head : Any_tensor,
}