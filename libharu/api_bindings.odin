package libharu_bindings

when ODIN_OS == .Windows {
    foreign import lib "jagpdf/libharu/hpdf.lib"
} else when ODIN_OS == .Linux {
    foreign import lib "fastnoise/libharu/hpdf.so"
} else when ODIN_OS == .Darwin {
    foreign import lib "fastnoise/libharu/hpdf.dylib"
}

UINT :: u32; //TODO CHECK 
UINT32 :: u32; //TODO CHECK 
BOOL :: b8; //TODO CHECK
BYTE :: u8; //TODO CHECK

//TODO
PDFVer :: i32;
Catalog :: i32;
Outline :: i32;
Xref :: i32;
Pages :: i32;
Page :: i32;
List :: i32;
Dict :: i32;
Encoder :: i32;
EncryptDict :: i32;
Stream :: i32;
STATUS :: i32; //TODO
MMgr :: i32; //TODO

Error_Rec :: struct {
    error_no 	: STATUS,
    detail_no 	: STATUS,
    error_fn 	: Error_Handler,
    user_data 	: rawptr,
};

Error :: ^Error_Rec;

Doc_Rec :: struct {
    sig_bytes 			: UINT32,
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

Error_Handler :: #type proc "c" (error_no : STATUS, detail_no : HPDF_STATUS, user_data : rawptr);
Alloc_Func :: #type proc "c" (size : UINT) -> rawptr;
Free_Func :: #type proc "c" (aptr : rawptr); 

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
	GetContents  :: proc(pdf : Doc,	buf : [^]BYTE, size : ^UINT32) -> STATUS ---;

	GetStreamSize :: proc(pdf : Doc) -> UINT32 ---;
	ReadFromStream :: proc(pdf : Doc, buf : [^]BYTE, size : ^UINT32) -> STATUS ---;
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
	GetPageMode :: proc(pdf : Doc) -> PageMode;
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
	Page_SetRotate :: proc(page : Page, angle : UINT16) -> STATUS ---;
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
	Encoder_GetUnicode :: proc(encoder : Encoder, code : UINT16) -> UNICODE ---;
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
	LinkAnnot_SetBorderStyle :: proc(annot : Annotation, width : REAL, dash_on : UINT16, dash_off : UINT16) -> STATUS ---;
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
	
	Annotation_SetBorderStyle :: proc(annot : Annotation, subtype : BSSubtype, width : REAL, dash_on : UINT16, dash_off : UINT16, dash_phase : UINT16) -> STATUS ---;
	ProjectionAnnot_SetExData :: proc(annot : Annotation, exdata : ExData) -> STATUS ---;
	
	
	/*----- image data ---------------------------------------------------------*/
	LoadPngImageFromMem :: proc(pdf : Doc, buffer : *BYTE, size : UINT) -> Image ---;
	LoadPngImageFromFile :: proc(pdf : Doc, filename : *char) -> Image ---;
	LoadPngImageFromFile2 :: proc(pdf : Doc, filename : *char) -> Image ---;
	LoadJpegImageFromFile :: proc(pdf : Doc, filename : *char) -> Image ---;
	LoadJpegImageFromMem :: proc(pdf : Doc, buffer : *BYTE, size : UINT) -> Image ---;
	LoadU3DFromFile :: proc(pdf : Doc, filename : *char) -> Image ---;
	LoadU3DFromMem :: proc(pdf : Doc, buffer : *BYTE, size : UINT) -> Image ---;
	Image_LoadRaw1BitImageFromMem :: proc(pdf : Doc, buf : *BYTE, width : UINT, height : UINT, line_width : UINT, black_is1 : BOOL, top_is_first : BOOL) -> Image ---;
	LoadRawImageFromFile :: proc(pdf : Doc, filename : *char, width : UINT, height : UINT, color_space : ColorSpace) -> Image ---;
	LoadRawImageFromMem :: proc(pdf : Doc, buf : *BYTE, width : UINT, height : UINT, color_space : ColorSpace, bits_per_component : UINT) -> Image ---;
	Image_AddSMask :: proc(image : Image, smask : Image) -> STATUS ---;
	Image_GetSize :: proc(image : Image) -> Point ---;
	Image_GetSize2 :: proc(image : Image, size : *Point) -> STATUS ---;
	Image_GetWidth :: proc(image : Image) -> UINT ---;
	Image_GetHeight :: proc(image : Image) -> UINT ---;
	Image_GetBitsPerComponent :: proc(image : Image) -> UINT ---;
	Image_GetColorSpace :: proc(image : Image) -> *char ---;
	Image_SetColorMask :: proc(image : Image, rmin : UINT, rmax : UINT, gmin : UINT, gmax : UINT, bmin : UINT, bmax : UINT) -> STATUS ---;
	Image_SetMaskImage :: proc(image : Image, mask_image : Image) -> STATUS ---;

	/*----- info dictionary ----------------------------------------------------*/
	SetInfoAttr :: proc(pdf : Doc, type : InfoType, value : *char) -> STATUS ---;
	GetInfoAttr :: proc(pdf : Doc, type : InfoType) -> *char ---;
	SetInfoDateAttr :: proc(pdf : Doc, type : InfoType, value : Date) -> STATUS ---;

	/*----- encryption ---------------------------------------------------------*/
	SetPassword :: proc(pdf : Doc, owner_passwd : *char, user_passwd : *char) -> STATUS ---;
	SetPermission :: proc(pdf : Doc, permission : UINT) -> STATUS ---;
	SetEncryptionMode :: proc(pdf : Doc, mode : EncryptMode, key_len : UINT) -> STATUS ---;

	/*----- compression --------------------------------------------------------*/
	SetCompressionMode :: proc(pdf : Doc, mode : UINT) -> STATUS ---;
	
	/*----- font ---------------------------------------------------------------*/
	Font_GetFontName :: proc(font : Font) -> *char ---;
	Font_GetEncodingName :: proc(font : Font) -> *char ---;
	Font_GetUnicodeWidth :: proc(font : Font, code : UNICODE) -> INT ---;
	Font_GetBBox :: proc(font : Font) -> Box ---;
	Font_GetAscent :: proc(font : Font) -> INT ---;
	Font_GetDescent :: proc(font : Font) -> INT ---;
	Font_GetXHeight :: proc(font : Font) -> UINT ---;
	Font_GetCapHeight :: proc(font : Font) -> UINT ---;
	Font_TextWidth :: proc(font : Font, text : *BYTE, len : UINT) -> TextWidth ---;
	Font_MeasureText :: proc(font : Font, text : *BYTE, len : UINT, width : REAL, font_size : REAL, char_space : REAL, word_space : REAL, wordwrap : BOOL, real_width : *REAL) -> UINT ---;

	/*----- attachments -------------------------------------------------------*/
	AttachFile :: proc(pdf : Doc, file : *char) -> EmbeddedFile ---;

	/*----- extended graphics state --------------------------------------------*/
	CreateExtGState :: proc(pdf : Doc) -> ExtGState ---;
	ExtGState_SetAlphaStroke :: proc(ext_gstate : ExtGState, value : REAL) -> STATUS ---;
	ExtGState_SetAlphaFill :: proc(ext_gstate : ExtGState, value : REAL) -> STATUS ---;
	ExtGState_SetBlendMode :: proc(ext_gstate : ExtGState, mode : BlendMode) -> STATUS ---;

	/*--------------------------------------------------------------------------*/
	Page_TextWidth :: proc(page : Page, text : *char) -> REAL ---;
	Page_MeasureText :: proc(page : Page, text : *char, width : REAL, wordwrap : BOOL, real_width : *REAL) -> UINT ---;
	Page_GetWidth :: proc(page : Page) -> REAL ---;
	Page_GetHeight :: proc(page : Page) -> REAL ---;
	Page_GetGMode :: proc(page : Page) -> UINT16 ---;
	Page_GetCurrentPos :: proc(page : Page) -> Point ---;
	Page_GetCurrentPos2 :: proc(page : Page, pos : *Point) -> STATUS ---;
	Page_GetCurrentTextPos :: proc(page : Page) -> Point ---;
	Page_GetCurrentTextPos2 :: proc(page : Page, pos : *Point) -> STATUS ---;
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
	Page_SetDash :: proc(page : Page, dash_ptn : *REAL, num_param : UINT, phase : REAL) -> STATUS ---;

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
	Shading_AddVertexRGB :: proc(shading : Shading, edgeFlag : Shading_FreeFormTriangleMeshEdgeFlag, x : REAL, y : REAL, r : UINT8, g : UINT8, b : UINT8) -> STATUS ---;

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

Page_Create3DC3DMeasure :: HPDF_Page_Create3DC3DMeasure;
Page_CreatePD33DMeasure :: HPDF_Page_CreatePD33DMeasure;
Measure3D_SetName :: HPDF_3DMeasure_SetName;
Measure3D_SetColor :: HPDF_3DMeasure_SetColor;
Measure3D_SetTextSize :: HPDF_3DMeasure_SetTextSize;
C3DMeasure3D_SetTextBoxSize :: HPDF_3DC3DMeasure_SetTextBoxSize;
C3DMeasure3D_SetText :: HPDF_3DC3DMeasure_SetText;
C3DMeasure3D_SetProjectionAnotation :: HPDF_3DC3DMeasure_SetProjectionAnotation;
Page_Create3DAnnotExData :: HPDF_Page_Create3DAnnotExData;
AnnotExData3D_Set3DMeasurement :: HPDF_3DAnnotExData_Set3DMeasurement;
Page_Create3DView :: HPDF_Page_Create3DView;
View3D_Add3DC3DMeasure :: HPDF_3DView_Add3DC3DMeasure;

@(default_calling_convention="c")
foreign lib {
		
	/*----- 3D Measure ---------------------------------------------------------*/
	HPDF_Page_Create3DC3DMeasure :: proc(page : Page, firstanchorpoint : Point3D, textanchorpoint : Point3D) -> Measure3D ---;
	HPDF_Page_CreatePD33DMeasure :: proc(page : Page, annotationPlaneNormal : Point3D, firstAnchorPoint : Point3D, secondAnchorPoint : Point3D, leaderLinesDirection : Point3D, measurementValuePoint : Point3D, textYDirection : Point3D, value : REAL, unitsString : cstring) -> Measure3D ---;
	HPDF_3DMeasure_SetName :: proc(measure : Measure3D, name : cstring) -> STATUS ---;
	HPDF_3DMeasure_SetColor :: proc(measure : Measure3D, color : RGBColor) -> STATUS ---;
	HPDF_3DMeasure_SetTextSize :: proc(measure : Measure3D, textsize : REAL) -> STATUS ---;
	HPDF_3DC3DMeasure_SetTextBoxSize :: proc(measure : Measure3D, x : INT32, y : INT32) -> STATUS ---;
	HPDF_3DC3DMeasure_SetText :: proc(measure : Measure3D, text : cstring, encoder : Encoder) -> STATUS ---;
	HPDF_3DC3DMeasure_SetProjectionAnotation :: proc(measure : Measure3D, projectionanotation : Annotation) -> STATUS ---;

	/*----- External Data ---------------------------------------------------------*/
	HPDF_Page_Create3DAnnotExData :: proc(page : Page) -> ExData ---;
	HPDF_3DAnnotExData_Set3DMeasurement :: proc(exdata : ExData, measure : Measure3D) -> STATUS ---;

	/*----- 3D View ---------------------------------------------------------*/
	HPDF_Page_Create3DView :: proc(page : Page, u3d : U3D, annot3d : Annotation, name : cstring) -> Dict ---;
	HPDF_3DView_Add3DC3DMeasure :: proc(view : Dict, measure : Measure3D) -> STATUS ---;
}