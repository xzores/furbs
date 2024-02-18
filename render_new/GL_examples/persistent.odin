

/*  Copyright (C) 2023 - Izanth

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>. */
package gfx_gl

import "core:slice"
import "core:time"
import "core:mem"
import m "core:math/linalg/glsl"

import "ext:gl"

import miko "miko:core"
import "miko:gfx/impl"
import "miko:log"

SprBatch :: struct {
    va: u32,
    quad_vb: u32,
    sprites_vb: u32,
    index_b: u32,
    program: u32,

    buffers: [3]SyncedBuffer(SprBatchInstance),
    current_buffer: uint,
    current_buffer_pushed_sprites: uint,

    draw_cmds_b: u32,
    draw_cmds_pushed_cmds: u32,
    draw_cmds: SyncedBuffer(gl.DrawElementsIndirectCommand),

    atlas: ^impl.TexAtlas,
}

SyncedBuffer :: struct(T: typeid) {
    data: []T,
    sync: gl.sync_t,
}

SPRBATCH_MAX_QUADS :: 8192
SPRBATCH_BATCH_SIZE :: size_of(SprBatchInstance) * SPRBATCH_MAX_QUADS

SPRBATCH_MAX_DRAW_CMDS :: 16
SPRBATCH_DRAW_CMDS_SIZE :: size_of(gl.DrawElementsIndirectCommand) * SPRBATCH_MAX_DRAW_CMDS

SprBatchInstance :: struct {
    spr_pos: m.vec2,
    spr_dim: m.vec2,
    spr_rot_origin: m.vec2,
    tex_pos: m.uvec2,
    tex_dim: m.uvec2,
    spr_rot: f32,
    spr_tint: [4]u8,
}

sprbatch_make :: proc() -> SprBatch {
    out := SprBatch {}

    gl.create_vertex_arrays(1, &out.va)
    debug__name_obj(out.va, .VertexArray, "SprBatch VertexArray")
    
    quad_vertices := []f32 {
        1.0, 1.0,  
        1.0, 0.0,
        0.0, 0.0,
        0.0, 1.0,
    }
	
    quad_indices := []u8 {
        0, 1, 3, 1, 2, 3,
    }

    gl.create_buffers(1, &out.quad_vb)
    gl.named_buffer_storage(out.quad_vb, size_of(f32) * len(quad_vertices), raw_data(quad_vertices), 0)
    debug__name_obj(out.quad_vb, .Buffer, "SprBatch Quad")

    gl.vertex_array_vertex_buffer(out.va, 0, out.quad_vb, 0, size_of(m.vec2))

    gl.create_buffers(1, &out.index_b)
    gl.named_buffer_storage(out.index_b, size_of(u8) * len(quad_indices), raw_data(quad_indices), 0)
    debug__name_obj(out.index_b, .Buffer, "SprBatch Quad Indices")

    gl.vertex_array_element_buffer(out.va, out.index_b)

    map_flags := gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT
    storage_flags := gl.DYNAMIC_STORAGE_BIT | map_flags

    gl.create_buffers(1, &out.sprites_vb)
    gl.named_buffer_storage(out.sprites_vb, SPRBATCH_BATCH_SIZE * 3, nil, u32(storage_flags))

    gl.vertex_array_vertex_buffer(out.va, 1, out.sprites_vb, 0, size_of(SprBatchInstance))

    ptr := gl.map_named_buffer_range(out.sprites_vb, 0, SPRBATCH_BATCH_SIZE * 3, u32(map_flags))
    all_thirds := slice.from_ptr(cast(^SprBatchInstance) ptr, SPRBATCH_MAX_QUADS * 3)
    out.buffers[0].data = all_thirds[SPRBATCH_MAX_QUADS * 0:][:SPRBATCH_MAX_QUADS]
    out.buffers[1].data = all_thirds[SPRBATCH_MAX_QUADS * 1:][:SPRBATCH_MAX_QUADS]
    out.buffers[2].data = all_thirds[SPRBATCH_MAX_QUADS * 2:][:SPRBATCH_MAX_QUADS]

    out.current_buffer = 0

    // Commands
    gl.create_buffers(1, &out.draw_cmds_b)
    gl.named_buffer_storage(out.draw_cmds_b, SPRBATCH_DRAW_CMDS_SIZE, nil, u32(storage_flags))
    ptr = gl.map_named_buffer_range(out.draw_cmds_b, 0, SPRBATCH_DRAW_CMDS_SIZE, u32(map_flags))
    out.draw_cmds.data = slice.from_ptr(cast(^gl.DrawElementsIndirectCommand) ptr, SPRBATCH_MAX_DRAW_CMDS)

    /* VA Format*/ {
        // Per vertex data
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 0)
        gl.vertex_array_attrib_binding(out.va, attribindex = 0, bindingindex = 0)
        gl.vertex_array_attrib_format(out.va, 0, 2, gl.FLOAT, false, 0)
        // Per instance data
        // spr_pos
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 1)
        gl.vertex_array_attrib_binding(out.va, attribindex = 1, bindingindex = 1)
        gl.vertex_array_attrib_format(out.va, /* attribindex */ 1, 2, gl.FLOAT, false, cast(u32) offset_of(SprBatchInstance, spr_pos))
        // spr_dim
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 2)
        gl.vertex_array_attrib_binding(out.va, attribindex = 2, bindingindex = 1)
        gl.vertex_array_attrib_format(out.va, /* attribindex */ 2, 2, gl.FLOAT, false, cast(u32) offset_of(SprBatchInstance, spr_dim))
        // spr_rot_origin
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 3)
        gl.vertex_array_attrib_binding(out.va, attribindex = 3, bindingindex = 1)
        gl.vertex_array_attrib_format(out.va, /*attribindex*/ 3, 2, gl.FLOAT, false, cast(u32) offset_of(SprBatchInstance, spr_rot_origin))
        // tex_pos
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 4)
        gl.vertex_array_attrib_binding(out.va, attribindex = 4, bindingindex = 1)
        gl.vertex_array_attrib_i_format(out.va, /* attribindex */ 4, 2, gl.UNSIGNED_INT, cast(u32) offset_of(SprBatchInstance, tex_pos))
        // tex_dim
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 5)
        gl.vertex_array_attrib_binding(out.va, attribindex = 5, bindingindex = 1)
        gl.vertex_array_attrib_i_format(out.va, /* attribindex */ 5, 2, gl.UNSIGNED_INT, cast(u32) offset_of(SprBatchInstance, tex_dim))
        // spr_rot
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 6)
        gl.vertex_array_attrib_binding(out.va, attribindex = 6, bindingindex = 1)
        gl.vertex_array_attrib_format(out.va, /*attribindex*/ 6, 1, gl.FLOAT, false, cast(u32) offset_of(SprBatchInstance, spr_rot))
        // spr_tint
        gl.enable_vertex_array_attrib(out.va, /* attribindex */ index = 7)
        gl.vertex_array_attrib_binding(out.va, attribindex = 7, bindingindex = 1)
        gl.vertex_array_attrib_format(out.va, /* attribindex */ 7, 4, gl.UNSIGNED_BYTE, true, cast(u32) offset_of(SprBatchInstance, spr_tint))
 
        // Enable per instance data
        gl.vertex_array_binding_divisor(out.va, bindingindex = 1, divisor = 1)
    }

    return out
}

