# Rep counting defaults

The master Exercise owns `repCountingMode`, with only `standard` and `perSide`.
For `perSide`, a stored target of 8 means 8 reps on the left and 8 on the right.
A set is complete after both sides. Odd targets are valid; equal sides do not require
an even stored number. Standard counts are total reps. Time/distance/steps ignore this setting.

## Catalog choices — 2026-09-02

These defaults are a conservative interpretation of the bundled catalog's names and
technique notes, not a runtime name-matching rule. Other exercises remain standard.
Explicit one-arm/single-leg strength exercises and fixed-side cable work are included.
Alternating exercises, ordinary Russian/Plate Twists, ambiguous side bends, and
plyometric drills remain standard. Single-Arm Cable Crossover and Glute Kickback
explicitly alternate; Tricep Dumbbell Kickback uses both arms together. One-Arm
Kettlebell Swings has no instructions, so it is left for manual review.

Users can edit any choice in exercise details, including during a workout. Duplicates
copy the source's current setting and can then be edited independently. Routine and
workout records do not override it.

## Existing data

The additive nullable SwiftData field allows lightweight migration. A one-time
per-record initialization fills only nil values from the catalog (custom exercises
start standard). Later app launches never overwrite an explicit choice, including
standard. Renamed catalog records use their stable source ID. Saved numeric targets,
sets, completions, and relationships are not rewritten.

As with units, the current master setting also labels history. Pounds-volume totals
count both sides for perSide exercises: 8 × 20 lb × 2 = 320 lb. A past total-reps log
cannot be distinguished automatically from a past per-side log; review the master
setting if its prior convention differed. Rep PRs remain per-side targets, not doubled
numbers; one completed pair still counts as one set.

## Per-side catalog entries

76 of 873 entries:

