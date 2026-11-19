## User requirements

- As a lifter, I want a completed workout's length to end at the time I logged its last activity, so that time spent away after my final set is not counted as training time.
- As a lifter, I want workout lengths over a reasonable maximum (probably three hours) treated as invalid, so that a forgotten or implausibly long session does not distort workout history and summaries.

Assumption: “last activity” means the latest completed set across active participants, using the existing `lastSetCompletedAt` value. If there is no completed set, retain the explicit completion time as the fallback. Treat three hours as the maximum valid duration; an over-limit workout can still be completed and saved, but its length is unavailable. Confirm whether the three-hour limit should instead block completion before implementation. The change applies to workouts created and completed in the app; imported workouts keep their source timestamps.

## Architecture and data model

No persisted schema or migration change is needed. `WorkoutSession` already stores `startedAt` and `endedAt`, derives `lastSetCompletedAt` from completed sets, and validates intervals through `maximumWorkoutDuration`. The current limit is 24 hours, while completion presently records the explicit Complete Workout time.

At the native completion boundary, set the persisted `endedAt` to the latest completed activity timestamp (with the stated no-completed-set fallback), then mark the session inactive. Keep the existing single validated interval as the source for active status, history, celebration, coaching, and HealthKit duration. Lower the shared maximum to three hours so invalid intervals are consistently omitted. Existing completed sessions and imported history require no rewrite; the field remains compatible with the existing SwiftData schema.

## Basic test cases

- Complete a workout after logging sets, with a delay after the final set: persisted end and displayed completed length use the final set time, not the later completion tap.
- Log another set after an earlier set: the newest completed set determines the end time.
- Complete a workout with no completed sets: end time falls back to the explicit completion time and the interval is validated normally.
- Validate durations at and just under three hours: they remain valid; a duration just over three hours is invalid and is omitted from duration displays and HealthKit export while the workout itself remains completed.
- Validate zero, negative, non-finite, and missing intervals: they remain invalid; active duration continues to update from start to now subject to the same maximum.
- Verify imported completed workouts retain their source end time and existing stored sessions load without migration.

## High-level implementation details

1. Update `WorkoutSession.maximumWorkoutDuration` and retain centralized interval validation in `StrengthLog/Models.swift`; adjust duration-focused fixtures or smoke checks that encode the current 24-hour boundary.
2. Change the native `close(_:)` completion path in `StrengthLog/StrengthLogApp.swift` to end at the latest completed activity, preserving a completion-time fallback when no set has been completed. Keep save failure behavior and downstream completion, summary, and HealthKit handling aligned with the stored end.
3. Review duration consumers in `StrengthLog/HomeView.swift`, `StrengthLog/ProgressView.swift`, `StrengthLog/WorkoutCelebrationView.swift`, and `StrengthLog/StrengthLogApp.swift` to confirm they all use the validated session duration and do not independently recompute the old end time.
4. Update the timing statements in `docs/product-requirements.md`, `docs/architecture.md`, and `docs/design.md` so they consistently describe last-activity completion and the three-hour cap.
5. Run the focused duration checks and project verification. Since this changes iOS app behavior, build with the supported Makefile workflow and deploy with `make phone-deploy`; launch and inspect the affected workout completion/history UI on Chase's iPhone 17 Pro. Report any device, signing, or lock limitation and what remains unverified.

Material decision to confirm during implementation: whether three hours is strictly a validation/display/export ceiling (assumed here) or should actively prevent completion. Ensure the chosen rule is consistent across active timer, history, celebration, coaching metrics, analytics, and HealthKit export.
