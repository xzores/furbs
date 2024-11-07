package libharu_bindings

/*
	Bindings for libharu, translated by Jakob Furbo Enevoldsen, 2024
	
	Translated by hand expect mistakes.
*/

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "libharu/hpdf.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "libharu/hpdf.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "libharu/hpdf.dylib"
}

Catalog :: Dict;

ParseText_Rec :: struct {
	text		: ^BYTE,
	index		: u32,
	len			: u32,
	byte_type   : ByteType,
}

Encoder :: ^Encoder_Rec;

Encoder_ByteType_Func :: proc "c" (encoder: Encoder, state: ^ParseText_Rec) -> ByteType;
Encoder_ToUnicode_Func :: proc "c" (encoder: Encoder, code: u16) -> u16;
Encoder_EncodeText_Func :: proc "c" (encoder: Encoder, text: ^cchar, len: u32, encoded_length: ^u32) -> ^cchar;
Encoder_Write_Func :: proc "c" (encoder: Encoder, out: Stream) -> STATUS;
Encoder_Init_Func :: proc "c" (encoder: Encoder) -> STATUS;
Encoder_Free_Func :: proc "c" (encoder: Encoder);

Encoder_Rec :: struct {
	sig_bytes	  : u32,
	name		   : [LIMIT_MAX_NAME_LEN + 1]cchar,
	mmgr		   : MMgr,
	error		  : Error,
	type_		  : EncoderType,

	byte_type_fn   : Encoder_ByteType_Func,
	to_unicode_fn  : Encoder_ToUnicode_Func,
	encode_text_fn : Encoder_EncodeText_Func,
	write_fn	   : Encoder_Write_Func,
	free_fn		: Encoder_Free_Func,
	init_fn		: Encoder_Init_Func,
	
	attr		   : rawptr,
}

BaseEncodings :: enum i32 {
	BASE_ENCODING_STANDARD,
	BASE_ENCODING_WIN_ANSI,
	BASE_ENCODING_MAC_ROMAN,
	BASE_ENCODING_FONT_SPECIFIC,
	BASE_ENCODING_EOF
}

BasicEncoderAttr :: ^BasicEncoderAttr_Rec;

BasicEncoderAttr_Rec :: struct {
	base_encoding  : [LIMIT_MAX_NAME_LEN + 1]cchar,
	first_char	 : BYTE,
	last_char	  : BYTE,
	unicode_map	: [256]UNICODE,  // HPDF_UNICODE
	has_differences: BOOL,
	differences	: [256]BYTE,
}

CMapEncoder_ByteType_Func :: proc "c" (encoder: Encoder, b: BYTE) -> BOOL;

CidRange_Rec :: struct {
	from  : u16,
	to	: u16,
	cid   : u16,
}

UnicodeMap_Rec :: struct {
	code	 : u16,
	unicode  : u16,
}

MAX_JWW_NUM :: 128;

CMapEncoderAttr :: ^CMapEncoderAttr_Rec;

CMapEncoderAttr_Rec :: struct {
	unicode_map		  : [256][256]UNICODE,  // HPDF_UNICODE
	cid_map			  : [256][256]u16,
	jww_line_head		: [MAX_JWW_NUM]u16,
	cmap_range		   : List,
	notdef_range		 : List,
	code_space_range	 : List,
	writing_mode		 : WritingMode,
	registry			 : [LIMIT_MAX_NAME_LEN + 1]cchar,
	ordering			 : [LIMIT_MAX_NAME_LEN + 1]cchar,
	suppliment		   : i32,
	is_lead_byte_fn	  : CMapEncoder_ByteType_Func,
	is_trial_byte_fn	 : CMapEncoder_ByteType_Func,
	uid_offset		   : i32,
	xuid				 : [3]u32,
}

ID_LEN			:: 16
PASSWD_LEN		:: 32
ENCRYPT_KEY_MAX   :: 16
MD5_KEY_LEN	   :: 16
PERMISSION_PAD	:: 0xFFFFFFC0
ARC4_BUF_SIZE	 :: 256

MD5_CTX :: struct {
	buf   : [4]u32,
	bits  : [2]u32,
	in_	: [64]BYTE,
}

ARC4_Ctx_Rec :: struct {
	idx1  : BYTE,
	idx2  : BYTE,
	state : [ARC4_BUF_SIZE]BYTE,
}

Encrypt :: ^Encrypt_Rec;

Encrypt_Rec :: struct {
	mode				: EncryptMode,
	key_len			   	: u32,  // key_len must be a multiple of 8, and between 40 to 128
	owner_passwd		: [PASSWD_LEN]BYTE,
	user_passwd		   	: [PASSWD_LEN]BYTE,
	owner_key			: [PASSWD_LEN]BYTE,
	user_key			: [PASSWD_LEN]BYTE,
	permission			: i32,
	encrypt_id			: [ID_LEN]BYTE,
	encryption_key		: [MD5_KEY_LEN + 5]BYTE,
	md5_encryption_key	: [MD5_KEY_LEN]BYTE,
	arc4ctx			   	: ARC4_Ctx_Rec,
}

FontType :: enum i32 {
	FONT_TYPE1	  = 0,
	FONT_TRUETYPE,
	FONT_TYPE3,
	FONT_TYPE0_CID,
	FONT_TYPE0_TT,
	FONT_CID_TYPE0,
	FONT_CID_TYPE2,
	FONT_MMTYPE1,
}

Font :: ^Dict;

Font_TextWidths_Func :: proc "c" (font: Font, text: ^u8, len: u32) -> TextWidth;

Font_MeasureText_Func :: proc "c" (font: Font, text: ^u8, len: u32, width: f32, fontsize: f32, charspace: f32, wordspace: f32, wordwrap: bool, real_width: ^f32) -> u32;

FontAttr :: ^FontAttr_Rec;

FontAttr_Rec :: struct {
	type			   : FontType,
	writing_mode	   : WritingMode,
	text_width_fn	  : Font_TextWidths_Func,
	measure_text_fn	: Font_MeasureText_Func,
	fontdef			: FontDef,
	encoder			: Encoder,

	// if the encoding-type is HPDF_ENCODER_TYPE_SINGLE_BYTE, the width of each character is cached in 'widths'.
	// when HPDF_ENCODER_TYPE_DOUBLE_BYTE, the width is calculated each time.
	widths			 : ^i16,
	used			   : ^u8,

	xref			   : Xref,
	descendant_font	: Font,
	map_stream		 : Dict,
	cmap_stream		: Dict,
}


