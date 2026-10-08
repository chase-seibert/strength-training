## User requirements

- As a user, I want the checkmark and “1 set” label on the complete-set button to remain clearly visible in both light and dark appearance, so that I can tell the group set action is available.
- As a user, I want the checkmark, plus, and next-exercise down arrow to use consistent, legible foreground colors, so that the related controls read as one visual system.
- Keep the existing set completion, add-set, and exercise-advance behavior and accessibility labels. The screenshot is the reference for the mismatched symbols and colors. The intended foreground is assumed to be white against the existing coral action fills, following the plus control; confirm the down-arrow treatment against the design when implementing.

## Architecture and data model

This is a presentation-only change in the active workout controls. No component boundaries, workout data flow, persistence, schema, migration, or compatibility behavior needs to change. Set completion remains handled by `completeOneSetForEveryone`; the add and advance actions retain their existing handlers and disabled states.

## Basic test cases

- In light appearance, inspect the complete-set capsule, plus control, and next-exercise control: the “1 set” text and checkmark are both visible, and the three action glyphs have the intended consistent foreground contrast against their coral fills.
- Repeat the same visual check in dark appearance, including the layered down-arrow symbol, and confirm no system-adaptive style makes a foreground disappear or change unexpectedly.
- Tap Complete one set for everyone and verify all visible participants’ next eligible sets complete once; retain the existing accessibility label and identifier.
- Tap Add set and Next exercise, and verify the set count and exercise position still update as before. Confirm the next-exercise control remains disabled at the final exercise and Remove set remains disabled when only one set exists.

## High-level implementation details

1. In `StrengthLog/ActiveWorkoutView.swift`, inspect `sharedSetButtons` and `nextExerciseButton`. The group completion control uses a tinted prominent `Label` without an explicit label foreground; the plus uses white over coral; the down arrow uses the layered `arrow.down.circle.fill` symbol tinted coral. Make foreground styling explicit for both the complete-set label and its checkmark, and give the down-arrow layers an explicit treatment consistent with the coral action controls. If the prominent button style continues to override the label color, use an explicit coral capsule background and white label while preserving the existing button target, sizing, accessibility, and handler.
2. Keep enabled/disabled appearance and all action semantics intact. Prefer a simple circle background with a separately colored down-arrow glyph if the layered SF Symbol continues to render inconsistently across appearance modes.
3. Extend the active-workout UI coverage around the existing `complete-one-set` and `add-shared-set` controls to check their actions and identifiers; use light- and dark-appearance screenshots or on-device inspection to verify symbol contrast, since functional assertions alone cannot catch this rendering issue.
4. Verify the app with the repository’s supported workflow (`make test` and the focused workout-navigation UI test), then deploy the successful build with `make phone-deploy` and inspect the affected controls on Chase’s iPhone 17 Pro in both appearances. Report any device availability or appearance-inspection limitation separately from build/test results.

Material risk: SwiftUI’s prominent button and multicolor SF Symbol rendering can apply adaptive or layered foreground styles. Validate the rendered checkmark and arrow rather than assuming a tint alone produces the same visible color as the plus control.
