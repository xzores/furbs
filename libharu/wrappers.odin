package libharu_wrappers;

/*
	Wrapper for libharu by Jakob Furbo Enevoldsen, 2024
*/

import "base:runtime"

import "core:slice"
import "core:fmt"
import "core:strings"
import "core:log"
import "core:mem"
import "core:testing"
import "core:time"

import haru "bindings"
import "../utils"

//THIS API IS SINGLE THREADED

//Is set at startup, used for allocating haru things
haru_logger : runtime.Logger;
haru_allocator : runtime.Allocator;

//Is set every call, used to locate error calls
haru_location : runtime.Source_Code_Location;

//Special enum, this is not included in haru itself but is just a named error codes.
Status_code :: haru.Status_code;

//Enums
StreamType :: haru.StreamType; 
WhenceMode :: haru.WhenceMode;
FontDefType :: haru.FontDefType;
FontType :: haru.FontType;

LineCap :: haru.LineCap;
LineJoin :: haru.LineJoin;
TextRenderingMode :: haru.TextRenderingMode;
WritingMode :: haru.WritingMode;
PageLayout :: haru.PageLayout;
PageMode :: haru.PageMode;
PageNumStyle :: haru.PageNumStyle;
DestinationType :: haru.DestinationType;
AnnotType :: haru.AnnotType;
AnnotFlgs :: haru.AnnotFlgs;
AnnotHighlightMode :: haru.AnnotHighlightMode;
AnnotIcon :: haru.AnnotIcon;
AnnotIntent :: haru.AnnotIntent;
LineAnnotEndingStyle :: haru.LineAnnotEndingStyle;
LineAnnotCapPosition :: haru.LineAnnotCapPosition;
StampAnnotName :: haru.StampAnnotName;
BSSubtype :: haru.BSSubtype;
BlendMode :: haru.BlendMode;
TransitionStyle :: haru.TransitionStyle;
PageSizes :: haru.PageSizes;
PageDirection :: haru.PageDirection;
EncoderType :: haru.EncoderType;
ByteType :: haru.ByteType;
TextAlignment :: haru.TextAlignment;
NameDictKey :: haru.NameDictKey;
PageBoundary :: haru.PageBoundary;
ShadingType :: haru.ShadingType;
Shading_FreeFormTriangleMeshEdgeFlag :: haru.Shading_FreeFormTriangleMeshEdgeFlag;
EncodingType :: haru.EncodingType;

InfoType ::  haru.InfoType;
PDFAType ::  haru.PDFAType;
PDFVer ::  haru.PDFVer;
EncryptMode ::  haru.EncryptMode;

ColorSpace :: haru.ColorSpace;

Xref :: haru.Xref;
Dict :: haru.Dict;

//Functions types
Stream_Write_Func :: haru.Stream_Write_Func;
Stream_Read_Func :: haru.Stream_Read_Func;
Stream_Seek_Func :: haru.Stream_Seek_Func;
Stream_Tell_Func :: haru.Stream_Tell_Func;
Stream_Free_Func :: haru.Stream_Free_Func;
Stream_Size_Func :: haru.Stream_Size_Func;

FontDef_FreeFunc :: haru.FontDef_FreeFunc;
FontDef_CleanFunc :: haru.FontDef_CleanFunc;
FontDef_InitFunc :: haru.FontDef_InitFunc;

Font_TextWidths_Func :: haru.Font_TextWidths_Func;
Font_MeasureText_Func :: haru.Font_MeasureText_Func;

Encoder_ByteType_Func :: haru.Encoder_ByteType_Func;
Encoder_ToUnicode_Func :: haru.Encoder_ToUnicode_Func;
Encoder_EncodeText_Func :: haru.Encoder_EncodeText_Func;
Encoder_Write_Func :: haru.Encoder_Write_Func;
Encoder_Init_Func :: haru.Encoder_Init_Func;
Encoder_Free_Func :: haru.Encoder_Free_Func;

Error_Handler :: haru.Error_Handler;
Alloc_Func :: haru.Alloc_Func;
Free_Func :: haru.Free_Func;

//Handles
Status :: haru.STATUS;
Stream :: haru.Stream;
Error :: haru.Error;
Doc :: haru.Doc;
MMgr :: haru.MMgr;
List :: haru.List;
GState :: haru.GState;
FontDef :: haru.FontDef;
Font :: haru.Font;
Encrypt :: haru.Encrypt;
Encoder :: haru.Encoder;
Catalog :: haru.Catalog;

EmbeddedFile   :: haru.EmbeddedFile;
NameDict       :: haru.NameDict;
NameTree       :: haru.NameTree;
Pages          :: haru.Pages;
Page           :: haru.Page;
Annotation     :: haru.Annotation;
Measure3D      :: haru.Measure3D;
ExData         :: haru.ExData;
XObject        :: haru.XObject;
Image          :: haru.Image;
Outline        :: haru.Outline;
EncryptDict    :: haru.EncryptDict;
Action         :: haru.Action;
ExtGState      :: haru.ExtGState;
Destination    :: haru.Destination;
U3D            :: haru.U3D;
OutputIntent   :: haru.OutputIntent;
JavaScript     :: haru.JavaScript;
Shading        :: haru.Shading;

//Structs
Point :: haru.Point;
Rect ::  haru.Rect;
Point3D :: haru.Point3D;
Box :: haru.Box;
Date ::haru.Date;
TextWidth :: haru.TextWidth;
DashMode :: haru.DashMode;
TransMatrix :: haru.TransMatrix;
_3DMatrix :: haru._3DMatrix;
RGBColor :: haru.RGBColor;
CMYKColor :: haru.CMYKColor;


//New enums
Viewer_prefenence :: enum u32 {
	HIDE_TOOLBAR 		= 1,
	HIDE_MENUBAR 		= 2,
	HIDE_WINDOW_UI 		= 4,
	FIT_WINDOW 			= 8,
	CENTER_WINDOW 		= 16,
	PRINT_SCALING_NONE 	= 32,
}

Compression_mode :: enum u32 {
	COMP_NONE = 	0x00,
	COMP_TEXT = 	0x01,
	COMP_IMAGE = 	0x02,
	COMP_METADATA = 0x04,
	COMP_ALL = 		0x0F,
	/* #define  HPDF_COMP_BEST_COMPRESS   0x10
	* #define  HPDF_COMP_BEST_SPEED      0x20
	*/
}

//The allocator must live until destroy has been called and all objects has been destoyed.
init :: proc (allocator := context.allocator, logger := context.logger, loc := #caller_location) {
	
	assert(allocator != {}, "The wrapper requires an allocator", loc);
	if logger == {} {
		fmt.eprintf("No logger is set, output from haru will be hidden.");
	}
	
	haru_allocator = allocator;
	haru_logger = logger;
}

destroy :: proc (loc := #caller_location) {
	
	assert(haru_allocator != {}, "Please call init first", loc);
	haru_allocator = {};
}

//This must be deleted by the user, using the temp allocator is recommended.
@(require_results)
get_version :: proc(alloc := context.allocator, loc := #caller_location) -> string {
	haru_location = loc;
	context.allocator = alloc;
	ver_string := haru.GetVersion();
	return strings.clone_from_cstring(ver_string);
}

