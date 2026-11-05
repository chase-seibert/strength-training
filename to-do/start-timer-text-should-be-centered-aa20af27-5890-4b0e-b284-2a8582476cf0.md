## User requirements

- As a user, I want the Start timer control's icon and text to be centered in the button, so that the action looks balanced within the full-width exercise card.
- Keep the existing start-timer action, wording, color, hit area, and accessibility identifier. Assume “centered” means centering the label group as a whole; the task does not request separate centering of the text independent of its timer icon.

## Architecture and data model

No material architecture, data-flow, persistence, schema, migration, or compatibility changes are required. This is a SwiftUI presentation adjustment to the existing timer button in the active exercise row.

## Basic test cases

- In an active seconds-based exercise with a configured target, the full-width Start timer button remains visible and its timer icon and label appear centered together.
- Repeat with a minutes-based target and a longer duration label; the label group remains centered as its text width changes.
- Tap the centered button: the existing preparation countdown still starts, and its cancel/stop behavior is unchanged.
- Confirm timer-running, timer-starting, and target-conflict states retain their current layout and behavior; the centering change applies only to the Start timer button.

## High-level implementation details

1. In `StrengthLog/ActiveWorkoutView.swift`, find the Start timer `Button` inside the timed exercise row. Adjust the label's frame alignment so the `Label` contents are centered within the existing full-width label area; retain the button style, tint, identifier, hint, and action.
2. Extend or add a focused assertion in `StrengthLogUITests/WorkoutNavigationUITests.swift` if UI automation can reliably verify the label's placement; otherwise use a screenshot or on-device visual inspection for the alignment, while keeping the existing seconds/minutes timer behavior coverage.
3. Verify with the repository's supported workflow: run `make sim-build` and the relevant `make exercise-timer-ui-test` target, then deploy a successful build with `make phone-deploy` and visually inspect the timed exercise card on Chase's iPhone 17 Pro. If the phone is unavailable or locked, report that limitation and the completed verification.
4. Check Dynamic Type and longer duration strings to ensure the centered label stays readable and does not reduce the full-width tap target. No unresolved product decision is expected beyond confirming that the icon and text are centered as a single group.
