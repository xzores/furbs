#+feature dynamic-literals
package furbs_network

import "core:debug/pe"
import "core:log"
import "core:fmt"
import "core:mem"
import "core:testing"
import "core:time"
import "core:sync"
import "core:thread"

import "core:container/queue"
import "../utils"

/*
my_logger : log.Logger;
my_alloc : mem.Allocator;
should_close_server : bool;

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

Default_game_port : int = 26604;
Default_game_ip := IP4_Loopback; //TODO should we use net.Address_Family.IP4

//This test starts a server in a new thread, send some commands between the server and client and closes the server and client.
//It creates 10 clients 1 at a time
//@test test_main :: proc (t : ^testing.T) {
test_main :: proc () {
	
	///////////////////////////////////////////////

	for  i : int = 0; i < 5; i += 1 {
		
		should_close_server = false;

		//For testing we start a new thread for scraping commands from the client.
		server_thread := thread.create(server_handle_func);
		thread.start(server_thread);
		
		for j: int = 0; j < 5; j += 1 {
			/////////// Client ///////////
			client := client_create(commands_map)

			assert(client_connect(client, Endpoint{Default_game_ip, Default_game_port}, context.logger, context.allocator) == nil)

			// Connected
			{
				tmoutcon := client_wait_for_event(client)
				assert(!tmoutcon)
				begin_handle_events(client)
				defer end_handle_events(client)
				econ, _ := get_next_event(client)
				_, okcon := econ.type.(Event_connected)
				assert(okcon)
			}

			// Hello echo 1
			{
				assert(client_send(client, Hello{}) == nil)
				tmout1 := client_wait_for_event(client)
				assert(!tmout1)
				begin_handle_events(client)
				defer end_handle_events(client)
				e1, _ := get_next_event(client)
				msg1, ok1 := e1.type.(Event_msg)
				assert(ok1)
				assert(msg1.commad.value.id == Hello_from_server)
			}

			// Hello echo 2
			{
				tmout2 := client_wait_for_event(client)
				assert(!tmout2)
				begin_handle_events(client)
				defer end_handle_events(client)
				e2, _ := get_next_event(client)
				msg2, ok2 := e2.type.(Event_msg)
				assert(ok2)
				assert(msg2.commad.value.id == Hello_from_server)
			}

			// Hello echo 3
			{
				tmout3 := client_wait_for_event(client)
				assert(!tmout3)
				begin_handle_events(client)
				defer end_handle_events(client)
				e3, _ := get_next_event(client)
				msg3, ok3 := e3.type.(Event_msg)
				assert(ok3)
				assert(msg3.commad.value.id == Hello_from_server)
			}

			// Short-timeout probe (expect timeout, no handling)
			{
				tmtest := client_wait_for_event(client, 10 * time.Millisecond)
				assert(tmtest)
			}

			// Batch chat sends
			assert(client_send(client, Chat_message{"Yoyoyo this is client calling! 1"}) == nil)
			assert(client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 2"}) == nil)
			assert(client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 3"}) == nil)
			assert(client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 4"}) == nil)
			assert(client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 5"}) == nil)
			assert(client_send(client, Chat_message{"Yoyoyo what is up server, this is client calling! 6"}) == nil)

			// Version check round-trip
			assert(client_send(client, Version_check{1,2,3}) == nil)
			{
				tmoute := client_wait_for_event(client)
				assert(!tmoute)
				begin_handle_events(client)
				defer end_handle_events(client)
				ee, _ := get_next_event(client)
				msge, oke := ee.type.(Event_msg)
				assert(oke)
				fmt.assertf(msge.commad.value.id == Version_check_passed, "did not recive a version check passed : %v", msge.commad.value.id)
				ver_passed, okvp := msge.commad.value.(Version_check_passed)
				assert(okvp)
				assert(ver_passed.was_passed == true)
			}

			// Disconnect flows
			if i %% 2 == 0 || true { // TODO keep your original condition
				// Client-initiated disconnect
				assert(client_disconnect(client) == nil)
				{
					tmdis := client_wait_for_event(client)
					assert(!tmdis)
					begin_handle_events(client)
					defer end_handle_events(client)
					ed, _ := get_next_event(client)
					_, oke := ed.type.(Event_disconnected)
					assert(oke)
				}
			} else {
				// Server-initiated disconnect
				log.warn("asking server to disconnect me")
				assert(client_send(client, Disconnect_me{}) == nil)
				{
					tmdce := client_wait_for_event(client)
					assert(!tmdce)
					begin_handle_events(client)
					defer end_handle_events(client)
					disconnect_event, _ := get_next_event(client)
					_, ok := disconnect_event.type.(Event_disconnected)
					assert(ok)
				}

				// Close locally as well (per your TODO notes)
				assert(client_disconnect(client) == nil)
				{
					tmdis := client_wait_for_event(client)
					assert(!tmdis)
					begin_handle_events(client)
					defer end_handle_events(client)
					ed, _ := get_next_event(client)
					_, oke := ed.type.(Event_disconnected)
					assert(oke)
				}
			}
		}
		
		/////////// Closure ///////////
		should_close_server = true;
		thread.destroy(server_thread); //also joins
		
		fmt.printf("\n\n ENDING \n\n");
		time.sleep(1 * time.Millisecond);
	}
	
}




Hello :: struct {};

Hello_from_server :: struct {};

Version_check :: struct {
	major_version : u16,
	minor_version : u16,
	patch : u16,
};

Version_check_passed :: struct { was_passed : bool };

Chat_message :: struct { 
	text : string,
};

Disconnect_me :: struct{};

commands_map : map[Message_id_type]typeid = {
	
	//random number to make it less likely a wrong connection will be accepted.
	14732 = Hello,
	42034 = Hello_from_server,

	//We start initiliztion stuff from id 100 and up
	100 = Version_check,
	101 = Version_check_passed,

	200 = Chat_message,

	500 = Disconnect_me,
}


server_handle_func : thread.Thread_Proc : proc(t : ^thread.Thread) {
	context.logger = my_logger;
	context.allocator = my_alloc;

	/////////// Server ///////////
	server : ^Server = server_create(commands_map, {Default_game_ip, Default_game_port});
	server_start_accepting(server, context.logger, context.allocator);
	
	log.debugf("server handle thread open"); 

	connected_clients : map[^Server_side_client]struct{};
	defer delete(connected_clients);

	server_handle_events :: proc (server : ^Server, connected_clients : ^map[^Server_side_client]struct{}) {

		server_begin_handle_events(server);
			
			e, done := server_get_next_event(server);
			for !done {
				defer e, done = server_get_next_event(server); //happens last, so for the next one
				assert(e.type != nil);
				
				client : ^Server_side_client = cast(^Server_side_client)e.user_data;
				
				#partial switch event in e.type {
					case Event_connected: {
						log.infof("connected client");
						connected_clients[client] = {};
					}
					case Event_msg: {
						switch msg in event.commad.value {
							case Hello: {
								assert(server_send(server, client, Hello_from_server{}) == nil);
								assert(server_send(server, client, Hello_from_server{}) == nil);
								assert(server_send(server, client, Hello_from_server{}) == nil);
							}
							case Version_check: {
								assert(msg.major_version 	== 1);
								assert(msg.minor_version 	== 2);
								assert(msg.patch 			== 3);
								assert(server_send(server, client, Version_check_passed{true}) == nil);
							}
							case Chat_message: {
								log.info("recived chat message from client");
							}
							case Disconnect_me: {
								log.info("Client asked to be disconnected, doint that now");
								server_disconnect_client(server, client.id);
							}
							case: {
								unreachable()
							}
						}
					}
					case Event_disconnected: {
						log.infof("disconnected client");
						delete_key(connected_clients, client);
					}
					case: {
						panic("TODO Event is not Event_msg");
					}
				}
			}

		server_end_handle_events(server);
	}

	for !should_close_server {
		server_handle_events(server, &connected_clients);
		time.sleep(1 * time.Millisecond);
	}

	assert(server_close(server) == nil);

	for len(connected_clients) != 0 {
		server_handle_events(server, &connected_clients);
		time.sleep(1 * time.Millisecond);
	}

	server_destroy(server);

	assert(len(connected_clients) == 0);
}






/* 
//Very simple setup, minimal code example
//This might failed as we try to conenct to the server before it is garentied to be created...
@test
server_and_client_test :: proc (t : ^testing.T) {

	endpoint    := net.Endpoint{net.IP4_Loopback, default_game_port};
	acceptor_socket, err := net.listen_tcp(endpoint); //TODO Receive_Timeout can be used to set a timeout for accpeting...

	defer net.close(acceptor_socket);

	if err != nil {
		fmt.printf("Failed to make a UDP socket, error:", err);
		panic("Unable to bind to port");
	}

	fmt.printf("Made UDP socket on %v\n", endpoint.port);
	
	client_socket, cerr := net.dial_tcp(endpoint);
	if cerr != nil {
		fmt.printf("Failed to connect to server, error:", cerr);
		panic("Unable to bind to port");
	}

	new_ss_client_socket, _, sscerr := net.accept_tcp(acceptor_socket);
	if sscerr != nil {
		fmt.printf("Failed to make a UDP socket, error:", sscerr);
		panic("Unable to bind to port");
	}

	fmt.printf("Succesfully accepted a client %v\n", endpoint.port);

	my_bytes : []u8 = {20, 100, 150};
	net.send(client_socket, my_bytes);

	recv_bytes : [20]u8;
	recv_butes_cnt, recv_err := net.recv(new_ss_client_socket, recv_bytes[:]);
	if recv_err != nil {
		panic("Failed to recive bytes from client");
	}

	fmt.printf("Succesfully recived bytes from client, bytes recived : %v, bytes : %v\n", recv_butes_cnt, recv_bytes);
}
*/
*/



