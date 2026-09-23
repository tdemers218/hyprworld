# Layout checkpoints and recovery

The full Hyprworld shell service saves a small checkpoint about **1.5 seconds
after layout changes stop**. A held gesture, zoom operation or pending compaction
can defer the save. Unchanged state is not rewritten, and idle use does not run a
periodic saving process. Startup also requests a checkpoint.

## What is restored

For matching open windows in each workspace, checkpoints retain grid positions,
group member order, width/height preset indices and alignment. They also retain
the workspace camera and zoom. Restoration handles windows arriving in a different
order after a Lua reset, and preserves checkpoints for inactive workspaces until
their layout callbacks run. Each window is restored once per layout instance,
so a later user move is not overwritten. Saved positions take precedence over
startup template placement for those restored windows.

The checkpoint belongs to the **same running compositor process**, identified by
boot ID, process ID and process start time. It is meant for config reloads,
shell/plugin recreation and plugin resets while the windows remain open.
It does not reopen applications, recreate closed windows, or restore after logout,
a compositor crash, reboot, or migration to a different plugin namespace.
Startup templates remain the feature for launching a planned workspace.

A reset before the first successful save has nothing to recover. A reset during
active changes can restore the last settled checkpoint, losing newer unsaved
moves. Saving requires the full QML Service, Python 3, working Hyprland IPC and a
writable state directory. Config-only installations do not start the saver.

## Files and failure behavior

The directory is `$XDG_STATE_HOME/hyprworld/`, falling back to
`~/.local/state/hyprworld/`:

| File | Purpose |
| --- | --- |
| `layout.json` | Latest settled checkpoint |
| `layout.json.1`, `layout.json.2` | Two older valid checkpoints |
| `checkpoint.lock` | Prevents concurrent writers |

These files sit outside the plugin checkout, so updating or replacing plugin
files does not remove them. Preferences are separate in
`~/.config/omarchy/hyprworld.json`. Legacy compatibility installations use
`hyprscroll2d` in those paths; public Hyprworld does not import them automatically.

Writes run in a separate bounded Python process, use a private temporary file,
flush to disk, and atomically replace the destination. Checkpoint files are mode
0600; a newly created state directory is mode 0700. Payloads are limited to 1 MiB.
The reader treats JSON as data and tries the older copies when the primary file
cannot be decoded or has an incompatible session/schema. Invalid window records
are skipped. File or IPC errors are logged and do not stop the compositor.

The saved data contains window identifiers and geometry, not window titles,
application launch commands or screenshots. To diagnose a failed save, inspect
shell logs for `Hyprworld checkpoint`, confirm the state directory is writable,
and check `hyprctl configerrors`. File modification time should stop changing
when the arrangement is idle.

## Verified behavior

Unit tests cover incremental restoration, subsequent user moves, malformed
records, corrupt primary fallback, session isolation, file permissions, failed
atomic replacement, history rotation and unchanged-state deduplication.
`tests/live_package.py` runs `tests/live_checkpoint.py` in an isolated compositor:
real groups, sizes, zoom and camera survive three full Lua resets; an inactive
workspace survives and restores on activation; identical saves do not rewrite.
The September 23 live source update also restored all ten existing windows
exactly and left the native helper loaded.
