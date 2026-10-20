# Mark some exercises as temporarily hidden on a routine

## User requirements

- As a user, I want to temporarily hide selected exercises from a routine, so that I can start a shorter workout without deleting those exercises.
- As a user, I want to unhide those exercises later, so that they can be included in future workouts again.
- Assumption: hidden status belongs to an exercise entry in one routine. It does not hide the catalog exercise or alter active and completed workouts.

## Architecture and data model

Add a per-entry hidden flag to `RoutineExercise`, the persisted relationship object that already carries routine-specific order and notes. Treat existing entries as visible by default and keep hidden entries in the routine so their identity, order, and workout history matching remain intact. Prefer an additive, lightweight-migration-safe field consistent with the model's existing optional fields; verify existing stores open without losing routine data.

Keep hide/unhide out of the routine's normal exercise display and out of the active workout's current-exercise view and hamburger menu. Put a clear “Manage Exercises” link in the routine's lower management area near Delete Routine. That screen should combine reordering with hide/unhide controls; hidden entries remain listed there so users can restore them. `WorkoutSessionStarter.start` is shared by routine-start surfaces, so filter hidden entries there when snapshotting a new session. Existing sessions remain snapshots and do not change when a routine entry is hidden later.

## Basic test cases

- Hide one of several routine exercises, save, and start from each available routine-start surface: the new workout contains visible exercises in their configured order and omits the hidden one.
- Open Manage Exercises, unhide the exercise, save, and start again: the exercise is included with its original identity and order; other entries are unchanged.
- Confirm the routine's normal exercise view and active-workout current-exercise view and hamburger menu do not expose hide controls; Manage Exercises is reachable near Delete Routine and contains both reorder and hide/unhide actions.
- Cancel after changing hidden status: the persisted routine and next workout remain unchanged.
- Hide every exercise: hidden entries remain accessible for unhide, and starting an empty routine is disabled or otherwise clearly unavailable.
- Hide an entry after a workout has started and verify that open and completed workout snapshots and history are unchanged.
- Open an existing store created before the new field: its routine exercises remain visible, editable, ordered, and usable for new workouts.

## High-level implementation details

1. Add and initialize the persisted hidden state on `RoutineExercise`, preserving compatibility with existing SwiftData stores and old routine entries.
2. Add a “Manage Exercises” link in the lower routine-management area near Delete Routine, opening a focused screen that combines ordering with hide/unhide. Make hide changes part of a Save/Cancel draft workflow; keep hidden entries visible in that screen with an obvious Unhide action. Do not add hide actions to the routine's normal exercise display, active workout, or hamburger menu. Update routine exercise counts and start availability to reflect only active entries where appropriate.
3. Filter to visible routine entries in `WorkoutSessionStarter.start`, keeping all launch paths consistent while preserving original `RoutineExercise` records and historical session snapshots.
4. Add focused UI/persistence coverage for hide, save/cancel, unhide, empty routines, and existing-store migration. Run `make format`, `make lint`, and the appropriate focused UI test plus `make sim-build`; after successful verification, use the repository workflow `make phone-deploy` and inspect the affected routine UI on the phone. Report simulator, signing, or device limits separately from successful checks.

The main risks are accidentally deleting entries instead of retaining them, making hidden entries impossible to restore, or filtering only one workout-start path. Keep the management entry point distinct from ordinary exercise browsing so hide controls do not clutter workout use.
