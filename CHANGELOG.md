# Changelog

## Hyprworld 0.2.0 - 2026-10-01

### Added

- Launch apps from overview search. Installed apps that match the query and
  have no open window appear as **Launch** cards (setting, on by default). A
  themed, pulsing placeholder appears where the new window will land; the
  camera pans to that slot first, so the window opens without moving anything.
- Search results are preview cards in a grid instead of a text list; arrows
  move through the grid. Result cards grow in and glide when the list reflows.
- Window state details on overview and search cards: floating, fullscreen,
  pinned, tabbed, video or game content, keeping awake, hidden and XWayland
  (setting, on by default). Equal search matches list recent windows first.
- Workspace arrows in the overview for switching with the mouse; they hide
  while searching.
- A more immersive overview transition, all following the overview curve:
  cards cascade out from the selected window and fold back into it, labels
  fade in as cards land, the header and arrows slide in, the wallpaper settles
  from a slight zoom with an adjustable blur, and a ring pulses once around the
  selected card. Each part has a setting; reduced motion turns movement off.
- Animation settings in **Effects**: presets (smooth, snappy, gentle, bouncy,
  instant) and, under advanced or with **custom**, a visual curve editor with
  draggable control points and a preview for every animation. **General**
  curve mode shapes all animations with one curve and a speed multiplier.
  Covers the overview, its workspace switch, tile movement, compaction,
  minimap movement and fade, focus highlight, camera movement, Hyprland's
  workspace slide, the launch pulse, constellation travel and zoom response.
- Minimap styles: **Base**, **Glass** (each card gets its own blurred backdrop,
  10 px by default, adjustable), **Constellation** (glowing stars joined by
  links; the focus glow travels along them) and **Icons** (one large app icon
  per window).
- Live touchpad swipes (setting, on by default). Three fingers move the camera
  with the swipe and spring back when too short; four fingers up/down drive the
  overview transition; four fingers left/right slide the workspace with the
  fingers while its windows fade (the focused one only slightly). On release
  the workspace slides and fades out completely, the switch happens, and the
  destination slides in from the other side and fades in, focused window
  first, so the two workspaces are never visible together. Short swipes slide
  and fade back. New **Swipe commit distance** and **Full swipe distance**.
- `openCustomizerSection` IPC call to open settings on a given page.
- A small workspace trace log (`~/.local/state/hyprworld/workspace-trace.log`,
  capped at 64 KB) to diagnose an intermittent jump to workspace 10.

### Changed

- Animation durations and overview easing moved from Minimap/Overview to
  Effects; saved values migrate and mark the feel as custom when they differ.
- Minimap styles Classic, Elevated and High contrast now map to Base.
- **Swipe threshold** is now **Swipe commit distance**; its default rose from
  40 to 90. Saved values are kept.
- Hyprland's workspace animation (keyboard and bar switching) is a full
  **slide** instead of **slidefade**, which stopped part of the way and cut to
  the next workspace.

### Fixed

- Selecting a window in the overview with the arrow keys and Enter could leave
  Hyprland focus and the camera on the old window while the minimap showed the
  selection. The focus request is now sent once the overview has released the
  keyboard and retried until it lands.
- Search + Enter did nothing or failed to focus the result, on the current and
  on other workspaces.
- Closing the focused window could leave focus nowhere, with the minimap
  highlighting an arbitrary window and the camera not following. The nearest
  neighbour now receives focus and the camera follows it.
- Apps that open and close splash windows while starting pulled focus and the
  camera back through older windows.
- Two quick swipes could leave pointer focus in click mode, and the plugin's
  own pointer handling could re-enable hover focus mid-swipe.

### Known limitations

- Four-finger workspace swipes with the overview open, or on an empty
  workspace, act once on release rather than fading live.
- Glass keeps live captures of the windows under the minimap while shown.
- The intermittent jump to workspace 10 is not yet explained; the trace log
  records the evidence for the next occurrence.