CIDFontDefAttr :: ^CIDFontDefAttr_Rec;

CIDFontDefAttr_Rec :: struct {
	widths  : List,
	DW	  : i16,
	DW2	 : [2]i16,
}

TTF_GryphOffsets :: struct {
	base_offset  : u32,
	offsets	  : ^u32,
	flgs		 : ^u8,  // 0: unused, 1: used
}

TTF_LongHorMetric :: struct {
	advance_width : u16,
	lsb		   : i16,
}

TTF_FontHeader :: struct {
	version_number	  : [4]u8,
	font_revision	   : u32,
	check_sum_adjustment: u32,
	magic_number		: u32,
	flags			   : u16,
	units_per_em		: u16,
	created			 : [8]u8,
	modified			: [8]u8,
	x_min			   : i16,
	y_min			   : i16,
	x_max			   : i16,
	y_max			   : i16,
	mac_style		   : u16,
	lowest_rec_ppem	 : u16,
	font_direction_hint : i16,
	index_to_loc_format : i16,
	glyph_data_format   : i16,
}

TTF_NameRecord :: struct {
	platform_id  : u16,
	encoding_id  : u16,
	language_id  : u16,
	name_id	  : u16,
	length	   : u16,
	offset	   : u16,
}

TTF_NamingTable :: struct {
	format		: u16,
	count		 : u16,
	string_offset : u16,
	name_records  : ^TTF_NameRecord,
}

TTFontDefAttr :: ^TTFontDefAttr_Rec;

TTFontDefAttr_Rec :: struct {
	base_font		: [LIMIT_MAX_NAME_LEN + 1]cchar,
	first_char	   : byte,
	last_char		: byte,
	char_set		 : ^cchar,
	tag_name		 : [TTF_FONT_TAG_LEN + 1]cchar,
	tag_name2		: [(TTF_FONT_TAG_LEN + 1) * 2]cchar,
	header		   : TTF_FontHeader,
	glyph_tbl		: TTF_GryphOffsets,
	num_glyphs	   : u16,
	name_tbl		 : TTF_NamingTable,
	h_metric		 : ^TTF_LongHorMetric,
	num_h_metric	 : u16,
	offset_tbl	   : TTF_OffsetTbl,
	cmap			 : TTF_CmapRange,
	fs_type		  : u16,
	sfamilyclass	 : [2]byte,
	panose		   : [10]byte,
	code_page_range1 : u32,
	code_page_range2 : u32,
	length1		  : u32,
	embedding		: bool,
	is_cidfont	   : bool,
	stream		   : Stream,
};

TTF_FONT_TAG_LEN  :: 6

TTFTable :: struct {
	tag		 : [4]cchar,
	check_sum   : u32,
	offset	  : u32,
	length	  : u32,
};

TTF_OffsetTbl :: struct {
	sfnt_version	  : u32,
	num_tables		: u16,
	search_range	  : u16,
	entry_selector	: u16,
	range_shift	   : u16,
	table			 : ^TTFTable,
};

TTF_CmapRange :: struct {
	format			: u16,
	length			: u16,
	language		  : u16,
	seg_count_x2	  : u16,
	search_range	  : u16,
	entry_selector	: u16,
	range_shift	   : u16,
	end_count		 : ^u16,
	reserved_pad	  : u16,
	start_count	   : ^u16,
	id_delta		  : ^i16,
	id_range_offset   : ^u16,
	glyph_id_array	: ^u16,
	glyph_id_array_count : UINT,
};

Type1FontDefAttr :: ^Type1FontDefAttr_Rec;

Type1FontDefAttr_Rec :: struct {
	first_char	  : BYTE,					 // Required
	last_char	   : BYTE,					 // Required
	widths		  : ^CharData,				// Required
	widths_count	: UINT,
	
	leading		 : i16,
	char_set		: ^cchar,
	encoding_scheme : [LIMIT_MAX_NAME_LEN + 1]cchar, // Adjusted size for encoding scheme
	length1		 : UINT,
	length2		 : UINT,
	length3		 : UINT,
	is_base14font   : BOOL,
	is_fixed_pitch  : BOOL,

	font_data	   : Stream,
};

CharData :: struct {
	char_cd : i16,
	unicode : UNICODE,
	width   : i16,
}

FontDefType :: enum i32 {
	FONTDEF_TYPE_TYPE1,
	FONTDEF_TYPE_TRUETYPE,
	FONTDEF_TYPE_CID,
	FONTDEF_TYPE_UNINITIALIZED,
	FONTDEF_TYPE_EOF,
}

CID_Width :: struct {
	cid   : u16,
	width : i16,
}

FontDef_FreeFunc :: #type proc(fontdef : FontDef);
FontDef_CleanFunc :: #type proc(fontdef : FontDef);
FontDef_InitFunc :: #type proc(fontdef : FontDef) -> STATUS;

LIMIT_MAX_NAME_LEN :: 127

FontDef :: ^FontDef_Rec;

FontDef_Rec :: struct {
	sig_bytes	 : u32,
	base_font	 : [LIMIT_MAX_NAME_LEN + 1]cchar,
	mmgr		  : MMgr,
	error		 : Error,
	type		  : FontDefType,
	clean_fn	  : FontDef_CleanFunc,
	free_fn	   : FontDef_FreeFunc,
	init_fn	   : FontDef_InitFunc,

	ascent		: i16,
	descent	   : i16,
	flags		 : u32,
	font_bbox	 : Box,
	italic_angle  : i16,
	stemv		 : u16,
	avg_width	 : i16,
	max_width	 : i16,
	missing_width : i16,
	stemh		 : u16,
	x_height	  : u16,
	cap_height	: u16,

	descriptor	: Dict,	 // Changed to Dict without the pointer
	data		  : Stream,

	valid		 : bool,
	attr		  : rawptr,
}

GState :: ^GState_Rec;

GState_Rec :: struct {
	trans_matrix 	: TransMatrix,
	line_width 		: REAL,
	line_cap 		: LineCap,
	line_join		: LineJoin,
	miter_limit 	: REAL,
	dash_mode 		: DashMode,
	flatness 		: REAL,
	
	char_space 		: REAL,
	word_space 		: REAL,
	h_scalling 		: REAL,
	text_leading 	: REAL,
	rendering_mode 	: TextRenderingMode,
	text_rise 		: REAL,
	
	cs_fill 		: ColorSpace,
	cs_stroke 		: ColorSpace,
	rgb_fill 		: RGBColor,
	rgb_stroke 		: RGBColor,
	cmyk_fill 		: CMYKColor,
	cmyk_stroke 	: CMYKColor,
	gray_fill 		: REAL,
	gray_stroke 	: REAL,
	
	font 			: Font,
	font_size 		: REAL,
	writing_mode 	: WritingMode,
	
	prev 			: GState,
	depth 			: UINT, 
};

