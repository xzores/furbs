package neural_network

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strconv"
import "core:strings"
import "core:slice"
import "core:bytes"
import "core:image"
import "core:image/png"

import "../utils"
import duckdb "../duckdb-odin"

// Dataset structure to hold training data
Dataset :: struct {
	features: Matrix `fmt:"-"`,		   // Input features (rows = samples, cols = features)
	labels: []Float `fmt:"-"`,		   // Target labels
	feature_names: []string `fmt:"-"`,   // Names of feature columns
    sample_count: int,	
    feature_count: int,
}

// Configuration for loading datasets
Dataset_Config :: struct {
	feature_columns: []string, // Column names to use as features (empty = auto-detect)
	label_column: string,	  // Column name for labels
	normalize_features: bool,   // Whether to normalize features to [0,1]
	skip_header: bool,		 // Whether to skip header row
	max_samples: int,		  // Maximum number of samples to load (0 = all)
}

// Default configuration
DEFAULT_DATASET_CONFIG :: Dataset_Config{
	feature_columns = {},
	label_column = "",
	normalize_features = false,
	skip_header = true,
	max_samples = 0,
}

// Error types for dataset loading
Dataset_Error :: enum {
	None,
	Database_Open_Failed,
	Database_Connect_Failed,
	Query_Failed,
	No_Data,
	Invalid_Schema,
	Memory_Allocation_Failed,
	Invalid_Configuration,
	PNG_Decode_Failed,
}

