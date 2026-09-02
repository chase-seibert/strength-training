# Changelog

## 2026-09-02

- Replaced full-card workout reordering with a dedicated compact exercise list, drag handles, and Save/Cancel; saved order changes preserve all logged sets and leave the routine unchanged.
- Simplified the Workout-page resume summary to show only completed sets, without a misleading total that includes empty extra sets.
- Corrected Balance Board, Battling Ropes, Mountain Climbers, and the three chest/neck isometric entries to seconds; corrected Superman, Toe Touchers, and Ankle Circles to reps, with a one-off existing-store update.
- Added catalog-backed duration targets independent of the rep preference: 30 seconds generally, reviewed shorter holds from the instructions, 20 seconds for Stomach Vacuum and One Handed Hang, and the existing 60-second Plank default. Saved workout values and later unit edits remain intact.
- Made master exercise units universal across routines, active workouts, history, and progress, with exercise-name navigation for mid-workout edits.
- Corrected Plank to seconds with a 60-second default, preserving saved values and applying the old catalog correction only once.
- Added duration-aware workout controls, last-set overrides, history summaries, and focused UI/on-disk persistence regression coverage.

## 2026-08-26

- Created the initial SwiftUI and SwiftData StrengthLog application.
- Added multi-person routines, quick-entry workout logs, editable sets/reps/load, immediate reopening, and remembered defaults.
- Added the 30-day activity grid, session history, and pounds-volume charts.
- Bundled a normalized 873-exercise Free Exercise DB catalog with inferred editable tracking units and on-demand exercise imagery.
- Added a generated app icon, project documentation, and simulator/device Makefile workflows.
- Replaced hard-coded people and sample routines with an opt-in onboarding flow and moved the “Build strength, together” hero there.
- Added one-tap reopening for the three most recent workouts on Workout and removed the former Today hero tile.
- Simplified routine prescriptions to two controls per person, with one shared rep count across all planned sets.
- Added swipeable two-position exercise imagery in the exercise library and full-size optional imagery during active workouts.
- Removed workout timing and explicit exercise/workout finishing; logs now save continuously and close without confirmation.
- Added a Debug-build-only Developer menu that replays onboarding with existing people and routines prefilled while preserving all local data.
- Added first-name AutoFill guidance for the primary onboarding profile and editable numbered defaults for additional people.
- Added optional Upper Body, Lower Body, and Core starter templates during onboarding and from the Routines add menu.
- Added an exercise-detail action for choosing a routine, preventing duplicates, and creating a routine when needed.
- Reworked navigation into Workout, tabbed Library, Progress, and Settings; open workouts now replace the whole tab interface.
- Added catalog exercise insertion and edit-mode exercise reordering to open workouts, plus routine exercise reordering.
- Persisted onboarding people order throughout the app so the primary profile always appears first.
- Moved Change People, Reorder, and Add Exercise into the bottom of the scrollable workout content to simplify the top bar.
- Added Hevy CSV import from Settings and shared CSV documents, with per-exercise mapping overrides, remembered mappings, routine creation, per-set history, and duplicate-workout protection.
- Made Hevy routine selection the first import decision, scoped the complete exercise list and history to those selections, added frequency/recency/alphabetical mapping sorts, allowed unmapped exercises to be skipped, and always creates uniquely named routines without updating existing ones.
- Fixed Hevy exports containing mixed CRLF and LF line endings being truncated to only the LF-delimited rows.
- Made exercise search name-only throughout the app and added All/30/60/90-day display filters to the Hevy exercise-mapping list.
- Restored separate Routines and Exercises app tabs, reordered Workout around routine choice, added transactional routine exercise deletion/reordering with explicit Save and Cancel, and added routine name/icon editing plus an edit-mode delete action.
- Added a dedicated routine appearance picker with 18 activity icons and 10 app-coordinated colors for new and existing routines.
- Changed routine deletion to a recoverable soft delete, with a Deleted Routines list and restore actions that preserve workout history.
- Moved Deleted Routines from the toolbar menu to a conditional link at the bottom of the Routines list, and fixed existing-routine appearance editing while list reordering mode is active.
- Added exercise selection to routine edit mode, with additions participating in the existing Save and Cancel draft.
- Added confirmed workout deletion from progress history and session details.
- Added swipe-to-delete for Workout-tab recent workouts and a confirmed delete button at the bottom of open workouts.
- Made routines person-agnostic: workouts own their participant set, and each person's latest workout values seed the next session.
- Made catalog exercise units the source of truth, restored master-exercise unit editing, and removed routine-level unit customization.
- Added guided create/edit exercise forms, exercise renaming and duplication, original-name search and display, and stable canonical identity links across routines and workout history.
- Replaced the long exercise-filter chip row with a compact filter menu ordered All, Custom, then muscles alphabetically.
- Replaced the original barbell/progress app icon with the selected Teal LC dumbbell monogram.
- Clarified exercise creation with workout-language labels, an optional More Details disclosure, and explanations of how muscle, equipment, and type are used.
- Made exercise duplication discoverable from a labeled More menu and simplified routine exercise summaries to describe what each set logs.
- Tightened Workout quick start and live-workout secondary actions, strengthened participant-colored selection and set affordances, and made next-exercise navigation more visible.
- Added person, routine, and 4W/12W/All filters to Progress and renamed chart sections to Training Volume.
- Kept three routines in Workout Quick Start, replaced Progress person/routine controls with a compact duration menu, and changed Training Volume to a person-separated line chart with data-point dots.
- Updated the Teal LC app icon so the orange bar runs through the C with matching clearance on both sides of its vertical stroke.
- Enlarged the Teal LC app icon vertically, tightening the mark and extending the end plates and letterforms to better fill the square.
- Balanced the Teal LC icon so the letters and mirrored plates share matching heights and align around the center bar.
- Restored the earlier diagonal rotation to the balanced Teal LC icon.
- Added a two-hour Workout-tab resume section for completed workouts, allowing them to be reopened and continued after completion.
- Added a configurable default set count for new workout exercises alongside default reps.
- Added routine-level optional rest timers, set-completion timestamps, workout-length reporting, and a live active-workout timer header.
- Simplified the live workout status into a pinned elapsed/rest header, made elapsed time tick live, and added an audio alert when rest expires.
- Moved elapsed time into the navigation title, pinned only active rest timers, and added an ActivityKit Lock Screen/Dynamic Island rest countdown.
- Tightened the Live Activity layout, added coral countdown styling and Lift Chase branding on the Lock Screen, moved Skip beside the sticky rest title, and corrected the initial countdown rounding.
- Added current exercise, set progress, reps, and load to the Lock Screen Live Activity, plus an opt-in rest-complete notification scheduled when a rest timer is first used.
- Reduced the Dynamic Island content to center-only expanded and timer-only compact presentations, and added a Workouts setting to enable or disable rest-complete notifications.
