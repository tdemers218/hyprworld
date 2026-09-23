# Hyprland / Omarchy compatibility and failure-safety audit

Initial audit: 2026-09-21. Updated with checks through 2026-09-23. Tested against Hyprland 0.56.2, Omarchy 4.0.4,
Quickshell with Qt 6.11.2. This is a review of the Lua layout/integration,
native helper, Python bootstrap/startup/shortcut tooling, QML/JavaScript UI,
manifest, installation scripts, and tests. It is not a guarantee against faults
in the compositor, graphics drivers, or arbitrary future API changes.

## Findings and changes

| Dependency / failure path | Treatment |
| --- | --- |
| Omarchy `keepLoaded` service lifecycle | Set the manifest flag to false. Omarchy deliberately preserves services marked true when plugins reload; this kept the old Preview component alive and hid the previously installed cross-monitor outline. Hyprworld does not own a session lock and can be recreated safely. |
| Lua custom layout, target userdata, timers, dispatchers and window-active events | Check required host APIs before installing bindings. Catch integration errors, report them and restore the previous general layout. Layout callback failures restore temporary pointer modes and place surviving targets in a simple visible row. This is a failure-only fallback. |
| Native C++ `changeWorkspace` hook, workspace placement and animation internals | Remains the principal version-dependent boundary. Preserve the exact compositor-commit check, hook-success check and native disable API. A missing/incompatible helper causes guarded initialization to stop instead of throwing out of the user's config. No attempt to guess private symbol addresses or support an ABI mismatch. |
| Build process and cache | Build outside the watched plugin directory, use a content/header/compiler fingerprint and atomic binary replacement. Wait at most 30 seconds for the build lock and bound the build to 120 seconds, followed by a kill grace period. The running helper is not hot-unloaded or replaced. |
| Shell / Python compositor IPC | Add finite timeouts. Treat non-`ok` bootstrap responses as failure, including warnings returned with exit code zero. Avoid perpetual customizer/preview waits. Escape Lua data strings; window titles are never evaluated as code. |
| Optional launcher IPC inside compositor Lua | Add a 200 ms timeout and 100 ms kill grace. Existing successful routing is unchanged. It remains synchronous because deciding whether the launcher consumed a key requires its reply; leave the opt-in unset when unused. |
| Settings files | Limit Lua input to 1 MiB, retain last valid settings during malformed edits, validate nested tables, and bound paths/templates/grid coordinates. Preserve built-in group layouts when malformed custom layouts are rejected. Read one settings snapshot per layout pass. QML normalization tolerates null/malformed nested entries. |
| Minimap focus / cached IPC geometry | Use authoritative layout geometry and retain the fit obstacle across same-sized focus changes. A new focused size, workspace/monitor, content dimensions, display dimensions or fitting preferences can still legitimately change the fit. Same-sized focus changes do not resize the map. The subsequent fit-motion feature interpolates size, position and scale using the existing movement-duration preference. |
| Drag crossing monitors / monitor disappearance | Send compact gesture geometry separately from full snapshots; use click-through local/destination surfaces in logical monitor coordinates. Fragment large snapshots within the event limit with bounded, revision-aware reassembly. Clear the preview on release, cancellation or invalid source/destination. Camera panning still cancels at a monitor boundary. |
| Overview input capture | Escape/close relinquishes the local overview's exclusive keyboard focus even if the compositor command fails. |
| Startup concurrency | Use a nonblocking lock; duplicate automatic launches return, manual attempts receive a retryable error. Preserve normal session markers and sanitize unusual signatures. Existing matching windows in the destination remain preferred. |
| Layout checkpoint files and reset recovery | Debounce settled state for 1.5 seconds; write bounded JSON atomically outside the compositor/plugin tree, retain two older copies, and skip unchanged writes. Validate records and compositor-session identity on restore. File/IPC failures leave the desktop running. No cross-session restoration. |
| Native config reconciliation | Declare the helper on every config generation and assert retained handles in repeated-reload tests. Bootstrap confirms the API before reporting success and rejects incompatible already-loaded helpers. |
| Keyboard mapping library | Check XKB context allocation, clean it up after keymap failure, and bound all Hyprland option queries. |

