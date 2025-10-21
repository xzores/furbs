package neural_network

import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:fmt"
import "core:log"

import "../utils"

//////////////////////////////// ARCHITECTURE ////////////////////////////////

//TODO For later
/*
//Can be feedforward, CNN, RNN, etc.
Module :: union {
	^Feedforward_network,
}

Dimensions :: distinct []int;
Input :: distinct Dimensions;
Output :: distinct Dimensions;

Interface_proc :: #type proc (); //TODO 
Flatten : Interface_proc : proc () {};

Connection :: struct {
	from : union {Input, int},
	to : union {Output, int},
	method : Interface_proc,
}

//A high level contruct, it contians multiple different networks, and then connects them.
Architecture :: struct {
	modules : []Module,
	connections : []Connection,
}

init_architecture :: proc (modules : []Module, connections : []Connection, loc := #caller_location) -> (arch : ^Architecture) {
	arch = new(Architecture);
	
	// check that all things are connected and that nothing is left unconencted
	if valid, error_msg := validate_connectivity(modules, connections); !valid {
		log.errorf("Architecture validation failed - connectivity issue: %s\n", error_msg);
		free(arch);
		return nil;
	}
	
	arch^ = {
		slice.clone(modules),
		slice.clone(connections),
	}
	
	in_dims : []Dimensions = get_input_dimension(arch);
	out_dims : []Dimensions = get_output_dimension(arch);

	assert(len(in_dims) != 0, "The input dimensions are empty", loc = loc);
	assert(len(out_dims) != 0, "The output dimensions are empty", loc = loc);

	return arch;
}

destroy_architecture :: proc (arch : ^Architecture) {
	//The modules are not own by the architecture, they are deleted sperately.
	delete(arch.modules);
	delete(arch.connections);
	free(arch);
}

//Trains an architecture, by feeding it data, and then backpropagating the error.
train_architecture :: proc (arch : ^Architecture, inputs : []Tensor, awnsers : []Tensor, batch_size : int, epochs : int, learning_rate : f32, loc := #caller_location) -> (res : []Tensor) {
	//Overall notes:
	//Because we do this as an architecture, and treat each module as its own sub NN, we cannot do feed forward and backward on the whole NN.
	//instead it is done for one neurual network and then the next and then the next passing the forward on the forward pass and backwards on the backprop pass.
	//IDK if that is a good idea but that is how it works right now, this means that each type of module must support taken in a Tensor of data instead of just a float vector.

	fmt.assertf(batch_size > 0, "Batch size must be greater than 0", loc = loc);
	fmt.assertf(epochs > 0, "Epochs must be greater than 0", loc = loc);
	fmt.assertf(learning_rate > 0.0, "Learning rate must be greater than 0", loc = loc);
	
	out_len := get_output_dimension(arch);
	in_len := get_output_dimension(arch);
	
	//first check, just checking if the amout of data given matches the number of module inputs.
	fmt.assertf(len(inputs) == len(in_len), "the input size does not match the size of the inputs in the architechture, expected: %v, got: %v", in_len, len(inputs), loc = loc);
	
	//Convert input data into batched data.
	batch_input := ....; //is the input data for the batch
	batch_awnsers := ...; //is the correct predictions for the batch
	
	//Activations is defined out here so that the memory can be reused for each epoch/batch
	activations := make([]Tensor, len(???));
	
	// For each epoch
	for epoch := 0; epoch < epochs; epoch += 1 {
		
		// Process inputs in batches
		for input, i in batch_input {

			// Forward pass the entire batch through the architecture
			forward_pass_architecture(arch, activations, input); //The dimension is {batchsize, ..out_len}
			
			//This is a single tensor which stores all the predictions.
			awnsers : Tensor = batch_awnsers[i];
			
			//A tensor used like an array to store all the predictions the models made
			predictions : Tensor = get_architecture_prediction(activations);

			//Calcuate the loss, the output is a tensor used like an array of Tensors (like []Tensor, but easier to operate on)
			loss := calculate_architecture_loss(prediction, awnser, .MSE);
			
			//Now give the activations (A tensor used like an array) and the awnsers (A tensor used like an array) and update the activations.
			//This will update all the wieghts and biases of the entire network.
			backprop_architecture(ff, activations, awnser, .MSE, 0.01);
		}
	}
	
	return nil;
}


// Forward pass through the entire architecture
forward_pass_architecture :: proc(arch: ^Architecture, inputs: []Tensor) -> (output: []Tensor) {
	
	// Track outputs from each module
	module_outputs := make([]Tensor, len(arch.modules));
	
	// Find input connections and feed data to input modules
	for connection in arch.connections {
		switch f in connection.from {
		case Input:
			// This is an input connection
			switch t in connection.to {
			case int:
				if t >= 0 && t < len(arch.modules) {
					// Feed input to this module
					module_output := feed_module(arch.modules[t], input);
					module_outputs[t] = module_output;
				}
			}
		}
	}
	
	// Process connections between modules
	// TODO: Implement proper topological sort or dependency resolution
	// For now, process connections in order (this is simplified)
	for connection in arch.connections {
		switch f in connection.from {
		case int:
			if f >= 0 && f < len(arch.modules) {
				// This is a module-to-module connection
				switch t in connection.to {
				case int:
					if t >= 0 && t < len(arch.modules) {
						// Get output from source module
						source_output := module_outputs[f];
						if len(source_output) > 0 {
							// Feed to target module
							module_output := feed_module(arch.modules[t], source_output);
							module_outputs[t] = module_output;
						}
					}
				case Output:
					// This is an output connection
					// Return the output from the source module
					return module_outputs[f];
				}
			}
		}
	}
	
	// If no output connection found, return the last module's output
	// This is a fallback and might not be the intended behavior
	for i := len(module_outputs) - 1; i >= 0; i -= 1 {
		if len(module_outputs[i]) > 0 {
			return module_outputs[i];
		}
	}
	
	// If no module outputs, return input
	return input;
}

// Feed input through a single module
feed_module :: proc(module: Module, input: Tensor) -> (output: Tensor) {
	switch m in module {
		case ^Feedforward_network:{
			return feed_feedforward(m, input);
		}
		case: {
			panic("not implemented");
		}
	}
	return input;
}








////////////////////////////////////// HELPER FUNCTIONS //////////////////////////////////////


// Helper function to get input dimensions for a module
get_module_input_dimensions :: proc(module: Module) -> Dimensions {
	switch m in module {
	case ^Feedforward_network:
		return {m.input_size};
	}
	return {};
}

// Helper function to get output dimensions for a module
get_module_output_dimensions :: proc(module: Module) -> Dimensions {
	switch m in module {
	case ^Feedforward_network:
		if len(m.layers) > 0 {
			last_layer := m.layers[len(m.layers) - 1];
			return {len(last_layer.biases)};
		}
	}
	return {};
}

// Get input dimensions for the entire architecture
// Returns dimensions for all input modules, e.g., {{10}, {3,64,64}} for two inputs
get_input_dimension :: proc(arch: ^Architecture) -> []Dimensions {
	input_dims: [dynamic]Dimensions;
	
	// Find all modules that receive input connections
	for connection in arch.connections {
		switch f in connection.from {
		case Input:
			// This is an input connection
			switch t in connection.to {
			case int:
				if t >= 0 && t < len(arch.modules) {
					// Get input dimensions for this module
					module_dims := get_module_input_dimensions(arch.modules[t]);
					if len(module_dims) > 0 {
						append(&input_dims, module_dims);
					}
				}
			}
		}
	}
	
	// Return the array of Dimensions directly
	result := make([]Dimensions, len(input_dims));
	for i, dims in input_dims {
		result[i] = dims;
	}
	
	delete(input_dims);
	return result;
}

// Get output dimensions for the entire architecture
// Returns dimensions for all output modules, e.g., {{10}, {3,64,64}} for two outputs
get_output_dimension :: proc(arch: ^Architecture) -> []Dimensions {
	output_dims: [dynamic]Dimensions;
	
	// Find all modules that have output connections
	for connection in arch.connections {
		switch t in connection.to {
		case Output:
			// This is an output connection
			switch f in connection.from {
			case int:
				if f >= 0 && f < len(arch.modules) {
					// Get output dimensions for this module
					module_dims := get_module_output_dimensions(arch.modules[f]);
					if len(module_dims) > 0 {
						append(&output_dims, module_dims);
					}
				}
			}
		}
	}
	
	// Return the array of Dimensions directly
	result := make([]Dimensions, len(output_dims));
	for i, dims in output_dims {
		result[i] = dims;
	}
	
	delete(output_dims);
	return result;
}

// Check that all modules are connected and nothing is left unconnected'
@(private)
validate_connectivity :: proc(modules: []Module, connections: []Connection) -> (valid: bool, error_msg: string) {
	// Track which modules have inputs and outputs
	has_input := make([]bool, len(modules));
	has_output := make([]bool, len(modules));
	
	// Check connections
	for connection in connections {
		switch f in connection.from {
		case int:
			if f >= 0 && f < len(modules) {
				has_output[f] = true;
			}
		}
		
		switch t in connection.to {
		case int:
			if t >= 0 && t < len(modules) {
				has_input[t] = true;
			}
		}
	}
	
	// Check for unconnected modules
	for i := 0; i < len(modules); i += 1 {
		if !has_input[i] && !has_output[i] {
			return false, fmt.tprintf("Module %d is completely unconnected", i);
		}
	}
	
	// Check for modules with no inputs (except if they're input modules)
	for i := 0; i < len(modules); i += 1 {
		if !has_input[i] {
			// This could be an input module, which is acceptable
			// But we should verify it has outputs
			if !has_output[i] {
				return false, fmt.tprintf("Module %d has no inputs and no outputs", i);
			}
		}
	}
	
	// Check for modules with no outputs (except if they're output modules)
	for i := 0; i < len(modules); i += 1 {
		if !has_output[i] {
			// This could be an output module, which is acceptable
			// But we should verify it has inputs
			if !has_input[i] {
				return false, fmt.tprintf("Module %d has no outputs and no inputs", i);
			}
		}
	}
	
	delete(has_input);
	delete(has_output);
	
	return true, "";
}
*/