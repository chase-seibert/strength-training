## User requirements

- As a user, I want to type a new pounds value and see each character respond promptly, so that direct editing is as usable as incrementing or decrementing the value.
- As a user, I want changing the base weight to preserve the app's existing per-set override behavior and save the final valid value, so that faster editing does not change workout data unexpectedly.
- The task asks whether the delay can be reproduced in the simulator. First establish a repeatable baseline with direct multi-character entry and compare it with the existing plus/minus controls. No numeric latency target or broader redesign is specified.

## Architecture and data model

No material schema, persistence-model, or migration change is expected. `MeasurementStepper` in `StrengthLog/ActiveWorkoutView.swift` owns the text draft and currently writes valid intermediate values to `ParticipantLog.measurement`, clears per-set `SetLog.measurement` overrides, and schedules a workout save as text changes. `SelectAllTextField` in `StrengthLog/Components.swift` bridges the UIKit text field into SwiftUI. The implementation should keep keystroke rendering responsive and defer expensive model or view work until the user commits a valid value, if profiling confirms that work contributes to the delay. Preserve the established override-clearing semantics when a changed base value is committed, and avoid changing stored identity or units.

## Basic test cases

- On an iPhone simulator with the active-workout fixture, tap the pounds field, replace its value with a multi-digit number, and record whether visible updates lag after individual keystrokes. Repeat the same entry enough times to distinguish a consistent delay from simulator or automation noise.
- In the same fixture, compare direct typing with the plus and minus buttons under the same screen and workload. Capture app-side text-change and subsequent UI-update timing where practical; do not treat XCTest `typeText` wall time alone as app latency.
- Confirm typed valid integer and fractional values appear correctly and the final committed value survives closing and resuming the workout.
- Confirm empty or temporarily invalid text can be edited without persisting an invalid number, and that leaving the field restores or retains a valid value according to the chosen commit behavior.
- With a per-set weight override present, confirm merely typing intermediate characters does not prematurely clear it; after committing a changed base weight, verify the established override behavior is applied exactly once.
- Verify plus/minus adjustment, kilograms, and unrelated rep/time fields retain their current behavior.

## High-level implementation details

1. Reproduce the reported delay before changing code. Use the existing `-basicWorkoutFixture` and `-activeWorkoutFixture` setup and the current pounds text field; compare multi-digit direct entry against stepping. Record simulator/runtime, fixture, input sequence, and visible/app-side timing. The existing `testWeightControlsJumpToStandardSizes` in `StrengthLogUITests/WorkoutNavigationUITests.swift` covers value correctness but not latency, so add focused regression/profiling coverage during implementation if the baseline is repeatable.
2. Trace the delay across `SelectAllTextField.Coordinator.textDidChange`, `MeasurementStepper` state updates, SwiftUI recomputation, `scheduleWorkoutSave`, and any synchronous model work. Keep instrumentation narrowly scoped and separate XCTest automation overhead from app response time.
3. Based on the measured cause, keep keystrokes in the local draft and commit model mutation, override clearing, and save scheduling once at a defined commit boundary (such as editing completion), or make a smaller targeted optimization if profiling points elsewhere. Preserve valid partial text entry, selection behavior, weight stepping, unit changes, and existing persistence semantics.
4. Extend simulator UI coverage for typing latency evidence and the data/edge cases above. Run the focused UI workflow and relevant repository checks during implementation; because the change affects app behavior, follow the repository's successful-build deployment and visual-inspection workflow. Report simulator timing as simulator evidence, not physical-device acceptance.
5. Recheck the original pounds-entry reproduction after the change. If simulator typing remains slow, use the timing evidence to isolate remaining UIKit/SwiftUI or workload costs before claiming the issue fixed.
