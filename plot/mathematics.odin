package plot;


import "core:fmt"
import "core:math"
import "core:math/cmplx"
import "core:unicode/utf8"
import "core:slice"
import "core:thread"
import "core:os"

@(require_results)
calculate_trig_dft :: proc (times : []f64, values : []f64, use_hertz := true) -> (a_coeff : []f64, b_coeff : []f64, freqs : []f64) {
	
	xlow, xhigh := get_extremes(times);
	sampling_rate : f64 = (cast(f64)len(times) - 1) / (xhigh - xlow);
	
	a_coeff = make([]f64, len(values));
	b_coeff = make([]f64, len(values));
	
	freqs = make([]f64, len(times));	
	
	frequency_span : f64 = sampling_rate * 0.5;
		
	if use_hertz {
		frequency_span : f64 = sampling_rate * 0.5;
		
		for f_i in 0..<len(values) {
			hz := cast(f64)(f_i) / cast(f64)(len(values) - 1) * frequency_span;
			freqs[f_i] = hz;
			
			for v, t_i in values {
				t := times[t_i];
				a_coeff[f_i] += v * math.sin(2 * math.PI * hz * t); 
				b_coeff[f_i] += v * math.cos(2 * math.PI * hz * t); 
			}
		}
	}
	else {
		frequency_span : f64 = sampling_rate * 0.5;
		
		for f_i in 0..<len(values) {
			omega := cast(f64)(f_i) / cast(f64)(len(values) - 1) * frequency_span * 2 * math.PI;
			freqs[f_i] = omega;
			
			for v, t_i in values {
				t := times[t_i];
				a_coeff[f_i] += v * math.sin(omega * t); 
				b_coeff[f_i] += v * math.cos(omega * t); 
			}
		}
	}
	
	return;
}

@(require_results)
calculate_complex_dft :: proc (times : []f64, values : []f64, use_hertz := true, range : Maybe([2]f64) = nil, loc := #caller_location) -> (phasors : []complex128, freqs : []f64) {
	
	xlow, xhigh := get_extremes(times);
	sampling_rate : f64 = (cast(f64)len(times) - 1) / (xhigh - xlow);
	
	frequency_max : f64 = sampling_rate * 0.5; //in samples per Hz

	low : i128 = 0;
	high : i128 = cast(i128)len(values);
	
	if r, ok := range.?; ok {
		mult : f64 = sampling_rate;
		
		//assert(r[0] <= r[1], "The lower range must be lower then the high range.", loc);
		//fmt.assertf(r[1] <= frequency_max, "The provided frequency %v is above the maximum achiviable frequency", r[1], loc = loc);
		
		// Convert the frequency range to index range
		low = auto_cast (cast(f64)(len(values) - 1) * r[0] / frequency_max);  // Convert lower frequency to index
		high = auto_cast math.ceil(cast(f64)(len(values) - 1) * r[1] / frequency_max);  // Convert upper frequency to index and round up
		
		// Clamp high to the length of the values to avoid out-of-bound access
		high = math.min(high, cast(i128)len(values));
		low = math.max(low, 0);
	}
	
	phasors = make([]complex128, high - low);
	freqs = make([]f64, high - low);	
	
	thread_count := math.max(1, os.processor_core_count()-1);
	
	pool : thread.Pool;
	thread.pool_init(&pool, context.allocator, thread_count);
	defer thread.pool_destroy(&pool);
	
	Task_info :: struct {
		times, values, freqs : []f64,
		phasors : []complex128,
		low, high: i128,
		index_offset : i128,
		use_hertz : bool,
		frequency_max : f64,
	}
	
	tasks := make([dynamic]Task_info);
	defer delete(tasks);
	
	dist := high - low;
	step_freq : i128 = dist/cast(i128)thread_count + 1;
	cur_freq : i128 = low;
	
	for cur_freq < high {
		next_freq : i128 = cur_freq + step_freq;
		next_freq = math.min(next_freq, high);
		index_offset : i128 = low;
		append(&tasks, Task_info{
			times,
			values,
			freqs,
			phasors,
			cur_freq,
			next_freq,
			index_offset,
			use_hertz,
			frequency_max,
		})
		cur_freq += step_freq;
	}
	
	calculate_freq_content :: proc (t : Task_info) {
		using t;
		
		if use_hertz {
			for f_i in low..<high {
				hz := cast(f64)(f_i) / cast(f64)(len(values) - 1) * frequency_max;
				freqs[f_i - index_offset] = hz;
				
				for v, t_i in values {
					t := times[t_i];
					phasors[f_i - index_offset] += complex(v,0) * cmplx.exp(complex(0,-2 * math.PI * hz * t));
				}
			}
		}
		else {
			for f_i in low..<high {
				omega := cast(f64)(f_i) / cast(f64)(len(values) - 1) * frequency_max * 2 * math.PI;
				freqs[f_i - index_offset] = omega;
				
				for v, t_i in values {
					t := times[t_i];
					phasors[f_i - index_offset] += complex(v,0) * cmplx.exp(- imag(1) * omega * t);
				}
			}
		}
	}
	
	calc_task : thread.Task_Proc : proc (task: thread.Task) {
		t : ^Task_info = auto_cast task.data;
		calculate_freq_content(t^);
	}
	
	for &t in tasks {
		thread.pool_add_task(&pool, context.allocator, calc_task, &t);
	}
	
	thread.pool_start(&pool);
	thread.pool_finish(&pool);

	
	return;
}


complex_to_mag_and_phase :: proc(phasors : []complex128) -> (mag : []f64, phase : []f64) {
	
	mag = make([]f64, len(phasors));
	phase = make([]f64, len(phasors));	
	
	for p, i in phasors {
		mag[i] = cmplx.abs(p);
		phase[i] = cmplx.phase(p);
	}
	
	return mag, phase;
} 


