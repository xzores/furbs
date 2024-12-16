package plot;

import "core:os"
import "core:fmt"
import "../utils"
import "core:math"
import "core:unicode"
import "core:unicode/utf8"
import "core:strconv"
import "core:strings"

@require_results
read_csv_file_as_signal :: proc (filepath : string, begin_row := 0, end_row := max(int), x_columb := 0, y_columb := 1, resample := false, loc := #caller_location) -> (signal : Signal) {

	csv_data : string;
	defer delete(csv_data);
	{
		t, ok := os.read_entire_file_from_filename(filepath);
		csv_data = string(t);
		csv_data, was_alloc := strings.replace_all(csv_data, "\r", "");
		if was_alloc {
			delete(t);
		}
		fmt.assertf(ok, "Failed to load file : %v", filepath);
	}
	
	return read_csv_data_as_signal(csv_data, begin_row, end_row, x_columb, y_columb, resample, loc); 
}

@require_results
read_csv_data_as_signal :: proc (csv_data : string, begin_row := 0, end_row := max(int), x_columb := 0, y_columb := 1, resample := false, loc := #caller_location) -> (signal : Signal) {
	
	ordinate := make([dynamic]f64, loc = loc); //y-coordinate
	abscissa := make([dynamic]f64, loc = loc); //x-coordinate
		
	cur_ordinate : f64;
	cur_abscissa : f64;
	cur_entry : [dynamic]rune;
	cur_columb : int = 0; 
	cur_exp_entry : [dynamic]rune;
	cur_exp : f64;
	cur_row : int = 0;
	defer delete(cur_entry);
	defer delete(cur_exp_entry);
	
	State :: enum {
		reading,
		found_surfix,
		parse_exponent,
	}
	state : State = .reading;
	
	for r in csv_data {
		
		if cur_row < begin_row {
			if r == '\n' {
				cur_row += 1;
			}
			continue;
		}
		if cur_row >= end_row {
			break;
		}
		
		if state == .found_surfix {
			fmt.assertf(r == ',' || r == ' ' || r == '\n', "surfix must be at the last charactor, found %v after %v at line %i", r, cur_entry[len(cur_entry)-1], cur_row);
		}
		
		read : bool = true;
		if state == .parse_exponent {
			if r == '\n' || r == ',' || r == ' ' {
				s := utf8.runes_to_string(cur_exp_entry[:], context.temp_allocator);
				cur_exp = strconv.atof(s);
				state = .reading;
				clear(&cur_exp_entry);
			}
			else {
				append(&cur_exp_entry, r);
				read = false;
			}
		}
		
		if read {
			if r == '\n' || r == ',' {
				s := utf8.runes_to_string(cur_entry[:], context.temp_allocator);
				if cur_columb == y_columb {
					cur_ordinate = strconv.atof(s) * math.pow10(cur_exp);
				}
				if cur_columb == x_columb {
					cur_abscissa = strconv.atof(s) * math.pow10(cur_exp);
				}
				clear(&cur_entry);
				cur_exp = 0;
				state = .reading;
				
				if r == ',' {
					cur_columb += 1;
				}
				if r == '\n' {
					append(&ordinate, cur_ordinate, loc = loc);
					append(&abscissa, cur_abscissa, loc = loc);
					cur_columb = 0;
					cur_row += 1;
				}
			}
			else if unicode.is_number(r) || r == '.' || r == '-' {
				append(&cur_entry, r);
			}
			else if unicode.is_letter(r) {
				if state == .found_surfix {
					fmt.panicf("Invalid entry at line %i, seems to be a string not a number.", cur_row);
				}
				if r == 'E' {
					state = .parse_exponent;
					continue;
				}
				switch r {
					case 'p': 
						cur_exp = (-12);
					case 'n':
						cur_exp = (-9);
					case 'u', 'µ':
						cur_exp = (-6);
					case 'm':
						cur_exp = (-3);
					case 'k':
						cur_exp = 3;
					case 'M':
						cur_exp = 6;
					case 'G':
						cur_exp = 9;
					case 'T':
						cur_exp = 12;
					case:
						fmt.panicf("Invalid surfix %v, found at line %v", r, cur_row);
				}
				state = .found_surfix;
			}
			else {
				fmt.panicf("unknown symbol : %v at line %i", r, cur_row);
			}
		}
	}
	
	if resample {
		
		sampled_ordinate := make([]f64, len(abscissa) - 1);
		
		xlow, xhigh := get_extremes(abscissa[:])
		sampling_rate : f64 = (cast(f64)len(abscissa) - 1) / (xhigh - xlow);
		
		origi_index : int = 0;
		
		for i in 0..<len(sampled_ordinate) {
			time := cast(f64)i * 1 / sampling_rate;
			for abscissa[origi_index] < time {
				origi_index += 1;
			}
			
			origi_index = math.min(origi_index, len(sampled_ordinate) - 1);
			
			a := abscissa[origi_index];
			a_v := ordinate[origi_index];
			b := abscissa[origi_index + 1];
			b_v := ordinate[origi_index + 1];
			sampled_ordinate[i] = a_v + ((time - a) / (b - a)) * (b_v - a_v);
		}
		
		delete(ordinate);
		delete(abscissa);
		
		return Signal {
			"",
		
			"",
			sampled_ordinate[:],
		
			"",
			Span(f64){xlow, xhigh, 1 / sampling_rate},
		};
	}
	
	return Signal {
		"",
	
		"",
		ordinate[:],
	
		"",
		abscissa[:],
	};
}

/*
@require_results
read_csv_file_as_signals :: proc (filepath : string, columbs : [][2]int, begin_row := 0, end_row := max(int), resample := false, loc := #caller_location) -> ([]Signal) {
	
	csv_data : string;
	defer delete(csv_data);
	{
		t, ok := os.read_entire_file_from_filename(filepath);
		csv_data = string(t);
		csv_data, was_alloc := strings.replace_all(csv_data, "\r", "");
		if was_alloc {
			delete(t);
		}
		fmt.assertf(ok, "Failed to load file : %v", filepath);
	}
	
	return read_csv_data_as_signals(csv_data, columbs, begin_row, end_row, resample, loc); 
}

@require_results
read_csv_data_as_signals :: proc (csv_data : string, columbs : [][2]int, begin_row := 0, end_row := max(int), resample := false, loc := #caller_location) -> ([]Signal) {
	
	signals := make([]Signal, len(columbs));
	
	for c, i in columbs {
		signals[i] = read_csv_data_as_signal(csv_data, c[0], c[1], begin_row, end_row, resample, loc);
	}
	
	return signals[:];
}

@require_results
read_csv_row_as_strings :: proc (data : string, begin_row := 0, end_row := max(int), loc := #caller_location) -> ([]string) {
	
	values := make([dynamic]string);
	
	for {
		
	}
	
	return values[:];
}
*/