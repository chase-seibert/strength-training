## User requirements

- As a user, I want exercise history opened from the current routine or workout to show separate weight and volume graphs, so that I can distinguish load progress from the amount of work completed.
- As a user, I want the graphs to retain each active participant's series, so that I can compare their history without mixing their results.
- Assumption: “weight” means the highest load from a completed, non-skipped set for that exercise in each workout. “Volume” means the sum of load × reps across that exercise's completed, non-skipped sets in that workout. Preserve the exercise's tracked unit and current participant coloring. The task notes do not specify alternate definitions or chart interaction changes.

## Architecture and data model

No material persistence, schema, or migration change is required. `ExerciseGroupHistoryView` already queries workout history and derives chart points from each session's exercise and participant logs. Extend that derived, in-memory history for weighted exercises to carry both per-session best load and summed volume, while preserving stable exercise-ID matching and the existing legacy name fallback. Keep completed/non-skipped set filtering consistent across both series. No new stored fields are needed.

## Basic test cases

- A weighted exercise with multiple completed sets shows two labeled charts: load in the exercise's unit and volume in that unit × reps.
- Given completed sets with different loads and rep counts, the load chart uses the session's highest load and the volume chart sums each eligible set's load × reps; the two values are calculated independently.
- Skipped and incomplete sets do not affect either chart. A session with no eligible sets contributes no point.
- Multiple active participants appear as separate, correctly colored series in both charts; a participant with no eligible set in a session has no point for that session.
- Existing exercise-ID matching, legacy name fallback, personal-record indicators, and history empty state continue to work.
- Non-weight tracking units retain their current history chart behavior.

## High-level implementation details

1. Review `ExerciseGroupHistoryView` and its `ExerciseHistoryPoint` derivation in `StrengthLog/ActiveWorkoutView.swift`; preserve the existing weighted PR calculation and selected-point semantics where they remain applicable.
2. Add a session-level load and volume value for weighted exercises, derived from the same completed, non-skipped sets and participant log. Do not reuse the best load-times-reps set as total volume.
3. Render two stacked, participant-colored Swift Charts graphs for weighted exercises, with clear labels and units. Retain per-person history and PR markers on the appropriate load graph; keep selection/detail behavior coherent with the load graph and avoid implying a selection also applies to the volume graph unless designed explicitly.
4. Update `docs/design.md` and `docs/product-requirements.md` to describe the two metrics and their definitions. Add focused UI coverage for distinct load and summed-volume values, multiple participants, and excluded skipped/incomplete sets; run the repository's relevant verification and deploy/inspect the visible change following `AGENTS.md`.
5. Confirm the product meaning of “weight” and “volume” during implementation if task context from the user or task detail becomes available; the definitions above are assumptions to make the plan concrete.
