package whirl_web;

import "core:reflect"
import "core:fmt"
import "core:c"
import "core:log"
import "core:mem"
import "core:os"
import "core:dynlib"
import win32 "core:sys/windows"
import "core:unicode/utf16"

import "../furbs/render"

check_win32_error :: proc (err_msg : string, loc := #caller_location) {
	error_msg_id := win32.GetLastError()

	if error_msg_id != 0 {
		messageBuffer := make([]u16, 1028);

		win32.FormatMessageW(win32.FORMAT_MESSAGE_FROM_SYSTEM | win32.FORMAT_MESSAGE_IGNORE_INSERTS,
		nil, error_msg_id, win32.MAKELANGID(win32.LANG_NEUTRAL, win32.SUBLANG_DEFAULT), raw_data(messageBuffer), auto_cast len(messageBuffer), nil);

		msg_u8 := make([]u8, 2*1028);

		utf16.decode_to_utf8(msg_u8, messageBuffer);

		log.errorf("win32 API call error : %v", string(msg_u8));
		fmt.panicf("%v, error code was %v\nError message : %v", err_msg, error_msg_id, string(msg_u8), loc = loc);
	}
}

map_to_win_vk :: proc(kc: render.Key_code) -> c.int {
	#partial switch kc {
		// --- Control / navigation ---
		case .escape:        return win32.VK_ESCAPE;
		case .tab:           return win32.VK_TAB;
		case .backspace:     return win32.VK_BACK;
		case .enter, .kp_enter:
			return win32.VK_RETURN;
		case .space:         return win32.VK_SPACE;

		case .insert:        return win32.VK_INSERT;
		case .delete:        return win32.VK_DELETE;
		case .home:          return win32.VK_HOME;
		case .end:           return win32.VK_END;
		case .page_up:       return win32.VK_PRIOR; // Page Up
		case .page_down:     return win32.VK_NEXT;  // Page Down

		case .left:          return win32.VK_LEFT;
		case .right:         return win32.VK_RIGHT;
		case .up:            return win32.VK_UP;
		case .down:          return win32.VK_DOWN;

		case .caps_lock:     return win32.VK_CAPITAL;
		case .scroll_lock:   return win32.VK_SCROLL;
		case .num_lock:      return win32.VK_NUMLOCK;
		case .print_screen:  return win32.VK_SNAPSHOT;
		case .pause:         return win32.VK_PAUSE;
		
		// --- Function keys ---
		case .f1:  return win32.VK_F1;
		case .f2:  return win32.VK_F2;
		case .f3:  return win32.VK_F3;
		case .f4:  return win32.VK_F4;
		case .f5:  return win32.VK_F5;
		case .f6:  return win32.VK_F6;
		case .f7:  return win32.VK_F7;
		case .f8:  return win32.VK_F8;
		case .f9:  return win32.VK_F9;
		case .f10: return win32.VK_F10;
		case .f11: return win32.VK_F11;
		case .f12: return win32.VK_F12;
		case .f13: return win32.VK_F13;
		case .f14: return win32.VK_F14;
		case .f15: return win32.VK_F15;
		case .f16: return win32.VK_F16;
		case .f17: return win32.VK_F17;
		case .f18: return win32.VK_F18;
		case .f19: return win32.VK_F19;
		case .f20: return win32.VK_F20;
		case .f21: return win32.VK_F21;
		case .f22: return win32.VK_F22;
		case .f23: return win32.VK_F23;
		case .f24: return win32.VK_F24;
		// GLFW has F25; Windows doesn't. If you have .f25 and want a fallback, map it to F24 or handle separately.

		// --- Modifiers ---
		case .shift_left:    return win32.VK_LSHIFT;
		case .shift_right:   return win32.VK_RSHIFT;
		case .control_left:  return win32.VK_LCONTROL;
		case .control_right: return win32.VK_RCONTROL;
		case .alt_left:      return win32.VK_LMENU;   // Alt
		case .alt_right:     return win32.VK_RMENU;   // AltGr on some layouts
		case .super_left:    return win32.VK_LWIN;    // Windows key
		case .super_right:   return win32.VK_RWIN;    // Windows key
		case .menu:          return win32.VK_APPS;    // Context/menu key

		// --- Main row digits (assumes your enum has _0.._9 like GLFW) ---
		case .zero: return win32.VK_0; // '0'
		case .one: return win32.VK_1;
		case .two: return win32.VK_2;
		case .three: return win32.VK_3;
		case .four: return win32.VK_4;
		case .five: return win32.VK_5;
		case .six: return win32.VK_6;
		case .seven: return win32.VK_7;
		case .eight: return win32.VK_8;
		case .nine: return win32.VK_9;

		// --- Letters ---
		case .a: return win32.VK_A;
		case .b: return win32.VK_B;
		case .c: return win32.VK_C;
		case .d: return win32.VK_D;
		case .e: return win32.VK_E;
		case .f: return win32.VK_F;
		case .g: return win32.VK_G;
		case .h: return win32.VK_H;
		case .i: return win32.VK_I;
		case .j: return win32.VK_J;
		case .k: return win32.VK_K;
		case .l: return win32.VK_L;
		case .m: return win32.VK_M;
		case .n: return win32.VK_N;
		case .o: return win32.VK_O;
		case .p: return win32.VK_P;
		case .q: return win32.VK_Q;
		case .r: return win32.VK_R;
		case .s: return win32.VK_S;
		case .t: return win32.VK_T;
		case .u: return win32.VK_U;
		case .v: return win32.VK_V;
		case .w: return win32.VK_W;
		case .x: return win32.VK_X;
		case .y: return win32.VK_Y;
		case .z: return win32.VK_Z;

		// --- OEM / punctuation (main section) ---
		case .minus:         return win32.VK_OEM_MINUS;   // '-'
		case .equal:         return win32.VK_OEM_PLUS;    // '='
		case .bracket_left:  return win32.VK_OEM_4;       // '['
		case .bracket_right: return win32.VK_OEM_6;       // ']'
		case .backslash:     return win32.VK_OEM_5;       // '\'
		case .semicolon:     return win32.VK_OEM_1;       // ';'
		case .apostrophe:    return win32.VK_OEM_7;       // '\''
		case .grave_accent:  return win32.VK_OEM_3;       // '`'
		case .comma:         return win32.VK_OEM_COMMA;   // ','
		case .period:        return win32.VK_OEM_PERIOD;  // '.'
		case .slash:         return win32.VK_OEM_2;       // '/'

		// --- Keypad ---
		case .kp_0:        return win32.VK_NUMPAD0;
		case .kp_1:        return win32.VK_NUMPAD1;
		case .kp_2:        return win32.VK_NUMPAD2;
		case .kp_3:        return win32.VK_NUMPAD3;
		case .kp_4:        return win32.VK_NUMPAD4;
		case .kp_5:        return win32.VK_NUMPAD5;
		case .kp_6:        return win32.VK_NUMPAD6;
		case .kp_7:        return win32.VK_NUMPAD7;
		case .kp_8:        return win32.VK_NUMPAD8;
		case .kp_9:        return win32.VK_NUMPAD9;
		case .kp_decimal:  return win32.VK_DECIMAL;
		case .kp_divide:   return win32.VK_DIVIDE;
		case .kp_multiply: return win32.VK_MULTIPLY;
		case .kp_subtract: return win32.VK_SUBTRACT;
		case .kp_add:      return win32.VK_ADD;
		case .kp_equal:    return win32.VK_OEM_NEC_EQUAL; // if present on the device
		
		// If you expose browser/media keys in your render.Key_code, map them similarly:
		// case .browser_back:        return win32.VK_BROWSER_BACK;
		// case .browser_forward:     return win32.VK_BROWSER_FORWARD;
		// case .browser_refresh:     return win32.VK_BROWSER_REFRESH;
		// case .browser_stop:        return win32.VK_BROWSER_STOP;
		// case .browser_search:      return win32.VK_BROWSER_SEARCH;
		// case .browser_favorites:   return win32.VK_BROWSER_FAVORITES;
		// case .browser_home:        return win32.VK_BROWSER_HOME;
		// case .volume_mute:         return win32.VK_VOLUME_MUTE;
		// case .volume_down:         return win32.VK_VOLUME_DOWN;
		// case .volume_up:           return win32.VK_VOLUME_UP;
		// case .media_next_track:    return win32.VK_MEDIA_NEXT_TRACK;
		// case .media_prev_track:    return win32.VK_MEDIA_PREV_TRACK;
		// case .media_stop:          return win32.VK_MEDIA_STOP;
		// case .media_play_pause:    return win32.VK_MEDIA_PLAY_PAUSE;
		// case .launch_mail:         return win32.VK_LAUNCH_MAIL;
		// case .launch_media_select: return win32.VK_LAUNCH_MEDIA_SELECT;
		// case .launch_app1:         return win32.VK_LAUNCH_APP1;
		// case .launch_app2:         return win32.VK_LAUNCH_APP2;

		case:
			fmt.panicf("TODO: unmapped key (%v)", kc);
	}
}
