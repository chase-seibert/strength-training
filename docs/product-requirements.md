# Product requirements

## Routines and catalog

- As a lifter, I want to create and rename routines, choose an icon and color for each one, and recover deleted routines, so that my recurring sessions match how I train without risking accidental loss.
- As a lifter, I want routines to be person-agnostic, so that each workout can choose its own crew.
- As a lifter, I want a new workout to remember each person's latest weights, reps, and sets for a routine, so that setup is fast without storing workout data on the routine.
- As a new lifter, I want optional Upper Body, Lower Body, and Core starters, so that I can begin quickly without being forced into sample data.
- As a lifter, I want a broad searchable exercise catalog with equipment, muscle, form notes, and imagery, so that I can build routines quickly and recognize unfamiliar movements.
- As a lifter, I want a compact exercise filter menu ordered All, Custom, then muscles alphabetically, so that custom and muscle filtering stays easy without consuming library space.
- As a lifter, I want to add an exercise to a routine directly from its catalog detail, so that browsing naturally turns into routine building.
- As a lifter, I want to add, remove, and reorder exercises while editing routines, so that their contents and workout order match my plan.
- As a lifter, I want custom exercises and editable catalog-unit defaults, so that routines use one consistent measurement per exercise while I can correct an inaccurate default.
- As a lifter, I want to rename and duplicate any exercise while retaining its original name and canonical identity, so that personalized labels never disconnect routines or workout history from the source movement.
- As a lifter, I want the exercise editor to explain tracking, muscle, equipment, type, and form-note choices in workout language, so that creating an exercise does not require understanding catalog internals.
- As a lifter, I want measurement units for pounds, kilograms, reps, time, distance, and steps, so that strength and conditioning movements share one model.

## Workout execution

- As a lifter, I want only one workout log open at a time, so that logging stays focused without introducing timer state.
- As a lifter, I want to select today's participants, so that solo, pair, and family sessions stay uncluttered.
- As a lifter, I want a separate measurement and sets for every participant, so that everyone can progress independently in one routine.
- As a lifter, I want exercise form thumbnails and optional full-size position images during a workout, so that I can check technique without leaving the session.
- As a lifter, I want one compact Load/Sets/Reps matrix per exercise, with one base rep count, an optional remembered last-set override, and numbered per-set completion squares, so that repeated sets stay compact without hiding progress.
- As a family, we want up to three people visible together in one exercise matrix, with one shared set count and per-person completion controls, so that group workouts do not require horizontal scrolling.
- As a lifter, I want to edit measurement/reps and add or remove sets while training, so that the log matches what actually happened.
- As a lifter, I want editable numeric inputs plus large decrement and increment controls for measurements and reps, so that both exact and small changes are fast.
- As a lifter, I want single-sided and alternating exercises to explain whether reps are per-side or split between sides, without doubling the controls.
- As a lifter, I want one exercise-level history chart comparing every active person's weight and reps in their profile color, so that progression decisions stay in context without repeated icons.
- As a lifter, I want large Remove Set and Add Set controls at the bottom of each exercise card, so that the shared set count stays easy to adjust without leaving a sparse band between participant controls.
- As a lifter, I want to skip the last one or two sets for an individual person from their set-options menu, so that fatigue or time constraints do not require changing everyone else's plan.
- As a family, we want every participant to share the same set count for an exercise, so that the group matrix stays compact and comparable.
- As a lifter, I want changing base reps to update every ordinary set while preserving a customized last set, so that progressive overload remains fast without losing intentional final-set variation.
- As a lifter, I want always-visible previous/next exercise controls and strong completed styling, so that navigation and progress remain clear even when scrolling through many controls.
- As a lifter, I want sets completed and removed in order, so that a workout never contains gaps such as a completed third set without a completed second set.
- As a lifter, I want to add and reorder exercises while a workout is open, so that I can adapt the session without leaving it.
- As a lifter, I want an open workout to replace the app navigation, so that tabs do not compete with the task at hand.
- As a lifter, I want every workout edit saved as I make it and the freedom to close at any point, so that logging never depends on a finish ceremony.
- As a lifter, I want to reopen any workout log directly, so that interruptions and later corrections are effortless.
- As a lifter, I want reopening to jump to the exercise after the last meaningfully progressed exercise and move an offscreen exercise name into the navigation title, so that I immediately recover my place.

## Persistence and progress

