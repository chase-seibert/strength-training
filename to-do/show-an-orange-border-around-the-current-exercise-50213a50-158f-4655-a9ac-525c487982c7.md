## User requirements

- As a lifter, I want the current exercise card in an active workout to have an orange border, so that I can quickly distinguish the exercise I am working on while scrolling through the workout.
- The border should follow the app's existing current-exercise selection as it changes through scrolling, exercise-menu selection, next/previous controls, and workout resume. Assumption: use the existing `Theme.coral` accent as the app's orange, unless design review calls for a different existing color.

## Architecture and data model

This is a presentation-only change in the active workout. `ActiveWorkoutView` already tracks the current exercise by the `ExerciseLog` UUID, and its exercise cards are rounded SwiftUI views. Pass or derive the current-selection state at the card boundary and draw an accent stroke on the matching card. Keep selection behavior, workout persistence, and the SwiftData schema unchanged. Match the existing first-exercise fallback when the selection is unset or no longer resolves, so the visible current card and its border stay consistent.

## Basic test cases

- Open or resume an active workout: exactly the card represented by the current exercise title is outlined; other exercise cards have no orange outline.
- Advance or go back with the exercise controls, then select another exercise from the menu: the outline moves to the newly selected card and the former card returns to its normal appearance.
- Scroll until another exercise becomes current: after scroll selection settles, the outline follows that exercise.
- Use a workout containing a custom exercise and two exercises with the same displayed name: selection follows the exercise ID, not a name match.
- Use a workout with no exercises or with a removed/stale current selection: the screen remains usable and follows the existing fallback behavior without outlining multiple cards.

## High-level implementation details

1. In `StrengthLog/ActiveWorkoutView.swift`, connect `currentExerciseID` (including the existing fallback to the first ordered exercise) to each `ActiveExerciseCard` and render a rounded accent outline only for the current card. Keep the stroke within the card's layout so it does not change card spacing or intercept controls.
2. Extend the focused active-workout navigation UI test in `StrengthLogUITests/WorkoutNavigationUITests.swift` to exercise the outline's selection transitions. Since XCUI does not inspect stroke color directly, retain screenshots at the initial and changed selections for visual confirmation, while keeping existing accessibility assertions for the current exercise.
3. Verify with the focused workout-navigation UI test and inspect its screenshots for the outline color, corner alignment, and single-card behavior. For implementation, follow the repository workflow: run the appropriate verification, then `make phone-deploy` and visually inspect the affected workout screen on Chase's iPhone 17 Pro when available. Do not treat a simulator screenshot as physical-device acceptance.

Risk: scroll-based current-exercise updates are available on iOS 18+, while explicit navigation and resume also set selection. Ensure the outline reads clearly in both light and dark appearance without obscuring the rounded card or its controls.
