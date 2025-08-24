from deepseek_tokenizer import ds_token

input = "%v"
tokenizer_path = "%v"

res = ""

if (tokenizer_path != ""):
	# Load the tokenizer from the specified path
	tokenizer = ds_token.from_pretrained(tokenizer_path);
	# Encode text and print result
	res = tokenizer.encode(input)

else:
	# Encode text
	res = ds_token.encode(input)


print(res)