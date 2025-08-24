package neural_network

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"
import "core:testing"

// Token type alias
Token :: u32

// Special tokens
ENDOFTEXT_TOKEN :: "<|endoftext|>"

// Tokenizer structures
Tokenizer :: struct {
	vocab:        map[string]Token,           // vocab token -> ID mapping
	reverse_vocab: map[Token]string,          // ID -> token mapping  
	merges:       [dynamic]BPE_Merge,         // BPE merge rules in priority order
	special_tokens: map[string]Token,         // special token mappings
}

BPE_Merge :: struct {
	pair: [2]string,  // the pair to merge (e.g., ["Ġ", "t"])
	priority: int,    // priority (lower number = higher priority)
}

// Load tokenizer from files
load_tokenizer :: proc(vocab_path, merges_path, special_tokens_path: string) -> (^Tokenizer, bool) {
	tokenizer := new(Tokenizer)
	
	// Initialize maps
	tokenizer.vocab = make(map[string]Token)
	tokenizer.reverse_vocab = make(map[Token]string)
	tokenizer.merges = make([dynamic]BPE_Merge)
	tokenizer.special_tokens = make(map[string]Token)
    
	// Load vocabulary
	if !load_vocab(tokenizer, vocab_path) {
		fmt.println("Failed to load vocabulary")
		return tokenizer, false
	}
	
	// Load merges
	if !load_merges(tokenizer, merges_path) {
		fmt.println("Failed to load merges")
		return tokenizer, false
	}
	
	// Load special tokens
	if !load_special_tokens(tokenizer, special_tokens_path) {
		fmt.println("Failed to load special tokens")
		return tokenizer, false
	}
	
	return tokenizer, true
}

// Tokenize text using BPE algorithm
tokenize :: proc(tokenizer: ^Tokenizer, text: string) -> []Token {
	if len(text) == 0 {
		return {}
	}
	
	// Convert text to initial tokens (character level)
	initial_tokens := make([dynamic]string)
	defer {
		for token in initial_tokens {
			delete(token)
		}
		delete(initial_tokens)
	}
	
	// Simple approach: split by whitespace and add space marker
	words := strings.split(text, " ")
	defer delete(words)
	
	for word_idx := 0; word_idx < len(words); word_idx += 1 {
		word := words[word_idx]
		if word_idx > 0 {
			// Add space marker (Ġ represents space in GPT-2 tokenizer)  
			append(&initial_tokens, strings.clone("Ġ"))
		}
		
		// Add each character of the word as separate tokens
		for char in word {
			char_str := fmt.aprintf("%c", char)
			append(&initial_tokens, char_str)
		}
	}
	
	// Apply BPE merges
	merged_tokens := apply_bpe_merges(tokenizer, initial_tokens[:])
	defer {
		for token in merged_tokens {
			delete(token)
		}
		delete(merged_tokens)
	}
	
	// Convert to token IDs
	result := make([dynamic]Token)
	for token in merged_tokens {
		if id, found := tokenizer.vocab[token]; found {
			append(&result, id)
		} else {
			// Use unknown token (endoftext in this case)
			if unk_id, found := tokenizer.vocab[ENDOFTEXT_TOKEN]; found {
				append(&result, unk_id)
			}
		}
	}
	
	return result[:]
}

// Cleanup tokenizer resources
destroy_tokenizer :: proc(tokenizer: ^Tokenizer) {
	// Clean up vocab
	for key, _ in tokenizer.vocab {
		delete(key)
	}
	delete(tokenizer.vocab)
	
	for _, value in tokenizer.reverse_vocab {
		delete(value)
	}
	delete(tokenizer.reverse_vocab)
	
	// Clean up merges
	for merge in tokenizer.merges {
		delete(merge.pair[0])
		delete(merge.pair[1])
	}
	delete(tokenizer.merges)
	
	// Clean up special tokens
	for key in tokenizer.special_tokens {
		delete(key)
	}
	delete(tokenizer.special_tokens)

	free(tokenizer)
}

