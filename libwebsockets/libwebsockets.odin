package libwebsocket;

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:strings"

when ODIN_OS == .Windows { 
	@(extra_linker_flags="/NODEFAULTLIB:MSVCRT /IGNORE:4217", require)
	foreign import libwebsockets {
		"libs/windows/libcrypto.lib",
		"libs/windows/libssl.lib",
		"libs/windows/libuv.lib",
		"libs/windows/pthreadVC3.lib",
		"libs/windows/websockets.lib",
		"libs/windows/zlib.lib",

        "system:ws2_32.lib",
        "system:user32.lib",
        "system:advapi32.lib",
        "system:iphlpapi.lib",
        "system:psapi.lib",
        "system:shell32.lib",
        "system:crypt32.lib",
        "system:bcrypt.lib",
        "system:dbghelp.lib",
        "system:userenv.lib",
        "system:ole32.lib",
	}
}
when ODIN_OS == .Linux {
	foreign import libwebsockets "a"
} 
when ODIN_OS == .Darwin {
	foreign import libwebsockets "a"
}


//////////// Defines ////////////

CONTEXT_PORT_NO_LISTEN :: -1
CONTEXT_PORT_NO_LISTEN_SERVER :: -2

LWS_PRE :: 16
#assert(size_of(rawptr) == 8) //otherwise LWS_PRE does not match

LWS_PROTOCOL_LIST_TERM :: Protocols {}
LWS_PLUGIN_API_MAGIC :: 191


//////////// Structs ////////////

/* Opaque types we interact with */
Context :: distinct rawptr;
Vhost :: distinct rawptr;
Client :: distinct rawptr;
Lws :: distinct rawptr;
Socket :: Lws; //same as Lws
Buflist :: distinct rawptr;
Ring :: distinct rawptr; //ring buffer, opaque struct

/*
//Minimal struct declarations (only fields you actually need).
//Keep these in sync with upstream if you enable more features later.
 */
/* Protocol definition (per-connection callback + per-session data size) */
Protocols :: struct {
    name : cstring,
	callback : proc "c" (Lws, Callback_reasons, rawptr, rawptr, c.size_t) -> c.int, //int (*callback)(struct lws *wsi, enum Callback_reasons reason, void *user, void *in, size_t len);
    per_session_data_size : c.size_t,
    rx_buffer_size : c.size_t,      /* 0 = default */
    id : c.uint,            /* optional */
    user : rawptr,                 /* optional */
    tx_packet_size : c.size_t,      /* 0 = default */
};

/* Context creation (server: set port; client-only: CONTEXT_PORT_NO_LISTEN) */
// helper typedefs (optional)
lws_usec_t      :: c.uint64_t     // microseconds
lws_sockfd_type :: c.int          // fd (assumed int)

// opaque handles assumed elsewhere:
// Context :: distinct rawptr
// Vhost   :: distinct rawptr
// Lws         :: distinct rawptr
// Protocols :: struct {...}

Context_creation_info :: struct {
    ////////////////////////// network basics //////////////////////////
    iface                           : cstring,                    // bind iface name, or NULL
    protocols                       : [^]Protocols,          // protocols array (NULL-terminated)
	
    //////////////////////// HTTP/1.x / HTTP/2 /////////////////////////
    token_limits                    : rawptr,                     // const lws_token_limits*
    http_proxy_address              : cstring,                   // "user:pass@host:port" or NULL
    headers                         : rawptr,                     // const lws_protocol_vhost_options*
    reject_service_keywords         : rawptr,                     // const lws_protocol_vhost_options*
    pvo                             : rawptr,                     // const lws_protocol_vhost_options*
    log_filepath                    : cstring,
    mounts                          : rawptr,                     // const lws_http_mount*
    server_string                   : cstring,

    error_document_404              : cstring,
    port                            : c.int,                      // listen port, or special values
    http_proxy_port                 : c.uint,
    max_http_header_data2           : c.uint,
    max_http_header_pool2           : c.uint,

    keepalive_timeout               : c.int,                      // seconds
    http2_settings                  : [7]c.uint32_t,             // http/2 overrides (0 = defaults)

    max_http_header_data            : c.ushort,
    max_http_header_pool            : c.ushort,

    ////////////////////////////// TLS /////////////////////////////////
    ssl_private_key_password        : cstring,
    ssl_cert_filepath               : cstring,
    ssl_private_key_filepath        : cstring,
    ssl_ca_filepath                 : cstring,
    ssl_cipher_list                 : cstring,                    // TLS1.2 and below
    ecdh_curve                      : cstring,                    // default "prime256v1"
    tls1_3_plus_cipher_list         : cstring,                    // TLS1.3+

    server_ssl_cert_mem             : rawptr,                     // const void*
    server_ssl_private_key_mem      : rawptr,                     // const void*
    server_ssl_ca_mem               : rawptr,                     // const void*

    ssl_options_set                 : c.long,
    ssl_options_clear               : c.long,
    simultaneous_ssl_restriction    : c.int,
    simultaneous_ssl_handshake_restriction : c.int,
    ssl_info_event_mask             : c.int,

    server_ssl_cert_mem_len         : c.uint,
    server_ssl_private_key_mem_len  : c.uint,
    server_ssl_ca_mem_len           : c.uint,

    alpn                            : cstring,                    // comma-separated list

    ////////////////////////// TLS (client) ////////////////////////////
    client_ssl_private_key_password : cstring,
    client_ssl_cert_filepath        : cstring,
    client_ssl_cert_mem             : rawptr,                     // const void*
    client_ssl_cert_mem_len         : c.uint,
    client_ssl_private_key_filepath : cstring,
    client_ssl_key_mem              : rawptr,                     // const void*
    client_ssl_ca_filepath          : cstring,
    client_ssl_ca_mem               : rawptr,                     // const void*

    client_ssl_cipher_list          : cstring,                    // TLS1.2 and below
    client_tls_1_3_plus_cipher_list : cstring,                    // TLS1.3+

    ssl_client_options_set          : c.long,
    ssl_client_options_clear        : c.long,

    client_ssl_ca_mem_len           : c.uint,
    client_ssl_key_mem_len          : c.uint,

    provided_client_ssl_ctx         : rawptr,                     // SSL_CTX* (OpenSSL build)

    /////////////////////// timeouts & keepalive ///////////////////////
    ka_time                         : c.int,
    ka_probes                       : c.int,
    ka_interval                     : c.int,
    timeout_secs                    : c.uint,
    connect_timeout_secs            : c.uint,
    bind_iface                      : c.int,                      // SO_BINDTODEVICE if non-zero
    timeout_secs_ah_idle            : c.uint,

    ///////////////////////// TLS sessions /////////////////////////////
    tls_session_timeout             : c.uint32_t,
    tls_session_cache_max           : c.uint32_t,

    ////////////////////// ids, options, userdata //////////////////////
    gid                             : c.int,                      // gid_t (assumed int)
    uid                             : c.int,                      // uid_t (assumed int)
    options                         : c.uint64_t,                 // LWS_SERVER_OPTION_* bitfield
    user                            : rawptr,                     // context / vhost user

    count_threads                   : c.uint,                     // 0 = 1
    fd_limit_per_thread             : c.uint,                     // 0 = auto

    vhost_name                      : cstring,                    // vhost or context name

    ////////////////////// extra lifecycle helpers /////////////////////
    external_baggage_free_on_destroy: rawptr,                     // free()d on context destroy

    pt_serv_buf_size                : c.uint,                     // 0 = default (4096)

    ///////////////////////// file ops (enabled) ///////////////////////
    fops                            : rawptr,                     // const lws_plat_file_ops*

    /////////////////// foreign event loop integration /////////////////
    foreign_loops                   : rawptr,                     // void** (array), or NULL
    signal_cb                       : proc "c" (event_lib_handle: rawptr, signum: c.int),
    pcontext                        : rawptr,                     // struct lws_context**

    finalize                        : proc "c" (vh: Vhost, arg: rawptr),
    finalize_arg                    : rawptr,

    listen_accept_role              : cstring,                    // force role name, or NULL
    listen_accept_protocol          : cstring,                    // force protocol name, or NULL

    pprotocols                      : ^^Protocols,            // const Protocols**

    username                        : cstring,                    // post-init permissions
    groupname                       : cstring,                    // post-init permissions
    unix_socket_perms               : cstring,                    // "user:group" for unix sock

    system_ops                      : rawptr,                     // const lws_system_ops_t*
    retry_and_idle_policy           : rawptr,                     // const lws_retry_bo_t*

    ////////////////////// system state notifiers //////////////////////
    register_notifier_list          : rawptr,                     // lws_state_notify_link_t//const
    ///////////////////////// secure streams ///////////////////////////
    pss_policies_json               : cstring,                    // JSON or filepath
    pss_plugins                     : rawptr,                     // const lws_ss_plugin**

    ss_proxy_bind                   : cstring,
    ss_proxy_address                : cstring,
    ss_proxy_port                   : c.uint16_t,

    txp_ops_ssproxy                 : rawptr,                     // const lws_transport_proxy_ops*
    txp_ssproxy_info                : rawptr,                     // const void*
    txp_ops_sspc                    : rawptr,                     // const lws_transport_client_ops*

    ////////////////////// resource limits & misc ///////////////////////
    rlimit_nofile                   : c.int,

    ///////////////////////// sys smd (enabled) /////////////////////////
    early_smd_cb                    : rawptr,                     // lws_smd_notification_cb_t
    early_smd_opaque                : rawptr,
    early_smd_class_filter          : c.uint32_t,                 // lws_smd_class_t
    smd_ttl_us                      : lws_usec_t,
    smd_queue_depth                 : c.uint16_t,

    ///////////////////////// TCP fast open /////////////////////////////
    fo_listen_queue                 : c.int,                      // 0 = disabled

    /////////////////// custom event library adapter ///////////////////
    event_lib_custom                : rawptr,                     // const lws_plugin_evlib*

    ////////////////////////// logging context //////////////////////////
    log_cx                          : rawptr,                     // lws_log_cx_t*

    /////////////////////// cookie jar (client) ////////////////////////
    http_nsc_filepath               : cstring,
    http_nsc_heap_max_footprint     : c.size_t,
    http_nsc_heap_max_items         : c.size_t,
    http_nsc_heap_max_payload       : c.size_t,

    ///////////////////////// windows client check //////////////////////
    win32_connect_check_interval_usec : c.uint,                   // harmless elsewhere

    ////////////////////////// default loglevel /////////////////////////
    default_loglevel                : c.int,

    ////////////////// listen socket fd override ////////////////////////
    vh_listen_sockfd                : lws_sockfd_type,

    /////////////////////// wake-on-lan interface ///////////////////////
    wol_if                          : cstring,

    ////////////////////////////// ABI pad /////////////////////////////
    _unused                         : [2]rawptr,
}

