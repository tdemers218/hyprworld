# Hyprworld

A two-dimensional scrolling layout for **Hyprland with Omarchy Shell**.
Arrange windows across a grid, group them into visible tiles, and navigate with
an interactive overview, minimap, and smooth camera zoom.

Hyprworld is an independent fork of
[Hyprscroll2D by Kirollos Atef](https://github.com/kirollosatef/hyprscroll2d).
The original layout and integration form its foundation; this fork adds a
substantially expanded grouping, navigation, and settings workflow. See
[CREDITS.md](CREDITS.md) and the preserved [MIT license](LICENSE).

Install this project through Omarchy, not `hyprpm`.

**Status:** 0.1.0, unreleased and experimental. The inherited development baseline
is Hyprland 0.56.2 with the Lua custom-layout API. Compatibility with other
versions is unverified. This repository contains Lua and QML, with no compiled
Hyprland plugin to build.

## Features

- Scrolling and camera movement in both dimensions.
- Groups of two, three, or four visible windows, with drag grouping and swaps.
- Interactive overview with keyboard navigation, dragging, and workspace transitions.
- Minimap with adjustable placement, dimensions, opacity, and outlines.
- Continuous mouse-wheel zoom and keyboard zoom presets.
- Five local workspaces per monitor, with stable saved monitor assignments.
- Themed settings, 19 configurable shortcuts, hover or click focus, and delayed compaction.

## Install

You need an Omarchy installation with its Lua Hyprland configuration, Omarchy
Shell/Quickshell, `omarchy plugin`, and Python 3 for shortcut validation.
The QML interface depends on Omarchy's shell components; it is not a standalone
Quickshell configuration.

Once published at [tdemers218/hyprworld](https://github.com/tdemers218/hyprworld), install with:

```sh
omarchy plugin add https://github.com/tdemers218/hyprworld.git --enable
```

The plugin ID is `io.github.tdemers218.hyprworld`. Do not use the Hyprscroll2D upstream URL: it
installs the original plugin. If migrating, follow [the migration guide](docs/MIGRATING.md)
first; run only one of the two layouts' Omarchy integrations at a time.

Enabling the plugin assigns **five workspaces to every connected monitor** and
replaces the workspace and layout shortcuts listed below. It is not limited to
workspace 9. Monitor order is saved in `~/.config/omarchy/hyprworld-monitors`:
the first monitor owns IDs 1–5, the next 6–10, and so on. The widget displays
local numbers 1–5 on each screen. Disconnected monitors retain their saved bank;
Hyprland may temporarily relocate their workspaces.

Choose the Hyprworld workspaces widget when prompted for bar placement. It can
replace the normal workspace widget through Omarchy's bar configuration.

### First use

1. Press **Super+1** on the focused monitor and open a few windows.
2. Use **Super+Arrow** to focus and **Super+Shift+Arrow** to move or group them.
3. Press **Super+O** to explore the overview; select a card to return to it.
4. Press **Super+Shift+L** to open settings.

## Controls

| Action | Default binding |
| --- | --- |
| Focus a window | Super+Arrow |
| Move, group, detach, or swap | Super+Shift+Arrow |
| Shrink width / height | Super+Alt+Left / Up |
| Grow width / height | Super+Alt+Right / Down |
| Toggle default / maximum tile size | Super+Alt+F |
| Zoom in / out | Super+Ctrl+Up / Down |
| Smooth zoom | Super+mouse wheel |
| Pan camera | Super+middle mouse drag |
| Move or group with pointer | Super+left mouse drag |
| Toggle overview | Super+O |
| Open settings | Super+Shift+L |
| Select local workspace 1–5 | Super+1–5 |
| Move window to local workspace and follow | Super+Shift+1–5 |
| Move window without following | Super+Shift+Alt+1–5 |
| Previous / next local workspace | Super+Ctrl+Left / Right |
| Previous workspace on this monitor | Super+Ctrl+Tab |
| Next / previous monitor | Super+Tab / Super+Shift+Tab |

Workspace number bindings use physical number-row keycodes. Workspace stepping
stops at the ends of each monitor's bank. Number-row shortcuts for 6–0 and the
stock whole-workspace monitor movement shortcuts are unbound while enabled.
Some other Omarchy shortcuts are replaced too; inspect the Shortcuts tab and
`integration/omarchy.lua` before adapting an existing custom keymap. Outside the
layout, only actions with an explicit fallback retain their normal behavior.

### Groups and overview

Dropping a window onto another creates or extends a group. Two windows share
halves, three use one half and two quarters, and four use quarters. A full
four-window destination swaps complete cells. These groups are visible tiles,
not native Hyprland tab groups. Moving a member outward detaches it; moving
within a group swaps member positions. Dragging across monitors cancels the gesture.

In overview, arrows select, Shift+arrows move/group, Alt+arrows resize, and
left-drag moves cards. Super+middle-drag pans. The configured workspace shortcuts
also work, including on empty workspaces. Click a card, press Enter/Escape, or
zoom in to return to the selected window. Click empty space or toggle overview
to close it.

## Settings

Open settings with **Super+Shift+L**. **Apply** or **Ctrl+S** saves the draft;
**Revert** discards it. Closing the panel preserves unsaved edits until the shell
restarts. Sections can restore defaults.

- **Minimap:** enable, corner, insets, maximum dimensions, opacity, and outline weight.
- **Overview:** animation duration, wallpaper, and card opacity.
- **Mouse/workflow:** hover or click focus, hover cooldown, connected layout, and compaction delay.
- **Shortcuts:** edit the 19 layout/settings actions; validation checks key names,
  keycodes, duplicate actions, and active binding conflicts.
- **Plugin:** disable/re-enable and refresh the shell. The settings controller
  remains accessible when the layout is disabled through this panel.

Settings are stored in `~/.config/omarchy/hyprworld.json`. Appearance and mouse
changes apply without a compositor reload; shortcut changes reload Hyprland.
Disabling/re-enabling also changes the workspace layout and refreshes the shell.
**Hyprland reloads reset in-memory window groups and camera/layout state.**

Advanced geometry defaults live in [layout/config.lua](layout/config.lua): edge
peeks, gaps, width/height presets, initial dimensions, and zoom presets. Reload
Hyprland after editing. Keep a copy of custom changes before updating the plugin.

An optional custom launcher can receive Up/Down navigation by setting
`HYPRWORLD_LAUNCHER_IPC` in Hyprland's environment to its shell IPC target. It must
implement `moveSelected` and return `handled` when it consumes navigation.
No personal launcher is required by default.

## Update, disable, or uninstall

```sh
omarchy plugin update io.github.tdemers218.hyprworld
```

For a temporary pause, disable it in its settings panel; use the same shortcut
to re-enable. To remove the plugin:

```sh
omarchy plugin remove io.github.tdemers218.hyprworld --yes
hyprctl reload
hyprctl configerrors
```

Preferences and saved monitor order remain in `~/.config/omarchy/` so they can be
reused. Removing the shell plugin makes its settings shortcut unavailable.

## Troubleshooting

- **Nothing appears:** confirm the plugin is enabled and inspect
  `hyprctl configerrors`. Verify your Hyprland supports the Lua layout API.
- **Wrong workspaces or duplicated bindings:** disable the previous Hyprscroll2D
  integration and check for a manually installed config block; see migration.
- **Settings will not apply:** resolve highlighted shortcut conflicts first.
- **Groups disappear after reload:** group state is currently in memory only.
- **Layout loads but no settings/overview:** use the full Omarchy shell plugin;
  the config installer loads only the Lua integration.

Fullscreen, native Hyprland groups, cross-monitor moves, special workspaces, and
mixed monitor setups need further live testing. Automated checks use compositor
mocks; they do not establish compatibility with your compositor release.

Report fork-specific problems in **this repository's Issues tab** with versions,
monitor geometry, reproduction steps, and relevant configuration errors.

## Other installation and development

[Advanced installation](docs/INSTALLATION.md) covers the config-only installer
and the Lua entry point. [Migration](docs/MIGRATING.md) explains renamed settings
and identifiers. [Contributing](CONTRIBUTING.md) covers testing and bug reports;
[design notes](docs/DESIGN.md) explain the implementation.

Run the automated suite with Lua 5.4, Python 3, Node.js, Bash, and Make installed:

```sh
make check
```

See [CHANGELOG.md](CHANGELOG.md) for the fork's changes and upstream history.