@(require_results)
new :: proc (mem_pool_buf_size : u32 = 1024 * 1024, loc := #caller_location) -> Doc {
	haru_location = loc;
	
	error_function : haru.Error_Handler : proc "c" (error_no : Status, detail_no : Status, user_data : rawptr) {
		context = runtime.default_context();
		context.logger = haru_logger;
		context.allocator = haru_allocator;
		
		log.errorf("Recived haru error, error code: %v(%v), detail no: %v at code location : %v", cast(Status_code)error_no, error_no, detail_no, haru_location);
	}

	alloc_function : haru.Alloc_Func : proc "c" (size : u32) -> rawptr {
		context = runtime.default_context();
		context.logger = haru_logger;
		context.allocator = haru_allocator;
		
		ptr, err := mem.alloc(auto_cast size, allocator = haru_allocator);
		assert(err == nil, "Failed to allocate");
		return ptr;
	}
	
	free_function : haru.Free_Func : proc "c" (ptr : rawptr) {
		context = runtime.default_context();
		context.logger = haru_logger;
		context.allocator = haru_allocator;
		
		mem.free(ptr, haru_allocator);
	}
	
	assert(haru_allocator != {}, "You must first call init", loc);
	
	doc := haru.NewEx(error_function, alloc_function, free_function, mem_pool_buf_size, nil);
	
	if doc == nil {
		log.error("Failed to create document", location = loc);
	}	
	
	return doc;
}

set_error_handler :: proc (pdf : Doc, user_error_fn : Error_Handler, loc := #caller_location) -> Status_code {
	haru_location = loc;
	status := haru.SetErrorHandler(pdf, user_error_fn);
	if status != 0 {
		log.error("Failed to set error handler status", location = loc);
	}
	return cast(Status_code)status;
}

// Free the document
free :: proc(pdf : Doc, loc := #caller_location) {
	haru_location = loc;
	haru.Free(pdf);
}

// Get memory manager associated with the document
@(require_results)
get_doc_mmgr :: proc(doc : Doc, loc := #caller_location) -> MMgr {
	haru_location = loc;
	return haru.GetDocMMgr(doc);
}


new_doc :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
	haru_location = loc;
	status := haru.NewDoc(pdf);
	if status != 0 {
		log.error("Failed to create document", location = loc);
	}
	return cast(Status_code)status;
}

// Free the document
free_doc :: proc(pdf : Doc, loc := #caller_location) {
	haru_location = loc;
	haru.FreeDoc(pdf);
}

@(require_results)
has_doc :: proc(pdf : Doc, loc := #caller_location) -> bool {
	haru_location = loc;
	return auto_cast haru.HasDoc(pdf);
}

free_doc_all :: proc(pdf : Doc, loc := #caller_location) {
	haru_location = loc;
	haru.FreeDocAll(pdf);
}

// Save the document to stream
save_to_stream :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
	haru_location = loc;
	status := haru.SaveToStream(pdf);
	if status != 0 {
		log.error("Failed to save document to stream", location = loc);
	}
	return cast(Status_code)status;
}

// Get the contents of the document
get_contents :: proc(pdf : Doc, loc := #caller_location) -> (buf : []u8, status : Status) {
	haru_location = loc;
	
	size : u32 = 4 * 1024; //try with 4kB and then double every time if there is not enough space.
	done : bool = false;
	
	for !done {
		buf_temp := make([]u8, size);
		defer delete(buf_temp);
		t_size := size;
		status = haru.GetContents(pdf, &buf_temp[0], &t_size);
		if status != 0 {
			log.error("Failed to get contents of the document", location = loc);
		}
		
		if size > t_size {
			done = true;
			buf = slice.clone(buf_temp[:t_size]);
		}
		else {
			size *= 2;
		}
	}
	
	return buf, status;
}

@(require_results)
get_stream_size :: proc(pdf : Doc, loc := #caller_location) -> u32 {
    haru_location = loc;
    return haru.GetStreamSize(pdf);
}

@(require_results)
read_from_stream :: proc(pdf : Doc, loc := #caller_location) -> (buf : []u8, status : Status) {
	
	stream_size := get_stream_size(pdf);
	
	buf = make([]u8, stream_size);
	
	haru_location = loc;
	status = haru.ReadFromStream(pdf, &buf[0], &stream_size);
	
	if status != 0 {
		log.error("Failed to read from stream", location = loc);
	}
	assert(auto_cast stream_size == len(buf), "something is wrong, internal error...");
	
	return;
}

reset_stream :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
	haru_location = loc;
	status := haru.ResetStream(pdf);
	if status != 0 {
		log.error("Failed to reset stream", location = loc);
	}
	return cast(Status_code)status;
}

// Save the document to a file
save_to_file :: proc(pdf : Doc, file_name : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_file_name := strings.clone_to_cstring(file_name);
	defer delete(c_file_name);
	
	status := haru.SaveToFile(pdf, c_file_name);
	
	if status != 0 {
		log.error("Failed to save document to file", location = loc);
	}
	
	return cast(Status_code)status;
}

// Get the error status of the document
get_error :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.GetError(pdf);
}

// Get detailed error information from the document
get_error_detail :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.GetErrorDetail(pdf);
}

// Reset the error status of the document
reset_error :: proc(pdf : Doc, loc := #caller_location) {
	haru_location = loc;
	haru.ResetError(pdf);
}

// Check if the error is valid
check_error :: proc(error : Error, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.CheckError(error);
}

// Set the page configuration for the document
page_sets_configuration :: proc(pdf : Doc, page_per_page : u32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	status := haru.SetPagesConfiguration(pdf, page_per_page);
	if status != 0 {
		log.error("Failed to set pages configuration", location = loc);
	}
	return cast(Status_code)status;
}

// Get the page by index
@(require_results)
get_page_by_index :: proc(pdf : Doc, index : u32, loc := #caller_location) -> Page {
	haru_location = loc;
	return haru.GetPageByIndex(pdf, index);
}


///////////////////////


// Get the memory manager associated with the page
@(require_results)
get_page_mmgr :: proc(page : Page, loc := #caller_location) -> MMgr {
    haru_location = loc;
    return haru.GetPageMMgr(page);
}

// Get the layout of the document's pages
@(require_results)
get_page_layout :: proc(pdf : Doc, loc := #caller_location) -> PageLayout {
    haru_location = loc;
    return haru.GetPageLayout(pdf);
}

// Set the layout of the document's pages
page_set_layout :: proc(pdf : Doc, layout : PageLayout, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.SetPageLayout(pdf, layout);
    if status != 0 {
        log.error("Failed to set page layout", location = loc);
    }
    return cast(Status_code)status;
}

// Get the current page mode of the document
@(require_results)
get_page_mode :: proc(pdf : Doc, loc := #caller_location) -> PageMode {
    haru_location = loc;
    return haru.GetPageMode(pdf);
}

// Set the page mode of the document
page_set_mode :: proc(pdf : Doc, mode : PageMode, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.SetPageMode(pdf, mode);
    if status != 0 {
        log.error("Failed to set page mode", location = loc);
    }
    return cast(Status_code)status;
}

// Get the viewer preferences for the document
@(require_results)
get_viewer_preference :: proc(pdf : Doc, loc := #caller_location) -> u32 {
    haru_location = loc;
    return haru.GetViewerPreference(pdf);
}

// Set the viewer preferences for the document
set_viewer_preference :: proc(pdf : Doc, value : Viewer_prefenence, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.SetViewerPreference(pdf, auto_cast value);
    if status != 0 {
        log.error("Failed to set viewer preference", location = loc);
    }
    return cast(Status_code)status;
}

// Set the open action for the document
set_open_action :: proc(pdf : Doc, open_action : Destination, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.SetOpenAction(pdf, open_action);
    if status != 0 {
        log.error("Failed to set open action", location = loc);
    }
    return cast(Status_code)status;
}

////////

// Get the current page of the document
@(require_results)
get_current_page :: proc(pdf : Doc, loc := #caller_location) -> Page {
    haru_location = loc;
    return haru.GetCurrentPage(pdf);
}

// Add a new page to the document
@(require_results)
add_page :: proc(pdf : Doc, loc := #caller_location) -> Page {
    haru_location = loc;
    return haru.AddPage(pdf);
}

// Insert a page into the document at a specific position
@(require_results)
insert_page :: proc(pdf : Doc, page : Page, loc := #caller_location) -> Page {
    haru_location = loc;
    return haru.InsertPage(pdf, page);
}

