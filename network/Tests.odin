package network

import "core:fmt"
import "core:net"
import "core:testing"
import "core:time"

import queue "core:container/queue"

import utils "../../FurbLib/utils"
import thread "../../FurbLib/utils"

@test
test_main :: proc (t : ^testing.T) {
	
    Default_game_port : int : 26604;
    Default_game_ip := net.IP4_Loopback; //TODO should we use net.Address_Family.IP4

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
    
    Disconnect :: struct {};
    Disconnected_by_server :: struct {}; //TODO add infomation about why.
    
    commands_map : map[message_id_type]typeid = {
        
        //random number to make it less likely a wrong connection will be accepted.
        14732 = Hello,
        42034 = Hello_from_server,

        //We start initiliztion stuff from id 100 and up
        100 = Version_check,
        101 = Version_check_passed,

        200 = Chat_message,
        
        500 = Disconnect,
        501 = Disconnected_by_server,

    }

    //The ones the server revices
    server_initial_allowed_commands : typeid_set = {
        Hello = {},
        Disconnect = {},
    };
    server_command_allowing_list : map[typeid][]typeid = {
        Hello = {Version_check},
        Version_check = {Chat_message},
    };
    server_command_disallowing_list : map[typeid][]typeid = {
        Hello = {Hello},
        Version_check = {Version_check},
    };

    //The ones the client revices
    client_initial_allowed_commands : typeid_set = {
        Hello_from_server = {},
        Disconnected_by_server = {},
        Disconnect = {},
    };
    client_command_allowing_list : map[typeid][]typeid = {
        Hello_from_server = {Version_check_passed},
    };
    client_command_disallowing_list : map[typeid][]typeid = {
        Hello_from_server = {Hello_from_server},
        Version_check_passed = {Version_check_passed},
    };

    handle_command :: proc(server : ^Server, client : ^Server_side_client, command : any) {
        
        switch command.id {
            case Hello:
                fmt.printf("Well hello\n");
                send_message(client.socket, server.params, Hello_from_server{});
            case Version_check:
                fmt.printf("Recived version %v\n", command);
                v_check := cast(^Version_check)command.data;
                if v_check.major_version == 12 && v_check.minor_version == 1 && v_check.patch == 1 {
                    fmt.printf("version passed\n");
                    send_message(client.socket, server.params, Version_check_passed{true});
                }
                else {
                    fmt.printf("version was wrong\n");
                    send_message(client.socket, server.params, Version_check_passed{false});
                    send_message(client.socket, server.params, Disconnected_by_server{});
                    remove_client(server, client.client_id);
                }
            case Chat_message:
                char_mes := cast(^Chat_message)command.data;
                fmt.printf("Recived chat message : %s\n", char_mes.text);
            case Disconnect:
                send_message(client.socket, server.params, Disconnected_by_server{});
                fmt.printf("Disconnecting client!\n");
                remove_client(server, client.client_id);
            case:
                panic("Unhandled command!");
		}

        free(command.data);
    }

    handle_commands :: proc (server : ^Server) {
        lock(&server.clients_mutex);
        for _, client  in server.clients {
            lock(&client.mutex);
            for queue.len(client.recv_commands) != 0 {
                command := queue.pop_front(&client.recv_commands);
                handle_command(server, client, command);
            }
            unlock(&client.mutex);
        }
        unlock(&server.clients_mutex);
    }

    cleaner_func :: proc(to_clean : any) {
        //TODO clean
    }

    server_test : thread.Thread_Proc : proc(t : ^thread.Thread) {
        
        server : ^Server = cast(^Server)t.data;

        for !server.should_close {
            lock(&server.clients_mutex);
            cnt := len(server.clients);
            unlock(&server.clients_mutex);
            
            if cnt == 1 {
                break;
            }
            
            //TODO handle commands
            handle_commands(server);
            update_server(server);
        }

        //The client will disconnect with the disconnect commands, and so we wait for that to be sent.
        for !server.should_close {
            
            lock(&server.clients_mutex);
            cnt := len(server.clients);
            unlock(&server.clients_mutex);
            
            if cnt == 0 {
                break;
            }

            //TODO handle commands
            handle_commands(server);
            update_server(server);
        }
    }

    ///////////////////////////////////////////////

    for  i : int = 0; i < 10; i += 1 {

        /////////// Server ///////////
        server_network_params : Network_params = make_params(cleaner_func, commands_map, server_initial_allowed_commands, server_command_allowing_list, server_command_disallowing_list);
		server : Server;
        make_server(&server, server_network_params, {Default_game_ip, Default_game_port});

        //For testing we start a new thread for scraping commands from the client.
        server_thread := thread.create(server_test, &server);
		
        //fmt.printf("Starting thread acceptor\n");
        thread.start(server_thread);

        /////////// Client ///////////
        client_network_params : Network_params = make_params(cleaner_func, commands_map, client_initial_allowed_commands, client_command_allowing_list, client_command_disallowing_list);
		client : Client;
        make_client(&client, client_network_params);

        Connect_client(&client, net.Endpoint{Default_game_ip, Default_game_port});

        //fmt.printf("client 1 : %#v\n", client);
        send_message(&client, Hello{});
        hello_resp, h_err := wait_for_message(&client, Hello_from_server);
        assert(h_err == false);
        
        send_message(&client, Version_check{12,1,1});
        version_resp, v_err := wait_for_message(&client, Version_check_passed);
        assert(v_err == false);
        assert(version_resp.was_passed == true);

        send_message(&client, Chat_message{"Yoyoyo this is client calling! 1"});
        send_message(&client, Chat_message{"Yoyoyo what is up server, this is client calling! 2"});
        //send_message(client, Chat_message{"Yoyoyo what is up server, this is client calling! 3"});
        //send_message(client, Chat_message{"Yoyoyo what is up server, this is client calling! 4"});
        //send_message(client, Chat_message{"Yoyoyo what is up server, this is client calling! 5"});
        //send_message(client, Chat_message{"Yoyoyo what is up server, this is client calling! 6"});

        //Disconnect in the end.
        send_message(&client, Disconnect{});
        _, d_err := wait_for_message(&client, Disconnected_by_server);
        //assert(d_err == false);

        //start_client_message_handler(client);

        /////////// Closure ///////////
        server.should_close = true;
        thread.destroy(server_thread);
        close_server(&server);

		delete_params(&server_network_params);
        fmt.printf("\n\n\n");
    }
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