# Layout design

## Grid and camera

Each workspace has an integer grid of cells. A cell contains one to four tiled
windows. Columns and rows are sized from their contents; width and height
presets, gaps, and edge peeks determine placement. The camera pans in both axes
and zoom scales the workspace. Keyboard zoom uses presets; wheel zoom is continuous.

New windows extend the grid to the right. Directional focus prefers aligned
neighbors. Focus can pan the camera to expose a target; manual panning also
allows exploring the canvas. Hover focus and click focus are configurable.

## Groups and movement

An occupied destination forms or extends a group. Two members use halves;
three use one half and two quarters; four use quarters. These are visible layout
tiles, separate from native Hyprland tab groups. Moves within a group reorder
members; moving outward detaches a member. A full destination swaps complete
cells. Mouse gestures and overview use the same grouping model.

Optional delayed compaction keeps cells connected after changes. It waits for
idle time rather than rearranging the grid during a held drag.

## Overview and minimap

The Lua adapter emits snapshots consumed by the QML overlays. Overview supports
keyboard navigation, drag operations, and transitions between workspaces,
including empty workspaces. Closing it releases the keyboard grab before
committing the selected window's focus. The minimap tracks canvas geometry and
camera position. Visual preferences live outside the watched plugin directory.

## Monitor workspaces

Each monitor connector has a saved position in an ordered list and owns five
workspace IDs: 1–5, 6–10, and so on. The bar displays local numbers 1–5. Saved
connector order survives reloads and reconnects. Workspace assignments are
persistent, but window groups and camera state remain in memory and reset on
Hyprland configuration reload.

## Code map

- `layout/core.lua`: geometry, navigation, groups, camera, and compaction.
- `layout/gestures.lua`: pointer gesture calculations.
- `layout/init.lua`: Hyprland adapter, focus, events, and overview state.
- `layout/preferences.lua`: layout preference access.
- `integration/plugin.lua`: shell bootstrap and reload guard.
- `integration/omarchy.lua`: settings shortcut and layout bindings.
- `integration/workspaces.lua`: monitor banks and local workspace navigation.
- `Service.qml`: service startup and settings IPC.
- `Preview.qml`, `MinimapMotion.qml`: overview and minimap.
- `Customizer.qml`, `Settings.js`, `SettingsPreview.qml`: settings UI and defaults.
- `Workspaces.qml`: per-monitor workspace bar widget.
- `validate-shortcuts.py`: key-name and conflict validation.

See the README for current controls and CONTRIBUTING.md for verification.
