package neural_network

import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:fmt"
import "core:log"

import "../utils"

Float :: f32;
Weight :: Float;
Bias :: Float;

Matrix 			:: utils.Matrix(Weight);
Tensor 			:: utils.Tensor(Weight);

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
				panic("TODO incorrect");
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

// Apply activation function to tensor (batch operation)
apply_activation_function_tensor :: proc (tensor : Tensor, A : Activation_function) {
	apply_activation_function(tensor.data, A);
}

// Apply activation function gradient to tensor (batch operation)
apply_activation_function_gradient_tensor :: proc (tensor : Tensor, A : Activation_function) {
	apply_activation_function_gradient(tensor.data, A);
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

// Calculate loss for batch (tensor)
@(require_results)
calculate_loss_tensor :: proc (prediction : Tensor, answer : Tensor, func : Loss_function, loc := #caller_location) -> f32 {
	
	assert(len(prediction.data) == len(answer.data), "The prediction and answer tensor sizes do not match", loc);
	
	L : f32;
	for p, i in prediction.data {
		switch func {
			case .MSE:
				L += f32(p - answer.data[i]) * f32(p - answer.data[i]);
			case:
				panic("TODO");
		}
	}
	
	L /= f32(len(prediction.data));
	
	return L;
}

//////////////////////////////// FEED FORWARD STUFF ////////////////////////////////

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

// Batch activations structure
Feedforward_batch_activations :: struct {
	activations : []Tensor,
}

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

// Initialize batch activations
init_batch_activations :: proc (network : ^Feedforward_network, batch_size : int) -> Feedforward_batch_activations {
	activations := make([]Tensor, len(network.layers) + 1);
	temp_gradients := make([]Tensor, len(network.layers));
	temp_matrices := make([]Matrix, len(network.layers));
	
	// Preallocate the activations for batch
	activations[0] = utils.tensor_make(Float, batch_size, network.input_size);
	for l, i in network.layers {
		activations[i+1] = utils.tensor_make(Float, batch_size, l.weights.rows);
		// temp_gradients should have the same dimensions as the input to this layer
		// For layer i, the input comes from activations[i] which has l.weights.columns dimensions
		temp_gradients[i] = utils.tensor_make(Float, batch_size, l.weights.columns);
		temp_matrices[i] = utils.matrix_make(l.weights.rows, l.weights.columns, Weight);
	}
	
	return {activations, temp_gradients, temp_matrices};
}

// Destroy batch activations
destroy_feedforward_batch_activations :: proc (activations : Feedforward_batch_activations) {
	for a in activations.activations {
		utils.tensor_destroy(a);
	}
	for t in activations.temp_gradients {
		utils.tensor_destroy(t);
	}
	for m in activations.temp_matrices {
		utils.matrix_destroy(m);
	}
	delete(activations.activations);
	delete(activations.temp_gradients);
	delete(activations.temp_matrices);
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

// Batch feedforward activations
feedforward_batch_activations :: proc (network : ^Feedforward_network, activations : Feedforward_batch_activations, data : Tensor, loc := #caller_location) {
	
	// Check if input data dimensions match network input size
	fmt.assertf(len(data.dims) >= 2 && data.dims[1] == network.input_size, 
		"The input data dimensions (%v) do not match the network input size %v", data.dims, network.input_size, loc = loc)
	
	batch_size := data.dims[0];
	
	// Copy input data to initial activation
	utils.tensor_copy(activations.activations[0], data);
	
	// Loop through each layer to compute activations
	for l, i in network.layers {
		// Store the computed activation for this layer
		next_activation := activations.activations[i + 1];
		
		// Compute next layer's activation by multiplying weights with current activation
		utils.tensor_matrix_mul_inplace(next_activation, activations.activations[i], l.weights, loc);
		
		// Add biases to the result (broadcast biases across batch)
		utils.tensor_add_bias_inplace(next_activation, l.biases);
		
		// Apply activation function to the result
		apply_activation_function_tensor(next_activation, network.activation);
	}
	
	return;
}

get_prediction :: proc (activations : Feedforward_activations, loc := #caller_location) -> (prediction : []Float) {
	
	prediction = activations.activations[len(activations.activations)-1];
	
	return prediction;
}

// Get prediction from batch activations
get_batch_prediction :: proc (activations : Feedforward_batch_activations, loc := #caller_location) -> (prediction : Tensor) {
	
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

// Batch feedforward
@(require_results)
feed_feedforward_batch :: proc (using network : ^Feedforward_network, activations : Feedforward_batch_activations, data : Tensor, loc := #caller_location) -> (prediction : Tensor) {
	
	fmt.assertf(len(data.dims) >= 2 && data.dims[1] == input_size, 
		"The input data dimensions (%v) do not match the network input size %v", data.dims, input_size, loc = loc)
	
	batch_size := data.dims[0];
	output_size := layers[len(layers)-1].weights.rows;
	
	// Copy input data to initial activation
	utils.tensor_copy(activations.activations[0], data);
	
	// Process through all layers
	for l, i in layers {
		// Matrix-tensor multiplication
		utils.tensor_matrix_mul_inplace(activations.activations[i+1], activations.activations[i], l.weights, loc);
		
		// Add biases (broadcast across batch)
		utils.tensor_add_bias_inplace(activations.activations[i+1], l.biases);
		
		// Apply activation function
		apply_activation_function_tensor(activations.activations[i+1], network.activation);
	}
	
	// Return the final activation as prediction
	prediction = activations.activations[len(activations.activations)-1];
	
	return prediction;
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

// Get loss gradient for batch
@(require_results)
get_loss_gradient_batch :: proc (prediction : Tensor, answer : Tensor, func : Loss_function, loc := #caller_location) -> Tensor {
	
	assert(len(prediction.data) == len(answer.data), "The prediction and answer tensor sizes do not match", loc);
	
	// This is the gradient of the Cost/Loss
	G := utils.tensor_make(Float, prediction.dims[0], prediction.dims[1]);
	
	// Calculate the loss gradient with respect to the output
	for p, i in prediction.data {
		switch func {
			case .MSE:
				G.data[i] = 2.0 * (p - answer.data[i]);
			case:
				panic("TODO");
		}
	}
	
	return G;
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
		// For most activation functions, we can compute ∂a/∂z from the output y = σ(z)
		y_curr := activations.activations[i + 1]; // Current layer's activations (output of this layer)
		
		#partial switch activation {
			case .none:
				// Identity: ∂a/∂z = 1, so ∂L/∂z = ∂L/∂y
				// G remains unchanged
			case .sigmoid:
				// For sigmoid: ∂a/∂z = y(1-y) where y = σ(z)
				for &g, idx in G {
					g *= y_curr[idx] * (1.0 - y_curr[idx]);
				}
			case .relu:
				// For ReLU: ∂a/∂z = 1 if y > 0, else 0
				for &g, idx in G {
					if y_curr[idx] <= 0.0 {
						g = 0.0;
					}
				}
			case .hyper_tan:
				// For tanh: ∂a/∂z = 1 - y² where y = tanh(z)
				for &g, idx in G {
					g *= (1.0 - y_curr[idx] * y_curr[idx]);
				}
			case .silu:
				// For SiLU: ∂a/∂z = σ(z)(1 + z(1-σ(z)))
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
		defer utils.matrix_destroy(dcdw);

		// Compute bias gradients: ∂L/∂b^l = ∂L/∂z^l
		// Bias gradient is identical to pre-activation gradient
		dcdb : []Float = G; // ∂L/∂b^l
		
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
		
		// Compute gradient for previous layer: ∂L/∂a^(l-1) = (W^l)^T * ∂L/∂z^l
		// This propagates the error back to the previous layer's activations
		G= utils.matrix_transposed_vec_mul(l.weights, G); // ∂L/∂a^(l-1)
		// G now contains ∂L/∂a^(l-1) for next iteration
	}
}

// Batch backpropagation
backprop_feedforward_batch :: proc (using network : ^Feedforward_network, activations : Feedforward_batch_activations, answer : Tensor, func : Loss_function, learning_rate : Float, loc := #caller_location) {
	
	// Get the final output prediction (y^L where L is the last layer)
	predictions := get_batch_prediction(activations);
	assert(predictions.dims[0] == answer.dims[0], "The prediction and awnser lengths does not match", loc);
	
	// Initialize gradient with ∂C/∂a^L (gradient of loss w.r.t. final output)
	dcda := get_loss_gradient_batch(predictions, answer, func); //This is ∂C/∂a^L 
	defer utils.tensor_destroy(dcda);
	
	//For the last layer (output layer)
	G := dcda; //the gradient is the cost function with respect to the activation

	fmt.assertf(len(activations.activations) == len(layers) + 1, "Expect one more activations then layers, expect %v activations, got: %v", len(layers) + 1, len(activations.activations));
	
	// Backpropagate through each layer in reverse order
	// If there are 10 layers then there is 11 activations.
	//The goal of this operation is to go from G -> da_L -> dz_L -> (dw_l, da_(L-1) or db_L)
	// da/dz * dG/da (G=C for output layer) is used to compute dw_l, da_(L-1) and db_L, so we start by computing that.
	// ∂C/∂a^L is tradionally the cost, but I use it here to describe just the gradient for the output of the current layer.
	#reverse for l, i in layers {
		
		// Get input activations for this layer: a^(l-1)
		// For layer i, activations[i] contains the input to that layer, because it is 0 indexed
		X := activations.activations[i]; //same as a^(l-1)
		
		// Next we want to convert ∂L/∂y^l to ∂L/∂z^l by multiplying by activation derivative
		// For this we need the derivitive of the activation function (which is σ'(y^l))
		// G currently holds ∂L/∂y^l, we need ∂L/∂z^l = ∂L/∂y^l ⊙ σ'(y^l)
		a_L := activations.activations[i + 1]; // Current layer's activations (output of this layer) //at this point it is a_L
		
		// For most activation functions, we can compute ∂a/∂z from the output y = σ(z)
		// The activations memeory is overwritten by the gradient, we reuse the memory for speed.
		apply_activation_function_gradient_tensor(a_L, network.activation); //Here it becomes ∂a/∂z instead of a_L
		dadz := a_L; //rename for consistentcy

		//Now we have da_L/dz_L and G where (G = dC/daL for output layer)
		//Calculate dcdz since it is used in the 3 other computations
		utils.tensor_elem_wise_multiply_inplace(dadz, G); //operation is inplace dadz becomes dcdz
		dcdz := dadz; //rename for consistentcy
		
		// Bias gradient is identical to dcdz //∂C/∂b^l = ∂L/∂z^l
		dcdb : Matrix = utils.tensor_as_matrix(dcdz); //does not copy, just a different way to view.

		// Compute weight gradients: ∂C/∂W^l = ∂C/∂z^l ⊗ a^(l-1)
		// This is an outer product: each element (i,j) = (∂L/∂z^l)_i * (a^(l-1))_j
		// Results in matrix same size as W^l
		// These weights are the weights on the output
		dcdw : Tensor = utils.outer_prodcut(G, X); // ∂L/∂W^l shape is [batch_size, out_dim, in_dim]
		defer utils.tensor_destroy(dcdw);
		
		// Gradient descent parameter updates:
		// W^l ← W^l - η * ∂L/∂W^l
		// b^l ← b^l - η * ∂L/∂b^l
		{
			batches := dcdb.rows;
			rate := learning_rate / f32(batches);

			// Update biases: b^l = b^l - η * ∂L/∂b^l
			assert(dcdb.columns == len(l.biases), "Incorrect biases length");
			for i in 0..<batches { //dcdb.dims[0] = number of batches
				bias_grad := utils.matrix_get_row_values(dcdb, i); //not a copy just a view
				for &b, j in l.biases {
					b -= rate * bias_grad[j]; //TODO we could move the *rate out of the loop by accumulating the result first and then dividing and then applying
				}
			}
			
			// Update weights: W^l = W^l - η * ∂L/∂W^l  
			assert(len(l.weights.data) == len(dcdw.data), "Incorrect weights length");
			for i in 0..<batches { //dcdb.dims[0] = number of batches
				wg := utils.tensor_get_sub_matrix(dcdw, {i})
				for &w, j in l.weights.data {
					w -= rate * wg.data[j];
				}
			}
		}
		
		// Compute gradient for previous layer: ∂L/∂a^(l-1) = (W^l)^T * ∂L/∂z^l
		// This propagates the error back to the previous layer's activations
		G = utils.matrix_transposed_vec_mul(l.weights, G); // ∂L/∂a^(l-1)
		// G now contains ∂L/∂a^(l-1) for next iteration
	}
}

feed :: proc {feed_feedforward, feed_feedforward_batch}
backprop :: proc {backprop_feedforward, backprop_feedforward_batch}
destroy :: proc {destroy_feedforward}

// Create batches from dataset
create_batches_from_dataset :: proc(dataset: ^Dataset, labels: [][]Float, batch_size: int, loc := #caller_location) -> (batch_inputs: []Tensor, batch_answers: []Tensor) {
	
	total_samples := dataset.sample_count;
	num_batches := (total_samples + batch_size - 1) / batch_size; // Ceiling division
	
	batch_inputs = make([]Tensor, num_batches);
	batch_answers = make([]Tensor, num_batches);
	
	for batch_idx in 0..<num_batches {
		start_idx := batch_idx * batch_size;
		end_idx := min(start_idx + batch_size, total_samples);
		current_batch_size := end_idx - start_idx;
		
		// Create input tensor for this batch
		batch_inputs[batch_idx] = utils.tensor_make(Float, current_batch_size, dataset.feature_count);
		
		// Create answer tensor for this batch
		batch_answers[batch_idx] = utils.tensor_make(Float, current_batch_size, len(labels[0]));
		
		// Fill the batch with data
		for sample_idx in 0..<current_batch_size {
			global_idx := start_idx + sample_idx;
			
			// Copy input features
			input_start := sample_idx * dataset.feature_count;
			input_end := input_start + dataset.feature_count;
			input_slice := batch_inputs[batch_idx].data[input_start:input_end];
			
			// Get row from dataset
			row_data := utils.matrix_get_row_values(dataset.features, global_idx);
			for j in 0..<dataset.feature_count {
				input_slice[j] = Float(row_data[j]);
			}
			
			// Copy answer labels
			answer_start := sample_idx * len(labels[0]);
			answer_end := answer_start + len(labels[0]);
			answer_slice := batch_answers[batch_idx].data[answer_start:answer_end];
			
			// Get one-hot label
			label_data := labels[global_idx];
			for j in 0..<len(labels[0]) {
				answer_slice[j] = Float(label_data[j]);
			}
		}
	}
	
	return;
}

// Destroy batch data
destroy_batch_data :: proc(batch_inputs: []Tensor, batch_answers: []Tensor) {
	for input in batch_inputs {
		utils.tensor_destroy(input);
	}
	for answer in batch_answers {
		utils.tensor_destroy(answer);
	}
	delete(batch_inputs);
	delete(batch_answers);
}






