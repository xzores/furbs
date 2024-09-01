package nn;

import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:fmt"

import "../utils"

Weight :: f16;
Bias :: f16;
Float :: f16;

Matrix 			:: utils.Matrix(Weight);
matrix_make 	:: utils.matrix_make;
matrix_destroy 	:: utils.matrix_destroy;
matrix_mul 		:: utils.matrix_mul;
matrix_vec_mul 	:: utils.matrix_vec_mul;
vec_matrix_mul 	:: utils.vec_matrix_mul;
mul 			:: utils.mul;

Activation_function :: enum {
	none,
	relu,
	silu,
	hyper_tan,
	sigmoid,
}

Loss_function :: enum {
	MSE, // mean squared error
}

Feedforward_network :: struct(A : Activation_function) {
	input_size : int, //"nodes", but not really because there is no activation function and no bias.
	layers : []Layer,
	opmizer : Optimizer,
}

Layer :: struct {
	weights : Matrix,
	biases : []Bias,
}

optimizer_proc :: #type proc();

Optimizer :: struct {
	eval : optimizer_proc,
}

randomize_layer :: proc (l : Layer) {
	utils.randomize_slice(l.biases);
	utils.randomize_slice(l.weights.data);
}

@(require_results)
sigmoid :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	return 1.0 / (1.0 + math.exp(-v));
}

@(require_results)
sigmoid_gradient :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	sig := sigmoid(v);
	return sig * (1.0 - sig);
}

add_to_slice :: proc (A : []$T, B : []T, loc := #caller_location) {
	fmt.assertf(len(A) == len(B), "Cannot sum vectors with lengths %v and %v", len(A), len(B), loc = loc);
	for &a, i in A {
		a = a + B[i];
	}
}

apply_activation_function :: proc (arr : []$T, A : Activation_function) {
	#partial switch A {
		case .sigmoid:
			for &a in arr {
				a = sigmoid(a);
			}
		case:
			panic("not implemented");
	}
}

apply_activation_function_gradient :: proc (arr : []$T, A : Activation_function) {
	#partial switch A {
		case .sigmoid:
			for &a in arr {
				a = sigmoid_gradient(a);
			}
		case:
			panic("not implemented");
	}
}

@(require_results)
calculate_loss :: proc (prediction : []Float, awnser : []Float, func : Loss_function, loc := #caller_location) -> f32 {
	
	assert(len(prediction) == len(awnser), "The prediction and awnser lengths does not match", loc);
	
	L : f32;
	for p, i in prediction {
		switch func {
			case .MSE:
				L += f32(p - awnser[i]) * f32(p - awnser[i]);
			case:
				panic("TODO");
		}
	}
	
	L /= f32(len(prediction));
	
	return L;
}

//This will edit the err_gradient
layer_loss_gradient :: proc (l : Layer, err_gradient : []Float, activation : Activation_function, loc := #caller_location) -> (prev_err_gradient : []Float) {
	
	//This is the backpropergration for the "activation layer" which is in this lib incorperated into the layer
	//So this is a step needed before the we do the weights, biases and for the gradient of the subsequent backprops.
	apply_activation_function_gradient(err_gradient, activation);
		
	// dc/dw is  		a^(L-1) * sigmoid'(Z) * 2*(a^(L)-y)
	//This can also be expressed as (dc/dw_ji * dy_j/dx_i) = (dc/dy_j * xi)
	//Whis is the same as a columb-row multiplication, this leads to a matrix with dimensions jxi
	//This matrix has the same dimensions as the weight matrix. You might say that it is xi transposed to be more correct.
 	dcdw := utils.vec_columb_vec_row_mul(err_gradient, err_gradient);
	
	// dc/db is  		sigmoid'(Z) * 2*(a^(L)-y)
	// This is the same as dC/dY, which is weird
	dcdb := err_gradient;
	
	//The 
	{
	
	}
	
	// dc/da^(L-1) is  	w^(L) * sigmoid'(Z) * 2*(a^(L)-y)
	// This is the same as W^T*dC/dY, where W^T is the weights transposed and dC/dY is the cost gradient.
	return utils.matrix_transposed_vec_mul(l.weights, err_gradient);
	
}

//////////////////////////////// FEED FORWARD STUFF ////////////////////////////////