/* Client connect params (no TLS) */
Client_connect_info :: struct {
    ctx : Context,
    address : cstring,						/* host or IP */
    port : c.int,							
    path : cstring,							/* "/ws" */
    host : cstring,							/* usually same as address */
    origin : cstring,						/* NULL */
    protocol : cstring,						/* must match one of protocols[].name */
    ietf_version_or_minus_one : c.int,  	/* -1 = latest */
    userdata : rawptr,						/* your per-connection user pointer */
    /* leave proxy / ssl fields NULL/0 for plain WS */
};

Humanize_unit :: struct {
	name : cstring,
	factor : c.uint64_t,
};

//struct lws_protocol_vhost_options - linked list of per-vhost protocol
//This provides a general way to attach a linked-list of name=value pairs,
//which can also have an optional child link-list using the options member.
Protocol_vhost_options :: struct{
	next : ^Protocol_vhost_options, //linked list
	options : ^Protocol_vhost_options, //child linked-list of more options for this node
	name : cstring, //name of name=value pair
	value : cstring, //value of name=value pair
};


Reload_func :: #type proc "c" () -> c.int;

@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {
	
	/* Core API you’ll call (declared in the subheaders, repeated here for clarity) */
	create_context :: proc (info : ^Context_creation_info) -> Context ---
	context_destroy :: proc (ctx : Context) ---

	client_connect_via_info :: proc (ccinfo : ^Client_connect_info) -> Lws ---

	write :: proc (wsi : Lws, buf : [^]u8, length : c.size_t, wp : Write_protocol) -> c.int ---
	callback_on_writable :: proc (wsi : Lws) ---
	
	/* Handy accessors (optional, but commonly used) */
	context_user :: proc (ctx : Context) -> rawptr ---
	wsi_user :: proc (wsi : Lws) -> rawptr ---
	
	context_deprecate :: proc (ctx : Context, cb : Reload_func) ---
	context_is_deprecated :: proc (ctx : Context) -> c.int ---
	set_proxy :: proc (vhost : Vhost, proxy : cstring) -> c.int ---
	set_socks :: proc (vhost : Vhost, proxy : cstring) -> c.int ---
	create_vhost :: proc (ctx : Context, info : ^Context_creation_info) -> Vhost ---
	vhost_destroy :: proc (vhost : Vhost) ---

	//lwsws_get_config_globals :: proc (info : ^Context_creation_info, d : cstring, char **config_strings, int *len) -> c.int ---

	//@(link_name="lwsws_get_config_vhosts")
	//ws_get_config_vhosts :: proc (ctx : Context, info : ^Context_creation_info, d : cstring, char **config_strings, int *len) -> c.int ---
	get_vhost :: proc (wsi : Lws) -> Vhost ---
	get_vhost_name :: proc (vhost : Vhost) -> cstring ---
	get_vhost_by_name :: proc (ctx : Context, name : cstring) -> Vhost ---
	get_vhost_port :: proc (vhost : Vhost) -> c.int ---
	get_vhost_user :: proc (vhost : Vhost) -> rawptr ---
	get_vhost_iface :: proc (vhost : Vhost) -> cstring ---
	vhost_user :: proc (vhost : Vhost) ---
	vh_tag :: proc (vhost : Vhost) -> cstring --- 

	//_lws_context_info_defaults :: proc (info : ^Context_creation_info, const char *sspol);

	default_loop_exit :: proc (ctx : Context) ---
	context_default_loop_run_destroy :: proc (ctx : Context) ---
	cmdline_passfail :: proc (argc : c.int, argv : [^]cstring, actual : c.int) -> c.int ---
	systemd_inherited_fd :: proc (index : c.uint, info : ^Context_creation_info) -> c.int ---
	context_is_being_destroyed :: proc (ctx : Context) -> c.int ---
}


/*
//NOTE: These public enums are part of the abi.  If you want to add one,
//add it at where specified so existing users are unaffected.
 */
Write_protocol :: enum u32 {
	LWS_WRITE_TEXT						= 0,
	/**< Send a ws TEXT message,the pointer must have LWS_PRE valid
	//memory behind it.
		//The receiver expects only valid utf-8 in the payload */
	LWS_WRITE_BINARY					= 1,

	/**< Send a ws BINARY message, the pointer must have LWS_PRE valid
	//memory behind it.
		//Any sequence of bytes is valid */
	LWS_WRITE_CONTINUATION					= 2,
	
	/**< Continue a previous ws message, the pointer must have LWS_PRE valid
	//memory behind it */
	LWS_WRITE_HTTP						= 3,
	
	/**< Send HTTP content */

	/* LWS_WRITE_CLOSE is handled by lws_close_reason() */
	LWS_WRITE_PING						= 5,
	LWS_WRITE_PONG						= 6,

	/* Same as write_http but we know this write ends the transaction */
	LWS_WRITE_HTTP_FINAL					= 7,

	
	
	/* HTTP2 */

	LWS_WRITE_HTTP_HEADERS					= 8,
	/**< Send http headers (http2 encodes this payload and LWS_WRITE_HTTP
	//payload differently, http 1.x links also handle this correctly. so
	//to be compatible with both in the future,header response part should
	//be sent using this regardless of http version expected)
	 */
	LWS_WRITE_HTTP_HEADERS_CONTINUATION			= 9,
	/**< Continuation of http/2 headers
	 */

	
	
	 /****** add new things just above ---^ ******/

	/* flags */

	LWS_WRITE_BUFLIST = 0x20,
	/**< Don't actually write it... stick it on the output buflist and
	//  write it as soon as possible.  Useful if you learn you have to
	//  write something, have the data to write to hand but the timing is
	//  unrelated as to whether the connection is writable or not, and were
	//  otherwise going to have to allocate a temp buffer and write it
	//  later anyway */

	LWS_WRITE_NO_FIN = 0x40,
	/**< This part of the message is not the end of the message */

	LWS_WRITE_H2_STREAM_END = 0x80,
	/**< Flag indicates this packet should go out with STREAM_END if h2
	//STREAM_END is allowed on DATA or HEADERS.
	 */

	LWS_WRITE_CLIENT_IGNORE_XOR_MASK = 0x80,
	/**< client packet payload goes out on wire unmunged
	//only useful for security tests since normal servers cannot
	//decode the content if used */
};



/*
//NOTE: These public enums are part of the abi.  If you want to add one,
//add it at where specified so existing users are unaffected.
 */
