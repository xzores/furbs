package nn_examples;

import "core:strconv"
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

Optimizer_struct :: struct {

}

entry :: proc () {
	
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
		labels := nn.dataset_labels_to_one_hot(dataset, 10);
		defer nn.destroy_one_hot_labels(labels);

		activations := nn.init_activations(ff);
		defer nn.destroy_feedforward_activations(activations);

		for k in 0..<1 {
			for i in 0..<dataset.sample_count {
				nn.feedforward_activations(ff, activations, utils.matrix_get_row_values(dataset.features, i));
				
				awnser : []nn.Float = labels[i]
				
				prediction := nn.get_prediction(activations);
				loss := nn.calculate_loss(prediction, awnser, .MSE);
				
				nn.backprop_feedforward(ff, activations, awnser, .MSE, 0.01);
				
				if i %% 100 == 0 {
					fmt.printf("loss : %v\n", loss);
				}
			}
		}
	}

	//testing
	{		
		// Load test dataset and run inference
		fmt.printf("\n=== TESTING ON TEST DATASET ===\n");
		
		test_config := nn.Dataset_Config{
			max_samples = 0, // Test on 1000 samples
		};
		
		test_dataset, test_err := nn.load_parquet_dataset("C:/Users/jakob/Datasets/mnist/mnist/mnist/test-00000-of-00001.parquet", test_config);
		assert(test_err == .None, "Failed to load test dataset");
		defer nn.destroy_dataset(test_dataset);
		
		log.infof("test_dataset: %#v", test_dataset);
		
		// Run inference on test dataset
		correct_predictions := 0;
		total_predictions := test_dataset.sample_count;
		
		fmt.printf("Running inference on %d test samples...\n", total_predictions);
		
		activations := nn.init_activations(ff);
		defer nn.destroy_feedforward_activations(activations);

		for i in 0..<total_predictions {
			nn.feedforward_activations(ff, activations, utils.matrix_get_row_values(test_dataset.features, i));
			
			predicted_digit := nn.one_hot_decode(nn.get_prediction(activations));
			actual_digit := int(test_dataset.labels[i]);
			
			if predicted_digit == actual_digit {
				correct_predictions += 1;
			}
			
			// Show first few predictions for debugging
			if i < 5 {
				fmt.printf("Sample %d: Predicted %d, Actual %d %v\n", i, predicted_digit, actual_digit, predicted_digit == actual_digit);
				
				// Show ASCII image for first sample
				if i == 0 {
					nn.print_ascii_image(utils.matrix_get_row_values(test_dataset.features, i), 28, 28, "Test Sample 0");
				}
			}
			
			// Progress indicator
			if i %% 100 == 0 && i > 0 {
				fmt.printf("Processed %d/%d samples...\n", i, total_predictions);
			}
		}
		
		// Calculate and display accuracy
		accuracy := f32(correct_predictions) / f32(total_predictions) * 100.0;
		fmt.printf("\n=== TEST RESULTS ===\n");
		fmt.printf("Correct predictions: %d/%d\n", correct_predictions, total_predictions);
		fmt.printf("Accuracy: %.2f%%\n", accuracy);
	}
}