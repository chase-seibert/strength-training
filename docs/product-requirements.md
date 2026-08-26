# Product requirements

## Routines and catalog

- As a lifter, I want to create and rename routines, choose an icon and color for each one, and recover deleted routines, so that my recurring sessions match how I train without risking accidental loss.
- As a new lifter, I want optional Upper Body, Lower Body, and Core starters, so that I can begin quickly without being forced into sample data.
- As a lifter, I want a broad searchable exercise catalog with equipment, muscle, form notes, and imagery, so that I can build routines quickly and recognize unfamiliar movements.
- As a lifter, I want to add an exercise to a routine directly from its catalog detail, so that browsing naturally turns into routine building.
- As a lifter, I want to reorder exercises in routines, so that their display and workout order match my plan.
- As a lifter, I want to create custom exercises and change units on catalog exercises, so that the app does not constrain how I measure work.
- As a lifter, I want measurement units for pounds, kilograms, reps, time, distance, and steps, so that strength and conditioning movements share one model.

## Workout execution

- As a lifter, I want only one workout log open at a time, so that logging stays focused without introducing timer state.
- As a lifter, I want to select today's participants, so that solo, pair, and family sessions stay uncluttered.
- As a lifter, I want a separate measurement and sets for every participant, so that everyone can progress independently in one routine.
- As a lifter, I want exercise form thumbnails and optional full-size position images during a workout, so that I can check technique without leaving the session.
- As a lifter, I want one compact row per exercise and person with visible set checkmarks, so that repeated sets take one tap each.
- As a lifter, I want to edit measurement/reps and add sets while training, so that the log matches what actually happened.
- As a lifter, I want to add and reorder exercises while a workout is open, so that I can adapt the session without leaving it.
- As a lifter, I want an open workout to replace the app navigation, so that tabs do not compete with the task at hand.
- As a lifter, I want every workout edit saved as I make it and the freedom to close at any point, so that logging never depends on a finish ceremony.
- As a lifter, I want to reopen any workout log directly, so that interruptions and later corrections are effortless.

## Persistence and progress

- As a lifter, I want each session to preserve participant, exercise, measurement, reps, and completion, so that progress analysis has accurate source data.
- As a lifter, I want the last session configuration to become the next routine defaults, so that progressive overload needs minimal setup.
- As a lifter, I want a 30-day activity calendar, so that consistency is visible at a glance.
- As a lifter, I want pounds-only total-volume charts for routines and history, so that weight-training trends are not mixed with incompatible units.
- As a Hevy user, I want to choose which first-column routine names to create before importing history into one local profile, so that only relevant workouts, sets, notes, and metrics become editable local data.
- As a Hevy user, I want every exercise from my selected routines shown with a suggested local match, an override, and an explicit skip option, so that routines and history are not silently attached to the wrong movement.
- As a lifter, I want exercise search to match names only and Hevy mappings to filter by the last 30, 60, or 90 days, so that broad muscle metadata does not overwhelm relevant results.

## MVP acceptance

- First launch presents onboarding, requests the primary user's first name with the system given-name AutoFill hint, offers editable “Person 2” and “Person 3” defaults, offers optional starter routines, and imports 873 catalog exercises.
- Upper Body, Lower Body, and Core starters are explicit opt-in templates, create editable copies for the current people, and remain available from Routines later.
- Routine setup exposes two prescription controls per person: sets × reps (or rounds) and load/target.
- Each imported exercise retains both available source images for swipeable offline viewing.
- Starting a routine snapshots selected people and all routine prescriptions.
- A session is persisted when it starts; closing it requires no confirmation and does not change its workout meaning.
- No path in the normal UI can start a second session while another is active.
- The primary navigation is Workout, Routines, Exercises, Progress, and Settings; Settings contains People. Workout presents routine choice first, 30-day activity second, and recent workouts third.
- Routine creation and editing offer a curated appearance picker with activity icons and app-coordinated colors. Deleting a routine hides it throughout the active app and moves it to Deleted Routines, where it can be restored without changing workout history.
- The Debug onboarding replay preserves and prefills existing people and routines without changing workout history or exercise data.
- Hevy CSV import is available from Settings and as an iOS CSV document handler. It filters exercises and history by selected source routines, supports frequency/recency/alphabetical exercise sorting, always creates uniquely named routines without updating existing ones, remembers confirmed exercise mappings, permits unmapped exercises to be skipped, reports completion, and skips previously imported workouts.
- The app compiles for the iOS simulator with no third-party dependencies.
