package utils;

import "core:fmt"
import "core:mem"
import "core:math";

//Pixel_count the amout of pixels to be copied
//dst_offset is how far to offset the into the dst texture 
//dst_size is the size of the destination texture
//The temp_alloc is when repeating texture, (faster if you pass context.temp_allocator)
@(optimization_mode="favor_size")
copy_pixels :: proc (#any_int channel_width, src_width, src_height, src_offset_x, src_offset_y: int,  src_pixels: []u8, #any_int dst_width, dst_height, dst_offset_x, dst_offset_y: int,
							dst_pixels: []u8, #any_int copy_width, copy_height : int, repeat : bool = false, temp_alloc := context.allocator, loc := #caller_location) #no_bounds_check {

	fmt.assertf(len(dst_pixels) == channel_width * dst_width * dst_height, "dst_pixels does not match dimensions, dst_pixels : %v, expected : %v.\n channel_width : %v, dst_width : %v, dst_height : %v\n",
																			 len(dst_pixels), channel_width * dst_width * dst_height, channel_width, dst_width, dst_height, loc = loc);
	
	if !repeat {
		fmt.assertf(src_width > 0 && src_width >= src_offset_x + copy_width, "source width out of bounds, src_width: %v, src_offset_x : %v, copy_width : %v", src_width, src_offset_x, copy_width, loc = loc);
		fmt.assertf(src_height >= 0 &&  src_height >= src_offset_y + copy_height, "source height out of bounds, src_height: %v, src_offset_y : %v, copy_height : %v", src_height, src_offset_y, copy_height, loc = loc);
	
		fmt.assertf(dst_width > 0 && dst_width >= dst_offset_x + copy_width, "dst width out of bounds, dst_width : %v, dst_offset_x : %v, copy_width : %v", dst_width, dst_offset_x, copy_width, loc = loc);
		fmt.assertf(dst_height >= 0 &&  dst_height >= dst_offset_y + copy_height, "dst height out of bounds : %v", dst_height, loc = loc);
	}
	
	src_offset_x := src_offset_x %% src_width;
	src_offset_y := src_offset_y %% src_height;
	dst_offset_x := dst_offset_x %% dst_width;
	dst_offset_y := dst_offset_y %% dst_height;
	
	//fmt.assertf(src_offset_x >= 0 && src_width > src_offset_x, "src_offset_x out of bounds, src_width: %v, src_offset_x : %v", src_width, src_offset_x, loc = loc);
	//fmt.assertf(src_offset_y >= 0 &&  src_height > src_offset_y, "src_offset_y out of bounds, src_height: %v, src_offset_y : %v", src_height, src_offset_y, loc = loc);
	//fmt.assertf(dst_offset_x >= 0 && dst_width > dst_offset_x, "dst_offset_x out of bounds, dst_width : %v, dst_offset_x : %v", dst_width, dst_offset_x, loc = loc);
	//fmt.assertf(dst_offset_y >= 0 &&  dst_height > dst_offset_y, "dst_offset_y height out of bounds, dst_height : %v, dst_offset_y : %", dst_height, dst_offset_y, loc = loc);
	
	for y in 0..<copy_height {
		src_y := y + src_offset_y;
		dst_y := y + dst_offset_y;
		
		if repeat {
			// Wrap the source Y coordinate if repeat is enabled
			src_y = src_y %% src_height;
			dst_y = dst_y %% dst_height;
		}
		
		src_index := (src_y * src_width + src_offset_x) * channel_width;
		dst_index := (dst_y * dst_width + dst_offset_x) * channel_width;
		
		if repeat {
			
			//We copy the line to a temp line, this makes the implementation simpler
			t := make([]u8, copy_width * channel_width, temp_alloc);
			defer delete(t, temp_alloc);
			
			if (src_offset_x + copy_width >= src_width) {
				first_copy_len := (src_width - src_offset_x) * channel_width;
				mem.copy_non_overlapping(&t[0], &src_pixels[src_index], first_copy_len);
				mem.copy_non_overlapping(&t[first_copy_len], &src_pixels[(src_y * src_width) * channel_width], copy_width * channel_width - first_copy_len);
			}else {
				mem.copy_non_overlapping(&t[0], &src_pixels[src_index], copy_width * channel_width);
			}
			
			//If we repeat and are out of bounds, then we spit the copy into 2 copies.
			if (dst_offset_x + copy_width >= dst_width) {
				first_copy_len := (dst_width - dst_offset_x) * channel_width;
				mem.copy_non_overlapping(&dst_pixels[dst_index], &t[0], first_copy_len);
				mem.copy_non_overlapping(&dst_pixels[(dst_y * dst_width) * channel_width], &t[first_copy_len], copy_width * channel_width - first_copy_len);
			}
			else {
				mem.copy_non_overlapping(&dst_pixels[dst_index], &t[0], copy_width * channel_width);
			}
		} else {
			mem.copy_non_overlapping(&dst_pixels[dst_index], &src_pixels[src_index], channel_width * copy_width);
		}
	}
}


