package utils;

import "core:fmt"
import "core:mem"

//Pixel_count the amout of pixels to be copied
//dst_offset is how far to offset the into the dst texture 
//dst_size is the size of the destination texture
@(optimization_mode="speed")
copy_pixels :: proc (#any_int channel_width, src_width, src_height, src_offset_x, src_offset_y: int,  src_pixels: []u8,
						#any_int dst_width, dst_height, dst_offset_x, dst_offset_y: int, dst_pixels: []u8, #any_int copy_width, copy_height : int, loc := #caller_location) {
    
	//TODO remove assert(channel_width >= 1 && channel_width <= 4, "channel_width must be between 1 and 4", loc);
	fmt.assertf(len(dst_pixels) == channel_width * dst_width * dst_height, "dst_pixels does not match dimensions, dst_pixels : %v, expected : %v.\n channel_width : %v, dst_width : %v, dst_height : %v\n",
																			 len(dst_pixels), channel_width * dst_width * dst_height, channel_width, dst_width, dst_height, loc = loc);

	assert(src_width > 0 && src_width >= src_offset_x + copy_width, "source width out of bounds", loc);
	assert(src_height >= 0 &&  src_height >= src_offset_y + copy_height, "source height out of bounds", loc);
	
	assert(dst_width > 0 && dst_width >= dst_offset_x + copy_width, "dst width out of bounds", loc);
	assert(dst_height >= 0 &&  dst_height >= dst_offset_y + copy_height, "dst height out of bounds", loc);
	
    for y in 0..<copy_height {
        src_y := y + src_offset_y;
		dst_y := y + dst_offset_y;

        src_index := (src_y * src_width + src_offset_x) * channel_width;
		dst_index := (dst_y * dst_width + dst_offset_x) * channel_width;
		
		mem.copy_non_overlapping(&dst_pixels[dst_index], &src_pixels[src_index], channel_width * copy_width);
    }
}