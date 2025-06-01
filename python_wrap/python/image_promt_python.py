import os
import json
import requests
import sys
import argparse

def process_image_with_openai(image_path, prompt, openai_api_key, model="gpt-4-vision-preview", max_tokens=300):
	import base64
	json_path = os.path.splitext(image_path)[0] + ".json"
	try:
		with open(image_path, "rb") as img_f:
			img_b64 = base64.b64encode(img_f.read()).decode("utf-8")
		headers = {
			"Authorization": f"Bearer {openai_api_key}",
			"Content-Type": "application/json"
		}
		data = {
			"model": model,
			"messages": [
				{"role": "user", "content": [
					{"type": "text", "text": prompt},
					{"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}}
				]}
			],
			"max_tokens": max_tokens
		}
		response = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=data)
		if response.status_code == 200:
			result = response.json()["choices"][0]["message"]["content"]
		else:
			print(f"OpenAI API error: {response.status_code} {response.text}")
			result = ""
		
		import re, json as pyjson
		match = re.search(r'\{[\s\S]*\}', result)
		if match:
			try:
				parsed = pyjson.loads(match.group(0))
			except Exception:
				parsed = {"description": result.strip()}
		else:
			parsed = {"description": result.strip()}
		print(pyjson.dumps(parsed, ensure_ascii=False, indent=2))
	except Exception as e:
		print(f"Failed to caption {image_path}: {e}", file=sys.stderr)

def process_image_with_llava(image_path, prompt):
	try:
		import torch
		from PIL import Image
		from transformers import AutoProcessor, AutoModelForVision2Seq
		
		device = "cuda" if torch.cuda.is_available() else "cpu"
		print(f"Using device: {device.upper()}")
		processor = AutoProcessor.from_pretrained("llava-hf/llava-1.5-7b-hf")
		model = AutoModelForVision2Seq.from_pretrained("llava-hf/llava-1.5-7b-hf").to(device)
		
		llava_prompt = f"<image>\n{prompt}"
		img = Image.open(image_path).convert("RGB")
		inputs = processor(text=llava_prompt, images=img, return_tensors="pt").to(device)
		output = model.generate(**inputs, max_new_tokens=512)
		result = processor.decode(output[0], skip_special_tokens=True)
		result = result.replace('\\n', '\n').replace('\\"', '"')
		
		import re, json as pyjson
		match = re.search(r'\{[\s\S]*\}', result)
		if match:
			try:
				parsed = pyjson.loads(match.group(0))
			except Exception:
				parsed = {"description": result.strip()}
		else:
			parsed = {"description": result.strip()}
		print(pyjson.dumps(parsed, ensure_ascii=False, indent=2))
	except Exception as e:
		print(f"Failed to caption {image_path}: {e}", file=sys.stderr)

def process_image(image_path, prompt, use_openai_api=True, openai_api_key=None, model="gpt-4-vision-preview", max_tokens=300):
	if use_openai_api:
		if not openai_api_key:
			openai_api_key = os.getenv('OPENAI_API_KEY')
			if not openai_api_key:
				print("Error: OpenAI API key not provided. Set OPENAI_API_KEY environment variable or pass it as argument.")
				return
		print("Using OpenAI API for image captioning.")
		process_image_with_openai(image_path, prompt, openai_api_key, model, max_tokens)
	else:
		print("Using Llava model for image captioning.")
		process_image_with_llava(image_path, prompt)

def main():
	parser = argparse.ArgumentParser(description='Process images with AI models')
	parser.add_argument('json_config', help='Path to JSON configuration file')
	
	args = parser.parse_args()
	
	# Read configuration from JSON file
	try:
		with open(args.json_config, 'r') as f:
			config = json.load(f)
	except Exception as e:
		print(f"Error reading JSON config file: {e}", file=sys.stderr)
		return
	
	# Extract parameters from JSON
	image_path = config.get('image_path', '')
	prompt = config.get('prompt', '')
	use_openai_api = not config.get('use_llava', False)  # Default to OpenAI unless use_llava is True
	openai_api_key = config.get('openai_api_key')
	model = config.get('model', 'gpt-4-vision-preview')
	max_tokens = config.get('max_tokens', 300)
	
	# Validate required parameters
	if not image_path:
		print("Error: image_path is required in JSON config", file=sys.stderr)
		return
	if not prompt:
		print("Error: prompt is required in JSON config", file=sys.stderr)
		return
	
	process_image(image_path, prompt, use_openai_api, openai_api_key, model, max_tokens)

if __name__ == "__main__":
	main()