package nerual_network;

import "core:math/rand"
import "core:container/queue"
import pq "core:container/priority_queue"

Neuron_type :: enum {
	input,
	hidden,
	output,
}

Free_connection :: struct {
	neuron : int, //indicies
	mult : f16, //The strength
}

Free_neuron :: struct {
	is_input : Neuron_type,
	req_activation : f16,
	out_connections : [dynamic]Free_connection,
	in_connections : [dynamic]int, //index of the other neuron
}

Neuron_trigger :: struct {
	trigger_time : int,	//In clocks
	trigger_on : int, //index 
	strength : f32,
}

Free_net :: struct {
	neuron_activations : pq.Priority_Queue(Neuron_trigger),
	neurons : [dynamic]Free_neuron,
}

make_free_net :: proc (input_size : int, output_size : int, start_neurons : int) -> Free_net {
	
	//_neuron_activations : queue.Queue(Neuron_trigger);
	//queue.init(&_neuron_activations,);
	
	less_proc :: proc (a, b : Neuron_trigger) -> bool {
		return a.trigger_time < b.trigger_time;
	}
	
	swap_proc :: proc (arr : []Neuron_trigger, a, b : int) {
		arr[a], arr[b] = arr[b], arr[a];
	}
	
	_na : pq.Priority_Queue(Neuron_trigger);
	err := pq.init(&_na, less_proc, swap_proc);
	assert(err == nil);
	
	fr := Free_net {
		_na,
		make([dynamic]Free_neuron),
	}
	
	for i in 0..<input_size {
		make_free_net_neuron(&fr, .input);
	}
	
	for i in 0..<output_size {
		make_free_net_neuron(&fr, .hidden);
	}
	
	for i in 0..<start_neurons {
		make_free_net_neuron(&fr, .output);
	}
	
	for n, i in fr.neurons {
		for other, j in fr.neurons {
			if i != j  {
				connect_free_net_neurons();			
			}
		}
	}
	
	return fr;
}

make_free_net_neuron :: proc (fr : ^Free_net, type : Neuron_type) -> int {
	
	append(&fr.neurons, Free_neuron{type, auto_cast rand.float32_range(-1, 1), make([dynamic]Free_connection), make([dynamic]int)});
	
	return len(neurons);
}


connect_free_net_neurons :: proc (fr : ^Free_net, a, b : int) {
	
}
