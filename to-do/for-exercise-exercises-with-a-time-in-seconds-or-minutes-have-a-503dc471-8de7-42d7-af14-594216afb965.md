## User requirements

- As a user, I want to start a countdown for an exercise tracked in seconds or minutes, so that I can time a set without using the rest timer.
- As a user, I want the running exercise countdown to use blue timer text like the existing rest countdown uses coral text, so that I can distinguish exercise time from recovery time at a glance.
- As a user, I want an explicit button to start the exercise countdown, so that it does not begin automatically when I edit or complete a set.
- As a user, I want the running timer to be very large and easy to read from a few feet away, so that I can check it while exercising without picking up the phone.
- As a user, I want the display to stay awake while the exercise countdown is running, so that the timer remains visible for the whole set.

Assumptions: the countdown starts from the target of the active timed set, converting minute targets to seconds, and is manually started during an active workout. Keep it separate from the routine's automatic rest timer. The task does not specify the button placement, behavior at zero, sound/notification, or which participant's target to use when a shared exercise has different targets; settle these details during implementation. Put Start with the active timed set controls and show the running countdown in a prominent workout-screen region rather than relying on toolbar-sized text. Match the rest timer's blue/coral distinction while keeping the existing rest timer presentation intact.

## Architecture and data model

The app already stores a set's timed target in `WorkoutSet.durationSeconds` (with seconds and minutes displayed through `TrackingUnit`) and persists the active routine rest timer on `WorkoutSession`. The rest countdown is rendered by `ActiveWorkoutToolbarTitle` in `ActiveWorkoutView.swift`, and rest state drives existing expiry, notification, and Live Activity behavior.

An exercise countdown needs state that is independent of rest state, so starting or clearing one cannot replace a configured rest countdown or alter its notification/Live Activity. Prefer optional session-level start date and duration fields (and a set identity if needed to reliably resolve the target) so the countdown survives navigation and workout resume. This is an additive SwiftData change; determine whether the repository's current model-container setup handles the optional-field addition without an explicit migration, and verify existing session data remains readable. No catalog or routine schema change is needed.

Keep the screen awake only while this exercise countdown is actively running, using SwiftUI's idle-timer control scoped to the active workout view and driven by the timer state. Restore the normal idle behavior on stop, expiry, workout completion, and view dismissal so a completed or abandoned timer cannot keep the screen awake indefinitely. Do not add notification, Live Activity, or audio behavior unless implementation scope is explicitly expanded.

## Basic test cases

- On a seconds-based exercise, Start begins a blue, large countdown from the active set's target; its digits decrease over time and are legible in the workout layout.
- On a minutes-based exercise, Start uses the target converted to seconds and the countdown has the expected total duration.
- Editing a target does not start a timer. Starting a timed exercise timer does not complete the set or start/change the routine rest timer.
- A repetitions or load-based exercise has no exercise timer Start action.
- The display stays awake while the exercise countdown is running, then returns to normal idle behavior after the timer stops or expires, the workout ends, or the workout view is dismissed.
- At zero, the exercise countdown follows the chosen expiry behavior and can be started again for a later set.
- Navigating between exercises and resuming an open workout preserves or clears the countdown according to the chosen session-state behavior; a rest countdown continues to behave as it does today.
- With multiple participants whose next-set targets differ, the selected duration is clear and deterministic (or starting is prevented until an unambiguous target is selected).
- Existing exercise-unit UI coverage continues to validate seconds/minutes target editing and persistence.

## High-level implementation details

1. Confirm UX details: put Start with the active timed set controls, place the running countdown in a prominent part of the active workout screen, use a very large monospaced style that remains usable with Dynamic Type, define whether the timer can be stopped/restarted, define zero-state behavior, and choose the target for multiple participants. Keep the timer's completion effects distinct from rest-timer effects.
2. In `StrengthLog/Models.swift`, add the minimum optional `WorkoutSession` state needed for an independent timed-exercise countdown. Keep the existing `WorkoutSet` duration as the source of truth; derive seconds from the active set target and unit rather than storing a second editable target. Add or verify compatibility for existing persisted sessions.
3. In `StrengthLog/ActiveWorkoutView.swift`, identify the next eligible set for the current timed exercise, add an accessible explicit Start control in its card, and show the active countdown in a high-visibility workout-screen region in blue, with large monospaced digits. Keep the existing rest countdown and its coral header treatment unchanged. Handle start, stop/expiry, exercise changes, set completion, workout completion, and resume consistently; do not invoke rest notifications or Live Activity for this timer.
4. Bind the active exercise timer state to a scoped idle-timer-disabled setting in the active workout view. Ensure every stop, expiry, completion, dismissal, and error/cleanup path restores normal screen-lock behavior.
5. Add focused active-workout UI coverage for seconds, minutes conversion, manual start, ineligible units, large/readable timer presentation, screen-awake behavior and restoration, coexistence with rest behavior, and the chosen expiry/resume rules. Follow repository conventions with `make exercise-unit-ui-test` and the relevant active-workout UI-test target; run `make lint` and the appropriate build/test workflow during implementation.
6. Review accessibility labels, Dynamic Type scaling, visibility from the exercise card layout, and two-participant target selection on an iPhone simulator. Document any user-visible behavior that the final implementation adds, and update product/design docs only if the agreed behavior changes those specifications.
