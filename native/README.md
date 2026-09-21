# Shared-workspace helper

Build with `make native` using headers matching the running Hyprland. The helper
checks the commit hash before installing its hook. It must be rebuilt after a
Hyprland upgrade; `make check` does not build native code.

The hook wraps `Config::Actions::changeWorkspace(PHLWORKSPACE)`. Remote visible
workspaces use Hyprland's atomic swap; remote inactive workspaces move to the
requesting monitor. Special workspaces and explicit monitor/window focus retain
native behavior. Animation offsets use logical monitor positions and retain
in-flight offsets for rapid reversals. The shell explicitly enables/disables the
hook when its plugin setting changes. Unloading removes the hook.

Tested against Hyprland 0.56.2, commit efb50993780079460b0cbed1363e2166a2de1d9f.
Native integration tests require an **isolated nested compositor**, with its
WAYLAND-1 output plus an output named HWTEST created using `hyprctl -i INSTANCE
output create headless HWTEST`. Load the built helper into that instance first.
The tests change monitor positions and workspaces, so do not use your desktop's
instance ID.

```
python3 tests/live_workspace_swap.py INSTANCE
python3 tests/live_workspace_windows.py INSTANCE
python3 tests/live_overlay.py INSTANCE
```

These cover workspace identity, numeric requests, repeated swaps, explicit
monitor focus, inactive remote workspaces, actual terminal placement under the
Lua layout, native animation direction/completion in five monitor arrangements,
overlay suppression while one or more screensaver windows exist, and restoring
native workspace requests when the helper is disabled.

The full service/package lifecycle test starts its own isolated compositor and
temporary home, rather than accepting an instance ID:

```sh
python3 tests/live_package.py
```

It requires the built helper, Quickshell and Omarchy's installed shell components.
It checks the public package ID, actual native loading, Lua registration, settings
opening, preferences, disable/re-enable, and explicit native removal.
