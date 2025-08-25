package cef_internal;

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

CEF_STRING_TYPE_UTF8 :: false;
CEF_STRING_TYPE_UTF16 :: true; //It is complied with this.
CEF_STRING_TYPE_WIDE :: false;

when CEF_STRING_TYPE_UTF8 {
	cef_char :: c.char;
	cef_string :: cef_string_utf8;
	cef_string_userfree :: cef_string_userfree_utf8;
	
	string_set            :: string_utf8_set
	string_copy           :: string_utf8_copy
	string_clear          :: string_utf8_clear
	string_userfree_alloc :: string_userfree_utf8_alloc
	string_userfree_free  :: string_userfree_utf8_free

	string_from_ascii     :: string_utf8_copy
	string_to_utf8        :: string_utf8_copy
	string_from_utf8      :: string_utf8_copy
	string_to_utf16       :: string_utf8_to_utf16
	string_from_utf16     :: string_utf16_to_utf8
	string_to_wide        :: string_utf8_to_wide
	string_from_wide      :: string_wide_to_utf8

}
when CEF_STRING_TYPE_UTF16 {
	cef_char :: u16;
	cef_string :: cef_string_utf16;
	cef_string_userfree :: cef_string_userfree_utf16;

	string_set            :: string_utf16_set
	string_copy           :: string_utf16_copy
	string_clear          :: string_utf16_clear
	string_userfree_alloc :: string_userfree_utf16_alloc
	string_userfree_free  :: string_userfree_utf16_free

	string_from_ascii     :: string_ascii_to_utf16
	string_to_utf8        :: string_utf16_to_utf8
	string_from_utf8      :: string_utf8_to_utf16
	string_to_utf16       :: string_utf16_copy
	string_from_utf16     :: string_utf16_copy
	string_to_wide        :: string_utf16_to_wide
	string_from_wide      :: string_wide_to_utf16

}
when CEF_STRING_TYPE_WIDE {
	cef_char :: u32; //TODO true??? idk
	cef_string :: cef_string_wide;
	cef_string_userfree :: cef_string_userfree_wide;

	string_set            :: string_wide_set
	string_copy           :: string_wide_copy
	string_clear          :: string_wide_clear
	string_userfree_alloc :: string_userfree_wide_alloc
	string_userfree_free  :: string_userfree_wide_free

	string_from_ascii     :: string_ascii_to_wide
	string_to_utf8        :: string_wide_to_utf8
	string_from_utf8      :: string_utf8_to_wide
	string_to_utf16       :: string_wide_to_utf16
	string_from_utf16     :: string_utf16_to_wide
	string_to_wide        :: string_wide_copy
	string_from_wide      :: string_wide_copy
} 
