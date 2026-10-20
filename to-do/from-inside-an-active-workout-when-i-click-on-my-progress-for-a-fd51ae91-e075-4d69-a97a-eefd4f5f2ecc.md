## User requirements

**Plan approval: Approved.** Implementation is not ready to finalize until the simulator chart screenshots have been reviewed and the visual result is accepted.

- As a lifter, I want to see one progress chart for a weighted exercise that uses the same load-times-reps value as my personal record, so that the chart reflects the strength metric used by the app.
- As a lifter, I want to tap a point on the chart and see the load and reps from that set, so that I can understand what produced the score.
- Preserve the active-workout entry point and the comparison between currently selected people. Assumption: this change applies to pounds- and kilograms-tracked exercises; non-weight exercise history keeps its existing metric and presentation.

## Architecture and data model

The change is presentation and history-point calculation only. `ExerciseGroupHistoryView` in `StrengthLog/ActiveWorkoutView.swift` already fetches workout history and renders the charts. Build each weighted point from the best completed, non-skipped set for that person and exercise in that session, using the existing `PersonalRecords.value(for:participant:unit:)` calculation (`load × reps`) and retain that same set's load and rep count for the detail shown on selection. This avoids combining the highest load from one set with the highest reps from another.

Workout sets already persist load, reps, completion, and skipped state, and PRs are derived from history. No persistence, schema, or migration change is needed. Keep the existing stable exercise-ID matching with its legacy name fallback, deleted-session exclusion, and per-person colors. Update the design/product requirement wording that currently describes separate measurement and reps lines.

## Basic test cases

- For a completed history containing sets of 15 lb × 12 reps and 20 lb × 7 reps, show the larger score of 180 lb·reps, and selecting that point shows 15 lb and 12 reps together.
- For kilogram history, show a kg·reps score and the corresponding kg load and reps. Selecting a point near a line resolves to the appropriate workout/person point and exposes the same values accessibly.
- With multiple selected people, show their per-person score series in their existing colors; selecting one person’s point reveals only that person’s matching set values.
- Ignore incomplete and skipped sets when finding a point. If there are no eligible completed sets, retain the empty-history state without a fabricated score.
- Confirm a weighted exercise has one score chart rather than separate load and reps charts, and that non-weight exercise history retains its current behavior.

## High-level implementation details

1. Refactor the history-point builder in `ExerciseGroupHistoryView` to select the highest-scoring eligible set per session/person for weighted exercises. Use the shared PR value calculation and carry the selected set's recorded load (falling back to participant load) and actual reps on the point. Keep PR markers consistent with `PersonalRecords.achievements(in:)`.
2. Replace the two weighted charts with one chart whose y-value is load × reps and whose unit label reflects lb·reps or kg·reps. Retain person color/series grouping. Add point selection so tapping the line resolves to a nearby data point and presents its load and reps; include a clear selected state and an accessible label/value for assistive technology.
3. Keep other tracking-unit chart behavior outside this weighted-metric change. Update `docs/design.md` and the matching `docs/product-requirements.md` statement to describe the single weighted score chart and point detail.
4. Add or extend focused history UI coverage in `StrengthLogUITests/WorkoutNavigationUITests.swift`, using a deterministic fixture with competing load/reps sets, multiple people, and excluded skipped/incomplete sets. Verify chart count/metric and the selected point detail, then run the focused UI test and the repository's standard verification.
5. Launch the verified build in the iPhone 17 Pro simulator. Capture screenshots of the chart and a selected point, review that the chart is readable and the selected load/reps are clear, and make any needed visual adjustments before calling the implementation final. Keep the screenshots as review evidence. After successful verification, also follow repository guidance to deploy with `make phone-deploy` and visually inspect the chart on Chase's iPhone 17 Pro; report separately if simulator, device access, signing, or launch prevents either visual check.

Risk to watch: score values must be computed from one actual set and use the same completed/non-skipped and PR semantics as the shared calculator. Confirm the intended tie behavior for equal load×reps sets while implementing; regardless of tie resolution, the displayed load and reps must come from the same selected set.
