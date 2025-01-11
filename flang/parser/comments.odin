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