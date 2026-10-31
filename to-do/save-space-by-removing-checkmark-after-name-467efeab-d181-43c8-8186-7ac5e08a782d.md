## User requirements

- As a user, I want the trailing checkmark removed from selected people in the active-workout picker, so that the compact row uses less space beside each name.
- As a user, I want selected people to remain visually distinguishable and the pills to keep their current toggle behavior, so that removing the checkmark does not make it unclear who is included.
- The attached screenshot shows the pinned participant picker with selected people and checkmarks after their truncated names. Assume the request is limited to this picker; keep the plus indicator for excluded people unless implementation review shows it conflicts with the intended compact layout.

## Architecture and data model

This is a presentation-only change to the participant picker in `StrengthLog/ActiveWorkoutView.swift`. No component boundary, workout data flow, persistence, SwiftData model, schema, migration, or compatibility change is required. Selection remains derived from `session.isParticipantActive`, and taps continue through `toggleParticipant`. Preserve the existing profile-colored selected pill fill and outline, unselected styling, accessibility label and hint, and selected/excluded state semantics.

## Basic test cases

- In the compact picker shown after advancing or scrolling, selected people have no trailing checkmark; their profile-colored pill treatment still identifies them as included.
- Excluded people retain the existing plus indicator and subdued pill treatment.
- Long names use the space no longer occupied by the selected-state icon where the current layout permits, while remaining readable and properly truncated in the fixed-width compact layout.
- Tap an included person and verify the existing removal behavior and accessibility state; tap an excluded person and verify they are included. Confirm the last active person remains protected by the existing guard and warning/data-retention behavior is unchanged.
- At the first exercise, verify the roomy picker remains correctly sized and selected states remain clear after the trailing checkmark is removed.

## High-level implementation details

1. In `StrengthLog/ActiveWorkoutView.swift`, inspect `participantPills`, `participantPillScrollView`, and `participantPickerLabel`. Remove the selected-only checkmark from the trailing label content while retaining the plus for excluded people, if consistent with the screenshot-driven scope.
2. Rebalance the label spacing or text frame only as needed so selected names can use the freed space. Preserve both picker modes: natural-width pills at the first exercise and fixed-width, aligned pills after advancing or scrolling.
3. Keep the selected profile-color fill and capsule outline as the visual selected-state cue. Preserve `participant-picker-*` identifiers, the included/excluded accessibility label and hint, and all toggle handlers.
4. Update or add focused active-workout UI coverage for selected and excluded picker pills, toggle behavior, and compact long-name rendering. Inspect the affected picker in both roomy and compact states; functional checks alone do not establish the visual space improvement.
5. Verify with the appropriate project checks, then deploy the successful app build with `make phone-deploy` and inspect the picker on Chase's iPhone 17 Pro. Do not treat a build or simulator check as physical-device visual acceptance.

Material risk: removing the checkmark may weaken the selected-state cue for users who do not distinguish the profile colors. Confirm the selected capsule fill and outline remain clear in light and dark appearance, and preserve explicit VoiceOver state text.
