package neural_network

import "core:fmt"
import "core:math/rand"

Neuron_type :: enum {
	hidden,
	input, 
	output,
}

Connection :: struct {
	weight : Float,
	//TODO we might something like only trigger if above x and below y (this could allow for between or outside)
	to : int,
}

Neuron :: struct {
	bias : Float,
	type : Neuron_type, //Cannot write to it.
	connections : [dynamic]Connection,
}

//Describtion of the neurual network.
Net :: struct {
	neurons : [dynamic]Neuron,

	input_index : int,
	input_size : int,
	output_index : int,
	output_size : int,
}

@(require_results)
make_net :: proc (input_size : int, output_size : int, start_neurons : int, connections_ratio : int) -> ^Net {

	//First at hidden, then output then input
	neurons := make([dynamic]Neuron, start_neurons + output_size + input_size);
	connections := make([dynamic]Connection, start_neurons * connections_ratio);

	for &n in neurons[:start_neurons] {
		//randomize biases
		n.bias = rand.float32_range(-1, 1);
		n.type = .hidden;

		//Create connections_ratio new connection outwards.
		for i in 0..<connections_ratio {
			append(&n.connections, Connection{rand.float32_range(-1, 1), rand.int_max(start_neurons + output_size - 1)});
		}
	}

	//Assign inputs
	for &n in neurons[start_neurons:start_neurons + output_size] {
		n.type = .input;
		n.bias = rand.float32_range(-1, 1);
		
		//Create connections_ratio new connection outwards.
		for i in 0..<connections_ratio {
			append(&n.connections, Connection{rand.float32_range(-1, 1), rand.int_max(start_neurons-1)});
		}
	}

	//Assign outputs
	for &n, i in neurons[start_neurons + output_size:start_neurons + output_size + input_size] {
		n.type = .output;
		//output nuerons dont need any outgoing connections.
		
		//Force minimum one connection to the output
		from := rand.int_max(start_neurons);
		append(&neurons[from].connections, Connection{rand.float32_range(-1, 1), start_neurons + output_size + i}) //from random to this.
	}
	
	net := new(Net);
	net^ = {neurons, start_neurons, input_size, start_neurons + input_size, output_size}

	return net; 
}

Activation :: struct {
	from : int,
	connect_index : int, //in the from connection

	to : int,
}

net_inference :: proc (net : ^Net, input : []Float, max_iterrations : int) -> (output : []Float, activations_history : [dynamic][dynamic]Activation, b_value_history : [dynamic][]Float) {

	output = make([]Float, net.output_size);

	Neuron_input :: struct {
		value : Float,
	}
	
	Neuron_output :: struct {
		value : Float,
	}
	
	A_values := make([]Neuron_input, len(net.neurons)); //A and B values has same length as neurons
	B_values := make([]Neuron_output, len(net.neurons));

	activations_history = make([dynamic][dynamic]Activation) //this is a set which tells what neurons are currently being active aka they are delivering data to the next one.
	//The history of all the activations levels, like how much was neuron 130 activated in the 3th cycle. Alot of memory is wasted here because we also store for all the ones which was not activated this round.
	b_value_history = make([dynamic][]Float) //has the same length as activations_history
	active_neurons := make(map[int]struct{});

	//First place the input data at the B value of the inputs
	for &b, i in B_values[net.input_index:net.input_index + net.input_size] {
		b.value = input[i];
		active_neurons[net.input_index + i] = {}
	}
	
	for it in 0..<max_iterrations {
		
		activations := make([dynamic]Activation) //The newly activated ones.
		append(&activations_history, activations);
		b_val_his := make([]Float, len(net.neurons));
		append(&b_value_history, b_val_his);

		new_active_neurons := make(map[int]struct{})
		
		//Calculate the new A values (the inputs of the next neurons)
		for an in active_neurons {
			for conn, c in net.neurons[an].connections {
				A_values[conn.to].value += conn.weight * B_values[an].value;
				append(&activations, Activation{an, c, conn.to});
				new_active_neurons[conn.to] = {};
				//fmt.printf("\tact from %v to %v, w: %v\n", an, conn.to, conn.weight);
			}
		}

		//The values are now placed at the input of the next neuron, now take it though the bias and activation function
		for act in activations {
			i := act.to;
			neu := net.neurons[i];
			B_values[i].value = sigmoid(A_values[i].value + neu.bias);
			b_val_his[i] = B_values[i].value; //store the value in the history.
			//fmt.printf("\tneuron %v of type %v with bias %v, new b value: %v\n", i, neu.bias, neu.type, B_values[i].value);
		}

		active_neurons = new_active_neurons;
	}
	
	//Finally read the output
	for a, i in B_values[net.output_index:net.output_index + net.output_size] {
		//fmt.printf("found output %v\n", B_values);
		output[i] = a.value;
	}
	
	return output, activations_history, b_value_history;
}

