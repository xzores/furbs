package libharu_bindings


/*
	Bindings for libharu, translated by Jakob Furbo Enevoldsen, 2024
	
	Translated by hand expect mistakes.
*/

import "core:c"


INT  :: i32;  // signed int
UINT :: u32; 

// float type (32-bit IEEE754)
REAL   :: f32;    // float

// double type (64-bit IEEE754)
DOUBLE :: f64;    // double

// boolean type (0: False, !0: True)
BOOL   :: b32;    // signed int

// error-no type (32-bit unsigned integer)
STATUS :: u32;    // unsigned long

BYTE   :: u8;     // unsigned char

// character-code type (16-bit)
CID    :: u16;    // UINT16
UNICODE:: u16;    // UINT16

cchar :: c.char;


// HPDF_Point struct
Point :: struct {
    x : REAL,
    y : REAL,
}

// HPDF_Rect struct
Rect :: struct {
    left   : REAL,
    bottom : REAL,
    right  : REAL,
    top    : REAL,
}

// HPDF_Point3D struct
Point3D :: struct {
    x : REAL,
    y : REAL,
    z : REAL,
}

Box :: Rect // HPDF_Box is a synonym for HPDF_Rect

// HPDF_Date struct
Date :: struct {
    year    : INT,
    month   : INT,
    day     : INT,
    hour    : INT,
    minutes : INT,
    seconds : INT,
    ind     : cchar,
    off_hour: INT,
    off_minutes : INT,
}

// HPDF_InfoType enum
InfoType :: enum i32 {
    // date-time type parameters
    INFO_CREATION_DATE = 0,
    INFO_MOD_DATE,

    // string type parameters
    INFO_AUTHOR,
    INFO_CREATOR,
    INFO_PRODUCER,
    INFO_TITLE,
    INFO_SUBJECT,
    INFO_KEYWORDS,
    INFO_TRAPPED,
    INFO_GTS_PDFX,
    INFO_EOF,
}

// PDF-A Types enum
PDFAType :: enum i32 {
    PDFA_1A = 0,
    PDFA_1B = 1,
}

// HPDF_PdfVer enum
PDFVer :: enum i32 {
    VER_12 = 0,
    VER_13,
    VER_14,
    VER_15,
    VER_16,
    VER_17,
    VER_EOF,
}

// HPDF_EncryptMode enum
EncryptMode :: enum i32 {
    ENCRYPT_R2 = 2,
    ENCRYPT_R3 = 3,
}

Error_Handler :: #type proc "c" (error_no: STATUS, detail_no: STATUS, user_data: rawptr);
Alloc_Func :: #type proc "c" (size: UINT) -> rawptr;
Free_Func :: #type proc "c" (aptr: rawptr);

TextWidth :: struct {
    numchars : UINT,
    
    // don't use this value (it may change in the future).
    // use numspace as an alternate.
    numwords : UINT,

    width : UINT,
    numspace : UINT,
};


DashMode :: struct {
    ptn      : [8]REAL,
    num_ptn  : UINT,
    phase    : REAL,
};

TransMatrix :: struct {
    a : REAL,
    b : REAL,
    c : REAL,
    d : REAL,
    x : REAL,
    y : REAL,
};

_3DMatrix :: struct {
    a : REAL,
    b : REAL,
    c : REAL,
    d : REAL,
    e : REAL,
    f : REAL,
    g : REAL,
    h : REAL,
    i : REAL,
    tx : REAL,
    ty : REAL,
    tz : REAL,
};

ColorSpace :: enum i32 {
    CS_DEVICE_GRAY          = 0,
    CS_DEVICE_RGB,
    CS_DEVICE_CMYK,
    CS_CAL_GRAY,
    CS_CAL_RGB,
    CS_LAB,
    CS_ICC_BASED,
    CS_SEPARATION,
    CS_DEVICE_N,
    CS_INDEXED,
    CS_PATTERN,
    CS_EOF,
};

RGBColor :: struct {
    r : REAL,
    g : REAL,
    b : REAL,
};

CMYKColor :: struct {
    c : REAL,
    m : REAL,
    y : REAL,
    k : REAL,
};

LineCap :: enum i32 {
    BUTT_END              = 0,
    ROUND_END,
    PROJECTING_SQUARE_END,
    LINECAP_EOF,
};

LineJoin :: enum i32 {
    MITER_JOIN            = 0,
    ROUND_JOIN,
    BEVEL_JOIN,
    LINEJOIN_EOF,
};


