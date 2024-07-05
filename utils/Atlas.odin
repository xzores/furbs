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
	
	fmt.assertf(src_width > 0 && src_width >= src_offset_x + copy_width, "source width out of bounds : %v", src_width, loc = loc);
	fmt.assertf(src_height >= 0 &&  src_height >= src_offset_y + copy_height, "source height out of bounds : %v", src_height, loc = loc);
	
	fmt.assertf(dst_width > 0 && dst_width >= dst_offset_x + copy_width, "dst width out of bounds : %v", src_width, loc = loc);
	fmt.assertf(dst_height >= 0 &&  dst_height >= dst_offset_y + copy_height, "dst height out of bounds : %v", dst_height, loc = loc);
	
    for y in 0..<copy_height {
        src_y := y + src_offset_y;
		dst_y := y + dst_offset_y;

        src_index := (src_y * src_width + src_offset_x) * channel_width;
		dst_index := (dst_y * dst_width + dst_offset_x) * channel_width;
		
		mem.copy_non_overlapping(&dst_pixels[dst_index], &src_pixels[src_index], channel_width * copy_width);
    }
}


//////////////////////////////////////////////////// Atlas allocation algorithem ////////////////////////////////////////////////////

//Refers to a quad in the atlas, there are returned from atlas_upload
Atlas_handle :: distinct i32;

//internal use
Altas_row :: struct {
	heigth : i32,
	width : i32,
	y_offset : i32,
}

Atlas_entry :: struct {
	row : int,
	x_offset, width, heigth : i32,
}

//Uses a modified strip packing, it is quite fast as it gets and the packing ratio is good for similar sized rectangles. 
//It might not work well for very large differences in quad sizes.
//Singled threaded
Atlas :: struct {
	atlas_handle_counter : Atlas_handle,
	margin : i32,

	rows : [dynamic]Altas_row,
	entries : map[Atlas_handle]Atlas_entry, //from handle to index
	free_entries : map[Atlas_handle]Atlas_entry,

	size : i32,
}

//TODO make margins work.
@(require_results)
atlas_make :: proc (#any_int margin : i32, init_size : i32, user_ptr : rawptr, loc := #caller_location) -> (atlas : Atlas) {
	
	atlas = {
		atlas_handle_counter = 0,
		margin = margin,
		
		rows = make([dynamic]Altas_row),
		entries = make(map[Atlas_handle]Atlas_entry),
		free_entries = make(map[Atlas_handle]Atlas_entry),
		
		size = init_size,
	}

	return;
}

