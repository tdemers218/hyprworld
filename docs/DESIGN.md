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
camera position. Visual preferences live outside the watched plugin directory.

## Monitor workspaces

Workspace IDs are shared across monitors. Explicitly requesting a visible remote
workspace atomically swaps it with the requesting monitor's active workspace.
Requesting a hidden remote workspace moves it to that monitor. Explicit monitor
or window focus does not swap workspaces. The C++ helper intercepts workspace
requests and preserves spatial animation offsets during rapid reversals.

The bar shows 1–5, occupied higher IDs, and the current workspace even when empty.
No monitor-order file is used. Groups and camera state remain in memory and reset
on configuration reload. The helper remains loaded across Lua reloads; the plugin
sets its enabled state explicitly, and removal/update must unload the binary.

## Code map

- `layout/core.lua`: geometry, navigation, groups, camera, and compaction.
- `layout/gestures.lua`: pointer gesture calculations.
- `layout/init.lua`: Hyprland adapter, focus, events, and overview state.
- `layout/preferences.lua`: layout preference access.
- `bootstrap.py`: explicit native plugin loading before Lua evaluation.
- `integration/plugin.lua`: layout/bootstrap guard and helper enable state.
- `integration/omarchy.lua`: settings shortcut and layout bindings.
- `integration/workspaces.lua`: shared workspace and monitor navigation.
- `Service.qml`: service startup and settings IPC.
- `Preview.qml`, `MinimapMotion.qml`: overview and minimap.
- `Customizer.qml`, `Settings.js`, `SettingsPreview.qml`: settings UI and defaults.
- `Workspaces.qml`: shared workspace bar widget.
- `validate-shortcuts.py`: readable keycode names and complete conflict reports.
- `ArrangementEditor.qml`, `StartupEditor.qml`: visual placement and startup editors.
- `SettingsIcon.qml`: theme-colored Canvas icons.
- `startup.py`: capture, matching, launching and per-session startup guard.
- `integration/touchpad.lua`: touchpad gesture translation.
- `native/shared-workspaces.cpp`: workspace interception and swap animation.

See the README for current controls and CONTRIBUTING.md for verification.
