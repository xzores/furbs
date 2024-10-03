package plot;


import "core:fmt"
import "core:math"
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








