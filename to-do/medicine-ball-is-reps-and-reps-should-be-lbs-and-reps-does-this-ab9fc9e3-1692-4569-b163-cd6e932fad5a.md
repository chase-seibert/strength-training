## User requirements

- As a user, I want medicine-ball exercises whose ball load is part of the exercise to track weight in pounds and repetitions, so that each set captures both the ball weight and the work performed.
- As a user, I want the catalog checked for other exercises with the same mismatch, so that any other externally loaded movement that should record weight and reps is identified and corrected consistently.
- Assumption: medicine-ball throws and passes may not all need load tracking. Review each catalog entry and change only exercises for which recording the ball's weight is appropriate; do not infer behavior from equipment labels alone.

## Architecture and data model

No SwiftData schema or material architecture change is expected. `TrackingUnit` already supports pounds plus reps, and the active workout UI uses the exercise's unit to decide whether to show load controls and weight/repetition labels. Exercise units are master-owned by `Exercise`, so routines and workout history resolve the corrected unit from that record.

The bundled catalog in `StrengthLog/Resources/exercise-catalog.json` supplies defaults for new installs. Existing installs do not refresh catalog units during seeding, so any approved changes also need a narrowly scoped, one-time correction in `SeedData.correctReviewedCatalogUnits`. Keep its source-ID and previous-unit guards so it updates only matching built-in exercises that still have the old default; preserve custom exercises and user-edited units. Do not synthesize historical loads when previously reps-only exercises become weighted. Review that existing set targets, measurements, and history summaries remain coherent when the master unit changes.

## Basic test cases

- For each medicine-ball exercise approved for load tracking, a fresh catalog seed shows a pounds-plus-reps unit; a reps-only throw or drill remains reps-only when load is not meaningful.
- On an existing store, the one-time correction changes an approved built-in exercise from its previous reps-only unit to pounds, and the workout presents a load control plus a reps target.
- Re-running seeding does not overwrite a unit the user changed, and custom or deleted exercises are not corrected.
- Existing routines and workout history linked to a corrected exercise resolve the new unit without losing set counts or inventing a weight; records with no load continue to omit a fabricated load in summaries.
- Audit other weighted-equipment catalog entries for similar mismatches and verify every proposed correction against the exercise instructions; bodyweight and unweighted movements remain unchanged.

## High-level implementation details

1. Inventory the medicine-ball catalog entries by stable source ID, name, and current unit. Review which movements have a meaningful selectable ball load; identify the specific intended exercise if the task refers to one entry, and record any additional approved medicine-ball corrections.
2. Audit other likely externally loaded equipment groups (such as dumbbell, barbell, kettlebell, cable, and machine) for reps-only defaults that may omit a real load. Treat these as candidates for review, not automatic changes.
3. Update approved catalog defaults and the matching guarded legacy corrections in `StrengthLog/Resources/exercise-catalog.json` and `StrengthLog/SeedData.swift`. Keep corrections limited to built-in records whose unit still equals the reviewed old default.
4. Add focused regression coverage for fresh seeding, the one-time existing-store correction, preservation of user/custom choices, and active workout/history presentation. Check whether changing the master unit affects old history values and ensure no implicit load conversion or default weight is introduced.
5. Run the repository's relevant verification for catalog and unit behavior, then follow the repository deployment and on-device visual-inspection workflow for this user-visible change.