/** enum Callback_reasons - reason you're getting a protocol callback */
Callback_reasons :: enum u32 {

	/* ---------------------------------------------------------------------
	//----- Callbacks related to wsi and protocol binding lifecycle -----
	 */

	LWS_CALLBACK_PROTOCOL_INIT				= 27,
	/**< One-time call per protocol, per-vhost using it, so it can
	//do initial setup / allocations etc */

	LWS_CALLBACK_PROTOCOL_DESTROY				= 28,
	/**< One-time call per protocol, per-vhost using it, indicating
	//this protocol won't get used at all after this callback, the
	//vhost is getting destroyed.  Take the opportunity to
	//deallocate everything that was allocated by the protocol. */

	LWS_CALLBACK_WSI_CREATE					= 29,
	/**< outermost (earliest) wsi create notification to protocols[0] */

	LWS_CALLBACK_WSI_DESTROY				= 30,
	/**< outermost (latest) wsi destroy notification to protocols[0] */

	LWS_CALLBACK_WSI_TX_CREDIT_GET				= 103,
	/**< manually-managed connection received TX credit (len is int32) */


	/* ---------------------------------------------------------------------
	//----- Callbacks related to Server TLS -----
	 */

	LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS	= 21,
	/**< if configured for
	//including OpenSSL support, this callback allows your user code
	//to perform extra SSL_CTX_load_verify_locations() or similar
	//calls to direct OpenSSL where to find certificates the client
	//can use to confirm the remote server identity.  user is the
	//OpenSSL SSL_CTX* */

	LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS	= 22,
	/**< if configured for
	//including OpenSSL support, this callback allows your user code
	//to load extra certificates into the server which allow it to
	//verify the validity of certificates returned by clients.  user
	//is the server's OpenSSL SSL_CTX* and in is the lws_vhost */

	LWS_CALLBACK_OPENSSL_PERFORM_CLIENT_CERT_VERIFICATION	= 23,
	/**< if the libwebsockets vhost was created with the option
	//LWS_SERVER_OPTION_REQUIRE_VALID_OPENSSL_CLIENT_CERT, then this
	//callback is generated during OpenSSL verification of the cert
	//sent from the client.  It is sent to protocol[0] callback as
	//no protocol has been negotiated on the connection yet.
	//Notice that the libwebsockets context and wsi are both NULL
	//during this callback.  See
	// http://www.openssl.org/docs/ssl/SSL_CTX_set_verify.html
	//to understand more detail about the OpenSSL callback that
	//generates this libwebsockets callback and the meanings of the
	//arguments passed.  In this callback, user is the x509_ctx,
	//in is the ssl pointer and len is preverify_ok
	//Notice that this callback maintains libwebsocket return
	//conventions, return 0 to mean the cert is OK or 1 to fail it.
	//This also means that if you don't handle this callback then
	//the default callback action of returning 0 allows the client
	//certificates. */

	LWS_CALLBACK_SSL_INFO					= 67,
	/**< SSL connections only.  An event you registered an
	//interest in at the vhost has occurred on a connection
	//using the vhost.  in is a pointer to a
	//struct lws_ssl_info containing information about the
	//event*/

	/* ---------------------------------------------------------------------
	//----- Callbacks related to Client TLS -----
	 */

	LWS_CALLBACK_OPENSSL_PERFORM_SERVER_CERT_VERIFICATION = 58,
	/**< Similar to LWS_CALLBACK_OPENSSL_PERFORM_CLIENT_CERT_VERIFICATION
	//this callback is called during OpenSSL verification of the cert
	//sent from the server to the client. It is sent to protocol[0]
	//callback as no protocol has been negotiated on the connection yet.
	//Notice that the wsi is set because lws_client_connect_via_info was
	//successful.
		//See http://www.openssl.org/docs/ssl/SSL_CTX_set_verify.html
	//to understand more detail about the OpenSSL callback that
	//generates this libwebsockets callback and the meanings of the
	//arguments passed. In this callback, user is the x509_ctx,
	//in is the ssl pointer and len is preverify_ok.
		//THIS IS NOT RECOMMENDED BUT if a cert validation error shall be
	//overruled and cert shall be accepted as ok,
	//X509_STORE_CTX_set_error((X509_STORE_CTX*)user, X509_V_OK); must be
	//called and return value must be 0 to mean the cert is OK;
	//returning 1 will fail the cert in any case.
		//This also means that if you don't handle this callback then
	//the default callback action of returning 0 will not accept the
	//certificate in case of a validation error decided by the SSL lib.
		//This is expected and secure behaviour when validating certificates.
		//Note: LCCSCF_ALLOW_SELFSIGNED and
	//LCCSCF_SKIP_SERVER_CERT_HOSTNAME_CHECK still work without this
	//callback being implemented.
	 */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to HTTP Server  -----
	 */

	LWS_CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED		= 19,
	/**< A new client has been accepted by the ws server.  This
	//callback allows setting any relevant property to it. Because this
	//happens immediately after the instantiation of a new client,
	//there's no websocket protocol selected yet so this callback is
	//issued only to protocol 0. Only wsi is defined, pointing to the
	//new client, and the return value is ignored. */

	LWS_CALLBACK_HTTP					= 12,
	/**< an http request has come from a client that is not
	//asking to upgrade the connection to a websocket
	//one.  This is a chance to serve http content,
	//for example, to send a script to the client
	//which will then open the websockets connection.
	//in points to the URI path requested and
	//lws_serve_http_file() makes it very
	//simple to send back a file to the client.
	//Normally after sending the file you are done
	//with the http connection, since the rest of the
	//activity will come by websockets from the script
	//that was delivered by http, so you will want to
	//return 1; to close and free up the connection. */

	LWS_CALLBACK_HTTP_BODY					= 13,
	/**< the next len bytes data from the http
	//request body HTTP connection is now available in in. */

	LWS_CALLBACK_HTTP_BODY_COMPLETION			= 14,
	/**< the expected amount of http request body has been delivered */

	LWS_CALLBACK_HTTP_FILE_COMPLETION			= 15,
	/**< a file requested to be sent down http link has completed. */

	LWS_CALLBACK_HTTP_WRITEABLE				= 16,
	/**< you can write more down the http protocol link now. */

	LWS_CALLBACK_CLOSED_HTTP				=  5,
	/**< when a HTTP (non-websocket) session ends */

	LWS_CALLBACK_FILTER_HTTP_CONNECTION			= 18,
	/**< called when the request has
	//been received and parsed from the client, but the response is
	//not sent yet.  Return non-zero to disallow the connection.
	//user is a pointer to the connection user space allocation,
	//in is the URI, eg, "/"
	//In your handler you can use the public APIs
	//lws_hdr_total_length() / lws_hdr_copy() to access all of the
	//headers using the header enums lws_token_indexes from
	//libwebsockets.h to check for and read the supported header
	//presence and content before deciding to allow the http
	//connection to proceed or to kill the connection. */

	LWS_CALLBACK_ADD_HEADERS				= 53,
	/**< This gives your user code a chance to add headers to a server
	//transaction bound to your protocol.  `in` points to a
	//`struct lws_process_html_args` describing a buffer and length
	//you can add headers into using the normal lws apis.
		//(see LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER to add headers to
	//a client transaction)
		//Only `args->p` and `args->len` are valid, and `args->p` should
	//be moved on by the amount of bytes written, if any.  Eg
		//	case LWS_CALLBACK_ADD_HEADERS:
		//         struct lws_process_html_args *args =
	//         		(struct lws_process_html_args *)in;
		 *	    if (lws_add_http_header_by_name(wsi,
	 *			(unsigned char *)"set-cookie:",
	 *			(unsigned char *)cookie, cookie_len,
	 *			(unsigned char **)&args->p,
	 *			(unsigned char *)args->p + args->max_len))
	 *		return 1;
		//         break;
	 */

	LWS_CALLBACK_VERIFY_BASIC_AUTHORIZATION = 102,
	/**< This gives the user code a chance to accept or reject credentials
	//provided HTTP to basic authorization. It will only be called if the
	//http mount's authentication_mode is set to LWSAUTHM_BASIC_AUTH_CALLBACK
	//`in` points to a credential string of the form `username:password` If
	//the callback returns zero (the default if unhandled), then the
	//transaction ends with HTTP_STATUS_UNAUTHORIZED, otherwise the request
	//will be processed */

	LWS_CALLBACK_CHECK_ACCESS_RIGHTS			= 51,
	/**< This gives the user code a chance to forbid an http access.
	//`in` points to a `struct lws_process_html_args`, which
	//describes the URL, and a bit mask describing the type of
	//authentication required.  If the callback returns nonzero,
	//the transaction ends with HTTP_STATUS_UNAUTHORIZED. */

	LWS_CALLBACK_PROCESS_HTML				= 52,
	/**< This gives your user code a chance to mangle outgoing
	//HTML.  `in` points to a `struct lws_process_html_args`
	//which describes the buffer containing outgoing HTML.
	//The buffer may grow up to `.max_len` (currently +128
	//bytes per buffer).
	 */

	LWS_CALLBACK_HTTP_BIND_PROTOCOL				= 49,
	/**< By default, all HTTP handling is done in protocols[0].
	//However you can bind different protocols (by name) to
	//different parts of the URL space using callback mounts.  This
	//callback occurs in the new protocol when a wsi is bound
	//to that protocol.  Any protocol allocation related to the
	//http transaction processing should be created then.
	//These specific callbacks are necessary because with HTTP/1.1,
	//a single connection may perform at series of different
	//transactions at different URLs, thus the lifetime of the
	//protocol bind is just for one transaction, not connection. */

	LWS_CALLBACK_HTTP_DROP_PROTOCOL				= 50,
	/**< This is called when a transaction is unbound from a protocol.
	//It indicates the connection completed its transaction and may
	//do something different now.  Any protocol allocation related
	//to the http transaction processing should be destroyed. */

	LWS_CALLBACK_HTTP_CONFIRM_UPGRADE			= 86,
	/**< This is your chance to reject an HTTP upgrade action.  The
	//name of the protocol being upgraded to is in 'in', and the ah
	//is still bound to the wsi, so you can look at the headers.
		//The default of returning 0 (ie, also if not handled) means the
	//upgrade may proceed.  Return <0 to just hang up the connection,
	//or >0 if you have rejected the connection by returning http headers
	//and response code yourself.
		//There is no need for you to call transaction_completed() as the
	//caller will take care of it when it sees you returned >0.
	 */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to HTTP Client  -----
	 */

	LWS_CALLBACK_ESTABLISHED_CLIENT_HTTP			= 44,
	/**< The HTTP client connection has succeeded, and is now
	//connected to the server */

	LWS_CALLBACK_CLOSED_CLIENT_HTTP				= 45,
	/**< The HTTP client connection is closing */

	LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ			= 48,
	/**< This is generated by lws_http_client_read() used to drain
	//incoming data.  In the case the incoming data was chunked, it will
	//be split into multiple smaller callbacks for each chunk block,
	//removing the chunk headers. If not chunked, it will appear all in
	//one callback. */

	LWS_CALLBACK_RECEIVE_CLIENT_HTTP			= 46,
	/**< This indicates data was received on the HTTP client connection.  It
	//does NOT actually drain or provide the data, so if you are doing
	//http client, you MUST handle this and call lws_http_client_read().
	//Failure to deal with it as in the minimal examples may cause spinning
	//around the event loop as it's continuously signalled the same data
	//is available for read.  The related minimal examples show how to
	//handle it.
		//It's possible to defer calling lws_http_client_read() if you use
	//rx flow control to stop further rx handling on the connection until
	//you did deal with it.  But normally you would call it in the handler.
		//lws_http_client_read() strips any chunked framing and calls back
	//with only payload data to LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ.  The
	//chunking is the reason this is not just all done in one callback for
	//http.
	 */
	LWS_CALLBACK_COMPLETED_CLIENT_HTTP			= 47,
	/**< The client transaction completed... at the moment this
	//is the same as closing since transaction pipelining on
	//client side is not yet supported.  */

	LWS_CALLBACK_CLIENT_HTTP_WRITEABLE			= 57,
	/**< when doing an HTTP type client connection, you can call
	//lws_client_http_body_pending(wsi, 1) from
	//LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER to get these callbacks
	//sending the HTTP headers.
		//From this callback, when you have sent everything, you should let
	//lws know by calling lws_client_http_body_pending(wsi, 0)
	 */

	LWS_CALLBACK_CLIENT_HTTP_REDIRECT			= 104,
	/**< we're handling a 3xx redirect... return nonzero to hang up */

	LWS_CALLBACK_CLIENT_HTTP_BIND_PROTOCOL			= 85,
	LWS_CALLBACK_CLIENT_HTTP_DROP_PROTOCOL			= 76,

	/* ---------------------------------------------------------------------
	//----- Callbacks related to Websocket Server -----
	 */

	LWS_CALLBACK_ESTABLISHED				=  0,
	/**< (VH) after the server completes a handshake with an incoming
	//client.  If you built the library with ssl support, in is a
	//pointer to the ssl struct associated with the connection or NULL.
		//b0 of len is set if the connection was made using ws-over-h2
	 */

	LWS_CALLBACK_CLOSED					=  4,
	/**< when the websocket session ends */

	LWS_CALLBACK_SERVER_WRITEABLE				= 11,
	/**< See LWS_CALLBACK_CLIENT_WRITEABLE */

	LWS_CALLBACK_RECEIVE					=  6,
	/**< data has appeared for this server endpoint from a
	//remote client, it can be found at *in and is
	//len bytes long */

	LWS_CALLBACK_RECEIVE_PONG				=  7,
	/**< servers receive PONG packets with this callback reason */

	LWS_CALLBACK_WS_PEER_INITIATED_CLOSE			= 38,
	/**< The peer has sent an unsolicited Close WS packet.  in and
	//len are the optional close code (first 2 bytes, network
	//order) and the optional additional information which is not
	//defined in the standard, and may be a string or non human-readable
	//data.
	//If you return 0 lws will echo the close and then close the
	//connection.  If you return nonzero lws will just close the
	//connection. */

	LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION			= 20,
	/**< called when the handshake has
	//been received and parsed from the client, but the response is
	//not sent yet.  Return non-zero to disallow the connection.
	//user is a pointer to the connection user space allocation,
	//in is the requested protocol name
	//In your handler you can use the public APIs
	//lws_hdr_total_length() / lws_hdr_copy() to access all of the
	//headers using the header enums lws_token_indexes from
	//libwebsockets.h to check for and read the supported header
	//presence and content before deciding to allow the handshake
	//to proceed or to kill the connection. */

	LWS_CALLBACK_CONFIRM_EXTENSION_OKAY			= 25,
	/**< When the server handshake code
	//sees that it does support a requested extension, before
	//accepting the extension by additing to the list sent back to
	//the client it gives this callback just to check that it's okay
	//to use that extension.  It calls back to the requested protocol
	//and with in being the extension name, len is 0 and user is
	//valid.  Note though at this time the ESTABLISHED callback hasn't
	//happened yet so if you initialize user content there, user
	//content during this callback might not be useful for anything. */

	LWS_CALLBACK_WS_SERVER_BIND_PROTOCOL			= 77,
	LWS_CALLBACK_WS_SERVER_DROP_PROTOCOL			= 78,

	/* ---------------------------------------------------------------------
	//----- Callbacks related to Websocket Client -----
	 */

	LWS_CALLBACK_CLIENT_CONNECTION_ERROR			=  1,
	/**< the request client connection has been unable to complete a
	//handshake with the remote server.  If in is non-NULL, you can
	//find an error string of length len where it points to
		//Diagnostic strings that may be returned include
		//    	"getaddrinfo (ipv6) failed"
	//    	"unknown address family"
	//    	"getaddrinfo (ipv4) failed"
	//    	"set socket opts failed"
	//    	"insert wsi failed"
	//    	"lws_ssl_client_connect1 failed"
	//    	"lws_ssl_client_connect2 failed"
	//    	"Peer hung up"
	//    	"read failed"
	//    	"HS: URI missing"
	//    	"HS: Redirect code but no Location"
	//    	"HS: URI did not parse"
	//    	"HS: Redirect failed"
	//    	"HS: Server did not return 200"
	//    	"HS: OOM"
	//    	"HS: disallowed by client filter"
	//    	"HS: disallowed at ESTABLISHED"
	//    	"HS: ACCEPT missing"
	//    	"HS: ws upgrade response not 101"
	//    	"HS: UPGRADE missing"
	//    	"HS: Upgrade to something other than websocket"
	//    	"HS: CONNECTION missing"
	//    	"HS: UPGRADE malformed"
	//    	"HS: PROTOCOL malformed"
	//    	"HS: Cannot match protocol"
	//    	"HS: EXT: list too big"
	//    	"HS: EXT: failed setting defaults"
	//    	"HS: EXT: failed parsing defaults"
	//    	"HS: EXT: failed parsing options"
	//    	"HS: EXT: Rejects server options"
	//    	"HS: EXT: unknown ext"
	//    	"HS: Accept hash wrong"
	//    	"HS: Rejected by filter cb"
	//    	"HS: OOM"
	//    	"HS: SO_SNDBUF failed"
	//    	"HS: Rejected at CLIENT_ESTABLISHED"
	 */

	LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH		=  2,
	/**< this is the last chance for the client user code to examine the
	//http headers and decide to reject the connection.  If the
	//content in the headers is interesting to the
	//client (url, etc) it needs to copy it out at
	//this point since it will be destroyed before
	//the CLIENT_ESTABLISHED call */

	LWS_CALLBACK_CLIENT_ESTABLISHED				=  3,
	/**< after your client connection completed the websocket upgrade
	//handshake with the remote server */

	LWS_CALLBACK_CLIENT_CLOSED				= 75,
	/**< when a client websocket session ends */

	LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER		= 24,
	/**< this callback happens
	//when a client handshake is being compiled.  user is NULL,
	//in is a char **, it's pointing to a char//which holds the
	//next location in the header buffer where you can add
	//headers, and len is the remaining space in the header buffer,
	//which is typically some hundreds of bytes.  So, to add a canned
	//cookie, your handler code might look similar to:
		 *	char **p = (char **)in, *end = (*p) + len;
		 *	if (lws_add_http_header_by_token(wsi, WSI_TOKEN_HTTP_COOKIE,
	 *			(unsigned char)"a=b", 3, p, end))
	 *		return -1;
		//See LWS_CALLBACK_ADD_HEADERS for adding headers to server
	//transactions.
	 */

	LWS_CALLBACK_CLIENT_RECEIVE				=  8,
	/**< data has appeared from the server for the client connection, it
	//can be found at *in and is len bytes long */

	LWS_CALLBACK_CLIENT_RECEIVE_PONG			=  9,
	/**< clients receive PONG packets with this callback reason */

	LWS_CALLBACK_CLIENT_WRITEABLE				= 10,
	/**<  If you call lws_callback_on_writable() on a connection, you will
	//get one of these callbacks coming when the connection socket
	//is able to accept another write packet without blocking.
	//If it already was able to take another packet without blocking,
	//you'll get this callback at the next call to the service loop
	//function.  Notice that CLIENTs get LWS_CALLBACK_CLIENT_WRITEABLE
	//and servers get LWS_CALLBACK_SERVER_WRITEABLE. */

	LWS_CALLBACK_CLIENT_CONFIRM_EXTENSION_SUPPORTED		= 26,
	/**< When a ws client
	//connection is being prepared to start a handshake to a server,
	//each supported extension is checked with protocols[0] callback
	//with this reason, giving the user code a chance to suppress the
	//claim to support that extension by returning non-zero.  If
	//unhandled, by default 0 will be returned and the extension
	//support included in the header to the server.  Notice this
	//callback comes to protocols[0]. */

	LWS_CALLBACK_WS_EXT_DEFAULTS				= 39,
	/**< Gives client connections an opportunity to adjust negotiated
	//extension defaults.  `user` is the extension name that was
	//negotiated (eg, "permessage-deflate").  `in` points to a
	//buffer and `len` is the buffer size.  The user callback can
	//set the buffer to a string describing options the extension
	//should parse.  Or just ignore for defaults. */


	LWS_CALLBACK_FILTER_NETWORK_CONNECTION			= 17,
	/**< called when a client connects to
	//the server at network level; the connection is accepted but then
	//passed to this callback to decide whether to hang up immediately
	//or not, based on the client IP.
		//user_data in the callback points to a
	//struct lws_filter_network_conn_args that is prepared with the
	//sockfd, and the peer's address information.
		//in contains the connection socket's descriptor.
		//Since the client connection information is not available yet,
	//wsi still pointing to the main server socket.
		//Return non-zero to terminate the connection before sending or
	//receiving anything. Because this happens immediately after the
	//network connection from the client, there's no websocket protocol
	//selected yet so this callback is issued only to protocol 0. */

	LWS_CALLBACK_WS_CLIENT_BIND_PROTOCOL			= 79,
	LWS_CALLBACK_WS_CLIENT_DROP_PROTOCOL			= 80,

	/* ---------------------------------------------------------------------
	//----- Callbacks related to external poll loop integration  -----
	 */

	LWS_CALLBACK_GET_THREAD_ID				= 31,
	/**< lws can accept callback when writable requests from other
	//threads, if you implement this callback and return an opaque
	//current thread ID integer. */

	/* external poll() management support */
	LWS_CALLBACK_ADD_POLL_FD				= 32,
	/**< lws normally deals with its poll() or other event loop
	//internally, but in the case you are integrating with another
	//server you will need to have lws sockets share a
	//polling array with the other server.  This and the other
	//POLL_FD related callbacks let you put your specialized
	//poll array interface code in the callback for protocol 0, the
	//first protocol you support, usually the HTTP protocol in the
	//serving case.
	//This callback happens when a socket needs to be
	//added to the polling loop: in points to a struct
	//lws_pollargs; the fd member of the struct is the file
	//descriptor, and events contains the active events
		//If you are using the internal lws polling / event loop
	//you can just ignore these callbacks. */

	LWS_CALLBACK_DEL_POLL_FD				= 33,
	/**< This callback happens when a socket descriptor
	//needs to be removed from an external polling array.  in is
	//again the struct lws_pollargs containing the fd member
	//to be removed.  If you are using the internal polling
	//loop, you can just ignore it. */

	LWS_CALLBACK_CHANGE_MODE_POLL_FD			= 34,
	/**< This callback happens when lws wants to modify the events for
	//a connection.
	//in is the struct lws_pollargs with the fd to change.
	//The new event mask is in events member and the old mask is in
	//the prev_events member.
	//If you are using the internal polling loop, you can just ignore
	//it. */

	LWS_CALLBACK_LOCK_POLL					= 35,
	/**< These allow the external poll changes driven
	//by lws to participate in an external thread locking
	//scheme around the changes, so the whole thing is threadsafe.
	//These are called around three activities in the library,
	 *	- inserting a new wsi in the wsi / fd table (len=1)
	 *	- deleting a wsi from the wsi / fd table (len=1)
	 *	- changing a wsi's POLLIN/OUT state (len=0)
	//Locking and unlocking external synchronization objects when
	//len == 1 allows external threads to be synchronized against
	//wsi lifecycle changes if it acquires the same lock for the
	//duration of wsi dereference from the other thread context. */

	LWS_CALLBACK_UNLOCK_POLL				= 36,
	/**< See LWS_CALLBACK_LOCK_POLL, ignore if using lws internal poll */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to CGI serving -----
	 */

	LWS_CALLBACK_CGI					= 40,
	/**< CGI: CGI IO events on stdin / out / err are sent here on
	//protocols[0].  The provided `lws_callback_http_dummy()`
	//handles this and the callback should be directed there if
	//you use CGI. */

	LWS_CALLBACK_CGI_TERMINATED				= 41,
	/**< CGI: The related CGI process ended, this is called before
	//the wsi is closed.  Used to, eg, terminate chunking.
	//The provided `lws_callback_http_dummy()`
	//handles this and the callback should be directed there if
	//you use CGI.  The child PID that terminated is in len. */

	LWS_CALLBACK_CGI_STDIN_DATA				= 42,
	/**< CGI: Data is, to be sent to the CGI process stdin, eg from
	//a POST body.  The provided `lws_callback_http_dummy()`
	//handles this and the callback should be directed there if
	//you use CGI. */

	LWS_CALLBACK_CGI_STDIN_COMPLETED			= 43,
	/**< CGI: no more stdin is coming.  The provided
	//`lws_callback_http_dummy()` handles this and the callback
	//should be directed there if you use CGI. */

	LWS_CALLBACK_CGI_PROCESS_ATTACH				= 70,
	/**< CGI: Sent when the CGI process is spawned for the wsi.  The
	//len parameter is the PID of the child process */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to Generic Sessions -----
	 */

	LWS_CALLBACK_SESSION_INFO				= 54,
	/**< This is only generated by user code using generic sessions.
	//It's used to get a `struct lws_session_info` filled in by
	//generic sessions with information about the logged-in user.
	//See the messageboard sample for an example of how to use. */

	LWS_CALLBACK_GS_EVENT					= 55,
	/**< Indicates an event happened to the Generic Sessions session.
	//`in` contains a `struct lws_gs_event_args` describing the event. */

	LWS_CALLBACK_HTTP_PMO					= 56,
	/**< per-mount options for this connection, called before
	//the normal LWS_CALLBACK_HTTP when the mount has per-mount
	//options.
	 */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to RAW PROXY -----
	 */

	LWS_CALLBACK_RAW_PROXY_CLI_RX				= 89,
	/**< RAW mode client (outgoing) RX */

	LWS_CALLBACK_RAW_PROXY_SRV_RX				= 90,
	/**< RAW mode server (listening) RX */

	LWS_CALLBACK_RAW_PROXY_CLI_CLOSE			= 91,
	/**< RAW mode client (outgoing) is closing */

	LWS_CALLBACK_RAW_PROXY_SRV_CLOSE			= 92,
	/**< RAW mode server (listening) is closing */

	LWS_CALLBACK_RAW_PROXY_CLI_WRITEABLE			= 93,
	/**< RAW mode client (outgoing) may be written */

	LWS_CALLBACK_RAW_PROXY_SRV_WRITEABLE			= 94,
	/**< RAW mode server (listening) may be written */

	LWS_CALLBACK_RAW_PROXY_CLI_ADOPT			= 95,
	/**< RAW mode client (onward) accepted socket was adopted
	//  (equivalent to 'wsi created') */

	LWS_CALLBACK_RAW_PROXY_SRV_ADOPT			= 96,
	/**< RAW mode server (listening) accepted socket was adopted
	//  (equivalent to 'wsi created') */

	LWS_CALLBACK_RAW_PROXY_CLI_BIND_PROTOCOL		= 97,
	LWS_CALLBACK_RAW_PROXY_SRV_BIND_PROTOCOL		= 98,
	LWS_CALLBACK_RAW_PROXY_CLI_DROP_PROTOCOL		= 99,
	LWS_CALLBACK_RAW_PROXY_SRV_DROP_PROTOCOL		= 100,


	/* ---------------------------------------------------------------------
	//----- Callbacks related to RAW sockets -----
	 */

	LWS_CALLBACK_RAW_RX					= 59,
	/**< RAW mode connection RX */

	LWS_CALLBACK_RAW_CLOSE					= 60,
	/**< RAW mode connection is closing */

	LWS_CALLBACK_RAW_WRITEABLE				= 61,
	/**< RAW mode connection may be written */

	LWS_CALLBACK_RAW_ADOPT					= 62,
	/**< RAW mode connection was adopted (equivalent to 'wsi created') */

	LWS_CALLBACK_RAW_CONNECTED				= 101,
	/**< outgoing client RAW mode connection was connected */

	LWS_CALLBACK_RAW_SKT_BIND_PROTOCOL			= 81,
	LWS_CALLBACK_RAW_SKT_DROP_PROTOCOL			= 82,

	/* ---------------------------------------------------------------------
	//----- Callbacks related to RAW file handles -----
	 */

	LWS_CALLBACK_RAW_ADOPT_FILE				= 63,
	/**< RAW mode file was adopted (equivalent to 'wsi created') */

	LWS_CALLBACK_RAW_RX_FILE				= 64,
	/**< This is the indication the RAW mode file has something to read.
	//  This doesn't actually do the read of the file and len is always
	//  0... your code should do the read having been informed there is
	//  something to read now. */

	LWS_CALLBACK_RAW_WRITEABLE_FILE				= 65,
	/**< RAW mode file is writeable */

	LWS_CALLBACK_RAW_CLOSE_FILE				= 66,
	/**< RAW mode wsi that adopted a file is closing */

	LWS_CALLBACK_RAW_FILE_BIND_PROTOCOL			= 83,
	LWS_CALLBACK_RAW_FILE_DROP_PROTOCOL			= 84,

	/* ---------------------------------------------------------------------
	//----- Callbacks related to generic wsi events -----
	 */

	LWS_CALLBACK_TIMER					= 73,
	/**< When the time elapsed after a call to
	//lws_set_timer_usecs(wsi, usecs) is up, the wsi will get one of
	//these callbacks.  The deadline can be continuously extended into the
	//future by later calls to lws_set_timer_usecs() before the deadline
	//expires, or cancelled by lws_set_timer_usecs(wsi, -1);
	 */

	LWS_CALLBACK_EVENT_WAIT_CANCELLED			= 71,
	/**< This is sent to every protocol of every vhost in response
	//to lws_cancel_service() or lws_cancel_service_pt().  This
	//callback is serialized in the lws event loop normally, even
	//if the lws_cancel_service[_pt]() call was from a different
	//thread. */

	LWS_CALLBACK_CHILD_CLOSING				= 69,
	/**< Sent to parent to notify them a child is closing / being
	//destroyed.  in is the child wsi.
	 */

	LWS_CALLBACK_CONNECTING					= 105,
	/**< Called before a socketfd is about to connect().  In is the
	//socketfd, cast to a (void *), if on a platform where the socketfd
	//is an int, recover portably using (lws_sockfd_type)(intptr_t)in.
		//It's also called in SOCKS5 or http_proxy cases where the socketfd is
	//going to try to connect to its proxy.
	 */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to TLS certificate management -----
	 */

	LWS_CALLBACK_VHOST_CERT_AGING				= 72,
	/**< When a vhost TLS cert has its expiry checked, this callback
	//is broadcast to every protocol of every vhost in case the
	//protocol wants to take some action with this information.
	//\p in is a pointer to a struct lws_acme_cert_aging_args,
	//and \p len is the number of days left before it expires, as
	//a (ssize_t).  In the struct lws_acme_cert_aging_args, vh
	//points to the vhost the cert aging information applies to,
	//and element_overrides[] is an optional way to update information
	//from the pvos... NULL in an index means use the information from
	//from the pvo for the cert renewal, non-NULL in the array index
	//means use that pointer instead for the index. */

	LWS_CALLBACK_VHOST_CERT_UPDATE				= 74,
	/**< When a vhost TLS cert is being updated, progress is
	//reported to the vhost in question here, including completion
	//and failure.  in points to optional JSON, and len represents the
	//connection state using enum lws_cert_update_state */

	/* ---------------------------------------------------------------------
	//----- Callbacks related to MQTT Client  -----
	 */

	LWS_CALLBACK_MQTT_NEW_CLIENT_INSTANTIATED		= 200,
	LWS_CALLBACK_MQTT_IDLE					= 201,
	LWS_CALLBACK_MQTT_CLIENT_ESTABLISHED			= 202,
	LWS_CALLBACK_MQTT_SUBSCRIBED				= 203,
	LWS_CALLBACK_MQTT_CLIENT_WRITEABLE			= 204,
	LWS_CALLBACK_MQTT_CLIENT_RX				= 205,
	LWS_CALLBACK_MQTT_UNSUBSCRIBED				= 206,
	LWS_CALLBACK_MQTT_DROP_PROTOCOL				= 207,
	LWS_CALLBACK_MQTT_CLIENT_CLOSED				= 208,
	LWS_CALLBACK_MQTT_ACK					= 209,
	/**< When a message is fully sent, if QoS0 this callback is generated
	//to locally "acknowledge" it.  For QoS1, this callback is only
	//generated when the matching PUBACK is received.  Return nonzero to
	//close the wsi.
	 */
	LWS_CALLBACK_MQTT_RESEND				= 210,
	/**< In QoS1 or QoS2, this callback is generated instead of the _ACK one
	//if we timed out waiting for a PUBACK or a PUBREC, and we must resend
	//the message.  Return nonzero to close the wsi.
	 */
	LWS_CALLBACK_MQTT_UNSUBSCRIBE_TIMEOUT			= 211,
	/**< When a UNSUBSCRIBE is sent, this callback is generated instead of
	//the _UNSUBSCRIBED one if we timed out waiting for a UNSUBACK.
	//Return nonzero to close the wsi.
	 */
	LWS_CALLBACK_MQTT_SHADOW_TIMEOUT			= 212,
	/**< When a Device Shadow is sent, this callback is generated if we
	//timed out waiting for a response from AWS IoT.
	//Return nonzero to close the wsi.
	 */

	/****** add new things just above ---^ ******/

	LWS_CALLBACK_USER = 1000,
	/**<  user code can use any including above without fear of clashes */
};