@(optimization_mode="favor_size")
blend_pixels :: proc (blend_factor : f32, #any_int channel_width, src_width, src_height, src_offset_x, src_offset_y: int,  src_pixels: []u8, #any_int dst_width, dst_height, dst_offset_x, dst_offset_y: int,
							dst_pixels: []u8, #any_int copy_width, copy_height : int, repeat : bool = false, temp_alloc := context.allocator, loc := #caller_location) #no_bounds_check {

	fmt.assertf(len(dst_pixels) == channel_width * dst_width * dst_height, "dst_pixels does not match dimensions, dst_pixels : %v, expected : %v.\n channel_width : %v, dst_width : %v, dst_height : %v\n",
																			 len(dst_pixels), channel_width * dst_width * dst_height, channel_width, dst_width, dst_height, loc = loc);
	
	if !repeat {
		fmt.assertf(src_width > 0 && src_width >= src_offset_x + copy_width, "source width out of bounds, src_width: %v, src_offset_x : %v, copy_width : %v", src_width, src_offset_x, copy_width, loc = loc);
		fmt.assertf(src_height >= 0 &&  src_height >= src_offset_y + copy_height, "source height out of bounds, src_height: %v, src_offset_y : %v, copy_height : %v", src_height, src_offset_y, copy_height, loc = loc);
	
		fmt.assertf(dst_width > 0 && dst_width >= dst_offset_x + copy_width, "dst width out of bounds, dst_width : %v, dst_offset_x : %v, copy_width : %v", dst_width, dst_offset_x, copy_width, loc = loc);
		fmt.assertf(dst_height >= 0 &&  dst_height >= dst_offset_y + copy_height, "dst height out of bounds : %v", dst_height, loc = loc);
	}
	
	src_offset_x := src_offset_x %% src_width;
	src_offset_y := src_offset_y %% src_height;
	dst_offset_x := dst_offset_x %% dst_width;
	dst_offset_y := dst_offset_y %% dst_height;
	
	//fmt.assertf(src_offset_x >= 0 && src_width > src_offset_x, "src_offset_x out of bounds, src_width: %v, src_offset_x : %v", src_width, src_offset_x, loc = loc);
	//fmt.assertf(src_offset_y >= 0 &&  src_height > src_offset_y, "src_offset_y out of bounds, src_height: %v, src_offset_y : %v", src_height, src_offset_y, loc = loc);
	//fmt.assertf(dst_offset_x >= 0 && dst_width > dst_offset_x, "dst_offset_x out of bounds, dst_width : %v, dst_offset_x : %v", dst_width, dst_offset_x, loc = loc);
	//fmt.assertf(dst_offset_y >= 0 &&  dst_height > dst_offset_y, "dst_offset_y height out of bounds, dst_height : %v, dst_offset_y : %", dst_height, dst_offset_y, loc = loc);
	
	@(optimization_mode="favor_size")
	blend_pixel_line :: #force_inline proc(dst_line, src_line: []u8, blend_factor: f32) {
		assert(len(src_line) == len(dst_line), "src_line and dst_line did not match")
		for src_c, i in src_line {
			dst_line[i] = u8(math.clamp((1.0 - blend_factor) * f32(dst_line[i]) + blend_factor * f32(src_c), 0.0, 255.0));
		}
	}
	
	for y in 0..<copy_height {
		src_y := y + src_offset_y;
		dst_y := y + dst_offset_y;
		
		if repeat {
			// Wrap the source Y coordinate if repeat is enabled
			src_y = src_y %% src_height;
			dst_y = dst_y %% dst_height;
		}
		
		src_index := (src_y * src_width + src_offset_x) * channel_width;
		dst_index := (dst_y * dst_width + dst_offset_x) * channel_width;
		
        if repeat {
            // We copy the line to a temp line, this makes the implementation simpler
            t := make([]u8, copy_width * channel_width, temp_alloc);
            defer delete(t, temp_alloc);
            
            if (src_offset_x + copy_width >= src_width) {
                first_copy_len := (src_width - src_offset_x) * channel_width;
                mem.copy_non_overlapping(&t[0], &src_pixels[src_index], first_copy_len);
                mem.copy_non_overlapping(&t[first_copy_len], &src_pixels[(src_y * src_width) * channel_width], copy_width * channel_width - first_copy_len);
            } else {
                mem.copy_non_overlapping(&t[0], &src_pixels[src_index], copy_width * channel_width);
            }
            
            // If we repeat and are out of bounds, then we split the copy into 2 copies.
            if (dst_offset_x + copy_width >= dst_width) {
                first_copy_len := (dst_width - dst_offset_x) * channel_width;
                blend_pixel_line(dst_pixels[dst_index:dst_index + first_copy_len], t[0:first_copy_len], blend_factor);
                b := (dst_y * dst_width) * channel_width;
                l := copy_width * channel_width - first_copy_len;
                blend_pixel_line(dst_pixels[b:b + l], t[first_copy_len:first_copy_len + l], blend_factor);
            } else {
                blend_pixel_line(dst_pixels[dst_index:dst_index + copy_width * channel_width], t[0:copy_width * channel_width], blend_factor);
            }
        } else {
            blend_pixel_line(dst_pixels[dst_index:dst_index + copy_width * channel_width], src_pixels[src_index:src_index + copy_width * channel_width], blend_factor);
        }
    }
}

//allocates new pixels
extract_pixels_patch :: proc(src_pixels : []u8, #any_int src_width, src_height, channels: int, #any_int offset_x, offset_y, width, height : int, repeat : bool = false, loc := #caller_location) -> []u8 {
	
	patch_data := make([]u8, width * height* channels);
	
	copy_pixels(channels, 
						src_width, src_height, offset_x, offset_y, src_pixels,
						width, height, 0, 0, patch_data,
						width, height, repeat, loc = loc);
	
	return patch_data;
}