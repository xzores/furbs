package serialize;

import "core:fmt"
import "base:runtime"
import "core:slice"
import "core:testing"
import "core:math/rand"

@test
test_seri_deseri_dyn_arr :: proc (t : ^testing.T) {
	context.allocator = context.temp_allocator;
	My_test_struct :: struct {
		data : []u8,
	}
	
	my_test_struct : My_test_struct = {data = {1,2,3,4,5,10,20,30,40,50,60,70,80,90}};
	
	ser, err := serialize_to_bytes(my_test_struct);
	my_test_struct2, err2 := deserialize_from_bytes(My_test_struct, ser[:], context.temp_allocator);
	testing.expectf(t, err2 == .ok, "Deserialize did not go well, err: %v", err2);

	for d, i in my_test_struct.data {
		v := my_test_struct2.data[i];
		if v != d {
			fmt.printf("data at %i was %v, while it should be %v\n", i, v, d)
		};
	}

	free_all(context.temp_allocator);
}

@test
test_seri_header_equals_total_len :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    v : i32 = 123456
    ser, err := serialize_to_bytes(v)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    header : u32 = (cast(^u32)&ser[0])^
    testing.expect(t, header == cast(u32)len(ser), fmt.tprintf("header %v != total len %v", header, len(ser)))

    v2, err2 := deserialize_from_bytes(i32, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    testing.expectf(t, v2 == v, "roundtrip mismatch %v != %v", v2, v)
    free_all(context.temp_allocator)
}

@test
test_seri_trivial_scalars_struct :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    S :: struct {
        x: i32,
        y: f32,
        b: bool,
    }
    s: S = {x = 42, y = 3.5, b = true}

    ser, err := serialize_to_bytes(s)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    testing.expect(t, s2.x == s.x && s2.y == s.y && s2.b == s.b, "roundtrip mismatch")
    free_all(context.temp_allocator)
}

@test
test_seri_empty_string_and_empty_slice :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    S :: struct {
        s: string,
        a: []i32,
    }
    s: S = {s = "", a = []i32{}}

    ser, err := serialize_to_bytes(s)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    testing.expect(t, len(s2.s) == 0 && len(s2.a) == 0, "expected empties")
    free_all(context.temp_allocator)
}

@test
test_seri_slice_of_strings :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    S :: struct {
        msgs: []string,
    }
    s: S = {msgs = []string{"a", "", "xyz", "hello world"}}

    ser, err := serialize_to_bytes(s)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    testing.expect(t, err2 == .ok, fmt.tprintf("deserialize err: %v", err2))
    testing.expect(t, len(s2.msgs) == len(s.msgs), "len mismatch")
    for m, i in s.msgs {
        testing.expectf(t, s2.msgs[i] == m, "msgs[%d] %q != %q", i, s2.msgs[i], m)
    }
    free_all(context.temp_allocator)
}

@test
test_seri_fixed_array_trivial :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    S :: struct {
        bytes: [5]u8,
    }
    s: S = {bytes = [5]u8{1,2,3,4,5}}

    ser, err := serialize_to_bytes(s)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    for b, i in s.bytes {
        testing.expectf(t, s2.bytes[i] == b, "bytes[%d] %v != %v", i, s2.bytes[i], b)
    }
    free_all(context.temp_allocator)
}

@test
test_seri_nested_structs :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    Inner :: struct { name: string, vals: []i64 }
    Outer :: struct { id: u32, inner: Inner }

    o: Outer = { id = 7, inner = { name = "nest", vals = []i64{10,20,30} } }

    ser, err := serialize_to_bytes(o)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    o2, err2 := deserialize_from_bytes(Outer, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    testing.expect(t, o2.id == o.id && o2.inner.name == o.inner.name, "header fields mismatch")
    testing.expect(t, len(o2.inner.vals) == 3 && o2.inner.vals[0] == 10 && o2.inner.vals[2] == 30, "vals mismatch")
    free_all(context.temp_allocator)
}

@test
test_seri_named_and_distinct_types :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    AliasI32   :: i32
    MyID       :: distinct u64
    S :: struct {
        a: AliasI32,
        id: MyID,
    }
    s: S = {a = 99, id = MyID(123456789)}

    ser, err := serialize_to_bytes(s)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    testing.expect(t, s2.a == s.a && u64(s2.id) == u64(s.id), "roundtrip mismatch for named/distinct")
    free_all(context.temp_allocator)
}

@test
test_seri_slice_of_structs :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    Point :: struct { x: i32, y: i32 }
    S :: struct { pts: []Point }

    s: S = { pts = []Point{{1,2}, {3,4}, {5,6}} }

    ser, err := serialize_to_bytes(s)
    testing.expectf(t, err == .ok, "serialize err: %v", err)

    s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
    testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
    testing.expect(t, len(s2.pts) == 3, "len mismatch")
    for p, i in s.pts {
        testing.expectf(t, s2.pts[i].x == p.x && s2.pts[i].y == p.y, "pts[%d] mismatch", i)
    }
    free_all(context.temp_allocator)
}

