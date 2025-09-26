package furbs_network_server_chat_example

import lws "../../../libwebsockets"
import "core:c"
import "core:strings"
import "core:time"
import "core:sync"
import "core:thread"
import "core:log"
import "core:slice"
import "core:container/queue"

LWS_PRE :: 16 // from earlier discussion; x86_64 => 16

// Per-session data
Per_session_data :: struct {
	pss_list: ^Per_session_data, // forward list link
	wsi:      lws.Lws,
	pending:  queue.Queue([]u8), // per-client buffer (each entry includes LWS_PRE headroom)
}

// Per-vhost data
Per_vhost_data :: struct {
	ctx:      lws.Context,
	protocol: [^]lws.Protocols,
	pss_list: ^Per_session_data, // list head

	lock:     sync.Mutex,
	finished: bool,
}

// --- small helpers ---
insert_pss_front :: proc (pss: ^Per_session_data, head: ^^Per_session_data) {
	pss.pss_list = head^
	head^ = pss
}

remove_pss :: proc (pss: ^Per_session_data, head: ^^Per_session_data) {
	prev : ^Per_session_data = nil
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
callback_minimal :: proc "c" (wsi : lws.Lws, reason : lws.Callback_reasons, user   : rawptr, input  : rawptr, in_len : c.size_t) -> c.int {
	
	pss := cast(^Per_session_data) user

	// get (or create) per-vhost storage
	vhd := cast(^Per_vhost_data)lws.protocol_vh_priv_get(lws.get_vhost(wsi), lws.get_protocol(wsi))

	_ = input
	_ = in_len

	#partial switch reason {
		case .LWS_CALLBACK_PROTOCOL_INIT: {
			vhd = cast(^Per_vhost_data)lws.protocol_vh_priv_zalloc(lws.get_vhost(wsi), lws.get_protocol(wsi), size_of(Per_vhost_data))
			if vhd == nil do return 1

			vhd.ctx      = lws.get_context(wsi)
			vhd.protocol = lws.get_protocol(wsi)
		}

		case .LWS_CALLBACK_PROTOCOL_DESTROY: {
			if vhd != nil {
				// drain & free any per-session queues before destroying the lock
				sync.mutex_lock(&vhd.lock)
				it := vhd.pss_list
				for it != nil {
					// pop and free any remaining messages
					for queue.len(&it.pending) > 0 {
						m := queue.pop(&it.pending)
						delete(m)
					}
					queue.destroy(&it.pending)
					it = it.pss_list
				}
				sync.mutex_unlock(&vhd.lock)

				sync.mutex_destroy(&vhd.lock)
			}
		}

		case .LWS_CALLBACK_ESTABLISHED: {
			sync.mutex_lock(&vhd.lock)
			insert_pss_front(pss, &vhd.pss_list)
			queue.init(&pss.pending)
			pss.wsi = wsi
			sync.mutex_unlock(&vhd.lock)
		}

		case .LWS_CALLBACK_CLOSED: {
			sync.mutex_lock(&vhd.lock)
			// drain and destroy this session's queue
			for queue.count(&pss.pending) > 0 {
				m := queue.pop(&pss.pending)
				delete(m)
			}
			queue.destroy(&pss.pending)

			remove_pss(pss, &vhd.pss_list)
			sync.mutex_unlock(&vhd.lock)
		}

		case .LWS_CALLBACK_SERVER_WRITEABLE: {
			sync.mutex_lock(&vhd.lock)

			if queue.count(&pss.pending) > 0 {
				m := queue.pop(&pss.pending)

				payload_len := cast(int)(len(m) - LWS_PRE)
				if payload_len > 0 {
					w := lws.write(wsi, &m[LWS_PRE], cast(c.size_t)payload_len, lws.LWS_WRITE_TEXT)
					if w < payload_len {
						sync.mutex_unlock(&vhd.lock)
						lws.lwsl_err("write failed %d\n", w)
						delete(m)
						return -1
					}
				}

				delete(m)

				// If more are queued, ask to be writable again
				if queue.count(&pss.pending) > 0 {
					lws.callback_on_writable(pss.wsi)
				}
			}

			sync.mutex_unlock(&vhd.lock)
		}

		case .LWS_CALLBACK_RECEIVE: {
			// nothing to buffer from receive in this minimal echo; just request writable
			lws.callback_on_writable(wsi)
		}

		case .LWS_CALLBACK_EVENT_WAIT_CANCELLED: {
			// app thread queued data; make all clients writable
			if vhd != nil {
				it := vhd.pss_list
				for it != nil {
					lws.callback_on_writable(it.wsi)
					it = it.pss_list
				}
			}
		}

		case: {
			// ignore
		}
	}

	return 0
}
Page_struct :: distinct struct{};
// ---- protocols table ----
protocols := [?]lws.Protocols {
	lws.Protocols{
		name                  = "lws-minimal",
		callback              = callback_minimal,
		per_session_data_size = size_of(Per_session_data),
		rx_buffer_size        = 128,
	},
	lws.Protocols{}, // terminator
}

// ---- termination flag + signal ----
interrupted: bool

sigint_handler :: proc (sig: c.int) {
	_ = sig
	interrupted = true
}

service_thread : thread.Thread_Proc : proc (t : ^thread.Thread) {
	for !interrupted {
		assert(lws.service(auto_cast t.user_args[0], 0) == 0, "service failed");
	}
}

// ---- main ----
main :: proc() -> c.int {
	
	info   : lws.Context_creation_info
	info.port      = 7681
	info.protocols = &protocols[0]
	info.options   = 0
	
	ctx := lws.create_context(&info)
	if ctx == nil {
		log.errorf("lws init failed\n")
		return 1
	}

	// start lws service in its own thread
	t := thread.create(service_thread);
	t.user_args[0] = ctx;
	thread.start(t);
	
	// ---- app loop in main thread: heartbeat every 100ms ----
	vhd := cast(^Per_vhost_data)lws.protocol_vh_priv_get(lws.get_vhost_by_name(ctx, "default"), &protocols[0])

	counter: u64 = 0
	for !interrupted {
		assert(vhd != nil);

		// build a message with headroom
		builder : strings.Builder;
		strings.builder_init_len(&builder, LWS_PRE);
		defer strings.builder_destroy(&builder);

		strings.write_string(&builder, "heartbeat ");
		strings.write_u64(&builder, counter);
		counter += 1
		msg := strings.to_string(builder);

		// broadcast: copy into each session's queue
		sync.mutex_lock(&vhd.lock); {
			it := vhd.pss_list;
			assert(it != nil);
			queue.append_elem(&it.pending, slice.clone(transmute([]u8)(msg)))
			lws.callback_on_writable(it.wsi)
			it = it.pss_list
		} sync.mutex_unlock(&vhd.lock);

		time.sleep(100 * time.Millisecond)
	}

	thread.join(t)
	lws.context_destroy(ctx)

	return 0
}
