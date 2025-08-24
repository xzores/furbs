package libwebsockets_odin

import "core:c"

/*
 -DLWS_WITH_TLS=ON ^
 -DLWS_WITH_NETWORK=ON ^
 -DLWS_WITH_CONMON=ON ^
 -DLWS_WITH_FILE_OPS=ON ^
 -DLWS_WITH_SYS_SMD=OFF ^
 -DLWS_WITH_MBEDTLS=OFF


 LWS_ROLE_WS = ON
 LWS_ROLE_H1 = ON
*/

/** struct lws_context_creation_info - parameters to create context and /or vhost with
 *
 * This is also used to create vhosts.... if LWS_SERVER_OPTION_EXPLICIT_VHOSTS
 * is not given, then for backwards compatibility one vhost is created at
 * context-creation time using the info from this struct.
 *
 * If LWS_SERVER_OPTION_EXPLICIT_VHOSTS is given, then no vhosts are created
 * at the same time as the context, they are expected to be created afterwards.
 */
lws_context_creation_info :: struct {
	iface : cstring,
	/**< VHOST: NULL to bind the listen socket to all interfaces, or the
	 * interface name, eg, "eth2"
	 * If options specifies LWS_SERVER_OPTION_UNIX_SOCK, this member is
	 * the pathname of a UNIX domain socket. you can use the UNIX domain
	 * sockets in abstract namespace, by prepending an at symbol to the
	 * socket name. */
	protocols : ^lws_protocols,
	/**< VHOST: Array of structures listing supported protocols and a
	 * protocol-specific callback for each one.  The list is ended with an
	 * entry that has a NULL callback pointer.  SEE ALSO .pprotocols below,
	 * which gives an alternative way to provide an array of pointers to
	 * protocol structs. */
	extensions : ^lws_extension,
	/**< VHOST: NULL or array of lws_extension structs listing the
	* extensions this context supports. */
	token_limits : ^lws_token_limits,
	/**< CONTEXT: NULL or struct lws_token_limits pointer which is
	* initialized with a token length limit for each possible WSI_TOKEN_ */
	http_proxy_address : cstring,
	/**< VHOST: If non-NULL, attempts to proxy via the given address.
	* If proxy auth is required, use format
	* "username:password\@server:port" */
	headers : ^lws_protocol_vhost_options,
	/**< VHOST: pointer to optional linked list of per-vhost
		* canned headers that are added to server responses */

	reject_service_keywords : ^lws_protocol_vhost_options,
	/**< CONTEXT: Optional list of keywords and rejection codes + text.
	*
	* The keywords are checked for existing in the user agent string.
	*
	* Eg, "badrobot" "404 Not Found"
	*/
	pvo : ^lws_protocol_vhost_options,
	/**< VHOST: pointer to optional linked list of per-vhost
	* options made accessible to protocols */
	log_filepath : cstring,
	/**< VHOST: filepath to append logs to... this is opened before
	*		any dropping of initial privileges */
	mounts : ^lws_http_mount,
	/**< VHOST: optional linked list of mounts for this vhost */
	server_string : cstring,
	/**< CONTEXT: string used in HTTP headers to identify server
	* software, if NULL, "libwebsockets". */

	error_document_404 : cstring,
	/**< VHOST: If non-NULL, when asked to serve a non-existent file,
	*          lws attempts to server this url path instead.  Eg,
	*          "/404.html" */
	port : c.int,
	/**< VHOST: Port to listen on. Use CONTEXT_PORT_NO_LISTEN to suppress
	* listening for a client. Use CONTEXT_PORT_NO_LISTEN_SERVER if you are
	* writing a server but you are using \ref sock-adopt instead of the
	* built-in listener.
	*
	* You can also set port to 0, in which case the kernel will pick
	* a random port that is not already in use.  You can find out what
	* port the vhost is listening on using lws_get_vhost_listen_port()
	*
	* If options specifies LWS_SERVER_OPTION_UNIX_SOCK, you should set
	* port to 0 */

	http_proxy_port : c.uint,
	/**< VHOST: If http_proxy_address was non-NULL, uses this port */
	max_http_header_data2 : c.uint,
	/**< CONTEXT: if max_http_header_data is 0 and this
	* is nonzero, this will be used in place of the default.  It's
	* like this for compatibility with the original short version,
	* this is unsigned int length. */
	max_http_header_pool2 : c.uint,
	/**< CONTEXT: if max_http_header_pool is 0 and this
	* is nonzero, this will be used in place of the default.  It's
	* like this for compatibility with the original short version:
	* this is unsigned int length. */

	keepalive_timeout : c.int,
	/**< VHOST: (default = 0 = 5s, 31s for http/2) seconds to allow remote
	* client to hold on to an idle HTTP/1.1 connection.  Timeout lifetime
	* applied to idle h2 network connections */
	http2_settings : [7]c.uint32_t,
	/**< VHOST:  if http2_settings[0] is nonzero, the values given in
	*	      http2_settings[1]..[6] are used instead of the lws
	*	      platform default values.
	*	      Just leave all at 0 if you don't care.
	*/

	max_http_header_data : c.ushort,
	/**< CONTEXT: The max amount of header payload that can be handled
	* in an http request (unrecognized header payload is dropped) */
	max_http_header_pool : c.ushort,
	/**< CONTEXT: The max number of connections with http headers that
	* can be processed simultaneously (the corresponding memory is
	* allocated and deallocated dynamically as needed).  If the pool is
	* fully busy new incoming connections must wait for accept until one
	* becomes free. 0 = allow as many ah as number of availble fds for
	* the process */


	ssl_private_key_password : cstring,
	/**< VHOST: NULL or the passphrase needed for the private key. (For
	 * backwards compatibility, this can also be used to pass the client
	 * cert passphrase when setting up a vhost client SSL context, but it is
	 * preferred to use .client_ssl_private_key_password for that.) */
	 
	ssl_cert_filepath : cstring,
	/**< VHOST: If libwebsockets was compiled to use ssl, and you want
	 * to listen using SSL, set to the filepath to fetch the
	 * server cert from, otherwise NULL for unencrypted.  (For backwards
	 * compatibility, this can also be used to pass the client certificate
	 * when setting up a vhost client SSL context, but it is preferred to
	 * use .client_ssl_cert_filepath for that.)
	 *
	 * Notice you can alternatively set a single DER or PEM from a memory
	 * buffer as the vhost tls cert using \p server_ssl_cert_mem and
	 * \p server_ssl_cert_mem_len.
	 */

	ssl_private_key_filepath : cstring,
	/**<  VHOST: filepath to private key if wanting SSL mode,
	 * this should not be set to NULL when ssl_cert_filepath is set.
	 *
	 * Alteratively, the certificate and private key can both be set in
	 * the OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS callback directly via
	 * openSSL library calls.  This requires that
	 * LWS_SERVER_OPTION_CREATE_VHOST_SSL_CTX is set in the vhost info options
	 * to force initializtion of the SSL_CTX context.
	 *
	 * (For backwards compatibility, this can also be used
	 * to pass the client cert private key filepath when setting up a
	 * vhost client SSL context, but it is preferred to use
	 * .client_ssl_private_key_filepath for that.)
	 *
	 * Notice you can alternatively set a DER or PEM private key from a
	 * memory buffer as the vhost tls private key using
	 * \p server_ssl_private_key_mem and \p server_ssl_private_key_mem_len.
	 */
	ssl_ca_filepath : cstring,
	/**< VHOST: CA certificate filepath or NULL.  (For backwards
	 * compatibility, this can also be used to pass the client CA
	 * filepath when setting up a vhost client SSL context,
	 * but it is preferred to use .client_ssl_ca_filepath for that.)
	 *
	 * Notice you can alternatively set a DER or PEM CA cert from a memory
	 * buffer using \p server_ssl_ca_mem and \p server_ssl_ca_mem_len.
	 */
	ssl_cipher_list : cstring,
	/**< VHOST: List of valid ciphers to use ON TLS1.2 AND LOWER ONLY (eg,
	 * "RC4-MD5:RC4-SHA:AES128-SHA:AES256-SHA:HIGH:!DSS:!aNULL"
	 * or you can leave it as NULL to get "DEFAULT" (For backwards
	 * compatibility, this can also be used to pass the client cipher
	 * list when setting up a vhost client SSL context,
	 * but it is preferred to use .client_ssl_cipher_list for that.)
	 * SEE .tls1_3_plus_cipher_list and .client_tls_1_3_plus_cipher_list
	 * for the equivalent for tls1.3.
	 */
	ecdh_curve : cstring,
	/**< VHOST: if NULL, defaults to initializing server with
	 *   "prime256v1" */
	tls1_3_plus_cipher_list : cstring,
	/**< VHOST: List of valid ciphers to use for incoming server connections
	 * ON TLS1.3 AND ABOVE (eg, "TLS_CHACHA20_POLY1305_SHA256" on this vhost
	 * or you can leave it as NULL to get "DEFAULT".
	 * SEE .client_tls_1_3_plus_cipher_list to do the same on the vhost
	 * client SSL_CTX.
	 */

	server_ssl_cert_mem : cstring,
	/**< VHOST: Alternative for \p ssl_cert_filepath that allows setting
	 * from memory instead of from a file.  At most one of
	 * \p ssl_cert_filepath or \p server_ssl_cert_mem should be non-NULL. */
	server_ssl_private_key_mem : cstring,
	/**<  VHOST: Alternative for \p ssl_private_key_filepath allowing
	 * init from a private key in memory instead of a file.  At most one
	 * of \p ssl_private_key_filepath or \p server_ssl_private_key_mem
	 * should be non-NULL. */
	server_ssl_ca_mem : cstring,
	/**< VHOST: Alternative for \p ssl_ca_filepath allowing
	 * init from a CA cert in memory instead of a file.  At most one
	 * of \p ssl_ca_filepath or \p server_ssl_ca_mem should be non-NULL. */

	ssl_options_set : c.long,
	/**< VHOST: Any bits set here will be set as server SSL options */
	ssl_options_clear : c.long,
	/**< VHOST: Any bits set here will be cleared as server SSL options */
	simultaneous_ssl_restriction : c.int,
	/**< CONTEXT: 0 (no limit) or limit of simultaneous SSL sessions
	 * possible.*/
	simultaneous_ssl_handshake_restriction : c.int,
	/**< CONTEXT: 0 (no limit) or limit of simultaneous SSL handshakes ongoing */
	ssl_info_event_mask : c.int,
	/**< VHOST: mask of ssl events to be reported on LWS_CALLBACK_SSL_INFO
	 * callback for connections on this vhost.  The mask values are of
	 * the form SSL_CB_ALERT, defined in openssl/ssl.h.  The default of
	 * 0 means no info events will be reported.
	 */
	server_ssl_cert_mem_len : c.uint,
	/**< VHOST: Server SSL context init: length of server_ssl_cert_mem in
	 * bytes */
	server_ssl_private_key_mem_len : c.uint,
	/**< VHOST: length of \p server_ssl_private_key_mem in memory */
	server_ssl_ca_mem_len : c.uint,
	/**< VHOST: length of \p server_ssl_ca_mem in memory */

	alpn : c.unit,
	/**< CONTEXT: If non-NULL, default list of advertised alpn, comma-
	 *	      separated
	 *
	 *     VHOST: If non-NULL, per-vhost list of advertised alpn, comma-
	 *	      separated
	 */
	
	client_ssl_private_key_password : cstring,
	/**< VHOST: Client SSL context init: NULL or the passphrase needed
	* for the private key */
	client_ssl_cert_filepath : cstring,
	/**< VHOST: Client SSL context init: The certificate the client
	* should present to the peer on connection */
	client_ssl_cert_mem : rawptr,
	/**< VHOST: Client SSL context init: client certificate memory buffer or
	* NULL... use this to load client cert from memory instead of file */
	client_ssl_cert_mem_len : c.uint,
	/**< VHOST: Client SSL context init: length of client_ssl_cert_mem in
	* bytes */
	client_ssl_private_key_filepath : cstring,
	/**<  VHOST: Client SSL context init: filepath to client private key
	* if this is set to NULL but client_ssl_cert_filepath is set, you
	* can handle the LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS
	* callback of protocols[0] to allow setting of the private key directly
	* via tls library calls */
	client_ssl_key_mem : rawptr,
	/**< VHOST: Client SSL context init: client key memory buffer or
	* NULL... use this to load client key from memory instead of file */
	client_ssl_ca_filepath : cstring,
	/**< VHOST: Client SSL context init: CA certificate filepath or NULL */
	client_ssl_ca_mem : rawptr,
	/**< VHOST: Client SSL context init: CA certificate memory buffer or
	* NULL... use this to load CA cert from memory instead of file */

	client_ssl_cipher_list : cstring,
	/**< VHOST: Client SSL context init: List of valid ciphers to use (eg,
	* "RC4-MD5:RC4-SHA:AES128-SHA:AES256-SHA:HIGH:!DSS:!aNULL"
	* or you can leave it as NULL to get "DEFAULT" */
	client_tls_1_3_plus_cipher_list : cstring,
	/**< VHOST: List of valid ciphers to use for outgoing client connections
	* ON TLS1.3 AND ABOVE on this vhost (eg,
	* "TLS_CHACHA20_POLY1305_SHA256") or you can leave it as NULL to get
	* "DEFAULT".
	*/

	ssl_client_options_set : c.long,
	/**< VHOST: Any bits set here will be set as CLIENT SSL options */
	ssl_client_options_clear : c.long,
	/**< VHOST: Any bits set here will be cleared as CLIENT SSL options */


	client_ssl_ca_mem_len : c.uint,
	/**< VHOST: Client SSL context init: length of client_ssl_ca_mem in
	* bytes */
	client_ssl_key_mem_len : c.uint,
	/**< VHOST: Client SSL context init: length of client_ssl_key_mem in
	* bytes */

	provided_client_ssl_ctx : ^SSL_CTX,
	/**< CONTEXT: If non-null, swap out libwebsockets ssl
	  * implementation for the one provided by provided_ssl_ctx.
	  * Libwebsockets no longer is responsible for freeing the context
	  * if this option is selected. */

	ka_time : c.int,
	/**< CONTEXT: 0 for no TCP keepalive, otherwise apply this keepalive
	 * timeout to all libwebsocket sockets, client or server */
	ka_probes : c.int,
	/**< CONTEXT: if ka_time was nonzero, after the timeout expires how many
	 * times to try to get a response from the peer before giving up
	 * and killing the connection */
	ka_interval : c.int,
	/**< CONTEXT: if ka_time was nonzero, how long to wait before each ka_probes
	 * attempt */

	timeout_secs : c.uint,
	/**< VHOST: various processes involving network roundtrips in the
	 * library are protected from hanging forever by timeouts.  If
	 * nonzero, this member lets you set the timeout used in seconds.
	 * Otherwise a default timeout is used. */
	connect_timeout_secs : c.uint,
	/**< VHOST: client connections have this long to find a working server
	 * from the DNS results, or the whole connection times out.  If zero,
	 * a default timeout is used */
	bind_iface : c.int,
	/**< VHOST: nonzero to strictly bind sockets to the interface name in
	 * .iface (eg, "eth2"), using SO_BIND_TO_DEVICE.
	 *
	 * Requires SO_BINDTODEVICE support from your OS and CAP_NET_RAW
	 * capability.
	 *
	 * Notice that common things like access network interface IP from
	 * your local machine use your lo / loopback interface and will be
	 * disallowed by this.
	 */
	timeout_secs_ah_idle : c.uint,
	/**< VHOST: seconds to allow a client to hold an ah without using it.
	 * 0 defaults to 10s. */
	
	tls_session_timeout : c.uint32_t,
	/**< VHOST: seconds until timeout/ttl for newly created sessions.
	 * 0 means default timeout (defined per protocol, usually 300s). */
	tls_session_cache_max : c.uint32_t,
	/**< VHOST: 0 for default limit of 10, or the maximum number of
	 * client tls sessions we are willing to cache */

	gid : gid_t,
	/**< CONTEXT: group id to change to after setting listen socket,
	 *   or -1. See also .username below. */
	uid : uid_t,
	/**< CONTEXT: user id to change to after setting listen socket,
	 *   or -1.  See also .groupname below. */
	options : c.uint64_t,
	/**< VHOST + CONTEXT: 0, or LWS_SERVER_OPTION_... bitfields */
	user : rawptr,
	/**< VHOST + CONTEXT: optional user pointer that will be associated
	 * with the context when creating the context (and can be retrieved by
	 * lws_context_user(context), or with the vhost when creating the vhost
	 * (and can be retrieved by lws_vhost_user(vhost)).  You will need to
	 * use LWS_SERVER_OPTION_EXPLICIT_VHOSTS and create the vhost separately
	 * if you care about giving the context and vhost different user pointer
	 * values.
	 */

	count_threads : c.uint,
	/**< CONTEXT: how many contexts to create in an array, 0 = 1 */
	fd_limit_per_thread : c.uint,
	/**< CONTEXT: nonzero means restrict each service thread to this
	 * many fds, 0 means the default which is divide the process fd
	 * limit by the number of threads.
	 *
	 * Note if this is nonzero, and fd_limit_per_thread multiplied by the
	 * number of service threads is less than the process ulimit, then lws
	 * restricts internal lookup table allocation to the smaller size, and
	 * switches to a less efficient lookup scheme.  You should use this to
	 * trade off speed against memory usage if you know the lws context
	 * will only use a handful of fds.
	 *
	 * Bear in mind lws may use some fds internally, for example for the
	 * cancel pipe, so you may need to allow for some extras for normal
	 * operation.
	 */
	vhost_name : cstring,
	/**< VHOST: name of vhost, must match external DNS name used to
	 * access the site, like "warmcat.com" as it's used to match
	 * Host: header and / or SNI name for SSL.
	 * CONTEXT: NULL, or the name to associate with the context for
	 * context-specific logging
	 */

	external_baggage_free_on_destroy : rawptr,
	/**< CONTEXT: NULL, or pointer to something externally malloc'd, that
	 * should be freed when the context is destroyed.  This allows you to
	 * automatically sync the freeing action to the context destruction
	 * action, so there is no need for an external free() if the context
	 * succeeded to create.
	 */


	pt_serv_buf_size : c.uint,
	/**< CONTEXT: 0 = default of 4096.  This buffer is used by
	 * various service related features including file serving, it
	 * defines the max chunk of file that can be sent at once.
	 * At the risk of lws having to buffer failed large sends, it
	 * can be increased to, eg, 128KiB to improve throughput. */

	fops : ^lws_plat_file_ops,
	/**< CONTEXT: NULL, or pointer to an array of fops structs, terminated
	 * by a sentinel with NULL .open.
	 *
	 * If NULL, lws provides just the platform file operations struct for
	 * backwards compatibility.
	 */

	foreign_loops : ^rawptr, //Yes a pointer to a pointer
	/**< CONTEXT: This is ignored if the context is not being started with
	 *		an event loop, ie, .options has a flag like
	 *		LWS_SERVER_OPTION_LIBUV.
	 *
	 *		NULL indicates lws should start its own even loop for
	 *		each service thread, and deal with closing the loops
	 *		when the context is destroyed.
	 *
	 *		Non-NULL means it points to an array of external
	 *		("foreign") event loops that are to be used in turn for
	 *		each service thread.  In the default case of 1 service
	 *		thread, it can just point to one foreign event loop.
	 */
	
	signal_cb : proc(event_lib_handle: rawptr, signum: c.int),
	/**< CONTEXT: NULL: default signal handling.  Otherwise this receives
	 *		the signal handler callback.  event_lib_handle is the
	 *		native event library signal handle, eg uv_signal_t *
	 *		for libuv.
	 */
	pcontext : ^^lws_context, //Yes a pointer to a pointer
	/**< CONTEXT: if non-NULL, at the end of context destroy processing,
	 * the pointer pointed to by pcontext is written with NULL.  You can
	 * use this to let foreign event loops know that lws context destruction
	 * is fully completed.
	 */
	
	finalize : proc(vh: ^lws_vhost, arg: rawptr),
	/**< VHOST: NULL, or pointer to function that will be called back
	 *	    when the vhost is just about to be freed.  The arg parameter
	 *	    will be set to whatever finalize_arg is below.
	 */
	finalize_arg : rawptr,
	/**< VHOST: opaque pointer lws ignores but passes to the finalize
	 *	    callback.  If you don't care, leave it NULL.
	 */

	listen_accept_role : cstring,
	/**< VHOST: NULL for default, or force accepted incoming connections to
	 * bind to this role.  Uses the role names from their ops struct, eg,
	 * "raw-skt".
	 */
	listen_accept_protocol : cstring,
	/**< VHOST: NULL for default, or force accepted incoming connections to
	 * bind to this vhost protocol name.
	 */
	pprotocols : ^^lws_protocols,
	/**< VHOST: NULL: use .protocols, otherwise ignore .protocols and use
	 * this array of pointers to protocols structs.  The end of the array
	 * is marked by a NULL pointer.
	 *
	 * This is preferred over .protocols, because it allows the protocol
	 * struct to be opaquely defined elsewhere, with just a pointer to it
	 * needed to create the context with it.  .protocols requires also
	 * the type of the user data to be known so its size can be given.
	 */

	username : cstring, /**< CONTEXT: string username for post-init
	 * permissions.  Like .uid but takes a string username. */
	groupname : cstring, /**< CONTEXT: string groupname for post-init
	 * permissions.  Like .gid but takes a string groupname. */
	unix_socket_perms : cstring, /**< VHOST: if your vhost is listening
	 * on a unix socket, you can give a "username:groupname" string here
	 * to control the owner:group it's created with.  It's always created
	 * with 0660 mode. */
	system_ops : ^lws_system_ops_t,
	/**< CONTEXT: hook up lws_system_ apis to system-specific
	 * implementations */
	retry_and_idle_policy : ^lws_retry_bo_t,
	/**< VHOST: optional retry and idle policy to apply to this vhost.
	 *   Currently only the idle parts are applied to the connections.
	 */

	register_notifier_list: [^]^lws_state_notify_link_t,
	/**< CONTEXT: NULL, or pointer to an array of notifiers that should
	 * be registered during context creation, so they can see state change
	 * events from very early on.  The array should end with a NULL. */

	pss_policies_json : cstring, /**< CONTEXT: point to a string
	* containing a JSON description of the secure streams policies.  Set
	* to NULL if not using Secure Streams.
	* If the platform supports files and the string does not begin with
	* '{', lws treats the string as a filepath to open to get the JSON
	* policy.
	*/

	pss_plugins : [^]^lws_ss_plugin, /**< CONTEXT: point to an array
	 * of pointers to plugin structs here, terminated with a NULL ptr.
	 * Set to NULL if not using Secure Streams. */
	ss_proxy_bind : cstring, /**< CONTEXT: NULL, or: ss_proxy_port == 0:
	 * point to a string giving the Unix Domain Socket address to use (start
	 * with @ for abstract namespace), ss_proxy_port nonzero: set the
	 * network interface address (not name, it's ambiguous for ipv4/6) to
	 * bind the tcp connection to the proxy to */
	ss_proxy_address : cstring, /**< CONTEXT: NULL, or if ss_proxy_port
	 * nonzero: the tcp address of the ss proxy to connect to */
	ss_proxy_port : c.uint16_t, /* 0 = if connecting to ss proxy, do it via a
	 * Unix Domain Socket, "+@proxy.ss.lws" if ss_proxy_bind is NULL else
	 * the socket path given in ss_proxy_bind (start it with a + or +@),
	 * nonzero means connect via a tcp socket to the tcp address in
	 * ss_proxy_bind and the given port */
	txp_ops_ssproxy : ^lws_transport_proxy_ops, /**< CONTEXT: NULL, or
	 * custom sss transport ops used for ss proxy communication.  NULL means
	 * to use the default wsi-based proxy server */
	txp_ssproxy_info : rawptr, /**< CONTEXT: NULL, or extra transport-
	 * specifi creation info to be used at \p txp_ops_ssproxy creation */
	txp_ops_sspc : ^lws_transport_client_ops, /**< CONTEXT: NULL, or
	 * custom sss transport ops used for ss client communication to the ss
	 * proxy.  NULL means to use the default wsi-based client support */

	rlimit_nofile : c.int,
	/**< 0 = inherit the initial ulimit for files / sockets from the startup
	 * environment.  Nonzero = try to set the limit for this process.
	 */

	fo_listen_queue : c.int,
	/**< VHOST: 0 = no TCP_FASTOPEN, nonzero = enable TCP_FASTOPEN if the
	* platform supports it, with the given queue length for the listen
	* socket.
	*/

	event_lib_custom : ^lws_plugin_evlib,
	/**< CONTEXT: If non-NULL, override event library selection so it uses
	* this custom event library implementation, instead of default internal
	* loop.  Don't set any other event lib context creation flags in that
	* case. it will be used automatically.  This is useful for integration
	* where an existing application is using its own handrolled event loop
	* instead of an event library, it provides a way to allow lws to use
	* the custom event loop natively as if it were an "event library".
	*/

	log_cx : ^lws_log_cx_t,
	/**< CONTEXT: NULL to use the default, process-scope logging context,
	* else a specific logging context to associate with this context */

	http_nsc_filepath : cstring,
	/**< CONTEXT: Filepath to use for http netscape cookiejar file */

	http_nsc_heap_max_footprint : c.size_t,
	/**< CONTEXT: 0, or limit in bytes for heap usage of memory cookie
	* cache */
	http_nsc_heap_max_items : c.size_t,
	/**< CONTEXT: 0, or the max number of items allowed in the cookie cache
	* before destroying lru items to keep it under the limit */
	http_nsc_heap_max_payload : c.size_t,
	/**< CONTEXT: 0, or the maximum size of a single cookie we are able to
	* handle */

	win32_connect_check_interval_usec : c.uint,
	/**< CONTEXT: win32 needs client connection status checking at intervals
	* to work reliably.  This sets the interval in us, up to 999999.  By
	* default, it's 500us.
	*/

	default_loglevel : c.int,
	/**< CONTEXT: 0 for LLL_USER, LLL_ERR, LLL_WARN, LLL_NOTICE enabled by default when
	* using lws_cmdline_option_handle_builtin(), else set to the LLL_ flags you want
	* to be the default before calling lws_cmdline_option_handle_builtin().  Your
	* selected default loglevel can then be cleanly overridden using -d 1039 etc
	* commandline switch */

	vh_listen_sockfd : lws_sockfd_type,
	/**< VHOST: 0 for normal vhost listen socket fd creation, if any.
	* Nonzero to force the selection of an already-existing fd for the
	* vhost's listen socket, which is already prepared.  This is intended
	* for an external process having chosen the fd, which cannot then be
	* zero.
	*/

	wol_if : cstring,
	/**< CONTEXT: NULL, or interface name to bind outgoing WOL packet to */

	/* Add new things just above here ---^
	* This is part of the ABI, don't needlessly break compatibility
	*
	* The below is to ensure later library versions with new
	* members added above will see 0 (default) even if the app
	* was not built against the newer headers.
	*/
	_unused : [2]rawptr, /**< dummy */
}
