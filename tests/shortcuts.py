import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("validator", Path(__file__).resolve().parents[1] / "validate-shortcuts.py")
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

class Keymap:
    def identity(self, key):
        keys = {"H":{"code:43"}, "J":{"code:44"}, "UP":{"code:111"}, "RETURN":{"code:36"}}
        if key.startswith("CODE:"): return {"code:"+key[5:]}
        if key not in keys: raise ValueError("Unknown key: "+key)
        return keys[key]

class Shortcuts(unittest.TestCase):
    def test_canonical_and_aliases(self):
        self.assertEqual(v.parse(" control + Super + h"), ("SUPER + CTRL + H",68,"H"))
        self.assertEqual(v.parse("Super + Enter")[2], "RETURN")
    def test_invalid(self):
        for value in ["SUPER", "SUPER +", "H; reboot", "SUPER + CTRL + CTRL + H"]:
            with self.assertRaises(ValueError): v.parse(value)
    def test_active_conflict_by_code(self):
        with self.assertRaisesRegex(ValueError,"Resize"):
            v.validate({"zoomIn":"SUPER + SHIFT + UP"},[{"modmask":65,"keycode":111,"description":"Resize"}],Keymap())
    def test_active_conflict_by_name(self):
        with self.assertRaisesRegex(ValueError,"Launcher"):
            v.validate({"zoomIn":"SUPER + H"},[{"modmask":64,"key":"h","description":"Launcher"}],Keymap())
    def test_duplicate_aliases(self):
        with self.assertRaisesRegex(ValueError,"overlaps"):
            v.validate({"zoomIn":"SUPER + H","zoomOut":"SUPER + code:43"},[],Keymap())
    def test_reassign_own_binding(self):
        self.assertEqual(v.validate({"zoomIn":"SUPER + H"},[{"modmask":64,"key":"H","description":"Hyprworld: Focus left"}],Keymap())["zoomIn"],"SUPER + H")
    def test_restore_factory_when_disabled(self):
        self.assertTrue(v.validate({"zoomIn":"SUPER + CTRL + UP"},[{"modmask":68,"keycode":111,"description":"Native"}],Keymap()))
    def test_unknown_key(self):
        with self.assertRaisesRegex(ValueError,"Unknown"): v.validate({"zoomIn":"SUPER + MADEUP"},[],Keymap())
    def test_mouse_gestures_reserved(self):
        for key in ("mouse:272", "mouse:274", "mouse_up", "mouse_down"):
            with self.assertRaisesRegex(ValueError,"reserved"):
                v.validate({"zoomIn":"SUPER + " + key},[],Keymap())
    def test_monitor_keys_reserved(self):
        for chord in ("SUPER + code:10", "SUPER + SHIFT + code:14", "SUPER + code:23"):
            with self.assertRaisesRegex(ValueError,"reserved"):
                v.validate({"zoomIn":chord},[],Keymap())

unittest.main()
