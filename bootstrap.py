#!/usr/bin/env python3
"""Build outside the watched plugin tree, then load Hyprworld through IPC."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def lua_quote(value):
    return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34, 92)
                         else '\\%03d' % b for b in str(value).encode()) + '"'


def ipc(*arguments):
    result = subprocess.run(['hyprctl', *arguments], capture_output=True, text=True, check=True, timeout=10)
    return result.stdout.strip()


def load(root):
    preferences = Path.home() / '.config/omarchy/hyprworld.json'
    legacy = root / 'customizer.json'
    settings = json.loads((preferences if preferences.exists() else legacy).read_text()) if preferences.exists() or legacy.exists() else {}
    if not isinstance(settings, dict) or not isinstance(settings.get('plugin', {}), dict):
        raise ValueError('Settings must contain a JSON object and a plugin object')
    code = ''
    if settings.get('plugin', {}).get('enabled', True):
        key = hashlib.sha256(str(root).encode()).hexdigest()[:16]
        cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'hyprworld' / key
        subprocess.run(['timeout', '--kill-after=5s', '120s', 'bash', str(root / 'native/build.sh'), str(cache)], check=True, timeout=130)
        # hl.plugin.load only queues configuration-time loading. During eval,
        # use the native IPC loader before registering the Lua layout.
        ready = ipc('repl', 'return hl.plugin.hyprworld_shared ~= nil and type(hl.plugin.hyprworld_shared.set_enabled) == "function"')
        if ready not in ('true', 'false'):
            raise RuntimeError('Cannot inspect native helper: ' + ready)
        if ready != 'true':
            loaded = json.loads(ipc('-j', 'plugin', 'list'))
            if not isinstance(loaded, list):
                raise RuntimeError('Cannot inspect loaded native plugins')
            if any(isinstance(p, dict) and p.get('name') in
                   ('hyprworld-shared-workspaces', 'hyprscroll2d-shared-workspaces') for p in loaded):
                raise RuntimeError('A workspace helper with an incompatible Lua API is already loaded; unload the old helper before updating')
            result = ipc('plugin', 'load', str(cache / 'shared-workspaces.so'))
            if result != 'ok':
                raise RuntimeError('Native helper load failed: ' + result)
        code = '__hyprworld_native_path = ' + lua_quote(cache / 'shared-workspaces.so') + '; '
    code += 'assert(dofile(' + lua_quote(root / 'integration/plugin.lua') + ') ~= false, "Hyprworld integration unavailable; see compositor log")'
    result = ipc('eval', code)
    if result != 'ok':
        raise RuntimeError(result)
    print(result)


if __name__ == '__main__':
    try:
        load(Path(__file__).resolve().parent)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('Hyprworld bootstrap failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
