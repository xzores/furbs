import os
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