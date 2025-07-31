package neural_network

import "core:testing"
import "core:fmt"
import "core:mem"
import "core:strings"

import "../utils"

@(test)
test_tokenizer_loading :: proc(t: ^testing.T) {

	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);

	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,
        
        {
    		// Test loading the tokenizer
    		tokenizer, ok := load_tokenizer(
    			"examples/tiny_model/vocab.json",
    			"examples/tiny_model/merges.txt", 
    			"examples/tiny_model/special_tokens_map.json"
    		)
    		defer destroy_tokenizer(tokenizer)
    		
    		testing.expect(t, ok, "Failed to load tokenizer")
    		testing.expect(t, len(tokenizer.vocab) > 0, "Vocabulary should not be empty")
    		testing.expect(t, len(tokenizer.merges) > 0, "Merges should not be empty")
    		testing.expect(t, len(tokenizer.special_tokens) > 0, "Special tokens should not be empty")
    		
    		// Check that endoftext token exists
    		eos_id, found := tokenizer.vocab[ENDOFTEXT_TOKEN]
    		testing.expect(t, found, "End of text token should exist in vocab")
    		testing.expect(t, eos_id == 0, "End of text token should have ID 0")
        }
	}

    utils.print_tracking_memory_results();
    utils.destroy_tracking_allocators();
}

@(test)
test_simple_tokenization :: proc(t: ^testing.T) {

	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);

	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,

		{
			tokenizer, ok := load_tokenizer(
				"examples/tiny_model/vocab.json",
				"examples/tiny_model/merges.txt",
				"examples/tiny_model/special_tokens_map.json"
			)
			defer destroy_tokenizer(tokenizer)
			
			testing.expect(t, ok, "Failed to load tokenizer")
			
			// Test simple tokenization
			text := "hello world"
			tokens := tokenize(tokenizer, text)
			defer delete(tokens)
			
			testing.expect(t, len(tokens) > 0, "Should produce some tokens")
			
			fmt.printf("Input: '%s'\n", text)
			fmt.printf("Tokens: %v\n", tokens)
			
			// Test decoding
			decoded := decode(tokenizer, tokens)
			defer delete(decoded)
			
			fmt.printf("Decoded: '%s'\n", decoded)
			// Note: decoded might not exactly match due to space handling, but should be similar
		}
	}

    utils.print_tracking_memory_results();
    utils.destroy_tracking_allocators();
}

@(test)
test_single_words :: proc(t: ^testing.T) {

	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);

	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,

		{
			tokenizer, ok := load_tokenizer(
				"examples/tiny_model/vocab.json", 
				"examples/tiny_model/merges.txt",
				"examples/tiny_model/special_tokens_map.json"
			)
			defer destroy_tokenizer(tokenizer)
			
			testing.expect(t, ok, "Failed to load tokenizer")
			
			// Test some words that should exist in vocab
			test_cases := []string{"the", "and", "is", "a"}
			
			for word in test_cases {
				tokens := tokenize(tokenizer, word)
				defer delete(tokens)
				
				testing.expectf(t, len(tokens) > 0, "Should tokenize '%s'", word)
				fmt.printf("'%s' -> %v\n", word, tokens)
			}
		}
	}

    utils.print_tracking_memory_results();
    utils.destroy_tracking_allocators();
}

@(test)
test_token_roundtrip :: proc(t: ^testing.T) {
	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);

	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker);

		{
			tokenizer, ok := load_tokenizer(
				"examples/tiny_model/vocab.json",
				"examples/tiny_model/merges.txt", 
				"examples/tiny_model/special_tokens_map.json"
			)
			defer destroy_tokenizer(tokenizer)
			
			testing.expect(t, ok, "Failed to load tokenizer")
			
			// Test cases for roundtrip conversion
			test_cases := []string{
				"hello world",
				"the quick brown fox",
				"this is a test",
				"a",
				"testing",
				"123",
				"hello",
				"world",
			}
			
			for test_text in test_cases {
				fmt.printf("\n--- Testing roundtrip for: '%s' ---\n", test_text)
				
				// Step 1: Convert text to tokens
				tokens := tokenize(tokenizer, test_text)
				defer delete(tokens)
				
				fmt.printf("Original text: '%s'\n", test_text)
				fmt.printf("Tokens: %v\n", tokens)
				
				// Step 2: Convert tokens back to text
				decoded_text := decode(tokenizer, tokens)
				defer delete(decoded_text)
				
				fmt.printf("Decoded text: '%s'\n", decoded_text)
				
				// Step 3: Verify roundtrip preserves the text
				// Note: We trim spaces for comparison as tokenizer may add/normalize spaces
				original_trimmed := strings.trim_space(test_text)
				decoded_trimmed := strings.trim_space(decoded_text)
				
				testing.expectf(t, original_trimmed == decoded_trimmed, 
					"Roundtrip failed for '%s': got '%s'", test_text, decoded_text)
				
				if original_trimmed == decoded_trimmed {
					fmt.printf("✓ Roundtrip successful!\n")
				} else {
					fmt.printf("✗ Roundtrip failed!\n")
				}
			}
		}
	}

    utils.print_tracking_memory_results();
    utils.destroy_tracking_allocators();
}

