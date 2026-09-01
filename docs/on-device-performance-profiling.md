# On-device performance profiling

## Purpose

Use this workflow when an interaction feels slow on a physical iPhone but simulator UI tests, button navigation, or ordinary code inspection do not explain it. It is designed for intermittent scrolling freezes, dropped frames, slow taps, and synchronous main-thread work in SwiftUI and SwiftData.

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
