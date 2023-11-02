package network

import "core:fmt"
import "core:net"
import "core:mem"

import queue "core:container/queue"

import utils "../../FurbLib/utils"
import thread "../../FurbLib/utils"

import tracy "shared:tracy"

Client :: struct {
    using base : Client_base,
    params : Network_params,
}

/////////////////////////////////////////////////////////

make_client :: proc(client : ^Client, params : Network_params, loc := #caller_location){
	tracy.Zone();

    assert(params.is_init, "network must be initialized before calling client_main", loc);
    
    client.params = params;
}

Connect_client :: proc(using client : ^Client, server_endpoint : net.Endpoint) {
	tracy.Zone();

    err : net.Network_Error;
    socket, err = net.dial_tcp(server_endpoint);
	
    if err != nil {
        panic("Cannot connect to server!\n");
    }
    
    lock(&mutex);

    /////////// setup recive thread ///////////
    assert(net.set_blocking(client.socket, true) == nil); //We want it to be blocking
    //TODO a timeout is needed (and maybe keep alive settings?)

    //fmt.printf("client 2 : %v\n", client);
    client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
        tracy.Zone();
		tracy.SetThreadName("client recive loop");

		client : ^Client = cast(^Client)t.data;

		recv_parse_loop(cast(^Client_base)client, client.params);
    }

    recive_thread = thread.create(client_recive_loop, client);

    queue.init(&current_bytes_recv);
    queue.init(&recv_commands);
    allowed_commands = make(typeid_set);
    for k, v in client.params.initial_allowed_commands {
        allowed_commands[k] = v;
    }
    
    unlock(&mutex);

    thread.start(recive_thread);
	free_all(context.temp_allocator);
}

close_client :: proc(using client : ^Client) {
    tracy.Zone();

    should_close = true;
    
    lock(&mutex);
    net.close(socket);
    unlock(&mutex);

    thread.destroy(recive_thread);
	free(recive_thread);

    fmt.printf("Closed client\n");
}