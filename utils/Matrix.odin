package utils;

import "base:intrinsics"

import "core:log"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"

AUTO_REGISITER_UTILS_MATRIX	:: #config(AUTO_REGISISTER_UTILS_MATRIX, true);

Matrix :: struct(T : typeid) where intrinsics.type_is_numeric(T) {
	// Matrix dimensions
	rows : int,
	columns : int,
	data : []T, // Flattened 2D matrix
}

matrix_make :: proc (rows : int, columns : int, $t : typeid) -> Matrix(t) {
	return {rows, columns, make([]t, rows * columns)};
}

matrix_make_identity :: proc (rows : int, columns : int, $T : typeid) -> Matrix(T) {
	m := Matrix(T){rows, columns, make([]T, rows * columns)};
	
	for i in 0..<math.min(rows, columns) {
		matrix_set(m, i, i, 1);
	}
	
	return m;
}

matrix_destroy :: proc (m : Matrix($T)) {
	delete(m.data);
}


/*
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
			row := matrix_get_row_values(m, r)

			fmt.wprintf(fi.writer, "\t%v\n", row)
		}
		fmt.wprintf(fi.writer, "]\n")

		return true;
	}
	
	fmt.register_user_formatter(Matrix(t), _matrix_formatter);
}
*/















///////////////////////////// Indexing, columns and rows /////////////////////////////

matrix_set_column_values :: #force_inline proc (m : Matrix($T), column : int, values : []T) {

	for c := 0; c < m.rows; c += 1 {
		m.data[c * m.columns + (column)] = values[c];
	}
}

matrix_set_row_values :: #force_inline proc (m : Matrix($T), row : int, values : []T) {

	assert(len(values) == m.columns);

	for r := 0; r < len(values); r += 1 {
		m.data[m.columns * (row) + r] = values[r];
	}
}

matrix_get_row_values :: #force_inline proc(m : Matrix($T), n : int) -> []T {

	return m.data[n * m.columns : n * m.columns + m.columns];
}


matrix_get_columb_values_cloned :: proc (m : Matrix($T), n : int, alloc := context.allocator, loc := #caller_location) -> []T {
	
	col := make([]T, m.rows, alloc, loc = loc);
	
	for c := 0; c < m.rows; c += 1 {
		col[c] = m.data[c * m.columns + n];
	}
	
	return col;
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
	
	matrix_set_row_values(m^, m.rows - 1, row);
}

matrix_get :: #force_inline proc (m : Matrix($T), c : int, r : int) -> T {
	return #force_inline get_array(m.data, m.columns, m.rows, c, r)
}

matrix_set :: #force_inline proc (m : Matrix($T), c : int, r : int, value : T) {
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

matrix_subtract :: #force_inline proc(A, B : Matrix($T), loc := #caller_location) -> Matrix(T) {

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


//This will first transpose the matrix a then multiply with the vector.
matrix_transposed_clone :: #force_inline proc(mat : Matrix($T), loc := #caller_location) -> Matrix(T) where intrinsics.type_is_numeric(T) {
	
	mat_t := matrix_make(mat.columns, mat.rows, T);
		
	for c in 0..<mat.columns {
		for r in 0..<mat.rows {
			
			v := matrix_get(mat, c, r);
			matrix_set(mat_t, r, c, v);
		}
	}
	
	return mat_t;
}


matrix_reciprocal_clone  :: #force_inline proc(mat : Matrix($T), loc := #caller_location) -> Matrix(T) where intrinsics.type_is_numeric(T) {
	
	mat_t := matrix_make(mat.columns, mat.rows, T);
		
	for c in 0..<mat.columns {
		for r in 0..<mat.rows {
			v := matrix_get(mat, c, r);
			matrix_set(mat_t, c, r, 1/v);
		}
	}
	
	return mat_t;
}


matrix_clone  :: #force_inline proc(mat : Matrix($T), loc := #caller_location) -> Matrix(T) where intrinsics.type_is_numeric(T) {
	
	mat_t := matrix_make(mat.columns, mat.rows, T);
		
	for c in 0..<mat.columns {
		for r in 0..<mat.rows {
			v := matrix_get(mat, c, r);
			matrix_set(mat_t, c, r, v);
		}
	}
	
	return mat_t;
}