@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {

	// Is the socket currently unable to accept writes? (1 = choked)
	send_pipe_choked :: proc (wsi : Lws) -> c.int ---

	// Is the received fragment the final fragment of the WS message?
	is_final_fragment :: proc (wsi : Lws) -> b32 ---

	// Is the received fragment the first fragment of the WS message?
	is_first_fragment :: proc (wsi : Lws) -> b32 ---

	// Are we mid-send of a multi-fragment WS message? (1 = yes)
	ws_sending_multifragment :: proc (wsi : Lws) -> c.int ---

	// Reserved bits of the current WS frame.
	get_reserved_bits :: proc (wsi : Lws) -> c.uchar ---

	// Opcode of the current WS frame.
	get_opcode :: proc (wsi : Lws) -> c.uint8_t ---

	// Did lws buffer the last write? (1 = buffered; call again when writeable)
	partial_buffered :: proc (wsi : Lws) -> c.int ---

	// True if the current received frame was sent in binary mode.
	frame_is_binary :: proc (wsi : Lws) -> b32 ---
}


// --------------------------- lsw-misc.h -----------------------------

@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {
    // Add buffer to buflist head. Returns -1 OOM, 1 if first seg, 0 otherwise.
    buflist_append_segment      :: proc(head: ^Buflist, buf: ^u8, len: c.size_t) -> c.int ---

    // Bytes left in current segment; optionally returns pointer to remaining data.
    buflist_next_segment_len    :: proc(head: ^Buflist, buf: ^^u8) -> c.size_t ---

    // Consume len bytes from current segment; returns bytes left in current seg.
    buflist_use_segment         :: proc(head: ^Buflist, len: c.size_t) -> c.size_t ---

    // Total bytes held across all segments.
    buflist_total_len           :: proc(head: ^Buflist) -> c.size_t ---

    // Linear copy without consuming; -1 if dest too small, else bytes copied.
    buflist_linear_copy         :: proc(head: ^Buflist, ofs: c.size_t, buf: ^u8, len: c.size_t) -> c.int ---

    // Linear copy and consume; returns bytes written into buf.
    buflist_linear_use          :: proc(head: ^Buflist, buf: ^u8, len: c.size_t) -> c.int ---

    // Copy & consume at most one fragment; returns bytes written. See frag flags.
    buflist_fragment_use        :: proc(head: ^Buflist, buf: ^u8, len: c.size_t, frag_first: ^u8, frag_fin: ^u8) -> c.int ---

    // Free all segments; *head becomes NULL.
    buflist_destroy_all_segments:: proc(head: ^Buflist) ---

    // Debug: describe buflist (only in debug builds of lws).
    buflist_describe            :: proc(head: ^Buflist, id: rawptr, reason: cstring) ---

    // Pointer to start of the fragment payload, or NULL if empty.
    buflist_get_frag_start_or_NULL :: proc(head: ^Buflist) -> rawptr ---
}


