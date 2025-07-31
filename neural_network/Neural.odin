package neural_network

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

Feedforward_activations :: struct {
	activations : [][]Float,
	//activations_gradient : [][]Float,
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

@(require_results)
relu :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	return math.max(0.0, v);
}

@(require_results)
relu_gradient :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	return v > 0.0 ? 1.0 : 0.0;
}

@(require_results)
silu :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	return v * sigmoid(v);
}

@(require_results)
silu_gradient :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	sig := sigmoid(v);
	return sig * (1.0 + v * (1.0 - sig));
}

@(require_results)
hyper_tan :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	return math.tanh(v);
}

@(require_results)
hyper_tan_gradient :: #force_inline proc(v: $T) -> T where intrinsics.type_is_numeric(T) {
	tanh_v := math.tanh(v);
	return 1.0 - tanh_v * tanh_v;
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
		case .none:
			// No activation function - values remain unchanged
			return;
		case .relu:
			for &a in arr {
				a = relu(a);
			}
		case .silu:
			for &a in arr {
				a = silu(a);
			}
		case .hyper_tan:
			for &a in arr {
				a = hyper_tan(a);
			}
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
		case .none:
			// No activation function - gradient is 1 (identity)
			for &a in arr {
				a = 1.0;
			}
		case .relu:
			for &a in arr {
				a = relu_gradient(a);
			}
		case .silu:
			for &a in arr {
				a = silu_gradient(a);
			}
		case .hyper_tan:
			for &a in arr {
				a = hyper_tan_gradient(a);
			}
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

init_activations :: proc (network : ^Feedforward_network) -> Feedforward_activations {

	activations := make([][]Float, len(network.layers) + 1);
	
	//preallocate the activations
	activations[0] = make([]Float, network.input_size);
	for l, i in network.layers {
		activations[i+1] = make([]Float, l.weights.rows);
	}
	
	return {activations};
}

destroy_feedforward_activations :: proc (activations : Feedforward_activations) {
	for a in activations.activations {
		delete(a);
	}
	delete(activations.activations);
}

feedforward_activations :: proc (network : ^Feedforward_network, activations : Feedforward_activations, data : []Float, loc := #caller_location) {
	
	// Check if input data length matches network input size
	fmt.assertf(len(data) == network.input_size, "The input data (%v) does not match the length of the input %v", len(data), network.input_size, loc = loc)
	
	// Clone input data to use as initial activation (input layer)
	current_activation : []Float = slice.clone(data);
	activations.activations[0] = current_activation; // Store the input layer's activation
	
	// Loop through each layer to compute activations
	for l, i in network.layers {
		// Store the computed activation for this layer
		next_activation := activations.activations[i + 1];
		// Compute next layer's activation by multiplying weights with current activation
		utils.matrix_vec_mul_inplace(l.weights, current_activation, next_activation, loc);
		
		// Add biases to the result
		add_to_slice(next_activation, l.biases); // Adds biases in place
		// Apply activation function to the result
		apply_activation_function(next_activation, network.activation); // Modifies next_activation in place
		
		// Update current activation for the next iteration
		current_activation = next_activation;
	}
	
	return;
}

