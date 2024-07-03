package utils;

import "core:fmt"
import "core:mem"
import "core:math"
import "core:slice"
import "core:container/queue"

//Pixel_count the amout of pixels to be copied
//dst_offset is how far to offset the into the dst texture 
//dst_size is the size of the destination texture
@(optimization_mode="speed")
copy_pixels :: proc (#any_int channel_width, src_width, src_height, src_offset_x, src_offset_y: int,  src_pixels: []u8, #any_int dst_width, dst_height, dst_offset_x, dst_offset_y: int,
							dst_pixels: []u8, #any_int copy_width, copy_height : int, loc := #caller_location) #no_bounds_check{

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


//Uses a modified strip packing, it is quite fast as it gets and the packing ratio is good for similar sized rectangles. 
//It might not work well for very large differences in quad sizes.
//Singled threaded
Atlas :: struct {
	atlas_handle_counter : Atlas_handle,
	margin : i32,

	rows : [dynamic]Altas_row,
	quads : map[Atlas_handle][4]i32, //from handle to index
	free_quads : map[Atlas_handle][4]i32,

	size : i32,
	max_texture_size : i32,
	user_ptr : rawptr,
}

//TODO make margins work.
atlas_make :: proc (#any_int max_texture_size : i32, #any_int margin : i32, init_size : i32, user_ptr : rawptr, make_proc : Atlas_make_from_proc, swap_proc : Atlas_swap_proc,
						upload_proc : Atlas_upload_proc, copy_proc : Atlas_copy_proc, delete_proc : Atlas_delete_proc, erase_proc : Atlas_erase_proc, loc := #caller_location) -> (atlas : Atlas) {
	
	atlas = {
		atlas_handle_counter = 0,
		margin = margin,

		rows = make([dynamic]Altas_row),
		quads = make(map[Atlas_handle][4]i32),
		free_quads = make(map[Atlas_handle][4]i32),

		size = init_size,
		max_texture_size = max_texture_size,
		user_ptr = user_ptr,
	}
	
	return;
}