## Intentional compatibility boundaries

- Hyprland's **Lua** API is required; hyprlang-era releases are not supported.
  Capability checks are not a promise that undocumented future semantic changes
  will work. See [Lua utilities](https://wiki.hypr.land/configuring/core/advanced-configuration/lua-utilities/)
  and [custom layouts](https://wiki.hypr.land/0.56.0/Configuring/Layouts/Custom-Layouts/).
- The native helper includes Hyprland private C++ headers. Rebuild it after a
  compositor update and restart the session to load changed native code. Do not
  unload a live compositor hook as a routine update mechanism.
- QML still depends on Omarchy's `qs.Commons` / `qs.Ui`, its theme objects,
  `omarchy-shell` IPC, and Quickshell layer-shell/Hyprland modules. These are host
  interfaces, not a standalone Qt application. Missing QML imports fail component
  loading and are logged; they cannot be recovered by JavaScript in that component.
- The repository retains `hyprworld` settings/IPC/layout identifiers. The existing
  local legacy installation retains `hyprscroll2d` identifiers and its settings
  file. They were not renamed during this repair. Do not load both copies together.
- Omarchy preference/background paths remain explicit compatibility contracts.
  Defaults are resolved relative to the plugin rather than a hard-coded checkout.
  Missing wallpapers/icons degrade to the existing color/text fallback.
- Direct `dofile()` lines in a user's config are outside the plugin's ability to
  protect if the entire plugin is deleted. Use a guarded manual loader or the
  shell bootstrap, and remove manual workspace rules when uninstalling.
- A mid-install host API failure after some successful binding mutations cannot
  transactionally restore every earlier binding. Preflight and parse checks reduce
  that exposure; reload a working config after correcting the dependency.
- Lua callback guards cannot recover a C++ compositor/driver crash or memory
  exhaustion. No claim is made that every possible external failure is preventable.

## Validation

`make check` covers existing geometry, 600 mixed group operations, touchpad and
mouse gestures, workspace behavior, startup reuse, shortcut validation, settings,
installer behavior, plus new malformed-settings and bootstrap-failure tests.
All QML files parse with `qmlformat`. Qt Quick's motion test verifies intermediate
frames and retargeting. The native helper builds against installed headers.
Rendered two-monitor checks and measured CPU results are recorded in
[PERFORMANCE-AUDIT.md](PERFORMANCE-AUDIT.md).

## Latest verification and remaining limits

The September 23 final isolated full-Service run passed:

- Large Unicode snapshot reassembly through the real Hyprland event socket.
- Fresh public-ID startup, settings opening and disable/re-enable.
- Twelve manual-config reloads retaining the same native helper handle; worst
  recovery in this run was 0.086 seconds.
- Automatic settled saves, three full Lua resets preserving groups, size, camera
  and zoom, inactive workspace recovery, and no identical-state rewrites.
- Local/remote outline updates in both directions, immediate cancellation,
  negative monitor positions and fractional scaling.
- Workspace/window swaps, five monitor arrangements, overlay suppression,
  native disable behavior and explicit native removal in the isolated session.

`make check` and the Qt Quick motion tests passed. The final live source-only
update captured and restored ten existing windows exactly, retained the native
helper, reloaded in 0.346 seconds, and passed shell/config health and idle-save
checks. The user confirmed smooth dragging both within and across monitors.
The live desktop retained its legacy package namespace; the separate isolated
package test used the public Hyprworld ID.

Earlier September 21–22 reload timeouts and rollbacks remain historical evidence,
not the latest deployment status. The exact cause of the original long freeze
was not conclusively established. Guards cannot protect against all native,
driver or future host failures, and short tests cannot certify long-term stability.
See [FREEZE-INVESTIGATION.md](FREEZE-INVESTIGATION.md) for the investigation and
[LAYOUT-RECOVERY.md](LAYOUT-RECOVERY.md) for checkpoint limits.
