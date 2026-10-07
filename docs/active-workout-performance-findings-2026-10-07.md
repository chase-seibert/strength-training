# Active workout performance findings — 2026-10-07

## Executive summary

**There are now production changes to set completion and row initialization, plus a repeatable simulator profiling workflow and a durable results history.** Completion checkmarks and button fills appear without a fade. Initializing weight text no longer rewrites models or clears per-set overrides, and preserves stored precision when the displayed value is rounded. The active screen no longer fetches personal-record history or rescans the current workout for live PR badges. Set grids calculate completion eligibility once, shared completion avoids repeated sorts, Live Activity details are calculated once per synchronization, and stopping a matching exercise timer is included in the completion's single save.

**The strongest measured visual improvement is shared completion.** In the matched lightweight baseline, the median delay from the app's action handler to recognizable completion pixels for all three participants was 215 ms. The final configuration measured 107 ms; intervening configurations measured 98–116 ms. Individual completion's final median was also 107 ms, matching its baseline; intervening differences were near the recording's one-frame uncertainty and do not establish a reliable visual speedup. The warmed handler itself fell from roughly 3–3.5 ms to roughly 1.4–1.9 ms. These measurements do not prove a strict sub-100-ms response on an iPhone.

**SQLite save duration is small in these warmed fixtures, about 1.2–1.4 ms in the final run.** An individual completion dirties two models; a synchronized three-person completion dirties four. The initialization fix also reduced the first completion from 37 dirty models to two, although its cold save still took 19.5 ms. The code retains per-set durability. Delaying these saves until workout completion would create a reliability tradeoff without addressing most of the measured visual delay.

**Scrolling is still an investigation, not a demonstrated fix.** The final simulator setup samples callback cadence only while UIKit reports dragging/deceleration, and keeps native scroll animation metrics separately. The simulator returns animation duration but no native rendered FPS or hitch metrics. CADisplayLink proxies show occasional gaps; they do not establish phone GPU hitches or show a convincing scrolling improvement.

The run ledger and graphs are in [performance/history.html](performance/history.html), with raw samples and XCTest metrics in [performance/runs](performance/runs). Large videos, proof frames, source snapshots, logs, and result bundles remain under the ignored local `build/performance/<run-id>/` directory. Future runs append new records; graph generation does not rerun tests.

## The responsiveness bar

For a completion control, use **under 100 ms to clearly visible confirmation** as the product goal, with headroom rather than treating 100 ms as a comfortable budget. Apple describes approximately 100 ms as a noticeable-delay threshold for discrete interactions and recommends allocating less than half of that to main-thread work. A reasonable engineering goal here is a warmed handler comfortably below 5 ms and visible confirmation within a few display intervals. Apple's guidance is approximate, not an XCTest tap-duration requirement. [Apple: Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness).

