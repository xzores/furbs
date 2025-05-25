package python_wrap;

import "base:runtime"
import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:slice"
import "core:fmt"
import "core:encoding/json"
import "core:mem"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:io"
import "core:strings"
import "core:c/libc"
import "core:strconv"

image_convert_code := 'import os
from typing import List

def convert_image(img_paths: list):
	import cv2
	icon_files = []
	for file_path in img_paths:
		img = cv2.imread(file_path)
		if img is not None:
			# Denoise using OpenCV
			denoised = cv2.fastNlMeansDenoisingColored(img, None, 10, 10, 7, 21)
			png_path = os.path.splitext(file_path)[0] + ".png"
			cv2.imwrite(png_path, denoised)
			os.remove(file_path)
			icon_files.append(png_path)
	return icon_files
	
img_to_convert = %v
convert_image(img_to_convert);
'

image_convert_png_and_denoise :: proc (imgs : []string, loc := #caller_location) {
	
	stdout := run_python_code(image_promt_python_code, imgs);
	
	s_res := "";
	
	{
		s_res = string(stdout);
	}
	
	return s_res;
}


@(private)
image_promt_python_code :=
`import os
import json
import requests

def process_image_with_openai(image_path, prompt, openai_api_key):
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
			"model": "%v",
			"messages": [
				{"role": "user", "content": [
					{"type": "text", "text": prompt},
					{"type": "image_url", "image_url": {"url": f"data:image/png;base64,{img_b64}"}}
				]}
			],
			"max_tokens": %v
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
		import sys
		print(f"Failed to caption {image_path}: {e}", file=sys.stderr)

def process_image_with_llava(image_path, prompt):
	import torch
	from PIL import Image
	from transformers import AutoProcessor, AutoModelForVision2Seq
	device = "cuda" if torch.cuda.is_available() else "cpu"
	print(f"Using device: {device.upper()}")
	processor = AutoProcessor.from_pretrained("llava-hf/llava-1.5-7b-hf")
	model = AutoModelForVision2Seq.from_pretrained("llava-hf/llava-1.5-7b-hf").to(device)
	try:
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
		import sys
		print(f"Failed to caption {image_path}: {e}", file=sys.stderr)

def process_image(image_path, prompt, use_openai_api):
	open_ai_key = %v
	
	if use_openai_api:
		print("Using OpenAI API for image captioning.")
		process_image_with_openai(image_path, prompt, open_ai_key)
	else:
		print("Using Llava API for image captioning.")
		process_image_with_llava(image_path, prompt)

use_openai_api = %v
img_to_promt = %v
prompt = %v
process_image(img_to_promt, prompt, use_openai_api);
`

promt_image_and_string :: proc (imgs : []string, open_ai_key : string, open_ai_model := "gpt-4-vision-preview", use_local : bool = false, max_tokens : int = 2048, loc := #caller_location) -> string {
	
	stdout := run_python_code(image_promt_python_code, open_ai_model, max_tokens, open_ai_key, img_to_promt);
	
	s_res := "";
	
	{
		s_res = string(stdout);
	}
	
	return s_res;
}