get_prediction :: proc (activations : Feedforward_activations, loc := #caller_location) -> (prediction : []Float) {
	
	prediction = activations.activations[len(activations.activations)-1];
	
	return prediction;
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

//Backpropagation implementation for feedforward networks
//Mathematical notation:
// L = Loss function
// y = Output activations (after activation function)  
// z = Pre-activation values (before activation function)
// W = Weight matrix
// b = Bias vector
// a = Input activations from previous layer
// η = learning_rate
backprop_feedforward :: proc (using network : ^Feedforward_network, activations : Feedforward_activations, awnser : []Float, func : Loss_function, learning_rate : Float, loc := #caller_location) {

	// Get the final output prediction (y^L where L is the last layer)
	prediction := activations.activations[len(activations.activations)-1];
	assert(len(prediction) == len(awnser), "The prediction and awnser lengths does not match", loc);
	
	// Initialize gradient with ∂L/∂y^L (gradient of loss w.r.t. final output)
	G := get_loss_gradient(prediction, awnser, func);
	defer delete(G);
	
	// Backpropagate through each layer in reverse order
	#reverse for l, i in layers {
		
		// Get input activations for this layer: a^(l-1)
		// For layer i, activations[i] contains the input to that layer
		X := activations.activations[i];
		
		// Convert ∂L/∂y^l to ∂L/∂z^l by multiplying by activation derivative
		// G currently holds ∂L/∂y^l, we need ∂L/∂z^l = ∂L/∂y^l ⊙ σ'(y^l)
		// For most activation functions, we can compute σ'(z) from the output y = σ(z)
		y_curr := activations.activations[i + 1]; // Current layer's activations (output of this layer)
		
		#partial switch activation {
			case .none:
				// Identity: σ'(z) = 1, so ∂L/∂z = ∂L/∂y
				// G remains unchanged
			case .sigmoid:
				// For sigmoid: σ'(z) = y(1-y) where y = σ(z)
				for &g, idx in G {
					g *= y_curr[idx] * (1.0 - y_curr[idx]);
				}
			case .relu:
				// For ReLU: σ'(z) = 1 if y > 0, else 0
				for &g, idx in G {
					if y_curr[idx] <= 0.0 {
						g = 0.0;
					}
				}
			case .hyper_tan:
				// For tanh: σ'(z) = 1 - y² where y = tanh(z)
				for &g, idx in G {
					g *= (1.0 - y_curr[idx] * y_curr[idx]);
				}
			case .silu:
				// For SiLU: σ'(z) = σ(z)(1 + z(1-σ(z)))
				// This is complex to compute from output alone, would need input z
				// For now, fall back to approximation or store z values
				panic("SiLU gradient needs pre-activation values - not implemented");
			case:
				panic("Activation function gradient not implemented");
		}
		
		// Compute weight gradients: ∂L/∂W^l = ∂L/∂z^l ⊗ a^(l-1)
		// This is an outer product: each element (i,j) = (∂L/∂z^l)_i * (a^(l-1))_j
		// Results in matrix same size as W^l
		dcdw : Matrix = utils.vec_columb_vec_row_mul(G, X); // ∂L/∂W^l
			
		// Compute bias gradients: ∂L/∂b^l = ∂L/∂z^l
		// Bias gradient is identical to pre-activation gradient
		dcdb : []Float = G; // ∂L/∂b^l
		
		// Compute gradient for previous layer: ∂L/∂a^(l-1) = (W^l)^T * ∂L/∂z^l
		// This propagates the error back to the previous layer's activations
		G_new := utils.matrix_transposed_vec_mul(l.weights, G); // ∂L/∂a^(l-1)
		

		
		// Gradient descent parameter updates:
		// W^l ← W^l - η * ∂L/∂W^l
		// b^l ← b^l - η * ∂L/∂b^l
		{
			// Update biases: b^l = b^l - η * ∂L/∂b^l
			assert(len(dcdb) == len(l.biases), "Incorrect biases length");
			for &v in soa_zip(bias=l.biases, dcdb=dcdb) {
				v.bias -= learning_rate * v.dcdb;
			}
			
			// Update weights: W^l = W^l - η * ∂L/∂W^l  
			assert(len(l.weights.data) == len(dcdw.data), "Incorrect weights length");
			for &v in soa_zip(w=l.weights.data, wg=dcdw.data) {
				v.w -= learning_rate * v.wg;
			}
		}
		
		// Clean up current layer gradients and prepare for next iteration
		utils.matrix_destroy(dcdw);
		delete(G);
		G = G_new; // G now contains ∂L/∂a^(l-1) for next iteration
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