sprbatch_destroy :: proc(spr: ^SprBatch) {
    gl.unmap_named_buffer(spr.sprites_vb)
    gl.delete_buffers(1, &spr.sprites_vb)
    gl.delete_buffers(1, &spr.quad_vb)
    gl.delete_vertex_arrays(1, &spr.va)

    spr^ = {}
}

sprbatch_begin :: proc(spr: ^SprBatch, atlas: ^impl.TexAtlas) {
    spr.atlas = atlas
    _sprbatch_reset(spr)
    spr.draw_cmds_pushed_cmds = 0
}

_sprbatch_reset :: proc(spr: ^SprBatch) {
    spr.current_buffer_pushed_sprites = 0
}

sprbatch_push :: proc(spr: ^SprBatch, inst: ^SprBatchInstance) {
    if spr.current_buffer_pushed_sprites >= SPRBATCH_MAX_QUADS {
        sprbatch_end(spr)
        _sprbatch_reset(spr)
    }
    #no_bounds_check buf := spr.buffers[spr.current_buffer]
    _sync_wait(&buf)

    #no_bounds_check buf.data[spr.current_buffer_pushed_sprites] = inst^
    spr.current_buffer_pushed_sprites += 1
}

sprbatch_end :: proc(spr: ^SprBatch) {
    first_inst := spr.current_buffer * SPRBATCH_MAX_QUADS
    inst_count := clamp(spr.current_buffer_pushed_sprites, 0, SPRBATCH_MAX_QUADS)

    _sync_wait(&spr.draw_cmds)
    if spr.draw_cmds_pushed_cmds >= SPRBATCH_MAX_DRAW_CMDS {
        sprbatch_flush(spr)
        spr.draw_cmds_pushed_cmds = 0
    }
    #no_bounds_check spr.draw_cmds.data[spr.draw_cmds_pushed_cmds] = gl.DrawElementsIndirectCommand {
        count = 6,
        instance_count = u32(inst_count),
        first_index = 0,
        base_vertex = 0,
        base_instance = u32(first_inst),
    }
    spr.draw_cmds_pushed_cmds += 1

    #no_bounds_check buf := spr.buffers[spr.current_buffer]
    _sync_lock(&buf)
    spr.current_buffer = (spr.current_buffer + 1) % 3
}

sprbatch_flush :: proc(spr: ^SprBatch) {
    atlas_id := cast(^u32) spr.atlas.tex._inner

    gl.bind_vertex_array(spr.va)
    gl.use_program(spr.program)
    gl.bind_texture_unit(0, atlas_id^)

    loc := gl.get_uniform_location(spr.program, "u_atlas_dim")
    gl.program_uniform_2ui(spr.program, loc, spr.atlas.tex.dim.x, spr.atlas.tex.dim.y)

    gl.bind_buffer(gl.DRAW_INDIRECT_BUFFER, spr.draw_cmds_b);
    gl.multi_draw_elements_indirect(gl.TRIANGLES, gl.UNSIGNED_BYTE, nil, i32(spr.draw_cmds_pushed_cmds), 0)
    _sync_lock(&spr.draw_cmds)

    impl.g__stats.num_draw_calls += 1
}

_get_elapsed_ms_since :: proc(since_time: time.Time) -> f64 {
    return time.duration_milliseconds(time.since(since_time))
}

_sync_lock :: proc(third: ^SyncedBuffer($T)) {
    if third.sync != nil {
        gl.delete_sync(third.sync)
    }
    third.sync = gl.fence_sync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0)
}

_sync_wait :: proc(third: ^SyncedBuffer($T)) {
    if third.sync == nil do return

    for {
        wait := gl.client_wait_sync(third.sync, gl.SYNC_FLUSH_COMMANDS_BIT, 1)
        if wait == gl.ALREADY_SIGNALED || wait == gl.CONDITION_SATISFIED {
            return
        }
    }    
}