| Exercise | Stable catalog ID |
| --- | --- |
| Band Hip Adductions | `Band_Hip_Adductions` |
| Barbell Side Split Squat | `Barbell_Side_Split_Squat` |
| Bent Over One-Arm Long Bar Row | `Bent_Over_One-Arm_Long_Bar_Row` |
| Cable Hip Adduction | `Cable_Hip_Adduction` |
| Cable Internal Rotation | `Cable_Internal_Rotation` |
| Cable One Arm Tricep Extension | `Cable_One_Arm_Tricep_Extension` |
| Cable Russian Twists | `Cable_Russian_Twists` |
| Dumbbell Lying One-Arm Rear Lateral Raise | `Dumbbell_Lying_One-Arm_Rear_Lateral_Raise` |
| Dumbbell One-Arm Shoulder Press | `Dumbbell_One-Arm_Shoulder_Press` |
| Dumbbell One-Arm Triceps Extension | `Dumbbell_One-Arm_Triceps_Extension` |
| Dumbbell One-Arm Upright Row | `Dumbbell_One-Arm_Upright_Row` |
| Dumbbell Seated One-Leg Calf Raise | `Dumbbell_Seated_One-Leg_Calf_Raise` |
| Extended Range One-Arm Kettlebell Floor Press | `Extended_Range_One-Arm_Kettlebell_Floor_Press` |
| External Rotation | `External_Rotation` |
| External Rotation with Band | `External_Rotation_with_Band` |
| External Rotation with Cable | `External_Rotation_with_Cable` |
| Internal Rotation with Band | `Internal_Rotation_with_Band` |
| Kettlebell One-Legged Deadlift | `Kettlebell_One-Legged_Deadlift` |
| Kettlebell Pistol Squat | `Kettlebell_Pistol_Squat` |
| Kneeling Single-Arm High Pulley Row | `Kneeling_Single-Arm_High_Pulley_Row` |
| Lying One-Arm Lateral Raise | `Lying_One-Arm_Lateral_Raise` |
| One-Arm Dumbbell Row | `One-Arm_Dumbbell_Row` |
| One-Arm Flat Bench Dumbbell Flye | `One-Arm_Flat_Bench_Dumbbell_Flye` |
| One-Arm High-Pulley Cable Side Bends | `One-Arm_High-Pulley_Cable_Side_Bends` |
| One-Arm Incline Lateral Raise | `One-Arm_Incline_Lateral_Raise` |
| One-Arm Kettlebell Clean | `One-Arm_Kettlebell_Clean` |
| One-Arm Kettlebell Clean and Jerk | `One-Arm_Kettlebell_Clean_and_Jerk` |
| One-Arm Kettlebell Floor Press | `One-Arm_Kettlebell_Floor_Press` |
| One-Arm Kettlebell Jerk | `One-Arm_Kettlebell_Jerk` |
| One-Arm Kettlebell Military Press To The Side | `One-Arm_Kettlebell_Military_Press_To_The_Side` |
| One-Arm Kettlebell Para Press | `One-Arm_Kettlebell_Para_Press` |
| One-Arm Kettlebell Push Press | `One-Arm_Kettlebell_Push_Press` |
| One-Arm Kettlebell Row | `One-Arm_Kettlebell_Row` |
| One-Arm Kettlebell Snatch | `One-Arm_Kettlebell_Snatch` |
| One-Arm Kettlebell Split Jerk | `One-Arm_Kettlebell_Split_Jerk` |
| One-Arm Kettlebell Split Snatch | `One-Arm_Kettlebell_Split_Snatch` |
| One-Arm Long Bar Row | `One-Arm_Long_Bar_Row` |
| One-Arm Medicine Ball Slam | `One-Arm_Medicine_Ball_Slam` |
| One-Arm Open Palm Kettlebell Clean | `One-Arm_Open_Palm_Kettlebell_Clean` |
| One-Arm Overhead Kettlebell Squats | `One-Arm_Overhead_Kettlebell_Squats` |
| One-Arm Side Deadlift | `One-Arm_Side_Deadlift` |
| One-Arm Side Laterals | `One-Arm_Side_Laterals` |
| One-Legged Cable Kickback | `One-Legged_Cable_Kickback` |
| One Arm Chin-Up | `One_Arm_Chin-Up` |
| One Arm Dumbbell Bench Press | `One_Arm_Dumbbell_Bench_Press` |
| One Arm Dumbbell Preacher Curl | `One_Arm_Dumbbell_Preacher_Curl` |
| One Arm Floor Press | `One_Arm_Floor_Press` |
| One Arm Lat Pulldown | `One_Arm_Lat_Pulldown` |
| One Arm Pronated Dumbbell Triceps Extension | `One_Arm_Pronated_Dumbbell_Triceps_Extension` |
| One Arm Supinated Dumbbell Triceps Extension | `One_Arm_Supinated_Dumbbell_Triceps_Extension` |
| One Leg Barbell Squat | `One_Leg_Barbell_Squat` |
| Pallof Press | `Pallof_Press` |
| Pallof Press With Rotation | `Pallof_Press_With_Rotation` |
| Seated Bent-Over One-Arm Dumbbell Triceps Extension | `Seated_Bent-Over_One-Arm_Dumbbell_Triceps_Extension` |
| Seated One-Arm Dumbbell Palms-Down Wrist Curl | `Seated_One-Arm_Dumbbell_Palms-Down_Wrist_Curl` |
| Seated One-Arm Dumbbell Palms-Up Wrist Curl | `Seated_One-Arm_Dumbbell_Palms-Up_Wrist_Curl` |
| Seated One-arm Cable Pulley Rows | `Seated_One-arm_Cable_Pulley_Rows` |
| Single-Arm Linear Jammer | `Single-Arm_Linear_Jammer` |
| Single-Arm Push-Up | `Single-Arm_Push-Up` |
| Single-Leg High Box Squat | `Single-Leg_High_Box_Squat` |
| Single-Leg Leg Extension | `Single-Leg_Leg_Extension` |
| Single Leg Glute Bridge | `Single_Leg_Glute_Bridge` |
| Smith Machine One-Arm Upright Row | `Smith_Machine_One-Arm_Upright_Row` |
| Smith Machine Pistol Squat | `Smith_Machine_Pistol_Squat` |
| Smith Single-Leg Split Squat | `Smith_Single-Leg_Split_Squat` |
| Split Squat with Dumbbells | `Split_Squat_with_Dumbbells` |
| Standing Bent-Over One-Arm Dumbbell Triceps Extension | `Standing_Bent-Over_One-Arm_Dumbbell_Triceps_Extension` |
| Standing Cable Lift | `Standing_Cable_Lift` |
| Standing Cable Wood Chop | `Standing_Cable_Wood_Chop` |
| Standing Low-Pulley One-Arm Triceps Extension | `Standing_Low-Pulley_One-Arm_Triceps_Extension` |
| Standing One-Arm Cable Curl | `Standing_One-Arm_Cable_Curl` |
| Standing One-Arm Dumbbell Curl Over Incline Bench | `Standing_One-Arm_Dumbbell_Curl_Over_Incline_Bench` |
| Standing One-Arm Dumbbell Triceps Extension | `Standing_One-Arm_Dumbbell_Triceps_Extension` |
| Standing Palm-In One-Arm Dumbbell Press | `Standing_Palm-In_One-Arm_Dumbbell_Press` |
| Suspended Split Squat | `Suspended_Split_Squat` |
| Weighted Ball Side Bend | `Weighted_Ball_Side_Bend` |
