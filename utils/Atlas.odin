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
	
	fmt.assertf(dst_width > 0 && dst_width >= dst_offset_x + copy_width, "dst width out of bounds, dst_width : %v, dst_offset_x : %v, copy_width : %v", dst_width, dst_offset_x, copy_width, loc = loc);
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
//This is the simplist implementation I could think of, that said I think it is still too complex//

//Refers to a quad in the atlas, there are returned from atlas_upload
Atlas_handle :: distinct i32;

//Internal use
Row_entry :: struct {
	x_start, width : i32,
}

//internal use
Atlas_row :: struct {
	height : i32,
	row_current_name : int,
	row_entires : map[int]Row_entry, //The size of the rect.
}

//Internal use
Atlas_index :: struct {
	row, row_name : int,
}

//Internal use
Atlas_entry :: struct {
	rect : [4]i32,		//This is the occupation.
	row, row_name : int,//This is where the entry is from.
}

//Uses a modified strip packing, it is quite fast as it gets and the packing ratio is good for similar sized rectangles. 
//It might not work well for very large differences in quad sizes.
//Singled threaded
Atlas :: struct {
	size, margin : i32,
	
	current_handle_counter : Atlas_handle,
	handles : map[Atlas_handle]Atlas_entry,
	rows : [dynamic]Atlas_row,
	
	free_rects : [dynamic]Atlas_index,
}

//margin is to each side, so effectivly doubled.
@(require_results)
atlas_make :: proc (#any_int margin, size : i32, user_ptr : rawptr, loc := #caller_location) -> (atlas : Atlas) {

	return Atlas {
		size = size,
		margin = margin,
		
		current_handle_counter = 0,
		handles = make(map[Atlas_handle]Atlas_entry),
		rows = make([dynamic]Atlas_row),
		
		free_rects = make([dynamic]Atlas_index),
	};
}

//Returns a free atlas handle, this will also consume the atlas handle space.
get_next_free_handle :: proc (using atlas : ^Atlas) -> (h : Atlas_handle) {
	h = atlas.current_handle_counter;
	atlas.current_handle_counter += 1;
	return h;
}

//If multiple textures are added to the atlas at once a better packing can be achived.
//See get_next_free_handle
@(require_results)
atlas_add_multi :: proc (using atlas : ^Atlas, pixel_cnts : map[Atlas_handle][2]i32, loc := #caller_location) -> (rects : map[Atlas_handle][4]i32, success : bool) {
	//TODO sort by heigth and do atlas_add
	
	rects = make(map[Atlas_handle][4]i32, len(pixel_cnts));
	
	Handle_sorting :: struct {
		handle : Atlas_handle,
		heigth : i32,
	}
	
	//Used to sort the array
	sort_proc :: proc (a : Handle_sorting, b : Handle_sorting) -> bool {
		return a.heigth < b.heigth;
	}
	
	sorted := make([]Handle_sorting, len(pixel_cnts));
	defer delete(sorted);
	
	i : int = 0;
	for h, pixel_cnt in pixel_cnts {
		sorted[i] = Handle_sorting{h, pixel_cnt.y};
		i += 1;
	}
	
	//The sort, it sorts from heighest to lowest quad height.
	slice.reverse_sort_by(sorted, sort_proc);
	
	for h in sorted {
		fmt.assertf(!(h.handle in atlas.handles), "The handle %v is already in use", h.handle, loc = loc);
		pixel_cnt := pixel_cnts[h.handle];
		handle, rect, ok := atlas_add(atlas, pixel_cnt, h.handle, loc);
		if !ok {
			//We failed in adding all the rects and so we will undo our steps and return failure.
			for h, r in rects {
				_ = atlas_remove(atlas, h);
			}
			delete(rects);
			return nil, false;
		}
		rects[h.handle] = rect;
	}
	
	return rects, true;
}