@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {

    // Render value with schema into buf; returns bytes written.
    humanize                    :: proc(buf: ^u8, len: c.size_t, value: c.ulonglong, schema: ^Humanize_unit) -> c.int ---
    humanize_pad                :: proc(buf: ^u8, len: c.size_t, value: c.ulonglong, schema: ^Humanize_unit) -> c.int ---

    // Big-endian write / read helpers.
    ser_wu16be                  :: proc(b: ^u8, u: c.ushort) ---
    ser_wu32be                  :: proc(b: ^u8, u: c.uint) ---
    ser_wu64be                  :: proc(b: ^u8, u: c.ulonglong) ---
    ser_ru16be                  :: proc(b: ^u8) -> c.ushort ---
    ser_ru32be                  :: proc(b: ^u8) -> c.uint ---
    ser_ru64be                  :: proc(b: ^u8) -> c.ulonglong ---

    // Variable-length integer encode / decode; returns bytes used / needed.
    vbi_encode                  :: proc(value: c.ulonglong, buf: rawptr) -> c.int ---
    vbi_decode                  :: proc(buf: rawptr, value: ^c.ulonglong, len: c.size_t) -> c.int ---

    // Significant bits in uintptr (from MSB side).
    sigbits                     :: proc(u: uintptr) -> c.uint ---

    // Send Wake-on-LAN magic packet to MAC; optional bind IP; returns 0/ok.
    wol                         :: proc(ctx: Context, ip_or_NULL: cstring, mac_6_bytes: ^u8) -> c.int ---
}

