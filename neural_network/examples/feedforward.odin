package nn_examples;

import "core:testing"
import "core:fmt"
import "core:time"

import nn ".."

@(test)
Feedforward :: proc (t : ^testing.T) {
	time.sleep(10 * time.Millisecond);
	
	ff := nn.make_feedforward(5, 3, {7, 8, 3, 5}, {}, nn.Activation_function.sigmoid);
	defer nn.destroy_feedforward(ff);
	
	
	for i in 0..<1 {
		activations : [][]nn.Float = nn.feed_feedforward_activations(ff, {1, 2, 3, 4, 5});
		fmt.printf("activations : %#v\n\n", activations)
		defer {
			for a in activations{
				delete(a);
			}
			delete(activations);
		}
		
		awnser : []nn.Float = {1, 0.5, 0}
		
		
		prediction := activations[len(activations)-1];
		loss := nn.calculate_loss(activations[len(activations)-1], awnser, .MSE);
		nn.backprop_feedforward(ff, activations, awnser, .MSE, 0.0001);
		if i %% 100 == 0 {
			fmt.printf("loss : %v\n", loss);
		}
	}
	
	//fmt.printf("res : %#v\n", activations);
	
	time.sleep(10 * time.Millisecond);
}