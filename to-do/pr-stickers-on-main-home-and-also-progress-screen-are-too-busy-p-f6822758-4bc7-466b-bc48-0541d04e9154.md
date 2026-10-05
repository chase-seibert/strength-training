## User requirements

- As a user, I want the PR count on Workout home to be larger and easier to read, so that it does not disappear among the workout-day symbols or overlap them.
- As a user, I want the Progress chart to show the training-volume trends without a row of overlapping PR icons on its horizontal axis, so that the chart is readable at a glance.
- As a user, I want each Workout History PR trophy and count to read as one badge, so that the record indicator feels like a single compact item beside the set count.
- Apply a consistent combined trophy-and-count treatment to PR days on the Workout home calendar, using enough size and reserved space to avoid covering routine, workout-count, or multiple-person markers. Preserve accessible PR counts and the ability to open workout details.
- Use a representative fixture derived from the phone’s actual workout history to check the layouts. Assumption: anonymize profile-identifying values before adding fixture data to the repository while retaining the workout/date/PR density needed to reproduce the screenshots.

## Architecture and data model

`PersonalRecords.achievements(in:)` in `StrengthLog/Models.swift` derives PRs from completed, non-skipped sets; keep this calculation and its historical meaning unchanged. Workout home’s `ActivityGrid` in `StrengthLog/HomeView.swift` and Progress in `StrengthLog/ProgressView.swift` render the indicators. No production data-model, persistence, schema, or migration change is needed.

Add a deterministic, sanitized history fixture to the existing DEBUG fixture setup in `StrengthLog/BasicWorkoutFixture.swift` / `StrengthLog/StrengthLogApp.swift`, with focused UI coverage for both screens. Select a safe phone-store export or backup route during implementation; do not modify the live store or copy only a live SQLite main file if its WAL may contain current data. Keep raw personal data out of source control and record how the fixture was anonymized. No production export feature is implied by this task.

## Basic test cases

- With the phone-derived fixture, Workout home shows the PR trophy and count together in a readable badge on PR days. It does not overlap routine symbols, the multiple-workout count, or the multiple-person cue; non-PR days have no PR badge.
- Progress’s volume chart has no per-week trophy/count annotations cluttering or colliding along the horizontal axis. Volume series, axis labels, and legend remain readable.
- Each Workout History row with PRs presents the trophy and `+count` as one conjoined badge, visually distinct from the completed/total set count. Rows without PRs have no badge.
- Opening a marked calendar day or history row still reaches the correct workout detail, where individual PR information remains available. VoiceOver announces the personal-record count.
- Fixture expectations match `PersonalRecords.achievements(in:)`, including multiple record achievements, sparse and dense weeks, non-record workouts, and skipped/incomplete sets. Changing the Progress date range does not leave stale chart markers or history badges.
- Empty history and a date range with no matching workouts show no stale PR indicators.

## High-level implementation details

1. Inspect the connected iPhone and determine a safe, read-only route to obtain representative workout history, using a consistent store backup/export if available. Preserve a source snapshot, anonymize profile-identifying values, and create a bounded fixture that reproduces the visible density and overlapping markers in the attached screenshots. If direct extraction is unavailable, use an existing app export/import route if it preserves the required history and document fidelity limits.
2. Calculate expected achievements from the fixture with the existing PR logic. Include representative PR totals and dates that exercise multiple calendar cues, adjacent history rows, crowded chart weeks, and quiet periods.
3. Replace the tiny separate calendar count sticker with a larger combined trophy/count badge. Reserve or adapt its placement so routine symbols and other day markers remain distinct, including days with several simultaneous cues.
4. Remove PR trophy/count annotations from the chart’s weekly points so the chart focuses on training volume and its X-axis remains clear. Keep PR totals discoverable in Workout History and detailed workout views.
5. Combine each Progress history trophy and count in a single capsule-style badge, with spacing that separates the badge from set completion text. Keep count and VoiceOver semantics intact.
6. Add fixture-driven UI assertions and inspect screenshots of Workout home and Progress at phone-sized simulator dimensions. Run focused UI tests plus `make lint` and `make test`; during implementation deploy the verified build using `make phone-deploy` and inspect the changed phone UI per repository guidance. Report any phone extraction, simulator, signing, or device-availability limit explicitly.
