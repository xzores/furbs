#+feature dynamic-literals
package furbs_network_tests

import "core:container/queue"
import "base:runtime"

import "core:log"
import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

import "../tcp"
import network ".."

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

commands_map : map[network.Message_id]typeid = {
	
	//random number to make it less likely a wrong connection will be accepted.
	14732 = Hello,
	42034 = Hello_from_server,

	//We start initiliztion stuff from id 100 and up
	100 = Version_check,
	101 = Version_check_passed,

	200 = Chat_message,

	500 = Disconnect_me,
}

my_logger : runtime.Logger;
my_alloc : runtime.Allocator;

get_server_func :: proc ($address : string, $binary : bool) -> thread.Thread_Proc {

	server_handle_func : thread.Thread_Proc : proc(t : ^thread.Thread) {
		context = tcp.restore_context();

		/////////// Server ///////////
		server := network.server_create();
		network.register_interface(server, tcp.server_interface(commands_map, address, binary));
		network.server_start_accepting(server);
		
		log.infof("server handle thread open on %v", address); 

		connected_clients : map[^network.Server_side_client]struct{};
		defer delete(connected_clients);

		server_handle_events :: proc (server : ^network.Server, connected_clients : ^map[^network.Server_side_client]struct{}) {

			network.server_begin_handle_events(server);
				
				e, done := network.server_get_next_event(server);
				for !done {
					defer e, done = network.server_get_next_event(server); //happens last, so for the next one
					assert(e.type != nil);
					
					client := e.client.(^network.Server_side_client);
					
					#partial switch event in e.type {
						case network.Event_connected: {
							log.infof("connected client (from server)");
							connected_clients[client] = {};
						}
						case network.Event_msg: {
							switch msg in event.value {
								case Hello: {
									log.infof("server got a hello");
									assert(network.server_send(server, client, Hello_from_server{}) == nil);
									assert(network.server_send(server, client, Hello_from_server{}) == nil);
									assert(network.server_send(server, client, Hello_from_server{}) == nil);
								}
								case Version_check: {
									assert(msg.major_version 	== 1);
									assert(msg.minor_version 	== 2);
									assert(msg.patch 			== 3);
									assert(network.server_send(server, client, Version_check_passed{true}) == nil);
								}
								case Chat_message: {
									log.infof("recived chat message from client: %v", msg.text);
								}
								case Disconnect_me: {
									log.info("Client asked to be disconnected, doint that now");
									network.server_disconnect_client(server, client);
								}
								case: {
									unreachable()
								}
							}
						}
						case network.Event_disconnected: {
							log.infof("disconnected client (from server)");
							delete_key(connected_clients, client);
						}
						case: {
							panic("TODO Event is not Event_msg");
						}
					}
				}

			network.server_end_handle_events(server);
		}

		for !should_close_server {
			server_handle_events(server, &connected_clients);
			time.sleep(1 * time.Millisecond);
		}

		network.server_close(server)

		for len(connected_clients) != 0 {
			log.debugf("handeling the last evetns, cur num of clients : %v", len(connected_clients));
			server_handle_events(server, &connected_clients);
			time.sleep(1 * time.Millisecond);
		}
		
		network.server_destroy(server);

		assert(len(connected_clients) == 0);
	}

	return server_handle_func;
}
