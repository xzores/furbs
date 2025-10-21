package neural_network

import "core:strings"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:slice"

Node_handle :: distinct int;

Graph_input :: struct {
	type : Tensor_data_type,
}

Graph_tensor :: struct {
	type : Tensor_data_type,
	data : Any_tensor,
}

Graph_elem_mul :: struct {
	type : Tensor_data_type, //common for all (might change)
}

Graph_mat_mul :: struct {
	type : Tensor_data_type, //common for all (might change)
}

Graph_node :: struct {
	shape : []int,
	data : union {
		Graph_input,
		Graph_tensor,
		Graph_elem_mul,
		Graph_mat_mul,
	}
}

Edge :: [2]Node_handle;

Graph :: struct {
	nodes : [dynamic]Graph_node,
	edges : [dynamic]Edge,
}

@(private="file")
next_node :: proc (g: ^Graph, node : Graph_node) -> Node_handle {
	nh := len(g.nodes);
	append(&g.nodes, node);
	return auto_cast nh;
}

@(private="file")
get_node_mat_dim :: proc (g: ^Graph, node : Node_handle, loc := #caller_location) -> [2]int {
	n := g.nodes[node];
	assert(len(n.shape) >= 2, "tensor must be rank 2 or more", loc = loc);

	return {n.shape[len(n.shape)-2], n.shape[len(n.shape)-1]}
}

create_graph :: proc () -> ^Graph {
	graph := new(Graph);

	return graph;
}

destroy_graph :: proc (g: ^Graph) {
	
}

//Makes a new node to pass along to other procedures
input :: proc (g: ^Graph, shape : []int, data_type : Tensor_data_type) -> Node_handle {
	return next_node(g, {slice.clone(shape), Graph_input{data_type}});
}

//crate a fixed tensor (aka is it not an input)
param :: proc (g: ^Graph, shape : []int, data_type : Tensor_data_type) -> Node_handle {
	return next_node(g, {slice.clone(shape), Graph_tensor{data_type, {}}});
}

//fill a param with a tensor, data is automaticly converted.
//This does not copy the tensor, it must live as long as the graph
fill_param :: proc (g: ^Graph, node : Node_handle, tensor : Any_tensor) {
	if t, ok := &g.nodes[node].data.(Graph_tensor); ok {
		t.data = tensor;
	}
	else {
		panic("This node was not a tensor/parameter");
	}
}

mat_mul :: proc(g: ^Graph, a : Node_handle, b : Node_handle, loc := #caller_location) -> Node_handle {
	
	a_node := g.nodes[a];

	a_dim := get_node_mat_dim(g, a, loc)
	b_dim := get_node_mat_dim(g, b, loc)
	c_dim := [2]int{a_dim[0], b_dim[1]} //mat dims of the output
	fmt.assertf(a_dim[1] == b_dim[0], "Last two dimenstion of the tensor is treatet as a matrix and must match such that both K's are the same in [M,K] @ [K,N] → [M,N], matrix dimensions was %v, %v", a_dim, b_dim, loc = loc)
	
	shape := make([]int, len(a_node.shape))
	
	for s, i in a_node.shape {
		shape[i] = s;
	}

	shape[len(shape)-2] = c_dim[0]
	shape[len(shape)-1] = c_dim[1]

	return next_node(g, {shape, Graph_mat_mul{.float32}}); //always float32 for now
}

elem_add :: proc(g: ^Graph, a : Node_handle, b : Node_handle) -> Node_handle {
	
}

layer_norm :: proc(g: ^Graph, x, gamma, beta: Node_handle, eps: f32) -> Node_handle {
	
}

activation :: proc(g: ^Graph, node : Node_handle, activation_type : Activation_function) -> Node_handle {
	
}

operation :: proc(g: ^Graph, node : Node_handle, operation : Operation) -> Node_handle {
	
}

reshape :: proc(g: ^Graph, x: Node_handle, new_shape: []int) -> Node_handle {

}

slice :: proc(g: ^Graph, x: Node_handle, new_shape: []int) -> Node_handle {

}

transpose :: proc(g: ^Graph, x: Node_handle, perm: []int) -> Node_handle {

}

concat :: proc(g: ^Graph, xs: []Node_handle, axis: int) -> Node_handle {

}

split :: proc (g: ^Graph, node : Node_handle, #any_int count : int) -> []Node_handle {

}

gather :: proc(g: ^Graph, params, indices: Node_handle, axis: int = 0) -> Node_handle {

}

//Used for masking (also called "where")
pick :: proc(g: ^Graph, cond, x, y: Node_handle) -> Node_handle {
	
}

output :: proc (g: ^Graph, node : Node_handle) {

}

/*
graph_get_nodes 	:: proc (g: ^Graph) {
	
}

graph_get_edge 	:: proc (g: ^Graph) {
	
}

graph_add_tensor      :: proc(g: ^Graph, tensor : Tensor) -> int
graph_add_edge      :: proc(g: ^Graph, src, dst: int) -> int

//inference
graph_forward     :: proc(g: ^Graph, input: Tensor) -> Tensor

graph_dump          :: proc(g: Graph)  // debug visualization
*/

