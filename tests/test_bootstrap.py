import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('bootstrap', Path(__file__).resolve().parents[1] / 'bootstrap.py')
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class BootstrapTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'user'
        self.home.mkdir()
        self.home_patch = patch.object(bootstrap.Path, 'home', return_value=self.home)
        self.home_patch.start()
        self.addCleanup(self.home_patch.stop)

    def test_build_finishes_before_loading_and_cache_is_outside_plugin(self):
        results = [subprocess.CompletedProcess([], 0, text) for text in ('', 'false', '[]', 'ok', 'ok')]
        with patch.object(bootstrap.subprocess, 'run', side_effect=results) as run:
            bootstrap.load(self.root)
        calls = run.call_args_list
        self.assertEqual(len(calls), 5)
        self.assertEqual(calls[0].args[0][0], 'timeout')
        self.assertEqual(calls[1].args[0][:2], ['hyprctl', 'repl'])
        self.assertEqual(calls[2].args[0], ['hyprctl', '-j', 'plugin', 'list'])
        self.assertEqual(calls[3].args[0][:3], ['hyprctl', 'plugin', 'load'])
        self.assertEqual(calls[4].args[0][:2], ['hyprctl', 'eval'])
        self.assertIn('__hyprworld_native_path', calls[4].args[0][2])
        self.assertNotEqual(Path(calls[0].args[0][-1]).parent, self.root / 'native')

    def test_build_failure_never_loads_layout(self):
        with patch.object(bootstrap.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'build')) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                bootstrap.load(self.root)
        self.assertEqual(run.call_count, 1)

    def test_existing_helper_is_not_loaded_twice(self):
        results = [subprocess.CompletedProcess([], 0, text) for text in ('', 'true', 'ok')]
        with patch.object(bootstrap.subprocess, 'run', side_effect=results) as run:
            bootstrap.load(self.root)
        self.assertEqual(run.call_count, 3)
        self.assertEqual(run.call_args.args[0][:2], ['hyprctl', 'eval'])

    def test_native_load_failure_never_registers_layout(self):
        results = [subprocess.CompletedProcess([], 0, text) for text in ('', 'false', '[]', 'version mismatch')]
        with patch.object(bootstrap.subprocess, 'run', side_effect=results) as run:
            with self.assertRaisesRegex(RuntimeError, 'Native helper load failed'):
                bootstrap.load(self.root)
        self.assertEqual(run.call_count, 4)

    def test_mismatched_helper_never_stacks_another_hook(self):
        for name in ('hyprworld-shared-workspaces', 'hyprscroll2d-shared-workspaces'):
            results = [subprocess.CompletedProcess([], 0, text) for text in
                       ('', 'false', '[{"name":"' + name + '"}]')]
            with patch.object(bootstrap.subprocess, 'run', side_effect=results) as run:
                with self.assertRaisesRegex(RuntimeError, 'incompatible Lua API'):
                    bootstrap.load(self.root)
            self.assertEqual(run.call_count, 3)

    def test_disabled_plugin_needs_no_compiler(self):
        (self.root / 'customizer.json').write_text('{"plugin":{"enabled":false}}')
        with patch.object(bootstrap.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'ok\n')) as run:
            bootstrap.load(self.root)
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][:2], ['hyprctl', 'eval'])

    def test_saved_preferences_override_legacy_defaults(self):
        (self.root / 'customizer.json').write_text('{"plugin":{"enabled":true}}')
        settings = self.home / '.config/omarchy/hyprworld.json'
        settings.parent.mkdir(parents=True)
        settings.write_text('{"plugin":{"enabled":false}}')
        with patch.object(bootstrap.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'ok\n')) as run:
            bootstrap.load(self.root)
        self.assertEqual(run.call_count, 1)

    def test_ipc_error_is_not_success(self):
        with patch.object(bootstrap.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'error: incompatible plugin')):
            with self.assertRaises(RuntimeError):
                bootstrap.load(self.root)

    def test_malformed_structure_never_reaches_compositor(self):
        (self.root / 'customizer.json').write_text('{"plugin":false}')
        with patch.object(bootstrap.subprocess, 'run') as run:
            with self.assertRaises(ValueError): bootstrap.load(self.root)
        run.assert_not_called()

    def test_ipc_warning_and_timeout_are_failures(self):
        with patch.object(bootstrap.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'warning: unavailable')):
            with self.assertRaises(RuntimeError): bootstrap.load(self.root)
        with patch.object(bootstrap.subprocess, 'run', side_effect=subprocess.TimeoutExpired('build', 130)):
            with self.assertRaises(subprocess.TimeoutExpired): bootstrap.load(self.root)

    def test_quote_roundtrips_unicode_and_control_characters_in_lua(self):
        value = 'a"\\\n雪'
        result = subprocess.run(['lua', '-e', 'io.write(' + bootstrap.lua_quote(value) + ')'], capture_output=True, check=True)
        self.assertEqual(result.stdout.decode(), value)


if __name__ == '__main__':
    unittest.main()
