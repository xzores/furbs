package render;

import "core:fmt"
import "core:reflect"
import "core:runtime"
import "core:mem"
import "core:slice"
import "core:log"
import "core:math"
import "core:container/queue"

import "core:math/linalg/glsl"
import "core:math/linalg"

import "gl"
import glgl "gl/OpenGL"


////////////////////////////// Mesh generation //////////////////////////////

//converts a index buffer and an vertex array into a vertex arrray without an index buffer
//Used internally
convert_to_non_indexed :: proc (verts : []$T, indices : Indices, loc := #caller_location) -> (new_verts : []T){

	vert_index : int = 0;
	
	switch index in indices {
		case []u16:
			new_verts = make([]T, len(index));
			for ind in index {
				new_verts[vert_index] = verts[ind];
				vert_index += 1;
			}
		case []u32:
			new_verts = make([]T, len(index));
			for ind in index {
				new_verts[vert_index] = verts[ind];
				vert_index += 1;
			}
		case:
			panic("??", loc);
	}

	return;
}

//This will convert mesh data to mesh data that can be drawn with triangle stips. This can optimize the rendering on the GPU.
//This will only help if you mesh is placed in a format where indicies often occurs multiple times in a row.
//TODO do we want this? I think not.
convert_to_triangle_strips_indexed :: proc (verts : []$T, indices : Indices, loc := #caller_location) -> (new_indices : Indices) {
	assert(indices != nil, "indicies are required", loc);
	assert(len(indices) %% 3 == 0, "len(indices) must be a multiple of 3", loc);

	//Check if the last triangle contained some of the new triangles
	//The last triangles might contain 2 of the same triangles.

	//insert degenerate triangles

	panic("todo");

}

//Combine the mesh data from 2 different meshes.
combine_mesh_data :: proc(transform1 : matrix[4,4]f32, verts : []$T, indices : Indices, transform2 : matrix[4,4]f32, verts2 : []T, indices2 : Indices, loc := #caller_location) -> (new_verts : []T, new_indices : Indices) {

	new_verts = make([]T, len(verts) + len(verts2), loc = loc);

	for v, i in verts {
		v := v;
		v.position = (transform1 * [4]f32{v.position.x, v.position.y, v.position.z, 1}).xyz;
		new_verts[i] = v;
	}
	for v, i in verts2 {
		v := v;
		v.position = (transform2 * [4]f32{v.position.x, v.position.y, v.position.z, 1}).xyz;
		new_verts[i + len(verts)] = v;
	}

	//This is a mess, there are too many names for indices, don't know how to fix
	switch indexes in indices {
		case nil:
			assert(indices2 == nil, "indices is nil, but indices2 is not, they must be the same", loc);
			new_indices = nil;
		case []u16:
			if indexes2, ok := indices2.([]u16); ok {
				new_index := make([]u16, len(indexes) + len(indexes2));
				for index, i in indexes {
					new_index[i] = index;
				}
				for index, i in indexes2 {
					new_index[len(indexes) + i] = index + auto_cast len(verts);
				}
				new_indices = new_index;
			}
			else {
				panic("The first mesh has unsigned short while the other is not.", loc);
			}
		case []u32:
			if indexes2, ok := indices2.([]u32); ok {
				new_index := make([]u32, len(indexes) + len(indexes2));
				for index, i in indexes {
					new_index[i] = index;
				}
				for index, i in indexes2 {
					new_index[len(indexes) + i] = index + auto_cast len(verts);
				}
				new_indices = new_index;
			}
			else {
				panic("The first mesh has unsigned int while the other is not.", loc);
			}
	}

	return;
}

Mesh_combine_data :: struct(T: typeid) { transform : matrix[4,4]f32, verts : []T, indices : Indices}

combine_mesh_data_multi :: proc ($T : typeid, mesh_datas : ..Mesh_combine_data(T), loc := #caller_location) -> (res_verts : []T, res_indices : Indices) {
	
	//fmt.assertf(mesh_datas[0].indices == nil, "mesh_datas[0].indices is : %v, %v\n", mesh_datas[0].indices, mesh_datas[0].indices);
	
	switch ind in mesh_datas[0].indices {
		case nil:
		case []u16:
			res_indices = make([]u16,0);
		case []u32:
			res_indices = make([]u32,0);
	}
	
	for m in mesh_datas {
		new_verts, new_indices := combine_mesh_data(1, res_verts, res_indices, m.transform, m.verts, m.indices, loc = loc);
		if res_verts != nil {
			delete(res_verts);
		}
		delete_indices(res_indices);
		res_verts = new_verts; 
		res_indices = new_indices;
	}

	return;
}

