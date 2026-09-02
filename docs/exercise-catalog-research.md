# Exercise catalog research

Date: 2026-08-26

## Recommendation

Use [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) as the initial offline catalog and keep a provider-neutral import boundary so wger or a reviewed commercial catalog can supplement it later.

The checked-in source contained 873 exercises at evaluation time. Each record includes a stable identifier, name, category, equipment, primary and secondary muscles, instructions, and generally two JPEGs showing exercise positions. The project describes the dataset as public domain and distributes it under the Unlicense. It can be downloaded as a single JSON file, so the app has no API-key, uptime, privacy, or first-launch network dependency.

StrengthLog bundles a compact normalized derivative containing all 873 entries and all 1,746 form images. The images are generated from pinned Free Exercise DB revision `b0eed061e1c832b3ed815fbaa4b45b3cdc14df49`, resized to 640 pixels wide, and encoded as WebP at quality 65. This preserves offline form imagery without depending on the upstream GitHub repository at runtime. The upstream JPEGs total 94.1 MiB; the phone-optimized bundled derivative is 27.5 MiB of image data.

## Sources evaluated

| Source | Breadth and fields | Media | Access and license | Assessment |
| --- | --- | --- | --- | --- |
| [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) | 873 checked-in records; category, equipment, muscles, level, force, mechanics, instructions | Usually two JPEG positions | Static JSON/files; Unlicense | Best MVP fit. Broad, offline-capable, no key, simplest reuse posture. Selected. |
| [wger](https://wger.de) / [API docs](https://wger.readthedocs.io/en/latest/api/api.html) | Community exercise/translation data plus workout concepts; public exercise endpoints are anonymous | Images and some videos | JSON REST API; content uses Creative Commons terms on individual entries; server code is AGPL | Strong future supplement, particularly for multilingual content and openly licensed video. Requires per-entry license/attribution handling and sync logic. |
| [RepDB free dataset](https://github.com/RepDB/exercise-dataset) | 250+ curated records in the current public free tier; multilingual instructions, equipment, muscles, MET | Consistent 512 px WebP start/peak illustrations | Static files under a custom in-app-use license requiring attribution and restricting redistribution/AI derivation | Higher visual consistency, but smaller and not open data in the conventional sense. Consider only after a legal/product review. |
| ExerciseDB-derived GitHub mirrors | Often claim 1,300+ records with animated GIFs | GIF/animation is the main attraction | Many mirrors disclaim ownership or point to separate commercial API terms | Do not ship from a mirror. Provenance and redistribution rights are too ambiguous. |

## Normalization and default units

The catalog does not provide the requested tracking measurement. StrengthLog seeds each master exercise with an editable default unit using transparent deterministic rules:

- weighted strength/strongman/equipment work → pounds;
- body-only and plyometric work → repetitions;
- stretching → seconds;
- cardio → minutes, except walking/running → miles and stair/step exercises → steps.

Reviewed overrides (2026-09-02): Plank, Balance Board, Battling Ropes, Mountain Climbers, Isometric Chest Squeezes, and both Isometric Neck Exercise entries use seconds. Superman, Toe Touchers, and Ankle Circles use repetitions. Other ambiguous or load-plus-duration candidates are unchanged.

Every seconds-based entry has an explicit `defaultDurationSeconds`: 30 as the general fallback, shorter values where the reviewed instructions specify them, Plank 60, Stomach Vacuum and One Handed Hang 20, Isometric Chest Squeezes 10, and both neck-isometric entries 5. Targets are per hold/side/direction, not the sum of both sides. Defaults only seed fresh sets; recorded values are retained.

Current distribution:

| Unit | Exercises |
| --- | ---: |
| Pounds | 598 |
| Repetitions | 134 |
| Seconds | 127 |
| Minutes | 8 |
| Miles | 4 |
| Steps | 2 |
| **Total** | **873** |

These are deliberate defaults rather than claims about the only valid way to track an exercise. Category-based inference can misclassify dynamic mobility as timed stretching and equipment-based holds as pounds; further changes require per-entry review. The master exercise unit can be corrected in exercise detail; routines never override it.

## Media findings

- Free Exercise DB's two-position photos are sufficient for recognition and a basic start/end pose reference. They are not video, do not demonstrate tempo, and vary in visual style/quality.
- StrengthLog bundles both images for every one of the 873 current records and offers paged offline viewing in exercise detail and from an active workout.
- wger is the most promising open video supplement. Its project documentation credits a batch of roughly 150 CC-BY-SA exercise videos, but the app would need to retain creator/license metadata per asset.
- A polished illustration catalog can improve consistency, but available options tend to use custom or commercial licensing rather than genuinely open data.

## Risks before public release

1. Perform a trainer-led content review. A large crowdsourced catalog contains duplicates, inconsistent names, incomplete equipment metadata, and form instructions that should not be treated as medical guidance.
2. Snapshot source revision and license text for every import. Upstream files and licensing can change after an app release.
3. Regenerate and review the bundled derivative deliberately when updating the pinned source revision.
4. Preserve source and per-asset attribution fields in the model before combining providers.
5. Avoid scraping commercial fitness sites or relying on mirrors whose authors do not own the imagery.

## Next catalog increment

Build a reproducible importer that pins a Free Exercise DB commit, validates schema/license files, produces the compact app JSON, reports duplicates/missing fields, and runs a human review queue for unit inference. Then pilot a wger supplement for properly attributed multilingual instructions and CC-licensed video.