- As a lifter, I want each session to preserve participant, exercise, measurement, reps, and completion, so that progress analysis has accurate source data.
- As a lifter, I want to delete an unwanted workout from history or while it is open, so that my progress reflects the sessions I want to keep.
- As a lifter, I want to remove every uncompleted set from the completed workouts shown for a day, so that abandoned planned sets do not remain in history.
- As a lifter, I want the last session configuration to become the next routine defaults, so that progressive overload needs minimal setup.
- As a lifter, I want only sets completed last time to seed the next workout, and a configurable default of eight reps when no completed history exists, so that abandoned planned sets do not return as clutter.
- As a lifter, I want a paged Sunday-through-Saturday four-week activity calendar with routine symbols, colors, fallback acronyms, multi-workout counts, multi-person indicators, and a complete per-day workout summary, so that consistency is visible at a glance and each day's people, sets, reps, and measurements remain easy to inspect.
- As a lifter, I want pounds-only total-volume charts for routines and history, so that weight-training trends are not mixed with incompatible units.
- As a Hevy user, I want to choose which first-column routine names to create before importing history into one local profile, so that only relevant workouts, sets, notes, and metrics become editable local data.
- As a Hevy user, I want every exercise from my selected routines shown with a suggested local match, an override, and an explicit skip option, so that routines and history are not silently attached to the wrong movement.
- As a lifter, I want exercise search to match names only and Hevy mappings to filter by the last 30, 60, or 90 days, so that broad muscle metadata does not overwhelm relevant results.

## MVP acceptance

- First launch presents onboarding, requests the primary user's first name with the system given-name AutoFill hint, offers editable “Person 2” and “Person 3” defaults, offers optional starter routines, and imports 873 catalog exercises.
- Upper Body, Lower Body, and Core starters are explicit opt-in templates, create editable copies for the current people, and remain available from Routines later.
- Routine setup edits exercise structure only; workout prescriptions are seeded per person from the latest session.
- Each imported exercise retains both available source images for swipeable offline viewing.
- Starting a routine snapshots the latest routine exercise structure and selected people, seeding each person's values from their latest session.
- Active-workout cards use compact Load and Reps participant sections followed by shared set actions at the bottom, without duplicate left-side headings or repeated participant names/badges. The pinned participant picker beneath the current exercise title identifies and edits the visible crew while cards scroll; it has no separate People label. At the first exercise, participant pills retain their natural width and full names. After the current exercise advances, they compact to the same fixed 108-point columns and centerlines as Load, Reps, and completion controls, truncating long names with an ellipsis. Every participant column fills from the left, and profile-colored controls identify it. Larger Load values, Reps values, and the midpoint of two-wide completion-square rows share one vertical axis. Load remains one measurement control per participant; Reps is one base-reps control per participant with singular Rep/Reps labeling, an enlarged ellipsis menu for last-set customization/skips, and larger numbered per-set completion squares. Circular minus/plus controls provide consistent tap targets. Completion squares wrap after two in every participant mode. Status text for customized or skipped sets wraps instead of truncating and occupies a shared-height row, leaving every participant's Reps controls top-aligned even when a skipped set gives one person fewer completion rows; compensating whitespace flows beneath participants without status before completion continues. Remove Set precedes Add Set and is disabled at one set. The next-exercise arrow sits at the bottom-right of that action row with clear trailing separation from Add Set. The up arrow is hidden on the first exercise and reverses to the previous exercise only after the current target advances.
- Completed-workout details show one Delete Uncompleted Sets action at the very bottom whenever unfinished sets remain. Its confirmation appears in a centered, caret-free alert and removes unfinished sets from that workout while preserving completed sets.
- Completed-workout detail lists completed sets only. Multi-workout calendar days use a compact workout picker with time, people, and completed-set count on separate lines; deleting the selected workout returns to Workout home.
- A session is persisted when it starts; closing it requires no confirmation and does not change its workout meaning.
- No path in the normal UI can start a second session while another is active.
- The primary navigation is Workout, Routines, Exercises, Progress, and Settings; Settings contains People. Workout presents routine choice first, four-week activity second, and a conditional Deleted Workouts link last. Deleted workouts never appear in the activity calendar.
- Routine creation and editing offer a curated appearance picker with activity icons and app-coordinated colors. Deleting a routine hides it throughout the active app and moves it to Deleted Routines, where it can be restored without changing workout history.
- The Debug onboarding replay preserves and prefills existing people and routines without changing workout history or exercise data.
- Hevy CSV import is available from Settings and as an iOS CSV document handler. It filters exercises and history by selected source routines, supports frequency/recency/alphabetical exercise sorting, always creates uniquely named routines without updating existing ones, remembers confirmed exercise mappings, permits unmapped exercises to be skipped, reports completion, and skips previously imported workouts.
- The app compiles for the iOS simulator with no third-party dependencies.
