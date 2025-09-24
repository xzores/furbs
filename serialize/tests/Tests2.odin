package serialize;

import "core:fmt"
import "core:testing"
import "core:mem"
import "core:math/rand"
import "core:slice"

// ------------------------------------------------------------
// 1) Very large flat byte slice
// ------------------------------------------------------------
@test
test_seri_big_flat_bytes :: proc(t: ^testing.T) {
    rand.reset(0xDEADBEEF)

    S :: struct { data: []u8 }

    make_S :: proc() -> S {
        data := make([]u8, 1<<22) // 4Mib
        _ = rand.read(data[:])
        return S{data = data}
    }
    destroy_S :: proc(s: S) {
        delete(s.data)
    }

    src := make_S()
    defer destroy_S(src)

    ser, err := serialize_to_bytes(src)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    dst, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)
    fmt.assertf(slice.equal(src.data, dst.data), "byte slice payload mismatch")

    free_all(context.temp_allocator)
}

// ------------------------------------------------------------
// 2) Very large string (~500k)
// ------------------------------------------------------------
@test
test_seri_big_string :: proc(t: ^testing.T) {
    rand.reset(0xC0FFEE)

    S :: struct { msg: string }

    make_S :: proc() -> S {
        buf := make([]u8, 500_000)
        _ = rand.read(buf[:])
        return S{msg = string(buf)}
    }
    destroy_S :: proc(s: S) {
        // Free backing buffer of the string
        bs := transmute([]u8)s.msg
        delete(bs)
    }

    src := make_S()
    defer destroy_S(src)

    ser, err := serialize_to_bytes(src)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    dst, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)
    fmt.assertf(src.msg == dst.msg, "string payload mismatch")

    free_all(context.temp_allocator)
}

