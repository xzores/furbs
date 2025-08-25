package odin_cef

import "core:c"

/// Callback structure for asynchronous continuation of print dialog requests.
/// NOTE: This struct is allocated DLL-side.
///
print_dialog_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Continue printing with the specified |settings|.
	cont: proc "system" (self: ^print_dialog_callback, settings: ^Print_settings),

	/// Cancel the printing.
	cancel: proc "system" (self: ^print_dialog_callback),
}

/// Callback structure for asynchronous continuation of print job requests.
/// NOTE: This struct is allocated DLL-side.
print_job_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Indicate completion of the print job.
	cont: proc "system" (self: ^print_job_callback),
}

/// Implement this structure to handle printing on Linux. Each browser will have
/// only one print job in progress at a time. The functions of this structure
/// will be called on the browser process UI thread.
/// NOTE: This struct is allocated client-side.
Print_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when printing has started for the specified |browser|. This
	/// function will be called before the other on_print*() functions and
	/// irrespective of how printing was initiated (e.g.
	/// Browser_host::print(), JavaScript window.print() or PDF extension
	/// print button).
	on_print_start: proc "system" (self: ^Print_handler, browser: ^Browser),

	/// Synchronize |settings| with client state. If |get_defaults| is true (1)
	/// then populate |settings| with the default print settings. Do not keep a
	/// reference to |settings| outside of this callback.
	on_print_settings: proc "system" (self: ^Print_handler, browser: ^Browser, settings: ^Print_settings, get_defaults: b32),

	/// Show the print dialog. Execute |callback| once the dialog is dismissed.
	/// Return true (1) if the dialog will be displayed or false (0) to cancel the
	/// printing immediately.
	on_print_dialog: proc "system" (self: ^Print_handler, browser: ^Browser, has_selection: b32, callback: ^print_dialog_callback) -> b32,

	/// Send the print job to the printer. Execute |callback| once the job is
	/// completed. Return true (1) if the job will proceed or false (0) to cancel
	/// the job immediately.
	on_print_job: proc "system" (self: ^Print_handler, browser: ^Browser, document_name: ^cef_string, pdf_file_path: ^cef_string, callback: ^print_job_callback) -> b32,

	/// Reset client state related to printing.
	on_print_reset: proc "system" (self: ^Print_handler, browser: ^Browser),

	/// Return the PDF paper size in device units. Used in combination with
	/// Browser_host::print_to_pdf().
	get_pdf_paper_size: proc "system" (self: ^Print_handler, browser: ^Browser, device_units_per_inch: c.int) -> cef_size,
}
