package furbs_ECS;

//This is a merge between an ECS and an event system

import "core:slice"
import "base:runtime"
import "../utils"

ECS_DEFAULT_COMP_SIZE :: 32;

Message_id :: distinct int; 	//This is what function call
Component_id :: distinct int;	//This is on what system that function is
Entity_id :: distinct int;		//This is what data to use for the call

Message :: struct {
	origin : Entity_id,	//may be 0 for nil
	target : Entity_id, 	//This can be the same as origin, may NOT be 0
	msg_type : Message_id, //this is implicit by the function call, but we pass it anyway
	msg_data : rawptr, //size of data infered by msg_type
}

Entity :: struct {
	//This might be bad if we have a lot of entities
	subs : map[Message_id][dynamic]^System,
}

System :: struct {
	
	//The component data, it is a array, but the size is not known a compile time.
	componet_array : utils.Dynamic_array, //this should also store the entity_id. This stores the component data! it owns it!
	component_owners : map[Entity_id]int, //maps from entity id into the component_data array (the index is in elements)
	
	//Cache the pointers, could be calculated every frame 
	arr_of_comp_data_ptr : [dynamic]rawptr, //This is another view of the data, which is just a list of rawptr next to each other. Only used for speed-up
	
	//The system can recive messages, these are the incoming messages
	messages : [dynamic]Message,
	new_messages : [dynamic]Message,
	msg_subs : map[Message_id]proc(components : []rawptr, origin : Entity_id, msg_data : rawptr), 
	
	//This is requirements, which is checked when applying the component
	requirements : []Component_id,
}

Entity_component_system :: struct {
	systems : map[Component_id]^System,
	entities : map[Entity_id]Entity,
	cur_msg_id : Message_id,
	cur_comp_id : Component_id,
	cur_entity_id : Entity_id,
}

make_ECS :: proc () -> Entity_component_system {
	return {
		make(map[Component_id]^System),
		make(map[Entity_id]Entity),
		0,
		0,
		0,
	};
}

destroy_ECS :: proc (ecs : ^Entity_component_system) {
	
}

//msg_size in bytes
register_message_id :: proc (ecs : ^Entity_component_system, name : string, msg_size : int) -> Message_id {
	ecs.cur_msg_id += 1;
	return ecs.cur_msg_id;
}

//Does not take any ownership of the data
register_system :: proc (ecs : ^Entity_component_system, name : string, size_of_component : int, msg_subs : map[Message_id]proc(components : []rawptr, origin : Entity_id, msg_data : rawptr), requirements : []Component_id) -> Component_id {
	
	ecs.cur_comp_id += 1;
	
	system := new(System);
	system^ = System{
		utils.dynamic_array_make(size_of_component),
		make(map[Entity_id]int, ECS_DEFAULT_COMP_SIZE),
		make([dynamic]rawptr),
		make([dynamic]Message),
		make([dynamic]Message),
		clone_map(msg_subs),
		slice.clone(requirements),
	};
	
	ecs.systems[ecs.cur_comp_id] = system;
	
	return 0;
}

make_entity :: proc (ecs : ^Entity_component_system) -> Entity_id {
	ecs.cur_entity_id += 1;
	
	ecs.entities[ecs.cur_entity_id] = Entity{make(map[Message_id][dynamic]^System)};
	
	return ecs.cur_entity_id;
}

destroy_entity :: proc (ecs : ^Entity_component_system, entity : Entity_id) {
	panic("TODO");
}

add_component :: proc (ecs : ^Entity_component_system, entity_id : Entity_id, component_type : Component_id, component_data : rawptr, data_size : int) {
	
	//Find the system	
	system := ecs.systems[component_type];
	assert(data_size == system.componet_array.element_size);
	
	//Setup the system
	comp_index := utils.dynamic_array_add_element(&system.componet_array, component_data); 
	system.component_owners[entity_id] = comp_index;
	resize(&system.arr_of_comp_data_ptr, utils.dynamic_array_len(system.componet_array));
	system.arr_of_comp_data_ptr[comp_index] = utils.dynamic_array_get(&system.componet_array, comp_index);
	
	assert(utils.dynamic_array_len(system.componet_array) == len(system.component_owners));
	assert(utils.dynamic_array_len(system.componet_array) == len(system.arr_of_comp_data_ptr));
	
	//Setup the entity
	entity := ecs.entities[entity_id];
	for msg_id, _ in system.msg_subs {
		append(&entity.subs[msg_id], system);
	}
}

//use for update
trigger_msg_all :: proc (ecs : ^Entity_component_system, msg_type : Message_id, msg_data : rawptr) {
	//trigger a msg to all system which are appliciable, does not require looping over entities
	//Does not append to the messages, this is an imittiate thing, for performence reasons.
	
	for _, system in ecs.systems {
		
		if msg_type in system.msg_subs {
			
			function := system.msg_subs[msg_type];
			
			//TODO split into threads and handle all messages
			function(system.arr_of_comp_data_ptr[:], 0, msg_data);
		}
	}
	
	//continue to trigger messages until they are all gone.
	//once done move new_messages to messages and clear old message and redo
	done := false;
	for done {
		done = true;
		
		//if we find any msg then make done = false
		for _, system in ecs.systems {
			if len(system.messages) == 0 {
				continue;
			}
			
			done = false;
			for msg in system.messages {
				function := system.msg_subs[msg.msg_type];
				index := system.component_owners[msg.target];
				target_ptr := [1]rawptr{utils.dynamic_array_get(&system.componet_array, index)};
				function(target_ptr[:], 0, msg_data);
			}
			
			clear(&system.messages);
			system.messages, system.new_messages = system.new_messages, system.messages;
		}
	}
}

//TODO multithreaded API, use from inside your system procs
add_messages :: proc (ecs : ^Entity_component_system, msg : Message) {
	
	entity := ecs.entities[msg.target];
	systems := entity.subs[msg.msg_type];
	
	for s in systems {
		append(&s.new_messages, msg);
	}
}

/*
//For online sync, TODO 
set_state_change_callback :: proc () {
	
}

set_message_callback :: proc () {
	
}
*/

@(private)
clone_map :: proc(original : map[$T]$TT) -> map[T]TT {
    result := make(map[T]TT)
    for key, value in original {
        result[key] = value
    }
    return result
}
