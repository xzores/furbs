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
				loss := nn.calculate_loss(prediction, awnser, .MSE);
				
				nn.backprop_feedforward(ff, activations, awnser, .MSE, learning_rate);
				
				if i %% 500 == 0 {
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

entry :: proc () {
	
	config := nn.Dataset_Config{
		max_samples = 1000,
	};
	
	dataset, err := nn.load_parquet_dataset("C:/Users/jakob/Datasets/mnist/mnist/mnist/train-00000-of-00001.parquet", config);
	assert(err == .None, "Failed to load dataset");
	defer nn.destroy_dataset(dataset);

	log.infof("dataset: %#v", dataset);
	
	ff := nn.make_feedforward(dataset.feature_count, 10, {2, 2}, {}, nn.Activation_function.sigmoid);
	defer nn.destroy_feedforward(ff);
	
	batch_size := 16;
	epochs := 10;
	learning_rate : f32 = 0.01;
	
	start_time := time.now();
	
	//training
	{
		// Convert dataset to one-hot labels
		labels := nn.dataset_labels_to_one_hot(dataset, 10);
		defer nn.destroy_one_hot_labels(labels);
		
		// Create batch data from dataset
		batch_input, batch_answers := nn.create_batches_from_dataset(dataset, labels, batch_size);
		defer nn.destroy_batch_data(batch_input, batch_answers);
		
		fmt.printf("batch_input length: %d, the dimensions are %v\n", len(batch_input), batch_input[0].dims);
		fmt.printf("batch_answers length: %d\n", len(batch_answers));
		if len(batch_input) > 0 {
			fmt.printf("batch_input[0] shape: %v\n", batch_input[0].dims);
			fmt.printf("batch_answers[0] shape: %v\n", batch_answers[0].dims);
		}

		//Activations is defined out here so that the memory can be reused for each epoch/batch
		//TODO cant handle last batch then

		// For each epoch
		for epoch := 0; epoch < epochs; epoch += 1 {
			fmt.printf("Epoch %d/%d\n", epoch + 1, epochs);
			
			// Process inputs in batches
			for input, i in batch_input {
				activations := nn.init_batch_activations(ff, input.dims[0]);
				defer nn.destroy_feedforward_batch_activations(activations);
		
				// Forward pass the entire batch through the architecture
				nn.feedforward_batch_activations(ff, activations, input);
				
				//This is a single tensor which stores all the predictions.
				answers : nn.Tensor = batch_answers[i];
				
				//A tensor used like an array to store all the predictions the models made
				predictions : nn.Tensor = nn.get_batch_prediction(activations);

				//Calcuate the loss, the output is a tensor used like an array of Tensors (like []Tensor, but easier to operate on)
				loss := nn.calculate_loss_tensor(predictions, answers, .MSE);
				
				//Now give the activations (A tensor used like an array) and the answers (A tensor used like an array) and update the activations.
				//This will update all the weights and biases of the entire network.
				nn.backprop_feedforward_batch(ff, activations, answers, .MSE, learning_rate);
				
				// Print progress every 10 batches
				if i %% 1000 == 0 {
					fmt.printf("=== DEBUG: Batch %d ===\n", i);
					pred_slice := utils.tensor_get_sub_vector(predictions, {0});
					answer_slice := utils.tensor_get_sub_vector(answers, {0});
					fmt.printf("Expected: %v\n", answer_slice);
					fmt.printf("Predicted: %v\n", pred_slice);
					fmt.printf("Loss: %.6f\n", loss);
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
			if i %% 10000 == 0 && i > 0 {
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
	total_samples := dataset.sample_count;

	fmt.printf("\n=== BATCH TRAINING TIME ===\n");
	fmt.printf("Total time: %v\n", duration);
	fmt.printf("Time per epoch: %.3f seconds\n", time.duration_seconds(duration) / f64(epochs));
	fmt.printf("Time per sample: %.6f seconds\n", time.duration_seconds(duration) / f64(total_samples * epochs));
	fmt.printf("Samples processed: %d\n", total_samples * epochs);
	fmt.printf("Batch size: %d\n", batch_size);
}