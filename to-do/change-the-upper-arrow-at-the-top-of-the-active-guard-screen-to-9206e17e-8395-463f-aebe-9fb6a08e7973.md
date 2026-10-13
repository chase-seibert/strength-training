## User requirements

- As a user, I want the upper exercise-navigation arrow on the active workout screen replaced by a hamburger menu, so that I can see the workout's exercises and jump directly to any one.
- As a user, I want the menu to clearly mark which exercise is current, so that I can tell where I am in the workout.
- As a user, I want selecting a different exercise in the menu to make it the current exercise and scroll to it, so that I can jump directly and see my new place reflected in the screen.
- Assumption: the menu lists only exercises in the current workout, in their current order, and is available even when the first exercise is selected. The existing close-workout control and exercise detail action remain separate.

## Architecture and data model

No material architecture, persistence, schema, migration, or compatibility change is required. `ActiveWorkoutView` already derives the ordered exercise list from the session and tracks `currentExerciseID`; its `requestExercise(at:)` path updates the target and scrolls the corresponding card into view. Use this existing state and navigation path for menu selections. The list should reflect exercises added or reordered during the active workout without maintaining a second copy of order or selection state.

## Basic test cases

- Open an active workout at its first exercise; the hamburger control is visible, and opening it shows every exercise in current workout order with the current one visibly and accessibly marked.
- Select a different middle or final exercise; the menu closes, the selection becomes the marked current exercise, that card scrolls into view, and the navigation title tracks it.
- Reopen the menu after a jump; the newly selected exercise is marked current. Selecting the already-current exercise leaves the current target unchanged.
- Open the menu at the first and final exercises; every exercise remains selectable, including the current one, with no out-of-range navigation.
- Add or reorder exercises, reopen the menu, and confirm its contents and order match the active workout.
- Confirm direct jumps preserve logged sets, participant selections, and exercise timer state; the close-workout control and exercise-detail title action continue to work.

## High-level implementation details

1. In `StrengthLog/ActiveWorkoutView.swift`, replace the top trailing previous-exercise arrow with an accessible hamburger/menu control. Build its choices from `orderedExercises`, visibly mark the exercise matching `currentExerciseID` (for example, with a checkmark) and expose that selected state to accessibility, and route each choice through `requestExercise(at:)`. This makes the chosen item the current target while preserving existing title tracking and animated scrolling. Keep the control available at either end of the list.
2. Update `StrengthLogUITests/WorkoutNavigationUITests.swift` to cover opening the menu, its current-item indicator, selecting nonadjacent exercises and observing the indicator move, first/final boundaries, and the existing navigation fixture. Retain regression coverage for title tracking and the per-card next control.
3. Update `docs/design.md` to describe the menu-based direct navigation instead of the upper previous arrow while keeping the per-card next arrow behavior accurate. Verify with the focused workout-navigation UI test and the repository's required app verification/deployment workflow; inspect the menu on the iPhone after successful deployment.

The main interaction risk is crowding the navigation bar alongside Close and the dynamic exercise/rest title; confirm the menu control remains easy to reach and distinguishable with longer exercise names and Dynamic Type. No unresolved data-model decision is expected.