TextRenderingMode :: enum i32 {
    FILL                   = 0,
    STROKE,
    FILL_THEN_STROKE,
    INVISIBLE,
    FILL_CLIPPING,
    STROKE_CLIPPING,
    FILL_STROKE_CLIPPING,
    CLIPPING,
    RENDERING_MODE_EOF,
};

WritingMode :: enum i32 {
    WMODE_HORIZONTAL      = 0,
    WMODE_VERTICAL,
    WMODE_EOF,
};

PageLayout :: enum i32 {
    PAGE_LAYOUT_SINGLE    = 0,
    PAGE_LAYOUT_ONE_COLUMN,
    PAGE_LAYOUT_TWO_COLUMN_LEFT,
    PAGE_LAYOUT_TWO_COLUMN_RIGHT,
    PAGE_LAYOUT_TWO_PAGE_LEFT,
    PAGE_LAYOUT_TWO_PAGE_RIGHT,
    PAGE_LAYOUT_EOF,
};

PageMode :: enum i32 {
    PAGE_MODE_USE_NONE    = 0,
    PAGE_MODE_USE_OUTLINE,
    PAGE_MODE_USE_THUMBS,
    PAGE_MODE_FULL_SCREEN,
    PAGE_MODE_EOF,
};

PageNumStyle :: enum i32 {
    PAGE_NUM_STYLE_DECIMAL     = 0,
    PAGE_NUM_STYLE_UPPER_ROMAN,
    PAGE_NUM_STYLE_LOWER_ROMAN,
    PAGE_NUM_STYLE_UPPER_LETTERS,
    PAGE_NUM_STYLE_LOWER_LETTERS,
    PAGE_NUM_STYLE_EOF,
};

DestinationType :: enum i32 {
    XYZ            = 0,
    FIT,
    FIT_H,
    FIT_V,
    FIT_R,
    FIT_B,
    FIT_BH,
    FIT_BV,
    DST_EOF,
};

AnnotType :: enum i32 {
    ANNOT_TEXT_NOTES,
    ANNOT_LINK,
    ANNOT_SOUND,
    ANNOT_FREE_TEXT,
    ANNOT_STAMP,
    ANNOT_SQUARE,
    ANNOT_CIRCLE,
    ANNOT_STRIKE_OUT,
    ANNOT_HIGHTLIGHT,
    ANNOT_UNDERLINE,
    ANNOT_INK,
    ANNOT_FILE_ATTACHMENT,
    ANNOT_POPUP,
    ANNOT_3D,
    ANNOT_SQUIGGLY,
    ANNOT_LINE,
    ANNOT_PROJECTION,
    ANNOT_WIDGET,
};

AnnotFlgs :: enum i32 {
    ANNOT_INVISIBLE,
    ANNOT_HIDDEN,
    ANNOT_PRINT,
    ANNOT_NOZOOM,
    ANNOT_NOROTATE,
    ANNOT_NOVIEW,
    ANNOT_READONLY,
};

AnnotHighlightMode :: enum i32 {
    ANNOT_NO_HIGHTLIGHT     = 0,
    ANNOT_INVERT_BOX,
    ANNOT_INVERT_BORDER,
    ANNOT_DOWN_APPEARANCE,
    ANNOT_HIGHTLIGHT_MODE_EOF,
};

AnnotIcon :: enum i32 {
    ANNOT_ICON_COMMENT      = 0,
    ANNOT_ICON_KEY,
    ANNOT_ICON_NOTE,
    ANNOT_ICON_HELP,
    ANNOT_ICON_NEW_PARAGRAPH,
    ANNOT_ICON_PARAGRAPH,
    ANNOT_ICON_INSERT,
    ANNOT_ICON_EOF,
};

AnnotIntent :: enum i32 {
    ANNOT_INTENT_FREETEXTCALLOUT = 0,
    ANNOT_INTENT_FREETEXTTYPEWRITER,
    ANNOT_INTENT_LINEARROW,
    ANNOT_INTENT_LINEDIMENSION,
    ANNOT_INTENT_POLYGONCLOUD,
    ANNOT_INTENT_POLYLINEDIMENSION,
    ANNOT_INTENT_POLYGONDIMENSION,
};

LineAnnotEndingStyle :: enum i32 {
    LINE_ANNOT_NONE          = 0,
    LINE_ANNOT_SQUARE,
    LINE_ANNOT_CIRCLE,
    LINE_ANNOT_DIAMOND,
    LINE_ANNOT_OPENARROW,
    LINE_ANNOT_CLOSEDARROW,
    LINE_ANNOT_BUTT,
    LINE_ANNOT_ROPENARROW,
    LINE_ANNOT_RCLOSEDARROW,
    LINE_ANNOT_SLASH,
};