uid_t :: c.uint;
gid_t :: c.uint;

@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {
    // From wsi → owning context.
    get_context                    :: proc(wsi: Lws) -> Context ---

    // Vhost listen port (useful if you passed 0 at creation).
    get_vhost_listen_port          :: proc(vhost: Vhost) -> c.int ---

    // Number of service threads actually in use.
    get_count_threads              :: proc(ctx: Context) -> c.int ---

    // Parent / child wsi helpers (NULL if none).
    get_parent                     :: proc(wsi: Lws) -> Lws ---
    get_child                      :: proc(wsi: Lws) -> Lws ---

    // Effective uid/gid that will apply after dropping root.
    get_effective_uid_gid          :: proc(ctx: Context, uid: ^uid_t, gid: ^gid_t) ---

    // UDP-specific info for this wsi (or NULL).
    //get_udp                        :: proc(wsi: ^Lws) -> ^Lws_udp ---

    // Get / set opaque parent data blob.
    get_opaque_parent_data         :: proc(wsi: Lws) -> rawptr ---
    set_opaque_parent_data         :: proc(wsi: Lws, data: rawptr) ---

    // Get / set opaque user data blob.
    get_opaque_user_data           :: proc(wsi: Lws) -> rawptr ---
    set_opaque_user_data           :: proc(wsi: Lws, data: rawptr) ---

    // Children pending-on-writable flags.
    get_child_pending_on_writable  :: proc(wsi: Lws) -> c.int ---
    clear_child_pending_on_writable:: proc(wsi: Lws) ---

    // Close frame helpers (len + payload pointer).
    get_close_length               :: proc(wsi: Lws) -> c.int ---
    get_close_payload              :: proc(wsi: Lws) -> ^u8 ---

    // Wsi that owns the TCP connection (H2 may differ).
    get_network_wsi                :: proc(wsi: Lws) -> ^Lws ---

    // RX flow control (boolean or bitmap flags); returns 0 on success.
    rx_flow_control                :: proc(wsi: Lws, enable: c.int) -> c.int ---

    // Allow all conns using protocol to receive again.
    rx_flow_allow_all_protocol     :: proc(ctx: Context, protocol: ^Protocols) ---

    // Bytes remaining in current WS fragment.
    remaining_packet_payload       :: proc(wsi: Lws) -> c.size_t ---
}