// ------------------------------------------------------------
// 3) Large nested slices of numbers/strings/bytes
// ------------------------------------------------------------
@test
test_seri_wide_nested_payloads :: proc(t: ^testing.T) {
    rand.reset(123456789)

    T :: struct {
        ints : []u32,
        strs : []string,
        blobs: [][]u8,
    }

    n_ints  :: 200_000
    n_strs  :: 5_000
    n_blobs :: 2_000

    make_T :: proc() -> T {
        ints := make([]u32, n_ints)
        for i := 0; i < n_ints; i += 1 do ints[i] = u32(rand.uint32())

        strs := make([]string, n_strs)
        for i := 0; i < n_strs; i += 1 {
            ln := int(rand.int31_max(64))
            sb := make([]u8, ln)
            _  = rand.read(sb[:])
            strs[i] = string(sb)
        }

        blobs := make([][]u8, n_blobs)
        for i := 0; i < n_blobs; i += 1 {
            ln := int(rand.int31_max(256))
            bb := make([]u8, ln)
            _  = rand.read(bb[:])
            blobs[i] = bb
        }

        return T{ ints = ints, strs = strs, blobs = blobs }
    }

    destroy_T :: proc(v: T) {
        delete(v.ints)
        for s in v.strs {
            bs := transmute([]u8)s
            delete(bs)
        }
        delete(v.strs)
        for b in v.blobs do delete(b)
        delete(v.blobs)
    }

    src := make_T()
    defer destroy_T(src)

    ser, err := serialize_to_bytes(src)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    dst, err2 := deserialize_from_bytes(T, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

    // verify ints
    fmt.assertf(len(dst.ints) == len(src.ints), "ints len mismatch")
    for x, i in src.ints do fmt.assertf(dst.ints[i] == x, "ints[%d] mismatch", i)

    // verify strings
    fmt.assertf(len(dst.strs) == len(src.strs), "strs len mismatch")
    for s, i in src.strs do fmt.assertf(s == dst.strs[i], "strs[%d] mismatch", i)

    // verify blobs
    fmt.assertf(len(dst.blobs) == len(src.blobs), "blobs len mismatch")
    for b, i in src.blobs do fmt.assertf(slice.equal(b, dst.blobs[i]), "blobs[%d] mismatch", i)

    free_all(context.temp_allocator)
}

// ------------------------------------------------------------
// 4) Deeply nested structs with jagged shapes (tree)
// ------------------------------------------------------------
@test
test_seri_deep_nesting_heavy :: proc(t: ^testing.T) {
    rand.reset(0xBADC0DE)

    Node :: struct {
        name : string,
        data : []u8,
        kids : []Node,
    }
    Tree :: struct { root: Node }

    make_node :: proc(depth: int, breadth: int, base: int) -> (n: Node) {
        // name
        name_len := base + int(rand.int31_max(32))
        name_buf := make([]u8, name_len)
        _ = rand.read(name_buf[:])
        n.name = string(name_buf)

        // data
        data_len := base*8 + int(rand.int31_max(64))
        n.data = make([]u8, data_len)
        _ = rand.read(n.data[:])

        if depth <= 0 {
            n.kids = []Node{}
            return
        }
        k := breadth + int(rand.int31_max(3))
        n.kids = make([]Node, k)
        for i := 0; i < k; i += 1 {
            n.kids[i] = make_node(depth-1, breadth, base/2 + 8)
        }
        return
    }

    destroy_node :: proc(n: ^Node) {
        // free name backing
        bs := transmute([]u8)n.name
        delete(bs)
        // free data
        delete(n.data)
        // recurse
        for i := 0; i < len(n.kids); i += 1 {
            destroy_node(&n.kids[i])
        }
        delete(n.kids)
    }

    make_tree   :: proc() -> Tree { return Tree{ root = make_node(3, 3, 64) } }
    destroy_tree:: proc(tre: ^Tree) { destroy_node(&tre.root) }

    src := make_tree()
    defer destroy_tree(&src)

    ser, err := serialize_to_bytes(src)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    dst, err2 := deserialize_from_bytes(Tree, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

    // equality
    eq_node :: proc(a, b: Node) -> bool {
        if a.name != b.name do return false
        if !slice.equal(a.data, b.data) do return false
        if len(a.kids) != len(b.kids) do return false
        for ka, i in a.kids {
            if !eq_node(ka, b.kids[i]) do return false
        }
        return true
    }
    fmt.assertf(eq_node(src.root, dst.root), "deep tree mismatch")

    free_all(context.temp_allocator)
}

// ------------------------------------------------------------
// 5) Randomized fuzz rounds over a mixed, bulky struct
// ------------------------------------------------------------
@test
test_seri_fuzz_mixed_heavy :: proc(t: ^testing.T) {
    rand.reset(42)

    Item :: struct {
        id     : u64,
        title  : string,
        payload: []u8,
    }
    Batch :: struct {
        items : []Item,
        tags  : []string,
        notes : string,
    }

    gen_batch :: proc() -> (b: Batch) {
        n_items := 1000 + int(rand.int31_max(200)) // 1000..1199
        b.items = make([]Item, n_items)
        for i := 0; i < n_items; i += 1 {
            title_len   := 5 + int(rand.int31_max(50))
            title_bytes := make([]u8, title_len)
            _ = rand.read(title_bytes[:])

            payload_len := 64 + int(rand.int31_max(512))
            payload     := make([]u8, payload_len)
            _ = rand.read(payload[:])

            b.items[i] = Item{
                id      = rand.uint64(),
                title   = string(title_bytes),
                payload = payload,
            }
        }

        n_tags := 200 + int(rand.int31_max(200))
        b.tags  = make([]string, n_tags)
        for i := 0; i < n_tags; i += 1 {
            ln := 3 + int(rand.int31_max(12))
            tb := make([]u8, ln)
            _  = rand.read(tb[:])
            b.tags[i] = string(tb)
        }

        notes_len := 50_000 + int(rand.int31_max(50_000)) // ~50–100k
        nb := make([]u8, notes_len)
        _  = rand.read(nb[:])
        b.notes = string(nb)
        return
    }

    destroy_batch :: proc(b: ^Batch) {
        for i := 0; i < len(b.items); i += 1 {
            // title backing
            tb := transmute([]u8)b.items[i].title
            delete(tb)
            // payload slice
            delete(b.items[i].payload)
        }
        delete(b.items)

        for i := 0; i < len(b.tags); i += 1 {
            tg := transmute([]u8)b.tags[i]
            delete(tg)
        }
        delete(b.tags)

        nb := transmute([]u8)b.notes
        delete(nb)
    }
	
    rounds := 5
    for r := 0; r < rounds; r += 1 {
        src := gen_batch()
        defer destroy_batch(&src) // ensure cleanup per round

        ser, err := serialize_to_bytes(src)
		defer delete(ser);
        fmt.assertf(err == .ok, "serialize err (r=%d): %v", r, err)

        dst, err2 := deserialize_from_bytes(Batch, ser[:], context.temp_allocator)
        fmt.assertf(err2 == .ok, "deserialize err (r=%d): %v", r, err2)

        // verify
        fmt.assertf(len(dst.items) == len(src.items), "items len mismatch (r=%d)", r)
        for it, i in src.items {
            jt := dst.items[i]
            ok := (jt.id == it.id) && (jt.title == it.title) && slice.equal(jt.payload, it.payload)
            fmt.assertf(ok, "item[%d] mismatch (r=%d)", i, r)
        }

        fmt.assertf(len(dst.tags) == len(src.tags), "tags len mismatch (r=%d)", r)
        for tg, i in src.tags do fmt.assertf(tg == dst.tags[i], "tag[%d] mismatch (r=%d)", i, r)

        fmt.assertf(src.notes == dst.notes, "notes mismatch (r=%d)", r)

        free_all(context.temp_allocator)
    }
}