LineAnnotCapPosition :: enum i32 {
    LINE_ANNOT_CAP_INLINE    = 0,
    LINE_ANNOT_CAP_TOP,
};

StampAnnotName :: enum i32 {
    STAMP_ANNOT_APPROVED       = 0,
    STAMP_ANNOT_EXPERIMENTAL,
    STAMP_ANNOT_NOTAPPROVED,
    STAMP_ANNOT_ASIS,
    STAMP_ANNOT_EXPIRED,
    STAMP_ANNOT_NOTFORPUBLICRELEASE,
    STAMP_ANNOT_CONFIDENTIAL,
    STAMP_ANNOT_FINAL,
    STAMP_ANNOT_SOLD,
    STAMP_ANNOT_DEPARTMENTAL,
    STAMP_ANNOT_FORCOMMENT,
    STAMP_ANNOT_TOPSECRET,
    STAMP_ANNOT_DRAFT,
    STAMP_ANNOT_FORPUBLICRELEASE,
};

// BS Subtype
BSSubtype :: enum i32 {
    SOLID,
    DASHED,
    BEVELED,
    INSET,
    UNDERLINED
}

// Blend Modes
BlendMode :: enum i32 {
    NORMAL,
    MULTIPLY,
    SCREEN,
    OVERLAY,
    DARKEN,
    LIGHTEN,
    COLOR_DODGE,
    COLOR_BUM,
    HARD_LIGHT,
    SOFT_LIGHT,
    DIFFERENCE,
    EXCLUSHON,
    EOF
}

// Slide Show Transition Styles
TransitionStyle :: enum i32 {
    WIPE_RIGHT = 0,
    WIPE_UP,
    WIPE_LEFT,
    WIPE_DOWN,
    BARN_DOORS_HORIZONTAL_OUT,
    BARN_DOORS_HORIZONTAL_IN,
    BARN_DOORS_VERTICAL_OUT,
    BARN_DOORS_VERTICAL_IN,
    BOX_OUT,
    BOX_IN,
    BLINDS_HORIZONTAL,
    BLINDS_VERTICAL,
    DISSOLVE,
    GLITTER_RIGHT,
    GLITTER_DOWN,
    GLITTER_TOP_LEFT_TO_BOTTOM_RIGHT,
    REPLACE,
    EOF
}

// Page Sizes
PageSizes :: enum i32 {
    LETTER = 0,
    LEGAL,
    A3,
    A4,
    A5,
    B4,
    B5,
    EXECUTIVE,
    US4x6,
    US4x8,
    US5x7,
    COMM10,
    EOF
}

// Page Direction
PageDirection :: enum i32 {
    PORTRAIT = 0,
    LANDSCAPE
}

// Encoder Types
EncoderType :: enum i32 {
    SINGLE_BYTE,
    DOUBLE_BYTE,
    UNINITIALIZED,
    UNKNOWN
}

// Byte Types
ByteType :: enum i32 {
    SINGLE = 0,
    LEAD,
    TRAIL,
    UNKNOWN
}

// Text Alignment
TextAlignment :: enum i32 {
    LEFT = 0,
    RIGHT,
    CENTER,
    JUSTIFY
}

// Name Dictionary Keys
NameDictKey :: enum i32 {
    EMBEDDED_FILES = 0,    // TODO the rest
    EOF
}

// Page Boundary
PageBoundary :: enum i32 {
    MEDIABOX = 0,
    CROPBOX,
    BLEEDBOX,
    TRIMBOX,
    ARTBOX
}

// Shading Types
ShadingType :: enum i32 {
    FREE_FORM_TRIANGLE_MESH = 4 // TODO the rest
}

// Shading FreeForm Triangle Mesh Edge Flags
Shading_FreeFormTriangleMeshEdgeFlag :: enum i32 {
    FREE_FORM_TRI_MESH_EDGEFLAG_NO_CONNECTION = 0,
    FREE_FORM_TRI_MESH_EDGEFLAG_BC,
    FREE_FORM_TRI_MESH_EDGEFLAG_AC
}

EncodingType :: enum i32 {
    STANDARD_ENCODING     = 0,
    MAC_ROMAN_ENCODING,
    WIN_ANSI_ENCODING,
    FONT_SPECIFIC,
    ENCODING_EOF
}