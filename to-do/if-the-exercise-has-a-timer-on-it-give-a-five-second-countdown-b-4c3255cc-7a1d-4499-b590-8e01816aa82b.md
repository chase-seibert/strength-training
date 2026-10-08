## User requirements

- As a user, I want a five-second countdown before a timed exercise starts, so that I can get into position before the set timer begins.
- As a user, I want the app to complete the timed set when its countdown reaches zero, so that I do not have to tap Complete afterward.
- As a user, I want an audible cue when the exercise timer finishes, so that I notice the end of the set.

Assumptions: Starting remains an explicit action for exercises tracked in seconds or minutes, using the next eligible set's target (minutes converted to seconds). Keep the pre-start countdown and exercise timer distinct from the routine rest timer. For shared workouts, preserve the existing rule that a timer starts only when visible participants have matching next-set targets, and have expiry complete that shared set for those participants. A user stop or manual completion during the five-second countdown cancels it. The finish sound is an in-app cue while the workout is active; background alerts are outside scope unless implementation clarifies that they are required.

## Architecture and data model

`WorkoutSet.durationSeconds` remains the target source and `WorkoutSession` already persists the active exercise timer's start, duration, and exercise ID. No material schema, catalog, or migration change is required. Represent the five-second pre-roll as transient active-workout view state; only after it finishes should the existing persisted exercise timer begin, so the displayed exercise duration does not consume the preparation time and existing resume behavior stays intact.

Use one guarded expiry path to complete the timed exercise's next eligible set through the same completion/save flow as the existing shared Complete action, then play a short cue. Keep routine rest timing, its notification, and Live Activity behavior independent. Reuse the app's existing alert sound mechanism unless implementation finds a platform or accessibility issue. Ensure expiry and sound run once, including when the app returns active after the deadline; do not add a notification permission prompt for this in-app behavior.

## Basic test cases

- Starting a seconds-based timer shows a visible 5-to-1 pre-roll; the exercise countdown begins at the full set target only after the pre-roll ends.
- A minutes-based target also waits five seconds, then starts at the correctly converted full duration.
- Stopping or closing the workout during pre-roll prevents the exercise timer, set completion, and finish sound; screen-awake behavior is restored.
- At zero, exactly one next timed set is marked complete and saved, the finish cue plays once, and the existing rest timer starts only according to the routine's normal completed-set behavior.
- If the set is manually completed during pre-roll or while its timer is running, automatic completion does not complete an additional set or play a duplicate finish cue.
- Repetitions/load exercises have no timer start action. Different visible-participant timed targets continue to prevent an ambiguous start.
- Navigating exercises or resuming an active workout during the exercise countdown does not lose or duplicate its expiry; existing rest countdown behavior is unchanged.
- Verify the finish cue with the app active and document/test the chosen behavior if the app is backgrounded at expiry.

## High-level implementation details

1. Extend the active-workout timer flow in `StrengthLog/ActiveWorkoutView.swift`: add an accessible five-second pre-roll in the fixed workout header, keep the exercise target timer dormant until the pre-roll ends, and make Stop, manual set completion, workout close/completion, and view cleanup cancel transient countdown work and restore idle-timer behavior.
2. Route exercise timer expiry to the existing set-completion flow for the timer's exercise, preserving participant set ordering, persistence checkpoints, and normal rest-timer start behavior. Guard against stale task completions and duplicate expiry callbacks when a timer is stopped, a set is manually completed, or the app resumes after expiry.
3. Play the completion sound once from the expiry path, using the current app alert-sound pattern where suitable. Keep it separate from rest notifications and Live Activity; decide during implementation whether background expiry needs a local notification, since that would change permission and product scope.
4. Update or extend `StrengthLogUITests/WorkoutNavigationUITests.swift` and the focused `exercise-timer-ui-test` Make target to cover pre-roll timing/cancellation, seconds and minutes, automatic completion and persistence, manual-completion races, exactly-once sound trigger, rest-timer coexistence, and cleanup/resume behavior. Use a short deterministic fixture duration or a test seam for expiry rather than waiting through a production-length set.
5. Update `docs/product-requirements.md` and `docs/architecture.md` if implementation confirms the user-visible behavior and timer lifecycle described here. Verify with the focused UI target, `make lint`, and the appropriate build; after successful app-code verification follow repository guidance with `make phone-deploy` and inspect the affected UI on the iPhone when available.