//This could also be called dC/da where d is derivative, C is cost and a is the output 
calculate_loss_gradient :: proc (using network : ^Feedforward_network($A), target : []Float, awnser : []Float, func : Loss_function, loc := #caller_location) -> []Float {

}

make_layer :: proc (input_layer_dim : int, layer_dim : int) -> Layer {
	
	return {
		utils.matrix_make(layer_dim, input_layer_dim, Weight),
		make([]Bias, layer_dim)
	};
}

make_feedforward :: proc (input_dim, output_layer_dim : int, hidden_dims : []int, opmizer : Optimizer, $A : Activation_function) -> ^Feedforward_network(A) {
	
	layers : [dynamic]Layer;
	
	//There is no input layer, there is just input data.
	
	last_layer_dim := input_dim;
	
	//Create the hidden layers
	for dim in hidden_dims {
		l := make_layer(last_layer_dim, dim);
		randomize_layer(l);
		last_layer_dim = dim;
		append(&layers, l)
	}
	
	{ //Create the output layer
		output := make_layer(last_layer_dim, output_layer_dim);
		randomize_layer(output);
		last_layer_dim = output_layer_dim;
		append(&layers, output)
	}
	
	network := new(Feedforward_network(A));
	network^ = Feedforward_network(A){input_dim, layers[:], opmizer};
	
	return network;
}

destroy_feedforward :: proc (network : ^Feedforward_network($A)) {
	
	for l in network.layers {
		delete(l.biases);
		matrix_destroy(l.weights);
	}
	
	delete(network.layers);
	free(network);
}

@(require_results)
feed_feedforward :: proc (using network : ^Feedforward_network($A), data : []Float, loc := #caller_location) -> (res : []Float) {
	
	fmt.assertf(len(data) == input_size, "The input data (%v) does not match the length of the input %v", len(data), input_size, loc = loc)
	
	//This could also be called a^(L-1)
	res = slice.clone(data);
	
	for l, i in layers {
		//l.weights could be called w^(L)
		a := matrix_vec_mul(l.weights, res, loc);
		//l.biases could be called  b^(L)
		add_to_slice(a, l.biases);			//Applies it inplace, so that the new_res gets l.nodes added to it per element.
		apply_activation_function(a, A); 	//Does it inplace
		
		delete(res);
		res = a;
	}
	
	return;
}

backprop_feedforward :: proc (using network : ^Feedforward_network($A), target : []Float, awnser : []Float, func : Loss_function, loc := #caller_location) -> []Float {
		
	assert(len(target) == len(awnser), "The prediction and awnser lengths does not match", loc);
	fmt.assertf(len(target) == input_size, "The target data (%v) does not match the length of the input %v", len(target), input_size, loc = loc)
	
	//This is the gradient of the Cost/Loss
	G := make([]Float, len(target));
	
	//Calculate the loss gradient with respect to the output
	for p, i in target {
		switch func {
			case .MSE:
				G[i] = 2.0 * (p - awnser[i]); //This is correct, no n's here
			case:
				panic("TODO");
		}
	}
	
	//Do the backpropergation by using G 
	for l, i in layers {
		
		dCdw := matrix_make(len(target), layers[i-1].weights.cols, Weight); // This is dC/da, so it is gradient with respect to the output.
		dCdb := make([]Float, len(target)); // This is da/dz, so it the inverse activation function.
		
		assert(dCdw.cols == l.weights.cols, "Columbs does not match");
		assert(dCdw.rows == l.weights.rows, "Rows does not match");
		
		//l.weights could be called w^(L)
		Z := matrix_vec_mul(l.weights, res, loc); //Z is a vector with length , this means it is "target"/"awnser"/"output vector size" for the first itteration.
		//l.biases could be called  b^(L)
		add_to_slice(Z, l.biases);			//Applies it inplace, so that the new_res gets l.nodes added to it per element.
		
		//This is common for all calculations
		temp := sigmoid_gradient(Z) * 2 * (a^(L)-y);
		
		// dC/dw is  		a^(L-1) * sigmoid'(Z) * 2*(a^(L)-y)
		
		// dC/db is  		sigmoid'(Z) * 2*(a^(L)-y)
		
		// dC/da^(L-1) is  	w^(L) * sigmoid'(Z) * 2*(a^(L)-y)
		
		
		delete(res);
		res = Z;
	}
	
	
	return G;
}

feed :: proc {feed_feedforward}
backprop :: proc {backprop_feedforward}
destroy :: proc {destroy_feedforward}