// Set the width of the page
page_set_width :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetWidth(page, value);
    if status != 0 {
        log.error("Failed to set page width", location = loc);
    }
    return cast(Status_code)status;
}

// Set the height of the page
page_set_height :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetHeight(page, value);
    if status != 0 {
        log.error("Failed to set page height", location = loc);
    }
    return cast(Status_code)status;
}

// Set the boundaries of the page
page_set_boundary :: proc(page : Page, boundary : PageBoundary, left : f32, bottom : f32, right : f32, top : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetBoundary(page, boundary, left, bottom, right, top);
    if status != 0 {
        log.error("Failed to set page boundary", location = loc);
    }
    return cast(Status_code)status;
}

// Set the size of the page
page_set_size :: proc(page : Page, size : PageSizes, direction : PageDirection, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetSize(page, size, direction);
    if status != 0 {
        log.error("Failed to set page size", location = loc);
    }
    return cast(Status_code)status;
}

// Set the rotation of the page
page_set_rotate :: proc(page : Page, angle : u16, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetRotate(page, angle);
    if status != 0 {
        log.error("Failed to set page rotation", location = loc);
    }
    return cast(Status_code)status;
}

// Set the zoom of the page
page_set_zoom :: proc(page : Page, zoom : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetZoom(page, zoom);
    if status != 0 {
        log.error("Failed to set page zoom", location = loc);
    }
    return cast(Status_code)status;
}

/////

// Get a font by name and encoding
@(require_results)
get_font :: proc(pdf : Doc, font_name : string, encoding_name : string, loc := #caller_location) -> Font {
    haru_location = loc;
    
    c_font_name := strings.clone_to_cstring(font_name);
    defer delete(c_font_name);
    
    c_encoding_name := strings.clone_to_cstring(encoding_name);
    defer delete(c_encoding_name);
    
    return haru.GetFont(pdf, c_font_name, c_encoding_name);
}

// Load a Type 1 font from files, the return string must be deleted by the user, it is adviced to use the temp allcator.
@(require_results)
load_type1_font_from_file :: proc(pdf : Doc, afm_file_name : string, data_file_name : string, alloc := context.allocator, loc := #caller_location) -> string {
    haru_location = loc;
    context.allocator = alloc;
	
    c_afm_file_name := strings.clone_to_cstring(afm_file_name);
    defer delete(c_afm_file_name);
    
    c_data_file_name := strings.clone_to_cstring(data_file_name);
    defer delete(c_data_file_name);
    
	c_res := haru.LoadType1FontFromFile(pdf, c_afm_file_name, c_data_file_name);
		
    return strings.clone_from_cstring(c_res);
}
// Get a TrueType font definition from a file
@(require_results)
get_tt_font_def_from_file :: proc(pdf : Doc, file_name : string, embedding : bool, loc := #caller_location) -> FontDef {
    haru_location = loc;
    
    c_file_name := strings.clone_to_cstring(file_name);
    defer delete(c_file_name);
    
    return haru.GetTTFontDefFromFile(pdf, c_file_name, auto_cast embedding);
}

// Load a TrueType font from a file, the return string must be deleted by the user, it is adviced to use the temp allcator.
@(require_results)
load_tt_font_from_file :: proc(pdf : Doc, file_name : string, embedding : bool, alloc := context.allocator, loc := #caller_location) -> string {
    haru_location = loc;
    context.allocator = alloc;
		
    c_file_name := strings.clone_to_cstring(file_name);
    defer delete(c_file_name);
    
    c_res := haru.LoadTTFontFromFile(pdf, c_file_name, auto_cast embedding);
    
    return strings.clone_from_cstring(c_res);
}

// Load a TrueType font from a file with index, the return string must be deleted by the user, it is adviced to use the temp allcator.
@(require_results)
load_tt_font_from_file2 :: proc(pdf : Doc, file_name : string, index : u32, embedding : bool, alloc := context.allocator, loc := #caller_location) -> string {
    haru_location = loc;
    context.allocator = alloc;
	
    c_file_name := strings.clone_to_cstring(file_name);
    defer delete(c_file_name);
    
    c_res := haru.LoadTTFontFromFile2(pdf, c_file_name, index, auto_cast embedding);
    
    return strings.clone_from_cstring(c_res);
}

// Add a page label to the document
add_page_label :: proc(pdf : Doc, page_num : u32, style : PageNumStyle, first_page : u32, prefix : string, loc := #caller_location) -> Status_code {
    haru_location = loc;
    
    c_prefix := strings.clone_to_cstring(prefix);
    defer delete(c_prefix);
    
    status := haru.AddPageLabel(pdf, page_num, style, first_page, c_prefix);
    if status != 0 {
        log.error("Failed to add page label", location = loc);
    }
    return cast(Status_code)status;
}

// Use Japanese fonts
use_jp_fonts :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseJPFonts(pdf);
    if status != 0 {
        log.error("Failed to use Japanese fonts", location = loc);
    }
    return cast(Status_code)status;
}

// Use Korean fonts
use_kr_fonts :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseKRFonts(pdf);
    if status != 0 {
        log.error("Failed to use Korean fonts", location = loc);
    }
    return cast(Status_code)status;
}

// Use Chinese (Simplified) fonts
use_cns_fonts :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseCNSFonts(pdf);
    if status != 0 {
        log.error("Failed to use Chinese fonts", location = loc);
    }
    return cast(Status_code)status;
}

// Use Traditional Chinese fonts
use_cnt_fonts :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseCNTFonts(pdf);
    if status != 0 {
        log.error("Failed to use Traditional Chinese fonts", location = loc);
    }
    return cast(Status_code)status;
}

///////////

// Create an outline for the document
@(require_results)
create_outline :: proc(pdf : Doc, parent : Outline, title : string, encoder : Encoder, loc := #caller_location) -> Outline {
    haru_location = loc;
    
    c_title := strings.clone_to_cstring(title);
    defer delete(c_title);
    
    return haru.CreateOutline(pdf, parent, c_title, encoder);
}

