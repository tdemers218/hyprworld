#!/usr/bin/env python3
"""Load the native helper before evaluating the shell's Lua integration."""
import json
import subprocess
import sys
from pathlib import Path

from startup import quote


def ctl(*args):
    result = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=15, check=True)
    output = result.stdout.strip()
    if output.lower().startswith('error'):
        raise RuntimeError(output)
    return output


def bootstrap(root, preferences):
    settings = json.loads(preferences.read_text()) if preferences.exists() else {}
    if settings.get('plugin', {}).get('enabled', True):
        helper = root / 'native/build/shared-workspaces.so'
        if not helper.is_file():
            raise RuntimeError(f'Native helper missing. Run make -C {root} native, then reload Hyprland.')
        if ctl('repl', 'return type(hl.plugin.hyprworld_shared)') != 'table':
            result = ctl('plugin', 'load', str(helper))
            if ctl('repl', 'return type(hl.plugin.hyprworld_shared)') != 'table':
                raise RuntimeError('Could not load the native helper: ' + result)
    ctl('eval', 'dofile(' + quote(root / 'integration/plugin.lua') + ')')


if __name__ == '__main__':
    try:
        bootstrap(Path(__file__).resolve().parent, Path.home() / '.config/omarchy/hyprworld.json')
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('Hyprworld: ' + str(error), file=sys.stderr)
        sys.exit(1)
