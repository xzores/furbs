package utils;

import "base:intrinsics"

import "core:fmt"
import "core:math"
import "core:slice"

AUTO_REGISITER_UTILS_MATRIX	:: #config(AUTO_REGISISTER_UTILS_MATRIX, true);

Matrix :: struct(T : typeid) where intrinsics.type_is_numeric(T) {
	// Matrix dimensions
	rows : int,
	columns : int,
	data : []T, // Flattened 2D matrix
}

matrix_make :: proc (rows : int, columns : int, $t : typeid) -> Matrix(t) {
	return Matrix(t){rows, columns, make([]t, rows * columns)};
}

matrix_destroy :: proc (m : Matrix($T)) {
	delete(m.data);
}



when AUTO_REGISITER_UTILS_MATRIX {

	_formatters : map[typeid]fmt.User_Formatter;
	@(init,private="file")
	auto_reg_utils_mats :: proc () {
		
		if fmt._user_formatters == nil {
			fmt.set_user_formatters(&_formatters);
		}
		
		matrix_set_formatter(f16);
		matrix_set_formatter(f32);
		matrix_set_formatter(f64);
		
		matrix_set_formatter(i8);
		matrix_set_formatter(i16);
		matrix_set_formatter(i32);
		matrix_set_formatter(i64);
		matrix_set_formatter(int);
	}
}

matrix_set_formatter :: proc($t : typeid){

	_matrix_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
		
		m := arg.(Matrix(t))
		fmt.wprintf(fi.writer, "[\n")
		fmt.wprintf(fi.writer, "\tcolumns: %i\n", m.columns)
		fmt.wprintf(fi.writer, "\trows: %i\n", m.rows)
		fmt.wprintf(fi.writer, "\tdata:\n")

		for r := 0; r < m.rows; r+=1 {
			row := matrix_get_row_values(&m, r)

			fmt.wprintf(fi.writer, "\t%v\n", row)
		}
		fmt.wprintf(fi.writer, "]\n")

		return true;
	}
	
	fmt.register_user_formatter(Matrix(t), _matrix_formatter);
}

///////////////////////////// Indexing, columns and rows /////////////////////////////

matrix_set_column_values :: #force_inline proc (m : ^Matrix($T), column : int, values : []T) {

	for c := 0; c < m.rows; c += 1 {
		m.data[c * m.columns + (column)] = values[c];
	}
}

matrix_set_row_values :: #force_inline proc (m : ^Matrix($T), row : int, values : []T) {

	assert(len(values) == m.columns);

	for r := 0; r < len(values); r += 1 {
		m.data[m.columns * (row) + r] = values[r];
	}
}

matrix_get_row_values :: #force_inline proc(m : ^Matrix($T), n : int) -> []T {

	return m.data[n * m.columns : n * m.columns + m.columns];
}

matrix_add_column :: #force_inline proc (m : ^Matrix($T), column : []T) {

	old_columns := m.columns
	old_rows := m.rows
	old_data := m.data
	defer delete(old_data)

	m.columns += 1
	m.data = make([]T, m.columns * m.rows)

	for c := 0; c < old_columns; c += 1 {
		for r := 0; r < old_rows; r += 1 {
			
			v : T = get_array(old_data[:], old_columns, old_rows, c, r);
			set_array_xy(m.data[:], v, m.columns,  m.rows, c, r);
		}
	}
	
	matrix_set_column(m, m.columns - 1, column);
}

matrix_add_row :: #force_inline proc (m : ^Matrix($T), row : []T) {

	old_columns := m.columns;
	old_rows := m.rows;
	old_data := m.data;
	defer delete(old_data)

	m.rows += 1;
	m.data = make([]T, m.columns * m.rows)

	for c := 0; c < old_columns; c += 1 {
		for r := 0; r < old_rows; r += 1 {
			
			v : T = get_array(old_data[:], old_columns, old_rows, c, r);
			set_array_xy(m.data[:], v, m.columns,  m.rows, c, r);
		}
	}

	matrix_set_row(m, m.rows - 1, row);
}

matrix_get :: #force_inline proc (m : ^Matrix($T), c : int, r : int) -> T {
	return #force_inline get_array(m.data, m.columns, m.rows, c, r)
}

matrix_set :: #force_inline proc (m : ^Matrix($T), c : int, r : int, value : T) {
	#force_inline set_array_xy(m.data, value, m.columns, m.rows, c, r);
}

///////////////////////////// Linear algebra, multiplication and vectors /////////////////////////////