// Set the opened state for an outline
outline_set_opened :: proc(outline : Outline, opened : bool, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Outline_SetOpened(outline, auto_cast opened);
    if status != 0 {
        log.error("Failed to set outline opened state", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination for an outline
outline_set_destination :: proc(outline : Outline, dst : Destination, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Outline_SetDestination(outline, dst);
    if status != 0 {
        log.error("Failed to set outline destination", location = loc);
    }
    return cast(Status_code)status;
}

///////////

// Create a destination for the page
@(require_results)
page_create_destination :: proc(page : Page, loc := #caller_location) -> Destination {
    haru_location = loc;
    return haru.Page_CreateDestination(page);
}

// Set the XYZ properties for a destination
destination_set_xyz :: proc(dst : Destination, left : f64, top : f64, zoom : f64, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetXYZ(dst, auto_cast left, auto_cast top, auto_cast zoom);
    if status != 0 {
        log.error("Failed to set XYZ properties for destination", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit the whole page
destination_set_fit :: proc(dst : Destination, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFit(dst);
    if status != 0 {
        log.error("Failed to set destination to fit", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit horizontally with a given top position
destination_set_fith :: proc(dst : Destination, top : f64, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFitH(dst, auto_cast top);
    if status != 0 {
        log.error("Failed to set destination fit horizontally", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit vertically with a given left position
destination_set_fitv :: proc(dst : Destination, left : f64, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFitV(dst, auto_cast left);
    if status != 0 {
        log.error("Failed to set destination fit vertically", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit a region with the given coordinates
destination_set_fitr :: proc(dst : Destination, left : f64, bottom : f64, right : f64, top : f64, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFitR(dst, auto_cast left, auto_cast bottom, auto_cast right, auto_cast top);
    if status != 0 {
        log.error("Failed to set destination fit region", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit the whole page with no borders
destination_set_fitb :: proc(dst : Destination, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFitB(dst);
    if status != 0 {
        log.error("Failed to set destination to fit without borders", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit horizontally with the given top position and no borders
destination_set_fitbh :: proc(dst : Destination, top : f64, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFitBH(dst, auto_cast top);
    if status != 0 {
        log.error("Failed to set destination fit horizontally with no borders", location = loc);
    }
    return cast(Status_code)status;
}

// Set the destination to fit vertically with the given left position and no borders
destination_set_fitbv :: proc(dst : Destination, left : f64, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Destination_SetFitBV(dst, auto_cast left);
    if status != 0 {
        log.error("Failed to set destination fit vertically with no borders", location = loc);
    }
    return cast(Status_code)status;
}

////////////////////


// Get an encoder by encoding name
@(require_results)
get_encoder :: proc(pdf : Doc, encoding_name : string, loc := #caller_location) -> Encoder {
    haru_location = loc;
    
    c_encoding_name := strings.clone_to_cstring(encoding_name);
    defer delete(c_encoding_name);
    
    return haru.GetEncoder(pdf, c_encoding_name);
}

// Get the current encoder from the document
@(require_results)
get_current_encoder :: proc(pdf : Doc, loc := #caller_location) -> Encoder {
    haru_location = loc;
    return haru.GetCurrentEncoder(pdf);
}

// Set the current encoder for the document
set_current_encoder :: proc(pdf : Doc, encoding_name : string, loc := #caller_location) -> Status_code {
    haru_location = loc;
    
    c_encoding_name := strings.clone_to_cstring(encoding_name);
    defer delete(c_encoding_name);
    
    status := haru.SetCurrentEncoder(pdf, c_encoding_name);
    if status != 0 {
        log.error("Failed to set current encoder", location = loc);
    }
    return cast(Status_code)status;
}

// Get the encoder type
@(require_results)
encoder_get_type :: proc(encoder : Encoder, loc := #caller_location) -> EncoderType {
    haru_location = loc;
    return haru.Encoder_GetType(encoder);
}

// Get the byte type at a specific index from the encoder's text
@(require_results)
encoder_get_byte_type :: proc(encoder : Encoder, text : string, index : u32, loc := #caller_location) -> ByteType {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Encoder_GetByteType(encoder, c_text, index);
}

// Get the Unicode value for a specific code from the encoder
@(require_results)
encoder_get_unicode :: proc(encoder : Encoder, code : rune, loc := #caller_location) -> rune {
    haru_location = loc;
    return auto_cast haru.Encoder_GetUnicode(encoder, auto_cast code);
}

// Get the writing mode from the encoder
@(require_results)
encoder_get_writing_mode :: proc(encoder : Encoder, loc := #caller_location) -> WritingMode {
    haru_location = loc;
    return haru.Encoder_GetWritingMode(encoder);
}

// Use JP encodings in the document
use_jp_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseJPEncodings(pdf);
    if status != 0 {
        log.error("Failed to set JP encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use KR encodings in the document
use_kr_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseKREncodings(pdf);
    if status != 0 {
        log.error("Failed to set KR encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use CNS encodings in the document
use_cns_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseCNSEncodings(pdf);
    if status != 0 {
        log.error("Failed to set CNS encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use CNT encodings in the document
use_cnt_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseCNTEncodings(pdf);
    if status != 0 {
        log.error("Failed to set CNT encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use UTF encodings in the document
use_utf_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseUTFEncodings(pdf);
    if status != 0 {
        log.error("Failed to set UTF encodings", location = loc);
    }
    return cast(Status_code)status;
}


/////////

// Create an XObject from an image and add it to the page
@(require_results)
page_create_xobject_from_image :: proc(pdf : Doc, page : Page, rect : Rect, image : Image, zoom : bool, loc := #caller_location) -> XObject {
	haru_location = loc;
	
	// Call the underlying function to create the XObject
	return haru.Page_CreateXObjectFromImage(pdf, page, rect, image, auto_cast zoom);
}

// Create an XObject as a white rectangle and add it to the page
@(require_results)
page_create_xobject_as_white_rect :: proc(pdf : Doc, page : Page, rect : Rect, loc := #caller_location) -> XObject {
	haru_location = loc;
	
	// Call the underlying function to create the XObject as a white rectangle
	return haru.Page_CreateXObjectAsWhiteRect(pdf, page, rect);
}


//////////////


// Create a 3D annotation on a page
@(require_results)
page_create_3d_annot :: proc(page : Page, rect : Rect, tb : bool, np : bool, u3d : U3D, ap : Image, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    return haru.Page_Create3DAnnot(page, rect, auto_cast tb, auto_cast np, u3d, ap);
}

// Create a text annotation on a page
@(require_results)
page_create_text_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
	
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateTextAnnot(page, rect, c_text, encoder);
}

// Create a free text annotation on a page
@(require_results)
page_create_free_text_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateFreeTextAnnot(page, rect, c_text, encoder);
}

// Create a line annotation on a page
@(require_results)
page_create_line_annot :: proc(page : Page, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateLineAnnot(page, c_text, encoder);
}

// Create a widget annotation that is only white while printing
@(require_results)
page_create_widget_annot_white_only_while_print :: proc(pdf : Doc, page : Page, rect : Rect, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    return haru.Page_CreateWidgetAnnot_WhiteOnlyWhilePrint(pdf, page, rect);
}

// Create a widget annotation on a page
@(require_results)
page_create_widget_annot :: proc(page : Page, rect : Rect, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    return haru.Page_CreateWidgetAnnot(page, rect);
}

// Create a link annotation on a page
@(require_results)
page_create_link_annot :: proc(page : Page, rect : Rect, dst : Destination, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    return haru.Page_CreateLinkAnnot(page, rect, dst);
}

// Create a URI link annotation on a page
@(require_results)
page_create_uri_link_annot :: proc(page : Page, rect : Rect, uri : string, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_uri := strings.clone_to_cstring(uri);
    defer delete(c_uri);
    
    return haru.Page_CreateURILinkAnnot(page, rect, c_uri);
}

// Create a text markup annotation on a page
@(require_results)
page_create_text_markup_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, subType : AnnotType, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateTextMarkupAnnot(page, rect, c_text, encoder, subType);
}

// Create a highlight annotation on a page
@(require_results)
page_create_highlight_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
	
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateHighlightAnnot(page, rect, c_text, encoder);
}

// Create an underline annotation on a page
@(require_results)
page_create_underline_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateUnderlineAnnot(page, rect, c_text, encoder);
}

// Create a squiggly annotation on a page
@(require_results)
page_create_squiggly_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateSquigglyAnnot(page, rect, c_text, encoder);
}

// Create a strike-out annotation on a page
@(require_results)
page_create_strike_out_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateStrikeOutAnnot(page, rect, c_text, encoder);
}

//////////

// Create a popup annotation on a page
@(require_results)
page_create_popup_annot :: proc(page : Page, rect : Rect, parent : Annotation, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    return haru.Page_CreatePopupAnnot(page, rect, parent);
}

// Create a stamp annotation on a page
@(require_results)
page_create_stamp_annot :: proc(page : Page, rect : Rect, name : StampAnnotName, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateStampAnnot(page, rect, name, c_text, encoder);
}

// Create a projection annotation on a page
@(require_results)
page_create_projection_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateProjectionAnnot(page, rect, c_text, encoder);
}

// Create a square annotation on a page
@(require_results)
page_create_square_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateSquareAnnot(page, rect, c_text, encoder);
}

// Create a circle annotation on a page
@(require_results)
page_create_circle_annot :: proc(page : Page, rect : Rect, text : string, encoder : Encoder, loc := #caller_location) -> Annotation {
    haru_location = loc;
    
    c_text := strings.clone_to_cstring(text);
    defer delete(c_text);
    
    return haru.Page_CreateCircleAnnot(page, rect, c_text, encoder);
}

///////////////

// Set the highlight mode for a link annotation
link_annot_set_highlight_mode :: proc(annot : Annotation, mode : AnnotHighlightMode, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.LinkAnnot_SetHighlightMode(annot, mode);
}

// Set JavaScript for a link annotation
link_annot_set_javascript :: proc(annot : Annotation, javascript : JavaScript, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.LinkAnnot_SetJavaScript(annot, javascript);
}

// Set the border style for a link annotation
link_annot_set_border_style :: proc(annot : Annotation, width : f32, dash_on : u16, dash_off : u16, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.LinkAnnot_SetBorderStyle(annot, width, dash_on, dash_off);
}

// Set the icon for a text annotation
text_annot_set_icon :: proc(annot : Annotation, icon : AnnotIcon, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.TextAnnot_SetIcon(annot, icon);
}

// Set whether a text annotation is opened
text_annot_set_opened :: proc(annot : Annotation, opened : bool, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.TextAnnot_SetOpened(annot, auto_cast opened);
}

// Set RGB color for an annotation
annot_set_rgb_color :: proc(annot : Annotation, color : RGBColor, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Annot_SetRGBColor(annot, color);
}

// Set CMYK color for an annotation
annot_set_cmyk_color :: proc(annot : Annotation, color : CMYKColor, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Annot_SetCMYKColor(annot, color);
}

// Set gray color for an annotation
annot_set_gray_color :: proc(annot : Annotation, color : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Annot_SetGrayColor(annot, color);
}

// Set no color for an annotation
annot_set_no_color :: proc(annot : Annotation, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Annot_SetNoColor(annot);
}

//////////////

// Set the title for a markup annotation
markup_annot_set_title :: proc(annot : Annotation, name : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_name := strings.clone_to_cstring(name);
	defer delete(c_name);
	
	return cast(Status_code)haru.MarkupAnnot_SetTitle(annot, c_name);
}

// Set the subject for a markup annotation
markup_annot_set_subject :: proc(annot : Annotation, name : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_name := strings.clone_to_cstring(name);
	defer delete(c_name);
	
	return cast(Status_code)haru.MarkupAnnot_SetSubject(annot, c_name);
}

// Set the creation date for a markup annotation
markup_annot_set_creation_date :: proc(annot : Annotation, value : Date, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetCreationDate(annot, value);
}

// Set the transparency for a markup annotation
markup_annot_set_transparency :: proc(annot : Annotation, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetTransparency(annot, value);
}

// Set the intent for a markup annotation
markup_annot_set_intent :: proc(annot : Annotation, intent : AnnotIntent, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetIntent(annot, intent);
}

///////

// Set the popup annotation for a markup annotation
markup_annot_set_popup :: proc(annot : Annotation, popup : Annotation, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetPopup(annot, popup);
}

// Set the rectangle difference for a markup annotation
markup_annot_set_rect_diff :: proc(annot : Annotation, rect : Rect, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetRectDiff(annot, rect);
}

// Set the cloud effect intensity for a markup annotation
markup_annot_set_cloud_effect :: proc(annot : Annotation, cloudIntensity : i32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetCloudEffect(annot, cloudIntensity);
}

// Set the interior RGB color for a markup annotation
markup_annot_set_interior_rgb_color :: proc(annot : Annotation, color : RGBColor, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorRGBColor(annot, color);
}

// Set the interior CMYK color for a markup annotation
markup_annot_set_interior_cmyk_color :: proc(annot : Annotation, color : CMYKColor, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorCMYKColor(annot, color);
}

// Set the interior gray color for a markup annotation
markup_annot_set_interior_gray_color :: proc(annot : Annotation, color : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorGrayColor(annot, color);
}

// Set the interior transparent for a markup annotation
markup_annot_set_interior_transparent :: proc(annot : Annotation, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorTransparent(annot);
}

// Set the quad points for a text markup annotation
text_markup_set_quad_points :: proc(annot : Annotation, lb : Point, rb : Point, rt : Point, lt : Point, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.TextMarkupAnnot_SetQuadPoints(annot, lb, rb, rt, lt);
}

///////////

// Set the 3D view for an annotation
annot_set_3d_view :: proc(mmgr : MMgr, annot : Annotation, annot3d : Annotation, view : Dict, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Annot_Set3DView(mmgr, annot, annot3d, view);
}

// Set the popup annotation's opened state
popup_annot_set_opened :: proc(annot : Annotation, opened : bool, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.PopupAnnot_SetOpened(annot, auto_cast opened);
}

// Set the line ending style for a free text annotation
free_text_annot_set_line_ending_style :: proc(annot : Annotation, startStyle : LineAnnotEndingStyle, endStyle : LineAnnotEndingStyle, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.FreeTextAnnot_SetLineEndingStyle(annot, startStyle, endStyle);
}

// Set the 3-point callout line for a free text annotation
free_text_annot_set_3_point_callout_line :: proc(annot : Annotation, startPoint : Point, kneePoint : Point, endPoint : Point, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.FreeTextAnnot_Set3PointCalloutLine(annot, startPoint, kneePoint, endPoint);
}

// Set the 2-point callout line for a free text annotation
free_text_annot_set_2_point_callout_line :: proc(annot : Annotation, startPoint : Point, endPoint : Point, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.FreeTextAnnot_Set2PointCalloutLine(annot, startPoint, endPoint);
}

// Set the default style for a free text annotation
free_text_annot_set_default_style :: proc(annot : Annotation, style : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_style := strings.clone_to_cstring(style);
	defer delete(c_style);
	
	return cast(Status_code)haru.FreeTextAnnot_SetDefaultStyle(annot, c_style);
}

/////////

// Set the position for a line annotation
line_annot_set_position :: proc(annot : Annotation, startPoint : Point, startStyle : LineAnnotEndingStyle, endPoint : Point, endStyle : LineAnnotEndingStyle, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.LineAnnot_SetPosition(annot, startPoint, startStyle, endPoint, endStyle);
}

// Set the leader for a line annotation
line_annot_set_leader :: proc(annot : Annotation, leaderLen : i32, leaderExtLen : i32, leaderOffsetLen : i32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.LineAnnot_SetLeader(annot, leaderLen, leaderExtLen, leaderOffsetLen);
}

// Set the caption for a line annotation
line_annot_set_caption :: proc(annot : Annotation, showCaption : bool, position : LineAnnotCapPosition, horzOffset : i32, vertOffset : i32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.LineAnnot_SetCaption(annot, auto_cast showCaption, position, horzOffset, vertOffset);
}

// Set the border style for an annotation
annotation_set_border_style :: proc(annot : Annotation, subtype : BSSubtype, width : f32, dash_on : u16, dash_off : u16, dash_phase : u16, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Annotation_SetBorderStyle(annot, subtype, width, dash_on, dash_off, dash_phase);
}

// Set extra data for a projection annotation
projection_annot_set_ex_data :: proc(annot : Annotation, exdata : ExData, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.ProjectionAnnot_SetExData(annot, exdata);
}


/////


// Load a PNG image from memory
load_png_image_from_mem :: proc(pdf : Doc, data : []u8, loc := #caller_location) -> Image {
	haru_location = loc;
	
	return cast(Image)haru.LoadPngImageFromMem(pdf, raw_data(data), auto_cast len(data));
}

// Load a PNG image from a file
load_png_image_from_file :: proc(pdf : Doc, filename : string, loc := #caller_location) -> Image {
	haru_location = loc;
	
	c_filename := strings.clone_to_cstring(filename);
	defer delete(c_filename);
	
	return cast(Image)haru.LoadPngImageFromFile(pdf, c_filename);
}

// Load a PNG image from a file (alternative version)
load_png_image_from_file2 :: proc(pdf : Doc, filename : string, loc := #caller_location) -> Image {
	haru_location = loc;
	
	c_filename := strings.clone_to_cstring(filename);
	defer delete(c_filename);
	
	return cast(Image)haru.LoadPngImageFromFile2(pdf, c_filename);
}

// Load a JPEG image from a file
load_jpeg_image_from_file :: proc(pdf : Doc, filename : string, loc := #caller_location) -> Image {
	haru_location = loc;
	
	c_filename := strings.clone_to_cstring(filename);
	defer delete(c_filename);
	
	return cast(Image)haru.LoadJpegImageFromFile(pdf, c_filename);
}

// Load a JPEG image from memory
load_jpeg_image_from_mem :: proc(pdf : Doc, data : []u8, loc := #caller_location) -> Image {
	haru_location = loc;
	
	return cast(Image)haru.LoadJpegImageFromMem(pdf, raw_data(data), auto_cast len(data));
}

// Load a U3D file from a file
load_u3d_from_file :: proc(pdf : Doc, filename : string, loc := #caller_location) -> Image {
	haru_location = loc;
	
	c_filename := strings.clone_to_cstring(filename);
	defer delete(c_filename);
	
	return cast(Image)haru.LoadU3DFromFile(pdf, c_filename);
}

// Load a U3D file from memory
load_u3d_from_mem :: proc(pdf : Doc, data : []u8, loc := #caller_location) -> Image {
	haru_location = loc;
	
	return cast(Image)haru.LoadU3DFromMem(pdf, raw_data(data), auto_cast len(data));
}

//////

// Load a 1-bit image from memory
image_load_raw_1bit_image_from_mem :: proc(pdf : Doc, buf : []u8, width : u32, height : u32, line_width : u32, black_is1 : bool, top_is_first : bool, loc := #caller_location) -> Image {
	haru_location = loc;
	
	//TODO assert
	
	return cast(Image)haru.Image_LoadRaw1BitImageFromMem(pdf, raw_data(buf), width, height, line_width, auto_cast black_is1, auto_cast top_is_first);
}

// Load a raw image from a file
load_raw_image_from_file :: proc(pdf : Doc, filename : string, width : u32, height : u32, color_space : ColorSpace, loc := #caller_location) -> Image {
	haru_location = loc;
	
	c_filename := strings.clone_to_cstring(filename);
	defer delete(c_filename);
	
	return cast(Image)haru.LoadRawImageFromFile(pdf, c_filename, width, height, color_space);
}

// Load a raw image from memory
@(require_results)
load_raw_image_from_mem :: proc(pdf : Doc, buf : []u8, width : u32, height : u32, color_space : ColorSpace, bits_per_component : u32, loc := #caller_location) -> Image {
	haru_location = loc;
	
	//components : u32 = 3; //TODO other colorspaces 
	//assert(auto_cast len(buf) == width * height * bits_per_component * components, "mismatch");
	
	return cast(Image)haru.LoadRawImageFromMem(pdf, raw_data(buf), width, height, color_space, bits_per_component);
}

// Add an SMask to an image
image_add_smask :: proc(image : Image, smask : Image, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Image_AddSMask(image, smask);
}

// Get the size of an image
image_get_size :: proc(image : Image, loc := #caller_location) -> Point {
	haru_location = loc;
	
	return cast(Point)haru.Image_GetSize(image);
}

// Get the size of an image (with size pointer)
image_get_size2 :: proc(image : Image, loc := #caller_location) -> (size : [2]f32, status : Status_code) {
	haru_location = loc;
	
	s : Point;
	status = cast(Status_code)haru.Image_GetSize2(image, &s);
	
	return [2]f32{s.x, s.y}, status;
}

// Get the width of an image
image_get_width :: proc(image : Image, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return cast(u32)haru.Image_GetWidth(image);
}

// Get the height of an image
image_get_height :: proc(image : Image, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return cast(u32)haru.Image_GetHeight(image);
}

// Get the bits per component of an image
image_get_bits_per_component :: proc(image : Image, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return cast(u32)haru.Image_GetBitsPerComponent(image);
}

// Get the color space of an image, you may use the temp allocator
image_get_color_space :: proc(image : Image, alloc := context.allocator, loc := #caller_location) -> string {
	haru_location = loc;
	context.temp_allocator = alloc;
	
	c_str := haru.Image_GetColorSpace(image);
	return strings.clone_from_cstring(c_str);
}

// Set the color mask for an image
image_set_color_mask :: proc(image : Image, rmin : u32, rmax : u32, gmin : u32, gmax : u32, bmin : u32, bmax : u32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Image_SetColorMask(image, rmin, rmax, gmin, gmax, bmin, bmax);
}

// Set the mask image for an image
image_set_mask_image :: proc(image : Image, mask_image : Image, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.Image_SetMaskImage(image, mask_image);
}

/////////

// Set an information attribute
set_info_attr :: proc(pdf : Doc, info_type : InfoType, value : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	// Convert string to cstring
	c_value := strings.clone_to_cstring(value);
	defer delete(c_value);
	
	return cast(Status_code)haru.SetInfoAttr(pdf, info_type, c_value);
}

// Get an information attribute, you may use the temp allocator
get_info_attr :: proc(pdf : Doc, info_type : InfoType, alloc := context.allocator, loc := #caller_location) -> string {
	haru_location = loc;
	context.temp_allocator = alloc;
	
	c_str := haru.GetInfoAttr(pdf, info_type);
	return strings.clone_from_cstring(c_str);
}

// Set an information date attribute
set_info_date_attr :: proc(pdf : Doc, info_type : InfoType, value : Date, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.SetInfoDateAttr(pdf, info_type, value);
}

/////////

// Set the password for the document
set_password :: proc(pdf : Doc, owner_passwd : string, user_passwd : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	// Convert strings to cstrings
	c_owner_passwd := strings.clone_to_cstring(owner_passwd);
	defer delete(c_owner_passwd);
	
	c_user_passwd := strings.clone_to_cstring(user_passwd);
	defer delete(c_user_passwd);
	
	return cast(Status_code)haru.SetPassword(pdf, c_owner_passwd, c_user_passwd);
}

// Set the permissions for the document
set_permission :: proc(pdf : Doc, permission : u32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.SetPermission(pdf, permission);
}

// Set the encryption mode for the document
set_encryption_mode :: proc(pdf : Doc, mode : EncryptMode, key_len : u32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.SetEncryptionMode(pdf, mode, key_len);
}

/////////

// Set the compression mode for the PDF
set_compression_mode :: proc(pdf : Doc, mode : Compression_mode, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.SetCompressionMode(pdf, auto_cast mode);
}

// Get the font name from the font object
font_get_font_name :: proc(font : Font, loc := #caller_location) -> string {
	haru_location = loc;
	
	c_font_name := haru.Font_GetFontName(font);
	return strings.clone_from_cstring(c_font_name);
}

// Get the encoding name from the font object
font_get_encoding_name :: proc(font : Font, loc := #caller_location) -> string {
	haru_location = loc;
	
	c_encoding_name := haru.Font_GetEncodingName(font);
	return strings.clone_from_cstring(c_encoding_name);
}

// Get the Unicode width for a given font and code
font_get_unicode_width :: proc(font : Font, code : rune, loc := #caller_location) -> i32 {
	haru_location = loc;
	
	return haru.Font_GetUnicodeWidth(font, auto_cast code);
}

// Get the bounding box of the font
font_get_bbox :: proc(font : Font, loc := #caller_location) -> Box {
	haru_location = loc;
	
	return haru.Font_GetBBox(font);
}

// Get the ascent value of the font
font_get_ascent :: proc(font : Font, loc := #caller_location) -> i32 {
	haru_location = loc;
	
	return haru.Font_GetAscent(font);
}

// Get the descent value of the font
font_get_descent :: proc(font : Font, loc := #caller_location) -> i32 {
	haru_location = loc;
	
	return haru.Font_GetDescent(font);
}

// Get the x-height value of the font
font_get_x_height :: proc(font : Font, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return haru.Font_GetXHeight(font);
}

// Get the cap height value of the font
font_get_cap_height :: proc(font : Font, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return haru.Font_GetCapHeight(font);
}

// Get the text width of the font for a given byte array
font_text_width :: proc(font : Font, text : [^]byte, len : u32, loc := #caller_location) -> TextWidth {
	haru_location = loc;
	
	return haru.Font_TextWidth(font, text, len);
}

// Measure the text width with various formatting options
font_measure_text :: proc(font : Font, text : [^]byte, len : u32, width : f32, font_size : f32, char_space : f32, word_space : f32, wordwrap : bool, real_width : ^f32, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return haru.Font_MeasureText(font, text, len, width, font_size, char_space, word_space, auto_cast wordwrap, real_width);
}

//////////

// Attach a file to the PDF
attach_file :: proc(pdf : Doc, file : string, loc := #caller_location) -> EmbeddedFile {
	haru_location = loc;
	
	c_file := strings.clone_to_cstring(file);
	defer delete(c_file);
	
	return haru.AttachFile(pdf, c_file);
}

// Create a new graphics state for the PDF
create_ext_gstate :: proc(pdf : Doc, loc := #caller_location) -> ExtGState {
	haru_location = loc;
	
	return haru.CreateExtGState(pdf);
}

// Set the alpha stroke value for a graphics state
ext_gstate_set_alpha_stroke :: proc(ext_gstate : ExtGState, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.ExtGState_SetAlphaStroke(ext_gstate, value);
}

// Set the alpha fill value for a graphics state
ext_gstate_set_alpha_fill :: proc(ext_gstate : ExtGState, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.ExtGState_SetAlphaFill(ext_gstate, value);
}

// Set the blend mode for a graphics state
ext_gstate_set_blend_mode :: proc(ext_gstate : ExtGState, mode : BlendMode, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.ExtGState_SetBlendMode(ext_gstate, mode);
}

//////////


// Get the width of the text on the page
page_text_width :: proc(page : Page, text : string, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return haru.Page_TextWidth(page, c_text);
}

// Measure the text on the page
page_measure_text :: proc(page : Page, text : string, width : f32, wordwrap : bool, real_width : ^f32, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return haru.Page_MeasureText(page, c_text, width, auto_cast wordwrap, real_width);
}

// Get the width of the page
page_get_width :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetWidth(page);
}

// Get the height of the page
page_get_height :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetHeight(page);
}

// Get the graphics mode of the page
page_get_gmode :: proc(page : Page, loc := #caller_location) -> u16 {
	haru_location = loc;
	
	return haru.Page_GetGMode(page);
}

// Get the current position on the page (with status)
page_get_current_pos2 :: proc(page : Page, loc := #caller_location) -> (pos : [2]f32, status : Status_code) {
	haru_location = loc;
	
	p : Point;
	status = cast(Status_code)haru.Page_GetCurrentPos2(page, &p);
	
	return {p.x, p.y}, status;
}

// Get the current text position on the page
page_get_current_text_pos :: proc(page : Page, loc := #caller_location) -> Point {
	haru_location = loc;
	
	return haru.Page_GetCurrentTextPos(page);
}

// Get the current text position on the page (with status)
page_get_current_text_pos2 :: proc(page : Page, loc := #caller_location) -> (pos : [2]f32, status : Status_code) {
	haru_location = loc;
	
	p : Point;
	status = cast(Status_code)haru.Page_GetCurrentTextPos2(page, &p);
	
	return {p.x, p.y}, status;
}

// Get the current font on the page
page_get_current_font :: proc(page : Page, loc := #caller_location) -> Font {
	haru_location = loc;
	
	return haru.Page_GetCurrentFont(page);
}

// Get the current font size on the page
page_get_current_font_size :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetCurrentFontSize(page);
}

// Get the transformation matrix of the page
page_get_trans_matrix :: proc(page : Page, loc := #caller_location) -> TransMatrix {
	haru_location = loc;
	
	return haru.Page_GetTransMatrix(page);
}

// Get the line width on the page
page_get_line_width :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetLineWidth(page);
}

// Get the line cap style on the page
page_get_line_cap :: proc(page : Page, loc := #caller_location) -> LineCap {
	haru_location = loc;
	
	return haru.Page_GetLineCap(page);
}

// Get the line join style on the page
page_get_line_join :: proc(page : Page, loc := #caller_location) -> LineJoin {
	haru_location = loc;
	
	return haru.Page_GetLineJoin(page);
}

// Get the miter limit on the page
page_get_miter_limit :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetMiterLimit(page);
}

// Get the dash style on the page
page_get_dash :: proc(page : Page, loc := #caller_location) -> DashMode {
	haru_location = loc;
	
	return haru.Page_GetDash(page);
}

// Get the flatness value on the page
page_get_flat :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetFlat(page);
}

// Get the character space on the page
page_get_char_space :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetCharSpace(page);
}

// Get the word space on the page
page_get_word_space :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetWordSpace(page);
}

// Get the horizontal scaling value on the page
page_get_horizontal_scaling :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetHorizontalScalling(page);
}

// Get the text leading value on the page
page_get_text_leading :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetTextLeading(page);
}

// Get the text rendering mode on the page
page_get_text_rendering_mode :: proc(page : Page, loc := #caller_location) -> TextRenderingMode {
	haru_location = loc;
	
	return haru.Page_GetTextRenderingMode(page);
}

// Get the text rise value on the page
page_get_text_rise :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetTextRise(page);
}

// Get the RGB fill color on the page
page_get_rgb_fill :: proc(page : Page, loc := #caller_location) -> RGBColor {
	haru_location = loc;
	
	return haru.Page_GetRGBFill(page);
}

// Get the RGB stroke color on the page
page_get_rgb_stroke :: proc(page : Page, loc := #caller_location) -> RGBColor {
	haru_location = loc;
	
	return haru.Page_GetRGBStroke(page);
}

// Get the CMYK fill color on the page
page_get_cmyk_fill :: proc(page : Page, loc := #caller_location) -> CMYKColor {
	haru_location = loc;
	
	return haru.Page_GetCMYKFill(page);
}

// Get the CMYK stroke color on the page
page_get_cmyk_stroke :: proc(page : Page, loc := #caller_location) -> CMYKColor {
	haru_location = loc;
	
	return haru.Page_GetCMYKStroke(page);
}

// Get the gray fill color on the page
page_get_gray_fill :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetGrayFill(page);
}

// Get the gray stroke color on the page
page_get_gray_stroke :: proc(page : Page, loc := #caller_location) -> f32 {
	haru_location = loc;
	
	return haru.Page_GetGrayStroke(page);
}

// Get the stroking color space on the page
page_get_stroking_color_space :: proc(page : Page, loc := #caller_location) -> ColorSpace {
	haru_location = loc;
	
	return haru.Page_GetStrokingColorSpace(page);
}

// Get the filling color space on the page
page_get_filling_color_space :: proc(page : Page, loc := #caller_location) -> ColorSpace {
	haru_location = loc;
	
	return haru.Page_GetFillingColorSpace(page);
}

// Get the text matrix on the page
page_get_text_matrix :: proc(page : Page, loc := #caller_location) -> TransMatrix {
	haru_location = loc;
	
	return haru.Page_GetTextMatrix(page);
}

// Get the graphics state depth on the page
page_get_gstate_depth :: proc(page : Page, loc := #caller_location) -> u32 {
	haru_location = loc;
	
	return haru.Page_GetGStateDepth(page);
}

/////////////

page_set_line_width :: proc(page : Page, line_width : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetLineWidth(page, line_width);
}

page_set_line_cap :: proc(page : Page, line_cap : LineCap, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetLineCap(page, line_cap);
}

page_set_line_join :: proc(page : Page, line_join : LineJoin, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetLineJoin(page, line_join);
}

page_set_miter_limit :: proc(page : Page, miter_limit : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetMiterLimit(page, miter_limit);
}

page_set_dash :: proc(page : Page, dash_ptn : ^f32, num_param : u32, phase : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetDash(page, dash_ptn, num_param, phase);
}

page_set_flat :: proc(page : Page, flatness : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetFlat(page, flatness);
}

page_set_ext_gstate :: proc(page : Page, ext_gstate : ExtGState, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetExtGState(page, ext_gstate);
}

page_set_shading :: proc(page : Page, shading : Shading, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetShading(page, shading);
}

page_g_save :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_GSave(page);
}

page_g_restore :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_GRestore(page);
}

page_concat :: proc(page : Page, a : f32, b : f32, c : f32, d : f32, x : f32, y : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Concat(page, a, b, c, d, x, y);
}

page_move_to :: proc(page : Page, x : f32, y : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_MoveTo(page, x, y);
}

page_line_to :: proc(page : Page, x : f32, y : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_LineTo(page, x, y);
}

page_curve_to :: proc(page : Page, x1 : f32, y1 : f32, x2 : f32, y2 : f32, x3 : f32, y3 : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_CurveTo(page, x1, y1, x2, y2, x3, y3);
}

page_curve_to2 :: proc(page : Page, x2 : f32, y2 : f32, x3 : f32, y3 : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_CurveTo2(page, x2, y2, x3, y3);
}

page_curve_to3 :: proc(page : Page, x1 : f32, y1 : f32, x3 : f32, y3 : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_CurveTo3(page, x1, y1, x3, y3);
}

page_close_path :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_ClosePath(page);
}

page_rectangle :: proc(page : Page, x : f32, y : f32, width : f32, height : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Rectangle(page, x, y, width, height);
}

page_stroke :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Stroke(page);
}

page_close_path_stroke :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_ClosePathStroke(page);
}

page_fill :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Fill(page);
}

page_eofill :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Eofill(page);
}

