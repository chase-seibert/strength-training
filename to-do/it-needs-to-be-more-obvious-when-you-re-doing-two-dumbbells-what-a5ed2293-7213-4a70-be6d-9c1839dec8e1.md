## User requirements

- As a user, I want the load for dumbbell exercises to say that the number is the weight of each dumbbell, so that a set shown as 25 lb is clearly understood as 25 lb in each hand when I use a pair.
- As a user, I want this meaning to stay clear when I review set details, so that the load is not mistaken for the combined weight of both dumbbells.

Assumption: the catalog's `equipment == "dumbbell"` identifies exercises whose load should be described per dumbbell, including one-arm variations. Keep the entered number as the load of one dumbbell; do not double it or change workout volume calculations as part of this task. The catalog does not currently distinguish one from two dumbbells.

## Architecture and data model

This is a presentation and wording change. `ParticipantLog.measurement` and the per-set `WorkoutSet.measurement` override already store one load value, and the exercise record already provides equipment metadata. No schema, migration, persistence, or compatibility change is required. Format the existing value with a contextual label such as “25 lb each” or “25 kg each” for dumbbell exercises, while retaining the ordinary unit label for other equipment. Use the same resolved exercise metadata and formatting rule in active workout entry and any set summary shown in history or review; preserve the underlying number and per-set override behavior.

## Basic test cases

- In an active dumbbell exercise, verify pound and kilogram loads visibly say “each” or “per dumbbell” beside the number; the participant's name, adjustment controls, and set values remain clear.
- Verify a per-set load override and the participant's default load both receive the per-dumbbell wording, and changing the value still saves and carries forward as the same numeric load.
- Verify dumbbell exercise summaries retain the per-dumbbell wording, including a completed set viewed later.
- Verify barbell, cable, and other non-dumbbell exercises keep their current unit presentation.
- Verify one-arm dumbbell exercises use wording that still describes the weight of the single dumbbell, without implying that the stored value is doubled.

## High-level implementation details

1. Trace the resolved exercise metadata from `ExerciseLog` into the active exercise card in `StrengthLog/ActiveWorkoutView.swift`. Add a small shared load-label/formatting rule keyed to dumbbell equipment, and show the per-dumbbell meaning next to the existing `MeasurementStepper` value without reducing the legibility or width of participant controls.
2. Apply the same contextual wording to set summaries in `StrengthLog/Models.swift` and the history/review surfaces that render those summaries. Keep calculations, stored measurements, imports, defaults, and unit conversion unchanged.
3. Add focused UI coverage in the existing workout UI tests for a paired dumbbell exercise and a non-dumbbell exercise, including a set-level override. Update `docs/product-requirements.md` and `docs/architecture.md` to document the per-dumbbell display convention if it is adopted consistently across entry and history.
4. During implementation, verify the wording in both lb and kg and check narrow participant layouts for clipping. Run the relevant workout UI coverage and `make lint`/`make test`; after successful app-code verification, follow the repository workflow with `make phone-deploy` and visually inspect the active workout and set summary on the iPhone 17 Pro.

Material decision: if the intended meaning should apply only to exercises explicitly performed with a pair, add a user-editable pair/single-dumbbell distinction to exercise metadata and define catalog defaults; equipment alone cannot reliably identify the number of dumbbells. The simpler assumption above keeps this request presentation-only and is safe for single-dumbbell movements as well.
