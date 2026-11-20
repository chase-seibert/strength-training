# Show total all time workouts

## User requirements

- As a user, I want to see my total all-time workouts on Progress, so that I can understand my overall training history at a glance.
- As a user, I want the total to stay independent of the selected chart range, so that choosing a shorter range does not hide my lifetime count.
- Assumption: count completed, nondeleted `WorkoutSession` records across app history, with a group session counted once regardless of participant count. Confirm the desired scope if the total should instead be per person.

## Architecture and data model

No material architecture, persistence, or data-model change is required. `WorkoutSession` already stores active and soft-delete state, and Progress already observes workout sessions through SwiftData. Derive the total from that history rather than adding a stored counter, which could drift when workouts are imported, deleted, restored, or completed.

The count should include inactive sessions with no `deletedAt` value, including imported completed sessions. Exclude active sessions and soft-deleted sessions. Do not apply the selected date range to this count. Keep the existing range filtering for the training-volume chart and recent-workout list.

## Basic test cases

- With no completed workouts, show a clear zero total with correct singular/plural wording.
- With one completed session, show one workout; with multiple sessions, show the matching all-time total.
- A multi-person session increments the total once, not once per participant.
- An active session does not increment the total; completing it updates the displayed total.
- A soft-deleted session is excluded; restoring it includes it again.
- Imported completed sessions contribute to the total.
- Switching between available Progress ranges changes the chart/history as before but leaves the all-time total unchanged.
- The count remains visible when the chart has no volume data, and VoiceOver can identify it as the all-time workout total.

## High-level implementation details

1. Inspect `ProgressView` and the SwiftData `WorkoutSession` model while implementing. Derive the all-time count from the session query or a focused fetch, filtering to inactive, nondeleted sessions and avoiding the range-filtered `primarySessions` collection.
2. Add a compact, accessible total to the Progress summary near its heading or training-volume section. Use the product’s existing typography and card styling; keep wording explicit that this is an all-time count.
3. Add or extend Progress UI coverage in `StrengthLogUITests/WorkoutNavigationUITests.swift` with fixture data for completed, active, deleted, restored, imported, and multi-person sessions. Verify range changes do not affect the total and empty state copy is correct.
4. Check the rendered Progress screen at the supported text sizes and verify count updates after completion and deletion/restoration. Run the relevant UI test and the repository’s required iOS verification; for an implementation, follow `make phone-deploy` and inspect the affected UI on Chase’s iPhone 17 Pro when available.

Potential product decision: confirm whether “workouts” means saved completed session records or only sessions containing at least one completed set. This plan assumes saved completed sessions, including explicit completions with no completed sets, because session completion is the history unit.
