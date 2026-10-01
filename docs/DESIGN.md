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

The overview transition runs on linear time. Each element applies the overview
curve to its own phase (`OverviewMotion.phase`), so the card cascade from the
selected tile, staged labels and header motion keep the chosen curve without
lengthening the duration. A four-finger swipe drives that timeline directly
through a small `hyprworld-overview-swipe` event; on release the remaining
motion animates from the finger position.

Animation durations and curves come from the effects settings through
`Settings.effective()`, which also applies the general curve mode. Curves are
named or custom cubic beziers; QML uses bezier easing, and the Lua integration
registers matching Hyprland curves for camera movement (`windowsMove`) and the
workspace slide.

Minimap styles: Base and Icons are drawn by the tile delegates; Constellation
(`MinimapConstellation.qml`) draws a spanning tree of the window centres and
animates focus along the tree path; Glass (`GlassBackdrop.qml`) rebuilds the
backdrop from the wallpaper and live captures of only the windows under the
minimap, blurs it at the configured radius and masks it to the cards, because
Hyprland's layer blur has one global size.

Launching an app from search asks the layout to predict the new window's box by
running the real placement on a copy of the state (`core.predict_new`). The
camera pans to that slot, the overlay draws a placeholder there, and focus
changes to older windows are ignored briefly while the app maps and unmaps
splash windows.

Full snapshots use UTF-8-safe fragments with at most 900 payload bytes when they
exceed the event budget. `PreviewStream.js` bounds and reassembles them, rejecting
stale revisions. Pointer ticks publish a separate compact ghost/drop frame;
they do not rebuild the tile model or re-place real windows. Click-through
surfaces draw local and cross-monitor outlines in logical monitor coordinates.
A two-second recovery poll handles missed events; it is not the animation clock.
Visual preferences live outside the watched plugin directory.

## Touchpad

Three-finger swipes call `swipe-begin`, `swipe-update` and `swipe-end`. The
layout computes the camera shift to the neighbour the swipe would focus
(`core.swipe_shift`), moves the camera by the finger progress with Hyprland's
window animation paused and pointer focus held at click mode, then either
focuses the neighbour (which lands where the preview ended) or restores the
camera. Progress is signed by the first movement, so it works with either
scroll direction.

Four-finger left/right swipes (`workspace-swipe-*`) move the camera by up to
30% of the monitor width with the fingers and fade windows through ten opacity
steps by tagging them `hyprworld-fade-1`…`10`; window rules registered by
`integration/omarchy.lua` map the tags to opacity, and removing a tag restores
the window's own rules exactly. The focused window fades at most 35% while the
fingers move. On release a 16 ms ticker (`workspace-swipe-tick`) runs the
rest with the workspace curve (`layout/motion.lua`): the outgoing workspace
slides and fades to invisible, its camera returns unseen, the destination is
tagged invisible and offset to the other side, the shared workspace steps with
Hyprland's own slide disabled, and the destination slides and fades in (focused
window first). A cancel animates back. Focus events do not move the camera
during the transition, and pointer focus is held at click mode.

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
- `layout/motion.lua`: animation curves and durations shared by Lua motion.
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
- `integration/touchpad.lua`: touchpad gesture translation and live swipes.
- `Search.js`: fuzzy search, launchable apps and window state details.
- `CurveEditor.qml`: visual animation curve editor used by the settings rows.
- `GlassBackdrop.qml`, `MinimapConstellation.qml`: Glass and Constellation minimap styles.
- `native/shared-workspaces.cpp`: workspace interception and swap animation.

See the README for current controls and CONTRIBUTING.md for verification.