@(test)
test_empty_and_edge_cases :: proc(t: ^testing.T) {


	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);

	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,

		{
			tokenizer, ok := load_tokenizer("examples/tiny_model/vocab.json", "examples/tiny_model/merges.txt", "examples/tiny_model/special_tokens_map.json")
			defer destroy_tokenizer(tokenizer)
			
			testing.expect(t, ok, "Failed to load tokenizer")
			
			// Test empty string
			empty_tokens := tokenize(tokenizer, "")
			testing.expect(t, len(empty_tokens) == 0, "Empty string should produce no tokens")
			
			// Test single character
			single_tokens := tokenize(tokenizer, "a")
			defer delete(single_tokens)
			testing.expect(t, len(single_tokens) > 0, "Single character should produce tokens")
			
			fmt.printf("Single 'a' -> %v\n", single_tokens)
		}
	}

    utils.print_tracking_memory_results();
    utils.destroy_tracking_allocators();
}

@(test)
test_parquet_dataset_loading :: proc(t: ^testing.T) {
    context.logger = utils.create_console_logger(.Debug);
    defer utils.destroy_console_logger(context.logger);

    context.assertion_failure_proc = utils.init_stack_trace();
    defer utils.destroy_stack_trace();
    
    utils.init_tracking_allocators();
    
    {
        tracker : ^mem.Tracking_Allocator;
        context.allocator = utils.make_tracking_allocator(tracker_res = &tracker);
        
        {
            // Test loading MNIST parquet file
            mnist_path := "C:/Users/jakob/Datasets/mnist/mnist/mnist/train-00000-of-00001.parquet"
            
            // Load a small subset for testing
            config := Dataset_Config{
                feature_columns = {},  // Auto-detect features
                label_column = "label", // Assuming MNIST has a 'label' column
                normalize_features = true,
                skip_header = false,
                max_samples = 100, // Load only first 100 samples for testing
            }
            
            data, err := load_parquet_dataset(mnist_path, config)
			defer destroy_dataset(data)
            
			if err != .None {
				#partial switch err {
					case .Database_Open_Failed:
						fmt.printf("⚠ DuckDB failed to open (may not be installed)\n")
						testing.expect(t, false, "DuckDB database failed to open")
					case .Query_Failed:
						fmt.printf("⚠ Query failed - file may not exist or be malformed\n")
						// Don't fail the test if file doesn't exist, just warn
						fmt.printf("Note: Ensure MNIST parquet file exists at: %s\n", mnist_path)
					case .No_Data:
						testing.expect(t, false, "No data found in parquet file")
					case .Invalid_Schema:
						testing.expect(t, false, "Invalid schema in parquet file")
					case .Memory_Allocation_Failed:
						testing.expect(t, false, "Memory allocation failed")
					case .Invalid_Configuration:
						testing.expect(t, false, "Invalid configuration")
					case:
						testing.expect(t, false, "Unknown error loading dataset")
				}
			}
            
            testing.expect(t, data.sample_count > 0, "Dataset should have samples")
            testing.expect(t, data.feature_count > 0, "Dataset should have features")
            testing.expect(t, len(data.feature_names) == data.feature_count, "Feature names should match feature count")
            testing.expect(t, len(data.labels) == data.sample_count, "Labels should match sample count")
            
            fmt.printf("✓ Successfully loaded MNIST dataset\n")
            print_dataset_info(data)
            
            // Test normalization - features should be in [0,1] range
            if config.normalize_features {
                for row_idx in 0..<min(data.sample_count, 10) {
                    for feat_idx in 0..<min(data.feature_count, 10) {
                        val := utils.matrix_get(data.features, feat_idx, row_idx)
                        testing.expect(t, val >= 0.0 && val <= 1.0, "Normalized features should be in [0,1] range")
                    }
                }
                fmt.printf("✓ Feature normalization verified\n")
            }
            
            // Test dataset subset functionality
            if data.sample_count >= 20 {
                subset, subset_ok := dataset_subset(data, 10, 10)
                defer destroy_dataset(subset)
                
                testing.expect(t, subset_ok, "Dataset subset should succeed")
                testing.expect(t, subset.sample_count == 10, "Subset should have 10 samples")
                testing.expect(t, subset.feature_count == data.feature_count, "Subset should have same feature count")
                
                fmt.printf("✓ Dataset subset functionality verified\n")
            }
             
            
            // Test with a simple CSV-like dataset if MNIST fails
            // This ensures the basic functionality works even without the specific MNIST file
            fmt.printf("\n--- Testing with basic CSV data ---\n")
            
            // Create a simple test parquet file in memory (this would require more setup)
            // For now, just test the data structures
            test_dataset, test_ok := init_dataset(5, 3)
            defer destroy_dataset(test_dataset)
            
            testing.expect(t, test_ok, "Test dataset initialization should succeed")
            testing.expect(t, test_dataset.sample_count == 5, "Test dataset should have 5 samples")
            testing.expect(t, test_dataset.feature_count == 3, "Test dataset should have 3 features")
            
            // Fill with test data
            for i in 0..<test_dataset.sample_count {
                for j in 0..<test_dataset.feature_count {
                    utils.matrix_set(test_dataset.features, j, i, Float(i * j))
                }
                test_dataset.labels[i] = Float(i)
            }
            
            fmt.printf("✓ Basic dataset operations verified\n")
        }
    }

    utils.print_tracking_memory_results();
    utils.destroy_tracking_allocators();
}

