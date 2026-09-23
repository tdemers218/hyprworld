# Publishing Hyprworld 0.1.1

The first update is prepared as **0.1.1** in `manifest.json` and
[CHANGELOG.md](../CHANGELOG.md). It is not marked as published. Keep the plugin ID
`io.github.tdemers218.hyprworld`, repository `https://github.com/tdemers218/hyprworld`,
manifest version and release tag consistent. No publishing step is automatic.

## Completed checks for this candidate

The documentation pass also passed `make check`, `omarchy plugin validate .`,
local link/heading checks, release-version consistency and `git diff --check`.

The September 23 implementation checks passed `make check`, the Qt Quick motion
suite and the full isolated `tests/live_package.py` lifecycle test. Coverage
includes native loading, settings opening, large Unicode event delivery,
12 reloads retaining the native handle, three checkpoint resets including an
inactive workspace, no unchanged-save rewrites, local/remote outlines, workspace
swaps and native removal. The live source update restored ten existing windows
exactly and retained the native helper. See [compatibility](COMPATIBILITY-AUDIT.md),
[performance](PERFORMANCE-AUDIT.md) and [recovery](LAYOUT-RECOVERY.md) for limits.

Earlier settings Apply/Revert and startup launching checks are documented in
[the settings reference](SETTINGS-OVERHAUL.md). They are separate checks, not
features exercised by every package-lifecycle run. CPU measurements predate the
latest additions; there is no demonstrated overall CPU reduction for this release.

## Before publishing

1. Review `git status --short` and the complete diff, including new untracked
   source/test files and `preview.png`. Include all new QML/JS, Lua and Python
   dependencies. Exclude native build output, user preferences/checkpoints,
   temporary files, logs and private screenshots. Do not stage the sibling local
   audit directory.
2. Run `make check` and `omarchy plugin validate .` on the final tree. For code
   changes after the recorded checks, repeat `make native`, the Qt Quick motion
   test and `python3 tests/live_package.py` as described in
   [CONTRIBUTING.md](../CONTRIBUTING.md). Use only isolated sessions for live tests.
3. Review installation, update, migration and removal instructions. Native code
   changes need a new compositor session. Do not replace them with a routine
   live-hook unload command. Only a same-session settled checkpoint can recover
   an existing arrangement; the first upgrade from pre-checkpoint code has none.
4. Set the actual publication date in the 0.1.1 changelog heading. Commit the
   reviewed release tree to this fork. Inspect `git remote -v` before pushing;
   do not push fork changes to Hyprscroll2D upstream.
5. Push your reviewed branch and create the matching `v0.1.1` tag/release on your
   repository. Use the changelog or release text below for the notes.
6. Check the Omarchy listing points to this repository and reflects the new
   manifest/README. Follow the marketplace's current maintenance/submission
   process if a listing change is needed; pushing a tag does not itself establish
   listing approval or immediate refresh.

GitHub CI runs compositor-independent checks. It does not compile the native
helper, run QML rendering, or certify a new Hyprland version. Rebuild and repeat
live checks for each supported compositor upgrade.

## Marketplace details

The [official publishing guide](https://plugins.omarchy.org/publish.html)
requires a public repository, root manifest, README, license and safe install/removal.
For a new listing, submit the repository link, category and tags through its issue
form; automated validation precedes maintainer approval. Marketplace validation
is not a security audit. The guide was checked on September 23, 2026.

Category: **Compositor**. Suggested tags: **Hyprland**, **workspaces**, **layout**,
**overview**, **productivity**.

Suggested listing copy:

> A two-dimensional scrolling workspace for Hyprland on Omarchy. Arrange windows
> in visible groups, search an animated overview, and navigate with a minimap,
> keyboard or touchpad. Includes continuous cross-monitor drag outlines, smooth
> minimap fit resizing, custom opening paths, group layouts and startup templates.
> Automatic settled checkpoints recover open-window arrangements after plugin
> resets within the same desktop session.

Make the requirements visible: tested with **Omarchy 4.0.4, Hyprland 0.56.2
(commit efb50993780079460b0cbed1363e2166a2de1d9f), Qt 6.11.2**. Requires the Lua
layout API, Omarchy Shell, Python 3, a C++23 compiler, Make/pkgconf and exact-match
Hyprland headers for the native helper. This is not a `hyprpm` package or a
standalone Quickshell app. Link [installation](../README.md#install),
[migration](MIGRATING.md) and [recovery limits](LAYOUT-RECOVERY.md); retain upstream
attribution. The repository preview shows settings with sample data.

## Suggested update announcement

> **Hyprworld 0.1.1** adds automatic settled-layout checkpoints and smooth minimap
> fit resizing. Open-window positions, groups, sizes, camera and zoom now recover
> after plugin/config resets in the same compositor session. Drag outlines update
> continuously within and across monitors, and equal-sized focus changes keep the
> minimap stable. This update also hardens loading, reloads, settings and IPC, with
> regression and isolated multi-monitor checks. Checkpoints do not restore after
> logout or reboot. See the README for native-helper update requirements.

The config installer/uninstaller ask before modifying `hyprland.lua`; `--yes`
is for an intentionally unattended invocation. The normal Omarchy plugin lifecycle
commands do not run those optional scripts.