@test
test_seri_append_multiple_messages :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    using runtime
    buf := make([dynamic]u8)

    A :: struct { n: i32 }
    B :: struct { s: string }

    a: A = {n = 321}
    b: B = {s = "second"}

    err1 := serialize_to_bytes_append(a, &buf)
    testing.expectf(t, err1 == .ok, "append a err: %v", err1)
    off0 := 0
    size0 : u32 = (cast(^u32)&buf[off0])^

    err2 := serialize_to_bytes_append(b, &buf)
    testing.expectf(t, err2 == .ok, "append b err: %v", err2)
    off1 := size0
    size1 : u32 = (cast(^u32)&buf[off1])^

    // Deserialize first message
    a2, e1 := deserialize_from_bytes(A, buf[off0:off0+int(size0)], context.temp_allocator)
    testing.expectf(t, e1 == .ok && a2.n == a.n, "first message roundtrip failed: %v", e1)

    // Deserialize second message
    b2, e2 := deserialize_from_bytes(B, buf[off1:off1+size1], context.temp_allocator)
    testing.expectf(t, e2 == .ok && b2.s == b.s, "second message roundtrip failed: %v", e2)

    free_all(context.temp_allocator)
    delete(buf)
}

@test
test_seri_cstring_not_supported :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
    S :: struct { cs: cstring }
    s: S = { cs = "hi" }

    ser, err := serialize_to_bytes(s)
    _ = ser
    testing.expectf(t, err == .type_not_supported, "expected .type_not_supported, got %v", err)
}

@test
test_i64_roundtrip_single :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
	S :: struct { handle : i64 }
	s : S = { handle = 1 }

	ser, err := serialize_to_bytes(s)
	testing.expectf(t, err == .ok, "serialize err: %v", err)

	// header should be payload size = 8 + header itself for a single i64
	header : u32 = (cast(^u32)&ser[0])^
	testing.expectf(t, header == 12, "header %v != 12", header)

	s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
	testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
	testing.expectf(t, s2.handle == s.handle, "i64 roundtrip mismatch %v != %v", s2.handle, s.handle)
	free_all(context.temp_allocator)
}

@test
test_i64_cross_32bit_boundary_bytes :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
	S :: struct { handle : i64 }
	// 4294967308 = 2^32 + 12 -> bytes LE: 0C 00 00 00 01 00 00 00
	s : S = { handle = 4294967308 }

	ser, err := serialize_to_bytes(s)
	testing.expectf(t, err == .ok, "serialize err: %v", err)

	// Validate payload bytes for i64 after 4-byte header
	expected : [8]u8 = {0x0C, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00}
	for b, i in expected {
		actual := ser[4 + i]
		testing.expectf(t, actual == b, "byte[%d] %v != %v", i, actual, b)
	}

	s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
	testing.expectf(t, err2 == .ok && s2.handle == s.handle, "i64 cross-boundary roundtrip failed: %v, got %v", err2, s2.handle)
	free_all(context.temp_allocator)
}

@test
test_network_like_frame_i64 :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
	S :: struct { handle : i64 }
	s : S = { handle = 1 }

	ser, err := serialize_to_bytes(s)
	testing.expectf(t, err == .ok, "serialize err: %v", err)

	// Simulate network frame: [u32 message_id][ser]
	message_id : u32 = 999
	frame := make([dynamic]u8, size_of(u32) + len(ser))
	runtime.mem_copy(&frame[0], &message_id, size_of(u32))
	runtime.mem_copy(&frame[size_of(u32)], &ser[0], len(ser))

	// Receiver passes header+payload (after message id) into deserializer
	s2, err2 := deserialize_from_bytes(S, frame[size_of(u32):], context.temp_allocator)
	testing.expectf(t, err2 == .ok && s2.handle == s.handle, "network-like frame roundtrip failed: %v, got %v", err2, s2.handle)
	delete(frame)
	free_all(context.temp_allocator)
}

@test
test_struct_with_string_and_i64 :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator;
	S :: struct { name: string, handle: i64 }
	s : S = { name = "sim", handle = 1 }

	ser, err := serialize_to_bytes(s)
	testing.expectf(t, err == .ok, "serialize err: %v", err)
	s2, err2 := deserialize_from_bytes(S, ser[:], context.temp_allocator)
	testing.expectf(t, err2 == .ok, "deserialize err: %v", err2)
	testing.expect(t, s2.name == s.name && s2.handle == s.handle, "string+i64 roundtrip mismatch")
	free_all(context.temp_allocator)
}