## Hyprworld 0.1.1 - 2026-09-23

First update to Hyprworld.

### Added

- Automatic checkpoints 1.5 seconds after layout changes settle, with atomic
  writes and two older snapshots outside the plugin folder. Restore window
  positions, group order, size presets, alignment, camera and zoom after resets
  within the same compositor session; no application relaunch or reboot restore.
- Smooth minimap fit resizing, including position and scale, with in-flight
  retargeting and respect for animation settings.
- Continuous click-through drag outlines on both source and destination monitors.

### Fixed

- Keep minimap fit stable when focus changes between same-sized windows.
- Send compact drag geometry separately from the tile model; fragment large
  Unicode preview snapshots to fit Hyprland's event socket limit. Keep bounded
  recovery polling for missed events without per-frame IPC polling.
- Declare the native helper on every config generation and retain it on reload.
  Load it explicitly before evaluating the layout, reject incompatible loaded
  helpers, and avoid false-success initialization.
- Guard unsupported APIs and failed initialization, bound IPC/build waits, build
  outside the watched plugin tree, validate malformed settings, and preserve
  visible fallback placement after layout callback errors.
- Read one settings snapshot per layout pass instead of five. The isolated
  settings-read benchmark improved; overall CPU improvement was not established.

### Verification and documentation

- Regression checks cover corrupt checkpoint fallback, session isolation, atomic
  writes, unchanged-save deduplication, event fragmentation and gesture recovery.
- Qt Quick tests cover intermediate fit sizes and retargeting. Isolated full-Service
  checks cover 12 reloads retaining the native handle, three checkpoint resets,
  inactive workspaces, local/remote dragging, workspace swaps and clean removal.
- Updated installation, migration, recovery, publishing and audit documentation.
  Tested baseline: Omarchy 4.0.4, Hyprland 0.56.2 at commit
  `efb50993780079460b0cbed1363e2166a2de1d9f`, Qt 6.11.2.
- The precise cause of the historical desktop freeze remains unproven; these
  checks do not certify every future host version or long-term interaction.

## Hyprworld 0.1.0

First independent release, derived from Hyprscroll2D.

- Rename the plugin, layout, IPC, settings paths, and UI to Hyprworld.
- Add visible groups of up to four windows, drag grouping, and cell swapping.
- Add interactive overview, minimap, continuous wheel zoom, and camera panning.
- Add themed settings, shortcut validation, and configurable mouse focus.
- Add shared workspace IDs, atomic swaps between monitors, and workspace fades.
- Keep overview open across workspace swaps; search window metadata across workspaces.
- Add three/four-finger swipes and two-finger pinch navigation.
- Add custom placement paths with workspace targeting, clickable branches and keyboard editing.
- Add per-group-size layouts, startup templates, readable key capture and conflict outlines.
- Add icon-led settings with animated previews, live appearance controls and draft editing.
- Add delayed compaction and focus/gesture regression coverage.
- Load the native helper explicitly on fresh shell installations and restore native behavior when disabled.
- Fix repeated paths with negative coordinates, template window reuse and startup placement cleanup.
- Define the workspace animation curve independently of theme configuration.
- Rewrite installation, migration, controls, and contributor documentation.

The releases below belong to the original project, not Hyprworld.

## Upstream Hyprscroll2D v0.2.0 - 2026-08-24

- Add native installation through `omarchy plugin add`.
- Reload the layout automatically after a Hyprland configuration reload.
- Add an Omarchy marketplace-compatible service manifest.

## Upstream Hyprscroll2D v0.1.0 - 2026-08-24

First experimental preview.

- Add an infinite two-dimensional grid and camera.
- Add horizontal and vertical focus, movement, swapping, and panning.
- Add independent width and height presets.
- Keep neighboring rows and columns visible with configurable edge peeks.
- Add conditional Omarchy integration for an isolated test workspace.
- Add safe Omarchy install and uninstall scripts with config backups.
- Add core, Hyprland adapter, and Omarchy integration tests.
