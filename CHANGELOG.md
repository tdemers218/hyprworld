# Changelog

## Hyprworld 0.1.1 — prepared for release

First update to Hyprworld. Set the publication date when releasing.

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
