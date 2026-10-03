# The same exercise between different routines should track the same weight and reps

## User requirements

- As a user, I want a person’s latest weight and rep prescription for an exercise to carry between routines that include that same exercise, so that I do not have to re-enter the same values when switching routines.
- As a user, I want each person’s values to remain independent, so that one person’s history never seeds another person’s workout.
- Assumption: “same exercise” means the same stable master exercise ID. Existing name-based matching remains available for legacy logs without an ID; duplicated master exercises remain distinct unless they share an ID.
- Keep the routine-specific participant selection and existing no-history/default behavior unless implementation review finds a conflict with the intended cross-routine behavior.

## Architecture and data model

`WorkoutSessionStarter` currently filters history to the selected routine before it finds prior exercise logs. Change the seed lookup to consider sessions across routines, ordered newest first, and select the matching exercise log for each participant. Continue creating independent `ExerciseLog` and `ParticipantLog` snapshots in the new session; routines remain structural templates and do not gain weight or rep fields.

No material SwiftData schema or migration change is required: `WorkoutSession` already records the routine ID, `ExerciseLog` stores an optional stable `exerciseID`, and `ParticipantLog`/`WorkoutSet` store per-person measurement and rep values. Preserve legacy name matching and routine prescriptions as fallback for older records without usable session history. Keep current set seeding rules, including copying completed sets and using existing defaults when the latest matching history has no completed sets.

## Basic test cases

- Log an exercise for a person in Routine A, then start Routine B containing the same master exercise. Verify that the person’s latest load, reps, and completed-set structure seed Routine B.
- Log newer values for that exercise in Routine B, then start Routine A again. Verify the newer cross-routine values are used.
- Use two people with different loads and reps. Verify each person receives only their own latest values, including when their most recent exercise history came from different routines.
- Add a different exercise with a similar name or a duplicated master exercise. Verify it does not inherit values from the other exercise when their stable IDs differ.
- Verify legacy ID-less history can still match by the existing case-insensitive name fallback, and that no matching history retains the current routine-prescription/default behavior.
- Verify an exercise with no completed sets follows the existing fallback rule and does not restore unfinished or skipped sets as completed work.

## High-level implementation details

1. Update `WorkoutSessionStarter` in `StrengthLog/RoutinesView.swift` to keep routine-scoped history for routine-specific participant selection, while using all relevant sessions for cross-routine exercise seeding. Ensure the candidate history is ordered by `startedAt` and matches both the exercise and participant before choosing the latest values.
2. Preserve the established matching precedence: stable IDs for canonical exercises and case-insensitive names only for legacy records missing an ID. Preserve completed-set copying, per-set measurement overrides, skipped/completion reset behavior, and current defaults.
3. Add regression coverage in the existing workout test suite for switching routines, newest-history precedence, participant isolation, duplicate exercise IDs, and legacy/default fallbacks. Update the relevant product and architecture documentation to describe exercise-level history seeding across routines while retaining routine-specific participant selection.
4. Review edge cases where the latest matching session has no completed sets, where a participant did not appear in the newest session, and where legacy records lack exercise IDs. Keep history reads scoped to the exercise/participant data needed by startup so larger workout histories do not make routine start unnecessarily expensive.
5. Verify with the focused regression coverage and the repository’s prescribed app verification workflow during implementation; this plan-only task does not run app tests or change application files.
