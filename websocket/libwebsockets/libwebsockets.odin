package libwebsockets_odin

import "core:c"


LWS_WITH_NETWORK :: true;
LWS_ROLE_WS :: true;

lws_ptr :: distinct rawptr;

// Determine the pad size based on architecture
// Odin does not have preprocessor macros, so you can use a constant and conditional compilation
// For x86_64, use 16, otherwise use size_of(pointer)
when ODIN_ARCH == .amd64 {
	LWS_PAD_SIZE : int = 16;
	// last 2 is for lws-meta
	LWS_PRE :: 16
	// used prior to 1.7 and retained for backward compatibility
	LWS_SEND_BUFFER_PRE_PADDING  : int : LWS_PRE;
	LWS_SEND_BUFFER_POST_PADDING : int : 0;
} else {
    //LWS_PAD_SIZE : int = size_of(rawptr);
	#panic("TODO");
}

/*
 * NOTE: These public enums are part of the abi.  If you want to add one,
 * add it at where specified so existing users are unaffected.
 */
/** enum lws_callback_reasons - reason you're getting a protocol callback */
lws_callback_reasons :: enum u32 {
	
	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to wsi and protocol binding lifecycle -----
	 */

	CALLBACK_PROTOCOL_INIT				= 27,
	/**< One-time call per protocol, per-vhost using it, so it can
	 * do initial setup / allocations etc */

	CALLBACK_PROTOCOL_DESTROY				= 28,
	/**< One-time call per protocol, per-vhost using it, indicating
	 * this protocol won't get used at all after this callback, the
	 * vhost is getting destroyed.  Take the opportunity to
	 * deallocate everything that was allocated by the protocol. */

	CALLBACK_WSI_CREATE					= 29,
	/**< outermost (earliest) wsi create notification to protocols[0] */

	CALLBACK_WSI_DESTROY				= 30,
	/**< outermost (latest) wsi destroy notification to protocols[0] */

	CALLBACK_WSI_TX_CREDIT_GET				= 103,
	/**< manually-managed connection received TX credit (len is int32) */


	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to Server TLS -----
	 */

	CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS	= 21,
	/**< if configured for
	 * including OpenSSL support, this callback allows your user code
	 * to perform extra SSL_CTX_load_verify_locations() or similar
	 * calls to direct OpenSSL where to find certificates the client
	 * can use to confirm the remote server identity.  user is the
	 * OpenSSL SSL_CTX* */

	CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS	= 22,
	/**< if configured for
	 * including OpenSSL support, this callback allows your user code
	 * to load extra certificates into the server which allow it to
	 * verify the validity of certificates returned by clients.  user
	 * is the server's OpenSSL SSL_CTX* and in is the lws_vhost */

	CALLBACK_OPENSSL_PERFORM_CLIENT_CERT_VERIFICATION	= 23,
	/**< if the libwebsockets vhost was created with the option
	 * SERVER_OPTION_REQUIRE_VALID_OPENSSL_CLIENT_CERT, then this
	 * callback is generated during OpenSSL verification of the cert
	 * sent from the client.  It is sent to protocol[0] callback as
	 * no protocol has been negotiated on the connection yet.
	 * Notice that the libwebsockets context and wsi are both NULL
	 * during this callback.  See
	 *  http://www.openssl.org/docs/ssl/SSL_CTX_set_verify.html
	 * to understand more detail about the OpenSSL callback that
	 * generates this libwebsockets callback and the meanings of the
	 * arguments passed.  In this callback, user is the x509_ctx,
	 * in is the ssl pointer and len is preverify_ok
	 * Notice that this callback maintains libwebsocket return
	 * conventions, return 0 to mean the cert is OK or 1 to fail it.
	 * This also means that if you don't handle this callback then
	 * the default callback action of returning 0 allows the client
	 * certificates. */

	CALLBACK_SSL_INFO					= 67,
	/**< SSL connections only.  An event you registered an
	 * interest in at the vhost has occurred on a connection
	 * using the vhost.  in is a pointer to a
	 * struct lws_ssl_info containing information about the
	 * event*/

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to Client TLS -----
	 */

	CALLBACK_OPENSSL_PERFORM_SERVER_CERT_VERIFICATION = 58,
	/**< Similar to CALLBACK_OPENSSL_PERFORM_CLIENT_CERT_VERIFICATION
	 * this callback is called during OpenSSL verification of the cert
	 * sent from the server to the client. It is sent to protocol[0]
	 * callback as no protocol has been negotiated on the connection yet.
	 * Notice that the wsi is set because lws_client_connect_via_info was
	 * successful.
	 *
	 * See http://www.openssl.org/docs/ssl/SSL_CTX_set_verify.html
	 * to understand more detail about the OpenSSL callback that
	 * generates this libwebsockets callback and the meanings of the
	 * arguments passed. In this callback, user is the x509_ctx,
	 * in is the ssl pointer and len is preverify_ok.
	 *
	 * THIS IS NOT RECOMMENDED BUT if a cert validation error shall be
	 * overruled and cert shall be accepted as ok,
	 * X509_STORE_CTX_set_error((X509_STORE_CTX*)user, X509_V_OK); must be
	 * called and return value must be 0 to mean the cert is OK;
	 * returning 1 will fail the cert in any case.
	 *
	 * This also means that if you don't handle this callback then
	 * the default callback action of returning 0 will not accept the
	 * certificate in case of a validation error decided by the SSL lib.
	 *
	 * This is expected and secure behaviour when validating certificates.
	 *
	 * Note: LCCSCF_ALLOW_SELFSIGNED and
	 * LCCSCF_SKIP_SERVER_CERT_HOSTNAME_CHECK still work without this
	 * callback being implemented.
	 */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to HTTP Server  -----
	 */

	CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED		= 19,
	/**< A new client has been accepted by the ws server.  This
	 * callback allows setting any relevant property to it. Because this
	 * happens immediately after the instantiation of a new client,
	 * there's no websocket protocol selected yet so this callback is
	 * issued only to protocol 0. Only wsi is defined, pointing to the
	 * new client, and the return value is ignored. */

	CALLBACK_HTTP					= 12,
	/**< an http request has come from a client that is not
	 * asking to upgrade the connection to a websocket
	 * one.  This is a chance to serve http content,
	 * for example, to send a script to the client
	 * which will then open the websockets connection.
	 * in points to the URI path requested and
	 * lws_serve_http_file() makes it very
	 * simple to send back a file to the client.
	 * Normally after sending the file you are done
	 * with the http connection, since the rest of the
	 * activity will come by websockets from the script
	 * that was delivered by http, so you will want to
	 * return 1; to close and free up the connection. */

	CALLBACK_HTTP_BODY					= 13,
	/**< the next len bytes data from the http
	 * request body HTTP connection is now available in in. */

	CALLBACK_HTTP_BODY_COMPLETION			= 14,
	/**< the expected amount of http request body has been delivered */

	CALLBACK_HTTP_FILE_COMPLETION			= 15,
	/**< a file requested to be sent down http link has completed. */

	CALLBACK_HTTP_WRITEABLE				= 16,
	/**< you can write more down the http protocol link now. */

	CALLBACK_CLOSED_HTTP				=  5,
	/**< when a HTTP (non-websocket) session ends */

	CALLBACK_FILTER_HTTP_CONNECTION			= 18,
	/**< called when the request has
	 * been received and parsed from the client, but the response is
	 * not sent yet.  Return non-zero to disallow the connection.
	 * user is a pointer to the connection user space allocation,
	 * in is the URI, eg, "/"
	 * In your handler you can use the public APIs
	 * lws_hdr_total_length() / lws_hdr_copy() to access all of the
	 * headers using the header enums lws_token_indexes from
	 * libwebsockets.h to check for and read the supported header
	 * presence and content before deciding to allow the http
	 * connection to proceed or to kill the connection. */

	CALLBACK_ADD_HEADERS				= 53,
	/**< This gives your user code a chance to add headers to a server
	 * transaction bound to your protocol.  `in` points to a
	 * `struct lws_process_html_args` describing a buffer and length
	 * you can add headers into using the normal lws apis.
	 *
	 * (see CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER to add headers to
	 * a client transaction)
	 *
	 * Only `args->p` and `args->len` are valid, and `args->p` should
	 * be moved on by the amount of bytes written, if any.  Eg
	 *
	 * 	case CALLBACK_ADD_HEADERS:
	 *
	 *          struct lws_process_html_args *args =
	 *          		(struct lws_process_html_args *)in;
	 *
	 *	    if (lws_add_http_header_by_name(wsi,
	 *			(unsigned char *)"set-cookie:",
	 *			(unsigned char *)cookie, cookie_len,
	 *			(unsigned char **)&args->p,
	 *			(unsigned char *)args->p + args->max_len))
	 *		return 1;
	 *
	 *          break;
	 */

	CALLBACK_VERIFY_BASIC_AUTHORIZATION = 102,
	/**< This gives the user code a chance to accept or reject credentials
	 * provided HTTP to basic authorization. It will only be called if the
	 * http mount's authentication_mode is set to LWSAUTHM_BASIC_AUTH_CALLBACK
	 * `in` points to a credential string of the form `username:password` If
	 * the callback returns zero (the default if unhandled), then the
	 * transaction ends with HTTP_STATUS_UNAUTHORIZED, otherwise the request
	 * will be processed */

	CALLBACK_CHECK_ACCESS_RIGHTS			= 51,
	/**< This gives the user code a chance to forbid an http access.
	 * `in` points to a `struct lws_process_html_args`, which
	 * describes the URL, and a bit mask describing the type of
	 * authentication required.  If the callback returns nonzero,
	 * the transaction ends with HTTP_STATUS_UNAUTHORIZED. */

	CALLBACK_PROCESS_HTML				= 52,
	/**< This gives your user code a chance to mangle outgoing
	 * HTML.  `in` points to a `struct lws_process_html_args`
	 * which describes the buffer containing outgoing HTML.
	 * The buffer may grow up to `.max_len` (currently +128
	 * bytes per buffer).
	 */

	CALLBACK_HTTP_BIND_PROTOCOL				= 49,
	/**< By default, all HTTP handling is done in protocols[0].
	 * However you can bind different protocols (by name) to
	 * different parts of the URL space using callback mounts.  This
	 * callback occurs in the new protocol when a wsi is bound
	 * to that protocol.  Any protocol allocation related to the
	 * http transaction processing should be created then.
	 * These specific callbacks are necessary because with HTTP/1.1,
	 * a single connection may perform at series of different
	 * transactions at different URLs, thus the lifetime of the
	 * protocol bind is just for one transaction, not connection. */

	CALLBACK_HTTP_DROP_PROTOCOL				= 50,
	/**< This is called when a transaction is unbound from a protocol.
	 * It indicates the connection completed its transaction and may
	 * do something different now.  Any protocol allocation related
	 * to the http transaction processing should be destroyed. */

	CALLBACK_HTTP_CONFIRM_UPGRADE			= 86,
	/**< This is your chance to reject an HTTP upgrade action.  The
	 * name of the protocol being upgraded to is in 'in', and the ah
	 * is still bound to the wsi, so you can look at the headers.
	 *
	 * The default of returning 0 (ie, also if not handled) means the
	 * upgrade may proceed.  Return <0 to just hang up the connection,
	 * or >0 if you have rejected the connection by returning http headers
	 * and response code yourself.
	 *
	 * There is no need for you to call transaction_completed() as the
	 * caller will take care of it when it sees you returned >0.
	 */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to HTTP Client  -----
	 */

	CALLBACK_ESTABLISHED_CLIENT_HTTP			= 44,
	/**< The HTTP client connection has succeeded, and is now
	 * connected to the server */

	CALLBACK_CLOSED_CLIENT_HTTP				= 45,
	/**< The HTTP client connection is closing */

	CALLBACK_RECEIVE_CLIENT_HTTP_READ			= 48,
	/**< This is generated by lws_http_client_read() used to drain
	 * incoming data.  In the case the incoming data was chunked, it will
	 * be split into multiple smaller callbacks for each chunk block,
	 * removing the chunk headers. If not chunked, it will appear all in
	 * one callback. */

	CALLBACK_RECEIVE_CLIENT_HTTP			= 46,
	/**< This indicates data was received on the HTTP client connection.  It
	 * does NOT actually drain or provide the data, so if you are doing
	 * http client, you MUST handle this and call lws_http_client_read().
	 * Failure to deal with it as in the minimal examples may cause spinning
	 * around the event loop as it's continuously signalled the same data
	 * is available for read.  The related minimal examples show how to
	 * handle it.
	 *
	 * It's possible to defer calling lws_http_client_read() if you use
	 * rx flow control to stop further rx handling on the connection until
	 * you did deal with it.  But normally you would call it in the handler.
	 *
	 * lws_http_client_read() strips any chunked framing and calls back
	 * with only payload data to CALLBACK_RECEIVE_CLIENT_HTTP_READ.  The
	 * chunking is the reason this is not just all done in one callback for
	 * http.
	 */
	CALLBACK_COMPLETED_CLIENT_HTTP			= 47,
	/**< The client transaction completed... at the moment this
	 * is the same as closing since transaction pipelining on
	 * client side is not yet supported.  */

	CALLBACK_CLIENT_HTTP_WRITEABLE			= 57,
	/**< when doing an HTTP type client connection, you can call
	 * lws_client_http_body_pending(wsi, 1) from
	 * CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER to get these callbacks
	 * sending the HTTP headers.
	 *
	 * From this callback, when you have sent everything, you should let
	 * lws know by calling lws_client_http_body_pending(wsi, 0)
	 */

	CALLBACK_CLIENT_HTTP_REDIRECT			= 104,
	/**< we're handling a 3xx redirect... return nonzero to hang up */

	CALLBACK_CLIENT_HTTP_BIND_PROTOCOL			= 85,
	CALLBACK_CLIENT_HTTP_DROP_PROTOCOL			= 76,

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to Websocket Server -----
	 */

	CALLBACK_ESTABLISHED				=  0,
	/**< (VH) after the server completes a handshake with an incoming
	 * client.  If you built the library with ssl support, in is a
	 * pointer to the ssl struct associated with the connection or NULL.
	 *
	 * b0 of len is set if the connection was made using ws-over-h2
	 */

	CALLBACK_CLOSED					=  4,
	/**< when the websocket session ends */

	CALLBACK_SERVER_WRITEABLE				= 11,
	/**< See CALLBACK_CLIENT_WRITEABLE */

	CALLBACK_RECEIVE					=  6,
	/**< data has appeared for this server endpoint from a
	 * remote client, it can be found at *in and is
	 * len bytes long */

	CALLBACK_RECEIVE_PONG				=  7,
	/**< servers receive PONG packets with this callback reason */

	CALLBACK_WS_PEER_INITIATED_CLOSE			= 38,
	/**< The peer has sent an unsolicited Close WS packet.  in and
	 * len are the optional close code (first 2 bytes, network
	 * order) and the optional additional information which is not
	 * defined in the standard, and may be a string or non human-readable
	 * data.
	 * If you return 0 lws will echo the close and then close the
	 * connection.  If you return nonzero lws will just close the
	 * connection. */

	CALLBACK_FILTER_PROTOCOL_CONNECTION			= 20,
	/**< called when the handshake has
	 * been received and parsed from the client, but the response is
	 * not sent yet.  Return non-zero to disallow the connection.
	 * user is a pointer to the connection user space allocation,
	 * in is the requested protocol name
	 * In your handler you can use the public APIs
	 * lws_hdr_total_length() / lws_hdr_copy() to access all of the
	 * headers using the header enums lws_token_indexes from
	 * libwebsockets.h to check for and read the supported header
	 * presence and content before deciding to allow the handshake
	 * to proceed or to kill the connection. */

	CALLBACK_CONFIRM_EXTENSION_OKAY			= 25,
	/**< When the server handshake code
	 * sees that it does support a requested extension, before
	 * accepting the extension by additing to the list sent back to
	 * the client it gives this callback just to check that it's okay
	 * to use that extension.  It calls back to the requested protocol
	 * and with in being the extension name, len is 0 and user is
	 * valid.  Note though at this time the ESTABLISHED callback hasn't
	 * happened yet so if you initialize user content there, user
	 * content during this callback might not be useful for anything. */

	CALLBACK_WS_SERVER_BIND_PROTOCOL			= 77,
	CALLBACK_WS_SERVER_DROP_PROTOCOL			= 78,

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to Websocket Client -----
	 */

	CALLBACK_CLIENT_CONNECTION_ERROR			=  1,
	/**< the request client connection has been unable to complete a
	 * handshake with the remote server.  If in is non-NULL, you can
	 * find an error string of length len where it points to
	 *
	 * Diagnostic strings that may be returned include
	 *
	 *     	"getaddrinfo (ipv6) failed"
	 *     	"unknown address family"
	 *     	"getaddrinfo (ipv4) failed"
	 *     	"set socket opts failed"
	 *     	"insert wsi failed"
	 *     	"lws_ssl_client_connect1 failed"
	 *     	"lws_ssl_client_connect2 failed"
	 *     	"Peer hung up"
	 *     	"read failed"
	 *     	"HS: URI missing"
	 *     	"HS: Redirect code but no Location"
	 *     	"HS: URI did not parse"
	 *     	"HS: Redirect failed"
	 *     	"HS: Server did not return 200"
	 *     	"HS: OOM"
	 *     	"HS: disallowed by client filter"
	 *     	"HS: disallowed at ESTABLISHED"
	 *     	"HS: ACCEPT missing"
	 *     	"HS: ws upgrade response not 101"
	 *     	"HS: UPGRADE missing"
	 *     	"HS: Upgrade to something other than websocket"
	 *     	"HS: CONNECTION missing"
	 *     	"HS: UPGRADE malformed"
	 *     	"HS: PROTOCOL malformed"
	 *     	"HS: Cannot match protocol"
	 *     	"HS: EXT: list too big"
	 *     	"HS: EXT: failed setting defaults"
	 *     	"HS: EXT: failed parsing defaults"
	 *     	"HS: EXT: failed parsing options"
	 *     	"HS: EXT: Rejects server options"
	 *     	"HS: EXT: unknown ext"
	 *     	"HS: Accept hash wrong"
	 *     	"HS: Rejected by filter cb"
	 *     	"HS: OOM"
	 *     	"HS: SO_SNDBUF failed"
	 *     	"HS: Rejected at CLIENT_ESTABLISHED"
	 */

	CALLBACK_CLIENT_FILTER_PRE_ESTABLISH		=  2,
	/**< this is the last chance for the client user code to examine the
	 * http headers and decide to reject the connection.  If the
	 * content in the headers is interesting to the
	 * client (url, etc) it needs to copy it out at
	 * this point since it will be destroyed before
	 * the CLIENT_ESTABLISHED call */

	CALLBACK_CLIENT_ESTABLISHED				=  3,
	/**< after your client connection completed the websocket upgrade
	 * handshake with the remote server */

	CALLBACK_CLIENT_CLOSED				= 75,
	/**< when a client websocket session ends */

	CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER		= 24,
	/**< this callback happens
	 * when a client handshake is being compiled.  user is NULL,
	 * in is a char **, it's pointing to a char * which holds the
	 * next location in the header buffer where you can add
	 * headers, and len is the remaining space in the header buffer,
	 * which is typically some hundreds of bytes.  So, to add a canned
	 * cookie, your handler code might look similar to:
	 *
	 *	char **p = (char **)in, *end = (*p) + len;
	 *
	 *	if (lws_add_http_header_by_token(wsi, WSI_TOKEN_HTTP_COOKIE,
	 *			(unsigned char)"a=b", 3, p, end))
	 *		return -1;
	 *
	 * See CALLBACK_ADD_HEADERS for adding headers to server
	 * transactions.
	 */

	CALLBACK_CLIENT_RECEIVE				=  8,
	/**< data has appeared from the server for the client connection, it
	 * can be found at *in and is len bytes long */

	CALLBACK_CLIENT_RECEIVE_PONG			=  9,
	/**< clients receive PONG packets with this callback reason */

	CALLBACK_CLIENT_WRITEABLE				= 10,
	/**<  If you call lws_callback_on_writable() on a connection, you will
	 * get one of these callbacks coming when the connection socket
	 * is able to accept another write packet without blocking.
	 * If it already was able to take another packet without blocking,
	 * you'll get this callback at the next call to the service loop
	 * function.  Notice that CLIENTs get CALLBACK_CLIENT_WRITEABLE
	 * and servers get CALLBACK_SERVER_WRITEABLE. */

	CALLBACK_CLIENT_CONFIRM_EXTENSION_SUPPORTED		= 26,
	/**< When a ws client
	 * connection is being prepared to start a handshake to a server,
	 * each supported extension is checked with protocols[0] callback
	 * with this reason, giving the user code a chance to suppress the
	 * claim to support that extension by returning non-zero.  If
	 * unhandled, by default 0 will be returned and the extension
	 * support included in the header to the server.  Notice this
	 * callback comes to protocols[0]. */

	CALLBACK_WS_EXT_DEFAULTS				= 39,
	/**< Gives client connections an opportunity to adjust negotiated
	 * extension defaults.  `user` is the extension name that was
	 * negotiated (eg, "permessage-deflate").  `in` points to a
	 * buffer and `len` is the buffer size.  The user callback can
	 * set the buffer to a string describing options the extension
	 * should parse.  Or just ignore for defaults. */


	CALLBACK_FILTER_NETWORK_CONNECTION			= 17,
	/**< called when a client connects to
	 * the server at network level; the connection is accepted but then
	 * passed to this callback to decide whether to hang up immediately
	 * or not, based on the client IP.
	 *
	 * user_data in the callback points to a
	 * struct lws_filter_network_conn_args that is prepared with the
	 * sockfd, and the peer's address information.
	 *
	 * in contains the connection socket's descriptor.
	 *
	 * Since the client connection information is not available yet,
	 * wsi still pointing to the main server socket.
	 *
	 * Return non-zero to terminate the connection before sending or
	 * receiving anything. Because this happens immediately after the
	 * network connection from the client, there's no websocket protocol
	 * selected yet so this callback is issued only to protocol 0. */

	CALLBACK_WS_CLIENT_BIND_PROTOCOL			= 79,
	CALLBACK_WS_CLIENT_DROP_PROTOCOL			= 80,

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to external poll loop integration  -----
	 */

	CALLBACK_GET_THREAD_ID				= 31,
	/**< lws can accept callback when writable requests from other
	 * threads, if you implement this callback and return an opaque
	 * current thread ID integer. */

	/* external poll() management support */
	CALLBACK_ADD_POLL_FD				= 32,
	/**< lws normally deals with its poll() or other event loop
	 * internally, but in the case you are integrating with another
	 * server you will need to have lws sockets share a
	 * polling array with the other server.  This and the other
	 * POLL_FD related callbacks let you put your specialized
	 * poll array interface code in the callback for protocol 0, the
	 * first protocol you support, usually the HTTP protocol in the
	 * serving case.
	 * This callback happens when a socket needs to be
	 * added to the polling loop: in points to a struct
	 * lws_pollargs; the fd member of the struct is the file
	 * descriptor, and events contains the active events
	 *
	 * If you are using the internal lws polling / event loop
	 * you can just ignore these callbacks. */

	CALLBACK_DEL_POLL_FD				= 33,
	/**< This callback happens when a socket descriptor
	 * needs to be removed from an external polling array.  in is
	 * again the struct lws_pollargs containing the fd member
	 * to be removed.  If you are using the internal polling
	 * loop, you can just ignore it. */

	CALLBACK_CHANGE_MODE_POLL_FD			= 34,
	/**< This callback happens when lws wants to modify the events for
	 * a connection.
	 * in is the struct lws_pollargs with the fd to change.
	 * The new event mask is in events member and the old mask is in
	 * the prev_events member.
	 * If you are using the internal polling loop, you can just ignore
	 * it. */

	CALLBACK_LOCK_POLL					= 35,
	/**< These allow the external poll changes driven
	 * by lws to participate in an external thread locking
	 * scheme around the changes, so the whole thing is threadsafe.
	 * These are called around three activities in the library,
	 *	- inserting a new wsi in the wsi / fd table (len=1)
	 *	- deleting a wsi from the wsi / fd table (len=1)
	 *	- changing a wsi's POLLIN/OUT state (len=0)
	 * Locking and unlocking external synchronization objects when
	 * len == 1 allows external threads to be synchronized against
	 * wsi lifecycle changes if it acquires the same lock for the
	 * duration of wsi dereference from the other thread context. */

	CALLBACK_UNLOCK_POLL				= 36,
	/**< See CALLBACK_LOCK_POLL, ignore if using lws internal poll */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to CGI serving -----
	 */

	CALLBACK_CGI					= 40,
	/**< CGI: CGI IO events on stdin / out / err are sent here on
	 * protocols[0].  The provided `lws_callback_http_dummy()`
	 * handles this and the callback should be directed there if
	 * you use CGI. */

	CALLBACK_CGI_TERMINATED				= 41,
	/**< CGI: The related CGI process ended, this is called before
	 * the wsi is closed.  Used to, eg, terminate chunking.
	 * The provided `lws_callback_http_dummy()`
	 * handles this and the callback should be directed there if
	 * you use CGI.  The child PID that terminated is in len. */

	CALLBACK_CGI_STDIN_DATA				= 42,
	/**< CGI: Data is, to be sent to the CGI process stdin, eg from
	 * a POST body.  The provided `lws_callback_http_dummy()`
	 * handles this and the callback should be directed there if
	 * you use CGI. */

	CALLBACK_CGI_STDIN_COMPLETED			= 43,
	/**< CGI: no more stdin is coming.  The provided
	 * `lws_callback_http_dummy()` handles this and the callback
	 * should be directed there if you use CGI. */

	CALLBACK_CGI_PROCESS_ATTACH				= 70,
	/**< CGI: Sent when the CGI process is spawned for the wsi.  The
	 * len parameter is the PID of the child process */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to Generic Sessions -----
	 */

	CALLBACK_SESSION_INFO				= 54,
	/**< This is only generated by user code using generic sessions.
	 * It's used to get a `struct lws_session_info` filled in by
	 * generic sessions with information about the logged-in user.
	 * See the messageboard sample for an example of how to use. */

	CALLBACK_GS_EVENT					= 55,
	/**< Indicates an event happened to the Generic Sessions session.
	 * `in` contains a `struct lws_gs_event_args` describing the event. */

	CALLBACK_HTTP_PMO					= 56,
	/**< per-mount options for this connection, called before
	 * the normal CALLBACK_HTTP when the mount has per-mount
	 * options.
	 */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to RAW PROXY -----
	 */

	CALLBACK_RAW_PROXY_CLI_RX				= 89,
	/**< RAW mode client (outgoing) RX */

	CALLBACK_RAW_PROXY_SRV_RX				= 90,
	/**< RAW mode server (listening) RX */

	CALLBACK_RAW_PROXY_CLI_CLOSE			= 91,
	/**< RAW mode client (outgoing) is closing */

	CALLBACK_RAW_PROXY_SRV_CLOSE			= 92,
	/**< RAW mode server (listening) is closing */

	CALLBACK_RAW_PROXY_CLI_WRITEABLE			= 93,
	/**< RAW mode client (outgoing) may be written */

	CALLBACK_RAW_PROXY_SRV_WRITEABLE			= 94,
	/**< RAW mode server (listening) may be written */

	CALLBACK_RAW_PROXY_CLI_ADOPT			= 95,
	/**< RAW mode client (onward) accepted socket was adopted
	 *   (equivalent to 'wsi created') */

	CALLBACK_RAW_PROXY_SRV_ADOPT			= 96,
	/**< RAW mode server (listening) accepted socket was adopted
	 *   (equivalent to 'wsi created') */

	CALLBACK_RAW_PROXY_CLI_BIND_PROTOCOL		= 97,
	CALLBACK_RAW_PROXY_SRV_BIND_PROTOCOL		= 98,
	CALLBACK_RAW_PROXY_CLI_DROP_PROTOCOL		= 99,
	CALLBACK_RAW_PROXY_SRV_DROP_PROTOCOL		= 100,


	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to RAW sockets -----
	 */

	CALLBACK_RAW_RX					= 59,
	/**< RAW mode connection RX */

	CALLBACK_RAW_CLOSE					= 60,
	/**< RAW mode connection is closing */

	CALLBACK_RAW_WRITEABLE				= 61,
	/**< RAW mode connection may be written */

	CALLBACK_RAW_ADOPT					= 62,
	/**< RAW mode connection was adopted (equivalent to 'wsi created') */

	CALLBACK_RAW_CONNECTED				= 101,
	/**< outgoing client RAW mode connection was connected */

	CALLBACK_RAW_SKT_BIND_PROTOCOL			= 81,
	CALLBACK_RAW_SKT_DROP_PROTOCOL			= 82,

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to RAW file handles -----
	 */

	CALLBACK_RAW_ADOPT_FILE				= 63,
	/**< RAW mode file was adopted (equivalent to 'wsi created') */

	CALLBACK_RAW_RX_FILE				= 64,
	/**< This is the indication the RAW mode file has something to read.
	 *   This doesn't actually do the read of the file and len is always
	 *   0... your code should do the read having been informed there is
	 *   something to read now. */

	CALLBACK_RAW_WRITEABLE_FILE				= 65,
	/**< RAW mode file is writeable */

	CALLBACK_RAW_CLOSE_FILE				= 66,
	/**< RAW mode wsi that adopted a file is closing */

	CALLBACK_RAW_FILE_BIND_PROTOCOL			= 83,
	CALLBACK_RAW_FILE_DROP_PROTOCOL			= 84,

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to generic wsi events -----
	 */

	CALLBACK_TIMER					= 73,
	/**< When the time elapsed after a call to
	 * lws_set_timer_usecs(wsi, usecs) is up, the wsi will get one of
	 * these callbacks.  The deadline can be continuously extended into the
	 * future by later calls to lws_set_timer_usecs() before the deadline
	 * expires, or cancelled by lws_set_timer_usecs(wsi, -1);
	 */

	CALLBACK_EVENT_WAIT_CANCELLED			= 71,
	/**< This is sent to every protocol of every vhost in response
	 * to lws_cancel_service() or lws_cancel_service_pt().  This
	 * callback is serialized in the lws event loop normally, even
	 * if the lws_cancel_service[_pt]() call was from a different
	 * thread. */

	CALLBACK_CHILD_CLOSING				= 69,
	/**< Sent to parent to notify them a child is closing / being
	 * destroyed.  in is the child wsi.
	 */

	CALLBACK_CONNECTING					= 105,
	/**< Called before a socketfd is about to connect().  In is the
	 * socketfd, cast to a (void *), if on a platform where the socketfd
	 * is an int, recover portably using (lws_sockfd_type)(intptr_t)in.
	 *
	 * It's also called in SOCKS5 or http_proxy cases where the socketfd is
	 * going to try to connect to its proxy.
	 */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to TLS certificate management -----
	 */

	CALLBACK_VHOST_CERT_AGING				= 72,
	/**< When a vhost TLS cert has its expiry checked, this callback
	 * is broadcast to every protocol of every vhost in case the
	 * protocol wants to take some action with this information.
	 * \p in is a pointer to a struct lws_acme_cert_aging_args,
	 * and \p len is the number of days left before it expires, as
	 * a (ssize_t).  In the struct lws_acme_cert_aging_args, vh
	 * points to the vhost the cert aging information applies to,
	 * and element_overrides[] is an optional way to update information
	 * from the pvos... NULL in an index means use the information from
	 * from the pvo for the cert renewal, non-NULL in the array index
	 * means use that pointer instead for the index. */

	CALLBACK_VHOST_CERT_UPDATE				= 74,
	/**< When a vhost TLS cert is being updated, progress is
	 * reported to the vhost in question here, including completion
	 * and failure.  in points to optional JSON, and len represents the
	 * connection state using enum lws_cert_update_state */

	/* ---------------------------------------------------------------------
	 * ----- Callbacks related to MQTT Client  -----
	 */

	CALLBACK_MQTT_NEW_CLIENT_INSTANTIATED		= 200,
	CALLBACK_MQTT_IDLE					= 201,
	CALLBACK_MQTT_CLIENT_ESTABLISHED			= 202,
	CALLBACK_MQTT_SUBSCRIBED				= 203,
	CALLBACK_MQTT_CLIENT_WRITEABLE			= 204,
	CALLBACK_MQTT_CLIENT_RX				= 205,
	CALLBACK_MQTT_UNSUBSCRIBED				= 206,
	CALLBACK_MQTT_DROP_PROTOCOL				= 207,
	CALLBACK_MQTT_CLIENT_CLOSED				= 208,
	CALLBACK_MQTT_ACK					= 209,
	/**< When a message is fully sent, if QoS0 this callback is generated
	 * to locally "acknowledge" it.  For QoS1, this callback is only
	 * generated when the matching PUBACK is received.  Return nonzero to
	 * close the wsi.
	 */
	CALLBACK_MQTT_RESEND				= 210,
	/**< In QoS1 or QoS2, this callback is generated instead of the _ACK one
	 * if we timed out waiting for a PUBACK or a PUBREC, and we must resend
	 * the message.  Return nonzero to close the wsi.
	 */
	CALLBACK_MQTT_UNSUBSCRIBE_TIMEOUT			= 211,
	/**< When a UNSUBSCRIBE is sent, this callback is generated instead of
	 * the _UNSUBSCRIBED one if we timed out waiting for a UNSUBACK.
	 * Return nonzero to close the wsi.
	 */
	CALLBACK_MQTT_SHADOW_TIMEOUT			= 212,
	/**< When a Device Shadow is sent, this callback is generated if we
	 * timed out waiting for a response from AWS IoT.
	 * Return nonzero to close the wsi.
	 */

	/****** add new things just above ---^ ******/

	CALLBACK_USER = 1000,
	/**<  user code can use any including above without fear of clashes */
};