List :: ^List_Rec;

List_Rec :: struct {
	mmgr 			: MMgr,
	error 			: Error,
	block_siz 		: UINT,
	items_per_block : UINT,
	count 			: UINT,
	obj 			: ^rawptr,
};

MPool_Node :: ^MPool_Node_Rec;

MPool_Node_Rec :: struct {
	buf : [^]BYTE,
	size : UINT,
	used_size : UINT,
	next_node : MPool_Node,
};

MMgr :: ^MMgr_Rec;

MMgr_Rec :: struct {
	error 		: Error,
	alloc_fn 	: Alloc_Func,
	free_fn 	: Free_Func,
	mpool 		: MPool_Node,
	buf_size 	: UINT,
};

Error_Rec :: struct {
	error_no 	: STATUS,
	detail_no 	: STATUS,
	error_fn 	: Error_Handler,
	user_data 	: rawptr,
};

Error :: ^Error_Rec;

Doc :: ^Doc_Rec;

Doc_Rec :: struct {
	sig_bytes 			: u32,
	pdf_version 		: PDFVer,

	mmgr 				: MMgr,
	catalog 			: Catalog,
	outlines 			: Outline,
	xref 				: Xref,
	root_pages 			: Pages,
	cur_pages 			: Pages,
	cur_page 			: Page,
	page_list 			: List,
	error 				: Error_Rec,
	info 				: Dict,
	trailer 			: Dict,

	font_mgr 			: List,
	ttfont_tag 			: [6]BYTE,

	/* list for loaded fontdefs */
	fontdef_list 		: List,

	/* list for loaded encodings */
	encoder_list 		: List,
	cur_encoder 		: Encoder,

	/* default compression mode */
	compression_mode 	: BOOL,

	encrypt_on 			: BOOL,
	encrypt_dict 		: EncryptDict,

	def_encoder 		: Encoder,

	page_per_pages 		: UINT,
	cur_page_num 		: UINT,

	/* buffer for saving into memory stream */
	stream 				: Stream,
};


StreamType :: enum i32 {
	STREAM_UNKNOWN = 0,
	STREAM_CALLBACK,
	STREAM_FILE,
	STREAM_MEMORY,
};

STREAM_FILTER_NONE  :: 0x0000;
STREAM_FILTER_ASCIIHEX  :: 0x0100;
STREAM_FILTER_ASCII85  :: 0x0200;
STREAM_FILTER_FLATE_DECODE  :: 0x0400;
STREAM_FILTER_DCT_DECODE  :: 0x0800;
STREAM_FILTER_CCITT_DECODE  :: 0x1000;

WhenceMode :: enum i32 {
	SEEK_SET = 0,
	SEEK_CUR,
	SEEK_END,
};

Stream_Write_Func :: #type proc "c" (stream: Stream, ptr: ^u8, siz: u32) -> STATUS;
Stream_Read_Func :: #type proc "c" (stream: Stream, ptr: ^u8, siz: ^u32) -> STATUS;
Stream_Seek_Func :: #type proc "c" (stream: Stream, pos: i32, mode: WhenceMode) -> STATUS;
Stream_Tell_Func :: #type proc "c" (stream: Stream) -> i32;
Stream_Free_Func :: #type proc "c" (stream: Stream);
Stream_Size_Func :: #type proc "c" (stream: Stream) -> u32;

MemStreamAttr :: ^MemStreamAttrRec;

MemStreamAttrRec :: struct {
	buf		: List,
	buf_siz	: u32,
	w_pos	  : u32,
	w_ptr	  : ^u8,
	r_ptr_idx  : u32,
	r_pos	  : u32,
	r_ptr	  : ^u8,
};

Stream :: ^Stream_Rec;

Stream_Rec :: struct {
	sig_bytes   : u32,
	type		: StreamType,
	mmgr		: MMgr,
	error	   : Error,
	size		: UINT,
	write_fn	: Stream_Write_Func,
	read_fn	 : Stream_Read_Func,
	seek_fn	 : Stream_Seek_Func,
	free_fn	 : Stream_Free_Func,
	tell_fn	 : Stream_Tell_Func,
	size_fn	 : Stream_Size_Func,
	attr		: rawptr,
};

