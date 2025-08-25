package odin_cef

import "core:c"

/// Callback structure for asynchronous continuation of file dialog requests.
/// NOTE: This struct is allocated DLL-side.
///
File_dialog_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Continue the file selection. |file_paths| should be a single value or a list of values depending on the dialog mode. An NULL |file_paths| value is
	/// treated the same as calling cancel().
	cont: proc "system" (self: ^File_dialog_callback, file_paths: string_list),

	/// Cancel the file selection.
	cancel: proc "system" (self: ^File_dialog_callback),
}

/// Implement this structure to handle dialog events. The functions of this structure will be called on the browser process UI thread.
/// NOTE: This struct is allocated client-side.
Dialog_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called to run a file chooser dialog. |mode| represents the type of dialog to display. |title| to the title to be used for the dialog and may be NULL
	/// to show the default title ("Open" or "Save" depending on the mode).
	/// |default_file_path| is the path with optional directory and/or file name
	/// component that should be initially selected in the dialog.
	/// |accept_filters| are used to restrict the selectable file types and may be
	/// any combination of valid lower-cased MIME types (e.g. "text/*" or
	/// "image/*") and individual file extensions (e.g. ".txt" or ".png").
	/// |accept_extensions| provides the semicolon-delimited expansion of MIME
	/// types to file extensions (if known, or NULL string otherwise).
	/// |accept_descriptions| provides the descriptions for MIME types (if known,
	/// or NULL string otherwise). For example, the "image/*" mime type might have
	/// extensions ".png;.jpg;.bmp;..." and description "Image Files".
	/// |accept_filters|, |accept_extensions| and |accept_descriptions| will all
	/// be the same size. To display a custom dialog return true (1) and execute
	/// |callback| either inline or at a later time. To display the default dialog
	/// return false (0). If this function returns false (0) it may be called an
	/// additional time for the same dialog (both before and after MIME type
	/// expansion).
	on_file_dialog: proc "system" (self: ^Dialog_handler, browser: ^Browser, mode: File_dialog_mode, title: ^cef_string, default_file_path: ^cef_string,
		 accept_filters: string_list, accept_extensions: string_list, accept_descriptions: string_list, callback: ^File_dialog_callback) -> b32,
} 