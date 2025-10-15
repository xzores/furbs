package furbs_css_tokenizer;

Token :: struct {

}

Selector_type :: enum {
	universal_selector,  		// * Universal selector
	element_selector,			// Anything that starts with a letter
	id_selector,				// * ID selector
	class_selector,				// . Class selector
	pseudo_class_selector,		// : Pseudo-class selector
	pseudo_element_selector,	// :: Pseudo-element selector
	attribute_selector, 		// [] Attribute selector
}

Selector_token :: struct {
	type : Selector_type,

}

Element_selector_token :: struct {

}

//@	At-rule
At_rule_token :: struct {

}

Combinator_type :: enum {
	descendant,	// (space)
	child,		// >
	adjacent,	// +
	sibling,	// ~
}

//Descendant, Adjacent, General
Combinator_token :: struct {
	type : Combinator_type,

}

QualifiedName :: struct {
	namespace : string,  // optional
	name : string,       // e.g. "circle"
};

Selector_list_token :: struct {
    selectors : []Selector_token,
}




tokenize :: proc (css : string) -> []Token {



}