@(default_calling_convention="c", link_prefix="HPDF_")
foreign lib {
		
	GetVersion :: proc() -> cstring ---;
	
	NewEx :: proc(user_error_fn : Error_Handler, user_alloc_fn : Alloc_Func, user_free_fn : Free_Func, mem_pool_buf_size : UINT, user_data : rawptr) -> Doc ---;
	New :: proc(user_error_fn : Error_Handler, user_data : rawptr) -> Doc ---;
	SetErrorHandler :: proc(pdf : Doc, user_error_fn : Error_Handler) -> STATUS ---;
	Free :: proc(pdf : Doc) ---;
	GetDocMMgr :: proc(doc : Doc) -> MMgr ---;
	NewDoc  :: proc(pdf : Doc) -> STATUS ---;
	FreeDoc :: proc(pdf : Doc) ---;
	HasDoc :: proc(pdf : Doc) -> BOOL ---;
	FreeDocAll :: proc(pdf : Doc) ---;
	SaveToStream :: proc(pdf : Doc) -> STATUS ---;
	GetContents  :: proc(pdf : Doc,	buf : [^]BYTE, size : ^u32) -> STATUS ---;

	GetStreamSize :: proc(pdf : Doc) -> u32 ---;
	ReadFromStream :: proc(pdf : Doc, buf : [^]BYTE, size : ^u32) -> STATUS ---;
	ResetStream :: proc(pdf : Doc) -> STATUS ---;
	
	SaveToFile :: proc(pdf : Doc, file_name : cstring) -> STATUS ---;
	GetError :: proc(pdf : Doc) -> STATUS ---;

	GetErrorDetail :: proc(pdf : Doc) -> STATUS ---;
	ResetError :: proc(pdf : Doc) ---;
	
	CheckError :: proc(error : Error) -> STATUS ---;
	
	SetPagesConfiguration :: proc(pdf : Doc, page_per_pages : UINT) -> STATUS ---;
	GetPageByIndex :: proc(pdf : Doc, index : UINT) -> Page ---;
	
	/*---------------------------------------------------------------------------*/
	
	GetPageMMgr :: proc(page : Page) -> MMgr ---;
	GetPageLayout :: proc(pdf : Doc) -> PageLayout ---;
	SetPageLayout :: proc(pdf : Doc, layout : PageLayout) -> STATUS ---;
	GetPageMode :: proc(pdf : Doc) -> PageMode ---;
	SetPageMode :: proc(pdf : Doc, mode : PageMode) -> STATUS ---;
	
	GetViewerPreference :: proc(pdf : Doc) -> UINT ---;
	SetViewerPreference :: proc(pdf : Doc, value : UINT) -> STATUS ---;
	SetOpenAction :: proc(pdf : Doc, open_action : Destination) -> STATUS --- ;
	
	/*----- page handling -------------------------------------------------------*/

	GetCurrentPage :: proc(pdf : Doc) -> Page ---;
	AddPage :: proc(pdf : Doc) -> Page ---;
	InsertPage :: proc(pdf : Doc, page : Page) -> Page ---;
	Page_SetWidth :: proc(page : Page, value : REAL) -> STATUS ---;
	Page_SetHeight :: proc(page : Page, value : REAL) -> STATUS ---;		
	Page_SetBoundary :: proc(page : Page, boundary : PageBoundary, left : REAL, bottom : REAL, right : REAL, top : REAL) -> STATUS ---;
	Page_SetSize :: proc(page : Page, size : PageSizes, direction : PageDirection) -> STATUS ---;
	Page_SetRotate :: proc(page : Page, angle : u16) -> STATUS ---;
	Page_SetZoom :: proc(page : Page, zoom : REAL) -> STATUS ---;

	/*----- font handling -------------------------------------------------------*/

	GetFont :: proc(pdf : Doc, font_name : cstring, encoding_name : cstring) -> Font ---;
	LoadType1FontFromFile :: proc(pdf : Doc, afm_file_name : cstring, data_file_name : cstring) -> cstring ---;					
	GetTTFontDefFromFile :: proc(pdf : Doc, file_name : cstring, embedding : BOOL) -> FontDef ---;
	LoadTTFontFromFile :: proc(pdf : Doc, file_name : cstring, embedding : BOOL) -> cstring ---;
	LoadTTFontFromFile2 :: proc(pdf : Doc, file_name : cstring, index : UINT, embedding : BOOL) -> cstring ---;
	AddPageLabel :: proc(pdf : Doc, page_num : UINT, style : PageNumStyle, first_page : UINT, prefix : cstring) -> STATUS ---;
	UseJPFonts :: proc(pdf : Doc) -> STATUS ---;
	UseKRFonts :: proc(pdf : Doc) -> STATUS ---;
	UseCNSFonts :: proc(pdf : Doc) -> STATUS ---;
	UseCNTFonts :: proc(pdf : Doc) -> STATUS ---;

	/*----- outline ------------------------------------------------------------*/

	CreateOutline :: proc(pdf : Doc, parent : Outline, title : cstring, encoder : Encoder) -> Outline ---;
	Outline_SetOpened :: proc(outline : Outline, opened : BOOL) -> STATUS ---;
	Outline_SetDestination :: proc(outline : Outline, dst : Destination) -> STATUS ---;

	/*----- destination --------------------------------------------------------*/

	Page_CreateDestination :: proc(page : Page) -> Destination ---;
	Destination_SetXYZ :: proc(dst : Destination, left : REAL, top : REAL, zoom : REAL) -> STATUS ---;
	Destination_SetFit :: proc(dst : Destination) -> STATUS ---;
	Destination_SetFitH :: proc(dst : Destination, top : REAL) -> STATUS ---;
	Destination_SetFitV :: proc(dst : Destination, left : REAL) -> STATUS ---;
	Destination_SetFitR :: proc(dst : Destination, left : REAL, bottom : REAL, right : REAL, top : REAL) -> STATUS ---;
	Destination_SetFitB :: proc(dst : Destination) -> STATUS ---;
	Destination_SetFitBH :: proc(dst : Destination, top : REAL) -> STATUS ---;
	Destination_SetFitBV :: proc(dst : Destination, left : REAL) -> STATUS ---;

	/*----- encoder ------------------------------------------------------------*/

	GetEncoder :: proc(pdf : Doc, encoding_name : cstring) -> Encoder ---;
	GetCurrentEncoder :: proc(pdf : Doc) -> Encoder ---;
	SetCurrentEncoder :: proc(pdf : Doc, encoding_name : cstring) -> STATUS ---;
	Encoder_GetType :: proc(encoder : Encoder) -> EncoderType ---;
	Encoder_GetByteType :: proc(encoder : Encoder, text : cstring, index : UINT) -> ByteType ---;
	Encoder_GetUnicode :: proc(encoder : Encoder, code : u16) -> UNICODE ---;
	Encoder_GetWritingMode :: proc(encoder : Encoder) -> WritingMode ---;
	UseJPEncodings :: proc(pdf : Doc) -> STATUS ---;
	UseKREncodings :: proc(pdf : Doc) -> STATUS ---;
	UseCNSEncodings :: proc(pdf : Doc) -> STATUS ---;
	UseCNTEncodings :: proc(pdf : Doc) -> STATUS ---;
	UseUTFEncodings :: proc(pdf : Doc) -> STATUS ---;

	/*----- XObject ------------------------------------------------------------*/

	Page_CreateXObjectFromImage :: proc(pdf : Doc, page : Page, rect : Rect, image : Image, zoom : BOOL) -> XObject ---;
	Page_CreateXObjectAsWhiteRect :: proc(pdf : Doc, page : Page, rect : Rect) -> XObject ---;

	/*----- annotation ---------------------------------------------------------*/

	Page_Create3DAnnot :: proc(page : Page, rect : Rect, tb : BOOL, np : BOOL, u3d : U3D, ap : Image) -> Annotation ---;
	Page_CreateTextAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateFreeTextAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateLineAnnot :: proc(page : Page, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateWidgetAnnot_WhiteOnlyWhilePrint :: proc(pdf : Doc, page : Page, rect : Rect) -> Annotation ---;
	Page_CreateWidgetAnnot :: proc(page : Page, rect : Rect) -> Annotation ---;
	Page_CreateLinkAnnot :: proc(page : Page, rect : Rect, dst : Destination) -> Annotation ---;
	Page_CreateURILinkAnnot :: proc(page : Page, rect : Rect, uri : cstring) -> Annotation ---;
	Page_CreateTextMarkupAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder, subType : AnnotType) -> Annotation ---;
	Page_CreateHighlightAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateUnderlineAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateSquigglyAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateStrikeOutAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;


	Page_CreatePopupAnnot :: proc(page : Page, rect : Rect, parent : Annotation) -> Annotation ---;
	Page_CreateStampAnnot :: proc(page : Page, rect : Rect, name : StampAnnotName, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateProjectionAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateSquareAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;
	Page_CreateCircleAnnot :: proc(page : Page, rect : Rect, text : cstring, encoder : Encoder) -> Annotation ---;

	LinkAnnot_SetHighlightMode :: proc(annot : Annotation, mode : AnnotHighlightMode) -> STATUS ---;
	LinkAnnot_SetJavaScript :: proc(annot : Annotation, javascript : JavaScript) -> STATUS ---;
	LinkAnnot_SetBorderStyle :: proc(annot : Annotation, width : REAL, dash_on : u16, dash_off : u16) -> STATUS ---;
	TextAnnot_SetIcon :: proc(annot : Annotation, icon : AnnotIcon) -> STATUS ---;
	TextAnnot_SetOpened :: proc(annot : Annotation, opened : BOOL) -> STATUS ---;
	Annot_SetRGBColor :: proc(annot : Annotation, color : RGBColor) -> STATUS ---;
	Annot_SetCMYKColor :: proc(annot : Annotation, color : CMYKColor) -> STATUS ---;
	Annot_SetGrayColor :: proc(annot : Annotation, color : REAL) -> STATUS ---;
	Annot_SetNoColor :: proc(annot : Annotation) -> STATUS ---;
	
	MarkupAnnot_SetTitle :: proc(annot : Annotation, name : cstring) -> STATUS ---;
	MarkupAnnot_SetSubject :: proc(annot : Annotation, name : cstring) -> STATUS ---;
	MarkupAnnot_SetCreationDate :: proc(annot : Annotation, value : Date) -> STATUS ---;
	MarkupAnnot_SetTransparency :: proc(annot : Annotation, value : REAL) -> STATUS ---;
	MarkupAnnot_SetIntent :: proc(annot : Annotation, intent : AnnotIntent) -> STATUS ---;
	MarkupAnnot_SetPopup :: proc(annot : Annotation, popup : Annotation) -> STATUS ---;
	MarkupAnnot_SetRectDiff :: proc(annot : Annotation, rect : Rect) -> STATUS ---; /* RD entry */
	MarkupAnnot_SetCloudEffect :: proc(annot : Annotation, cloudIntensity : INT) -> STATUS ---; /* BE entry */
	MarkupAnnot_SetInteriorRGBColor :: proc(annot : Annotation, color : RGBColor) -> STATUS ---; /* IC with RGB entry */
	MarkupAnnot_SetInteriorCMYKColor :: proc(annot : Annotation, color : CMYKColor) -> STATUS ---; /* IC with CMYK entry */
	MarkupAnnot_SetInteriorGrayColor :: proc(annot : Annotation, color : REAL) -> STATUS ---; /* IC with Gray entry */
	MarkupAnnot_SetInteriorTransparent :: proc(annot : Annotation) -> STATUS ---; /* IC with No Color entry */
	TextMarkupAnnot_SetQuadPoints :: proc(annot : Annotation, lb : Point, rb : Point, rt : Point, lt : Point) -> STATUS ---; /* l-left, r-right, b-bottom, t-top positions */
	
	Annot_Set3DView :: proc(mmgr : MMgr, annot : Annotation, annot3d : Annotation, view : Dict) -> STATUS ---;
	PopupAnnot_SetOpened :: proc(annot : Annotation, opened : BOOL) -> STATUS ---;
	
	FreeTextAnnot_SetLineEndingStyle :: proc(annot : Annotation, startStyle : LineAnnotEndingStyle, endStyle : LineAnnotEndingStyle) -> STATUS ---;
	FreeTextAnnot_Set3PointCalloutLine :: proc(annot : Annotation, startPoint : Point, kneePoint : Point, endPoint : Point) -> STATUS ---; /* Callout line will be in default user space */
	FreeTextAnnot_Set2PointCalloutLine :: proc(annot : Annotation, startPoint : Point, endPoint : Point) -> STATUS ---; /* Callout line will be in default user space */
	FreeTextAnnot_SetDefaultStyle :: proc(annot : Annotation, style : cstring) -> STATUS ---;
	
	LineAnnot_SetPosition :: proc(annot : Annotation, startPoint : Point, startStyle : LineAnnotEndingStyle, endPoint : Point, endStyle : LineAnnotEndingStyle) -> STATUS ---;
	LineAnnot_SetLeader :: proc(annot : Annotation, leaderLen : INT, leaderExtLen : INT, leaderOffsetLen : INT) -> STATUS ---;
	LineAnnot_SetCaption :: proc(annot : Annotation, showCaption : BOOL, position : LineAnnotCapPosition, horzOffset : INT, vertOffset : INT) -> STATUS ---;
	
	Annotation_SetBorderStyle :: proc(annot : Annotation, subtype : BSSubtype, width : REAL, dash_on : u16, dash_off : u16, dash_phase : u16) -> STATUS ---;
	ProjectionAnnot_SetExData :: proc(annot : Annotation, exdata : ExData) -> STATUS ---;
	
	
	/*----- image data ---------------------------------------------------------*/
	LoadPngImageFromMem :: proc(pdf : Doc, buffer : [^]BYTE, size : UINT) -> Image ---;
	LoadPngImageFromFile :: proc(pdf : Doc, filename : cstring) -> Image ---;
	LoadPngImageFromFile2 :: proc(pdf : Doc, filename : cstring) -> Image ---;
	LoadJpegImageFromFile :: proc(pdf : Doc, filename : cstring) -> Image ---;
	LoadJpegImageFromMem :: proc(pdf : Doc, buffer : [^]BYTE, size : UINT) -> Image ---;
	LoadU3DFromFile :: proc(pdf : Doc, filename : cstring) -> Image ---;
	LoadU3DFromMem :: proc(pdf : Doc, buffer : [^]BYTE, size : UINT) -> Image ---;
	Image_LoadRaw1BitImageFromMem :: proc(pdf : Doc, buf : [^]BYTE, width : UINT, height : UINT, line_width : UINT, black_is1 : BOOL, top_is_first : BOOL) -> Image ---;
	LoadRawImageFromFile :: proc(pdf : Doc, filename : cstring, width : UINT, height : UINT, color_space : ColorSpace) -> Image ---;
	LoadRawImageFromMem :: proc(pdf : Doc, buf : [^]BYTE, width : UINT, height : UINT, color_space : ColorSpace, bits_per_component : UINT) -> Image ---;
	Image_AddSMask :: proc(image : Image, smask : Image) -> STATUS ---;
	Image_GetSize :: proc(image : Image) -> Point ---;
	Image_GetSize2 :: proc(image : Image, size : ^Point) -> STATUS ---;
	Image_GetWidth :: proc(image : Image) -> UINT ---;
	Image_GetHeight :: proc(image : Image) -> UINT ---;
	Image_GetBitsPerComponent :: proc(image : Image) -> UINT ---;
	Image_GetColorSpace :: proc(image : Image) -> cstring ---;
	Image_SetColorMask :: proc(image : Image, rmin : UINT, rmax : UINT, gmin : UINT, gmax : UINT, bmin : UINT, bmax : UINT) -> STATUS ---;
	Image_SetMaskImage :: proc(image : Image, mask_image : Image) -> STATUS ---;

	/*----- info dictionary ----------------------------------------------------*/
	SetInfoAttr :: proc(pdf : Doc, type : InfoType, value : cstring) -> STATUS ---;
	GetInfoAttr :: proc(pdf : Doc, type : InfoType) -> cstring ---;
	SetInfoDateAttr :: proc(pdf : Doc, type : InfoType, value : Date) -> STATUS ---;

	/*----- encryption ---------------------------------------------------------*/
	SetPassword :: proc(pdf : Doc, owner_passwd : cstring, user_passwd : cstring) -> STATUS ---;
	SetPermission :: proc(pdf : Doc, permission : UINT) -> STATUS ---;
	SetEncryptionMode :: proc(pdf : Doc, mode : EncryptMode, key_len : UINT) -> STATUS ---;

	/*----- compression --------------------------------------------------------*/
	SetCompressionMode :: proc(pdf : Doc, mode : UINT) -> STATUS ---;
	
	/*----- font ---------------------------------------------------------------*/
	Font_GetFontName :: proc(font : Font) -> cstring ---;
	Font_GetEncodingName :: proc(font : Font) -> cstring ---;
	Font_GetUnicodeWidth :: proc(font : Font, code : UNICODE) -> INT ---;
	Font_GetBBox :: proc(font : Font) -> Box ---;
	Font_GetAscent :: proc(font : Font) -> INT ---;
	Font_GetDescent :: proc(font : Font) -> INT ---;
	Font_GetXHeight :: proc(font : Font) -> UINT ---;
	Font_GetCapHeight :: proc(font : Font) -> UINT ---;
	Font_TextWidth :: proc(font : Font, text : [^]BYTE, len : UINT) -> TextWidth ---;
	Font_MeasureText :: proc(font : Font, text : [^]BYTE, len : UINT, width : REAL, font_size : REAL, char_space : REAL, word_space : REAL, wordwrap : BOOL, real_width : ^REAL) -> UINT ---;
	
	/*----- attachments -------------------------------------------------------*/
	AttachFile :: proc(pdf : Doc, file : cstring) -> EmbeddedFile ---;

	/*----- extended graphics state --------------------------------------------*/
	CreateExtGState :: proc(pdf : Doc) -> ExtGState ---;
	ExtGState_SetAlphaStroke :: proc(ext_gstate : ExtGState, value : REAL) -> STATUS ---;
	ExtGState_SetAlphaFill :: proc(ext_gstate : ExtGState, value : REAL) -> STATUS ---;
	ExtGState_SetBlendMode :: proc(ext_gstate : ExtGState, mode : BlendMode) -> STATUS ---;

	/*--------------------------------------------------------------------------*/
	Page_TextWidth :: proc(page : Page, text : cstring) -> REAL ---;
	Page_MeasureText :: proc(page : Page, text : cstring, width : REAL, wordwrap : BOOL, real_width : ^REAL) -> UINT ---;
	Page_GetWidth :: proc(page : Page) -> REAL ---;
	Page_GetHeight :: proc(page : Page) -> REAL ---;
	Page_GetGMode :: proc(page : Page) -> u16 ---;
	Page_GetCurrentPos :: proc(page : Page) -> Point ---;
	Page_GetCurrentPos2 :: proc(page : Page, pos : ^Point) -> STATUS ---;
	Page_GetCurrentTextPos :: proc(page : Page) -> Point ---;
	Page_GetCurrentTextPos2 :: proc(page : Page, pos : ^Point) -> STATUS ---;
	Page_GetCurrentFont :: proc(page : Page) -> Font ---;
	Page_GetCurrentFontSize :: proc(page : Page) -> REAL ---;
	Page_GetTransMatrix :: proc(page : Page) -> TransMatrix ---;
	Page_GetLineWidth :: proc(page : Page) -> REAL ---;
	Page_GetLineCap :: proc(page : Page) -> LineCap ---;
	Page_GetLineJoin :: proc(page : Page) -> LineJoin ---;
	Page_GetMiterLimit :: proc(page : Page) -> REAL ---;
	Page_GetDash :: proc(page : Page) -> DashMode ---;
	Page_GetFlat :: proc(page : Page) -> REAL ---;
	Page_GetCharSpace :: proc(page : Page) -> REAL ---;
	Page_GetWordSpace :: proc(page : Page) -> REAL ---;
	Page_GetHorizontalScalling :: proc(page : Page) -> REAL ---;
	Page_GetTextLeading :: proc(page : Page) -> REAL ---;
	Page_GetTextRenderingMode :: proc(page : Page) -> TextRenderingMode ---;
	Page_GetTextRise :: proc(page : Page) -> REAL ---;
	Page_GetRGBFill :: proc(page : Page) -> RGBColor ---;
	Page_GetRGBStroke :: proc(page : Page) -> RGBColor ---;
	Page_GetCMYKFill :: proc(page : Page) -> CMYKColor ---;
	Page_GetCMYKStroke :: proc(page : Page) -> CMYKColor ---;
	Page_GetGrayFill :: proc(page : Page) -> REAL ---;
	Page_GetGrayStroke :: proc(page : Page) -> REAL ---;
	Page_GetStrokingColorSpace :: proc(page : Page) -> ColorSpace ---;
	Page_GetFillingColorSpace :: proc(page : Page) -> ColorSpace ---;
	Page_GetTextMatrix :: proc(page : Page) -> TransMatrix ---;
	Page_GetGStateDepth :: proc(page : Page) -> UINT ---;


/*----- GRAPHICS OPERATORS -------------------------------------------------*/
/*--- General graphics state ---------------------------------------------*/
	/* w */
	Page_SetLineWidth :: proc(page : Page, line_width : REAL) -> STATUS ---;

	/* J */
	Page_SetLineCap :: proc(page : Page, line_cap : LineCap) -> STATUS ---;

	/* j */
	Page_SetLineJoin :: proc(page : Page, line_join : LineJoin) -> STATUS ---;

	/* M */
	Page_SetMiterLimit :: proc(page : Page, miter_limit : REAL) -> STATUS ---;

	/* d */
	Page_SetDash :: proc(page : Page, dash_ptn : ^REAL, num_param : UINT, phase : REAL) -> STATUS ---;

	/* ri --not implemented yet */

	/* i */
	Page_SetFlat :: proc(page : Page, flatness : REAL) -> STATUS ---;

	/* gs */
	Page_SetExtGState :: proc(page : Page, ext_gstate : ExtGState) -> STATUS ---;

	/* sh */
	Page_SetShading :: proc(page : Page, shading : Shading) -> STATUS ---;


	/*--- Special graphic state operator --------------------------------------*/
	/* q */
	Page_GSave :: proc(page : Page) -> STATUS ---;

	/* Q */
	Page_GRestore :: proc(page : Page) -> STATUS ---;

	/* cm */
	Page_Concat :: proc(page : Page, a : REAL, b : REAL, c : REAL, d : REAL, x : REAL, y : REAL) -> STATUS ---;

/*--- Path construction operator ------------------------------------------*/
	/* m */
	Page_MoveTo :: proc(page : Page, x : REAL, y : REAL) -> STATUS ---;

	/* l */
	Page_LineTo :: proc(page : Page, x : REAL, y : REAL) -> STATUS ---;

	/* c */
	Page_CurveTo :: proc(page : Page, x1 : REAL, y1 : REAL, x2 : REAL, y2 : REAL, x3 : REAL, y3 : REAL) -> STATUS ---;

	/* v */
	Page_CurveTo2 :: proc(page : Page, x2 : REAL, y2 : REAL, x3 : REAL, y3 : REAL) -> STATUS ---;

	/* y */
	Page_CurveTo3 :: proc(page : Page, x1 : REAL, y1 : REAL, x3 : REAL, y3 : REAL) -> STATUS ---;

	/* h */
	Page_ClosePath :: proc(page : Page) -> STATUS ---;

	/* re */
	Page_Rectangle :: proc(page : Page, x : REAL, y : REAL, width : REAL, height : REAL) -> STATUS ---;

/*--- Path painting operator ---------------------------------------------*/
	/* S */
	Page_Stroke :: proc(page : Page) -> STATUS ---;

	/* s */
	Page_ClosePathStroke :: proc(page : Page) -> STATUS ---;

	/* f */
	Page_Fill :: proc(page : Page) -> STATUS ---;

	/* f* */
	Page_Eofill :: proc(page : Page) -> STATUS ---;

	/* B */
	Page_FillStroke :: proc(page : Page) -> STATUS ---;

	/* B* */
	Page_EofillStroke :: proc(page : Page) -> STATUS ---;

	/* b */
	Page_ClosePathFillStroke :: proc(page : Page) -> STATUS ---;

	/* b* */
	Page_ClosePathEofillStroke :: proc(page : Page) -> STATUS ---;

	/* n */
	Page_EndPath :: proc(page : Page) -> STATUS ---;


/*--- Clipping paths operator --------------------------------------------*/
	/* W */
	Page_Clip :: proc(page : Page) -> STATUS ---;

	/* W* */
	Page_Eoclip :: proc(page : Page) -> STATUS ---;

/*--- Text object operator -----------------------------------------------*/
	/* BT */
	Page_BeginText :: proc(page : Page) -> STATUS ---;

	/* ET */
	Page_EndText :: proc(page : Page) -> STATUS ---;

/*--- Text state ---------------------------------------------------------*/
	/* Tc */
	Page_SetCharSpace :: proc(page : Page, value : REAL) -> STATUS ---;

	/* Tw */
	Page_SetWordSpace :: proc(page : Page, value : REAL) -> STATUS ---;

	/* Tz */
	Page_SetHorizontalScalling :: proc(page : Page, value : REAL) -> STATUS ---;

	/* TL */
	Page_SetTextLeading :: proc(page : Page, value : REAL) -> STATUS ---;

	/* Tf */
	Page_SetFontAndSize :: proc(page : Page, font : Font, size : REAL) -> STATUS ---;

	/* Tr */
	Page_SetTextRenderingMode :: proc(page : Page, mode : TextRenderingMode) -> STATUS ---;

	/* Ts */
	Page_SetTextRise :: proc(page : Page, value : REAL) -> STATUS ---;

	/* This function is obsolete. Use Page_SetTextRise.  */
	Page_SetTextRaise :: proc(page : Page, value : REAL) -> STATUS ---;

/*--- Text positioning ---------------------------------------------------*/
	/* Td */
	Page_MoveTextPos :: proc(page : Page, x : REAL, y : REAL) -> STATUS ---;

	/* TD */
	Page_MoveTextPos2 :: proc(page : Page, x : REAL, y : REAL) -> STATUS ---;

	/* Tm */
	Page_SetTextMatrix :: proc(page : Page, a : REAL, b : REAL, c : REAL, d : REAL, x : REAL, y : REAL) -> STATUS ---;

	/* T* */
	Page_MoveToNextLine :: proc(page : Page) -> STATUS ---;

/*--- Text showing -------------------------------------------------------*/
	/* Tj */
	Page_ShowText :: proc(page : Page, text : cstring) -> STATUS ---;

	/* TJ */

	/* ' */
	Page_ShowTextNextLine :: proc(page : Page, text : cstring) -> STATUS ---;

	/* " */
	Page_ShowTextNextLineEx :: proc(page : Page, word_space : REAL, char_space : REAL, text : cstring) -> STATUS ---;

/*--- Color showing ------------------------------------------------------*/
	/* cs --not implemented yet */
	/* CS --not implemented yet */
	/* sc --not implemented yet */
	/* scn --not implemented yet */
	/* SC --not implemented yet */
	/* SCN --not implemented yet */

	/* g */
	Page_SetGrayFill :: proc(page : Page, gray : REAL) -> STATUS ---;

	/* G */
	Page_SetGrayStroke :: proc(page : Page, gray : REAL) -> STATUS ---;

	/* rg */
	Page_SetRGBFill :: proc(page : Page, r : REAL, g : REAL, b : REAL) -> STATUS ---;

	/* RG */
	Page_SetRGBStroke :: proc(page : Page, r : REAL, g : REAL, b : REAL) -> STATUS ---;

	/* k */
	Page_SetCMYKFill :: proc(page : Page, c : REAL, m : REAL, y : REAL, k : REAL) -> STATUS ---;
	
	/* K */
	Page_SetCMYKStroke :: proc(page : Page, c : REAL, m : REAL, y : REAL, k : REAL) -> STATUS ---;


	/*--- Shading patterns ---------------------------------------------------*/
	/* Notes for docs:
	* - ShadingType must be SHADING_FREE_FORM_TRIANGLE_MESH:: proc(the only
	*   defined option...)
	* - colorSpace must be CS_DEVICE_RGB for now.
	*/
	Shading_New :: proc(pdf : Doc, type : ShadingType, colorSpace : ColorSpace, xMin : REAL, xMax : REAL, yMin : REAL, yMax : REAL) -> Shading ---;
	Shading_AddVertexRGB :: proc(shading : Shading, edgeFlag : Shading_FreeFormTriangleMeshEdgeFlag, x : REAL, y : REAL, r : u8, g : u8, b : u8) -> STATUS ---;

	/*--- In-line images -----------------------------------------------------*/
	/* BI --not implemented yet */
	/* ID --not implemented yet */
	/* EI --not implemented yet */

	/*--- XObjects -----------------------------------------------------------*/
	Page_ExecuteXObject :: proc(page : Page, obj : XObject) -> STATUS ---;
	/*--- Content streams ----------------------------------------------------*/
	Page_New_Content_Stream :: proc(page : Page, new_stream : ^Dict) -> STATUS ---;
	Page_Insert_Shared_Content_Stream :: proc(page : Page, shared_stream : Dict) -> STATUS ---;

	/*--- Marked content -----------------------------------------------------*/
	/* BMC --not implemented yet */
	/* BDC --not implemented yet */
	/* EMC --not implemented yet */
	/* MP --not implemented yet */
	/* DP --not implemented yet */

	/*--- Compatibility ------------------------------------------------------*/
	/* BX --not implemented yet */
	/* EX --not implemented yet */
	Page_DrawImage :: proc(page : Page, image : Image, x : REAL, y : REAL, width : REAL, height : REAL) -> STATUS ---;
	Page_Circle :: proc(page : Page, x : REAL, y : REAL, ray : REAL) -> STATUS ---;
	Page_Ellipse :: proc(page : Page, x : REAL, y : REAL, xray : REAL, yray : REAL) -> STATUS ---;
	Page_Arc :: proc(page : Page, x : REAL, y : REAL, ray : REAL, ang1 : REAL, ang2 : REAL) -> STATUS ---;
	Page_TextOut :: proc(page : Page, xpos : REAL, ypos : REAL, text : cstring) -> STATUS ---;
	Page_TextRect :: proc(page : Page, left : REAL, top : REAL, right : REAL, bottom : REAL, text : cstring, align : TextAlignment, len : ^UINT) -> STATUS ---;
	Page_SetSlideShow :: proc(page : Page, type : TransitionStyle, disp_time : REAL, trans_time : REAL) -> STATUS ---;
	ICC_LoadIccFromMem :: proc(pdf : Doc, mmgr : MMgr, iccdata : Stream, xref : Xref, numcomponent : int) -> OutputIntent ---;
	LoadIccProfileFromFile :: proc(pdf : Doc, icc_file_name : cstring, numcomponent : int) -> OutputIntent ---;
	
}

@(default_calling_convention="c")
foreign lib {
		
	/*----- 3D Measure ---------------------------------------------------------*/
	@(link_name="HPDF_Page_Create3DC3DMeasure") Page_Create3DC3DMeasure :: proc(page : Page, firstanchorpoint : Point3D, textanchorpoint : Point3D) -> Measure3D ---;
	@(link_name="HPDF_Page_CreatePD33DMeasure") Page_CreatePD33DMeasure :: proc(page : Page, annotationPlaneNormal : Point3D, firstAnchorPoint : Point3D, secondAnchorPoint : Point3D, leaderLinesDirection : Point3D, measurementValuePoint : Point3D, textYDirection : Point3D, value : REAL, unitsString : cstring) -> Measure3D ---;
	@(link_name="HPDF_3DMeasure_SetName") Measure3D_SetName :: proc(measure : Measure3D, name : cstring) -> STATUS ---;
	@(link_name="HPDF_3DMeasure_SetColor") Measure3D_SetColor :: proc(measure : Measure3D, color : RGBColor) -> STATUS ---;
	@(link_name="HPDF_3DMeasure_SetTextSize") Measure3D_SetTextSize :: proc(measure : Measure3D, textsize : REAL) -> STATUS ---;
	@(link_name="HPDF_3DC3DMeasure_SetTextBoxSize") C3DMeasure3D_SetTextBoxSize :: proc(measure : Measure3D, x : i32, y : i32) -> STATUS ---;
	@(link_name="HPDF_3DC3DMeasure_SetText") C3DMeasure3D_SetText :: proc(measure : Measure3D, text : cstring, encoder : Encoder) -> STATUS ---;
	@(link_name="HPDF_3DC3DMeasure_SetProjectionAnotation") C3DMeasure3D_SetProjectionAnotation :: proc(measure : Measure3D, projectionanotation : Annotation) -> STATUS ---;

	/*----- External Data ---------------------------------------------------------*/
	@(link_name="HPDF_Page_Create3DAnnotExData") Page_Create3DAnnotExData :: proc(page : Page) -> ExData ---;
	@(link_name="HPDF_3DAnnotExData_Set3DMeasurement") AnnotExData3D_Set3DMeasurement :: proc(exdata : ExData, measure : Measure3D) -> STATUS ---;

	/*----- 3D View ---------------------------------------------------------*/
	@(link_name="HPDF_Page_Create3DView") Page_Create3DView :: proc(page : Page, u3d : U3D, annot3d : Annotation, name : cstring) -> Dict ---;
	@(link_name="HPDF_3DView_Add3DC3DMeasure") View3D_Add3DC3DMeasure :: proc(view : Dict, measure : Measure3D) -> STATUS ---;
}