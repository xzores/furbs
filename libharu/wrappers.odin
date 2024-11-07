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

//This must be deleted by the user, using the temp allocator is recommended.
@(require_results)
get_version :: proc(alloc := context.allocator, loc := #caller_location) -> string {
	haru_location = loc;
	context.allocator = alloc;
	ver_string := haru.GetVersion();
	return strings.clone_from_cstring(ver_string);
}

@(require_results)
new_simple :: proc (user_error_fn : Error_Handler, user_data : rawptr, loc := #caller_location) -> Doc {
	haru_location = loc;
	doc := haru.New(user_error_fn, user_data);
	if doc == nil {
		log.error("Failed to create document", location = loc);
	}
	return doc;
}

@(require_results)
new_extended :: proc (user_error_fn : Error_Handler, user_alloc_fn : Alloc_Func, user_free_fn : Free_Func, user_data : rawptr, mem_pool_buf_size : u32 = 1024 * 1024, loc := #caller_location) -> Doc {
	haru_location = loc;
	doc := haru.NewEx(user_error_fn, user_alloc_fn, user_free_fn, mem_pool_buf_size, user_data);
	if doc == nil {
		log.error("Failed to create document", location = loc);
	}	
	return doc;
}

new :: proc {new_simple, new_extended};

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

// Create a new document
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
set_pages_configuration :: proc(pdf : Doc, page_per_page : u32, loc := #caller_location) -> Status_code {
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
set_page_layout :: proc(pdf : Doc, layout : PageLayout, loc := #caller_location) -> Status_code {
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
set_page_mode :: proc(pdf : Doc, mode : PageMode, loc := #caller_location) -> Status_code {
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
set_page_width :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetWidth(page, value);
    if status != 0 {
        log.error("Failed to set page width", location = loc);
    }
    return cast(Status_code)status;
}

// Set the height of the page
set_page_height :: proc(page : Page, value : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetHeight(page, value);
    if status != 0 {
        log.error("Failed to set page height", location = loc);
    }
    return cast(Status_code)status;
}

// Set the boundaries of the page
set_page_boundary :: proc(page : Page, boundary : PageBoundary, left : f32, bottom : f32, right : f32, top : f32, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetBoundary(page, boundary, left, bottom, right, top);
    if status != 0 {
        log.error("Failed to set page boundary", location = loc);
    }
    return cast(Status_code)status;
}

// Set the size of the page
set_page_size :: proc(page : Page, size : PageSizes, direction : PageDirection, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetSize(page, size, direction);
    if status != 0 {
        log.error("Failed to set page size", location = loc);
    }
    return cast(Status_code)status;
}

// Set the rotation of the page
set_page_rotate :: proc(page : Page, angle : u16, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.Page_SetRotate(page, angle);
    if status != 0 {
        log.error("Failed to set page rotation", location = loc);
    }
    return cast(Status_code)status;
}

// Set the zoom of the page
set_page_zoom :: proc(page : Page, zoom : f32, loc := #caller_location) -> Status_code {
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
set_use_jp_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseJPEncodings(pdf);
    if status != 0 {
        log.error("Failed to set JP encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use KR encodings in the document
set_use_kr_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseKREncodings(pdf);
    if status != 0 {
        log.error("Failed to set KR encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use CNS encodings in the document
set_use_cns_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseCNSEncodings(pdf);
    if status != 0 {
        log.error("Failed to set CNS encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use CNT encodings in the document
set_use_cnt_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
    haru_location = loc;
    status := haru.UseCNTEncodings(pdf);
    if status != 0 {
        log.error("Failed to set CNT encodings", location = loc);
    }
    return cast(Status_code)status;
}

// Use UTF encodings in the document
set_use_utf_encodings :: proc(pdf : Doc, loc := #caller_location) -> Status_code {
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
annot_markup_set_title :: proc(annot : Annotation, name : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_name := strings.clone_to_cstring(name);
	defer delete(c_name);
	
	return cast(Status_code)haru.MarkupAnnot_SetTitle(annot, c_name);
}

// Set the subject for a markup annotation
annot_markup_set_subject :: proc(annot : Annotation, name : string, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	c_name := strings.clone_to_cstring(name);
	defer delete(c_name);
	
	return cast(Status_code)haru.MarkupAnnot_SetSubject(annot, c_name);
}

// Set the creation date for a markup annotation
annot_markup_set_creation_date :: proc(annot : Annotation, value : Date, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetCreationDate(annot, value);
}

// Set the transparency for a markup annotation
annot_markup_set_transparency :: proc(annot : Annotation, value : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetTransparency(annot, value);
}

// Set the intent for a markup annotation
annot_markup_set_intent :: proc(annot : Annotation, intent : AnnotIntent, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetIntent(annot, intent);
}

///////

// Set the popup annotation for a markup annotation
annot_markup_set_popup :: proc(annot : Annotation, popup : Annotation, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetPopup(annot, popup);
}

// Set the rectangle difference for a markup annotation
annot_markup_set_rect_diff :: proc(annot : Annotation, rect : Rect, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetRectDiff(annot, rect);
}

// Set the cloud effect intensity for a markup annotation
annot_markup_set_cloud_effect :: proc(annot : Annotation, cloudIntensity : i32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetCloudEffect(annot, cloudIntensity);
}

// Set the interior RGB color for a markup annotation
annot_markup_set_interior_rgb_color :: proc(annot : Annotation, color : RGBColor, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorRGBColor(annot, color);
}

// Set the interior CMYK color for a markup annotation
annot_markup_set_interior_cmyk_color :: proc(annot : Annotation, color : CMYKColor, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorCMYKColor(annot, color);
}

// Set the interior gray color for a markup annotation
annot_markup_set_interior_gray_color :: proc(annot : Annotation, color : f32, loc := #caller_location) -> Status_code {
	haru_location = loc;
	
	return cast(Status_code)haru.MarkupAnnot_SetInteriorGrayColor(annot, color);
}

// Set the interior transparent for a markup annotation
annot_markup_set_interior_transparent :: proc(annot : Annotation, loc := #caller_location) -> Status_code {
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
	
	return cast(Status_code)haru.PopupAnnot_SetOpened(annot, opened);
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
	
	return cast(Status_code)haru.FreeTextAnnot_SetDefaultStyle(annot, style);
}
