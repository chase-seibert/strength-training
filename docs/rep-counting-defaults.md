# Rep counting defaults

The master Exercise owns both the legacy `repCountingMode` and the optional
`sideTotalRepsReminderEnabled` setting. The reminder defaults on for 77 catalog entries:
the 76 previously reviewed `perSide` choices plus Russian Twist, whose instructions
alternate sides. With the reminder on,
the reps picker stores the total across both sides and the active-workout callout can
show either that total or its per-side split. The callout never changes the stored target.
With the reminder off, `repCountingMode` retains its legacy `standard` and `perSide`
behavior. Time/distance/steps ignore both rep settings.

## Catalog choices — 2026-09-02

These defaults are a conservative interpretation of the bundled catalog's names and
technique notes, not a runtime name-matching rule. The list is now the default-on set
for the total-reps/per-side reminder, including single-arm/single-leg movements that
are normally performed on each side and fixed-side cable work. Users can still override
each exercise in Edit Exercise. Paired-count movements such as Alternate Heel Touchers,
ordinary Plate Twists, ambiguous side bends, and plyometric drills stay off unless the
catalog already marked them `perSide`; these are candidates for future review.
Single-Arm Cable Crossover and
Glute Kickback explicitly alternate, Tricep Dumbbell Kickback uses both arms together,
and One-Arm Kettlebell Swings has no instructions, so each needs manual judgment.

Users can edit any choice in exercise details, including during a workout. Duplicates
copy the source's current setting and can then be edited independently. Routine and
workout records do not override it.

## Existing data

The additive nullable SwiftData fields allow lightweight migration. A one-time
per-record initialization fills only nil `repCountingModeRaw` values from the catalog.
The reminder's nil value follows the stable source ID's default list; custom exercises
start with it off, and an explicit true/false choice is never overwritten. Renamed
catalog records use their stable source ID. Saved numeric targets, sets, completions,
and relationships are not rewritten.

When the reminder is enabled, the effective rep-counting mode is total, so an existing
stored target of 24 is still 24 and volume is not multiplied by two. This deliberately
changes the interpretation of old catalog-default `perSide` logs without rewriting
their numeric values. If a user disables the reminder, they can select legacy `perSide`
again in Edit Exercise; legacy per-side pounds volume multiplies the recorded count by
two. PRs and set completion continue to use the recorded target and completed set.

## Default-on total-reps/per-side reminder entries

77 of 873 entries:

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
| Russian Twist | `Russian_Twist` |
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