page_fill_stroke :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_FillStroke(page);
}

page_eofill_stroke :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_EofillStroke(page);
}

page_close_path_fill_stroke :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_ClosePathFillStroke(page);
}

page_close_path_eofill_stroke :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_ClosePathEofillStroke(page);
}

page_end_path :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_EndPath(page);
}

page_clip :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Clip(page);
}

page_eoclip :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Eoclip(page);
}

page_begin_text :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_BeginText(page);
}

page_end_text :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_EndText(page);
}

page_set_char_space :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetCharSpace(page, value);
}

page_set_word_space :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetWordSpace(page, value);
}

page_set_horizontal_scaling :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetHorizontalScalling(page, value);
}

page_set_text_leading :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetTextLeading(page, value);
}

page_set_font_and_size :: proc(page : Page, font : Font, size : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetFontAndSize(page, font, size);
}

page_set_text_rendering_mode :: proc(page : Page, mode : TextRenderingMode, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetTextRenderingMode(page, mode);
}

page_set_text_rise :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetTextRise(page, value);
}

page_set_text_raise :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetTextRaise(page, value);
}

page_move_text_pos :: proc(page : Page, x : f32, y : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_MoveTextPos(page, x, y);
}

page_move_text_pos2 :: proc(page : Page, x : f32, y : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_MoveTextPos2(page, x, y);
}

