## User requirements

As a user, I want every weight and weight-volume value on the workout celebration screen to use comma grouping for thousands, so that large totals are easy to read.

As a user, I want smaller values and fractional values to remain clear, so that formatting does not change the underlying workout results or hide precision already shown.

Scope: the completed-workout celebration shown in the supplied screenshot, including total workout volume, each participant's workout volume, four-week volume totals and participant momentum rows, and new personal-record values with weight-based units. Assume comma grouping for thousands while retaining the existing number of fractional digits and the current units. Workout counts, set counts, dates, and duration are not weight values and should keep their current presentation.

## Architecture and data model

No material architecture, persistence, schema, migration, or compatibility change is required. `WorkoutCelebrationSummary` already supplies numeric values, and the presentation centralizes their display through `celebrationNumber` in `WorkoutCelebrationView.swift`. The implementation should ensure the shared display formatting applies comma grouping consistently to all weight and volume labels without changing stored or calculated values.

## Basic test cases

- Complete a workout whose total and participant volumes exceed 999; each displayed pounds value includes the thousands separator (for example, `10,880 lb`).
- Display a four-week total and participant momentum value above 999; both use the same grouping as workout volume.
- Display a new weight-based personal record above 999; its number is grouped while its existing unit label remains intact.
- Display values below 1,000 and fractional values; they retain the existing presentation and precision, with no unnecessary grouping.
- Confirm workout counts, completed-set counts, duration, and non-weight personal-record units remain unchanged.
- Open and scroll the celebration screen to verify values in the top summary, participant cards, PR list, and recent-momentum section.

### Text version of the supplied screenshot with proposed number formatting

```text
THIS WORKOUT
Total volume                                      22,300 lb
Duration                                          49m 41s

Chase                                             22,300 lb volume
New personal records
Dumbbell Walking Lunge                            810 lb·reps
Goblet Squat                                       480 lb·reps

RECENT MOMENTUM · 4 WEEKS
Workouts                                          8 completed sessions
Volume                                            132,452 lb
Chase                                             8 workouts · 132,452 lb
```

The values below 1,000 remain unchanged; the larger volume values show the comma separator. Counts and duration retain their current formatting.

## High-level implementation details

1. Review `StrengthLog/WorkoutCelebrationView.swift` and make `celebrationNumber` explicitly provide the requested grouping behavior while preserving its current integer-versus-fractional precision. Apply it to every weight/volume display, and avoid changing count or duration fields.
2. Extend `testCompletingWorkoutShowsCelebrationSummary` in `StrengthLogUITests/WorkoutNavigationUITests.swift`. Its `-celebrationFormattingFixture` already creates a large workout weight and the test currently checks only total volume (`10,880 lb`); add observable assertions for large participant, recent-momentum, and weight-based PR values. Adjust the fixture only as needed to produce those cases without changing production data behavior.
3. Verify with `make workout-navigation-ui-test UI_TEST_FILTER=StrengthLogUITests/WorkoutNavigationUITests/testCompletingWorkoutShowsCelebrationSummary`, checking a nonzero executed test count and the displayed values. After the app change passes verification, follow the repository workflow with `make phone-deploy` and visually inspect the celebration screen on Chase's iPhone 17 Pro.
4. Keep number formatting locale behavior explicit in implementation and assertions. The screenshot shows values without separators; confirm the intended comma behavior in the test environment so locale defaults cannot leave the regression undetected.
