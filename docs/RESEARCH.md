# Historical upstream research notes

These notes are preserved from Hyprscroll2D, which records research against
Hyprland 0.56.2 on 2026-08-24. They describe the original design investigation,
not a current survey or compatibility guarantee. Project status may have changed.
Current Hyprworld also uses a native C++ workspace helper; the original pure-Lua
design choice below does not describe the full current package. See
[the current design](DESIGN.md) and [compatibility audit](COMPATIBILITY-AUDIT.md).

## Existing projects

- Hyprland's built-in scrolling layout is an infinitely growing one-axis tape.
- `dawsers/hyprscroller` is feature-rich but one-axis and archived.
- `kuroiko0429/hyprscroller-ng` is maintained but remains column-based.
- `outfoxxed/hy3` provides mature manual two-dimensional tiling without an
  infinite scrolling viewport.
- `shawnmurali/hyprortholayout` provides orthogonal stacks without scrolling.
- `ForgeDuSavoir/fit-scroller-layout` is the strongest Lua reference. Its
  spatial mode supports directional geometry but deliberately allows overflow
  on only one configured axis.
- `aaronsb/hypr-canvas` is a compiled C++ plugin providing a continuous,
  zoomable and pannable canvas. It transforms compositor coordinates rather
  than arranging windows into a tiled grid.
- `HarryC913/hyprplane` is a compiled C++ canvas-mode plugin with freeform
  floating windows, multi-monitor panning, an overview and a minimap.
- `sarodscommits/hyprland-infinitie-desktop-v2` and `rippelz/infiniscroll`
  provide floating-window canvas workflows using external Python, shell and
  Rust processes.
- `lonelyobserver0/infinite_desk` is a compiled continuous-canvas plugin that
  explicitly avoids grids, cells and snapping.

Several maintained projects therefore explore the broader infinite-canvas
idea. No project found during the search matched Hyprscroll2D's specific
combination: a pure-Lua `hl.layout.register` layout, discrete tiled cells,
independent horizontal and vertical size presets, two-axis edge peeks and
native Omarchy plugin packaging.

## Technical choice

Hyprland 0.56.2 exposes `hl.layout.register`, layout messages, target window
metadata and `target:place({ x, y, w, h })`. The implementation forwards those
coordinates to global target positioning without clamping them to one axis.

This makes an independent X/Y camera feasible in a Lua custom layout. Lua is
preferred over a compiled plugin because compiled Hyprland plugins must closely
match the running compositor ABI and can reduce compositor stability.

## References

- https://wiki.hypr.land/Configuring/Layouts/Custom-Layouts/
- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
- https://github.com/hyprwm/Hyprland/tree/v0.56.2/example/layouts
- https://github.com/ForgeDuSavoir/fit-scroller-layout
- https://github.com/dawsers/hyprscroller
- https://github.com/kuroiko0429/hyprscroller-ng
- https://github.com/outfoxxed/hy3
- https://github.com/shawnmurali/hyprortholayout
- https://github.com/aaronsb/hypr-canvas
- https://github.com/HarryC913/hyprplane
- https://github.com/sarodscommits/hyprland-infinitie-desktop-v2
- https://github.com/rippelz/infiniscroll
- https://github.com/lonelyobserver0/infinite_desk