//////////////// Mesh generation ////////////////

@(require_results)
generate_quad :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool, alloc := context.allocator) -> (verts : []Default_vertex, indices : Indices) {

	context.allocator = alloc;

	if use_index_buffer {
		verts = make([]Default_vertex, 4)
		_indices := make([]u16, 6);
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + offset - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{0,1,0} * size + offset - {0.5,0.5,0}, {0,1}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{1,1,0} * size + offset - {0.5,0.5,0}, {1,1}, {0,0,1}};
		verts[3] = Default_vertex{[3]f32{1,0,0} * size + offset - {0.5,0.5,0}, {1,0}, {0,0,1}};
		
		_indices[0] = 0;
		_indices[1] = 1;
		_indices[2] = 2;
		_indices[3] = 0;
		_indices[4] = 2;
		_indices[5] = 3;
		indices = _indices;
	}
	else {
		verts = make([]Default_vertex, 6)
		indices = nil;
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + offset - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{0,1,0} * size + offset - {0.5,0.5,0}, {0,1}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{1,1,0} * size + offset - {0.5,0.5,0}, {1,1}, {0,0,1}};

		verts[3] = Default_vertex{[3]f32{0,0,0} * size + offset - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[4] = Default_vertex{[3]f32{1,1,0} * size + offset - {0.5,0.5,0}, {1,1}, {0,0,1}};
		verts[5] = Default_vertex{[3]f32{1,0,0} * size + offset - {0.5,0.5,0}, {1,0}, {0,0,1}};
	}
	
	return;
}

//returns a static mesh containing a quad.
@(require_results)
make_mesh_quad :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool) -> (res : Mesh_single) {

	vert, index := generate_quad(size, offset, use_index_buffer);

	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);
	
	return;
}

@(require_results)
generate_circle :: proc(diameter : f32, offset : [3]f32, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : Indices) {
	
	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	for phi in 0..<sectors {
		angle : f32 = f32(phi);
		
		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		y := math.sin(t);
		x2 := math.cos(t2);
		y2 := math.sin(t2);

		vert 	:= [3]f32{x, y, 0};
		vert2 	:= [3]f32{x2, y2, 0};

		//the center only added once
		if len(vertices) == 0 {
			append(&vertices, 	Default_vertex{[3]f32{0,0,0} *  diameter / 2 + offset, [2]f32{0,0} + 0.5, 	[3]f32{0,0,1}});
		}

		if len(vertices) == 1 {
			append(&vertices,  	Default_vertex{vert * diameter / 2 + offset, 			vert.xy/2 + 0.5, 	[3]f32{0,0,1}});
		}

		append(&vertices, 		Default_vertex{vert2 * diameter / 2 + offset, 			vert2.xy/2 + 0.5, 	[3]f32{0,0,1}});

		append(&temp_indices, 0);
		append(&temp_indices, auto_cast (len(vertices) - 1));
		append(&temp_indices, auto_cast (len(vertices) - 2));
	}

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices));
		_indices := make([]u16, len(temp_indices));
		
		for v, i in vertices {
			verts[i] = v; 	//convert from 2D to 3D
		}
		for ii, i in temp_indices {
			_indices[i] = ii;
		}
		indices = _indices;
	}
	else {
		non_indexed := convert_to_non_indexed(vertices[:], temp_indices[:]);
		verts = non_indexed;
	}

	return;
}

//returns a static mesh containing a circle.
@(require_results)
make_mesh_circle :: proc(diameter : f32, offset : [3]f32, sectors : int, use_index_buffer : bool) -> (res : Mesh_single) {

	vert, index := generate_circle(diameter, offset, sectors, use_index_buffer);

	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);

	return;
}