lws_callback_function :: #type proc "c" (wsi : lws_ptr, reason : lws_callback_reasons, user : rawptr, _in : rawptr, len : c.size_t);

lws_protocols :: struct {
	name : cstring,
	/**< Protocol name that must match the one given in the client
	 * Javascript new WebSocket(url, 'protocol') name. */
	
	callback : lws_callback_function,
	/**< The service callback used for this protocol.  It allows the
	 * service action for an entire protocol to be encapsulated in
	 * the protocol-specific callback */
	
	per_session_data_size : c.size_t,
	/**< Each new connection using this protocol gets
	 * this much memory allocated on connection establishment and
	 * freed on connection takedown.  A pointer to this per-connection
	 * allocation is passed into the callback in the 'user' parameter */
	
	rx_buffer_size : c.size_t,
	/**< lws allocates this much space for rx data and informs callback
	 * when something came.  Due to rx flow control, the callback may not
	 * be able to consume it all without having to return to the event
	 * loop.  That is supported in lws.
	 *
	 * If .tx_packet_size is 0, this also controls how much may be sent at
	 * once for backwards compatibility.
	 */
	
	id : c.uint, //unsigned int
	/**< ignored by lws, but useful to contain user information bound
	 * to the selected protocol.  For example if this protocol was
	 * called "myprotocol-v2", you might set id to 2, and the user
	 * code that acts differently according to the version can do so by
	 * switch (wsi->a.protocol->id), user code might use some bits as
	 * capability flags based on selected protocol version, etc. */
	
	user : rawptr, /**< ignored by lws, but user code can pass a pointer
	here it can later access from the protocol callback */
	
	tx_packet_size : c.size_t,
	/**< 0 indicates restrict send() size to .rx_buffer_size for backwards-
	 * compatibility.
	 * If greater than zero, a single send() is restricted to this amount
	 * and any remainder is buffered by lws and sent afterwards also in
	 * these size chunks.  Since that is expensive, it's preferable
	 * to restrict one fragment you are trying to send to match this
	 * size.
	 */

	/* Add new things just above here ---^
	 * This is part of the ABI, don't needlessly break compatibility */
};
