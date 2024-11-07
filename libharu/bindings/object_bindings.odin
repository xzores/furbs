package libharu_bindings

/*
	Bindings for libharu, translated by Jakob Furbo Enevoldsen, 2024
	
	Translated by hand expect mistakes.
*/

import "core:c"

Obj_Header :: struct {
    obj_id   : u32,
    gen_no   : u16,
    obj_class: u16
}

Null_Rec :: struct {
    header : Obj_Header
}

Null :: ^Null_Rec

Boolean_Rec :: struct {
    header : Obj_Header,
    value  : bool
}

Boolean :: ^Boolean_Rec


Number_Rec :: struct {
    header : Obj_Header,
    value  : i32
}

Number :: ^Number_Rec


Real_Rec :: struct {
    header : Obj_Header,
    error  : Error,
    value  : f64
}

Real :: ^Real_Rec

Name_Rec :: struct {
    header : Obj_Header,
    error  : Error,
    value  : [LIMIT_MAX_NAME_LEN + 1]u8
}

Name :: ^Name_Rec

String_Rec :: struct {
    header  : Obj_Header,
    mmgr    : MMgr,
    error   : Error,
    encoder : Encoder,
    value   : [^]u8,       // pointer to byte array (HPDF_BYTE)
    len     : u32        // length (HPDF_UINT is typically unsigned 32-bit)
}

String :: ^String_Rec

Binary_Rec :: struct {
    header  : Obj_Header,
    mmgr    : MMgr,
    error   : Error,
    value   : ^u8,       // pointer to byte array (HPDF_BYTE)
    len     : u32        // length (HPDF_UINT is typically unsigned 32-bit)
}

Binary :: ^Binary_Rec

Dict :: ^Dict_Rec

Dict_FreeFunc :: proc "c" (obj : Dict)
Dict_BeforeWriteFunc :: proc "c" (obj : Dict) -> STATUS
Dict_AfterWriteFunc :: proc "c" (obj : Dict) -> STATUS
Dict_OnWriteFunc :: proc "c" (obj : Dict, stream : Stream) -> STATUS

Dict_Rec :: struct {
    header               : Obj_Header,
    mmgr                 : MMgr,
    error                : Error,
    list                 : List,
    before_write_fn      : Dict_BeforeWriteFunc,
    write_fn             : Dict_OnWriteFunc,
    after_write_fn       : Dict_AfterWriteFunc,
    free_fn              : Dict_FreeFunc,
    stream               : Stream,
    filter               : UINT,
    filterParams         : Dict,
    attr                 : rawptr,
}

DictElement_Rec :: struct {
    key   : [LIMIT_MAX_NAME_LEN + 1]cchar,
    value : rawptr,
}

DictElement :: ^DictElement_Rec

Proxy :: ^Proxy_Rec

Proxy_Rec :: struct {
    header : Obj_Header,
    obj    : rawptr,
}


Array_Rec :: struct {
    header  : Obj_Header,
    mmgr    : MMgr,
    error   : Error,
    list    : List
}

Array :: ^Array_Rec


XrefEntry :: ^XrefEntry_Rec

XrefEntry_Rec :: struct {
    entry_typ   : u8,
    byte_offset : u32,
    gen_no      : u16,
    obj         : rawptr,
}

Xref :: ^Xref_Rec;

Xref_Rec :: struct {
    mmgr      : MMgr,
    error     : Error,
    start_offset : u32,
    entries   : List,
    addr      : u32,
    prev      : Xref,
    trailer   : Dict
}

EmbeddedFile   :: Dict;
NameDict       :: Dict;
NameTree       :: Dict;
Pages          :: Dict;
Page           :: Dict;
Annotation     :: Dict;
Measure3D      :: Dict;
ExData         :: Dict;
XObject        :: Dict;
Image          :: Dict;
Outline        :: Dict;
EncryptDict    :: Dict;
Action         :: Dict;
ExtGState      :: Dict;
Destination    :: Array;
U3D            :: Dict;
OutputIntent   :: Dict;
JavaScript     :: Dict;
Shading        :: Dict;

Direct :: ^DirectRec;

DirectRec :: struct {
    header  : Obj_Header,
    mmgr    : MMgr,
    error   : Error,
    value   : ^BYTE,
    len     : UINT,
};
