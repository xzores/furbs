package furbs_web;

import "core:reflect"
import "core:fmt"
import "core:c"
import "core:log"
import "core:mem"
import "core:os"
import "core:dynlib"
import "core:sys/windows"
import "core:unicode/utf16"

import "../render"

check_windows_error :: proc (err_msg : string, loc := #caller_location) {
	error_msg_id := windows.GetLastError()

	if error_msg_id != 0 {
		messageBuffer := make([]u16, 1028);

		windows.FormatMessageW(windows.FORMAT_MESSAGE_FROM_SYSTEM | windows.FORMAT_MESSAGE_IGNORE_INSERTS,
		nil, error_msg_id, windows.MAKELANGID(windows.LANG_NEUTRAL, windows.SUBLANG_DEFAULT), raw_data(messageBuffer), auto_cast len(messageBuffer), nil);

		msg_u8 := make([]u8, 2*1028);

		utf16.decode_to_utf8(msg_u8, messageBuffer);

		log.errorf("windows API call error : %v", string(msg_u8));
		fmt.panicf("%v, error code was %v\nError message : %v", err_msg, error_msg_id, string(msg_u8), loc = loc);
	}
}

map_to_win_vk :: proc(kc: render.Key_code) -> c.int {
	#partial switch kc {
		// --- Control / navigation ---
		case .escape:        return windows.VK_ESCAPE;
		case .tab:           return windows.VK_TAB;
		case .backspace:     return windows.VK_BACK;
		case .enter, .kp_enter:
			return windows.VK_RETURN;
		case .space:         return windows.VK_SPACE;

		case .insert:        return windows.VK_INSERT;
		case .delete:        return windows.VK_DELETE;
		case .home:          return windows.VK_HOME;
		case .end:           return windows.VK_END;
		case .page_up:       return windows.VK_PRIOR; // Page Up
		case .page_down:     return windows.VK_NEXT;  // Page Down

		case .left:          return windows.VK_LEFT;
		case .right:         return windows.VK_RIGHT;
		case .up:            return windows.VK_UP;
		case .down:          return windows.VK_DOWN;

		case .caps_lock:     return windows.VK_CAPITAL;
		case .scroll_lock:   return windows.VK_SCROLL;
		case .num_lock:      return windows.VK_NUMLOCK;
		case .print_screen:  return windows.VK_SNAPSHOT;
		case .pause:         return windows.VK_PAUSE;
		
		// --- Function keys ---
		case .f1:  return windows.VK_F1;
		case .f2:  return windows.VK_F2;
		case .f3:  return windows.VK_F3;
		case .f4:  return windows.VK_F4;
		case .f5:  return windows.VK_F5;
		case .f6:  return windows.VK_F6;
		case .f7:  return windows.VK_F7;
		case .f8:  return windows.VK_F8;
		case .f9:  return windows.VK_F9;
		case .f10: return windows.VK_F10;
		case .f11: return windows.VK_F11;
		case .f12: return windows.VK_F12;
		case .f13: return windows.VK_F13;
		case .f14: return windows.VK_F14;
		case .f15: return windows.VK_F15;
		case .f16: return windows.VK_F16;
		case .f17: return windows.VK_F17;
		case .f18: return windows.VK_F18;
		case .f19: return windows.VK_F19;
		case .f20: return windows.VK_F20;
		case .f21: return windows.VK_F21;
		case .f22: return windows.VK_F22;
		case .f23: return windows.VK_F23;
		case .f24: return windows.VK_F24;
		// GLFW has F25; Windows doesn't. If you have .f25 and want a fallback, map it to F24 or handle separately.

		// --- Modifiers ---
		case .shift_left:    return windows.VK_LSHIFT;
		case .shift_right:   return windows.VK_RSHIFT;
		case .control_left:  return windows.VK_LCONTROL;
		case .control_right: return windows.VK_RCONTROL;
		case .alt_left:      return windows.VK_LMENU;   // Alt
		case .alt_right:     return windows.VK_RMENU;   // AltGr on some layouts
		case .super_left:    return windows.VK_LWIN;    // Windows key
		case .super_right:   return windows.VK_RWIN;    // Windows key
		case .menu:          return windows.VK_APPS;    // Context/menu key

		// --- Main row digits (assumes your enum has _0.._9 like GLFW) ---
		case .zero: return windows.VK_0; // '0'
		case .one: return windows.VK_1;
		case .two: return windows.VK_2;
		case .three: return windows.VK_3;
		case .four: return windows.VK_4;
		case .five: return windows.VK_5;
		case .six: return windows.VK_6;
		case .seven: return windows.VK_7;
		case .eight: return windows.VK_8;
		case .nine: return windows.VK_9;

		// --- Letters ---
		case .a: return windows.VK_A;
		case .b: return windows.VK_B;
		case .c: return windows.VK_C;
		case .d: return windows.VK_D;
		case .e: return windows.VK_E;
		case .f: return windows.VK_F;
		case .g: return windows.VK_G;
		case .h: return windows.VK_H;
		case .i: return windows.VK_I;
		case .j: return windows.VK_J;
		case .k: return windows.VK_K;
		case .l: return windows.VK_L;
		case .m: return windows.VK_M;
		case .n: return windows.VK_N;
		case .o: return windows.VK_O;
		case .p: return windows.VK_P;
		case .q: return windows.VK_Q;
		case .r: return windows.VK_R;
		case .s: return windows.VK_S;
		case .t: return windows.VK_T;
		case .u: return windows.VK_U;
		case .v: return windows.VK_V;
		case .w: return windows.VK_W;
		case .x: return windows.VK_X;
		case .y: return windows.VK_Y;
		case .z: return windows.VK_Z;

		// --- OEM / punctuation (main section) ---
		case .minus:         return windows.VK_OEM_MINUS;   // '-'
		case .equal:         return windows.VK_OEM_PLUS;    // '='
		case .bracket_left:  return windows.VK_OEM_4;       // '['
		case .bracket_right: return windows.VK_OEM_6;       // ']'
		case .backslash:     return windows.VK_OEM_5;       // '\'
		case .semicolon:     return windows.VK_OEM_1;       // ';'
		case .apostrophe:    return windows.VK_OEM_7;       // '\''
		case .grave_accent:  return windows.VK_OEM_3;       // '`'
		case .comma:         return windows.VK_OEM_COMMA;   // ','
		case .period:        return windows.VK_OEM_PERIOD;  // '.'
		case .slash:         return windows.VK_OEM_2;       // '/'

		// --- Keypad ---
		case .kp_0:        return windows.VK_NUMPAD0;
		case .kp_1:        return windows.VK_NUMPAD1;
		case .kp_2:        return windows.VK_NUMPAD2;
		case .kp_3:        return windows.VK_NUMPAD3;
		case .kp_4:        return windows.VK_NUMPAD4;
		case .kp_5:        return windows.VK_NUMPAD5;
		case .kp_6:        return windows.VK_NUMPAD6;
		case .kp_7:        return windows.VK_NUMPAD7;
		case .kp_8:        return windows.VK_NUMPAD8;
		case .kp_9:        return windows.VK_NUMPAD9;
		case .kp_decimal:  return windows.VK_DECIMAL;
		case .kp_divide:   return windows.VK_DIVIDE;
		case .kp_multiply: return windows.VK_MULTIPLY;
		case .kp_subtract: return windows.VK_SUBTRACT;
		case .kp_add:      return windows.VK_ADD;
		case .kp_equal:    return windows.VK_OEM_NEC_EQUAL; // if present on the device
		
		// If you expose browser/media keys in your render.Key_code, map them similarly:
		// case .browser_back:        return windows.VK_BROWSER_BACK;
		// case .browser_forward:     return windows.VK_BROWSER_FORWARD;
		// case .browser_refresh:     return windows.VK_BROWSER_REFRESH;
		// case .browser_stop:        return windows.VK_BROWSER_STOP;
		// case .browser_search:      return windows.VK_BROWSER_SEARCH;
		// case .browser_favorites:   return windows.VK_BROWSER_FAVORITES;
		// case .browser_home:        return windows.VK_BROWSER_HOME;
		// case .volume_mute:         return windows.VK_VOLUME_MUTE;
		// case .volume_down:         return windows.VK_VOLUME_DOWN;
		// case .volume_up:           return windows.VK_VOLUME_UP;
		// case .media_next_track:    return windows.VK_MEDIA_NEXT_TRACK;
		// case .media_prev_track:    return windows.VK_MEDIA_PREV_TRACK;
		// case .media_stop:          return windows.VK_MEDIA_STOP;
		// case .media_play_pause:    return windows.VK_MEDIA_PLAY_PAUSE;
		// case .launch_mail:         return windows.VK_LAUNCH_MAIL;
		// case .launch_media_select: return windows.VK_LAUNCH_MEDIA_SELECT;
		// case .launch_app1:         return windows.VK_LAUNCH_APP1;
		// case .launch_app2:         return windows.VK_LAUNCH_APP2;

		case:
			fmt.panicf("TODO: unmapped key (%v)", kc);
	}
}