//
@(require_results)
generate_cube :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : Indices) {

	corners : [24]Default_vertex = {
		//XP
		Default_vertex{{1,0,0}, {0,0}, {1,0,0}},	
		Default_vertex{{1,1,0}, {1,0}, {1,0,0}},
		Default_vertex{{1,1,1}, {1,1}, {1,0,0}},
		Default_vertex{{1,0,1}, {0,1}, {1,0,0}},

		//XN
		Default_vertex{{0,0,0}, {0,0}, {-1,0,0}},
		Default_vertex{{0,0,1}, {0,1}, {-1,0,0}},
		Default_vertex{{0,1,1}, {1,1}, {-1,0,0}},
		Default_vertex{{0,1,0}, {1,0}, {-1,0,0}},

		//YP
		Default_vertex{{0,1,0}, {0,0}, {0,1,0}},
		Default_vertex{{0,1,1}, {0,1}, {0,1,0}},
		Default_vertex{{1,1,1}, {1,1}, {0,1,0}},
		Default_vertex{{1,1,0}, {1,0}, {0,1,0}},

		//YN
		Default_vertex{{0,0,0}, {0,0}, {0,-1,0}},
		Default_vertex{{1,0,0}, {1,0}, {0,-1,0}},
		Default_vertex{{1,0,1}, {1,1}, {0,-1,0}},
		Default_vertex{{0,0,1}, {0,1}, {0,-1,0}},

		//ZP
		Default_vertex{{0,0,1}, {0,0}, {0,0,1}},
		Default_vertex{{1,0,1}, {1,0}, {0,0,1}},
		Default_vertex{{1,1,1}, {1,1}, {0,0,1}},
		Default_vertex{{0,1,1}, {0,1}, {0,0,1}},

		//ZN
		Default_vertex{{0,0,0}, {0,0}, {0,0,-1}},
		Default_vertex{{0,1,0}, {0,1}, {0,0,-1}},
		Default_vertex{{1,1,0}, {1,1}, {0,0,-1}},
		Default_vertex{{1,0,0}, {1,0}, {0,0,-1}},
	};

	odering : [6]u16 = {
		0, 1, 2,
		0, 2, 3,
	}

	_indices := make([]u16, 36);

	index : int = 0;
	for i in 0..<6 {
		for o in odering {
			_indices[index] = o + 4 * cast(u16)i;
			index += 1;
		}
	}
	
	verts = make([]Default_vertex, 24);
	for c,i in corners {
		verts[i] = Default_vertex{(c.position - {0.5,0.5,0.5} + offset) * size, c.texcoord, c.normal};
	}

	if !use_index_buffer {
		new_verts := convert_to_non_indexed(verts, _indices);
		delete(verts);
		delete(_indices);
		verts = new_verts;
		indices = nil;
	}else {
		indices = _indices;
	}

	return;
}

//returns a static mesh containing a cube.
@(require_results)
make_mesh_cube :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool) -> (res : Mesh_single) {
	
	vert, index := generate_cube(size, offset, use_index_buffer);

	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);

	return;
}

@(require_results)
generate_cylinder :: proc(offset : [3]f32, height, diameter : f32, stacks : int, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : Indices) {

	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	for up in 0..=stacks {
		
		y : f32 = f32(up) / f32(stacks);
		
		sectors := sectors + 1;

		for phi in 0..<sectors {
			
			angle : f32 = f32(-phi);

			x := math.cos_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);
			z := math.sin_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);

			vert := [3]f32{x / 2 + offset.x, y + offset.y - 0.5, z / 2 + offset.z};

			append(&vertices, Default_vertex{{vert.x * diameter, vert.y * height, vert.z * diameter}, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)}, [3]f32{x,0,z}});
			
			if up != 0 {
				below_neg 	:= up * sectors + ((phi - 1) %% sectors) - sectors;
				below_i	 	:= up * sectors + phi - sectors;
				this 		:= up * sectors + phi;
				pos 		:= up * sectors + ((phi + 1) %% sectors);
				append(&temp_indices, u16(below_i), u16(pos), u16(this));
				append(&temp_indices, u16(below_i), u16(this), u16(below_neg)); 
			}
			
		}
	}

	up_center := len(vertices);
	append(&vertices, Default_vertex{[3]f32{0, height / 2,0} + offset, [2]f32{0,0} + 0.5, 	[3]f32{0,1,0}});
	down_center := len(vertices);
	append(&vertices, Default_vertex{[3]f32{0, -height / 2, 0} + offset, [2]f32{0,0} + 0.5, [3]f32{0,-1,0}});

	added_first := false;
	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		z := math.sin(t);
		x2 := math.cos(t2);
		z2 := math.sin(t2);

		vert 	:= [3]f32{x, -height/2, z};
		vert2 	:= [3]f32{x2, -height/2, z2};
		vert.xz = vert.xz * diameter / 2;
		vert2.xz = vert2.xz * diameter / 2;

		//the center only added once
		if added_first == false {
			append(&vertices,  	Default_vertex{vert + offset, 	[2]f32{x, z}/2 + 0.5, 	[3]f32{0,0,-1}}); //TODO calculate the normal correctly
			added_first = true;
		}

		append(&vertices, 		Default_vertex{vert2 + offset, 	[2]f32{x2, z2}/2 + 0.5, 	[3]f32{0,0,-1}}); //TODO calculate the normal correctly

		append(&temp_indices, auto_cast down_center);
		append(&temp_indices, auto_cast (len(vertices) - 2));
		append(&temp_indices, auto_cast (len(vertices) - 1));
	}


	added_first = false;
	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		z := math.sin(t);
		x2 := math.cos(t2);
		z2 := math.sin(t2);

		vert 	:= [3]f32{x, height/2, z};
		vert2 	:= [3]f32{x2, height/2, z2};
		vert.xz = vert.xz * diameter / 2;
		vert2.xz = vert2.xz * diameter / 2;

		//the center only added once
		if added_first == false {
			append(&vertices,  	Default_vertex{vert + offset, 	[2]f32{x, z}/2 + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly
			added_first = true;
		}

		append(&vertices, 		Default_vertex{vert2 + offset, 	[2]f32{x2, z2}/2 + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly

		append(&temp_indices, auto_cast up_center);
		append(&temp_indices, auto_cast (len(vertices) - 1));
		append(&temp_indices, auto_cast (len(vertices) - 2));
	}

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices)); 
		_indices := make([]u16, len(temp_indices));

		for v, i in vertices {
			verts[i] = v;
		}
		for ii, i in temp_indices {
			_indices[i] = ii;
		}
		indices = _indices;
	}
	else {
		verts = convert_to_non_indexed(vertices[:], temp_indices[:]);
		indices = nil;
	}

	return;
}

