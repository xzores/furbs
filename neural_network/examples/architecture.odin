package nn_examples;

import "core:strconv"
import "core:testing"
import "core:fmt"
import "core:log"
import "core:time"

import "../../utils"
import nn ".."

Tuner_struct :: struct {

}

_entry :: proc () {
	
	config := nn.Dataset_Config{
		max_samples = 0,
	};
	
	dataset, err := nn.load_parquet_dataset("C:/Users/jakob/Datasets/mnist/mnist/mnist/train-00000-of-00001.parquet", config);
	assert(err == .None, "Failed to load dataset");
	defer nn.destroy_dataset(dataset);

	log.infof("dataset: %#v", dataset);
	
	ff := nn.make_feedforward(dataset.feature_count, 10, {100, 100, 100}, {}, nn.Activation_function.sigmoid);
	defer nn.destroy_feedforward(ff);
	
	//training
	{
		
	}
	
}