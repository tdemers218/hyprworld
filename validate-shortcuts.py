"""Validate layout shortcuts against active Hyprland bindings, including keycodes."""
import ctypes as C
import ctypes.util
import json
import re
import subprocess
import sys

MODS = {"SUPER": 64, "CTRL": 4, "ALT": 8, "SHIFT": 1}
ALIASES = {"CONTROL": "CTRL", "WIN": "SUPER", "META": "SUPER", "ENTER": "RETURN", "ESC": "ESCAPE"}
DEFAULTS = {"settings":"SUPER + SHIFT + L", "overview":"SUPER + O", "zoomIn":"SUPER + CTRL + UP", "zoomOut":"SUPER + CTRL + DOWN",
    "panLeft":"SUPER + CTRL + LEFT", "panRight":"SUPER + CTRL + RIGHT", "toggleMax":"SUPER + ALT + F"}
for prefix, mods in (("focus","SUPER"), ("move","SUPER + SHIFT"), ("resize","SUPER + ALT")):
    for direction in ("Left","Right","Up","Down"):
        DEFAULTS[prefix+direction] = mods+" + "+direction.upper()

def parse(value):
    tokens = [ALIASES.get(t.strip().upper(), t.strip().upper()) for t in value.split("+")]
    if not tokens or not all(tokens):
        raise ValueError("Enter a key combination, such as SUPER + CTRL + H.")
    key, mods = tokens[-1], tokens[:-1]
    if key in MODS or any(m not in MODS for m in mods) or len(set(mods)) != len(mods):
        raise ValueError("Use modifiers SUPER, CTRL, ALT or SHIFT, followed by one key.")
    if not re.fullmatch(r"[A-Z0-9_]+|CODE:[0-9]+|MOUSE:[0-9]+", key):
        raise ValueError("Use a key name (e.g. H, LEFT, F8, minus), code:NN or mouse:NNN.")
    mask = sum(MODS[m] for m in mods)
    rendered_key = key.lower() if ":" in key else key
    return " + ".join([m for m in MODS if m in mods] + [rendered_key]), mask, key

class Keymap:
    def __init__(self):
        self.lib = C.CDLL(ctypes.util.find_library("xkbcommon") or "libxkbcommon.so.0")
        lib = self.lib
        def declare(name, result, *args):
            f = getattr(lib, name); f.restype = result; f.argtypes = args
        declare("xkb_context_new", C.c_void_p, C.c_int)
        declare("xkb_keymap_new_from_names", C.c_void_p, C.c_void_p, C.c_void_p, C.c_int)
        declare("xkb_keysym_from_name", C.c_uint32, C.c_char_p, C.c_int)
        declare("xkb_keymap_min_keycode", C.c_uint32, C.c_void_p)
        declare("xkb_keymap_max_keycode", C.c_uint32, C.c_void_p)
        declare("xkb_keymap_num_layouts_for_key", C.c_uint32, C.c_void_p, C.c_uint32)
        declare("xkb_keymap_num_levels_for_key", C.c_uint32, C.c_void_p, C.c_uint32, C.c_uint32)
        declare("xkb_keymap_key_get_syms_by_level", C.c_int, C.c_void_p, C.c_uint32, C.c_uint32, C.c_uint32, C.POINTER(C.POINTER(C.c_uint32)))
        declare("xkb_keymap_unref", None, C.c_void_p)
        declare("xkb_context_unref", None, C.c_void_p)
        class Names(C.Structure):
            _fields_ = [(k, C.c_char_p) for k in ("rules", "model", "layout", "variant", "options")]
        def option(key):
            data = json.loads(subprocess.check_output(["hyprctl", "-j", "getoption", "input:kb_"+key], text=True))
            return str(data.get("str", "")).encode() or None
        names = Names(*(option(k) for k in ("rules", "model", "layout", "variant", "options")))
        self.ctx = lib.xkb_context_new(0)
        self.map = lib.xkb_keymap_new_from_names(self.ctx, C.byref(names), 0)
        if not self.map: raise ValueError("Could not load the current keyboard layout.")
        self.codes = {}
        for code in range(lib.xkb_keymap_min_keycode(self.map), lib.xkb_keymap_max_keycode(self.map)+1):
            for group in range(lib.xkb_keymap_num_layouts_for_key(self.map, code)):
                for level in range(lib.xkb_keymap_num_levels_for_key(self.map, code, group)):
                    syms = C.POINTER(C.c_uint32)()
                    count = lib.xkb_keymap_key_get_syms_by_level(self.map, code, group, level, C.byref(syms))
                    for i in range(count): self.codes.setdefault(syms[i], set()).add(code)

    def identity(self, key):
        if key.startswith("CODE:"):
            code = int(key[5:])
            if not 8 <= code <= 767: raise ValueError("Keycodes must be between 8 and 767.")
            return {"code:"+str(code)}
        if key.startswith("MOUSE:"):
            code = int(key[6:])
            if not 272 <= code < 352: raise ValueError("Mouse button codes must be between 272 and 351.")
            return {"mouse:"+str(code)}
        sym = self.lib.xkb_keysym_from_name(key.encode(), 1)
        if not sym: raise ValueError("Unknown key: "+key)
        # Keep symbol identity as well, for keys absent from the current keymap.
        return {"sym:"+str(sym)} | {"code:"+str(c) for c in self.codes.get(sym, set())}

    def close(self):
        self.lib.xkb_keymap_unref(self.map)
        self.lib.xkb_context_unref(self.ctx)