// Helper function to decode PNG data to grayscale values for MNIST
@(require_results)
decode_png_to_grayscale :: proc(png_data: []u8, allocator := context.allocator) -> (pixels: []Float, ok: bool) {
	options := image.Options{
		.alpha_add_if_missing,
	}
	
	img, err := png.load_from_bytes(png_data, options)
	defer image.destroy(img)
	
	if err != nil {
		log.errorf("Failed to decode PNG: %v", err)
		return {}, false
	}
	
	// Ensure it's the expected MNIST size (28x28)
	if img.width != 28 || img.height != 28 {
		log.errorf("Expected 28x28 image, got %dx%d", img.width, img.height)
		return {}, false
	}
	
	raw_data := bytes.buffer_to_bytes(&img.pixels)
	pixel_count := 784  // 28 * 28
	pixels = make([]Float, pixel_count, allocator)
	
	// Convert to grayscale and normalize to [0,1]
	switch img.channels {
	case 1: // Already grayscale
		for i in 0..<pixel_count {
			pixels[i] = Float(raw_data[i]) / 255.0
		}
	case 3: // RGB - convert to grayscale
		for i in 0..<pixel_count {
			r := Float(raw_data[i*3 + 0])
			g := Float(raw_data[i*3 + 1])
			b := Float(raw_data[i*3 + 2])
			// Standard RGB to grayscale conversion
			gray := (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
			pixels[i] = gray
		}
	case 4: // RGBA - convert to grayscale, ignore alpha
		for i in 0..<pixel_count {
			r := Float(raw_data[i*4 + 0])
			g := Float(raw_data[i*4 + 1])
			b := Float(raw_data[i*4 + 2])
			// Standard RGB to grayscale conversion
			gray := (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
			pixels[i] = gray
		}
	case:
		log.errorf("Unsupported channel count: %d", img.channels)
		return {}, false
	}
	
	return pixels, true
}

// Initialize a dataset with given dimensions
@(require_results)
init_dataset :: proc(sample_count, feature_count: int, allocator := context.allocator) -> (^Dataset, bool) {
	dataset := new(Dataset);

	dataset^ = Dataset{
        sample_count = sample_count,
        feature_count = feature_count,
    }
    

	// Allocate features matrix
	dataset.features = utils.matrix_make(sample_count, feature_count, Weight)
	
	// Allocate labels
	dataset.labels = make([]Float, sample_count, allocator)
	
	// Allocate feature names
	dataset.feature_names = make([]string, feature_count, allocator)
	
	return dataset, true
}

// Destroy a dataset and free its memory
destroy_dataset :: proc(dataset: ^Dataset) {
	if dataset == nil do return
	
	utils.matrix_destroy(dataset.features)
	delete(dataset.labels)
	
	for name in dataset.feature_names {
		delete(name)
	}
	delete(dataset.feature_names)
	free(dataset)
}
	
// Load dataset from Parquet file using DuckDB
@(require_results)
load_parquet_dataset :: proc(filepath: string, config := DEFAULT_DATASET_CONFIG, allocator := context.allocator) -> (^Dataset, Dataset_Error) {
	// Initialize DuckDB
	db: duckdb.duckdb_database
	con: duckdb.duckdb_connection
	result: duckdb.duckdb_result
	
	defer {
		duckdb.disconnect(&con)
		duckdb.destroy_result(&result)
		duckdb.close(&db)
	}
	
	// Open database (in-memory)
	if duckdb.open(nil, &db) == .DuckDBError {
		log.error("Failed to open DuckDB database")
		return {}, Dataset_Error.Database_Open_Failed
	}
	
	// Connect to database
	if duckdb.connect(db, &con) == .DuckDBError {
		log.error("Failed to connect to DuckDB database")
		return {}, Dataset_Error.Database_Connect_Failed
	}
	
	// Build query to read parquet file - get all data
	query_builder := strings.builder_make(allocator)
	defer strings.builder_destroy(&query_builder)
	
	// The image column is STRUCT(bytes BLOB, path VARCHAR) - extract the bytes
	strings.write_string(&query_builder, "SELECT image.bytes as image_bytes, label FROM read_parquet('")
	strings.write_string(&query_builder, filepath)
	strings.write_string(&query_builder, "')")
	
	// Apply max_samples limit if specified
	if config.max_samples > 0 {
		strings.write_string(&query_builder, " LIMIT ")
		strings.write_int(&query_builder, config.max_samples)
	}
	
	query_str := strings.to_cstring(&query_builder)

	// Execute query
	if duckdb.query(con, query_str, &result) == .DuckDBError {
		error_msg := duckdb.result_error(&result)
		log.errorf("Failed to execute query: %s", error_msg)
		return {}, Dataset_Error.Query_Failed
	}
	
	// Get result dimensions
	row_count := int(duckdb.row_count(&result))
	
	if row_count == 0 {
		log.error("No data found in parquet file")
		return {}, Dataset_Error.No_Data
	}
	
	log.infof("Loading %d samples from %s", row_count, filepath)
	
	// Create dataset - MNIST has 784 features (28x28 pixels)
	feature_count := 784
	dataset, init_ok := init_dataset(row_count, feature_count, allocator)
	if !init_ok {
		log.error("Failed to initialize dataset")
		return {}, Dataset_Error.Memory_Allocation_Failed
	}
	
	// Set feature names (pixel_0, pixel_1, etc.)
	for i in 0..<feature_count {
		dataset.feature_names[i] = fmt.aprintf("pixel_%d", i, allocator = allocator)
	}
	
	// Load data row by row
	for row_idx in 0..<row_count {
		// Get PNG data
		blob_val := duckdb.value_blob(&result, 0, duckdb.idx_t(row_idx))  // image_bytes column
		defer duckdb.free(blob_val.data)
		
		if blob_val.size == 0 {
			log.errorf("Empty image data at row %d", row_idx)
			destroy_dataset(dataset)
			return {}, Dataset_Error.Invalid_Schema
		}
		
		// Convert blob to slice
		png_data := slice.from_ptr(cast(^u8)blob_val.data, int(blob_val.size))
		
		// Decode PNG to grayscale pixel values
		pixels, decode_ok := decode_png_to_grayscale(png_data, context.temp_allocator)
		defer delete(pixels, context.temp_allocator)
		
		if !decode_ok {
			log.errorf("Failed to decode PNG at row %d", row_idx)
			destroy_dataset(dataset)
			return {}, Dataset_Error.PNG_Decode_Failed
		}
		
		// Copy pixel values to dataset features
		for feat_idx in 0..<feature_count {
			utils.matrix_set(dataset.features, feat_idx, row_idx, pixels[feat_idx])
		}
		
		// Get label
		label_value := duckdb.value_double(&result, 1, duckdb.idx_t(row_idx))  // label column
		dataset.labels[row_idx] = Float(label_value)
	}
	
	// Apply normalization if requested
	if config.normalize_features {
		normalize_dataset_features(dataset)
	}
	
	log.infof("Successfully loaded dataset with %d samples and %d features", 
			 dataset.sample_count, dataset.feature_count)
	
	return dataset, Dataset_Error.None
}

// Normalize features to [0,1] range
normalize_dataset_features :: proc(dataset: ^Dataset) {
	if dataset.feature_count == 0 || dataset.sample_count == 0 do return
	
	// Find min/max for each feature
	min_vals := make([]Float, dataset.feature_count, context.temp_allocator)
	max_vals := make([]Float, dataset.feature_count, context.temp_allocator)
	
	// Initialize with first row
	for feat_idx in 0..<dataset.feature_count {
		val := utils.matrix_get(dataset.features, feat_idx, 0)
		min_vals[feat_idx] = val
		max_vals[feat_idx] = val
	}
	
	// Find actual min/max
	for row_idx in 1..<dataset.sample_count {
		for feat_idx in 0..<dataset.feature_count {
			val := utils.matrix_get(dataset.features, feat_idx, row_idx)
			min_vals[feat_idx] = min(min_vals[feat_idx], val)
			max_vals[feat_idx] = max(max_vals[feat_idx], val)
		}
	}
	
	// Normalize each feature
	for row_idx in 0..<dataset.sample_count {
		for feat_idx in 0..<dataset.feature_count {
			val := utils.matrix_get(dataset.features, feat_idx, row_idx)
			range_val := max_vals[feat_idx] - min_vals[feat_idx]
			
			if range_val > 0 {
				normalized := (val - min_vals[feat_idx]) / range_val
				utils.matrix_set(dataset.features, feat_idx, row_idx, normalized)
			}
		}
	}
}

// Get a subset of the dataset (useful for train/test splits)
@(require_results)
dataset_subset :: proc(dataset: ^Dataset, start_idx, count: int, allocator := context.allocator) -> (^Dataset, bool) {
	if start_idx < 0 || start_idx >= dataset.sample_count do return {}, false
	if count <= 0 || start_idx + count > dataset.sample_count do return {}, false
	
	subset, init_ok := init_dataset(count, dataset.feature_count, allocator)
	if !init_ok do return {}, false
	
	// Copy feature names
	for i in 0..<dataset.feature_count {
		subset.feature_names[i] = strings.clone(dataset.feature_names[i], allocator)
	}
	
	// Copy data
	for i in 0..<count {
		src_row := start_idx + i
		
		// Copy features
		for feat_idx in 0..<dataset.feature_count {
			val := utils.matrix_get(dataset.features, feat_idx, src_row)
			utils.matrix_set(subset.features, feat_idx, i, val)
		}
		
		// Copy label
		subset.labels[i] = dataset.labels[src_row]
	}
	
	return subset, true
}

// Print an image as ASCII art
// pixels: 1D array of pixel values (0.0-1.0)
// width, height: dimensions of the image
// title: optional title to display above the image
print_ascii_image :: proc(pixels: []Float, width, height: int, title: string = "") {
	if len(pixels) != width * height {
		fmt.printf("Error: pixel count (%d) doesn't match dimensions (%dx%d)\n", len(pixels), width, height)
		return
	}
	
	if title != "" {
		fmt.printf("%s:\n", title)
	}
	
	for row in 0..<height {
		fmt.printf("  ");
		for col in 0..<width {
			pixel_idx := row * width + col
			val := pixels[pixel_idx]
			
			// Convert to ASCII art based on intensity
			if val > 0.8 {
				fmt.printf("#");  // Very bright
			} else if val > 0.6 {
				fmt.printf("@");  // Bright
			} else if val > 0.4 {
				fmt.printf("%%");  // Medium bright
			} else if val > 0.2 {
				fmt.printf("+");  // Medium
			} else if val > 0.1 {
				fmt.printf(".");  // Dim
			} else {
				fmt.printf(" ");  // Very dim/black
			}
		}
		fmt.printf("\n");
	}
}

// Convert a single value to one-hot encoding
// value: the value to encode (e.g., digit 0-9)
// num_classes: total number of classes (e.g., 10 for digits 0-9)
// allocator: memory allocator to use
@(require_results)
one_hot_encode :: proc(value: Float, num_classes: int, allocator := context.allocator) -> []Float {
	encoded := make([]Float, num_classes, allocator)
	
	// Initialize all to 0
	for i in 0..<num_classes {
		encoded[i] = 0.0
	}
	
	// Set the target class to 1
	class_idx := int(value)
	if class_idx >= 0 && class_idx < num_classes {
		encoded[class_idx] = 1.0
	}
	
	return encoded
}

// Convert a dataset's labels to one-hot encoded format
// dataset: the dataset containing labels
// num_classes: total number of classes (e.g., 10 for digits 0-9)
// allocator: memory allocator to use
@(require_results)
dataset_labels_to_one_hot :: proc(dataset: ^Dataset, num_classes: int, allocator := context.allocator) -> [][]Float {
	one_hot_labels := make([][]Float, dataset.sample_count, allocator)
	
	for i in 0..<dataset.sample_count {
		one_hot_labels[i] = one_hot_encode(dataset.labels[i], num_classes, allocator)
	}
	
	return one_hot_labels
}

destroy_one_hot_labels :: proc(one_hot_labels: [][]Float) {
	for l in one_hot_labels {
		delete(l);
	}
	delete(one_hot_labels);
}

// Convert one-hot encoded vector back to class index
// one_hot: the one-hot encoded vector
@(require_results)
one_hot_decode :: proc(one_hot: []Float) -> int {
	max_idx := 0
	max_val := one_hot[0]
	
	for i in 1..<len(one_hot) {
		if one_hot[i] > max_val {
			max_val = one_hot[i]
			max_idx = i
		}
	}
	
	return max_idx
}
