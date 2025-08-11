package nn_examples;

import "core:strconv"
import "core:testing"
import "core:fmt"
import "core:log"
import "core:time"
import "core:slice"
import "core:math"

import "../../utils"
import nn ".."

/*
@(test)
Feedforward :: proc (t : ^testing.T) {
*/

entry :: proc () {

	config := nn.Dataset_Config{
		max_samples = 20,
	};

	dataset, err := nn.load_parquet_dataset("C:/Users/jakob/Datasets/mnist/mnist/mnist/train-00000-of-00001.parquet", config);
	assert(err == .None, "Failed to load dataset");
	defer nn.destroy_dataset(dataset);
	
	//net := nn.make_net(dataset.feature_count, 10, 100, 200);
	net := nn.make_net(5, 10, 5, 5);

	labels := nn.dataset_labels_to_one_hot(dataset, 10);
	defer nn.destroy_one_hot_labels(labels);

	epochs := 1;

	for epoch in 0..<epochs {
		for i in 0..<dataset.sample_count {
			awnser : []nn.Float = labels[i];
			prediction, act_his, b_his := nn.net_inference(net, {0.653, 0.23, 1, 4, -1}, 5);
			
			loss := nn.calculate_loss(prediction, awnser, .MSE);
			loss_grad := nn.get_loss_gradient(prediction, awnser, .MSE);
			nn.net_backprop(net, loss_grad, act_his, b_his, 0.1);
			
			pick := -1;
			last_p : f32 = math.inf_f32(-1);
			for p, i in prediction {
				if p > last_p {
					pick = i;
					last_p = p;
				}
			}

			fmt.printf("loss : %v, pick : %v, prediction : %v\n", loss, pick, prediction);
		}
	}


}