def validate(shortcuts, bindings, keymap):
    result, seen = {}, []
    for action, raw in shortcuts.items():
        chord, mask, key = parse(raw)
        if mask == 64 and key in {"MOUSE:272", "MOUSE:274", "MOUSE_UP", "MOUSE_DOWN"}:
            raise ValueError(chord+" is reserved for workspace mouse gestures.")
        identity = keymap.identity(key)
        if mask in {64,65,73} and any("code:"+str(code) in identity for code in range(10,20)):
            raise ValueError(chord+" is reserved for monitor-local workspace selection and movement.")
        if mask in {64,65,68} and (key == "TAB" or "code:23" in identity):
            raise ValueError(chord+" is reserved for monitor navigation.")
        # These are the plugin's established overrides. Allow restoring them
        # while disabled, when the underlying native bindings are visible.
        default = DEFAULTS.get(action)
        restoring_default = bool(default and parse(default)[:2] == (chord, mask))
        for other, other_mask, other_identity in seen:
            if mask == other_mask and identity & other_identity:
                raise ValueError(action+" overlaps with "+other+". Give each action a different shortcut.")
        seen.append((action, mask, identity))
        for binding in bindings:
            if restoring_default: continue
            if binding.get("modmask") != mask or str(binding.get("description", "")).startswith("Hyprworld: "):
                continue
            if binding.get("keycode", 0):
                bound = {"code:"+str(binding["keycode"])}
            else:
                try: bound = keymap.identity(str(binding.get("key", "")).upper())
                except ValueError: continue
            if identity & bound:
                raise ValueError(chord+" is already used by "+(binding.get("description") or binding.get("dispatcher") or "another binding")+".")
        result[action] = chord
    return result

def main():
    keymap = None
    try:
        shortcuts = json.loads(sys.argv[1])
        bindings = json.loads(subprocess.check_output(["hyprctl", "-j", "binds"], text=True))
        keymap = Keymap()
        print(json.dumps({"shortcuts": validate(shortcuts, bindings, keymap), "error": ""}))
    except (ValueError, OSError, subprocess.SubprocessError, IndexError) as error:
        print(json.dumps({"error": str(error)}))
    finally:
        if keymap: keymap.close()

if __name__ == "__main__": main()
