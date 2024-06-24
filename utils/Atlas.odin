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

//Refers to a quad in the atlas, there are returned from atlas_upload
Atlas_handle :: distinct i32;

//internal use
Altas_row :: struct {
	heigth : i32,
	width : i32,
	y_offset : i32,
}

Atlas_init_proc :: #type proc(new_data : ^$T, new_size : i32);
Atlas_upload_proc :: #type proc(atlas : Atlas($T), quad : [4]i32);
Atlas_copy_proc :: #type proc(atlas_src, atlas_dst : Atlas($T), src, dst, size : [2]i32);
Atlas_delete_proc :: #type proc(atlas : Atlas($T));
Atlas_erase_proc :: #type proc(atlas_src : Atlas($T), dst, size : [2]i32);

//Uses a modified strip packing, it is quite fast as it gets and the packing ratio is good for similar sized rectangles. 
//It might not work well for very large differences in quad sizes.
//Singled threaded
Atlas :: struct(T : typeid) {
	atlas_handle_counter : Atlas_handle,
	margin : i32,

	rows : [dynamic]Altas_row,
	quads : map[Atlas_handle][4]i32, //from handle to index
	free_quads : map[Atlas_handle][4]i32,

	size : i32,
	max_texture_size : i32,
	user_data : T,

	//procs
	make_proc : Atlas_init_proc,
	upload_proc : Atlas_upload_proc,
	copy_proc : Atlas_copy_proc,
	delete_proc : Atlas_delete_proc,
	erase_proc : Atlas_erase_proc,
}


//TODO make margins work.
atlas_make :: proc (T : typeid, #any_int max_texture_size : i32, #any_int margin : i32, init_size : i32, user_ptr : rawptr, make_proc : Atlas_make_from_proc, swap_proc : Atlas_swap_proc,
						upload_proc : Atlas_upload_proc, copy_proc : Atlas_copy_proc, delete_proc : Atlas_delete_proc, erase_proc : Atlas_erase_proc, loc := #caller_location) -> (atlas : Atlas(T)) {
	
	atlas = {
		atlas_handle_counter = 0,
		margin = margin,

		rows = make([dynamic]Altas_row),
		quads = make(map[Atlas_handle][4]i32),
		free_quads = make(map[Atlas_handle][4]i32),

		size = init_size,
		max_texture_size = max_texture_size,
		user_ptr = user_ptr,

		make_proc = make_proc,
		swap_proc = swap_proc,
		upload_proc = upload_proc,
		copy_proc = copy_proc,
		delete_proc = delete_proc,
		erase_proc = erase_proc,
	}

	return;
}

//Uploads a texture into the atlas and returns a handle.
//Success may return false if the GPU texture size limit is reached.
@(require_results)
atlas_upload :: proc (using atlas : ^Atlas, pixel_cnt : [2]i32, user_data : any, loc := #caller_location) -> (handle : Atlas_handle, success : bool) {

	tex_size := pixel_cnt + 2 * [2]i32{atlas.margin, atlas.margin};

	//If the texture is not big enough, then we double and try again.
	if tex_size.x > atlas.size || tex_size.x > atlas.size {
		growed := atlas_grow(atlas);
		if !growed {
			return -1, false;
		}
		return atlas_upload(atlas, tex_size, user_data, loc);
	}
	//At this point the texture is big enough, but there might still not be space because if the other rects.
	
	//We will check if an unused placement is sutiable, and if it is we will use that first.
	{
		found_area : i32 = max(i32);
		handle : Atlas_handle = -1;
		
		for k, q in free_quads {
			//r := atlas.rows[v.row];
			//q := [4]i32{v.x_offset, r.y_offset, v.width, r.heigth};
			if q.z >= tex_size.x && q.w >= tex_size.y {
				if (q.z * q.w) <= found_area {
					handle = k;
					found_area = q.z * q.w;
				}
			}
		}
		if handle != -1 {
			//We found a unused quad, now we make a handle for it and return that.
			//v := free_quads[handle];
			//r := atlas.rows[v.row];
			//quad := [4]i32{v.x_offset, r.y_offset, v.width, r.heigth};
			quad := free_quads[handle];
			quad.zw = pixel_cnt;

			quads[handle] = quad; //Create the quad reference

			//remove the quad from free quads, as it is now not free
			delete_key(&free_quads, handle);

			//Upload/copy data into texture
			atlas.upload_proc(atlas.user_ptr, quad, user_data);

			return handle, true; //We have already found a good solution!
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
				return atlas_upload(atlas, tex_size, user_data, loc);
			}
		}
	}

	if min_row_index == -1 {
		//No placement has been found and the texture must be grown and we try again.
		growed := atlas_grow(atlas);
		if !growed {
			return -1, false;
		}
		return atlas_upload(atlas, tex_size, user_data, loc);
	}
	else {
		//A placement was found.
		pixels_offset : [2]i32 = {rows[min_row_index].width + margin, rows[min_row_index].y_offset + margin};

		quad := [4]i32{
			rows[min_row_index].width + margin,		//X_pos
			rows[min_row_index].y_offset + margin,	//Y_pos
			pixel_cnt.x, 							//Width (x_size)
			pixel_cnt.y								//Heigth (y_size)
		};
		
		rows[min_row_index].heigth = math.max(rows[min_row_index].heigth, tex_size.y); //increase the row heigth to this quads hight, if it is bigger.
		rows[min_row_index].width += tex_size.x; //incease the width by the size of the sub-texture.
		
		atlas_handle_counter += 1;
		quads[atlas_handle_counter] = quad; //Create the quad 1 reference

		//Upload
		atlas.upload_proc(atlas.user_ptr, quad, user_data);
		
		return atlas_handle_counter, true;
	}

	unreachable();
}

