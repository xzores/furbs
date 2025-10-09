package furbs_network_tests

import "core:debug/pe"
import "core:log"
import "core:fmt"
import "core:mem"
import "core:testing"
import "core:time"
import "core:sync"
import "core:thread"

import "../tcp"
import network ".."

import "../../utils" 

main :: proc () {
	
	my_logger = utils.create_console_logger(.Debug);
	context.logger = my_logger;
	defer utils.destroy_console_logger(my_logger);
	
	when ODIN_DEBUG {
		context.assertion_failure_proc = utils.init_stack_trace();
		defer utils.destroy_stack_trace();
		
		utils.init_tracking_allocators();
		
		{
			tracker : ^mem.Tracking_Allocator;
			my_alloc = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,
			context.allocator = my_alloc;
			
			test_main();
		}
		
		utils.print_tracking_memory_results();
		utils.destroy_tracking_allocators();
	}
	else {
		test_main();
	}
}

//This test starts a server in a new thread, send some commands between the server and client and closes the server and client.
//It creates 10 clients 1 at a time
//@test 
//tcp_test :: proc (t : ^testing.T) {

test_main :: proc () {
	
	address :: "127.0.0.1:8139";

	bin_server := get_server_func(address, true);
	json_server := get_server_func(address, false);

	bs := []bool{false}
	for b in bs {
		///////////////////////////////////////////////
		
		tcp.init(context.allocator, context.logger);
		defer tcp.destroy();
		
		for  i : int = 0; i < 5; i += 1 {
			
			should_close_server = false;

			//For testing we start a new thread for scraping commands from the client.
			server_thread := thread.create(b ? bin_server : json_server);
			thread.start(server_thread);
			
			time.sleep(20 * time.Millisecond);
			
			for j: int = 0; j < 5; j += 1 {

				/////////// Client ///////////
				client := network.client_create(tcp.client_interface(commands_map, address, .ipv4_only, b));

				assert(network.client_connect(client) == nil, "failed to connect?");

				// Connected
				{
					tmoutcon := network.client_wait_for_event(client);
					assert(!tmoutcon, "connection timeout...")
					network.begin_handle_events(client)
					defer network.end_handle_events(client)
					econ, _ := network.get_next_event(client)
					_, okcon := econ.type.(network.Event_connected)
					assert(okcon)
				}

				// Hello echo 1
				{
					assert(network.client_send(client, Hello{}) == nil)
					tmout1 := network.client_wait_for_event(client)
					assert(!tmout1)
					network.begin_handle_events(client)
					defer network.end_handle_events(client)

					e1, _ := network.get_next_event(client)
					msg1, ok1 := e1.type.(network.Event_msg)
					assert(ok1)

					_, okv1 := msg1.value.(Hello_from_server)
					assert(okv1)
				}

				// Hello echo 2
				{
					tmout2 := network.client_wait_for_event(client)
					assert(!tmout2)
					network.begin_handle_events(client)
					defer network.end_handle_events(client)

					e2, _ := network.get_next_event(client)
					msg2, ok2 := e2.type.(network.Event_msg)
					assert(ok2)

					_, okv2 := msg2.value.(Hello_from_server)
					assert(okv2)
				}

				// Hello echo 3
				{
					tmout3 := network.client_wait_for_event(client)
					assert(!tmout3)
					network.begin_handle_events(client)
					defer network.end_handle_events(client)

					e3, _ := network.get_next_event(client)
					msg3, ok3 := e3.type.(network.Event_msg)
					assert(ok3)

					_, okv3 := msg3.value.(Hello_from_server)
					assert(okv3)
				}

				// Batch chat sends
				assert(network.client_send(client, Chat_message{"Yoyoyo this is client calling! 1"}) == nil)
				assert(network.client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 2"}) == nil)
				assert(network.client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 3"}) == nil)
				assert(network.client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 4"}) == nil)
				assert(network.client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 5"}) == nil)
				assert(network.client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 6"}) == nil)

				// Version check round-trip
				assert(network.client_send(client, Version_check{1, 2, 3}) == nil)
				{
					tmoute := network.client_wait_for_event(client)
					assert(!tmoute)
					network.begin_handle_events(client)
					defer network.end_handle_events(client)

					ee, _ := network.get_next_event(client)
					msge, oke := ee.type.(network.Event_msg)
					assert(oke)

					ver_passed, okvp := msge.value.(Version_check_passed)
					assert(okvp)
					assert(ver_passed.was_passed == true)
				}

				// Disconnect flows
				if i %% 2 == 0 || true { // keep your original condition
					// Client-initiated disconnect
					assert(network.client_disconnect(client) == nil)
					{
						tmdis := network.client_wait_for_event(client)
						assert(!tmdis)
						network.begin_handle_events(client)
						defer network.end_handle_events(client)

						ed, _ := network.get_next_event(client)
						_, okd := ed.type.(network.Event_disconnected)
						assert(okd)
					}
				} else {
					// Server-initiated disconnect
					log.warn("asking server to disconnect me")
					assert(network.client_send(client, Disconnect_me{}) == nil)
					{
						tmdce := network.client_wait_for_event(client)
						assert(!tmdce)
						network.begin_handle_events(client)
						defer network.end_handle_events(client)

						disconnect_event, _ := network.get_next_event(client)
						_, ok := disconnect_event.type.(network.Event_disconnected)
						assert(ok)
					}

					// Close locally as well (if you still want to mirror the old flow)
					assert(network.client_disconnect(client) == nil)
					{
						tmdis := network.client_wait_for_event(client)
						assert(!tmdis)
						network.begin_handle_events(client)
						defer network.end_handle_events(client)

						ed, _ := network.get_next_event(client)
						_, okd := ed.type.(network.Event_disconnected)
						assert(okd)
					}
				}

				network.client_destroy(client);
			}
			
			/////////// Closure ///////////
			time.sleep(100 * time.Millisecond);
			should_close_server = true;
			log.infof("should_close_server is set to true and we are waiting for the server to end.");
			thread.destroy(server_thread); //also joins
			
			fmt.printf("\n\n ENDING \n\n");
			time.sleep(1 * time.Millisecond);
		}
	}
}