matrix_add_to_inplace :: #force_inline proc(A, B : Matrix($T), loc := #caller_location) where intrinsics.type_is_numeric(T) {
	
	assert(A.columns == B.columns, "Matrix does not have same dimensions", loc);
	assert(A.rows == B.rows, "Matrix does not have same dimensions", loc);
		
	for c in 0..<A.columns {
		for r in 0..<A.rows {
			a := matrix_get(A, c, r);
			b := matrix_get(B, c, r);
			matrix_set(A, c, r, a + b);
		}
	}
}


///////////////////////////// Vector stuff /////////////////////////////

dot :: proc (a : []$T, b : []T) -> T {
	// Ensure both vectors have the same length
	assert(len(a) == len(b), "Vectors must be of the same length for dot product.");

	sum : T = 0.0;
	
	// Perform the dot product calculation
	for i in 0..<len(a) {
		sum += a[i] * b[i]; // Add the product of corresponding elements
	}
	
	return sum;
}

// Normalize a vector in place (make it a unit vector)
normalize_inplace :: proc (vec : []$T) {
	len := length(vec);
	if len > 0 {
		for &v in vec {
			v /= len; // Scale each element by the vector's length
		}
	}
}

// Calculate the length (magnitude) of the vector
length :: proc (vec : []$T) -> T {
	sum_of_squares : T = 0.0;
	
	for i in 0..<len(vec) {
		sum_of_squares += vec[i] * vec[i]; // Sum of squares of the elements
	}
	
	return math.sqrt(sum_of_squares); // Return the square root of the sum
}


negate_inplace :: proc (vec : []$T) {
	for &v in vec {
		v = -v;
	}
}

normalized :: proc (vec : []$T) -> (norm : []T) {
	norm = slice.clone(vec);
	
	l := length(vec);
	for &e in norm {
		e = e / l;
	}
	
	return;
}








///////////////////////////// Solveing Equations /////////////////////////////

//amount_of_unknown is the amount of zero rows
//They must be placed in the front.
partial_elimination :: #force_inline proc (m : Matrix($T), convert_signed_zero : bool = true) {
	using m;

	variables := min(m.rows, m.columns);

	for i := 0; i < variables; i+=1 {
		ensure_number_in_row(m, i);
	}

	for i := variables - 1; i < m.columns - 1; i+=1 {		   
		
		//find lowest row with an entry.
		for r := m.columns - 2; r > 0; r-=1 {
			if matrix_get(m, i, r) != 0 {
				elimination(m, i, r);
			}
		}
	}
	
	for i := variables - 1; i < m.columns - 1; i+=1 {
		
		for j := 0; j < variables; j+=1 {
			
			if matrix_get(m, i, j) != 0 {

				//find a non zero wire row.
				for r := variables; r < variables * 2; r+=1 {
					if matrix_get(m, i, r) != 0 {
						elimination(m, i, r);		 
					}   
				}		 
			} 
		}		   
	}
	
	for i := 0; i < variables; i+=1 {
		normalize(m, i);
	}

	if convert_signed_zero {
		//remove -0, so they become 0, make it nicer to print
		for d,d_i in m.data {
			if is_entry_zero(d) {
				m.data[d_i] = 0
			}
		}
	}
}

gaussian_elimination :: #force_inline proc (m : Matrix($T), convert_signed_zero : bool = true) {
	
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
			if is_entry_zero(d) {
				m.data[d_i] = 0
			}
		}
	}
}

is_solution :: #force_inline proc(m : Matrix($T)) -> bool {

	for i := 0; i < min(m.rows, m.columns); i+=1 {
		
		if(matrix_get(m, i, i) != 1){
			return false;
		}
	}

	return true;
}

is_partial_solution :: #force_inline proc(m : Matrix($T), external_terminals : int) -> bool {

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

