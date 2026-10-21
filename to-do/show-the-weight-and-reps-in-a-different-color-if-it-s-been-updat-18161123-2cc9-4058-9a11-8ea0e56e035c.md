## User requirements

- As a user, I want a weight or rep value to appear in a different color when it differs from the last time I did that exercise, so that I can quickly see what changed in my current workout.
- As a user, I want the comparison to use my own most recent history for that exercise, so that another participant's values do not affect what I see.

Assumptions: “Updated” means the current value differs from the prior recorded value; changing a value and then restoring it to the prior value removes the highlight. Compare exercise history across routines, consistent with current workout seeding. Highlight weight and reps independently. If no comparable prior value exists, leave the current presentation unchanged. The exact semantic highlight color and behavior when historical and current weight units differ should be settled against the existing theme and unit behavior during implementation.

## Architecture and data model

No material data-model, persistence, or migration change is expected. `WorkoutSession`, `ExerciseLog`, `ParticipantLog`, and `WorkoutSet` already persist session history, participant-specific loads, and per-set reps/weight overrides. Derive the prior-value baseline from the latest eligible history for the same participant and exercise, using stable exercise IDs when available and the existing legacy name fallback only when an ID is absent.

Use the current session’s values and the prior completed, non-skipped set values to determine highlight state. Match sets by their ordered position because each new workout creates new set records; newly added sets without a corresponding historical set have no baseline. Keep the calculation separate from value persistence, and avoid a SwiftData fetch in each small control if the parent can supply a bounded or precomputed history snapshot. Preserve existing profile colors for participant identity and completion controls while applying a consistent semantic color to only the changed value.

## Basic test cases

- Start an exercise with a prior completed set at 100 lb and 8 reps. With the seeded values unchanged, neither value is highlighted.
- Change only the load to 105 lb: the load is highlighted and reps are not. Change only reps to 9: reps are highlighted and load is not.
- Change a value and restore the historical value: its highlight clears without changing completion state.
- For multiple participants, compare each person only with their own latest matching exercise history.
- Use history from another routine for the same exercise; its matching participant values provide the baseline.
- Ignore deleted workouts and prior sets that are incomplete or skipped. If no eligible value or corresponding set exists, do not show a false change indicator.
- Verify reps-only exercises retain their normal controls and that a historical/current weight-unit mismatch follows the explicitly chosen comparison rule without presenting a misleading change.

## High-level implementation details

1. Trace the active-workout presentation and history inputs around `ActiveExerciseCard`, `MeasurementStepper`, `ParticipantExerciseCell`/`CompactRepsControl`, and `WorkoutSessionStarter` in `StrengthLog/ActiveWorkoutView.swift` and `StrengthLog/RoutinesView.swift`.
2. Reuse the existing exercise identity and history ordering rules: newest non-deleted session first, stable `exerciseID` matching with legacy name fallback only when an ID is missing, participant-specific matching, and completed non-skipped sets for the baseline. Define a small derived comparison value/helper so UI rendering does not duplicate history selection logic.
3. Thread the prior baseline into the load and reps controls. Apply the chosen semantic highlight to only the field whose effective value differs; account for set-level measurement overrides versus participant load, optional history, set-count changes, and active-workout edits. Preserve accessibility labels and ensure the visual distinction is not color-only if the project’s existing status conventions call for supporting text or another cue.
4. Add a deterministic active-workout fixture and focused UI coverage for independent load/reps changes, reset-to-baseline, participant isolation, cross-routine history, and ignored incomplete/skipped/deleted history. Extend an existing focused target or add a Makefile target following the repository’s UI-test conventions.
5. Verify with `make lint` and the focused UI test, then use `make phone-deploy` and visually inspect the affected phone UI after successful verification, as required by the repository. Simulator/UI evidence should be reported separately from physical-device acceptance. No build or test is part of this plan-only task.

Risks and unresolved decisions: history can contain legacy records without stable IDs, changed tracking units, participant-name collisions, per-set load overrides, and custom set counts. Confirm whether to compare weight only when units match or normalize units, and confirm the app’s semantic highlight color while preserving the existing participant-color system.