//What is the error here? the gradient
net_backprop :: proc (net : ^Net, error_grad : []Float, activations_history : [dynamic][dynamic]Activation, a_L_values_history : [dynamic][]Float, learning_rate : f32) {
	//Notes:
	//We want to go from the gradient from the A value of the "to" neuron to the B value of the "from" neuron
	//The gradients we get in is the "to" neurons desired gradient change (at the A value place) since the output does not get any bias or activation funtion
	assert(len(activations_history) == len(a_L_values_history), "B history and activations history not the same");
	
	//This is A node gradients
	grad_of_C := error_grad;
	neurons_in_this_layer := make(map[int]int); //this is an index into the gradient vector from the neuron index.
	
	//Make a sorted list of which neuron corrrisponds to which gradient.
	for o, i in net.output_index ..< net.output_index+net.output_size {
		neurons_in_this_layer[o] = i; //add it to the set mapping from neuron id to gradient index
	}

	//convert to gradient of a_L
	//TODO
	grad := grad_of_C; //For now. 

	/*
	#reverse for activations, his_i in activations_history {
		//activations is a list of neurons getting fired in this step
		//The overall goal of this loop is to update the weight and bias and then provide the gradient for the next activations layer/step.
		//We do this by looking at the activations in this activations layer, these will 
		assert(len(grad_of_C) == len(neurons_in_this_layer), "internal error");

		//The infomation i need is the "current" neuron layer, which is all the neurons which we currently know the gradient for and the known gradients
		//For the first layer that is the error_grad, and then i need a list which tell me what neurons that corrispond to.
		
		A_val_gradient := make(map[int]Float);

		//This will take the activations and sum up all the activations on the input of the current and place them in the backprop to the previous layer. 
		for act in activations {
			//Ok this is an output, now let us find the error gradient for this perticular output
			//This is pre activation function
			dcda_last := net.neurons[act.from].connections[act.connect_index].weight * grad[neurons_in_this_layer[act.to]]; //this is dC/da_L-1 for a single connection, we must sum them all up.
			A_value_grad := &A_val_gradient[act.from];
			A_value_grad += dcda_last;
			
			//TODO update wieght
		}

		for from, gradient in A_val_gradient {
			neu_grad := activation_function_gradient(gradient, b_values_history[his_i][from], .sigmoid); //Convert the gradient from to dC/dz_L dcdz
			from_neuron := &net.neurons[from];

			//now find dcdw, dcda_(l-1) and dcdb 
			dcdb := 1 * neu_grad; //The same the dz/db is 1
			dcdw := b_values_history[his_i-1][from] * neu_grad;

			//update the neuron
			from_neuron.bias += dcdb * learning_rate;
			from_neuron.connections[act.connect_index].weight += dcdw * learning_rate;

			//place dcda_last in an array such the we can update the next neurons
			next_grads[neurons_in_this_layer[act.from]] += dcda_last;

		}


		next_grads := make([dynamic]Float);
		next_neurons_in_this_layer := make([dynamic]int)
	}
	*/
}

backprop_step :: proc (gradients : []Float, neurons_a_L : []^Neuron, neurons_a_L_1 : []^Neuron) {


}

activation_function_gradient :: proc (g : Float, a : Float, A : Activation_function) -> Float {
	// `g` is ∂C/∂a (loss gradient w.r.t. activation)
	// `a` is the activation output (e.g., sigmoid(z))
	// returns: ∂C/∂z = ∂C/∂a * ∂a/∂z
	switch A {
		case .none:
			// Identity: ∂a/∂z = 1
			return g;

		case .sigmoid:
			// ∂a/∂z = a * (1 - a), where a = sigmoid(z)
			return g * a * (1.0 - a);

		case .relu:
			// ∂a/∂z = 1 if a > 0 else 0 (approximation using a instead of z)
			if a > 0.0 { 
				return g
			} else { 
				return 0.0 
			};

		case .hyper_tan:
			// ∂a/∂z = 1 - a^2, where a = tanh(z)
			return g * (1.0 - a * a);

		case .silu:
			// Requires z (not a), so fail here
			panic("SiLU gradient needs pre-activation value (z), not just activation output (a)");

		case:
			panic("Activation function gradient not implemented");
	}
}