//Returns the texture coordinates in (0,0) -> (1,1) coordinates. 
//The coordinates until the atlas is resized or destroy.
//resized refers to atlas_shirnk, atlas_grow and atlas_upload.
@(require_results)
atlas_get_coords :: proc (atlas : Atlas, handle : Atlas_handle) -> [4]i32 {
	return atlas.quads[handle] / atlas.size;
}

atlas_remove :: proc(atlas : ^Atlas, handle : Atlas_handle, loc := #caller_location) {
	fmt.assertf(handle in atlas.quads, "the handle %v is invalid", handle, loc = loc);

	quad := atlas.quads[handle];
	assert(quad.z != 0, "width is zero, internal error", loc);
	assert(quad.w != 0, "heigth is zero, internal error", loc);
	atlas.erase_proc(atlas.user_ptr, quad.xy, quad.zw);
	
	atlas.free_quads[handle] = quad;
	delete_key(&atlas.quads, handle);
}

//Will double the size (in each dimension) of the atlas, the old rects will be repacked in a smart way to increase the packing ratio.
//Retruns false if the GPU texture size limit is reached.
atlas_grow :: proc (atlas : ^Atlas, loc := #caller_location) -> (success : bool) {

	//Check if there is space on the GPU.
	if atlas.size * 2 > atlas.max_texture_size {
		return false;
	}
	
	//Make a new teature atlas
	new_atlas := atlas_make(atlas.max_texture_size, atlas.margin, atlas.size * 2, atlas.user_ptr, atlas.make_proc, atlas.swap_proc, atlas.upload_proc, atlas.copy_proc, atlas.delete_proc, atlas.erase_proc, loc);
	new_atlas.user_ptr = atlas.make_proc(atlas.user_ptr, new_atlas.size);
	
	atlas_transfer(atlas, &new_atlas);

	//Destroy the old atlas
	atlas_destroy(new_atlas);

	return true;
}

//Will try and shrink the atlas to half the size, returns true if success, returns false if it could not shrink.
//To shrink as much as possiable do "for atlas_shirnk(atlas) {};"
atlas_shirnk :: proc (atlas : ^Atlas, loc := #caller_location) -> (success : bool) {

	new_atlas := atlas_make(atlas.max_texture_size, atlas.margin, atlas.size / 2, atlas.user_ptr, atlas.make_proc, atlas.swap_proc, atlas.upload_proc, atlas.copy_proc, atlas.delete_proc, atlas.erase_proc, loc);
	new_atlas.user_ptr = atlas.make_proc(atlas.user_ptr, new_atlas.size);
	defer atlas_destroy(new_atlas);

	return atlas_transfer(atlas, &new_atlas);
}

