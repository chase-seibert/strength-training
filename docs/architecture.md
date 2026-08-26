# Architecture

## Shape

StrengthLog is a dependency-free SwiftUI app targeting iOS 17 and later. SwiftData owns local persistence, Swift Charts renders progress, and `AsyncImage` loads optional catalog photography.

The resting UI is organized around five tabs:

- Workout: available routines first, then 30-day activity and direct reopening for the three most recent workouts.
- Routines: routine composition, naming, icon and color selection, ordering, and recoverable deletion.
- Exercises: catalog browsing and custom exercises.
- Progress: aggregate pounds volume and immutable session snapshots.
- Settings: a People section for configurable participant names/colors and archiving, plus app information.

In Debug builds, Settings also links to a Developer menu. Its replay action clears only the onboarding presentation flag. Onboarding then prefills existing people and routines while preserving workout history, exercise records, custom exercises, and all configuration. The menu is excluded from Release builds.

## Data flow

`Routine` owns ordered `RoutineExercise` objects. Each routine exercise owns a `Prescription` per named participant, containing one measurement and ordered set templates. An optional `deletedAt` timestamp implements lightweight soft deletion: active-routine queries exclude deleted rows, while Deleted Routines can clear the timestamp to restore the same routine graph.

`PersonProfile.sortOrder` preserves the order established during onboarding across Settings, routine editing, workout setup, and participant visibility. The primary onboarding profile is therefore always presented first. Existing stores are migrated once using the original onboarding color sequence before persisting explicit order values.

Starting a routine immediately snapshots that graph into a persisted `WorkoutSession`. Session logs are independent objects, so changing a routine later does not rewrite exercise history; the current routine name is resolved from the session's stable `routineID` whenever history is displayed. During a workout the app edits session measurement, reps, completion, visibility, and added sets directly. Closing the editor copies its current prescriptions back to the matching routine as next-time defaults.

Only one session can be open in the app UI. When one is open, the root replaces the entire tab interface with its workout editor. Done returns to the five resting tabs and performs the save/default-update path. Any log can be reopened directly from Workout or Progress without confirmation. The persisted `isActive` and `endedAt` fields remain as presentation and migration plumbing, not as workout completion or timing concepts.

Both `RoutineExercise` and `ExerciseLog` use explicit `sortOrder` values. Open-workout moves rewrite those values after every reorder. Routine edit mode instead snapshots its name, icon, color, and ordered exercise references into draft state: deletion, reordering, and appearance changes refresh that draft immediately, Cancel discards it, and Save applies relationship removals, child deletion, appearance, and final sort-order values in one persistence operation. Deleting the routine itself sets `deletedAt`, preserving its relationships and all independent workout history. A running workout can append catalog exercises with participant logs for the current workout crew; additions remain part of that session snapshot.

Fresh installs enter onboarding before the tab interface. Onboarding creates user-entered profiles and, only when selected, editable copies of the Upper Body, Lower Body, and Core starter templates. The same templates remain available from the Routines add menu, alongside custom routine creation. Existing stores containing profiles bypass onboarding.

## Hevy CSV import

StrengthLog registers `public.comma-separated-values` as a document type and routes both shared files and the Settings file picker through `HevyImportCoordinator`. `HevyCSVParser` is an RFC 4180-style, dependency-free parser that normalizes mixed CRLF/LF line endings and accepts the Hevy workout columns shown in the product flow, including local or ISO timestamps, pounds or kilograms, miles/kilometers/meters, duration, set type, and RPE. The first `title` column is treated as the routine name; rows are grouped into workouts by title and start time, then into ordered exercises and sets.

Before persistence, the user selects which source routines to import. Only exercises and workouts belonging to those routines proceed. Every distinct relevant exercise is visible in the review UI and resolves through a remembered `ExternalExerciseMapping`, normalized catalog-name scoring, or an explicit local/custom choice. Unmapped exercises are skipped in both routine templates and history. Confirmed mappings are reusable on later imports. A Hevy account is assigned to one selected `PersonProfile`.

The importer always creates a new routine for every selected source title and never updates an existing one. Name collisions receive a numeric suffix. Each routine includes the union of mapped exercises found across all exported workouts for that title, using the most recent occurrence for its default prescription. As a secondary operation, the importer snapshots selected workouts as inactive history, retains per-set load, reps, distance, duration, RPE, type, notes, and superset identifiers, and uses a stable source key to skip re-imported workouts. All inserts and mapping updates are saved together; a failure rolls back the model context.

## Catalog

`exercise-catalog.json` is a generated, normalized, offline seed. On first launch it becomes editable SwiftData `Exercise` records. Each source record retains both image paths; the app maps those paths to a bundled 640-pixel WebP derivative and pages through the local images in the library and active workout. Custom exercises use the same model and have no source identifier.

## Tradeoffs

- Participant references are snapshot names rather than mutable foreign keys. This intentionally keeps history readable after a profile rename or archive.
- Routine default reconciliation currently matches exercise names inside a stable routine ID. A later migration should store the routine-exercise UUID in each exercise log.
- The first seed inserts 873 records on the main model context. It passed the first-launch smoke test, but a background staged import would be appropriate if the catalog grows substantially.
- Sync, outbound sharing, HealthKit, rest timers, live superset behavior, and cloud backup are outside the first version.
