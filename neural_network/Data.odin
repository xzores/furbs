package neural_network

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strconv"
import "core:strings"
import "core:slice"

import "../utils"
import duckdb "../duckdb-odin"

// Dataset structure to hold training data
Dataset :: struct {
    features: Matrix `fmt:"-"`,           // Input features (rows = samples, cols = features)
    labels: []Float `fmt:"-"`,           // Target labels
    feature_names: []string,   // Names of feature columns
    sample_count: int,         // Number of samples
    feature_count: int,        // Number of features
}

// Configuration for loading datasets
Dataset_Config :: struct {
    feature_columns: []string, // Column names to use as features (empty = auto-detect)
    label_column: string,      // Column name for labels
    normalize_features: bool,   // Whether to normalize features to [0,1]
    skip_header: bool,         // Whether to skip header row
    max_samples: int,          // Maximum number of samples to load (0 = all)
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
    labels_result := make([]Float, sample_count, allocator)
    if labels_result == nil {
        utils.matrix_destroy(dataset.features)
        return {}, false
    }
    dataset.labels = labels_result
    
    // Allocate feature names
    names_result := make([]string, feature_count, allocator)
    if names_result == nil {
        utils.matrix_destroy(dataset.features)
        delete(dataset.labels)
        return {}, false
    }
    dataset.feature_names = names_result
    
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
    
    dataset^ = {}
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
    
    // Build query to read parquet file
    query_builder := strings.builder_make(allocator)
    defer strings.builder_destroy(&query_builder)
    
    strings.write_string(&query_builder, "SELECT * FROM read_parquet('")
    strings.write_string(&query_builder, filepath)
    strings.write_string(&query_builder, "')")
    
    if config.max_samples > 0 {
        strings.write_string(&query_builder, " LIMIT ")
        strings.write_string(&query_builder, fmt.tprintf("%d", config.max_samples))
    }
    
    query_str := strings.to_string(query_builder)
    
    // Execute query
    if duckdb.query(con, strings.clone_to_cstring(query_str, context.temp_allocator), &result) == .DuckDBError {
        error_msg := duckdb.result_error(&result)
        log.errorf("Failed to execute query: %s", error_msg)
        return {}, Dataset_Error.Query_Failed
    }
    
    // Get result dimensions
    row_count := int(duckdb.row_count(&result))
    col_count := int(duckdb.column_count(&result))
    
    if row_count == 0 {
        log.error("No data found in parquet file")
        return {}, Dataset_Error.No_Data
    }
    
    if col_count == 0 {
        log.error("No columns found in parquet file")
        return {}, Dataset_Error.Invalid_Schema
    }
    
    // Determine feature and label columns
    feature_col_indices: [dynamic]int
    label_col_index := -1
    
    defer delete(feature_col_indices)
    
    for col_idx in 0..<col_count {
        col_name := duckdb.column_name(&result, duckdb.idx_t(col_idx))
        col_name_str := string(col_name)
        
        // Check if this column is the label column
        if config.label_column != "" && col_name_str == config.label_column {
            label_col_index = col_idx
            continue
        }
        
        // Check if this column should be included as a feature
        if len(config.feature_columns) > 0 {
            // Use specified feature columns
            for feature_name in config.feature_columns {
                if col_name_str == feature_name {
                    append(&feature_col_indices, col_idx)
                    break
                }
            }
        } else {
            // Auto-detect: include all columns except label column
            if config.label_column == "" || col_name_str != config.label_column {
                append(&feature_col_indices, col_idx)
            }
        }
    }
    
    feature_count := len(feature_col_indices)
    if feature_count == 0 {
        log.error("No feature columns found")
        return {}, Dataset_Error.Invalid_Configuration
    }
    
    // Initialize dataset
    dataset, init_ok := init_dataset(row_count, feature_count, allocator)
    if !init_ok {
        log.error("Failed to initialize dataset")
        return {}, Dataset_Error.Memory_Allocation_Failed
    }
    
    // Fill feature names
    for i, col_idx in feature_col_indices {
        col_name := duckdb.column_name(&result, duckdb.idx_t(col_idx))
        dataset.feature_names[i] = strings.clone(string(col_name), allocator)
    }
    
    // Load data
    for row_idx in 0..<row_count {
        // Load features
        for feat_idx, col_idx in feature_col_indices {
            value := duckdb.value_double(&result, duckdb.idx_t(col_idx), duckdb.idx_t(row_idx))
            utils.matrix_set(dataset.features, feat_idx, row_idx, Float(value))
        }
        
        // Load label (if specified)
        if label_col_index >= 0 {
            label_value := duckdb.value_double(&result, duckdb.idx_t(label_col_index), duckdb.idx_t(row_idx))
            dataset.labels[row_idx] = Float(label_value)
        }
    }
    
    // Normalize features if requested
    if config.normalize_features {
        normalize_dataset_features(dataset)
    }
    
    log.infof("Successfully loaded dataset: %d samples, %d features", dataset.sample_count, dataset.feature_count)
    
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

// Print dataset information
print_dataset_info :: proc(dataset: ^Dataset) {
    fmt.printf("Dataset Info:\n")
    fmt.printf("  Samples: %d\n", dataset.sample_count)
    fmt.printf("  Features: %d\n", dataset.feature_count)
    fmt.printf("  Feature names: %v\n", dataset.feature_names)
    
    if dataset.sample_count > 0 && dataset.feature_count > 0 {
        fmt.printf("  Sample data (first row):\n")
        fmt.printf("    Features: ")
        for feat_idx in 0..<min(dataset.feature_count, 5) {
            val := utils.matrix_get(dataset.features, feat_idx, 0)
            fmt.printf("%.3f ", val)
        }
        if dataset.feature_count > 5 {
            fmt.printf("... ")
        }
        fmt.printf("\n")
        fmt.printf("    Label: %.3f\n", dataset.labels[0])
    }
}