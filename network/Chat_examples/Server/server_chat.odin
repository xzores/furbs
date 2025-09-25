package furbs_network_server_chat_example

import lws "../../../libwebsockets"
import "core:c"
import "core:strings"
import "core:time"
import "core:sync"
import "core:thread"

LWS_PRE :: lws.LWS_PRE

// Per-session data
per_session_data__minimal :: struct {
	pss_list: ^per_session_data__minimal, // forward list link
	wsi:	  lws.Lws,
	tail:	 c.uint32_t,
}

// Per-vhost data
per_vhost_data__minimal :: struct {
	ctx:	   lws.Context,
	protocol:  [^]lws.Protocols,
	pss_list:  ^per_session_data__minimal, // list head
	lock_ring: sync.Mutex,
	ring:	  lws.Ring,
	finished:  bool,
}

// --- helpers ---
__destroy_msg :: proc (m: ^([]u8)) {
	if m == nil do return
	// the slice memory was created with make([]u8, ...); delete will free it
	delete(m^)
	m^ = nil
}

insert_pss_front :: proc (pss: ^per_session_data__minimal, head: ^^per_session_data__minimal) {
	pss.pss_list = head^
	head^ = pss
}

remove_pss :: proc (pss: ^per_session_data__minimal, head: ^^per_session_data__minimal) {
	prev : ^per_session_data__minimal = nil
	cur  := head^
	for cur != nil {
		if cur == pss {
			if prev == nil {
				head^ = cur.pss_list
			} else {
				prev.pss_list = cur.pss_list
			}
			cur.pss_list = nil
			return
		}
		prev = cur
		cur  = cur.pss_list
	}
}
	
// ---- lws protocol callback ----
callback_minimal :: proc(
	wsi:	lws.Lws,
	reason: lws.Callback_reasons,
	user:   rawptr,
	input:  rawptr,
	in_len: c.size_t,
) -> c.int {
	pss := cast(^per_session_data__minimal) user

	vhd := cast(^per_vhost_data__minimal)lws.protocol_vh_priv_get(lws.get_vhost(wsi), lws.get_protocol(wsi))

	pmsg: ^([]u8)
	r:	c.int = 0

	_ = input
	_ = in_len

	switch reason {
		case lws.LWS_CALLBACK_PROTOCOL_INIT: {
			vhd = cast(^per_vhost_data__minimal)lws.lws_protocol_vh_priv_zalloc(lws.lws_get_vhost(wsi), lws.lws_get_protocol(wsi), c.sizeof(per_vhost_data__minimal))
			if vhd == nil {
				return 1
			}

			sync.mutex_init(&vhd.lock_ring)
			vhd.ctx	  = lws.lws_get_context(wsi)
			vhd.protocol = lws.lws_get_protocol(wsi)

			vhd.ring = lws.lws_ring_create(c.sizeof([]u8), 32, proc (data: rawptr) {
				__destroy_msg(cast(^([]u8)) data)
			})
			if vhd.ring == nil {
				lws.lwsl_err("%s: ring create failed\n", c.__func__)
				return 1
			}
		}
		case lws.LWS_CALLBACK_PROTOCOL_DESTROY: {
			if vhd != nil {
				if vhd.ring != nil {
					lws.lws_ring_destroy(vhd.ring)
					vhd.ring = nil
				}
				sync.mutex_destroy(&vhd.lock_ring)
			}
		}
		case lws.LWS_CALLBACK_ESTABLISHED: {
			insert_pss_front(pss, &vhd.pss_list)
			pss.tail = lws.lws_ring_get_oldest_tail(vhd.ring)
			pss.wsi  = wsi
		}
		case lws.LWS_CALLBACK_CLOSED: {
			remove_pss(pss, &vhd.pss_list)
		}
		case lws.LWS_CALLBACK_SERVER_WRITEABLE:{
			sync.mutex_lock(&vhd.lock_ring)

			pmsg = cast(^([]u8)) lws.lws_ring_get_element(vhd.ring, &pss->tail)
			if pmsg == nil {
				sync.mutex_unlock(&vhd.lock_ring)
				break
			}

			payload_len := cast(int)(len(pmsg^) - LWS_PRE)
			if payload_len > 0 {
				// write from the payload area after LWS_PRE
				m := lws.lws_write(
					wsi,
					&pmsg^[LWS_PRE],
					cast(c.size_t) payload_len,
					lws.LWS_WRITE_TEXT,
				)
				if m < payload_len {
					sync.mutex_unlock(&vhd.lock_ring)
					lws.lwsl_err("write failed %d\n", m)
					return -1
				}
			}

			lws.lws_ring_consume_and_update_oldest_tail(
				vhd.ring,
				per_session_data__minimal,
				&pss.tail,
				1,
				vhd.pss_list,
				tail,
				pss_list,
			)

			if lws.lws_ring_get_element(vhd.ring, &pss.tail) != nil {
				lws.lws_callback_on_writable(pss.wsi)
			}

			sync.mutex_unlock(&vhd.lock_ring)
		}
		case lws.LWS_CALLBACK_RECEIVE: {
			// request writable; app thread will have queued data
			lws.lws_callback_on_writable(wsi)
		}
		case lws.LWS_CALLBACK_EVENT_WAIT_CANCELLED: {
			if vhd != nil {
				it := vhd.pss_list
				for it != nil {
					lws.lws_callback_on_writable(it.wsi)
					it = it.pss_list
				}
			}
		}
		case: {
			// ignore others in this minimal example
			log.warnf("unhandled event : %v", reason);
		}
	}

	return r
}

