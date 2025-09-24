package serialize

import "core:fmt"
import "core:testing"
import "core:math/rand"

// ---------- Types under test (from your snippet) ----------
Transient_simulation :: struct {
    start_time    : f64,
    stop_time     : f64,
    time_step     : f64,
    max_time_step : f64,
    use_uic       : bool,
}

Ac_spacing :: enum { dec, oct, lin }

Ac_simulation :: struct {
    spacing   : Ac_spacing,
    start_freq: f64,
    stop_freq : f64,
    freq_res  : f64,
}

Dc_target :: enum { source, param }

Dc_simulation :: struct {
    target     : Dc_target,
    name       : string,
    start_value: f64,
    stop_value : f64,
    step_value : f64,
}

Simulation_type :: union {
    Transient_simulation,
    Ac_simulation,
    Dc_simulation,
}

Ng_method :: enum { Trap, Gear }

Sim_options :: struct {
    // Accuracy / tolerances
    reltol  : f64,
    vabstol : f64,   // V
    iabstol : f64,   // A
    chgtol  : f64,   // C

    // Integration / timestep
    method  : Ng_method,
    trtol   : f64,   // 1..7
    maxord  : i32,   // 1..2
    maxstep : f64,   // seconds; <=0 means "omit"

    // Temperature
    temp_c  : f64,   // .temp
    tnom_c  : f64,   // .option tnom

    // Convergence / solver
    itl1    : i32,
    itl4    : i32,
    gmin    : f64,
    pivrel  : f64,
    pivtol  : f64,

    // Misc
    numdgt  : i32,
    seed    : u32,   // 0 => omit
}

// ---------- Small destroy helpers (only where needed) ----------
destroy_string :: proc(s: string) {
    bs := transmute([]u8)s
    delete(bs)
}

destroy_simulation_type :: proc(s: ^Simulation_type) {
    // Only Dc_simulation contains a string we must free explicitly
    if ds, ok := s.(Dc_simulation); ok {
        destroy_string(ds.name)
    }
}

// ============================================================
// 1) Enum-in-struct roundtrip (Ac_simulation with all spacings)
// ============================================================
@test
test_enum_in_struct_roundtrip :: proc(t: ^testing.T) {
    rand.reset(1)

    vals := [3]Ac_spacing{.dec, .oct, .lin}
    for sp in vals {
        src := Ac_simulation{
            spacing    = sp,
            start_freq = 1.0,
            stop_freq  = 1e6,
            freq_res   = 123.25,
        }

        ser, err := serialize_to_bytes(src)
		defer delete (ser);
        fmt.assertf(err == .ok, "serialize err: %v", err)

        dst, err2 := deserialize_from_bytes(Ac_simulation, ser[:], context.temp_allocator)
        fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

        fmt.assertf(dst.spacing == src.spacing, "spacing mismatch")
        fmt.assertf(dst.start_freq == src.start_freq && dst.stop_freq == src.stop_freq && dst.freq_res == src.freq_res, "ac fields mismatch")

        free_all(context.temp_allocator)
    }
}

