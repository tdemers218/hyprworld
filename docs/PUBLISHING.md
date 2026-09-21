# Publishing and maintaining the listing

Hyprworld uses the plugin ID `io.github.tdemers218.hyprworld` and repository
`https://github.com/tdemers218/hyprworld`. Keep the manifest, widget module name,
README commands and release tag consistent.

## Release checks

1. Run `make check`, `make native`, and `omarchy plugin validate .`.
2. Run the [isolated compositor checks](../native/README.md), including native
   helper disable behavior, plus settings Apply/Revert and startup launching.
3. Run `python3 tests/live_package.py` for a fresh installation with the public
   plugin ID. Build the native helper before enabling. Test update, migration and removal too.
4. Review all tracked and untracked files. Commit the QML components, native
   source, tests and current `preview.png`; exclude native build output,
   temporary files, preferences from a real session, and logs.
5. Match `manifest.json` version to [CHANGELOG.md](../CHANGELOG.md). Set the release
   date when the release is actually published, then create the matching tag.
6. Inspect `git remote -v` before pushing. This fork must be pushed to its own
   repository, not the original Hyprscroll2D upstream.

The GitHub workflow runs compositor-independent tests. It does not compile the
native helper or certify compatibility with a new Hyprland version. Rebuild and
repeat the live checks for each supported compositor upgrade.

## Marketplace submission

Follow the [official publishing guide](https://plugins.omarchy.org/publish.html).
The marketplace requires a public repository, valid root manifest, README,
license, and safe installation/removal. A listing requires a separate submission
and approval; a successful manifest validation alone does not publish anything.

The optional config installer and uninstaller ask for confirmation before they
change `hyprland.lua`. Their `--yes` flag is reserved for an explicitly approved
scripted action; unattended runs without that flag fail before changing the file.
The normal Omarchy plugin add, enable, disable, update, and remove commands do
not use these scripts.

Suggested listing copy:

> Hyprworld turns your desktop into a two-dimensional workspace. Arrange windows
> in visible groups, find them in a searchable overview, and navigate with a
> minimap, keyboard or touchpad. Design opening paths, choose group layouts, and
> save startup workspace templates through themed visual settings.

Category: **Compositor**. Suggested tags: **Hyprland**, **workspaces**, **layout**,
**overview**, **productivity**.

Make the build requirement prominent in the listing: Omarchy 4.0.3 and Hyprland
0.56.2 are the tested baseline; this plugin requires a C++23 native helper built
against the exact running Hyprland version. It is an Omarchy Shell plugin, not a
`hyprpm` package. Link the [installation](../README.md#install) and
[migration](MIGRATING.md) instructions and retain upstream attribution.

The repository preview depicts current settings with sample data. Update it
when the interface changes. Never submit screenshots containing private window
titles, user paths, or messages.
