#!/usr/bin/env python3
"""Save settled compositor state atomically, outside its event loop/plugin tree."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

LIMIT = 1024 * 1024

def atomic_write(path, data):
    fd, name = tempfile.mkstemp(prefix='.checkpoint-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        if os.path.exists(name): os.unlink(name)

def save(path, state):
    if not isinstance(state, dict) or state.get('version') != 1 or not isinstance(state.get('scope'), str) or not isinstance(state.get('workspaces'), dict):
        raise ValueError('Invalid checkpoint')
    raw = (json.dumps(state, sort_keys=True, separators=(',', ':'), allow_nan=False)+'\n').encode()
    if len(raw) > LIMIT: raise ValueError('Checkpoint exceeds size limit')
    def bounded_read(file):
        if not file.exists(): return None
        with file.open('rb') as handle: data = handle.read(LIMIT+1)
        return data if len(data) <= LIMIT else None
    previous = bounded_read(path)
    if previous == raw: return False
    # Retain two older valid snapshots. Corrupt files never displace good history.
    if previous:
        try:
            old = json.loads(previous)
            valid = old.get('version') == 1 and isinstance(old.get('workspaces'), dict)
        except (ValueError, AttributeError): valid = False
        if valid:
            first = Path(str(path)+'.1')
            older = bounded_read(first)
            if older:
                try:
                    history = json.loads(older)
                    if history.get('version') == 1 and isinstance(history.get('workspaces'), dict):
                        atomic_write(Path(str(path)+'.2'), older)
                except (ValueError, AttributeError): pass
            atomic_write(first, previous)
    atomic_write(path, raw)
    return True

def main():
    directory = Path(os.environ.get('XDG_STATE_HOME') or Path.home()/'.local/state')/'hyprworld'
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory/'checkpoint.lock').open('a') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: return 0
        result = subprocess.run(['hyprctl','repl','return __hyprworld_checkpoint and __hyprworld_checkpoint() or "null"'], capture_output=True, text=True, check=True, timeout=5)
        if len(result.stdout.encode()) > LIMIT: raise ValueError('Checkpoint exceeds size limit')
        state = json.loads(result.stdout)
        if state is None: return 0
        if isinstance(state, dict) and state.get('busy'): return 75
        save(directory/'layout.json', state)
    return 0

if __name__ == '__main__':
    try: sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('Hyprworld checkpoint: '+str(error), file=sys.stderr)
        sys.exit(1)
