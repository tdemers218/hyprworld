# Freeze investigation — September 21–23, 2026

## Current status

The compact outline update is active; the user confirmed smooth dragging both
within and across monitors. The later checkpoint/fit-animation update also
succeeded: all ten existing windows restored exactly, the native helper stayed
loaded, config reload took 0.346 seconds, and shell/config checks passed.
The final isolated public-ID run passed 12 retained-handle reloads (worst 0.086
seconds), three checkpoint resets with inactive workspace coverage, drag events,
workspace swaps and native lifecycle checks. See [the compatibility audit](COMPATIBILITY-AUDIT.md).

The sections below retain earlier failures and recovery evidence in context.
They do not claim that the precise cause of the original long freeze was proved.


## September 23 follow-up: compact drag geometry

The existing desktop session recovered without a compositor restart. The outline
now has a separate geometry stream: each move tick sends the ghost and drop
target, not all workspace tiles and titles. Move ticks no longer re-place real
windows or update the minimap's tile model. A single click-through overlay design
handles both the source and destination monitor. The two-second poll is retained
only for recovery, with revision checks preventing stale polls from overwriting
newer geometry. Full workspace snapshots still use bounded fragments.

The regression's twenty move ticks each emitted exactly one event, at most 278
bytes, even with a long Unicode window title. Real compositor/QML tests verified
successive updates within 600 ms on the same monitor and across monitors in both
directions, including a negative-position monitor at scale 1.25, and immediate
outline cancellation. Rendered local and remote outlines were inspected. Twelve
manual-config reloads retained the exact native helper handle; worst reload
recovery in the final run was 0.044 seconds. The full test suite passed.

Only `Preview.qml`, `PreviewStream.js`, and `layout/init.lua` were then updated
in the existing legacy-ID installation. The live reload completed in 0.420
seconds with the native helper retained; the shell and layout passed health
checks. A source backup was retained outside the watched plugin tree.

## Findings and changes

The full Service test exposed a real initialization bug: `hl.plugin.load` called
through `hyprctl eval` reported success while `hyprctl plugin list` remained
empty and `hl.plugin.hyprworld_shared` was nil. At the installed Hyprland commit
`efb50993780079460b0cbed1363e2166a2de1d9f`, the Lua binding only adds a path to
the configuration's registered-plugin list; it does not load the library during
eval. This is visible in the official
[Lua binding implementation](https://github.com/hyprwm/Hyprland/blob/efb50993780079460b0cbed1363e2166a2de1d9f/src/config/lua/bindings/LuaBindingsConfigRules.cpp#L537).

`bootstrap.py` now loads the helper through bounded native IPC before evaluating
the layout integration. Lua initialization verifies that the helper's callback
actually exists before reporting success. Bootstrap rejects an already-loaded
workspace helper with an incompatible API instead of stacking another hook.

The live installation used the legacy Hyprscroll2D Lua namespace, but its loaded
native library exposed the Hyprworld API. A compatibility build preserving the
installed plugin ID, layout name and preference path corrected that mismatch.

The prior fixes also retain a two-second recovery poll during a gesture and
disable the helper after partial initialization failure. Automated regression
tests cover missed gesture-end events, reload recovery, deferred native loading,
incompatible helpers, failed native loading, and partial Lua initialization.

## Verification

- `make check`, QML syntax parsing, and whitespace checks passed.
- Both the public-ID package and legacy-ID compatibility build ran their full
  Service with real native helpers in separate temporary Hyprland sessions.
- Each passed enable/disable, 12 repeated reloads, rapid workspace reversals,
  actual terminal-window swaps, five monitor arrangements, overlay suppression,
  native disable behavior, and clean native removal. Worst reload recovery was
  0.342 seconds for the public package and 0.343 seconds for the compatibility build.
- Separate copies of the user's configuration completed ten reloads each with
  the original and candidate integration. Session autostart was suppressed;
  these nested sessions do not exercise physical display reconfiguration.
- During live deployment, the shell was stopped before directory replacement,
  the mismatched helper was unloaded, and a rollback copy was retained outside
  the watched plugin tree. Config reload completed in 0.356 seconds. The new
  shell, layout and matching native API then passed health checks.
- Twelve subsequent live snapshot requests averaged 0.005 seconds, with a
  maximum of 0.006 seconds. Shell ping succeeded and config errors were empty.

## Limits and rollback

**Earlier failed deployment:** the event-fragmentation follow-up hit
another compositor reload timeout. The updater restored the previous plugin
directory, but the compositor remained CPU-active and stopped answering IPC;
the restarted shell could not finish connecting. Debugger attachment was denied
by the OS ptrace policy. The earlier successful live checks did not establish
the stalled session's health. No compositor restart was performed because that would
close user applications. At that stage, the outline transport fix was verified only in isolation and
was rolled back live. The September 23 source-only update above later succeeded.

The investigation also found that skipping `hl.plugin.load` for an already
loaded config helper can omit it from the next config's plugin list. Hyprland
unloads omitted config plugins and schedules another reload. Initialization now
declares the helper on every config generation, and a regression checks that
behavior. This declaration fix was applied to the restored integration file,
but did not recover the already-stalled process. No stack trace was obtained to establish where the stalled process was spinning.
The desktop subsequently recovered without a compositor restart.

A subsequent report of two-second outline updates on one monitor exposed a
separate, reproduced bug: this Hyprland version truncates custom event data at
1024 bytes, whereas the live preview payload measured 2070 bytes even before
adding drag geometry. Larger workspaces therefore sent invalid JSON and fell
back to recovery polling. Preview snapshots now use UTF-8-safe fragments with
900-byte payloads and bounded reassembly in `PreviewStream.js`. Small snapshots
keep the original event format. Tests verify twenty large Unicode drag frames
on source and destination monitors and pass an oversized frame through the real
Hyprland event socket into the actual Service's QML receiver. This explains the
uneven outline refresh; it does not prove the cause of the earlier desktop freeze.

The historical journal shows repeated plugin-change notifications and 140
duplicate-IPC-handler warnings during the September 21 failure window. This is
evidence of reload churn, not proof that preview polling caused the freeze.
Some unrelated shell components still emit duplicate-handler warnings on startup.
The original long freeze was not reproduced in these tests, so its exact cause
remains unproven. There is no claim of exhaustive long-term stability.

The live verification used a legacy-ID compatibility installation; the public
Hyprworld ID was verified independently in temporary sessions. Local deployment
backups and logs are not shipped with the plugin. This investigation documents
observed failures and fixes; it is not a guarantee against all compositor freezes.
