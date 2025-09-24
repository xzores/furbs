//This is a copy of the standart core:log library, fittet to my taste.
//Go there to see more and lisence.
package utils

import "core:fmt"
import "core:strings"
import "core:os"
import "core:time"
import "core:log"
import "core:sync"


//Shallow copy
reverse_map :: proc (to_reverse : map[$A]$B) -> map[B]A {

	reversed := make(map[B]A);

	for k, v in to_reverse {
		reversed[v] = k
	}

	return reversed;
}