//Uploads a texture into the atlas and returns a handle.
//Success may return false if texture needs to grow.
//Can be used to request a speficic Atlas_handle number, the number must be unused.
@(require_results)
atlas_add :: proc (using atlas : ^Atlas, pixel_cnt : [2]i32, handle_index : Maybe(Atlas_handle) = nil, loc := #caller_location) -> (handle : Atlas_handle, rect : [4]i32, success : bool) {
	
	
	found_row, found_row_name, found_index : int = -1, -1, -1;
	found_height, found_area : i32 = max(i32), 0;
	
	/////// See if there is free space in one of the existing free rects ///////
	required_size := pixel_cnt + 2 * margin;
	for rect, i in free_rects {
		//Find available space
		available_space : [2]i32; 
		row := rows[rect.row];
		available_space.y = row.height;
		available_space.x = row.row_entires[rect.row_name].width;
		
		//Find the smallest area that can fit the image.
		if available_space.x >= required_size.x && available_space.y >= required_size.y {
			area := available_space.x * available_space.y;
			if available_space.y < found_height && found_area < area {
				found_height = available_space.y;
				found_row = rect.row;
				found_row_name = rect.row_name;
				found_index = i;
			}
		}
	}
	
	if found_row != -1 {
		assert(found_row_name != -1, "internal error");
		assert(found_index != -1, "internal error");
		
		row := &rows[found_row];
		entry : Row_entry = row.row_entires[found_row_name];
		
		row_begin_height : i32;
		for r in rows[:found_row] {
			row_begin_height += r.height;
		}
		
		if row_begin_height + required_size.y > size {
			return -1, {}, false;
		}
		
		//consume the space
		unordered_remove(&free_rects, found_index);
		//if the rect does not match exactly with, then create a new space for the remaining space.
		if required_size.x != entry.width {
			new_entry : Row_entry = entry; //This is the "rest" of what was not used, it will be added as a new entry.
			new_entry.width -= required_size.x;
			new_entry.x_start += required_size.x;
			entry.width = required_size.x;
			
			row.row_entires[found_row_name] = entry;
			
			//add the new entry to the row and the free rects.
			row.row_entires[row.row_current_name] = new_entry;
			append(&free_rects, Atlas_index{row = found_row, row_name = row.row_current_name});
			row.row_current_name += 1;
		}
		//contruct to occupying rect
		rect : [4]i32 = {entry.x_start + margin, row_begin_height + margin, pixel_cnt.x, pixel_cnt.y}; // this is the max height.
		
		//Create the handle
		if h, ok := handle_index.?; ok {
			assert(!(h in handles), "The handle is already in use", loc);
			//If the handle is a specific handle
			handles[h] = Atlas_entry {rect = rect, row = found_row, row_name = found_row_name};
			current_handle_counter = math.max(current_handle_counter + 1, h + 1);
		}
		else {
			//if not increment counter
			handles[current_handle_counter] = Atlas_entry {rect = rect, row = found_row, row_name = found_row_name};
			current_handle_counter += 1;
		}
		
		return current_handle_counter - 1, rect, true;
	}
	
	/////// A free rect was not found, check if we can add a new row, otherwise return ok = false; ///////
	current_height : i32;
	for r in rows {
		current_height += r.height;
	}
	
	if (size - current_height) >= pixel_cnt.y {
		//Add a new row.
		append(&rows, Atlas_row{
			height = required_size.y,
			row_current_name = 0,
			row_entires = make(map[int]Row_entry),
		});
		row : ^Atlas_row = &rows[len(rows)-1];
		
		//Add the entire row to free quads and all atlas_add again.
		append(&free_rects, Atlas_index{
				row = len(rows) - 1,
				row_name = row.row_current_name,
		});
		row.row_entires[row.row_current_name] = Row_entry{x_start = 0, width = size};
		row.row_current_name += 1;
		
		return atlas_add(atlas, pixel_cnt, handle_index, loc);
	}
	
	return -1, {}, false;
}

//Returns the texture coordinates in (0,0) -> (1,1) coordinates. 
//The coordinates until the atlas is resized or destroy.
//resized refers to atlas_shirnk, atlas_grow and atlas_upload.
@(require_results)
atlas_get_coords :: proc (atlas : Atlas, handle : Atlas_handle) -> [4]i32 {
	return atlas.handles[handle].rect;
}

@(require_results)
atlas_remove :: proc(using atlas : ^Atlas, handle : Atlas_handle, loc := #caller_location) -> (quad : [4]i32) {
	
	//Remove the entry from the handles
	entry : Atlas_entry = handles[handle];
	delete_key(&handles, handle);
	
	row := &rows[entry.row];
	row_entry := &row.row_entires[entry.row_name];
	fmt.assertf(row_entry != nil, "row_entry is nil, internal error : %v : %#v", entry, atlas);
	
	could_expand : bool = false;
	
	//The entry is added to free quads.
	append(&free_rects, Atlas_index{row = entry.row, row_name = entry.row_name});
	
	//// Seach all other free rects, if it shares the row we check if it is connected to the entry. ////
	//Look to the right
	for r, i in free_rects {
		if r.row == entry.row {
			
			//it shares the row, so it might also be able to expand the exsisting rect.
			free_entry := &row.row_entires[r.row_name];
			
			if free_entry.x_start + free_entry.width == row_entry.x_start {
				//The free entry can be expanded to the left (backward) to consume the newly deleted entry.
				//Deleted the old and expand the current row_entry.
				could_expand = true;
				row_entry.x_start = free_entry.x_start;
				row_entry.width += free_entry.width;
				//Remove the entry from the row
				delete_key(&row.row_entires, r.row_name);
				unordered_remove(&free_rects, i);
				break;
			}
		}
	}
	
	//Look to the left
	for r, i in free_rects {
		if r.row == entry.row {
			
			//it shares the row, so it might also be able to expand the exsisting rect.
			free_entry := row.row_entires[r.row_name];
			
			if free_entry.x_start == row_entry.x_start + row_entry.width {
				//The free entry can be expanded to the right (forwards) to consume the newly deleted entry.
				could_expand = true;
				row_entry.width += free_entry.width;
				//Remove the entry from the row
				delete_key(&row.row_entires, r.row_name);
				unordered_remove(&free_rects, i);
				break;
			}
		}
	}
	
	//Keep removing the top row if it has 0 entries, this will help "reset" the atlas state, so it behaves as expected.
	//Only at the top to now fuck up any old entry indecies.
	for len(rows) != 0 {
		if len(rows[len(rows)-1].row_entires) == 1 {
			row_name : int = 0;
			
			for name in rows[len(rows)-1].row_entires {
				row_name = name;
			}
			
			index, contains := slice.linear_search(free_rects[:], Atlas_index{row = len(rows)-1, row_name = row_name});
			if contains {
				//remove the top.
				old_row := pop(&rows);
				delete(old_row.row_entires);
				
				//TODO we are not deleting old free rects.
				unordered_remove(&free_rects, index);
			}
			else {
				break;
			}
		}
		else {
			break;
		}
	}
	
	return entry.rect;
}

atlas_destroy :: proc (using atlas : Atlas) {
	
	for r in rows {
		delete(r.row_entires);
	}
	
	delete(rows);
	delete(handles);
	delete(free_rects);
}


/////////////////////////////////////////////////// Client side atlas ///////////////////////////////////////////////////




