/////////////////////////// lws-service.h ///////////////////////////

Pollfd :: struct {
        fd : c.int,					// File descriptor to poll.
        events : c.short,			// Types of events poller cares about.
        revents : c.short,			// Types of events that actually occurred.
};

@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {
    ////////////// Built-in service loop //////////////
    // Service pending activity. timeout_ms is ignored (keep 0).
    service :: proc(ctx: Context, timeout_ms: c.int) -> c.int ---

    // Same as service(), but for a specific service thread (TSI).
    service_tsi :: proc(ctx: Context, timeout_ms: c.int, tsi: c.int) -> c.int ---

    // Wake only the service thread that owns this wsi (rarely needed).
    cancel_service_pt :: proc(wsi: Lws) ---

    // Wake the event loop immediately on this context (thread-safe wake).
    cancel_service :: proc(ctx: Context) ---

    // Tell lws to handle a pollfd that signaled events.
    // If it's an lws socket, it’s serviced and pollfd.revents is cleared.
    service_fd :: proc(ctx: Context, pollfd: ^Pollfd) -> c.int ---

    // Same as service_fd(), but for a specific TSI.
    service_fd_tsi :: proc(ctx: Context, pollfd: ^Pollfd, tsi: c.int) -> c.int ---

    // Returns adjusted poll timeout. If zero, someone needs “forced service”.
    // In that case you can call service_tsi(context, -1, tsi).
    service_adjust_timeout :: proc(ctx: Context, timeout_ms: c.int, tsi: c.int) -> c.int ---

    // Handle POLLOUT for a given wsi (helper used by external poll integrations).
    handle_POLLOUT_event :: proc(wsi: Lws, pollfd: ^Pollfd) -> c.int ---

    ////////////// libuv helpers (require LWS_WITH_LIBUV) //////////////
    // Get the libuv loop used by lws for the given TSI.
    //uv_getloop :: proc(ctx: ^Context, tsi: c.int) -> ^uv_loop_t ---

    // If you allocate your own uv handles, tie them into lws’ refcounting.
    //libuv_static_refcount_add :: proc(h: ^uv_handle_t, ctx: ^Context, tsi: c.int) ---

    // Use as the close callback for your own uv handles to drop the refcount.
    //libuv_static_refcount_del :: proc(h: ^uv_handle_t) ---
}





///////////////////////////// lws-protocols-plugin.h /////////////////////////////

