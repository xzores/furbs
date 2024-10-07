package plot;


import "core:fmt"
import "core:math"
import "core:math/cmplx"
import "core:unicode/utf8"
import "core:slice"

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
calculate_complex_dft :: proc (times : []f64, values : []f64, use_hertz := true, range : Maybe([2]f64) = nil) -> (phasors : []complex128, freqs : []f64) {
	
	xlow, xhigh := get_extremes(times);
	sampling_rate : f64 = (cast(f64)len(times) - 1) / (xhigh - xlow);
	
	frequency_max : f64 = sampling_rate * 0.5; //in samples per Hz

	low : i128 = 0;
	high : i128 = cast(i128)len(values);
	
	if r, ok := range.?; ok {
		mult : f64 = sampling_rate;
		
		// Convert the frequency range to index range
		low = auto_cast (r[0] * cast(f64)(len(values) - 1) / frequency_max);  // Convert lower frequency to index
		high = auto_cast math.ceil(r[1] * cast(f64)(len(values) - 1) / frequency_max);  // Convert upper frequency to index and round up
		
		// Clamp high to the length of the values to avoid out-of-bound access
		high = math.min(high, cast(i128)len(values));
		low = math.max(low, 0);
	}

	phasors = make([]complex128, high - low);
	freqs = make([]f64, high - low);	
	
	if use_hertz {
		for f_i in low..<high {
			hz := cast(f64)(f_i) / cast(f64)(len(values) - 1) * frequency_max;
			freqs[f_i - low] = hz;
			
			for v, t_i in values {
				t := times[t_i];
				phasors[f_i - low] += complex(v,0) * cmplx.exp(complex(0,-2 * math.PI * hz * t));
			}
		}
	}
	else {
		
		for f_i in 0..<len(values) {
			omega := cast(f64)(f_i) / cast(f64)(len(values) - 1) * frequency_max * 2 * math.PI;
			freqs[f_i] = omega;
			
			for v, t_i in values {
				t := times[t_i];
				//phasors[f_i] += v * math.sin(omega * t);
				phasors[f_i] += complex(v,0) * cmplx.exp(- imag(1) * omega * t);
			}
		}
	}
	
	fmt.printf("phasors : %#v\n, freqs : %#v\n", phasors, freqs);
	
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


