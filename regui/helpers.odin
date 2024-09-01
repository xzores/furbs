package gui;

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:math"
import "core:reflect"
import "base:intrinsics"
import "core:strconv"
import "core:mem"
import "core:slice"

import "core:time" //Temp

import render "../render"
import utils "../utils"


create_panel_from_struct :: proc (value : ^$T, parent : Parent, dest : Destination, show : bool = true, tooltip : Tooltip = nil,
			appearance : Maybe(Appearance) = nil, hover_appearance : Maybe(Appearance) = nil, selected_appearance : Maybe(Appearance) = nil,
			active_appearance : Maybe(Appearance) = nil, loc := #caller_location) -> (panel : Panel) where intrinsics.type_is_struct(T)
{
	
	
	
	return {};
}
		