# On-device performance profiling

## Purpose

Use this workflow when an interaction feels slow on a physical iPhone but simulator UI tests, button navigation, or ordinary code inspection do not explain it. It is designed for intermittent scrolling freezes, dropped frames, slow taps, and synchronous main-thread work in SwiftUI and SwiftData.

See [the 2026-10-07 timer-enabled active-workout findings](active-workout-performance-findings-2026-10-07.md) for the latest set-completion and up/down scroll Simulator measurements, including the XCTest polling overhead and current evidence limits.

The simulator remains useful for repeatable regression tests and CPU, memory, and signpost proxies. It does not reproduce the physical display pipeline, ProMotion behavior, finger-driven scrolling, or device-only frame hitches reliably enough to answer “is this screen actually smooth?” Physical-device measurements are authoritative for that question.

## Recommended diagnostic design

Retain the active-workout frame monitor in the app with these constraints:

- Compile it only in Debug builds with `#if DEBUG`.
- Put it behind an “Active Workout Frame Monitor” toggle in Settings → Developer.
- Default the toggle to off.
- When off, do not create or start a `CADisplayLink`, render an overlay, publish samples, or write frame logs.
- When on, show the small FPS/hitch/worst-frame overlay and emit the structured `ACTIVE_WORKOUT_FRAME_SAMPLE` console line once per second.
- Publish each one-second sample atomically. Updating FPS, hitch count, and worst-frame duration separately causes extra SwiftUI graph transactions and can distort the measurement.
- Keep the monitor observational. It must never save models, change workout state, or trigger production analytics.

The monitor implements this design: it is Debug-only and starts only when the default-off Settings → Developer → Active Workout Frame Monitor toggle is enabled. Turning the toggle off removes the overlay and leaves no display link or frame logging active.

The existing `CADisableMinimumFrameDurationOnPhone` Info.plist setting should remain enabled in Debug and Release. It permits the app to render above 60 Hz on supported iPhones; it is a product performance setting, not profiling code.

Do not add the overlay or display link to Release builds. If production-only stalls eventually need investigation, prefer low-overhead signposts around known operations or MetricKit hang diagnostics rather than shipping a continuously running frame monitor.

## Controlled test setup

Keep before and after runs comparable:

1. Connect the iPhone by cable, unlock it, and keep it awake.
2. Confirm Developer Mode and pairing are active.
3. Preserve the existing app data so the test uses realistic history and SwiftData relationships.
4. Open the same active workout with no rest timer running.
5. Let the screen idle for roughly ten seconds to establish the refresh-rate ceiling.
6. Finger-flick up and down continuously for 15 seconds. Finger scrolling is the primary test; exercise arrow buttons are a useful control but do not exercise the same deceleration and lazy-row path.
7. Repeat the same gesture pattern after each material fix.
8. Record whether a hitch happens during profiler attachment. Instruments can briefly suspend or perturb the process, so distinguish that event from hitches inside the recorded interval.

Treat “it becomes faster after one pass” as evidence of lazy loading, relationship faulting, image decoding, or cache warm-up—not as proof that the problem is fixed.

## Controlled active-workout load

Use `make workout-profile PROFILE_LABEL=<label>` for the repeatable simulator workflow and `make workout-profile-graph` to regenerate retained trend charts. See [the detailed findings and measurement contract](active-workout-performance-findings-2026-10-07.md) and [run history](performance/history.html). The normal profile uses an isolated disposable SQLite store, ten exercises, three participants and five sets per exercise, with 48 generated plus eight basic historical sessions. Individual and shared completion run with a rest countdown; scrolling starts after completing a set and keeps both the rest countdown and elapsed-workout label active.

The runner records actual completion-indication pixels in simulator video using a Debug optical clock, plus app-handler/save phases. It explicitly targets app CPU, memory and logical writes. Scroll samples separate UIKit dragging/deceleration callbacks from whole-window cadence, and retain the native dragging/deceleration metric. This simulator currently provides native scroll duration but no rendered FPS/hitch measurements; callback proxies must stay labelled as proxies. Results include source/configuration metadata, actual fixture validation, raw samples and sample counts. The optional `PROFILE_DENSE=1` profile is a separate twelve-exercise stress case with 64 sets on the first active exercise; `PROFILE_HISTORY=192` is a separate history-scaling case. Raw video and result bundles are under `build/performance/`; durable JSON summaries are under `docs/performance/runs/`.

