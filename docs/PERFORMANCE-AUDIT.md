# CPU and rendered behavior audit

Measurements: 2026-09-21. Documentation and functional follow-up: 2026-09-23.
Hyprland 0.56.2; Omarchy 4.0.4; Qt 6.11.2.

These CPU figures predate compact drag events, layout checkpoints and animated
fit resizing. They are not a full CPU profile of the final 0.1.1 candidate.

## Method

Used an isolated compositor with two 1280×720 logical headless outputs, the
matching native workspace helper and the real Preview.qml. The preview host
substitutes only theme colors/utilities for Omarchy's theme singletons. Test
windows are static Quickshell windows plus one terminal. The user's windows,
workspaces and running compositor were not used for these workload actions.

Each measured phase lasts six seconds. Idle and normal use have 13 windows;
normal focus runs at 4 actions/second, rapid zoom at 30 wheel actions/second,
workspace changes at 8/second, and many-window focus at 8/second with 61 windows.
Window counts, monitor ownership and config errors are asserted. Creation,
layout reload and compaction are allowed to settle before measurements.

CPU is process user+system time plus reaped-child CPU from `/proc/PID/stat`,
divided by monotonic elapsed time. 100% means one logical CPU. This captures
compositor work, real preview rendering and its helper processes, but not the
test client renderer or input-driving Python process. It is not an FPS test or
an estimate of the entire Omarchy shell. Initial pilot runs with incorrect
monitor setup were discarded.

## Measurements

| Workload | Hyprland before / after | Preview process before / after |
| --- | ---: | ---: |
| idle | 0.17% / 0.00% | 0.33% / 0.33% |
| normal_focus | 18.33% / 19.00% | 18.33% / 19.83% |
| rapid_zoom | 69.83% / 73.17% | 91.00% / 97.17% |
| workspace_changes | 16.83% / 16.00% | 20.33% / 20.83% |
| many_windows_focus | 67.16% / 72.50% | 71.33% / 73.33% |

The end-to-end runs do **not** establish an overall CPU improvement. Changes of
this size in short rendering runs can reflect workload timing and scheduling;
several candidate phases are higher. No animation was removed, shortened or
throttled to improve the numbers. Additional speculative rendering changes were
not made.

One specific, measured optimization was retained: context creation previously
opened/read the settings file five times. A single immutable settings snapshot
per layout pass produces the same valid settings. A Lua microbenchmark of 10,000
passes measured **0.7643 s → 0.3091 s**, and **50,000 → 10,000 file opens**
(about 60% less time for that settings-reading workload). This is not a claim
of a 60% compositor improvement. Malformed-file handling is tested separately.

## Rendered verification

- Destination-monitor outline and label were rendered and captured with `grim`.
- Repeated on a monitor at **−1280, −100**, physical mode 1600×900, scale **1.25**.
- Both releases moved the selected window to the destination workspace, and the
  destination overlay disappeared afterward.
- Twelve alternating same-size focus changes yielded a single stable fit size,
  with no intervening minimap size changes. The sizing helper separately tests
  actual dimension changes and workspace changes as invalidation cases.
- The later Qt Quick motion tests verify intermediate animated fit sizes,
  in-flight retargeting, final dimensions and immediate updates with animations
  disabled. Fit motion uses the existing movement-duration setting.

The recorded measurements are checked in as
[performance-audit-results.json](performance-audit-results.json). Original
machine-local scripts and captures are not a portable release artifact. Do not
claim a final-release CPU reduction based on this short benchmark.

## September 23 functional follow-up

Compact geometry events now drive both local and remote outlines without
rebuilding full tile/title snapshots on every pointer tick. The mocked long-title
regression emitted one event per tick, at most 278 bytes. The real Service test
verifies event delivery and outline progression in both directions, including
negative origins and scale 1.25. The user confirmed smooth local/remote dragging.
This is functional/event-volume evidence, not a new CPU measurement.

Checkpoint tests verify no disk rewrites for unchanged state; writes occur in a
separate process after settling. Final lifecycle tests also preserve active and
inactive workspace arrangements through three Lua resets. The subsequent live
source update succeeded with ten windows restored exactly and the native helper
retained. Earlier rollback notes do not describe the current installation.
See [the compatibility audit](COMPATIBILITY-AUDIT.md) for verification limits.