page_set_text_matrix :: proc(page : Page, a : f32, b : f32, c : f32, d : f32, x : f32, y : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetTextMatrix(page, a, b, c, d, x, y);
}

page_move_to_next_line :: proc(page : Page, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_MoveToNextLine(page);
}

page_show_text :: proc(page : Page, text : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return cast(Status_code)haru.Page_ShowText(page, c_text);
}

page_show_text_next_line :: proc(page : Page, text : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return cast(Status_code)haru.Page_ShowTextNextLine(page, c_text);
}

page_show_text_next_line_ex :: proc(page : Page, word_space : f32, char_space : f32, text : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return cast(Status_code)haru.Page_ShowTextNextLineEx(page, word_space, char_space, c_text);
}

page_set_gray_fill :: proc(page : Page, gray : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetGrayFill(page, gray);
}

page_set_gray_stroke :: proc(page : Page, gray : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetGrayStroke(page, gray);
}

page_set_rgb_fill :: proc(page : Page, r : f32, g : f32, b : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetRGBFill(page, r, g, b);
}

page_set_rgb_stroke :: proc(page : Page, r : f32, g : f32, b : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetRGBStroke(page, r, g, b);
}

page_set_cmyk_fill :: proc(page : Page, c : f32, m : f32, y : f32, k : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetCMYKFill(page, c, m, y, k);
}

