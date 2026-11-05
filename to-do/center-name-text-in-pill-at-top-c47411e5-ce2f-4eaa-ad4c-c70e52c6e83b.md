## User requirements

- As a user, I want the participant name centered within its pill at the top of an active workout, so that the name looks balanced and easy to scan.
- Preserve the existing participant-selection behavior and visual cues, including the initials badge, profile color, included/excluded state, and horizontal scrolling.
- Assumption: the request applies to the pinned participant pills shown in the attached active-workout screenshot. Keep the badge leading and center the name in the remaining pill space; retain existing truncation for long names.

## Architecture and data model

This is a local SwiftUI layout change in the active-workout header, centered on `participantPills`, `participantPillScrollView`, and `participantPickerLabel` in `StrengthLog/ActiveWorkoutView.swift`. No material architecture, data-flow, persistence, schema, migration, or compatibility change is required. Existing selection actions and accessibility labels should remain intact.

## Basic test cases

- On the first exercise, confirm each visible participant name is centered within its pill while the initials badge remains at the leading edge.
- On a later exercise, confirm names remain centered in pills aligned with the participant's exercise column.
- With long names and multiple participants, confirm truncation still fits, the pills continue to scroll horizontally, and off-screen pills remain reachable.
- Toggle a participant off and on; confirm the name remains centered and the existing excluded styling and accessibility label update correctly.
- Check at a larger accessibility text size that the name remains legible and the pill stays usable without overlapping its badge.

## High-level implementation details

1. Review the existing layout rules in `ActiveWorkoutView.swift`, especially the first-exercise and column-aligned picker variants, and preserve their pill sizing and placement.
2. Adjust the name label's layout so it is centered within the pill's available text area without shifting the leading initials badge or excluded-state plus icon. Keep `DashTruncatedName` behavior for the aligned variant and verify the regular variant with long names.
3. Extend the relevant active-workout UI coverage in `StrengthLogUITests/WorkoutNavigationUITests.swift` to verify pill geometry and behavior in both alignment modes, including a long-name case. Use the repository Makefile's appropriate UI-test target or a focused target added during implementation if needed.
4. Run the repository's app verification, including an iPhone-target build, then deploy a successful build with `make phone-deploy` and visually inspect the header on the phone as required for user-visible app changes. Keep any adjustments limited to the pill layout and its focused coverage.

Risk: centering the text can conflict with the leading badge or excluded-state plus icon in narrow pills. Check short and long names, included and excluded states, and both picker alignment modes before finalizing. No unresolved product decision is apparent beyond confirming the screenshot interpretation during implementation.