// ============================================================
// 2) Union roundtrip: Transient_simulation variant
// ============================================================
@test
test_union_transient_variant :: proc(t: ^testing.T) {
    src : Simulation_type
    src = Transient_simulation{
        start_time    = 0.0,
        stop_time     = 1e-3,
        time_step     = 1e-6,
        max_time_step = 1e-5,
        use_uic       = true,
    }

    ser, err := serialize_to_bytes(src)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    dst, err2 := deserialize_from_bytes(Simulation_type, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

    tr, ok := dst.(Transient_simulation)
    fmt.assertf(ok, "expected Transient_simulation variant")
    fmt.assertf(tr.use_uic == true && tr.time_step == 1e-6 && tr.max_time_step == 1e-5 && tr.stop_time == 1e-3, "transient fields mismatch")

    free_all(context.temp_allocator)
}

// ============================================================
// 3) Union roundtrip: Ac_simulation variant with each enum value
// ============================================================
@test
test_union_ac_variant_all_spacings :: proc(t: ^testing.T) {
	spcingings : []Ac_spacing = []Ac_spacing{Ac_spacing.dec, Ac_spacing.oct, Ac_spacing.lin};
    for sp in spcingings {
        src : Simulation_type
        src = Ac_simulation{
            spacing    = sp,
            start_freq = 10.0,
            stop_freq  = 2.0e9,
            freq_res   = 1000.0,
        }

        ser, err := serialize_to_bytes(src)
		defer delete(ser);
        fmt.assertf(err == .ok, "serialize err: %v", err)

        dst, err2 := deserialize_from_bytes(Simulation_type, ser[:], context.temp_allocator)
        fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

        ac, ok := dst.(Ac_simulation)
        fmt.assertf(ok, "expected Ac_simulation variant")
        fmt.assertf(ac.spacing == sp, "ac.spacing mismatch")
        fmt.assertf(ac.start_freq == 10.0 && ac.stop_freq == 2.0e9 && ac.freq_res == 1000.0, "ac fields mismatch")

        free_all(context.temp_allocator)
    }
}

// ============================================================
// 4) Union roundtrip: Dc_simulation (enum + string inside union)
// ============================================================
@test
test_union_dc_variant_with_string :: proc(t: ^testing.T) {
    rand.reset(0xD00D)

    // Build a random-ish name (not cstring)
    name_len := 64 + int(rand.int31_max(64))
    nb := make([]u8, name_len)
    _ = rand.read(nb[:])
    nm := string(nb)

    src : Simulation_type
    src = Dc_simulation{
        target      = .param,
        name        = nm,
        start_value = -2.5,
        stop_value  =  2.5,
        step_value  =  0.25,
    }

    // Serialize/deserialize
    ser, err := serialize_to_bytes(src)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    dst, err2 := deserialize_from_bytes(Simulation_type, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

    dc, ok := dst.(Dc_simulation)
    fmt.assertf(ok, "expected Dc_simulation variant")
    fmt.assertf(dc.target == .param, "dc.target mismatch")
    fmt.assertf(dc.name == nm, "dc.name mismatch")
    fmt.assertf(dc.start_value == -2.5 && dc.stop_value == 2.5 && dc.step_value == 0.25, "dc fields mismatch")

    free_all(context.temp_allocator)

    // Explicitly free source string backing
    destroy_string(nm)
}

// ============================================================
// 5) Mixed struct (Sim_options + Simulation_type), both Ng_method values
// ============================================================
@test
test_mixed_options_plus_union :: proc(t: ^testing.T) {
    TestCase :: struct {
        opt : Sim_options,
        sim : Simulation_type,
    }

    make_opts :: proc(m: Ng_method, seed: u32) -> Sim_options {
        return Sim_options{
            reltol  = 1e-3, vabstol = 1e-6, iabstol = 1e-9, chgtol = 1e-14,
            method  = m, trtol = 7.0, maxord = 2, maxstep = 0.0,
            temp_c  = 27.0, tnom_c = 27.0,
            itl1    = 100, itl4 = 50, gmin = 1e-12, pivrel = 1e-3, pivtol = 1e-13,
            numdgt  = 6, seed = seed,
        }
    }

    cases := [2]TestCase{
        TestCase{
            opt = make_opts(.Trap, 0),
            sim = Transient_simulation{ start_time = 0, stop_time = 1e-3, time_step = 1e-6, max_time_step = 0, use_uic = false },
        },
        TestCase{
            opt = make_opts(.Gear, 1234),
            sim = Ac_simulation{ spacing = .lin, start_freq = 1.0, stop_freq = 1e6, freq_res = 10.0 },
        },
    }

    for c in cases {
        ser, err := serialize_to_bytes(c)
		defer delete(ser);
        fmt.assertf(err == .ok, "serialize err: %v", err)

        got, err2 := deserialize_from_bytes(TestCase, ser[:], context.temp_allocator)
        fmt.assertf(err2 == .ok, "deserialize err: %v", err2)

        // options check
        fmt.assertf(got.opt.method == c.opt.method && got.opt.seed == c.opt.seed, "options enum/seed mismatch")

        // union variant + fields
        if tr, ok := c.sim.(Transient_simulation); ok {
            gtr, gok := got.sim.(Transient_simulation)
            fmt.assertf(gok, "expected Transient_simulation")
            fmt.assertf(gtr.stop_time == tr.stop_time && gtr.time_step == tr.time_step && gtr.use_uic == tr.use_uic, "transient mismatch")
        } else if ac, ok := c.sim.(Ac_simulation); ok {
            gac, gok := got.sim.(Ac_simulation)
            fmt.assertf(gok, "expected Ac_simulation")
            fmt.assertf(gac.spacing == ac.spacing && gac.freq_res == ac.freq_res, "ac mismatch")
        } else {
            fmt.assertf(false, "unexpected variant in source case")
        }

        free_all(context.temp_allocator)
    }
}

// ============================================================
// 6) Slice of mixed union variants (incl. multiple Dc with strings)
// ============================================================
@test
test_slice_of_mixed_union_variants :: proc(t: ^testing.T) {
    rand.reset(77)

    // Build a mixed slice: [Transient, Ac(lin), Dc("V1"), Dc("V2"), Ac(oct)]
    sims := make([]Simulation_type, 5)
    // 0: Transient
    sims[0] = Transient_simulation{ start_time = 0, stop_time = 2e-3, time_step = 5e-6, max_time_step = 0, use_uic = true }
    // 1: Ac(lin)
    sims[1] = Ac_simulation{ spacing = .lin, start_freq = 10.0, stop_freq = 1e5, freq_res = 123.0 }
    // 2: Dc with random name
    {
        ln := 20 + int(rand.int31_max(20))
        b := make([]u8, ln); _ = rand.read(b[:])
        sims[2] = Dc_simulation{ target = .source, name = string(b), start_value = 0, stop_value = 5, step_value = 0.5 }
    }
    // 3: Another Dc
    {
        ln := 10 + int(rand.int31_max(10))
        b := make([]u8, ln); _ = rand.read(b[:])
        sims[3] = Dc_simulation{ target = .param, name = string(b), start_value = -1, stop_value = 1, step_value = 0.1 }
    }
    // 4: Ac(oct)
    sims[4] = Ac_simulation{ spacing = .oct, start_freq = 1.0, stop_freq = 1e6, freq_res = 42.0 }

    // Serialize/deserialize
    ser, err := serialize_to_bytes(sims)
	defer delete(ser);
    fmt.assertf(err == .ok, "serialize err: %v", err)

    got, err2 := deserialize_from_bytes([]Simulation_type, ser[:], context.temp_allocator)
    fmt.assertf(err2 == .ok, "deserialize err: %v", err2)
    fmt.assertf(len(got) == len(sims), "length mismatch")

    // Compare element-wise
    // 0 transient
    g0, ok0 := got[0].(Transient_simulation); fmt.assertf(ok0, "idx0 not transient")
    s0, _   := sims[0].(Transient_simulation)
    fmt.assertf(g0.stop_time == s0.stop_time && g0.time_step == s0.time_step && g0.use_uic == s0.use_uic, "idx0 mismatch")

    // 1 ac(lin)
    g1, ok1 := got[1].(Ac_simulation); fmt.assertf(ok1, "idx1 not ac")
    s1, _   := sims[1].(Ac_simulation)
    fmt.assertf(g1.spacing == s1.spacing && g1.freq_res == s1.freq_res, "idx1 mismatch")

    // 2 dc
    g2, ok2 := got[2].(Dc_simulation); fmt.assertf(ok2, "idx2 not dc")
    s2, _   := sims[2].(Dc_simulation)
    fmt.assertf(g2.target == s2.target && g2.name == s2.name && g2.step_value == s2.step_value, "idx2 mismatch")

    // 3 dc
    g3, ok3 := got[3].(Dc_simulation); fmt.assertf(ok3, "idx3 not dc")
    s3, _   := sims[3].(Dc_simulation)
    fmt.assertf(g3.target == s3.target && g3.name == s3.name && g3.start_value == s3.start_value, "idx3 mismatch")

    // 4 ac(oct)
    g4, ok4 := got[4].(Ac_simulation); fmt.assertf(ok4, "idx4 not ac")
    s4, _   := sims[4].(Ac_simulation)
    fmt.assertf(g4.spacing == s4.spacing && g4.start_freq == s4.start_freq, "idx4 mismatch")

    free_all(context.temp_allocator)

    // Explicitly destroy any Dc_simulation source strings
    for i := 0; i < len(sims); i += 1 {
        destroy_simulation_type(&sims[i])
    }
    delete(sims)
}
