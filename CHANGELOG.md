# Changelog

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
