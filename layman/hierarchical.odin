package furbs_layman;

import "base:runtime"

import "core:math"
import "core:math/linalg"
import "core:strings"
import "core:slice"
import "core:container/queue"

import "core:fmt"

@private
Hierarchy :: struct {
	
	root : ^Node,
	current_node : ^Node,
	
	to_promote : ^Node, //Almost the same as to next_active, but this one has 
	
	uid_to_node : map[Unique_id]^Node,
	priorities : map[^Node]u16, //last priorties used to control which one is next_active and next_hot
	
	append_command_back : bool,
}

@private
init_hierarchy :: proc () -> Hierarchy{
	
}

@private
destroy_hierarchy :: proc () {
	
}

@private
Node :: struct {
	uid : Unique_id,
	sub_nodes : [dynamic]^Node,
	parent : ^Node,
	
	refound : bool,
}

@private
push_element :: proc (s : ^Hierarchy, uid : Unique_id, loc := #caller_location) {
	
	s.append_command_back = false;
	
	assert(uid != {});
	if uid in s.uid_to_node {
		//Mark node as being found this frame, (so it has been decalred same as last frame)
		node := s.uid_to_node[uid];
		fmt.assertf(node != s.current_node, "You are pushing the same node twice %v", uid, loc = loc);
		
		if s.current_node == nil {
			s.root = node;
		}
		else {
			i, found := slice.linear_search(s.current_node.sub_nodes[:], node);
			if !found {
				append(&s.current_node.sub_nodes, node);
			}
			
			node.refound = true;
			node.parent = s.current_node;
		}
		s.current_node = node;
	}
	else {
		//make the root node
		if s.current_node == nil {
			new := new_node(uid, s.current_node);
			new.refound = true;
			s.root = new;
			s.current_node = new;
			s.uid_to_node[uid] = new;
		}
		else {
			new := new_node(uid, s.current_node);
			new.refound = true;
			new.parent = s.current_node;
			append(&s.current_node.sub_nodes, new);
			s.uid_to_node[uid] = new;
			s.current_node = new;
		}
	}
	
	
}

@private
pop_element :: proc (s : ^Hierarchy) -> Unique_id {
	
	popped := s.current_node;
	s.current_node = s.current_node.parent;
	
	s.append_command_back = true;
	
	return popped.uid;
}


@(private, require_results)
new_node :: proc (uid : Unique_id, parent : ^Node) -> ^Node {
	
	n := new(Node)
	
	n^ = {
		uid,
		make([dynamic]^Node),
		parent,
		true,
	};
	
	return n;
}