gaussian_elimination2 :: proc(m : Matrix($T), convert_signed_zero : bool = false) {
	
	row_normalize :: proc(row : []$T, index : int) {

		divisor := row[index];

		for &e in row {
			e /= divisor;
		}
		row[index] = 1;
	}

	// minuend - subtrahend
	// Index specifies the entry that will be eliminated (set to zero)
	row_replacement :: proc(minuend, subtrahend : []$T, index : int) {

		multiplier := minuend[index] / subtrahend[index];

		for &e, i in minuend {
			e -= subtrahend[i] * multiplier;
		}
		minuend[index] = 0;
	}

	solved := true; //TODO, should we use?
	
	rows := make([][]T, m.rows);
	
	//Creates a 2d array to make it easier to iterate through.
	for &row, i in rows {
		row = m.data[i * m.columns:(i + 1) * m.columns]
		assert(len(row) == m.columns);
	}
	
	//Iterates down through each row, eliminating non-zero's entries below
	//This creates a zero lower trangle, and normalizes the [n,n] to 1
	for n in 0..<m.rows {

		if is_entry_zero(rows[n][n]) {
			found : bool = false;
			for r in rows[n+1:] {
				if r[n] != 0 {
					slice.swap_between(r, rows[n])
					found = true;
					break;
				}
			}
			if !found {
				solved = false;
			}
		} 
		
		row_normalize(rows[n], n);
		for i in n+1..<m.rows {
			row_replacement(rows[i], rows[n], n);
		}
	}
	
	//Iterates upwards through each row, eliminating non-zero's entries.
	for n : int = m.rows-1; n >= 0; n-=1 {
		for i : int = n-1; i >= 0; i -= 1 {
			row_replacement(rows[i], rows[n], n);
		}
	}
	
	if convert_signed_zero {
		//remove -0, so they become 0, make it nicer to print
		for d,d_i in m.data {
			if is_entry_zero(d) {
				m.data[d_i] = 0
			}
		}
	}
	
	return;
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
is_entry_zero :: proc (e : $T) -> bool {
	
	if math.abs(e) < 0.00000001 {
		return true;
	}
	
	return false;
}

@(private="file")
normalize :: #force_inline proc(m : Matrix($T), n : int) {
	if n >= m.columns {
		return
	}
	
	// Get the pivot value (diagonal element)
	v := matrix_get(m, n, n);

	// If the pivot value is zero, we should not attempt to normalize this row
	if is_entry_zero(v) {
		matrix_set(m, n, n, 0);
		return; // Skip normalization for rows with zero pivots
	}

	// Get the row values
	r := matrix_get_row_values(m, n);

	// Normalize the row (divide each element by the pivot)
	for value, index in r {
		r[index] = value / v;  // Normalize the row based on the pivot

		// Force the pivot to be 1 (in case of floating point issues)
		if index == n {
			r[index] = 1;
		}
	}
}

@(private="file")
swap_rows :: #force_inline proc(m : Matrix($T), n : int, k : int){

	r1 := matrix_get_row_values(m, n)
	r2 := matrix_get_row_values(m, k)

	slice.swap_between(r1, r2)
}