// Convert tokens back to text (for debugging/testing)
decode :: proc(tokenizer: ^Tokenizer, tokens: []Token) -> string {
	if len(tokens) == 0 {
		return ""
	}
	
	parts := make([dynamic]string)
	defer delete(parts)
	
	for token in tokens {
		if text, found := tokenizer.reverse_vocab[token]; found {
			append(&parts, text)
		}
	}
	
	// Join and replace space markers
	temp_result := strings.concatenate(parts[:])
	defer delete(temp_result)
	
	final_result, _ := strings.replace_all(temp_result, "Ġ", " ")
	
	return final_result
}

///////////////////////// PRIVATE /////////////////////////

// Load vocabulary from vocab.json
@(private="file")
load_vocab :: proc(tokenizer: ^Tokenizer, vocab_path: string) -> bool {
	data, ok := os.read_entire_file(vocab_path)
	if !ok {
		return false
	}
	defer delete(data)
	
	// Parse JSON
	vocab_map: map[string]json.Value
	if json.unmarshal(data, &vocab_map, allocator = context.temp_allocator) != nil {
		return false
	}
	
	// Convert to our format
	for token, value in vocab_map {
		if id, ok := value.(json.Integer); ok {
			token_id := Token(id)
			tokenizer.vocab[strings.clone(token)] = token_id
			tokenizer.reverse_vocab[token_id] = strings.clone(token)
		}
	}
	
	return true
}

// Load BPE merges from merges.txt
@(private="file")
load_merges :: proc(tokenizer: ^Tokenizer, merges_path: string) -> bool {
	data, ok := os.read_entire_file(merges_path)
	if !ok {
		return false
	}
	defer delete(data)
	
	lines := strings.split_lines(string(data))
	defer delete(lines)
	
	priority := 0
	for line in lines {
		trimmed := strings.trim_space(line)
		if len(trimmed) == 0 || strings.has_prefix(trimmed, "#") {
			continue
		}
		
		parts := strings.split(trimmed, " ")
		if len(parts) == 2 {
			merge := BPE_Merge{
				pair = {strings.clone(parts[0]), strings.clone(parts[1])},
				priority = priority,
			}
			append(&tokenizer.merges, merge)
			priority += 1
		}
		delete(parts)
	}
	
	return true
}

// Load special tokens from special_tokens_map.json
@(private="file")
load_special_tokens :: proc(tokenizer: ^Tokenizer, special_tokens_path: string) -> bool {
	data, ok := os.read_entire_file(special_tokens_path)
	if !ok {
		return false
	}
	defer delete(data)
	
	// Parse JSON
	special_map: map[string]json.Value
	if json.unmarshal(data, &special_map, allocator = context.temp_allocator) != nil {
		return false
	}
	
	// Convert to our format and lookup IDs from vocab
	for key, value in special_map {
		if token_str, ok := value.(json.String); ok {
			if token_id, found := tokenizer.vocab[token_str]; found {
				tokenizer.special_tokens[strings.clone(key)] = token_id
			}
		}
	}
	
	return true
}

// Apply BPE merges to token list
@(private="file")
apply_bpe_merges :: proc(tokenizer: ^Tokenizer, tokens: []string) -> [dynamic]string {
	result := make([dynamic]string)
	for token in tokens {
		append(&result, strings.clone(token))
	}
	
	// Apply merges in priority order
	for merge in tokenizer.merges {
		new_result := make([dynamic]string)
		
		i := 0
		for i < len(result) {
			if i < len(result) - 1 && 
			   result[i] == merge.pair[0] && 
			   result[i + 1] == merge.pair[1] {
				// Merge the pair
				merged := strings.concatenate({result[i], result[i + 1]})
				append(&new_result, merged)
				i += 2  // Skip the next token since we merged it
			} else {
				append(&new_result, strings.clone(result[i]))
				i += 1
			}
		}
		
		// Clean up old result
		for token in result {
			delete(token)
		}
		delete(result)
		
		result = new_result
	}
	
	return result
}