atlas_prune :: proc (atlas : ^Atlas, loc := #caller_location) {
	
	//Make a new teature atlas
	new_atlas := atlas_make(atlas.max_texture_size, atlas.margin, atlas.size, atlas.user_ptr, atlas.make_proc, atlas.swap_proc, atlas.upload_proc, atlas.copy_proc, atlas.delete_proc, atlas.erase_proc, loc);
	new_atlas.user_ptr = atlas.make_proc(atlas.user_ptr, new_atlas.size);
	
	atlas_transfer(atlas, &new_atlas);

	//Destroy the old atlas
	atlas_destroy(new_atlas);
}

atlas_destroy :: proc (using atlas : Atlas) {

	atlas.delete_proc(atlas.user_ptr);

	delete(rows);
	delete(quads);
	delete(free_quads);
}


//Used internally
@(private="file")
atlas_transfer :: proc (atlas : ^Atlas, new_atlas : ^Atlas, loc := #caller_location) -> bool {
	
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
	handles := make([]Handle, len(atlas.quads));
	defer delete(handles);
	
	//because it prune might fail, an optimization is done
	//This will make it so that it does not try to copy all the rects and then give up.
	//instead it will make sure there is space and then begin the copies.
	Copy_command :: struct {
		old_user_ptr : rawptr,
		new_user_ptr : rawptr, 
		src_offset : [2]i32, 
		current_offset : [2]i32,
		quad : [2]i32,
	}
	copy_command_queue : queue.Queue(Copy_command); queue.init(&copy_command_queue);
	defer queue.destroy(&copy_command_queue);

	i : int = 0;

	//Now we add the values that needs to be sorted.
	for k, quad in atlas.quads {

		handles[i] = Handle{
			k,
			quad.z,
			quad.w,
		}

		i += 1;
	}

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

		append(&new_atlas.rows, Altas_row{
			heigth = h,
			width = 0,
			y_offset = 0,
		});
	}
	
	new_atlas.atlas_handle_counter = atlas.atlas_handle_counter;
	//Now add the old quads to the new atlas in the right order.
	for h in handles {

		quad := atlas.quads[h.handle];
		q := quad.zw + (2 * [2]i32{atlas.margin, atlas.margin});
		
		//Because we sort from heigst to lowest, we can just append to each row.
		//when the end of the row is reached, we make a new row. There will always be space enough.

		row := &new_atlas.rows[current_row];
		
		if row.width + q.x > new_atlas.size {
			//There is not enough space to place the quad on the same row, so we move forward.
			
			//Create a new row
			current_row += 1;
			current_y_offset += row.heigth;
			current_x_offset = 0;
			row_heigth = q.y;
			append(&new_atlas.rows, Altas_row{
				heigth = q.y,
				width = 0,
				y_offset = current_y_offset,
			});
			row = &new_atlas.rows[current_row];	//the move
		}

		//The row width is increased
		row.width += q.x;

		//The handle is added to the new atlas
		new_atlas.quads[h.handle] = [4]i32{
			current_x_offset,
			current_y_offset,
			q.x,
			q.y,
		};
		
		src_offset := quad.xy;
		
		if current_y_offset + q.y > new_atlas.size {
			return false; //Prune failed to optimize or shrink failed to shrink, meaning we do nothing.
		}
		queue.append(&copy_command_queue, Copy_command{atlas.user_ptr, new_atlas.user_ptr, src_offset, {current_x_offset, current_y_offset}, {q.x, q.y}});

		current_x_offset += q.x
	}
	
	for queue.len(copy_command_queue) != 0 {
		e := queue.pop_front(&copy_command_queue);
		atlas.copy_proc(e.old_user_ptr, e.new_user_ptr, e.src_offset, e.current_offset, e.quad);
	}

	//Swap the old and new atlas's
	atlas^, new_atlas^ = new_atlas^, atlas^;
	
	//Ok, so because the pointer should be valid until program termination (as we do not own the pointer)
	atlas.user_ptr, new_atlas.user_ptr = new_atlas.user_ptr, atlas.user_ptr;
	atlas.swap_proc(atlas.user_ptr, new_atlas.user_ptr)

	//Upload the initial data.
	//TODO currently a the copies happens in small seqments, one for each quad. If a CPU side texture is used, then it would require a lot of  small copies. 
	//A optimization can be made here as upload_data could be called here, this is not the copy, but the thing that states, please upload now.
	atlas.upload_proc(atlas.user_ptr, {0,0, atlas.size, current_y_offset + atlas.rows[current_row].heigth}, nil);	//Nil means, there is just the copied data. No user data.

	return true;
}