@(private="file")
ensure_number_in_row :: #force_inline proc(m : Matrix($T), n : int) {
	//TODO this should look for the larges one to improve stability
	
	if(n >= m.columns){
		return;
	}
	
	row := matrix_get_row_values(m, n);
	
	val : T = 1.0 / row[n];
	if(math.is_inf(val) || math.is_nan(val)){
		row[n] = 0;
	}
	
	if !is_entry_zero(row[n]) {
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
elimination :: #force_inline proc(m : Matrix($T), column : int, row : int) {
		
	if is_entry_zero(matrix_get(m, column, row)) {
		return;
	}
	
	for i := row; i < m.rows; i+=1 {		   
		
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










///////////////////////////// Decomposition and eigen values /////////////////////////////

Eigen :: struct(T : typeid){eigenval : T, eigenvec : []T};

//Sorted from highest to lowest.
get_sorted_eigen :: proc (sym_mat : Matrix(f32), tol : f32 = 0.000000001, max_itter := 100) -> []Eigen(f32) {
	
	assert(sym_mat.columns != 0, "columns len is 0");
	assert(sym_mat.rows != 0, "rows len is 0");
	
	eigen : [dynamic]Eigen(f32);
	
	eigenvalues := get_eigen_values(sym_mat, tol, max_itter);
	
	for eigenval in eigenvalues {
		
		eigenvec := make([]f32, len(eigenvalues));
		
		// Solve (A - lambda * I) * v = 0 for each eigenvalue
		A_lambda_I := matrix_make(sym_mat.rows, sym_mat.columns, f32);  // Initialize (A - lambda * I)
		
		//Compute A - lambda * I
		for i in 0..<sym_mat.rows {
			for j in 0..<sym_mat.columns {
				matrix_set(A_lambda_I, i, j, matrix_get(sym_mat, i, j) - eigenval * (i == j ? 1.0 : 0.0));  // Subtract eigenvalue on diagonal
			}
		}
		
		fmt.printf("A_lambda_I : %#v\n", A_lambda_I);
		
		//Solve (A - lambda * I) * eigenvec = 0 (or use direct solver)
		//Here we perform a simplified system solving approach (Gaussian elimination)
		gaussian_elimination(A_lambda_I);
		
		fmt.printf("A_lambda_I after guass elimination : %#v\n", A_lambda_I);
		
		//A_lambda_I is now in reduced row echelon form and the statement A_lambda_I * x = 0 is true.
		// Loop through the rows of the matrix to extract the eigenvector components
		for i in 0..<A_lambda_I.rows {
			// Check if there's a pivot in the current row
			// A pivot is usually denoted by a 1 in the RREF matrix
			is_pivot := false;
			
			// Scan each column for the pivot
			for j in 0..<A_lambda_I.columns {
				
				// If a pivot is found, the corresponding variable is dependent and we can solve for it
				if matrix_get(A_lambda_I, j, i) != 0 {
					//there is a pivot
					if is_pivot {
						eigenvec[i] -= matrix_get(A_lambda_I, j, i);
					}
					is_pivot = true;
				}
			}
			
			// If there's no pivot in this row, the variable is free, and we can assign an arbitrary value (e.g., 1.0)
			if !is_pivot {
				eigenvec[i] = 1.0;  // Choose 1 for the free variable (arbitrary, can be any non-zero value)
				break;
			}
		}

		// At this point, eigenvec contains the eigenvector components
		normalize_inplace(eigenvec[:]);  // Optionally normalize the eigenvector

		append(&eigen, Eigen(f32){eigenval, eigenvec[:]});
	}
	
	//Sort
	eigen_less :: proc(e1, e2 : Eigen(f32)) -> bool {
		return e1.eigenval < e2.eigenval;
	}
	slice.reverse_sort_by(eigen[:], eigen_less);
	
	return eigen[:];
}

//https://www.youtube.com/watch?v=FAnNBw7d0vg&t
qr_decomposition :: proc (A: Matrix($T)) -> (Q : Matrix(T), R : Matrix(T)) {
	
	m, n := A.columns, A.rows;
	
	assert(m == n, "Matrix must be sqaure");
	
	// Initialize Q and R
	Q = matrix_make(n, n, T);
	R = matrix_make(n, n, T);
	
	prev : [dynamic][]f32;
	defer {
		for p in prev {
			delete(p);
		}
		delete(prev);
	}
	
	//Loop though each columb of A
	for i in 0..<n {
		
		a_i := matrix_get_columb_values_cloned(A, i);
		q_i := a_i
		
		//This is Gram-Schmidt
		for p, j in prev {
			
			inner_product := dot(a_i, p);
			matrix_set(R, i, j, inner_product); //The the non diagonal of R
			
			//elementwise subtraction of q_i -= inner_product * p
			for _, k in q_i {
				q_i[k] -= inner_product * p[k];
			}
		}
		
		q_len := length(q_i);
		
		//Elementwise division of q_i/q_len, this will normalize it.
		for &qv in q_i {
			qv /= q_len; //Normalize q_i
		}
		
		append(&prev, q_i);
		
		matrix_set_column_values(Q, i, q_i); //Set the Q columb
		
		matrix_set(R, i, i, q_len); // set the diagonal
		
	}

	return Q, R;
}

//https://www.youtube.com/watch?v=d32WV1rKoVk
//Returns the eigenvalues
qr_method_solver :: proc (A: Matrix($T), tol: T, max_iter: int = 100) -> ([]Eigen(T)) where intrinsics.type_is_float(T) {
	assert(A.rows == A.columns);
	
	// Get matrix dimensions
	n := A.rows;
	
	// Initialize variables
	error := max(T);
	iter_count := 0;
	A_iter := A;  // Copy A to A_iter for iteration
	
	Q_V := matrix_make_identity(n,n,T);
	defer matrix_destroy(Q_V);
	
	Q, R : Matrix(T);
	defer matrix_destroy(Q);
	defer matrix_destroy(R);
	
	// Loop until convergence or maximum iterations
	for iter_count < max_iter && error > tol {
		
		shift : T = matrix_get(A_iter, n-1, n-1) + 0.1;
		
		//Do the shift
		for d in 0..<n {
			matrix_set(A_iter, d, d, matrix_get(A_iter, d, d) - shift);
		}
		
		//Perform QR decomposition
		Q, R = qr_decomposition(A_iter); //TODO clean up mmeory
		
		Q_V_new := mul(Q_V, Q);
		matrix_destroy(Q_V);
		Q_V = Q_V_new;
		
		//Compute the next iterate
		A_iter = matrix_mul(R, Q);  // A_iter = R * Q
		
		//Undo the shift
		for d in 0..<n {
			matrix_set(A_iter, d, d, matrix_get(A_iter, d, d) + shift);
		}
		
		//Calculate the error (sum of absolute values of below-diagonal elements) IDK if this is right, but it seems to give a good result.
		error = 0;
		for i in 0..<n {
			for j in i+1..<n {
				error += math.abs(matrix_get(A_iter, i, j));
			}
		}
		
		// Increment iteration count
		iter_count += 1;
	}
	
	if iter_count >= max_iter {
		//log.warnf("qr_method_solver reached maximum number of iterations, you might need to increase.");
	}
	
	//log.debugf("Total number of iterations: %v, error : %v, eigenvalues : %v", iter_count, error, A_iter);


	//Extract the eigenvalues (diagonal of A_iter)
	eigenvalues := make([]Eigen(T), n);
	for i in 0..<n {
		eigenvalues[i].eigenval = matrix_get(A_iter, i, i);
		eigenvalues[i].eigenvec = matrix_get_columb_values_cloned(Q_V, i);
		normalize_inplace(eigenvalues[i].eigenvec);
	}
	
	return eigenvalues;
}

get_eigen_values :: proc (A: Matrix($T), tol : T, max_iter: int = 100) -> []T where intrinsics.type_is_float(T) {
	
	if A.columns == 1 && A.rows == 1 {
		lambda := matrix_get(A, 0, 0);
		return slice.clone([]T{lambda});
	}
	else if A.columns == 2 && A.rows == 2 {
		a := matrix_get(A, 0, 0);
		b := matrix_get(A, 0, 1);
		c := matrix_get(A, 1, 0);
		d := matrix_get(A, 1, 1);
		
		// Characteristic polynomial: det(A - λI) = 0 => λ^2 - (a+d)λ + (ad-bc) = 0
		trace := a + d;
		det := a*d - b*c;
		discriminant := trace*trace - 4*det;
		
		if discriminant >= 0 {
			// Two real eigenvalues
			lambda1 := (trace + math.sqrt(discriminant)) / 2;
			lambda2 := (trace - math.sqrt(discriminant)) / 2;
			return slice.clone([]T{lambda1, lambda2});
		} else {
			// Complex eigenvalues
			real_part := trace / 2;
			imaginary_part := math.sqrt(-discriminant) / 2;
			return slice.clone([]T{real_part + imaginary_part, real_part - imaginary_part});
		}
	}
	else if A.columns == 3 && A.rows == 3 {
		a := matrix_get(A, 0, 0);
		b := matrix_get(A, 0, 1);
		c := matrix_get(A, 0, 2);
		d := matrix_get(A, 1, 0);
		e := matrix_get(A, 1, 1);
		f := matrix_get(A, 1, 2);
		g := matrix_get(A, 2, 0);
		h := matrix_get(A, 2, 1);
		i := matrix_get(A, 2, 2);
		
		//(a-l) * ((e-l) * (i-l) - fh) - b (d*(i-l) - fg) + c * (dh - (e-l)*g) 
		//TODO maybe later
	}
	
	// For matrices larger than 3x3, use the QR method solver
	//return qr_method_solver(A, tol, max_iter);
	panic("TODO");
}

//https://www.youtube.com/watch?v=mBcLRGuAFUk
//https://www.youtube.com/watch?v=cOUTpqlX-Xs&t
//This gives back "V" NOT! "V transposed".
singular_value_decomposition :: proc (A : Matrix(f32)) -> (U : Matrix(f32), SIGMA : Matrix(f32), V : Matrix(f32)) {
	
	//The point of SVD is A = U*E*VT
	//Where E is called big SIGMA
	//E is a diagonal matrix with values s_i
	//s_i are called singular values. 
	//The eigenvalue e_i = s_i^2
	
	//Then  AT*A = V*ET*UT * U*E*VT
	//This leads to AT*A = V * E^2 * VT
	
	//Likewise A * AT = U*E*VT * V*ET*UT
	//Which leads to AT*A = U * E^2 * UT
	
	//Both AAT and ATA is symmetric. 
	
	//A be a m*n matrix
	//Then AAT is m*m and ATA is n*n
	
	//ATA and ATT are PSD (positive semi-definte) which mean their eigenvalues are positive or zero. 
	
	//The eigenvalues of AAT and ATA is the same, if they are sorted from largest to lowest l_1 > l_2 .... if one matrix has more eigenvalues then the other the rest is zero.
	//The sqaureroot of the eigenvalues of AAT and ATA are the the signular values of matrix A. sqrt(l_i) = s_i
	
	//Matrix U contrains the normalized eigenvectors of the left singular matrix (AAT) ordered in desending order. 
	//Matrix V contrains the normalized eigenvectors of the right sigluar matrix (ATA) ordered in desending order.  
	
	AT := matrix_transposed_clone(A);
	ATA := matrix_mul(AT, A); 			//ATA (S_right) eigenvectors are its own columbs! because it is orthorgonal
	
	V_eigen := qr_method_solver(ATA, 0.0001, 50);
	
	//Sort the eigenvalues
	{
		less :: proc (a : Eigen(f32), b : Eigen(f32)) -> bool {
			return a.eigenval < b.eigenval;
		} 
		
		slice.reverse_sort_by(V_eigen, less);
	}
	
	//V is a matrix with the eigenvector as ???
	V = matrix_make(len(V_eigen), len(V_eigen[0].eigenvec), f32);
	{//Find V
		for ev, i in V_eigen {
			matrix_set_column_values(V, i, ev.eigenvec);//V is made from eigenvectors.
		}
	}
	
	U = matrix_make(len(V_eigen[0].eigenvec), len(V_eigen), f32);
	{ //Find U, it is made from V
		
		//Find U from V, it is so that: A * v_i = s_i * u_i
		//We have A, v_i and s_i, just find u_i, which is the columb vector of U
		for v_i, i in V_eigen { //This is the same as itterating over V columbs
			//small sigma
			u_i := matrix_vec_mul(A, v_i.eigenvec);
			
			for &u in u_i {
				v := V_eigen[i].eigenval;
				if !math.is_nan(v) && !math.is_inf(v) && math.abs(v) > 0.00001 {
					u /= v; 
				}
				else {
					u = 0;
				}
			}
			
			matrix_set_column_values(U, i, u_i);
		}
	}
	
	//Construct D_1 matrix
	SIGMA = matrix_make(A.rows, A.columns, f32);
	{//Find sigma
		for i in 0..<math.min(SIGMA.rows, SIGMA.columns) {
			v := V_eigen[i].eigenval;
			
			if math.abs(v) < 0.0001 {
				v = 0;
				matrix_set(SIGMA, i, i, 0);
			}
			else {
				matrix_set(SIGMA, i, i, math.sqrt(v));
			}
		}
	}
	
	return V, SIGMA, V; //Because A is symmetrical V = UT
}
