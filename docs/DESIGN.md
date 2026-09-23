# Layout design

## Grid and camera

Each workspace has an integer grid of cells. A cell contains one to four tiled
windows. Columns and rows are sized from their contents; width and height
presets, gaps, and edge peeks determine placement. The camera pans in both axes
and zoom scales the workspace. Keyboard zoom uses presets; wheel zoom is continuous.

New windows extend the grid to the right unless a placement path or startup
template supplies their positions. Custom paths support grouping capacity and
repeat/extend overflow; repeated paths use their full coordinate span. Directional focus prefers aligned
neighbors. Focus can pan the camera to expose a target; manual panning also
allows exploring the canvas. Hover focus and click focus are configurable.

## Groups and movement

An occupied destination forms or extends a group. By default, two members use halves;
three use one half and two quarters; four use quarters. These are visible layout
tiles, separate from native Hyprland tab groups. Moves within a group reorder
members; moving outward detaches a member. A full destination swaps complete
cells. Per-size settings override the default partitions. Mouse gestures and
overview use the same grouping model.

Optional delayed compaction keeps cells connected after changes. It waits for
idle time rather than rearranging the grid during a held drag.

## Overview and minimap

The Lua adapter emits snapshots consumed by the QML overlays. Overview supports
keyboard navigation, drag operations, and transitions between workspaces,
including empty workspaces. Closing it releases the keyboard grab before
committing the selected window's focus. The minimap tracks canvas geometry and
camera position. Fit geometry is retained across same-sized focus changes.
`MinimapFitMotion.qml` interpolates the fitted position, dimensions and scale
from the current frame, so retargeting does not snap. Global animation settings
and the minimap movement duration control this transition.

Full snapshots use UTF-8-safe fragments with at most 900 payload bytes when they
exceed the event budget. `PreviewStream.js` bounds and reassembles them, rejecting
stale revisions. Pointer ticks publish a separate compact ghost/drop frame;
they do not rebuild the tile model or re-place real windows. Click-through
surfaces draw local and cross-monitor outlines in logical monitor coordinates.
A two-second recovery poll handles missed events; it is not the animation clock.
Visual preferences live outside the watched plugin directory.

## Monitor workspaces

Workspace IDs are shared across monitors. Explicitly requesting a visible remote
workspace atomically swaps it with the requesting monitor's active workspace.
Requesting a hidden remote workspace moves it to that monitor. Explicit monitor
or window focus does not swap workspaces. The C++ helper intercepts workspace
requests and preserves spatial animation offsets during rapid reversals.

The bar shows 1–5, occupied higher IDs, and the current workspace even when empty.
No monitor-order file is used. The helper remains loaded across Lua reloads;
the config declares its path on every generation and explicitly sets its enabled
state. Bootstrap uses bounded native IPC to load before Lua evaluation, builds in
the user cache, and rejects a conflicting loaded API. Changed native code is
activated in a new compositor session, not by routine hot-unloading.

## Settled checkpoints

`layout/checkpoint.lua` captures only persistent arrangement data; `Service.qml`
debounces change notifications for 1.5 seconds and runs `checkpoint.py` outside the
compositor. The writer atomically saves bounded JSON with two older copies and
skips identical data. Restoration is scoped to the running compositor, handles
incremental window discovery, and retains unvisited workspace records.
See [layout recovery](LAYOUT-RECOVERY.md) for fields, paths and failure limits.

## Code map

- `layout/core.lua`: geometry, navigation, groups, camera, and compaction.
- `layout/gestures.lua`: pointer gesture calculations.
- `layout/init.lua`: Hyprland adapter, focus, events, and overview state.
- `layout/preferences.lua`: layout preference access.
- `bootstrap.py`: explicit native plugin loading before Lua evaluation.
- `integration/plugin.lua`: layout/bootstrap guard and helper enable state.
- `integration/omarchy.lua`: settings shortcut and layout bindings.
- `integration/workspaces.lua`: shared workspace and monitor navigation.
- `Service.qml`: service startup, settings IPC and debounced checkpoint scheduling.
- `layout/checkpoint.lua`, `checkpoint.py`: validated restoration and atomic saving.
- `Preview.qml`, `MinimapSurface.qml`: overview, minimap and drag surfaces.
- `MinimapMotion.qml`, `MinimapFitMotion.qml`, `OverviewMotion.js`: visual motion.
- `MinimapLayout.js`: fit geometry and invalidation.
- `PreviewStream.js`: bounded snapshot and gesture event transport.
- `Customizer.qml`, `Settings.js`, `SettingsPreview.qml`: settings UI and defaults.
- `Workspaces.qml`: shared workspace bar widget.
- `validate-shortcuts.py`: readable keycode names and complete conflict reports.
- `ArrangementEditor.qml`, `StartupEditor.qml`: visual placement and startup editors.
- `SettingsIcon.qml`: theme-colored Canvas icons.
- `startup.py`: capture, matching, launching and per-session startup guard.
- `integration/touchpad.lua`: touchpad gesture translation.
- `native/shared-workspaces.cpp`: workspace interception and swap animation.

See the README for current controls and CONTRIBUTING.md for verification.