@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {
	//lws_vhost_name_to_protocol() - get vhost's protocol object from its name
	//vh: vhost to search
	//name: protocol name
	//Returns NULL or a pointer to the vhost's protocol of the requested name
	vhost_name_to_protocol :: proc (vh : Vhost, name : cstring) -> ^Protocols ---

	//lws_get_protocol() - Returns a protocol pointer from a websocket
	//wsi:	pointer to struct websocket you want to know the protocol of
	//Some apis can act on all live connections of a given protocol,
	//this is how you can get a pointer to the active protocol if needed.
	get_protocol :: proc (wsi : Lws)  -> ^Protocols ---

	//lws_protocol_vh_priv_zalloc() - Allocate and zero down a protocol's per-vhost
	//vhost:	vhost the instance is related to
	//prot:		protocol the instance is related to
	//size:		bytes to allocate
	//Protocols often find it useful to allocate a per-vhost struct, this is a
	//helper to be called in the per-vhost init LWS_CALLBACK_PROTOCOL_INIT
	protocol_vh_priv_zalloc :: proc (vhost : Vhost, prot : ^Protocols, size : c.int) -> rawptr ---

	//lws_protocol_vh_priv_get() - retreive a protocol's per-vhost storage
	//vhost:	vhost the instance is related to
	//prot:		protocol the instance is related to
	//Recover a pointer to the allocated per-vhost storage for the protocol created
	//by lws_protocol_vh_priv_zalloc() earlier
	protocol_vh_priv_get :: proc (vhost : Vhost, prot : ^Protocols) -> rawptr ---

	//lws_vhd_find_by_pvo() - find a partner vhd
	// cx: the lws_context
	// protname: the name of the lws_protocol the vhd belongs to
	// pvo_name: the name of a pvo that must exist bound to the vhd
	// pvo_value: the required value of the named pvo
	//This allows architectures with multiple protocols bound together to
	//cleanly discover partner protocol instances even on completely
	//different vhosts.  For example, a proxy may consist of two protocols
	//listening on different vhosts, and there may be multiple instances
	//of the proxy in the same process.  It's desirable that each side of
	//the proxy is an independent protocol that can be freely bound to any
	//vhost, eg, allowing Unix Domain to tls / h2 proxying, or each side
	//bound to different network interfaces for localhost-only visibility
	//on one side, using existing vhost management.
	//That leaves the problem that the two sides have to find each other
	//and bind at runtime.  This api allows each side to specify the
	//protocol name, and a common pvo name and pvo value that indicates
	//the two sides belong together, and search through all the instantiated
	//vhost-protocols looking for a match.  If found, the private allocation
	//(aka "vhd" of the match is returned).  NULL is returned on no match.
	//Since this can only succeed when called by the last of the two
	//protocols to be instantiated, both sides should call it and handle
	//NULL gracefully, since it may mean that they were first and their
	//partner vhsot-protocol has not been instantiated yet.
	vhd_find_by_pvo :: proc (ctx : Context, protname : cstring, pvo_name : cstring, pvo_value : cstring) -> rawptr ---


	//lws_adjust_protocol_psds - change a vhost protocol's per session data size
	//wsi: a connection with the protocol to change
	//new_size: the new size of the per session data size for the protocol
	//Returns user_space for the wsi, after allocating
	//This should not be used except to initalize a vhost protocol's per session
	//data size one time, before any connections are accepted.
	//Sometimes the protocol wraps another protocol and needs to discover and set
	//its per session data size at runtime.
	adjust_protocol_psds :: proc (wsi : Lws, new_size : c.size_t) -> rawptr ---

	//lws_finalize_startup() - drop initial process privileges
	//context:	lws context
	//This is called after the end of the vhost protocol initializations, but
	//you may choose to call it earlier
	finalize_startup :: proc (ctx : Context) -> c.int ---

	//lws_pvo_search() - helper to find a named pvo in a linked-list
	//pvo:	the first pvo in the linked-list
	//name: the name of the pvo to return if found
	//Returns NULL, or a pointer to the name pvo in the linked-list
	pvo_search :: proc (pvo : ^Protocol_vhost_options, name : cstring) -> ^Protocol_vhost_options ---

	//lws_pvo_get_str() - retreive a string pvo value
	//in:	the first pvo in the linked-list
	//name: the name of the pvo to return if found
	//result: pointer to a const char//to get the result if any
	//Returns 0 if found and *result set, or nonzero if not found
	pvo_get_str :: proc (input : rawptr, name : cstring, result : ^cstring) -> c.int ---

	protocol_init :: proc (ctx : Context) -> c.int ---
}








///////////////////////////// lws-ring.h /////////////////////////////

@(link_prefix = "lws_", require_results, default_calling_convention="c")
foreign libwebsockets {
	//lws_ring_create() - create a new ringbuffer
	//element_len: size in bytes of one element in the ringbuffer
	//count:       number of elements the ringbuffer can contain
	//destroy_element: NULL, or callback called for each element retired when the
	//                 oldest tail moves beyond it, and for any element left when
	//                 the ringbuffer is destroyed
	//Creates the ringbuffer and its storage. Returns the new lws_ring*, or NULL on failure.
	ring_create :: proc (element_len: c.size_t, count: c.size_t, destroy_element: proc (element: rawptr)) -> ^Ring ---

	//lws_ring_destroy() - destroy a previously created ringbuffer
	//ring: the lws_ring to destroy
	//Destroys the ringbuffer allocation and the lws_ring itself.
	ring_destroy :: proc (ring: ^Ring) ---

	//lws_ring_get_count_free_elements() - how many whole elements still fit
	//ring: the lws_ring to report on
	//Returns how much room is left for whole-element insertion.
	ring_get_count_free_elements :: proc (ring: ^Ring) -> c.size_t ---

	//lws_ring_get_count_waiting_elements() - how many elements can be consumed
	//ring: the lws_ring to report on
	//tail: pointer to the tail to use, or NULL for single tail
	//Returns how many elements are waiting to be consumed from that tail's view.
	ring_get_count_waiting_elements :: proc (ring: ^Ring, tail: ^c.uint32_t) -> c.size_t ---

	//lws_ring_insert() - attempt to insert up to max_count elements from src
	//ring: the lws_ring to operate on
	//src: array of elements to insert
	//max_count: number of available elements at src
	//Attempts to insert as many elements as possible, up to max_count.
	//Returns the number of elements actually inserted.
	ring_insert :: proc (ring: ^Ring, src: rawptr, max_count: c.size_t) -> c.size_t ---

	//lws_ring_consume() - copy out and remove up to max_count elements to dest
	//ring: the lws_ring to operate on
	//tail: pointer to the tail to use, or NULL for single tail
	//dest: array to receive elements, or NULL for no copy
	//max_count: maximum elements to consume
	//Copies out up to max_count waiting elements into dest from tail's view; if
	//dest is NULL, elements are logically consumed without copying. Increments
	//the tail by the number consumed. Returns number of elements consumed.
	ring_consume :: proc (ring: ^Ring, tail: ^c.uint32_t, dest: rawptr, max_count: c.size_t) -> c.size_t ---

	//lws_ring_get_element() - pointer to next waiting element for tail
	//ring: the lws_ring to report on
	//tail: pointer to the tail to use, or NULL for single tail
	//Returns NULL if none waiting, else a const void* to the next element.
	//After using it, call lws_ring_consume(ring, &tail, NULL, 1).
	ring_get_element :: proc (ring: ^Ring, tail: ^c.uint32_t) -> rawptr ---

	//lws_ring_update_oldest_tail() - free up elements older than tail for reuse
	//ring: the lws_ring to operate on
	//tail: the tail value representing the new oldest live consumer
	//For multi-tail use, update when the "oldest" tail advances.
	ring_update_oldest_tail :: proc (ring: ^Ring, tail: c.uint32_t) ---

	//lws_ring_get_oldest_tail() - get current oldest available data index
	//ring: the lws_ring to report on
	//Use this to initialize a new consumer's tail to the oldest entry still available.
	ring_get_oldest_tail :: proc (ring: ^Ring) -> c.uint32_t ---

	//lws_ring_next_linear_insert_range() - write directly into the ring
	//ring:  the lws_ring to report on
	//start: *out: start of next linear writable range in the ring
	//bytes: *out: max length writable from *start before wrap
	//Provides direct bytewise access to the next linear insertion range. Returns
	//nonzero if no insertion currently possible.
	ring_next_linear_insert_range :: proc (ring: ^Ring, start: ^rawptr, bytes: ^c.size_t) -> c.int ---

	//lws_ring_bump_head() - commit bytes written via linear insert range
	//ring:  the lws_ring to operate on
	//bytes: number of bytes inserted at the current head
	ring_bump_head :: proc (ring: ^Ring, bytes: c.size_t) ---

	//lws_ring_dump() - debug dump of the ring state
	//ring: the lws_ring to report on
	//tail: pointer to the tail to use, or NULL for single tail
	ring_dump :: proc (ring: ^Ring, tail: ^c.uint32_t) ---
}