For scrolling, a frame budget is roughly 16.7 ms at 60 Hz or 8.3 ms at 120 Hz; Apple's recommended main-thread work budget is usually below 5 ms. FPS is useful alongside the refresh-rate target, but **hitch count, total hitch duration, worst gap, and hitch ratio** explain interruptions better than average FPS alone. Apple's rendered-animation guidance considers a hitch ratio below 5 ms/s good, 5–10 ms/s worth investigating, and 10 ms/s or more poor. Apply those bands to native animation metrics, not as a phone acceptance test for this callback proxy. [Apple: Eliminate animation hitches with XCTest](https://developer.apple.com/videos/play/wwdc2020/10077/).

## Corrections to the earlier measurements

1. XCTest's 373-ms `tap()` measures event synthesis, automation queries, synchronization, and app work. It is not a 373-ms app handler. The extra approximately 1.07 seconds in `XCTWaiter` was polling after the accessibility label had already changed.
2. The earlier basic performance fixture used an **in-memory SwiftData store**. It could not characterize actual SQLite saves. The new profile uses a fresh, disposable SQLite store in its own temporary directory, separate from normal workout data.
3. Default `XCTCPUMetric()` and `XCTMemoryMetric()` target the **test runner**. Earlier reported 30-ms CPU and approximately 22-MB memory results must not be treated as app measurements. The refined suite explicitly passes `application: app`, including storage metrics.
4. Routine prescriptions did not prove the active set count: `WorkoutSessionStarter` carries forward historical prescriptions. The normal profile is verified as ten exercises, three participants, and five active sets per participant per exercise. The explicit dense option now enforces 64 sets on the first active exercise and uses twelve exercises; it is a separate stress case.
5. Capturing PNGs inside the app distorted CPU, memory, and logical-write metrics. That experiment is retained as a separate earlier scenario version. The primary workflow now records the simulator screen externally and writes only small diagnostic records from the app. Optional rendered-window snapshots require a separate launch argument.

## What the refined setup measures

### Fixture and configuration

- iPhone 17 Pro simulator, pinned by UDID for comparisons; the main runs use iOS 26.5. Other runtimes are separate profiles.
- Optimized Debug build (`SWIFT_OPTIMIZATION_LEVEL=-O`) because fixtures/probes are Debug-only; coverage and parallel test execution are disabled. This is a development regression configuration, not an uninstrumented Release benchmark.
- Ten exercise logs, three participants, five sets each; 48 generated historical sessions plus eight basic history sessions, and one active session: 57 total sessions. The larger-history case requests 192 generated sessions and checks actual counts.
- The 60-second rest countdown is started by completing Alex's first set. The elapsed-workout label also runs. Tests verify Skip remains visible after the measured actions. A manually started seconds/minutes exercise timer is covered separately by functional regression tests.
- No CPU, memory, or temporary-file load toggle is enabled. Load comparisons require distinct matched profiles; this report's figures are unloaded.

### Completion interval and visible evidence

The primary timestamp begins at entry to the SwiftUI action handler. It includes mutation, synchronous parent-handler work, save, SwiftUI processing, and delay before the completion indication is seen in recorded simulator frames. It **excludes time before the action handler**, including input delivery and the synthetic press duration. It is therefore an action-to-visible simulator metric, not a complete finger-contact-to-phone-display measurement.

A Debug-only binary optical clock appears in the recorded screen. It encodes the app launch token, action sequence, action timestamp, and display-link timestamp. The native AVFoundation decoder reads that clock in the same video frames as the actual set buttons; it does not estimate video start time from a host wall clock. Changed set IDs and button rectangles are recorded by an observer participating in the completion state update.

The decoder compares the checkmark corner region against its preceding frame. A recognizable change requires mean RGB difference of at least 12/255 and at least 8% of channel samples changing by more than 30/255. Individual completion requires its region to change; shared completion requires **every changed participant's region** to change. The decoder saves the first qualifying full frame for inspection. This detects visible confirmation rather than merely an accessibility-label change, but it is a threshold-based pixel detector, not a semantic image recognizer.

Results are quantized by captured frames and the optical clock's display callback. Allow approximately one 60-Hz interval (16.7 ms) of uncertainty, plus any capture gap. Small differences near that scale are inconclusive. Recording, XCTest, and the optical-clock overlay can perturb the simulator. Large timestamp gaps and missing/undecodable samples remain visible in the run data; a run cannot pass collection unless it has at least five qualifying completion samples per action and actual scroll samples.

The app separately records mutation, save, and Live Activity durations, handler return, view-observer update, and subsequent display-link callbacks. **View-observer updates and display-link callbacks are not GPU presentation timestamps.** They help locate work in the pipeline; the video supplies the visual evidence. Phase totals may include Live Activity calls after handler return, so do not add phase medians to derive handler time.

### Warmup, reset, and assertions

Each XCTest measure block has a warmup plus five measured iterations. Setup completions and the metric warmup are excluded from the primary summary. Individual measurements repeatedly complete the same visible second set, undoing it outside the measured interval. Shared setup first catches Jordan and Owen up to Alex, then repeatedly completes the second set for all three; reset taps and assertions run after `stopMeasuring()`.

This avoids comparing progressively different set positions or measuring offscreen controls. Catch-up setup remains in raw records for separate examination. Cold first completion is retained, but is not mixed into warmed medians. Five samples yield descriptive medians/maxima and interpolated p95 estimates; they are insufficient for a confident population p95 or a statistical speedup claim.

### Scroll interval

A completed set and running countdown are established before scrolling. One up/down pair warms row reuse and image caches. The test then measures five fast up/down pairs; XCTest's measure warmup adds another pair. Both setup and assertions are outside the measure block.

The app finds the active vertical UIKit scroll view and retains raw frame intervals while profiling is enabled. Primary callback summaries include intervals whose previous callback reported dragging/deceleration. Whole-window summaries are also retained. Hitch proxies use gaps above 1.5 times the expected display-link interval, summing excess gap time per second of the sampled motion duration.

These are **main-thread callback metrics**. UIKit scrolling state can outlast substantial visible movement, and the callback does not prove a distinct frame reached the display. The current simulator supplies only duration for `XCTOSSignpostMetric.scrollingAndDecelerationMetric`; missing native frame/hitch data remains missing. The ideal physical acceptance capture is Animation Hitches/Instruments, with actual rendered FPS, hitch count and ratio at the phone's current refresh rate.

## Results and history

### Matched completion comparison

Baseline [20261007T153145Z](performance/runs/20261007T153145Z.json) and final [20261007T210047Z](performance/runs/20261007T210047Z.json) use the same iOS 26.5 simulator, SQLite fixture, optimized Debug build, external video and lightweight optical clock. Scenario version 5 adds motion-scoped scrolling and storage collection for scrolling; completion pixels and timing definitions are unchanged from version 4. Each warmed row below contains five samples.

| Action / measurement | Original production path | Final production path |
| --- | ---: | ---: |
| Individual handler median / p95 | 3.05 / 3.21 ms | 1.39 / 1.45 ms |
| Individual view observer median | 5.58 ms | 3.49 ms |
| Individual visible pixels median / p95 / maximum | 107 / 112.8 / 114 ms | 107 / 132 / 132 ms |
| Shared handler median / p95 | 3.50 / 3.65 ms | 1.91 / 2.09 ms |
| Shared view observer median | 7.53 ms | 5.67 ms |
| All three shared badges visible median / p95 / maximum | 215 / 228.6 / 232 ms | 107 / 114.8 / 116 ms |

The shared median fell by approximately 50%. This is a useful simulator result across a bundle of changes, not proof that one particular sort or save optimization caused all of it. The individual visual result did not improve, and its final observed tail is worse. Confirmation-animation removal is a plausible explanation for the shared visual improvement, but no isolated animation-only benchmark establishes causality.

The optimized run that retained the parent's existing animation but disabled the confirmation indicators' animation measured 96/98 ms for individual/shared pixels. Removing the parent animation later measured 115/116 ms. The final run measured 107/107 ms. That additional animation change is not demonstrated to improve latency; it keeps completion state updates immediate without animating the surrounding grid. These small differences need repeated paired runs.

### Where the time goes

| Final warmed phase median | Individual | Shared |
| --- | ---: | ---: |
| Model mutation | 0.153 ms | 0.470 ms |
| Synchronous save | 1.194 ms | 1.393 ms |
| Handler return | 1.394 ms | 1.911 ms |
| Live Activity work accumulated for the action | 1.067 ms | 1.107 ms |
| Observer sees updated completion state | 3.488 ms | 5.666 ms |
| First collected display callback after observer update | 117.042 ms | 117.179 ms |
| Completion indication detected in video | 107 ms | 107 ms |

The observer reports model-driven UI processing within several milliseconds. Most of the approximately 107-ms visual interval occurs after the synchronous handler work. This experiment does **not** attribute the rest to a database save: the run does not record a full render-server/GPU timeline. Run-loop scheduling, UIKit/SwiftUI layout/render transactions, synthesized gesture behavior, optical-clock scheduling, screen capture and the simulator compositor can contribute. A delayed display callback is not equivalent to CPU work lasting that entire interval. The optical clock's frame timestamp and the diagnostic callback use different checkpoints; their quantized medians need not be ordered exactly.

The earlier 1.5-second interval was dominated by automation and waiter polling. It must not be graphed as app visual latency. The new app-handler and pixel timestamps separate those quantities.

### Cold completion and storage evidence

| First individual completion after launch | Baseline | Final |
| --- | ---: | ---: |
| Dirty models at save | 37 | 2 |
| Inserted / deleted models | 0 / 0 | 0 / 0 |
| Save duration | 26.99 ms | 19.53 ms |
| Handler duration | 33.65 ms | 20.74 ms |
| View observer | 38.66 ms | 25.57 ms |
| Video completion indication | 365 ms | 398 ms |

These are single cold observations, excluded from warmed medians. They demonstrate fewer unnecessary model writes and less synchronous work; they **do not demonstrate faster cold visual confirmation**. First-save/faulting/framework work remains relevant even after removing initialization edits. No claim is made that the remaining 19.5 ms is a particular number of SQLite statements.

XCTest app-targeted interval averages in the final run:

| Scenario | App CPU | Logical app writes | Peak physical app memory |
| --- | ---: | ---: | ---: |
| Individual completion | 0.222 s | 76.2 kB | 74.9 MB |
| Shared completion | 0.243 s | 89.3 kB | 74.9 MB |
| One up/down scroll pair | 0.747 s | 0 kB | 78.3 MB |

These CPU and write figures encompass the XCTest interval, including framework work and optical diagnostics; they are not handler CPU or database-only writes. The completion clock interval still averages roughly 0.38 seconds because it includes XCTest's synthesized tap. Scrolling's zero logical writes in the measured interval supports the source finding that timer redraws are not saving the workout every second.

### Scrolling with countdown running

| Run | Motion callback FPS proxy | Proxy hitches | Excess-gap ratio | Worst gap | Motion duration |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before weight initialization fix, 48 generated histories | 58.21 | 19 | 28.16 ms/s | 72.46 ms | 30.80 s |
| Before initialization fix, 192 generated histories | 58.20 | 18 | 28.51 ms/s | 68.80 ms | 29.93 s |
| Final initialization fix, 48 generated histories | 58.17 | 19 | 29.87 ms/s | 72.76 ms | 30.05 s |

Native rendered FPS/hitch metrics are unavailable in all three simulator result bundles. The numbers above sample main-thread callbacks during UIKit motion and are not rendered-frame measurements. No convincing scrolling improvement is demonstrated. The original whole-window callback rate was 57.54 versus the final 57.63; comparing original whole-window cadence with current motion-only cadence would be misleading.

### History scaling and iteration ledger

The history scaling run [20261007T205145Z](performance/runs/20261007T205145Z.json) validates 201 sessions including the active workout, versus 57 in [20261007T204803Z](performance/runs/20261007T204803Z.json). Both were taken before the initialization fix. Increasing generated histories from 48 to 192 changed warmed individual/shared handler medians from 1.54/2.03 to 1.62/2.14 ms, and saves from 1.33/1.50 to 1.40/1.57 ms. Peak app memory increased to approximately 92–95 MB. This small experiment shows no history-proportional per-set latency increase; source inspection supplies the stronger conclusion that PR/history work has been removed from this path. It does not prove SwiftData has constant cost under arbitrary database growth.

| Retained successful run | Purpose | Individual / shared visible medians |
| --- | --- | ---: |
| [152440Z](performance/runs/20261007T152440Z.json) | Earlier app-PNG capture; overhead-contaminated, separate version | 114 / 282 ms |
| [153145Z](performance/runs/20261007T153145Z.json) | Matched lightweight baseline | 107 / 215 ms |
| [153640Z](performance/runs/20261007T153640Z.json) | PR, grid, save, Live Activity and badge changes | 96 / 98 ms |
| [204256Z](performance/runs/20261007T204256Z.json) | Parent completion animation removed | 115 / 116 ms |
| [204803Z](performance/runs/20261007T204803Z.json) | Motion-scoped scroll collection | 115 / 115 ms |
| [205145Z](performance/runs/20261007T205145Z.json) | 192 generated histories; separate scaling profile | 116 / 103 ms |
| [210047Z](performance/runs/20261007T210047Z.json) | Weight initialization fix; final measured app path | 107 / 107 ms |

All run IDs have the date prefix `20261007T`. Failed fixture/build attempts are also retained in the JSON ledger and history table. They are excluded from trend charts. The dense 64-set stress option is implemented but was not benchmarked in this pass.

## Completion: work and algorithmic cost

Let `E` be active exercises, `P` participants, `S` sets per participant, `H` historical sessions, `C` catalog entries, `A` PR achievements, and `D` dirty persistent models. These are source-level upper bounds, not claims about undocumented SwiftData internals.

| Operation | Previous cost | Current cost / behavior |
| --- | --- | --- |
| Individual eligibility and mutation | One `orderedSets` sort plus prefix/suffix scan: `O(S log S)` | Action still checks the model's ordering rules; mutates one set. |
| Rendering a participant's grid | Repeated sorting/scanning for every button and repeated row construction: approximately `O(S² log S)` | Cache row arrays locally; one sort plus two eligibility passes, then constant-time lookups: `O(S log S)` with `O(S)` temporary storage. |
| Shared completion | Repeated sorted counts/next-set selection, approximately `O(P S log S)` | Count each participant once, reuse counts, find the minimum eligible order with linear scans: `O(P S)` for existing sets. Rare append fallback can still sort for target defaults. |
| Active-workout PR baseline | History sort/traversal and achievement sorting, approximately `O(H log H + H E P(S + P) + A log A)` for similarly sized history sessions | Removed from active-screen loading. |
| Per-set live PR markers | Whole current workout scan, approximately `O(E P(S + P))`; participant membership checks scan names | Removed. No global history traversal was happening on every set; that distinction matters. |
| Live Activity details | Several calls per synchronization with repeated sorts; participant matching can be `O(P²)` | Compute one tuple per synchronization. Count/latest-set scans use unsorted arrays; approximately `O(P² + P S)`, plus ordering the small exercise list. |
| SwiftData save | Synchronous main-context checkpoint | Retained once per completion; relevant timer clearing is included in the same save. App code makes no history-wide serialization or save loop. Framework/SQL cost must be measured. |

The meaningful quadratic term was **rendering many set buttons**, not an algorithm comparing every historical workout with every other workout on each tap. The actual current routine has at most about ten exercises, which bounds `E`, but a large `S` can still hurt if work is repeated for every button. Avoiding repeated sorts remains useful even with small routine counts.

### Parent completion handler and writes

1. Individual completion checks order and updates `isCompleted`, left/right completion flags, and `completedAt`. Shared completion applies those fields to each eligible participant once.
2. `scheduleSave()` marks a pending checkpoint; it does not itself write the database.
3. The parent clears a matching exercise timer, updates the rest-timer start/duration, and saves. Previously clearing the exercise timer could save once and restarting rest could save again. They are now coalesced for this action. The ordinary weighted fixture does not exercise that extra-save branch; the exercise-timer regression covers its behavior.
4. The rest-timer state change triggers Live Activity synchronization. Previously starting rest called synchronization directly as well as through `onChange`; the redundant direct call is removed. Notification/activity work is separate from workout persistence.
5. SwiftUI reads changed models and updates number styles, completion badges, eligibility, and timer state. Confirmation indicators opt out of the inherited animation.

The first completion initially had 37 dirty models and approximately 25–28 ms of save work. Source inspection identified weight-field initialization: setting its text in `onAppear` ran the edit handler, assigned the unchanged participant weight and cleared every set-specific measurement. Two visible exercises × three participants × (one participant plus five sets) produced 36 dirty models before the session timer change. Comparing initialized text with its existing display value prevents those writes and preserves both per-set overrides and underlying precision. A passing regression completes a 123.5-lb overridden set and a 95.06-lb base set, checking 1,748.5 lb summary volume rather than trusting the rounded 95.1 display.

For warmed measurements, dirty counts are two models for one participant (one set plus the session timer) and four for synchronized completion (three sets plus the session). There are zero inserted/deleted models in these measured existing-set completions. Additional pending edits would change those counts. **Dirty-model counts are not SQL statement counts or NAND write counts.** The store may perform journal, relationship, metadata, or checkpoint writes; app-targeted logical-write metrics measure all app writes in their interval, including small diagnostic output.

The warmed save duration is not evidence that a cold phone save is always cheap: the first completion, relationship faulting, storage contention, thermal conditions, and large unsaved changes can differ. Keep per-set persistence while investigating such a case with Data Persistence/File Activity. Do not pass main-context models to a detached task to move saves off-thread; that requires a deliberate actor/persistence design.

### Personal records after this change

Active cards no longer show live PR badges. The completion celebration already computes achievements from current and previous history, and history/progress screens still calculate PRs when those screens are used. This moves PR work out of both the active-screen startup and per-set path without changing the PR definition or stored workout data.

The end-of-workout summary still traverses history and filters previous achievements per current achievement. That can be `O(currentAchievements × previousAchievements)` in addition to the two history calculations. With a bounded routine, current achievements are bounded by exercises/participants, but the history term grows. A precomputed dictionary of previous best values is a possible future optimization if workout-end latency becomes a problem; it is not needed for these set/scroll intervals.

## Scrolling: timer, residency, and remaining investigation

The screen uses SwiftUI `List` and reusable/lazy exercise rows. SwiftData models and catalog lookups can remain cached in memory while the corresponding visual rows are created or reused as needed. Keeping ten model references resident does not require eagerly rendering every image, text field, menu, and set button. Forcing all cards into a non-lazy stack can shift work and increase startup, observation, and layout cost; these measurements do not justify that change.

The workout elapsed-duration `TimelineView` updates its small label once a second. The rest countdown uses the system's timer text. Neither timer schedules a database save or a PR calculation every tick. On iOS 18+, exercise selection changes when a row crosses a visibility threshold; there is no continuous per-row geometry publication. The global session completion-count properties traverse the current workout; they do not compare historical workouts. Group catch-up counts concern only the selected participants in the current exercise and are necessary immediately for group completion semantics.

The grid optimization reduces reusable-row work, and the image thumbnail/cache infrastructure remains in place. However, a similar callback FPS with occasional gaps is not proof that scrolling got faster. The remaining attribution should distinguish SwiftUI row/layout work, relationship faulting, image cache misses, timer redraws, UIKit/accessibility work initiated by XCTest, and the simulator compositor. Average FPS alone cannot assign those causes. Native phone animation metrics are still required before declaring the scrolling complaint resolved.

## Repeatable workflow and interpretation

```sh
make workout-profile PROFILE_LABEL=before-change
# Make one focused change.
make workout-profile PROFILE_LABEL=after-change
make workout-profile-graph

# Pin a simulator when more than one iOS runtime is installed.
make workout-profile PROFILE_DEVICE=<simulator-udid> PROFILE_LABEL=after-change

# Separate scaling/stress profiles; do not blend them with the normal profile.
make workout-profile PROFILE_HISTORY=192 PROFILE_LABEL=larger-history
make workout-profile PROFILE_DENSE=1 PROFILE_LABEL=dense-stress
```

The runner chooses a simulator deterministically, records its UDID/runtime, creates the isolated fixture, clears only the previous diagnostic output, captures video, exports XCTest metrics, decodes completion pixels, and stores results. The ledger records source digest, Git HEAD, configuration, fixture arguments/actual counts, timer/load conditions, raw samples, sample count, and collection/test status. Current runs also archive the source files and patch beside the video. Failed and incomplete attempts remain in the ledger and are excluded from trend lines.

Graphs group matching scenario versions, build, store, history, density, load and runtime. A source digest identifies uncommitted changes; no commit is required to profile. Use paired repeats with similar host load before claiming small improvements. For acceptance, aim for visible confirmation below 100 ms including input delivery, small cold/warm tails, no major scrolling gaps, and native hitch ratio below 5 ms/s on the actual iPhone.

## Verification and remaining limits

- The final simulator profile passed all three performance tests, collecting five measured pixel samples for each completion action and a motion-scoped scroll capture. The larger-history profile also passed all three tests and actual fixture validation.
- Thirteen active-workout functional regressions passed with zero failures: individual/shared completion, catch-up, skipped-set eligibility, one/two/three-person grids, navigation, close/resume and edit persistence, workout summary/PR behavior, rest header and seconds/minutes exercise countdown. The subsequently added precision/override regression passed separately: one executed test, zero failures. Its early attempts caught two test assumptions (summary decimal format and a one-set inherited prescription), which were corrected in the fixture/assertion.
- Release simulator build passed, confirming the Debug-only probe/fixture paths compile away. Changed Swift files passed formatting lint, the Xcode project passed plist validation, and `git diff --check` passed.
- `make phone-deploy` built, installed and launched successfully on Chase's iPhone 17 Pro. Device Hub inspection of the disposable in-memory fixture confirmed individual and shared completion badges and the running rest countdown. This is visual behavior verification, not an instrumented physical latency benchmark.
- No schema change or migration was introduced. Live PR markers are intentionally removed from active cards; workout-end celebration and history/progress PR views remain.
- Remaining performance limits: no reliable individual visual speedup, no proven cold visual speedup, no confirmed scrolling fix, no native simulator rendered FPS/hitch metrics, no uninstrumented Release/120-Hz physical acceptance capture, no loaded/dense benchmark in this pass, and only five warmed samples per action per run. These limits should guide the next measurements rather than be hidden by average tap times.

Verification artifacts: functional results at `build-ui-tests/Logs/Test/Test-StrengthLog-2026.10.07_13-57-05--0700.xcresult`; precision regression at `build-weight-override-final/Logs/Test/Test-StrengthLog-2026.10.07_14-08-23--0700.xcresult`; performance result bundles/videos/source snapshots under `build/performance/<run-id>/`. Final phone deployment log is `/private/tmp/strength-performance-phone-deploy-final.log`.