page_set_cmyk_stroke :: proc(page : Page, c : f32, m : f32, y : f32, k : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetCMYKStroke(page, c, m, y, k);
}

//////////

shading_new :: proc(pdf : Doc, type : ShadingType, color_space : ColorSpace, x_min : f32, x_max : f32, y_min : f32, y_max : f32, loc := #caller_location) -> Shading {
	haru_location = loc;
	return haru.Shading_New(pdf, type, color_space, x_min, x_max, y_min, y_max);
}

shading_add_vertex_rgb :: proc(shading : Shading, edge_flag : Shading_FreeFormTriangleMeshEdgeFlag, x : f32, y : f32, r : u8, g : u8, b : u8, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Shading_AddVertexRGB(shading, edge_flag, x, y, r, g, b);
}

page_execute_xobject :: proc(page : Page, obj : XObject, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_ExecuteXObject(page, obj);
}

page_new_content_stream :: proc(page : Page, new_stream : ^Dict, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_New_Content_Stream(page, new_stream);
}

page_insert_shared_content_stream :: proc(page : Page, shared_stream : Dict, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Insert_Shared_Content_Stream(page, shared_stream);
}

page_draw_image :: proc(page : Page, image : Image, x : f32, y : f32, width : f32, height : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_DrawImage(page, image, x, y, width, height);
}

