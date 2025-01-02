package fast_noise;

when ODIN_OS == .Windows {
    foreign import lib "fastnoise/lib/FastNosie.lib"
} else when ODIN_OS == .Linux {
    foreign import lib "fastnoise/lib/FastNosie.a"
} else when ODIN_OS == .Darwin {
    foreign import lib "fastnoise/lib/FastNosie.a"
}

////////////////////////////////////////////////////////////////////////////////////////////////

Node_tree :: distinct rawptr;

new_from_encoded_node_tree :: fnNewFromEncodedNodeTree;
delete_node_ref :: fnDeleteNodeRef;

gen_uniform_grid_2D :: fnGenUniformGrid2D;
gen_uniform_grid_3D :: fnGenUniformGrid3D;
gen_uniform_grid_4D :: fnGenUniformGrid4D;

gen_position_array_2D :: fnGenPositionArray2D;
gen_position_array_3D :: fnGenPositionArray3D;
gen_position_array_4D :: fnGenPositionArray4D;

gen_tileable_2D :: fnGenTileable2D;

////////////////////////////////////////////////////////////////////////////////////////////////

@(default_calling_convention="c")
foreign lib {
	fnNewFromEncodedNodeTree :: proc(encodedString : cstring, simdLevel : u32 /*FastSIMD::eLevel 0 = Auto*/) -> Node_tree ---;
	fnDeleteNodeRef :: proc(node_tree : Node_tree) ---;

	fnGetSIMDLevel :: proc(node_tree : Node_tree) -> u32 ---;
	fnGetMetadataID :: proc(node_tree : Node_tree) -> i32 ---;

	fnGenUniformGrid2D :: proc(node_tree : Node_tree, noise_out : [^]f32,
							x_start : i32, y_start : i32,
							x_size : i32, y_size : i32,
							frequency : f32, seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/ ) ---;

	fnGenUniformGrid3D :: proc(node_tree : Node_tree, noise_out : ^f32,
							x_start : i32, y_start : i32, z_start : i32,
							x_size : i32, y_size : i32, z_size : i32,
							frequency : f32, seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/) ---;
									   
	fnGenUniformGrid4D :: proc(node_tree : Node_tree, noise_out : [^]f32,
							x_start : i32, y_start : i32, z_start : i32, w_start : i32,
							x_size : i32, y_size : i32, z_size : i32, w_size : i32,
							frequency : f32, seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/ ) ---;

	fnGenPositionArray2D :: proc(node_tree : Node_tree, noise_out : [^]f32, count : i32,
							xPosArray : [^]f32, yPosArray : [^]f32,
							xOffset : f32, yOffset : f32,
							seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/ ) ---;;

	fnGenPositionArray3D :: proc(node_tree : Node_tree, noise_out : [^]f32, count : i32,
							xPosArray : [^]f32, yPosArray : [^]f32, zPosArray : [^]f32,
							xOffset : f32, yOffset : f32, zOffset : f32,
							seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/ ) ---;

	fnGenPositionArray4D :: proc(node_tree : Node_tree, noise_out : [^]f32, count : i32,
							xPosArray : [^]f32, yPosArray : [^]f32, zPosArray : [^]f32, wPosArray : [^]f32,
							xOffset : f32, yOffset : f32, zOffset : f32, wOffset : f32,
							seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/ ) ---;
	
	fnGenTileable2D :: proc(node_tree : Node_tree, noise_out : [^]f32,
							x_size : i32, y_size : i32,
							frequency : f32, seed : i32, output_min_max : ^[2]f32 /*nullptr or float[2]*/ ) ---;
}

/*
FASTNOISE_API float fnGenSingle2D( const void* node, float x, float y, i32 seed );
FASTNOISE_API float fnGenSingle3D( const void* node, float x, float y, float z, i32 seed );
FASTNOISE_API float fnGenSingle4D( const void* node, float x, float y, float z, float w, i32 seed );

FASTNOISE_API i32 fnGetMetadataCount();
FASTNOISE_API const char* fnGetMetadataName( i32 id ); // valid IDs up to `fnGetMetadataCount() - 1`
FASTNOISE_API void* fnNewFromMetadata( i32 id, unsigned /*FastSIMD::eLevel*/ simdLevel /*0 = Auto*/ );

FASTNOISE_API i32 fnGetMetadataVariableCount( i32 id );
FASTNOISE_API const char* fnGetMetadataVariableName( i32 id, i32 variableIndex );
FASTNOISE_API i32 fnGetMetadataVariableType( i32 id, i32 variableIndex );
FASTNOISE_API i32 fnGetMetadataVariableDimensionIdx( i32 id, i32 variableIndex );
FASTNOISE_API i32 fnGetMetadataEnumCount( i32 id, i32 variableIndex );
FASTNOISE_API const char* fnGetMetadataEnumName( i32 id, i32 variableIndex, i32 enumIndex );
FASTNOISE_API bool fnSetVariableFloat( void* node, i32 variableIndex, float value );
FASTNOISE_API bool fnSetVariablei32Enum( void* node, i32 variableIndex, i32 value );

FASTNOISE_API i32 fnGetMetadataNodeLookupCount( i32 id ); 
FASTNOISE_API const char* fnGetMetadataNodeLookupName( i32 id, i32 nodeLookupIndex );
FASTNOISE_API i32 fnGetMetadataNodeLookupDimensionIdx( i32 id, i32 nodeLookupIndex );
FASTNOISE_API bool fnSetNodeLookup( void* node, i32 nodeLookupIndex, const void* nodeLookup );

FASTNOISE_API i32 fnGetMetadataHybridCount( i32 id );
FASTNOISE_API const char* fnGetMetadataHybridName( i32 id, i32 hybridIndex );
FASTNOISE_API i32 fnGetMetadataHybridDimensionIdx( i32 id, i32 hybridIndex );
FASTNOISE_API bool fnSetHybridNodeLookup( void* node, i32 hybridIndex, const void* nodeLookup );
FASTNOISE_API bool fnSetHybridFloat( void* node, i32 hybridIndex, float value );
*/

////////////////////////////////////////////////////////////////////////////////////////////////
