# Contributing

Bug reports, documentation improvements, and testing are welcome. Use the Issues
and Pull requests tabs of this fork's repository for changes specific to this
project; please do not send fork-specific issues to Hyprscroll2D upstream.

## Development

Install Lua 5.4 (`lua` and `luac`), Python 3, Node.js, Bash, and Make, then run:

```sh
make check
```

The suite covers geometry, grouping, gestures, compaction, focus, monitor
workspaces, shortcut validation, settings, and installer round trips. Hyprland
APIs are mocked, so it runs without starting a compositor. If the `omarchy`
command is available, the check also validates the plugin manifest.

Keep geometry independent of compositor APIs. Add regression coverage for
behavior changes, and update the user documentation when controls or defaults
change. Keep changes focused and describe their behavior and validation in the PR.

## Visual testing

Use a separate test session when possible. Check minimap and overview, drag and
group behavior, keyboard focus after closing overview, settings Apply/Revert,
and monitor switching. Test configuration reload and disable/re-enable too.
Record the Hyprland and Omarchy versions used. Automated tests cannot establish
that QML rendering or compositor interaction works on a particular release.

`make native` builds the native helper using C++23, pkg-config and matching Hyprland
headers. See [native testing](native/README.md) for the isolated multi-monitor tests.
Never run those tests against your working desktop.

`tests/tst_minimap_motion.qml` is an optional Qt Quick Test regression test.
`tests/live_mouse_check.py` moves the real pointer and changes window focus;
run it manually only in a prepared session with visible neighboring tiles.

## Reporting problems

Include:

- Plugin commit or version and installation method.
- Hyprland and Omarchy versions.
- Monitor resolution, scale, arrangement, and workspace involved.
- Reproduction steps, expected behavior, and actual behavior.
- Relevant settings and `hyprctl configerrors` output.

Redact private window titles and paths from logs or screenshots. For visual
bugs, a short recording is particularly useful.

## Attribution

Preserve the upstream MIT notice and credit derived work. Contributions are
provided under the repository's MIT license. See [LICENSE](LICENSE).