//returns a static mesh containing a cylinder.
@(require_results)
make_mesh_cylinder :: proc(offset : [3]f32, height, diameter : f32, stacks : int, sectors : int, use_index_buffer : bool) -> (res : Mesh_single) {
	
	vert, index := generate_cylinder(offset, height, diameter, stacks, sectors, use_index_buffer);

	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);
	return;
}

@(require_results)
generate_sphere :: proc(offset : [3]f32 = {0,0,0}, diameter : f32 = 1, stacks : int = 10, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (verts : []Default_vertex, indices : Indices) {

	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	stacks := stacks + 1;

	for up in 0..=stacks {
		
		theta := f32(up) / f32(stacks) * math.PI - math.PI / 2;
		y : f32 = math.sin(theta);
		
		for phi in 0..<sectors {
			
			angle : f32 = f32(phi);

			t := f32(-angle) / f32(sectors-1) * 2 * math.PI;
			x := math.cos(t) * math.cos(theta);
			z := math.sin(t) * math.cos(theta);

			vert := [3]f32{x / 2 + offset.x, y / 2 + offset.y, z / 2 + offset.z};
			//append(&vertices, linalg.mul(transform, vert).xyz);
			//append(&texcoords, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)});
			//append(&normals, [3]f32{x,0,z});
			
			append(&vertices, Default_vertex{vert * diameter, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)}, [3]f32{x,y,z}});

			if up != 0 {
				below_neg 	:= up * sectors + ((phi - 1) %% sectors) - sectors;
				below_i	 	:= up * sectors + phi - sectors;
				this 		:= up * sectors + phi;
				pos 		:= up * sectors + ((phi + 1) %% sectors);
				append(&temp_indices, u16(below_i), u16(this), u16(below_neg)); 
				append(&temp_indices, u16(below_i), u16(pos), u16(this)); 
			}
			
		}
	}
	
	//assert(indices[6 * stacks * sectors - 1] != 0)

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices)); 
		_indices := make([]u16, len(temp_indices));

		for v, i in vertices {
			verts[i] = v;
		}
		for ii, i in temp_indices {
			_indices[i] = ii;
		}
		indices = _indices;
	}
	else {
		verts = convert_to_non_indexed(vertices[:], temp_indices[:]);
		indices = nil;
	}

	return;
}

@(require_results)
make_mesh_sphere :: proc(offset : [3]f32, diameter : f32, stacks : int, sectors : int, use_index_buffer : bool) -> (res : Mesh_single) {
	
	vert, index := generate_sphere(offset, diameter, stacks, sectors, use_index_buffer);
	
	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);

	return;
}