//Uploads a texture into the atlas and returns a handle.
//Success may return false if texture needs to grow.
@(require_results)
atlas_upload :: proc (using atlas : ^Atlas, pixel_cnt : [2]i32, loc := #caller_location) -> (handle : Atlas_handle, quad : [4]i32, success : bool) {
	
	tex_size := pixel_cnt + 2 * [2]i32{atlas.margin, atlas.margin}
	
	//If the texture is not big enough, then we double and try again.
	if tex_size.x > atlas.size || tex_size.y > atlas.size {
		return -1, {}, false;
	}
	//At this point the texture is big enough, but there might still not be space because if the other rects.
	
	//We will check if an unused placement is sutiable, and if it is we will use that first.
	{
		found_area : i32 = max(i32);
		handle : Atlas_handle = -1;
		
		for k, v in free_entries {
			r := atlas.rows[v.row];
			q := [4]i32{v.x_offset, r.y_offset, v.width, r.heigth};
			assert(v.heigth == 0, "set free quads heigth to zero to reduce bugs.");
			if q.z >= tex_size.x && q.w >= tex_size.y {
				if (q.z * q.w) <= found_area {
					handle = k;
					found_area = q.z * q.w;
				}
			}
		}
		if handle != -1 {
			//We found a unused quad, now we make a handle for it and return that.
			//v := free_entries[handle];
			//r := atlas.rows[v.row];
			//quad := [4]i32{v.x_offset, r.y_offset, v.width, r.heigth};
			entry := free_entries[handle];
			delete_key(&free_entries, handle);
			
			row := atlas.rows[entry.row];
			entry.heigth = tex_size.y;
			
			//TODO
			/*if !quad_takes_up_entire_space() {
				split_quad();
				add other quad
			}*/
			entry.width = tex_size.x; //add into the if statement above.
			
			entries[handle] = entry; //Create the quad reference
			
			//remove the quad from free quads, as it is now not free
			
			quad = {entry.x_offset + margin, row.y_offset + margin, entry.width - 2*margin, entry.heigth - 2*margin};
			return handle, quad, true; //We have already found a good solution!
		}
	}

	//Followingly we will find the row with the lowest (height) that can accomedate the texture.
	min_row_index : int = -1;
	min_row_heigth : i32 = max(i32);

	//linear search though all rows.
	for r, i in rows {

		if r.heigth >= tex_size.y && r.heigth < min_row_heigth {
			//there is enough vertical space, but is there enough horizontal space

			if atlas.size - r.width >= tex_size.x {
				//There is enough space and we can use this row.
				min_row_index = i;
				min_row_heigth = r.heigth;
			}
		}
	}
	
	//If there is no rows add an empty row. This will make sure not to go out of bounds in the next step.
	if len(rows) == 0 {
		append(&rows, Altas_row{0, 0, 0});
	}
	
	if min_row_index == -1 {
		
		//We did not find a row, check if we can grow the last row, if not grow texture.
		row := rows[len(rows)-1];
		
		if size - row.y_offset >= tex_size.y {
			
			//We can grow the last row!
			
			//Now We want to check if we have enough horizontal space if we grow the last row.
			if size - row.width >= tex_size.x {

				//there is enough horizontal space and so we grow!
				row.heigth = tex_size.y;
				min_row_index = len(rows)-1;
				min_row_heigth = row.heigth;
			}
			else {
				//There was not enough horizontal space, try to make a new row.
				append(&rows, Altas_row{0, 0, row.y_offset + row.heigth});
				return atlas_upload(atlas, pixel_cnt, loc);
			}
		}
	}
	
	if min_row_index == -1 {
		//No placement has been found and the texture must be grown and we try again.
		return -1, {}, false;
	}
	else {
		//A placement was found.
		quad := [4]i32{
			rows[min_row_index].width,			//X_pos
			rows[min_row_index].y_offset,		//Y_pos
			tex_size.x, 						//Width (x_size)
			tex_size.y							//Heigth (y_size)
		};
		
		rows[min_row_index].heigth = math.max(rows[min_row_index].heigth, tex_size.y); //increase the row heigth to this quads hight, if it is bigger.
		rows[min_row_index].width += tex_size.x; //incease the width by the size of the sub-texture.
		
		atlas_handle_counter += 1;
		entries[atlas_handle_counter] = Atlas_entry{row = min_row_index, x_offset = quad.x, width = tex_size.x, heigth = tex_size.y}; //Create the quad 1 reference
		
		res := quad + {margin, margin, -2*margin, -2*margin};
		return atlas_handle_counter, res, true;
	}

	unreachable();
}

//Returns the texture coordinates in (0,0) -> (1,1) coordinates. 
//The coordinates until the atlas is resized or destroy.
//resized refers to atlas_shirnk, atlas_grow and atlas_upload.
@(require_results)
atlas_get_coords :: proc (atlas : Atlas, handle : Atlas_handle) -> [4]i32 {
	entry := atlas.entries[handle];
	row := atlas.rows[entry.row];
	quad : [4]i32 = {entry.x_offset, row.y_offset, entry.width, entry.heigth};
	return quad / atlas.size;
}

@(require_results)
atlas_remove :: proc(using atlas : ^Atlas, handle : Atlas_handle, loc := #caller_location) -> (quad : [4]i32) {
	fmt.assertf(handle in atlas.entries, "the handle %v is invalid", handle, loc = loc);
	
	entry := atlas.entries[handle];
	assert(entry.width != 0, "width is zero, internal error", loc);
	
	//TODO
	/*
	if is_free_entry_next_to_this() {
		merge_entires();
	}*/
	
	row := atlas.rows[entry.row];
	quad = {entry.x_offset, row.y_offset, entry.width, row.heigth};
	
	entry.heigth = 0;
	atlas.free_entries[handle] = entry;
	delete_key(&atlas.entries, handle);
	
	return;
}

