package nn_examples;

import "core:testing"
import "core:fmt"
import "core:log"
import "core:time"

import "../../utils"
import nn ".."

/*
@(test)
Feedforward :: proc (t : ^testing.T) {
*/

entry :: proc () {
	time.sleep(10 * time.Millisecond);
	
	config := nn.Dataset_Config{
		max_samples = 15,
	};
	dataset, err := nn.load_parquet_dataset("C:/Users/jakob/Datasets/mnist/mnist/mnist/train-00000-of-00001.parquet", config);
	assert(err == .None, "Failed to load dataset");
	defer nn.destroy_dataset(dataset);

	log.infof("dataset: %#v", dataset);

	ff := nn.make_feedforward(dataset.feature_count, 10, {100, 20, 20, 20}, {}, nn.Activation_function.sigmoid);
	defer nn.destroy_feedforward(ff);

	labels := nn.dataset_labels_to_one_hot(dataset, 10);
	defer nn.destroy_one_hot_labels(labels);

	//training
	for i in 0..<config.max_samples-1 {
		activations := nn.feed_feedforward_activations(ff, utils.matrix_get_row_values(dataset.features, i));
		defer nn.destroy_feedforward_activations(activations);
		
		awnser : []nn.Float = labels[i]
		
		prediction := activations[len(activations)-1];
		loss := nn.calculate_loss(activations[len(activations)-1], awnser, .MSE);
		
		nn.backprop_feedforward(ff, activations, awnser, .MSE, 10);
		
		if i %% 100 == 0 {
			fmt.printf("loss : %v\n", loss);
		}
	}
	
	//testing
	activations := nn.feed_feedforward_activations(ff, utils.matrix_get_row_values(dataset.features, 0));
	defer nn.destroy_feedforward_activations(activations);
	
	nn.print_ascii_image(utils.matrix_get_row_values(dataset.features, 0), 28, 28);

	fmt.printf("res : %#v (label: %v, correct : %v) \n", activations[len(activations)-1], nn.one_hot_decode(activations[len(activations)-1]), dataset.labels[0]);
}