For an app-local load comparison on a physical phone, install a Debug build and go to Settings → Developer → Bounded Device Load. Select CPU, memory, temporary-file I/O, or a combination, start the 30-second run, and immediately open the same active workout state used for the unloaded capture. Enable the Active Workout Frame Monitor for both runs and repeat the same 15-second finger-scroll pattern. Keep the workout, history, display settings, profiler attachment, and action duration matched. Capture CPU or memory with Instruments; capture file operations with an available File Activity or Filesystem instrument and record the exact template name. If no disk instrument is available on the current Xcode version, report that app-generated file I/O was enabled without claiming a measured physical-storage rate.

The Debug-only harness is bounded to one CPU worker at about 40% duty cycle, a 64 MiB allocation, and/or an 8 MiB temporary file read and rewritten at up to 4 MiB/s. It never writes to the workout database. It stops after 30 seconds, when Stop is pressed, on app backgrounding, or when the active workout closes; cancellation releases the allocation and removes the temporary file. The file workload establishes repeatable app-local I/O calls but cannot guarantee NAND writes or system-wide disk pressure because the OS may cache or coalesce them. These settings are a moderate, controlled comparison, not a thermal stress test.

Simulator CPU/memory tools and Simulator device controls apply to the Mac-hosted simulator. They cannot create actual CPU, memory, storage, or display pressure on the iPhone. The in-app harness adds app-local work on the phone, but cannot force pressure from unrelated processes or prove how the entire device behaves under system-wide contention. Treat simulator metrics as regression proxies and use physical-device frame logs plus Instruments for phone conclusions.

## SwiftUI scrolling regression guardrails

Treat scroll visibility and geometry callbacks as observation points, not as a place to continuously update state owned by the view that contains a large scrolling hierarchy. A callback that writes a parent `@State` or `@Binding` can invalidate that parent and cause SwiftUI to revisit the list and its expensive rows while a finger or deceleration is moving the content. Visibility callbacks may fire less often than per-frame geometry readers, but each threshold crossing can still trigger costly work during motion.

For active-workout exercise selection and similar scroll-driven UI:

- Keep callback work bounded: identify the candidate row and store only the latest candidate in state that does not invalidate the list-owning view.
- Coalesce updates while scrolling. Commit parent-visible selection when the scroll phase becomes idle, rather than for each row crossing a visibility threshold.
- Keep programmatic scrolling semantics explicit. A visibility event during a requested jump must not replace the requested selection; retain a navigation test for menu jumps and current-exercise selection.
- Keep expensive lookup, formatting, persistence, and relationship traversal out of visibility/geometry callbacks. Cache or derive that data when its inputs change.
- When a callback must update parent state during motion, profile that exact path and document why the invalidation is bounded.

For a scroll-state change, run the same `make workout-profile` scenario before and after with matching history, timer, build configuration, simulator, and source revision metadata. Repeat captures and compare motion callback FPS, callback-gap counts, and excess-gap ratio; inspect raw samples as well as aggregates. Keep very long gaps visible and investigate them separately because XCTest, automation, and video capture can pause sampling, while a real app freeze can also produce a long gap. Do not silently count these as ordinary frame hitches or discard them without checking the trace. Simulator callback metrics are a regression signal, not rendered-frame or GPU hitch counts. Use the physical-device frame monitor and Instruments when making claims about actual dropped frames.

### October 2026 scroll-selection case study

The active-workout list's exercise visibility tracker wrote `currentExerciseID` through a binding as each exercise crossed the visibility threshold. Since `ActiveWorkoutView` owns the list and its exercise cards, these selection changes could invalidate the list-owning view during scrolling. The tracker now records a candidate in non-observable state and commits the selection once the scroll phase is idle; programmatic selection remains guarded.

In the matched iPhone 17 Pro simulator profile, the motion callback FPS proxy changed from 36.52 before the adjustment to 47.94 and 47.27 in two after runs. The callback hitch proxy count changed from 22 to 14 and 12. Those runs support the hypothesis that coalescing parent updates helps, but the remaining long sampling gaps and the lack of rendered-frame metrics mean they do not prove an improvement in actual device frame hitches. See [the retained run history](performance/history.html) and the raw summaries for `20261020T190245Z`, `20261020T190712Z`, and `20261020T191037Z`.

## Build and live frame capture

Build, install, and launch the Debug app using the supported project workflow:

```sh
make phone-deploy
```

Before opening the active workout, enable Settings → Developer → Active Workout Frame Monitor. Turn it off again after the profiling session.

Attach the app console. The repository's default phone UDID is recorded by `DEVICE_ID` in the Makefile:

```sh
xcrun devicectl device process launch \
  --device 00008150-000E41422E40401C \
  --terminate-existing \
  --console \
  com.cseibert.StrengthLog
```

The monitor prints one structured sample per one-second window:

```text
ACTIVE_WORKOUT_FRAME_SAMPLE fps=99 hitches=5 worst_ms=68.8
```

