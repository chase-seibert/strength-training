# Persist the active workout side-reps reminder display choice

## User requirements

- As a user, I want the active-workout reminder to remember whether I last viewed total reps or the per-side split, so that I do not have to toggle it again each time I work out.
- As a user, I want that choice to carry across workout instances and routines that use the same exercise, so that the reminder behaves consistently wherever I train that exercise.
- The screenshot and task wording are interpreted as referring to the “BOTH SIDES” / “EACH SIDE” reminder on the Cable Russian Twists exercise card. The choice is a presentation preference; it must not change the stored rep target, set completion, or volume calculations.

## Architecture and data model

Persist the reminder's display mode on the shared master `Exercise` record, keyed implicitly by its existing stable UUID. This makes the preference exercise-wide across routines and workout instances and avoids adding routine-specific state or modifying historical workout snapshots. Replace the card-local `@State` source of truth with the master exercise value, while continuing to share the value across all participant reminders on the current card.

Add an optional persisted Boolean (or equivalently typed display-mode value) to `Exercise` in `Models.swift`. Its effective value should default to the current UI behavior, showing total reps, when no value exists. An optional field supports SwiftData's additive lightweight migration for existing stores; verify that existing stores open without destructive migration or history rewrites. No new repository layer or routine schema is needed because `ExerciseLog` already resolves the shared master exercise by `exerciseID`.

## Basic test cases

- On a reminder-enabled exercise, the first display with no saved preference shows total reps (“BOTH SIDES”), preserving current behavior.
- Toggle to “EACH SIDE,” leave the workout, and start another instance of the same routine: the reminder still shows the per-side split.
- Use the same exercise in another routine (and after relaunch): it shows the same saved display choice.
- With two or more participants visible, toggling either participant's reminder updates every participant immediately; reopening the exercise retains that choice.
- Change one exercise's display choice and confirm a different exercise retains its own default or saved choice.
- Odd totals still show the existing nearest split range. Toggling the reminder leaves rep targets, set completion, and completed volume unchanged.
- Exercises with the reminder disabled do not show the reminder and retain existing `standard` / `perSide` behavior.
- An existing store with no saved display choice opens normally and uses the total-reps default; saving the choice survives store reopen without changing existing workout IDs, sets, or history.

## High-level implementation details

1. Confirm the model registration and exercise lookup paths in `StrengthLog/StrengthLogApp.swift` and `Models.swift`; use the existing `ExerciseLog.exerciseID` resolution so the value is shared across routines. Keep the value separate from `sideTotalRepsReminderEnabled`, which controls whether the reminder exists.
2. Add the optional persisted display preference to `Exercise`, with an effective getter that returns the existing total-reps-first default when unset. Consider naming it to distinguish display mode from reminder enablement and legacy `repCountingMode`.
3. Update `ActiveWorkoutView.swift` so the callout reads and writes the master exercise preference instead of initializing card-local state to `true`. Preserve one shared display value for every participant on the card, odd-count formatting, and the current non-mutating relationship to reps and volume.
4. Extend the focused active-workout UI coverage in `StrengthLogUITests/WorkoutNavigationUITests.swift` and the persistence coverage around the existing rep-counting fixtures/smoke tests. Cover subsequent workout instances, another routine using the same master exercise, relaunch/store reopen where the harness supports it, and unchanged rep/volume behavior.
5. Update `docs/architecture.md` and `docs/data-model.md` to describe the persisted exercise-wide display preference and clarify that only the toggle's display choice persists; retain current behavior for existing nil values. Verify with the focused UI test and the repository's normal build/test workflow, including existing-store migration coverage. The main risk is keeping SwiftUI observation and writes consistent when several participant callouts share the same master model; exercise-specific storage also means duplicates with separate master records keep separate choices, which follows existing exercise identity semantics.

