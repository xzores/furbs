package nn;

import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:fmt"

import "../utils"

Float :: f32;
Weight :: Float;
Bias :: Float;

Matrix 			:: utils.Matrix(Weight);

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

Feedforward_network :: struct {
	input_size : int, //"nodes", but not really because there is no activation function and no bias.
	layers : []Layer,
	activation : Activation_function,
	//opmizer : Optimizer,
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

//Replaces the values in A by the element wise addition of the two slices.
add_to_slice :: proc (A : []$T, B : []T, loc := #caller_location) {
	fmt.assertf(len(A) == len(B), "Cannot sum vectors with lengths %v and %v", len(A), len(B), loc = loc);
	for &a, i in A {
		a = a + B[i];
	}
}

//replaces the values, by the activation_function.
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

//replaces the values, by the gradient of the activation_function.
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

//////////////////////////////// FEED FORWARD STUFF ////////////////////////////////

make_layer :: proc (input_layer_dim : int, layer_dim : int) -> Layer {
	
	return {
		utils.matrix_make(layer_dim, input_layer_dim, Weight),
		make([]Bias, layer_dim)
	};
}

make_feedforward :: proc (input_dim, output_layer_dim : int, hidden_dims : []int, opmizer : Optimizer, activation : Activation_function) -> ^Feedforward_network {
	
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
	
	network := new(Feedforward_network);
	network^ = Feedforward_network{input_dim, layers[:], activation};
	
	return network;
}

destroy_feedforward :: proc (network : ^Feedforward_network) {
	
	for l in network.layers {
		delete(l.biases);
		utils.matrix_destroy(l.weights);
	}
	
	delete(network.layers);
	free(network);
}

@(require_results)
feed_feedforward_activations :: proc (network : ^Feedforward_network, data : []Float, loc := #caller_location) -> (activations : [][]Float) {
	
	// Check if input data length matches network input size
	fmt.assertf(len(data) == network.input_size, "The input data (%v) does not match the length of the input %v", len(data), network.input_size, loc = loc)
	
	// Initialize activations array to hold activations for all layers, including the input layer
	activations = make([][]Float, len(network.layers) + 1);
	
	// Clone input data to use as initial activation (input layer)
	current_activation : []Float = slice.clone(data);
	activations[0] = current_activation; // Store the input layer's activation
	
	// Loop through each layer to compute activations
	for l, i in network.layers {
		// Compute next layer's activation by multiplying weights with current activation
		next_activation := utils.matrix_vec_mul(l.weights, current_activation, loc);
		
		// Add biases to the result
		add_to_slice(next_activation, l.biases); // Adds biases in place
		// Apply activation function to the result
		apply_activation_function(next_activation, network.activation); // Modifies next_activation in place
		
		// Store the computed activation for this layer
		activations[i + 1] = next_activation;
		
		// Update current activation for the next iteration
		current_activation = next_activation;
	}
	
	return;
}


@(require_results)
feed_feedforward :: proc (using network : ^Feedforward_network, data : []Float, loc := #caller_location) -> (prediction : []Float) {
	
	fmt.assertf(len(data) == input_size, "The input data (%v) does not match the length of the input %v", len(data), input_size, loc = loc)
	
	//This could also be called a^(L-1)
	prediction = slice.clone(data);
	
	for l, i in layers {
		//l.weights could be called w^(L)
		a := utils.matrix_vec_mul(l.weights, prediction, loc);
		//l.biases could be called  b^(L)
		add_to_slice(a, l.biases);			//Applies it inplace, so that the new_res gets l.nodes added to it per element.
		apply_activation_function(a, network.activation); 	//Does it inplace
		
		delete(prediction);
		prediction = a;
	}
	
	return;
}

@(require_results)
get_loss_gradient :: proc (prediction : []Float, awnser : []Float, func : Loss_function, loc := #caller_location) -> []Float {
	
	assert(len(prediction) == len(awnser), "The prediction and awnser lengths does not match", loc);
	
	//This is the gradient of the Cost/Loss
	G := make([]Float, len(prediction));
	
	//Calculate the loss gradient with respect to the output
	for p, i in prediction {
		switch func {
			case .MSE:
				G[i] = 2.0 * (p - awnser[i]); //This is correct, no n's here
			case:
				panic("TODO");
		}
	}
	
	return G,
}

//Might change the input vectors.
backprop_feedforward :: proc (using network : ^Feedforward_network, activations : [][]Float, awnser : []Float, func : Loss_function, learning_rate : Float, loc := #caller_location) {

	//Note the awnser is the last output or "activations" in the layer.
	prediction := activations[len(activations)-1];
	assert(len(prediction) == len(awnser), "The prediction and awnser lengths does not match", loc);
	
	//This is the gradient of the Cost/Loss
	G := get_loss_gradient(prediction, awnser, func);
	defer delete(G);
	
	//Do the backpropergation by using G 
	#reverse for l, i in layers {
		
		X := activations[i];
		fmt.printf("X : %#v\n", X)
		
		//This is the backpropergration for the "activation layer" which is in this lib incorperated into the layer
		//So this is a step needed before the we do the weights, biases and for the gradient of the subsequent backprops.
		apply_activation_function_gradient(G, activation); //inplace, it replaces the values, by the gradient.
		
		//This can also be expressed as (dc/dw_ji * dy_j/dx_i) = (dc/dy_j * xi)
		//Whis is the same as a columb-row multiplication, this leads to a matrix with dimensions jxi
		//This matrix has the same dimensions as the weight matrix. You might say that it is xi transposed to be more correct.
		dcdw : Matrix = utils.vec_columb_vec_row_mul(G, X); // This is dC/da, so it is gradient with respect to the output.
			
		// This is the same as dC/dY, which is weird, but ok.
		//This is just an alias for G
		dcdb : []Float = G; // This is da/dz, so it the inverse activation function.
		
		//New allocation, passes the error gradient back to the next layer.
		G_new := utils.matrix_transposed_vec_mul(l.weights, G);
		
		assert(dcdw.cols == l.weights.cols, "Columbs does not match");
		assert(dcdw.rows == l.weights.rows, "Rows does not match");
		
		//Apply the gradients 
		//TODO this should not be done at this stage, we need to make epochs
		//We average over a large part of the dataset.
		{
			assert(len(dcdb) == len(l.biases), "Incorrect biases length");
			for &v in soa_zip(bias=l.biases, dcdb=dcdb) {
				v.bias -= learning_rate * v.dcdb;
			}
			
			assert(len(l.weights.data) == len(dcdw.data), "Incorrect weigths length");
			for &v in soa_zip(w=l.weights.data, wg=dcdw.data) {
				v.w -= learning_rate * v.wg;
			}
		}
		
		utils.matrix_destroy(dcdw);
		delete(G);
		G = G_new;
	}
}

@(require_results)
get_data_error :: proc (using network : ^Feedforward_network, prediction : []Float, awnser : []Float, func : Loss_function, loc := #caller_location) -> (data_err : []Float) {
	
	assert(len(prediction) == len(awnser), "The prediction and awnser lengths does not match", loc);
	fmt.assertf(len(prediction) == input_size, "The prediction data (%v) does not match the length of the input %v", len(prediction), input_size, loc = loc)
	
	//This is the gradient of the Cost/Loss
	G := get_loss_gradient(prediction, awnser, func);
	
	//Do the backpropergation by using G 
	for l, i in layers {
		delete(G);
		G = utils.matrix_transposed_vec_mul(l.weights, G);;
	}
	
	return G;
}

feed :: proc {feed_feedforward}
backprop :: proc {backprop_feedforward}
destroy :: proc {destroy_feedforward}
