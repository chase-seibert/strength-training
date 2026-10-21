# Button press feedback for workout actions

## User requirements

- As a user, I want Start Workout to show immediate pressed feedback, so that I know my tap registered while a workout is being created and opened.
- As a user, I want Complete Workout to show immediate pressed feedback, so that I know my tap registered while the workout is saved and the completion summary opens.
- As a user, I may want Next Exercise to show the same feedback, so that exercise navigation also acknowledges a tap when the screen takes a moment to move.
- Assumption: use the existing action and navigation behavior, adding only transient visual acknowledgement and protection against duplicate activation during an in-flight transition. Keep accessibility labels and identifiers intact. Include Next Exercise because the task names it as a likely related control, but keep its feedback short and tied to the actual navigation.

## Architecture and data model

No material architecture, persistence, or data-model change is required. This is transient SwiftUI interaction state. Keep any in-flight state local to the view that owns each action; do not persist it or change `WorkoutSessionStarter`, completion semantics, or workout history. Prefer the system button pressed treatment where it provides sufficiently visible feedback; if a custom treatment is needed for the plain circular Next Exercise control, keep it reusable and limited to pressed presentation.

## Basic test cases

- Tap a routine on Workout home and Start Routine in routine detail: the control visibly acknowledges the press immediately, starts/opens the workout once, then returns to its normal state or disappears with the transition.
- Tap Complete Workout: the full-width action visibly acknowledges the press before the completion flow finishes; the session is completed once and the existing summary appears.
- Tap Next Exercise when another exercise exists: the arrow visibly acknowledges the press and advances once without changing set-completion state. Previous Exercise navigation, if present, should remain consistent if the same treatment is applied there.
- Tap a disabled Next Exercise at the end of the workout: it remains disabled and does not show an actionable pressed state or advance.
- Exercise a delayed or unavailable action path: the pressed state clears on failure or cancellation, and repeated taps cannot create duplicate sessions or complete the same session twice.
- Verify pressed feedback remains legible in light and dark appearances and does not replace VoiceOver labels, hints, or button activation semantics.

## High-level implementation details

1. Review the action entry points in `HomeView.swift` and `RoutinesView.swift` for workout start, `ActiveWorkoutView.swift` for Complete Workout and Next Exercise, and any existing shared button styles in `Components.swift`.
2. Choose the smallest consistent treatment: use native SwiftUI pressed feedback for standard prominent buttons where it is visible enough; add a reusable pressed style or narrowly scoped transient state for the custom plain Next Exercise arrow if native feedback is not perceptible.
3. For start and completion actions, set in-flight state synchronously before invoking the potentially slow work, disable duplicate activation while that work is pending, and clear state on failure/cancellation. Preserve existing navigation, save, timer-cancellation, and completion ordering.
4. For Next Exercise, apply only an ephemeral press acknowledgement around the existing `onAdvance` action; do not delay navigation or modify exercise/set data. Confirm whether Previous Exercise should share the style for consistency.
5. Add or update focused UI coverage for immediate visible acknowledgement, single activation, disabled navigation, and state reset. Run the relevant UI tests and project lint/build verification. After successful app verification, follow repository guidance to deploy with `make phone-deploy` and visually inspect the affected controls on the phone; report any unavailable-device boundary separately.

Risks and unresolved decisions: a system pressed animation may be too subtle on the custom arrow, while an explicit loading indicator could change the control layout. Keep feedback visible without shifting content, and determine whether start/completion can fail synchronously or be cancelled so in-flight state always resets.
