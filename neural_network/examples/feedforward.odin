package nn_examples;

import "core:testing"
import "core:fmt"

import nn ".."

@(test)
Feedforward :: proc (t : ^testing.T) {
	
	ff := nn.make_feedforward(5, 3, {7, 8}, {}, nn.Activation_function.sigmoid);
	defer nn.destroy_feedforward(ff);
	
	res := nn.feed_feedforward(ff, {1, 2, 3, 4, 5});
	defer delete(res);
	
	awnser : []nn.Float = {1, 0.5, 0}
	
	fmt.printf("res : %#v\n", res);
	
	loss := nn.calculate_loss(res, awnser, .MSE);
	loss_gradient := nn.calculate_loss_gradient(ff, res, awnser, .MSE);
	
	fmt.printf("loss : %v\n", loss);
	fmt.printf("gradient : %v\n", loss_gradient);
	
}