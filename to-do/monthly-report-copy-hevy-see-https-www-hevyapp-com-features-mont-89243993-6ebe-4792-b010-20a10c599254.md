## User requirements

- As a user, I want a monthly recap of my previous calendar month's training, so that I can see what I completed and how it compares with the prior month.
- As a user, I want to review workouts, completed sets, training time, pounds volume, and personal records for that month, so that I can understand my training at a glance.
- As a user, I want to see workout days, frequently logged exercises, and available muscle-group coverage, so that I can spot consistency and training patterns.
- Assumption: the report summarizes the previous local calendar month, excludes active and deleted sessions, and follows Progress's primary-person context initially. Historical reports beyond the previous month, sharing, and new muscle tagging are outside this scope.

## Architecture and data model

- No material persistence, schema, or migration change is required. `WorkoutSession`, `ExerciseLog`, `ParticipantLog`, and `WorkoutSet` already store dates, participant membership, exercise identity, completion/skip state, load, reps, distance, duration, RPE, and set type. Workout duration is already validated from start/end dates.
- Build a value-type monthly summary from existing SwiftData history, following `ProgressSummaryBuilder` and `PersonalRecords` as the calculation sources. Keep saved history authoritative and derive report totals so edits/restores are reflected.
- Available metrics: completed workout count and workout-day calendar from session dates; training time from valid completed-session durations; completed, unskipped set count; pounds load × reps volume using existing per-side rules; personal-record achievements; and most-frequent exercises from completed logged sets.
- Muscle summaries can use each linked exercise's `primaryMuscle`. The model has only one primary muscle label, not primary/secondary contribution weights, so do not imply Hevy-style muscle volume distribution. Custom or legacy logs without a resolvable muscle label should remain in overall totals and be grouped as unclassified. Do not add muscle schema fields in this plan.
- Keep volume explicitly in pounds × reps, matching existing Progress calculations. Do not combine kilograms, bodyweight/repetition, distance, or timed exercises into that total. A total-duration metric is available only for sessions with a valid recorded end time.

## Basic test cases

- A completed workout inside the previous local calendar month contributes once to workout count and its local workout day; adjacent-month, active, and deleted sessions do not.
- A valid completed session duration contributes to training time. Missing, reversed, zero, or over-24-hour durations are omitted without hiding the workout or its other valid metrics.
- Completed, unskipped sets contribute to set count and supported pounds volume; incomplete and skipped sets do not. Per-side rep counting matches the existing Progress volume result.
- Monthly PRs include only achievements dated in the month and link to the source workout. Multiple sets that improve the same exercise/person record within one workout count once, consistent with `PersonalRecords`.
- Exercise ranking counts completed logged work, groups by stable exercise ID when available, and handles legacy name-only logs without double-counting duplicate rows in a session.
- Muscle totals use the primary muscle label for classified exercises; unclassified custom/legacy exercises remain visible in overall totals and do not create a fabricated muscle category.
- A month with no qualifying workouts shows an empty state and zero-valued summaries without a chart or ranking failure. A participant/group session contributes only to the selected participant's metrics.

## High-level implementation details

1. Add a focused monthly-summary value type/builder near `ProgressSummary.swift`. Pass an explicit `Calendar`, month interval, selected person, people, sessions, and exercise catalog/context as needed so month boundaries and legacy participant matching can be tested deterministically.
2. Reuse `WorkoutSession.workoutDuration`, `ExerciseLog.completedPoundsVolume(for:)`, active-participant filtering, and `PersonalRecords.achievements(in:)`; centralize date filtering so every card uses the same completed, non-deleted month population.
3. Add a Monthly Report section or destination from `ProgressView.swift`, consistent with current Progress cards and navigation. Present headline totals, a month/day workout calendar, month-over-month comparisons for comparable workout count, sets, duration, and pounds volume, followed by monthly PRs, top exercises, and primary-muscle set counts.
4. Make month navigation intentionally limited to the previous month for the first version, with an empty state when there is no history. Link PRs and calendar dates to existing `SessionDetailView` sessions. Avoid changing workout history or adding persisted report snapshots.
5. Verify through focused summary-builder tests for date boundaries, participant scoping, metric eligibility, PR de-duplication, and missing muscle labels; run the repository's appropriate lint/test workflow for implementation. No build, deployment, or app changes are part of this plan-only task.

Material decisions for implementation: choose whether the report is reached through a Progress card or a dedicated navigation row, and confirm the primary-person-only initial scope versus a participant picker. If broader muscle distribution is desired, it requires a separate decision about secondary muscle metadata and weighting.