// ---- protocols table ----
protocols := [?]lws.Protocols {
	lws.Protocols{
		name				  = "lws-minimal",
		callback			  = callback_minimal,
		per_session_data_size = c.sizeof(per_session_data__minimal),
		rx_buffer_size		= 128,
	},
	lws.Protocols{}, // terminator
}

// ---- termination flag + signal ----
interrupted: bool;

sigint_handler :: proc (sig: c.int) {
	_ = sig
	interrupted = true
}

// ---- service thread ----
service_args :: struct { ctx: lws.Context };

service_thread :: proc (a: ^service_args) {
	
	for !interrupted {
		assert(lws.service(a.ctx, 0) == 0);
	};

}

// ---- main ----
main :: proc() -> c.int {
	info	: lws.lws_context_creation_info
	ctx : lws.Context
	sargs   : service_args
	svc_th  : thread.Thread

	logs: c.int = lws.LLL_USER | lws.LLL_ERR | lws.LLL_WARN | lws.LLL_NOTICE

	// SIGINT handler
	c.signal(c.SIGINT, sigint_handler)

	// optional -d <level>
	p := lws.lws_cmdline_option(c.__argc, c.__argv, "-d")
	if p != nil {
		logs = strings.atoi(p)
	}
	lws.lws_set_log_level(logs, nil)

	// zero & fill info
	c.memset(&info, 0, c.sizeof(info))
	info.port	  = 7681
	info.protocols = &protocols[0] // WS only, no HTTP
	info.options   = 0

	ctx = lws.lws_create_context(&info)
	if ctx == nil {
		lws.lwsl_err("lws init failed\n")
		return 1
	}

	// start lws service in its own thread
	sargs.ctx = ctx
	svc_th = thread.spawn(service_thread, &sargs)

	// ---- app loop in main thread ----
	vhd := cast(^per_vhost_data__minimal)lws.lws_protocol_vh_priv_get(lws.lws_get_vhost_by_name(ctx, "default"), &protocols[0])

	counter: u32 = 0
	for !interrupted {
		if vhd != nil && vhd.ring != nil {
			sync.mutex_lock(&vhd.lock_ring)

			if lws.lws_ring_get_count_free_elements(vhd.ring) > 0 {
				max := 128

				// allocate (LWS_PRE + max) bytes; slice includes headroom
				msg := make([]u8, LWS_PRE + max)

				// write payload after headroom
				written := lws.lws_snprintf(
					&msg[LWS_PRE],
					max,
					"heartbeat %u",
					counter,
				)
				counter += 1

				// shrink slice length to exactly headroom + payload
				msg = msg[:LWS_PRE + cast(int)written]

				n := lws.lws_ring_insert(vhd.ring, &msg, 1)
				if n != 1 {
					__destroy_msg(&msg)
				} else {
					// wake service thread
					lws.lws_cancel_service(ctx)
				}
			}

			sync.mutex_unlock(&vhd.lock_ring)
		}

		time.sleep(100 * time.millisecond)
	}

	thread.join(&svc_th)
	lws.lws_context_destroy(ctx)
	return 0
}