matrix_mul :: #force_inline proc(A, B : Matrix($T), loc := #caller_location) -> Matrix(T) {
	// Ensure the matrices can be multiplied (A.columns == B.rows)
	if A.columns != B.rows {
		panic("Matrix dimensions do not align for multiplication.");
	}

	// Initialize result matrix
	result := Matrix(T) {
		rows = A.rows,
		columns = B.columns,
		data = make([]T, A.rows * B.columns, loc = loc), // Flattened 2D matrix with zeros, as Odin is zero-init
	};

	// Perform matrix multiplication
	for i in 0 ..< A.rows {
		for j in 0 ..< B.columns {
			sum : T;
			
			for k in 0 ..< A.columns {
				// Access elements in flattened arrays
				a_elem := A.data[i * A.columns + k];
				b_elem := B.data[k * B.columns + j];
				sum += a_elem * b_elem;
			}
			result.data[i * B.columns + j] = sum;
		}
	}

	return result;
}

matrix_vec_mul :: #force_inline proc(A : Matrix($T), B : []T, loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	// Ensure the matrix and vector can be multiplied (A.columns == length(B))
	if A.columns != len(B) {
		fmt.panicf("Matrix and vector dimensions do not align for multiplication, Matrix : (%v, %v). The vector has length %v and the matrix has %v columbs", A.rows, A.columns, len(B), A.columns);
	}

	// Initialize result vector
	result := make([]T, A.rows, loc = loc);

	// Perform matrix-vector multiplication
	for i in 0 ..< A.rows {
		sum : T;
		
		for j in 0 ..< A.columns {
			// Access elements in flattened arrays
			a_elem := A.data[i * A.columns + j];
			b_elem := B[j];
			sum += a_elem * b_elem;
		}
		result[i] = sum;
	}

	return result;
}

vec_matrix_mul :: #force_inline proc(B : []$T, A : Matrix(T), loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	// Ensure the vector and matrix can be multiplied (len(B) == A.rows)
	if len(B) != A.rows {
		fmt.panicf("Vector and matrix dimensions do not align for multiplication, Matrix : (%v, %v). The vector has length %v and the matrix has %v rows", A.rows, A.columns, len(B), A.rows);
	}

	// Initialize result vector
	result := make([]T, A.columns, loc);

	// Perform vector-matrix multiplication
	for j in 0 ..< A.columns {
		sum : T;
		
		for i in 0 ..< A.rows {
			// Access elements in flattened arrays
			b_elem := B[i];
			a_elem := A.data[i * A.columns + j];
			sum += b_elem * a_elem;
		}
		result[j] = sum;
	}

	return result;
}

//This multiplies a columb vector with a row vector, the result from a jx1 and 1xi vector is a jxi matrix. 
vec_columb_vec_row_mul :: #force_inline proc(A, B : []$T, loc := #caller_location) -> Matrix(T) where intrinsics.type_is_numeric(T) {
	// Ensure both vectors are non-empty
	if len(A) == 0 || len(B) == 0 {
		panic("Vectors must be non-empty for multiplication.");
	}

	// Initialize result matrix
	result := Matrix(T) {
		rows = len(A),
		columns = len(B),
		data = make([]T, len(A) * len(B), loc=loc),
	};

	// Perform column-vector x row-vector multiplication
	for i in 0 ..< len(A) {
		for j in 0 ..< len(B) {
			result.data[i * len(B) + j] = A[i] * B[j];
		}
	}

	return result;
}

//This will first transpose the matrix a then multiply with the vector.
matrix_transposed_vec_mul :: #force_inline proc(col_vec : Matrix($T), row_vec : []T, loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	A := col_vec; B := row_vec;
	
	// Ensure the matrix and vector can be multiplied (A.rows == len(B) after transpose)
	if A.rows != len(B) {
		fmt.panicf("Matrix and vector dimensions do not align for multiplication after transpose, Matrix: (%v, %v). The vector has length %v and the matrix has %v rows", A.rows, A.columns, len(B), A.rows);
	}

	// Initialize result vector
	result := make([]T, A.columns, loc = loc);  // After transpose, we have A.columns rows

	// Perform transposed matrix-vector multiplication
	for j in 0 ..< A.columns { // Iterate over what will be rows after transpose
		sum : T;

		for i in 0 ..< A.rows { // Iterate over what will be columns after transpose
			// Access elements in flattened arrays as if the matrix were transposed
			a_elem := A.data[i * A.columns + j];
			b_elem := B[i];
			sum += a_elem * b_elem;
		}
		result[j] = sum;  // Result has A.columns elements (since A^T has A.columns rows)
	}

	return result;
}


mul :: proc {matrix_mul, matrix_vec_mul, vec_matrix_mul};



///////////////////////////// Solveing Equations /////////////////////////////

