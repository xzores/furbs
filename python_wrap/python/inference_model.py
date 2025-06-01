import torch
from transformers import AutoModel
import numpy as np
import sys

# Define the model architecture (replace with the correct model type)
model = AutoModel.from_pretrained('%v')  # or specify the exact model class

# Load the state dictionary
model.load_state_dict(torch.load('%v/pytorch_model.bin', weights_only=True), strict=False)

# Set the model to evaluation mode
model.eval()

# Example input (replace with your actual input)
input_tensor = torch.tensor([%v])  # Replace with actual input data

# Run inference
with torch.no_grad():  # Disable gradient tracking during inference
    output = model(input_tensor)

tensor = output.last_hidden_state.cpu().numpy()

# Step 1: Prepend the length of the shape (number of dimensions)
shape = np.array(tensor.shape, dtype=np.int32)
shape_length = np.array([len(tensor.shape)], dtype=np.int32)  # Length of shape

# Combine the length and shape into a single array
shape_with_length = np.concatenate([shape_length, shape])

# Step 2: Write the combined shape data (length + shape) as binary
shape_with_length.tofile(sys.stdout.buffer)

# Writing raw binary data to stdout
#tensor.astype(np.float32).tofile(sys.stdout.buffer)