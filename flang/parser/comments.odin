package flang_parser;

				//It works for this case
				// a + (b * c)
				/*
						+
					   / \
					  a   *
					     / \
						b   c
				*/
				
				// a * b + c * (d + e) //This case is wrong 
				/*
						*
					   / \
					  a   +
					     / \
						b   *
						   / \
						  c   +
						     / \
							d   e
				*/
				
				//The tree should be
				/*
					     +
					    / \
					  *     *
					 / \   / \
					a	b c   +
						     / \
						    d   e
				*/
				
				// a * !b + c * (d + e)
				// a * Parse(!b + c * (d + e))
				// a * Parse( Parse(!b + c * (d + e)) )
				
				// We just look at:
				// !b + c * (d + e)
				// !Parse(b + c * (d + e))
				// ! was higher presedence then + so the + operator is returned and we where put under
				//THis is wrong
				//tree should be
				/*
					     +
					    / \
					  *     *
					 / \   / \
					a	! c   +
						|    / \
						b    d   e
				*/
				
				// case: a * b + c
				// contruct node (a * b)
				// Then call parse(b + c)
				// if ourself is returned our presedence was higher and the node remains (a * b), we will be put under the other node
				//This results in:
				/*
					     +
					    / \
					   *   c
				      / \
				     a   b
				*/
				
				// case: a + b * c
				// contruct node (a + b)
				// Then call parse(b * c)
				// if the other is returned our presedence was lower, so the 'b' is swapped to (a + res)
				//This results in:
				/*
					     +
					    / \
					   a   *
					      / \
					     b   c
				*/
				
				
				
/*



	get_next_node :: proc (syntax_nodes : []Syntax_node, cur_node : ^int, last_node : ^Syntax_node) -> (res : Syntax_node, done : bool) {
		
		done = false;
		
		if cur_node^ >= len(syntax_nodes) {
			done = true;
			return;
		}
		if cur_node^ < len(syntax_nodes)-1 {
			last_node^ = syntax_nodes[cur_node^ - 1];
		}
		
		res = syntax_nodes[cur_node^];
		cur_node^ += 1;
		
		return;
	}
	
	cur_node : int;
	res : ^Expression = left_side;
	last_node : Syntax_node;
	
	node, node_done := get_next_node(syntax_nodes, &cur_node, &last_node);
	//node_done : bool;
	for !node_done {
		
		defer node, node_done = get_next_node(syntax_nodes, &cur_node, &last_node);
		//precedence := precedence(node);
		
		switch v in node.value {
			case ^Expression: {
				
				//We dont know what this means yet?
				switch l in last_node.value {
					case ^Expression, Binary_operator_kind: 
						return nil, Parse_error{
							"Got 2 expression in a row, this is not valid, it has no meaning.",
							node.origin, 
						};
						
					case Unary_operator_kind: {
						exp := new(Expression);
						exp^ = Unary_operator{
							l,
							v,
						};
						
						res = exp; //This is like a return
					}
					case: {
						if node_done {
							assert(len(syntax_nodes) == 1, "something is wrong length is not 1, but we only found 1 expression");
						} else {
							panic("something is wrong");
						}
					}
				}
			}
			case Binary_operator_kind: {
				
				switch l in last_node.value {
					case ^Expression: {
						
						//Peek next node
						next_node : Syntax_node;
						if cur_node < len(syntax_nodes) {
							next_node = syntax_nodes[cur_node];
						}

						if next_exp, ok := next_node.value.(^Expression); ok {
							
							exp := new(Expression);
							exp^ = Binary_operator{
								v,
								res,
								next_exp, //This assumes our presedence is higher
							};
							
							assert(len(syntax_nodes[cur_node:]) != 0, "syntax_nodes[cur_node:] is 0");
							new_res, err := parse_syntex_nodes_to_ast(syntax_nodes[cur_node:], res);
							
							if err != {} {
								return nil, err;
							}
							
							//We want to return the lowest presedence (highest in the tree).
							if new_res == res {
								//Our precedence was lower
								//keep it as it and return outself
								exp^ = Binary_operator{
									v,
									res,
									new_res, //This means we place the other node below us (presedence is lower when high in the tree)
								};
								
								return exp, {};
							}
							else {
								//Our presedence was higher
								return new_res, {};
							}
							
							unreachable();
						}
						else {
							return nil, Parse_error{
								fmt.tprintf("Expected expression after %v", node.origin),
								next_node.origin,
							};
						}
					}
					case Unary_operator_kind : {
						return nil, Parse_error{
							"Found a binary operator followed by a binary operator, this has no meaning",
							node.origin,
						};
					}
					case Binary_operator_kind: {
						return nil, Parse_error{
							"Found a unary operator followed by a binary operator, this has no meaning",
							node.origin,
						};
					}
					case: {
						return nil, Parse_error{
							"Illigal",
							node.origin,
						};
					}
				}
			}
			case Unary_operator_kind: {
				switch l in last_node.value {
					case ^Expression, Unary_operator_kind: {
						//this is not ok 
						return nil, Parse_error{
							"Left side of unary operator is illigal",
							node.origin,
						};
					}
					case Binary_operator_kind: {
						//This is ok
					}
				}				
			}
		}
		
		last_node = node;
	}
	
	assert(res != nil, "internal error parse_expression returned nil without erroring");
	

*/