//amount_of_unknown is the amount of zero rows
//They must be placed in the front.
partial_elimination :: #force_inline proc (m : ^Matrix($T), external_terminals : int, $convert_signed_zero : bool) {
	using m;

	variables := min(m.rows, m.columns);

	for i := 0; i < external_terminals; i+=1 {
		ensure_number_in_row(m, i);
	}

	for i := external_terminals - 1; i < m.columns - 1; i+=1 {		   
		
		//find lowest row with an entry.
		for r := m.columns - 2; r > 0; r-=1 {
			if matrix_get(m, i, r) != 0 {
				elimination(m, i, r);
			}
		}
	}
	
	for i := external_terminals - 1; i < m.columns - 1; i+=1 {
		
		for j := 0; j < external_terminals; j+=1 {
			
			if matrix_get(m, i, j) != 0 {

				//find a non zero wire row.
				for r := external_terminals; r < external_terminals * 2; r+=1 {
					if matrix_get(m, i, r) != 0 {
						elimination(m, i, r);		 
					}   
				}		 
			} 
		}		   
	}
	
	for i := 0; i < external_terminals; i+=1 {
		normalize(m, i);
	}

	when convert_signed_zero {
		//remove -0, so they become 0, make it nicer to print
		for d,d_i in m.data {
			if d == 0 {
				m.data[d_i] = 0
			}
		}
	}
}

gaussian_elimination :: #force_inline proc (m : ^Matrix($T), convert_signed_zero : bool = true) {
	

	variables := min(m.rows, m.columns);

	for i := 0; i < variables; i+=1 {
		ensure_number_in_row(m, i);
		elimination(m, i, i);
	}

	for i := m.rows - 1; i > 0; i-=1 {
		elimination(m, i, i);
	}

	for i := 0; i < variables; i+=1 {
		normalize(m, i);
	}

	if convert_signed_zero {
		//remove -0, so they become 0, make it nicer to print
		for d,d_i in m.data {
			if d == 0 {
				m.data[d_i] = 0
			}
		}
	}
}

is_solution :: #force_inline proc(m : ^Matrix($T)) -> bool {

	for i := 0; i < min(m.rows, m.columns); i+=1 {
		
		if(matrix_get(m, i, i) != 1){
			return false;
		}
	}

	return true;
}

is_partial_solution :: #force_inline proc(m : ^Matrix($T), external_terminals : int) -> bool {

	for i := 0; i < external_terminals; i+=1 {
		
		if(matrix_get(m, i, i) != 1){
			return false;
		}

		for j := 2 * external_terminals; j < m.columns - 1; j+=1 {
			if matrix_get(m, j, i) != 0 {
				//fmt.printf("Not a solution at : %v, %v\n", j, i);
				return false;
			}
		}
	}
	
	return true;
}



///////////////////////////// PRIVATE /////////////////////////////

@(private="file")
get_array :: #force_inline proc (a : []$T, columns : int, rows : int, c : int, r : int) -> T {

	//fmt.println("%v %v %v %v %v", len(a), columns, rows, c, r)
	return a[c + r * columns];
}

@(private="file")
set_array_xy :: #force_inline proc (a : []$T, value : T, columns : int, rows : int, c : int, r : int) {

	a[c + r * columns] = value;
}

@(private="file")
normalize :: #force_inline proc(m : ^Matrix($T), n : int) {
	
	if(n >= m.columns){
		return
	}
	
	v := matrix_get(m, n, n);
	r := matrix_get_row_values(m, n);
	
	if(v == 0){
		return;
	}

	for value, index in r {
		r[index] = value / v;
		if(index == n){
			r[index] = 1;
		}
	}
}

@(private="file")
swap_rows :: #force_inline proc(m : ^Matrix($T), n : int, k : int){

	r1 := matrix_get_row_values(m, n)
	r2 := matrix_get_row_values(m, k)

	slice.swap_between(r1, r2)
}

@(private="file")
ensure_number_in_row :: #force_inline proc(m : ^Matrix($T), n : int) {
				
	if(n >= m.columns){
		return;
	}

	row := matrix_get_row_values(m, n);

	val : f64 = 1.0 / row[n];
	if(math.is_inf_f64(val) || math.is_nan(val)){
		row[n] = 0;
	}

	if row[n] != 0 {
		return;
	}

	for i := n + 1; i < m.rows; i+=1 {
		//swap with a row below
		swap_row := matrix_get_row_values(m, i);
		if swap_row[n] != 0 {
			swap_rows(m, n, i)
			break;
		}
	}
}

@(private="file")
elimination :: #force_inline proc(m : ^Matrix($T), column : int, row : int) {
		
	if matrix_get(m, column, row) == 0 {
		return;
	}
	
	for i := 0; i < m.rows; i+=1 {		   

		if(column >= m.columns){
			return;
		}

		v : T = matrix_get(m, column, i);
		if v != 0 && i != row {
			
			minuend : []T = matrix_get_row_values(m, i);
			subtrahend : []T = matrix_get_row_values(m, row);

			multiplier := minuend[column] / subtrahend[column];
			for min, index in minuend {
				minuend[index] = min - (subtrahend[index] * multiplier);
			}
			
			matrix_set(m, column, i, 0); //is this ok? we assume eliminate worked 100%
		}
	}
}
