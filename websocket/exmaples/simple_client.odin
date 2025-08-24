package lws_simple_client;

import lws "../libwebsockets"
import "core:c"
import "core:time"
import "core:fmt"
import "core:math/rand"

web_socket : lws.lws_ptr = nil;

EXAMPLE_TX_BUFFER_BYTES :: 10

callback_example :: proc (wsi : lws.lws_ptr, reason : lws.lws_callback_reasons, user : rawptr, _in : rawptr, len : c.size_t) -> c.int
{
	switch reason {
		case .CALLBACK_CLIENT_ESTABLISHED: {
			lws.callback_on_writable(wsi);
		}
		case .CALLBACK_CLIENT_RECEIVE: {
			/* Handle incomming messages here. */
		}
		case .CALLBACK_CLIENT_WRITEABLE:
		{
			buf : [lws.SEND_BUFFER_PRE_PADDING + EXAMPLE_TX_BUFFER_BYTES + lws.SEND_BUFFER_POST_PADDING]u8;
			p :  [^]u8 = &buf[lws.SEND_BUFFER_PRE_PADDING];

			// Write a random number as a string to the buffer
			n : c.size_t = fmt.buf_print(p, "%d", rand.uint32()); // returns the number of bytes written
			
			lws.lws_write(wsi, p, n, .WRITE_TEXT);
		}
		case .CALLBACK_CLIENT_CLOSED:  {

		}
		case .CALLBACK_CLIENT_CONNECTION_ERROR:  {
			web_socket = nil;
		}
		case: {
			unreachable();
		}
	}
	
	return 0;
}

/*
WHAT IS THIS??
protocols :: enum u32 {
	PROTOCOL_EXAMPLE = 0,
	PROTOCOL_COUNT
};
*/

protocols := [?]lws.protocols {
    {
        .name                  = "example-protocol", /* Protocol name*/
        .callback              = callback_example,   /* Protocol callback */
        .per_session_data_size = 0,                  /* Protocol callback 'userdata' size */
        .rx_buffer_size        = 0,                  /* Receve buffer size (0 = no restriction) */
        .id                    = 0,                  /* Protocol Id (version) (optional) */
        .user                  = NULL,               /* 'User data' ptr, to access in 'protocol callback */
        .tx_packet_size        = 0                   /* Transmission buffer size restriction (0 = no restriction) */
    },
    LWS_PROTOCOL_LIST_TERM /* terminator */
};

main :: proc() { //int argc, char *argv[]
	
	info : lws.context_creation_info = {};

	info.port = lws.CONTEXT_PORT_NO_LISTEN; /* we do not run any server */
	info.protocols = protocols;
	info.gid = -1;
	info.uid = -1;
	
	lws_context : ^lws.lws_context = lws.create_context( &info );
	
	old : time.Time = {};
	for true {
		tv : time.Time = time.now();
		
		/* Connect if we are not connected to the server. */
		if !web_socket {  //  && tv_sec != old
			ccinfo : lws_client_connect_info = {};
			
			//ccinfo.context = lws_context;
			ccinfo.address = "localhost";
			ccinfo.port = 8000;
			ccinfo.path = "/";
			ccinfo.host = lws.canonical_hostname( lws_context );
			ccinfo.origin = "origin";
			ccinfo.protocol = protocols[PROTOCOL_EXAMPLE].name;
			
			web_socket = lws.client_connect_via_info(&ccinfo);
		}

		if( tv.tv_sec != old )
		{
			/* Send a random number to the server every second. */
			lws.callback_on_writable( web_socket );
			old = tv.tv_sec;
		}

		lws.service( lws_context, /* timeout_ms = */ 250 ); /* NOTE: since v3.2, timeout_ms may be set to '0', since it internally ignored */
	}

	lws.context_destroy( lws_context );
}