Interpret the fields together:

- `fps`: delivered display-link callbacks per elapsed second. Compare it with the idle ceiling.
- `hitches`: gaps larger than the expected refresh interval threshold.
- `worst_ms`: the largest callback gap in the window. This reveals a freeze even when adjacent windows return to 120 FPS.

A steady 60 FPS ceiling on a ProMotion phone can indicate that the app has not opted into the higher refresh rate. A one- to two-second `worst_ms` value is a main-thread stall, not ordinary scroll variance.

## Time Profiler capture

Find the running app PID:

```sh
xcrun devicectl device info processes \
  --device 00008150-000E41422E40401C
```

While the tester continuously finger-scrolls, attach Time Profiler for a short, bounded interval:

```sh
xcrun xctrace record \
  --template 'Time Profiler' \
  --device 00008150-000E41422E40401C \
  --time-limit 15s \
  --attach APP_PID \
  --output /tmp/active-workout-time-profiler.trace \
  --no-prompt
```

Export the hang table:

```sh
xcrun xctrace export \
  --input /tmp/active-workout-time-profiler.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="potential-hangs"]' \
  --output /tmp/active-workout-potential-hangs.xml
```

Export the sampled call stacks:

```sh
xcrun xctrace export \
  --input /tmp/active-workout-time-profiler.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
  --output /tmp/active-workout-time-profile.xml
```

Correlate the potential-hang start times with the frame monitor's worst gaps. Inspect the main-thread stacks during those intervals and follow the first app-owned frames upward through SwiftUI, SwiftData, Core Data, image decoding, formatting, or persistence work. Do not infer the cause solely from the highest framework symbol; identify which app getter or view builder initiated it.

## Active-workout case study

The September 2026 investigation found several independent costs:

- The app lacked the ProMotion opt-in and was capped at 60 FPS.
- Home remained alive beneath the pushed active-workout destination. Its 28-day activity grid called `PersonalRecords.achievements(in:)` inside every day cell, repeatedly traversing the full workout history and synchronously faulting SwiftData relationships on the main thread.
- Home's periodic timeline and calendar continued to reevaluate while covered by the workout.
- The first diagnostic overlay published three properties separately every second, producing avoidable graph updates.
- The active screen observed broader catalog/history data than it needed, synchronously autosaved rapid edits, used per-card geometry preferences, and could load/decode exercise thumbnails while rows appeared.

The fixes were correspondingly layered:

- Enable ProMotion with `CADisableMinimumFrameDurationOnPhone`.
- Memoize activity-grid personal-record counts by workout-history revision.
- Replace covered Home content with an inert placeholder while the active workout is presented.
- Publish one frame-monitor sample per second.
- Cache only the active workout's catalog and personal-record support values.
- Checkpoint SwiftData saves at meaningful boundaries instead of autosaving every rapid edit.
- Use scroll visibility callbacks instead of continuous per-card geometry preferences.
- Read, decode, and prepare thumbnails off the main actor with a bounded decoded-image cache.

### Measured result

The matched physical-device captures showed:

| Metric | Before | After primary fix |
| --- | ---: | ---: |
| Idle refresh ceiling | 60 FPS | 120 FPS |
| Finger-scroll FPS during stall windows | 1–41 FPS | 99.6 FPS average over 72 windows |
| Median finger-scroll FPS | Intermittently dominated by freezes | 99 FPS |
| Worst observed frame gap | 4,869 ms | 92 ms, excluding profiler attachment |
| Instruments potential hangs | 3 severe hangs in 13.3s | 0 hangs in 15s |
| Severe-hang durations | 3.27s, 3.72s, 3.52s | None |
| `PersonalRecords.achievements` in after trace | Repeated hot stack | 0 samples |

The remaining simulator metrics were deliberately treated as regression proxies, not device FPS. The final hidden-Home suppression reduced simulator scroll CPU from 0.084s to 0.079s, button CPU from 0.122s to 0.114s, and peak scroll memory from 45.5 MB to 42.0 MB while preserving the same 2.433s system-controlled scroll deceleration.

## Completion checklist

- Capture baseline frame logs before changing code.
- Record at least one Time Profiler trace that overlaps a reproduced freeze.
- Fix app-owned work identified in the sampled main-thread stack.
- Repeat the same physical gesture with the same data and screen state.
- Export and compare the after hang table; do not rely only on subjective improvement.
- Run `make active-workout-performance-ui-test`.
- Run `make active-workout-regression-ui-test` after navigation or persistence changes.
- Run `make lint` and `make test` before handoff.
- Turn the Active Workout Frame Monitor toggle off after the profiling session.
