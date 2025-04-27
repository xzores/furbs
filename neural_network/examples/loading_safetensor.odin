package nn_examples;

import "core:testing"
import "core:fmt"
import "core:time"

import nn ".."

//@(test) load_safetensor_1 :: proc (t : ^testing.T) {

main :: proc() {
	nn.load_safetensors_from_filename("tiny_model/model.safetensors");
}