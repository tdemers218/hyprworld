# Settings reference and design decisions

The settings window uses an icon-led sidebar, a searchable control catalog,
section defaults, draft edits, and persistent Apply/Revert controls. Wide screens
keep a preview beside the controls; smaller screens place it inside the scrolling
content. Icons are drawn locally so they do not depend on an installed icon theme.
Text remains for ambiguous concepts and accessible names.

## Review decisions

- Keep existing preferences and shortcuts. New behavior is opt-in: placement paths
  and automatic startup launching are disabled until configured.
- Every exposed control must change real behavior. Do not show placeholder controls
  for unfinished rendering or input features.
- Groups currently support 2–4 windows. Increasing that requires changes throughout
  drag, swap, geometry, and navigation; the editor must reflect the current limit.
- Path tiles are ordered coordinates, with per-tile group capacity. Branches are
  created by adding neighbors; explicit order removes ambiguity at a fork. Overflow
  either extends the layout or repeats the pattern. Vacancy filling is optional.
- Startup templates use exact application classes and explicit launch commands.
  Capturing a workspace never guesses commands. Existing matching windows are
  reused; unrelated windows are not closed. The session marker prevents shell
  reloads from repeatedly launching a saved startup set.
- Schema validation clamps dimensions, group ratios, positions and capacities.
  Settings are decoded as JSON data, never executed as Lua.

## Available controls

| Section | Working controls |
| --- | --- |
| Minimap | Visibility exceptions, fixed/fit sizing, fit maximum dimensions, position, size, borders, corners, fill/backdrop opacity, custom colors, icons, titles, workspace label, click-to-focus, movement/fade durations |
| Overview | Open/close and workspace transition timing, easing, reduced motion, wallpaper dimming, card/group sizes, spacing, corners, colors, labels, title font size, search scope/metadata, empty-space exit |
| Flow | Compaction delay and move/removal triggers, focused-tile anchoring, click/hover focus, hover cooldown, gaps, edge peeks, initial dimensions, gesture threshold and pinch sensitivity |
| Placement paths | Horizontal/vertical/custom, visual numbered editor, branching, tile capacity, order, vacancy filling, extend/repeat overflow |
| Group layouts | Independent 2/3/4-window presets: columns, rows, grid, master-left, master-right, master-top; master proportion slider and draggable divider |
| Startup workspaces | Named templates, workspace/monitor, app commands and matching classes, position/group coordinates, zoom, capture, manual launch, opt-in session startup |
| Shortcuts | Fuzzy search by action/binding, all/customized filter, edit or keyboard capture, individual defaults, conflict validation |
| Plugin | Enable/disable, shell refresh, original-plugin credits |

Appearance and layout settings apply without a configuration reload. Shortcut or
plugin-enable changes reload Hyprland; settled checkpoints restore matching open
windows within that compositor session. See [layout recovery](LAYOUT-RECOVERY.md).
Automatic checkpoints are separate from startup templates and require no settings
switch. Fit resizing glides with the minimap movement duration; equal-sized focus
changes retain the fit. Disabled animations or zero duration make it immediate.
Placement changes govern newly placed windows. Startup template arrangements match
new windows on their configured workspace; manually launching a template can reuse
matching windows from another workspace. If a preferred monitor is absent, normal
workspace assignment is used. Capture includes the tiled windows in the layout.

## Remaining ideas from the broad plan

These remain design proposals, not inactive switches in the UI:

- Per-monitor overrides, all-monitor minimaps, additional anchors, idle visibility,
  viewport shading, hover tooltips, and interactive minimap dragging.
- Live window thumbnails/privacy exclusions, multiple overview layout modes,
  simultaneous multi-monitor overview, custom backgrounds, context menus and
  independently configurable entry/exit gestures.
- Named placement profiles, per-workspace/app routing, initial branch selection,
  and a time-based placement simulation.
- Arbitrary split trees, per-group overrides and more than four members.
- Startup launch delays/timeouts, first-access triggers, focus selection,
  application pickers, saved-session restoration and template import/export.
- Multiple bindings per action, device/category filters,
  gesture remapping and profile import/export.

## Verification

`make check` includes schema migration, custom path placement/group capacity,
vacancy reuse, group partition geometry, JSON escapes, startup duplicate detection,
command quoting, malformed nested settings, minimap fit invalidation, checkpoint
recovery, event transport, and the navigation/compaction/shortcut regressions.
Qt Quick tests verify fit-size interpolation and retargeting without snapping.

An isolated compositor also verified settings rendering, fuzzy control search,
draft/revert/save, and real startup command dispatch, target workspace, matching,
position and zoom. Desktop and narrow-screen visual checks precede installation.

## Usability refinements

Custom paths grow from the selected tile using its neighboring + buttons or arrow
keys while the canvas has focus. All-workspace scope is the default; specific
workspace IDs restrict the path, with an empty selection matching none.

Startup templates have a capture-first introduction, numbered steps, a position
preview, and labeled app identifiers, commands, columns and rows. Group master
controls appear only for master layouts. The sidebar preview animates in only for
Minimap and Overview. Shortcut capture inhibits compositor shortcuts while active,
records a physical keycode, and ends on key release; Escape cancels.

Sidebar icons are drawn in `SettingsIcon.qml`: `minimap`, `workflow` (Flow),
and `startup` identify the three customizable drawings.