page_circle :: proc(page : Page, x : f32, y : f32, ray : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Circle(page, x, y, ray);
}

page_ellipse :: proc(page : Page, x : f32, y : f32, x_ray : f32, y_ray : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Ellipse(page, x, y, x_ray, y_ray);
}

page_arc :: proc(page : Page, x : f32, y : f32, ray : f32, ang1 : f32, ang2 : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_Arc(page, x, y, ray, ang1, ang2);
}

page_text_out :: proc(page : Page, x_pos : f32, y_pos : f32, text : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return cast(Status_code)haru.Page_TextOut(page, x_pos, y_pos, c_text);
}

page_text_rect :: proc(page : Page, left : f32, top : f32, right : f32, bottom : f32, text : string, align : TextAlignment, len : ^u32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_text := strings.clone_to_cstring(text);
	defer delete(c_text);
	
	return cast(Status_code)haru.Page_TextRect(page, left, top, right, bottom, c_text, align, len);
}

page_set_slideshow :: proc(page : Page, type : TransitionStyle, disp_time : f32, trans_time : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	return cast(Status_code)haru.Page_SetSlideShow(page, type, disp_time, trans_time);
}

icc_load_icc_from_mem :: proc(pdf : Doc, mmgr : MMgr, iccdata : Stream, xref : Xref, num_component : int, loc := #caller_location) -> OutputIntent {
	haru_location = loc;
	return haru.ICC_LoadIccFromMem(pdf, mmgr, iccdata, xref, num_component);
}

load_icc_profile_from_file :: proc(pdf : Doc, icc_file_name : string, num_component : int, loc := #caller_location) -> OutputIntent {
	haru_location = loc;
	
	c_icc_file_name := strings.clone_to_cstring(icc_file_name);
	defer delete(c_icc_file_name);
	
	return haru.LoadIccProfileFromFile(pdf, c_icc_file_name, num_component);
}