@(require_results)
generate_cone :: proc (offset : [3]f32, height, diameter : f32, sectors : int, use_index_buffer : bool) -> (verts : []Default_vertex, indices : Indices) {

	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);
	
	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		z := math.sin(t);
		x2 := math.cos(t2);
		z2 := math.sin(t2);

		vert 	:= [3]f32{x, -height/2, z};
		vert2 	:= [3]f32{x2, -height/2, z2};
		vert.xz = vert.xz * diameter / 2;
		vert2.xz = vert2.xz * diameter / 2; 

		//the center only added once
		if len(vertices) == 0 {
			append(&vertices, 	Default_vertex{[3]f32{0,height/2,0} + offset, [2]f32{0,0} + 0.5, 	[3]f32{0,1,0}}); //TODO calculate the normal correctly
		}
		if len(vertices) == 1 {
			append(&vertices,  	Default_vertex{[3]f32{0,-height/2,0} + offset, 	 [2]f32{0,0} + 0.5, 	[3]f32{0,-1,0}});
		}
		if len(vertices) == 2 {
			append(&vertices,  	Default_vertex{vert + offset, 	vert.xz/diameter + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly
		}
	
		append(&vertices, 		Default_vertex{vert2 + offset, 	vert2.xz/diameter + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly

		append(&temp_indices, 0);
		append(&temp_indices, auto_cast (len(vertices) - 1));
		append(&temp_indices, auto_cast (len(vertices) - 2));
		
		append(&temp_indices, auto_cast (len(vertices) - 2));
		append(&temp_indices, auto_cast (len(vertices) - 1));
		append(&temp_indices, 1);
	}

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices));
		_indices := make([]u16, len(temp_indices));
		
		for v, i in vertices {
			verts[i] = v; 	//convert from 2D to 3D
		}
		for ii, i in temp_indices {
			_indices[i] = ii;
		}
		indices = _indices;
		assert(indices != nil);
	}
	else {
		non_indexed := convert_to_non_indexed(vertices[:], temp_indices[:]);
		verts = non_indexed;
		indices = nil;
	}
	
	return;
}

@(require_results)
make_mesh_cone :: proc(offset : [3]f32, height, diameter : f32, sectors : int, use_index_buffer : bool) -> (res : Mesh_single) {
	
	vert, index := generate_cone(offset, height, diameter, sectors, use_index_buffer);
	
	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);

	return;
}

//direction will be normalized
generate_arrow :: proc (direction : [3]f32, height_cyl, heigth_cone, diameter_cyl, diameter_cone : f32, sectors : int, use_index_buffer : bool, up : [3]f32 = {0,1,0}) -> (verts : []Default_vertex, indices : Indices) {
	using linalg;

	vert_cone, index_cone := generate_cone({0,heigth_cone/2,0}, heigth_cone, diameter_cone, sectors, use_index_buffer);
	defer delete(vert_cone);
	defer delete_indices(index_cone);
	vert_cylinder, index_cylinder := generate_cylinder({0,0,0}, height_cyl, diameter_cyl, 1, sectors, use_index_buffer);
	defer delete(vert_cylinder);
	defer delete_indices(index_cylinder);
	
	arb := up;
	if math.abs(linalg.dot(arb, direction)) >= 0.9999 {
		arb = [3]f32{1,0,0}; //is there something better? likely...
	}

	b := normalize(direction);
	a := normalize(cross(arb, b));
	c := normalize(cross(a, b));

	r_mat := matrix[4,4]f32{
		a.x, b.x, c.x, 0,
		a.y, b.y, c.y, 0,
		a.z, b.z, c.z, 0,
		0,   0,   0,   1,
	};
	
	t1 := linalg.matrix4_translate_f32({0,height_cyl,0});
	t2 := linalg.matrix4_translate_f32({0,height_cyl/2,0});

	t1 = r_mat * t1;
	t2 = r_mat * t2;

	_verts, _indices := combine_mesh_data(t1, vert_cone, index_cone, t2, vert_cylinder, index_cylinder);

	if use_index_buffer {
		assert(index_cone != nil);
		assert(index_cylinder != nil);
		assert(_indices != nil);

		ok : bool;
		verts = _verts;
		indices, ok = _indices.([]u16);
		assert(ok, "internal error");
	}
	else {
		verts = _verts;
		indices = nil;
	}

	return;
}

@(require_results)
make_mesh_arrow :: proc(direction : [3]f32, height_cyl, heigth_cone, diameter_cyl, diameter_cone : f32, sectors : int, use_index_buffer : bool, up := [3]f32{1,0,0}) -> (res : Mesh_single) {

	vert, index := generate_arrow(direction, height_cyl, heigth_cone, diameter_cyl, diameter_cone, sectors, use_index_buffer);

	res = make_mesh_single(vert, index, .static_use);
	
	delete_indices(index);
	delete(vert);

	return;
}