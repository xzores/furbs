package furbs_fontstash;

//////////////////////////////////////////////////////////////////////////////////////
//	Written by Jakob Furbo Enevoldsen, as an alternative to the original fontstash	//
//				This work is devoteted to the public domain 2024					//
//////////////////////////////////////////////////////////////////////////////////////

import "core:fmt"
import "core:mem"
import "core:math"
import "core:slice"

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

//Refers to a rect in the atlas, there are returned from atlas_upload
Atlas_handle :: distinct i32;

//Internal use
Row_entry :: struct {
	x_start, width : i32,
}

//internal use
Atlas_row :: struct {
	height, y_offset : i32,
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
//It might not work well for very large differences in rect sizes.
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
atlas_make :: proc (#any_int size, margin : i32, loc := #caller_location) -> (atlas : Atlas) {

	return Atlas {
		size = size,
		margin = margin,
		
		current_handle_counter = 0,
		handles = make(map[Atlas_handle]Atlas_entry),
		rows = make([dynamic]Atlas_row),
		
		free_rects = make([dynamic]Atlas_index),
	};
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
		if rect.row == len(rows)-1 {
			//If the is on the last row then they y advaliable space is all the way to the top.
			available_space.y = atlas.size - row.y_offset;
		}
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
	
	//This consumes the free rect
	if found_row != -1 {
		assert(found_row_name != -1, "internal error");
		assert(found_index != -1, "internal error");
		
		row := &rows[found_row];
		entry : Row_entry = row.row_entires[found_row_name];
		
		if row.y_offset + required_size.y > size {
			return -1, {}, false;
		}
		
		if found_row == len(rows)-1 {
			//If this is the last row, then increase height to match.
			row.height = math.max(row.height, required_size.y);
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
		rect : [4]i32 = {entry.x_start + margin, row.y_offset + margin, pixel_cnt.x, pixel_cnt.y}; // this is the max height.
		
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
	
	/////// There was not enough horizontal space, check if we can add a new row, otherwise return ok = false; ///////
	
	current_height : i32;
	for r in rows {
		current_height += r.height;
	}
	
	if (size - current_height) >= pixel_cnt.y {
		//Add a new row.
		append(&rows, Atlas_row{
			height = required_size.y,
			y_offset = current_height,
			row_current_name = 0,
			row_entires = make(map[int]Row_entry),
		});
		row : ^Atlas_row = &rows[len(rows)-1];
		
		//Add the entire row to free rects and all atlas_add again.
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
atlas_get_coords :: proc (atlas : Atlas, handle : Atlas_handle, loc := #caller_location) -> [4]f32 {
	assert(handle in atlas.handles, "invalid handle", loc);
	r := atlas.handles[handle].rect;
	return [4]f32{f32(r.x), f32(r.y), f32(r.z), f32(r.w)} / cast(f32)atlas.size;
}

@(require_results)
atlas_remove :: proc(using atlas : ^Atlas, handle : Atlas_handle, loc := #caller_location) -> (rect : [4]i32) {
	
	//Remove the entry from the handles
	entry : Atlas_entry = handles[handle];
	delete_key(&handles, handle);
	
	row := &rows[entry.row];
	row_entry := &row.row_entires[entry.row_name];
	fmt.assertf(row_entry != nil, "row_entry is nil, internal error : %v : %#v", entry, atlas);
	
	could_expand : bool = false;
	
	//The entry is added to free rects.
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
	
	//The sort, it sorts from heighest to lowest rect height.
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

atlas_destroy :: proc (using atlas : Atlas) {
	
	for r in rows {
		delete(r.row_entires);
	}
	
	delete(rows);
	delete(handles);
	delete(free_rects);
}


/////////////////////////////////////////////////// Client side atlas ///////////////////////////////////////////////////
//This a wrapper around the atlas algo it handles pixel coping for you and add resize functionality //

Client_atlas :: struct {
	using impl : Atlas,
	channel_cnt : i32,
	component_size : i32,
	pixels : []u8,
	max_size : i32,
}

//channel_cnt is how many channels the texture has, this should likely be 1,2,3 or 4.
//component_size is the number of bytes per channel, this should likely be 1.
//init_size specifies the initial texture atlas size, it will automagicly change size when needed. The atlas is always a sqaure.
//max size is the atlas texture size limit. 
//margin specifies the distance between textures, it is effectively doubled as the margin is applied on all sides for each texture.
@(require_results)
client_atlas_make :: proc (#any_int channel_cnt, component_size, init_size, max_size, margin : i32, loc := #caller_location) -> (atlas : Client_atlas) {
	
	atlas = Client_atlas{
		impl = atlas_make(init_size, margin, loc),
		component_size = component_size,
		channel_cnt = channel_cnt,
		pixels = make([]u8, component_size * channel_cnt * init_size * init_size),
		max_size = max_size,
	}
	
	return;
}

//Finds space for a new texture and allocates the space. Data is pixel data.
@(require_results)
client_atlas_add :: proc (atlas : ^Client_atlas, pixel_cnt : [2]i32, data : []u8, loc := #caller_location) -> (handle : Atlas_handle, rect : [4]i32, resized, success : bool) {
	
	handle, rect, success = atlas_add(&atlas.impl, pixel_cnt, loc = loc);
	
	for !success { //if we fail, then we grow then prune at max size.
		grew := client_atlas_grow(atlas);
		handle, rect, success = atlas_add(&atlas.impl, pixel_cnt, loc = loc);
		if grew {
			resized = true;
		}
		else {
			pruned := client_atlas_prune(atlas);
			handle, rect, success = atlas_add(&atlas.impl, pixel_cnt, loc = loc);
			break;
		}
	}
	
	if success {
		copy_pixels(atlas.channel_cnt * atlas.component_size, rect.z, rect.w, 0, 0, data, atlas.size, atlas.size, rect.x, rect.y, atlas.pixels, rect.z, rect.w, loc = loc);
	}
		
	return handle, rect, resized, success;
}

//Finds space for a new texture and allocates the space. Data is pixel data.
//This will unlike client_atlas_add, not take any data in, instead a pointer to the data is returned, this allows the user to add the data themselfs.
//IMPORTANT: pixels_begin is not continues, you must interleave/skip by the total width of the atlas, when coping into this.
@(require_results)
client_atlas_add_no_data :: proc (atlas : ^Client_atlas, pixel_cnt : [2]i32, loc := #caller_location) -> (handle : Atlas_handle, rect : [4]i32, pixels_begin : ^u8, resized, success : bool) {
	assert(pixel_cnt.x != 0, "width is zero", loc);
	assert(pixel_cnt.y != 0, "hieght is zero", loc);
	
	handle, rect, success = atlas_add(&atlas.impl, pixel_cnt, loc = loc);
	
	for !success { //if we fail, then we grow then prune at max size.
		grew := client_atlas_grow(atlas);
		handle, rect, success = atlas_add(&atlas.impl, pixel_cnt, loc = loc);
		if grew {
			resized = true;
		}
		else {
			pruned := client_atlas_prune(atlas);
			handle, rect, success = atlas_add(&atlas.impl, pixel_cnt, loc = loc);
			break;
		}
	}
	
	dst_index := (rect.y * atlas.size + rect.x) * atlas.channel_cnt * atlas.component_size;
	
	return handle, rect, &atlas.pixels[dst_index], resized, success;
}

//Returns the texture coordinates in (0,0) -> (1,1) coordinates. 
//The coordinates are kept until the atlas is resized or destroy.
//resized refers to client_atlas_shirnk, client_atlas_grow and client_atlas_add.
@(require_results)
client_atlas_get_coords :: proc (atlas : Client_atlas, handle : Atlas_handle) -> [4]f32 {
	return atlas_get_coords(atlas.impl, handle);
}

//Return the rect to remove from the atlas.
@(require_results)
client_atlas_remove :: proc(atlas : ^Client_atlas, handle : Atlas_handle) -> (erase_quad : [4]i32) {
	return atlas_remove(&atlas.impl, handle);
}

//We reorder the atlas for better packing
client_atlas_prune :: proc (atlas : ^Client_atlas, loc := #caller_location) -> (success : bool) {
	return client_atlas_transfer(atlas, atlas.size);
}

//Will double the size (in each dimension) of the atlas, the old rects will be repacked in a smart way to increase the packing ratio.
//Retruns false if the GPU texture size limit is reached.
client_atlas_grow :: proc (using atlas : ^Client_atlas, loc := #caller_location) -> (success : bool) {
	if size * 2 > max_size {
		return false;
	}
	return client_atlas_transfer(atlas, atlas.size * 2);
}

//Will try and shrink the atlas to half the size, returns true if success, returns false if it could not shrink.
//To shrink as much as possiable do "for client_atlas_shirnk(atlas) {};"
client_atlas_shirnk :: proc (atlas : ^Client_atlas) -> (success : bool) {
	return client_atlas_transfer(atlas, math.max(1, atlas.size / 2));
}

//Destroys the client atlas
client_atlas_destroy :: proc (using atlas : Client_atlas) {
	delete(atlas.pixels);
	atlas_destroy(atlas);
}

//used internally
@(private="file")
client_atlas_transfer :: proc (atlas : ^Client_atlas, new_size : i32, loc := #caller_location) -> (success : bool) {
	new_atlas : Client_atlas = client_atlas_make(atlas.channel_cnt, atlas.component_size, new_size, atlas.max_size, atlas.margin);
	
	handle_map := make(map[Atlas_handle][2]i32);
	defer delete(handle_map);
	for h, v in atlas.impl.handles {
		handle_map[h] = v.rect.zw;
	}
	
	rects, ok := atlas_add_multi(&new_atlas, handle_map, loc = loc);
	defer delete(rects);
	
	if !ok {
		client_atlas_destroy(new_atlas);
		return false;
	}
	
	used_height : i32 = 0;
	
	for h, v in atlas.impl.handles {
		assert(h in handle_map, "internal error, h is not in handle_map");
		
		src_quad := atlas.handles[h].rect;
		dst_quad := rects[h];
		copy_pixels(atlas.channel_cnt * atlas.component_size, atlas.size, atlas.size, src_quad.x, src_quad.y, atlas.pixels,
							new_atlas.size, new_atlas.size, dst_quad.x, dst_quad.y, new_atlas.pixels, dst_quad.z, dst_quad.w);
		
		used_height = math.max(used_height, dst_quad.y + dst_quad.w);
	}
	
	atlas^, new_atlas = new_atlas, atlas^;
	client_atlas_destroy(new_atlas);
	
	return true;
}


