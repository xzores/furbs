package nn_examples;

/*
import "core:strconv"
import "core:testing"
import "core:fmt"
import "core:log"
import "core:time"

import "../../utils"
import nn ".."

entry_single :: proc () {
	
	config := nn.Dataset_Config{
		max_samples = 10000,
	};

	dataset, err := nn.load_parquet_dataset("C:/Users/jakob/Datasets/mnist/mnist/mnist/train-00000-of-00001.parquet", config);
	assert(err == .None, "Failed to load dataset");
	defer nn.destroy_dataset(dataset);

	log.infof("dataset: %#v", dataset);
	
	ff := nn.make_feedforward(dataset.feature_count, 10, {100, 100, 100}, {}, nn.Activation_function.sigmoid);
	defer nn.destroy_feedforward(ff);

	epochs := 2;
	learning_rate : f32 = 0.01;

	start_time := time.now();

	//training
	{
		labels := nn.dataset_labels_to_one_hot(dataset, 10);
		defer nn.destroy_one_hot_labels(labels);

		activations := nn.init_activations(ff);
		defer nn.destroy_feedforward_activations(activations);

		for epoch in 0..<epochs {
				
			for i in 0..<dataset.sample_count {
				nn.feedforward_activations(ff, activations, utils.matrix_get_row_values(dataset.features, i));
				awnser : []nn.Float = labels[i]
				prediction := nn.get_prediction(activations);
			
				if is_wrong {
					l := 0;
					change_amount := 0.01;
					//Loop over the neurons, change them a little to see if the result gets correct
					
					bad : []nn.Feedforward_network;
					//TODO defer delete bad ones

					for true {
						//copy the nn, to get a slight different version to see if it does better.
						new_ff := nn.changed_copy(ff, change_amount);
						
						nn.feedforward_activations(new_ff, activations, utils.matrix_get_row_values(dataset.features, i));
						prediction := nn.get_prediction(activations);

						if is_new_right {
							//Then take the difference between the wrong output and the right output, that is now out Cost gradient.
							//there is technicallity because we likely have many bad ones, so we average that somehow
							
							
							break; //we are done next training example
						}
						else {
							append(&bad, new_ff);
						}
							
						change_amount = change_amount + change_amount * l; //incease the change by l * 1 percent until we find a good awnser. so 1 then 2.01 then 3.0... procent so on.
					}
				}
				
			}
		}

		loss := nn.calculate_loss(prediction, awnser, .MSE);
		nn.backprop_feedforward(ff, activations, awnser, .MSE, learning_rate);
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
			
			prediction := nn.get_prediction(activations);
			predicted_digit := nn.one_hot_decode(prediction);
			actual_digit := int(test_dataset.labels[i]);
			
			// DEBUG: Print first 5 predictions with their values
			if i < 5 {
				fmt.printf("Sample %d: Predicted %d, Actual %d %v\n", i, predicted_digit, actual_digit, predicted_digit == actual_digit);
				fmt.printf("  Prediction values: %v\n", prediction);
			}
			
			if predicted_digit == actual_digit {
				correct_predictions += 1;
			}
			
			// Show first few predictions for debugging
			if i < 5 {
				fmt.printf("Sample %d: Predicted %d, Actual %d %v\n", i, predicted_digit, actual_digit, predicted_digit == actual_digit);
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

	end_time := time.now();
	duration := time.diff(start_time, end_time);
	fmt.printf("\n=== SINGLE SAMPLE TRAINING TIME ===\n");
	fmt.printf("Total time: %v\n", duration);
	fmt.printf("Time per epoch: %.3f seconds\n", time.duration_seconds(duration) / 10.0);
	fmt.printf("Time per sample: %.6f seconds\n", time.duration_seconds(duration) / f64(dataset.sample_count * 10));
	fmt.printf("Samples processed: %d\n", dataset.sample_count * 10);
}
*/