atlas_destroy :: proc (using atlas : Atlas) {
	delete(rows);
	delete(entries);
	delete(free_entries);
}

Copy_command :: struct {
	src_offset : [2]i32, 
	dst_offset : [2]i32,
	size : [2]i32,
}

atlas_transfer :: proc (atlas : ^Atlas, new_atlas : ^Atlas, alloc := context.allocator, loc := #caller_location) -> (success : bool, copy_commands : []Copy_command, max_height : i32) {
	context.allocator = alloc;
	
	//Sort the old data, so we know the best order to add them in (this would be heighest to lowest)
	Handle :: struct {
		handle : Atlas_handle,
		width, heigth : i32,
	}
	
	//Used to sort the array
	sort_proc :: proc (a : Handle, b : Handle) -> bool {
		return a.heigth < b.heigth;
	}
	
	//Make a slice of handles
	handles := make([]Handle, len(atlas.entries));
	defer delete(handles);
	
	copy_commands = make([]Copy_command, len(atlas.entries));

	i : int = 0;

	//Now we add the values that needs to be sorted.
	for k, entry in atlas.entries {
		
		handles[i] = Handle{
			k,
			entry.width,
			entry.heigth,
		}

		i += 1;
	}

	assert(len(atlas.entries) == len(handles));

	//The sort, it sorts from heighest to lowest quad height.
	slice.reverse_sort_by(handles, sort_proc);

	current_row := 0;
	current_y_offset : i32 = 0;
	current_x_offset : i32 = 0;
	row_heigth : i32 = 0;

	if len(new_atlas.rows) == 0 {

		h : i32 = 0;
		
		if len(handles) != 0 {
			h = handles[0].heigth;
		}
		
		row_heigth = h;
		append(&new_atlas.rows, Altas_row{
			heigth = h,
			width = 0,
			y_offset = 0,
		});
	}
	
	new_atlas.atlas_handle_counter = atlas.atlas_handle_counter;
	//Now add the old quads to the new atlas in the right order.
	for h, i in handles {
		
		//Because we sort from heigst to lowest, we can just append to each row.
		//when the end of the row is reached, we make a new row. There will always be space enough.
		
		entry := atlas.entries[h.handle];
		row := &new_atlas.rows[current_row];
		quad : [4]i32 = {entry.x_offset, row.y_offset, entry.width, entry.heigth};
		
		if row.width + quad.z > new_atlas.size {
			//There is not enough space to place the quad on the same row, so we move forward.
			
			//Create a new row
			current_row += 1;
			current_y_offset += row.heigth;
			current_x_offset = 0;
			row_heigth = quad.w;
			append(&new_atlas.rows, Altas_row{
				heigth = quad.w,
				width = 0,
				y_offset = current_y_offset,
			});
			row = &new_atlas.rows[current_row];	//the move
		}

		//The row width is increased
		row.width += quad.z;
		
		//The handle is added to the new atlas
		new_atlas.entries[h.handle] = Atlas_entry{
			row = current_row,
			x_offset = current_x_offset, 
			width = quad.z,
			heigth = quad.w,
		};
		
		if current_y_offset + quad.w > new_atlas.size {
			delete(copy_commands);
			return false, nil, {}; //Prune failed to optimize or shrink failed to shrink, meaning we do nothing.
		}
		
		copy_commands[i] = Copy_command{quad.xy, {current_x_offset, current_y_offset}, [2]i32{quad.z, quad.w}};
		fmt.printf("Copy : %#v", copy_commands[i]);
		
		current_x_offset += quad.z;
	}
	
	assert(len(new_atlas.entries) == len(atlas.entries), "internal error");
	
	return true, copy_commands, current_y_offset + row_heigth;
}

/////////////////////////////////////////////////// Client side atlas ///////////////////////////////////////////////////




































