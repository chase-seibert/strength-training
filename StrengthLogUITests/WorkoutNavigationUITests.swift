import XCTest

final class WorkoutNavigationUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-basicWorkoutFixture"]
    app.launch()
  }

  func testStartCloseAndResumeActiveWorkout() {
    let startButton = app.buttons["start-routine-Basic Workout"]
    XCTAssertTrue(startButton.waitForExistence(timeout: 5))
    startButton.tap()

    let closeButton = app.buttons["close-active-workout"]
    XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    XCTAssertLessThan(closeButton.frame.midX, app.frame.midX)
    XCTAssertTrue(app.navigationBars["Basic Workout"].exists)

    closeButton.tap()

    let resumeButton = app.buttons["resume-active-workout"]
    XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
    resumeButton.tap()

    XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Basic Workout"].exists)
  }

  func testThreePersonWorkoutMatrixAndSharedCompletion() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 5))
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertTrue(app.staticTexts[name].exists)
    }
    XCTAssertFalse(app.buttons["previous-exercise"].exists)

    app.buttons["base-reps-plus-Alex"].tap()
    XCTAssertEqual(app.textFields["Base reps for Alex"].value as? String, "9")

    XCTAssertTrue(app.buttons["next-exercise-Bench Press"].exists)
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertTrue(app.buttons["participant-set-\(name)-1"].exists)
      XCTAssertTrue(app.buttons["participant-set-\(name)-2"].exists)
    }

    app.buttons["participant-set-Alex-1"].tap()
    XCTAssertEqual(
      app.buttons["participant-set-Alex-1"].label,
      "Remove completed Bench Press set 1")

    app.buttons["last-set-menu-Alex"].tap()
    XCTAssertTrue(app.buttons["Customize Last Set…"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.buttons["Skip Last Set"].exists)
    XCTAssertFalse(app.buttons["Skip Last Two Sets"].exists)
    app.buttons["Customize Last Set…"].tap()
    XCTAssertTrue(app.navigationBars["Customize last set"].waitForExistence(timeout: 2))
    app.buttons["Done"].tap()

    app.buttons["last-set-menu-Jordan"].tap()
    XCTAssertTrue(app.buttons["Skip Last Set"].exists)
    app.buttons["Skip Last Set"].tap()
    XCTAssertTrue(app.staticTexts["Last set skipped"].exists)
    app.buttons["last-set-menu-Jordan"].tap()
    app.buttons["Restore Skipped Sets"].tap()
    XCTAssertTrue(app.buttons["participant-set-Jordan-2"].exists)

    let historyButton = app.buttons["exercise-history-Bench Press"]
    historyButton.tap()
    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 3))
    app.buttons["Done"].tap()

    app.buttons["add-shared-set"].tap()
    XCTAssertTrue(app.buttons["remove-shared-set"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.buttons["participant-set-Alex-3"].exists)
    app.buttons["remove-shared-set"].tap()
    app.buttons["remove-shared-set"].tap()
    XCTAssertFalse(app.buttons["remove-shared-set"].isEnabled)
    XCTAssertFalse(app.buttons["participant-set-Alex-2"].exists)

    let addSet = app.buttons["add-shared-set"]
    let nextExercise = app.buttons["next-exercise-Bench Press"]
    XCTAssertLessThan(abs(addSet.frame.midY - nextExercise.frame.midY), 2)
  }

  func testSetCompletionControlsWrapByParticipantCount() {
    assertSetWrap(
      extraArguments: ["-activeWorkoutOnePersonFixture"],
      person: "Alex",
      lastSetOnFirstRow: 2,
      firstSetOnNextRow: 3)
    assertSetWrap(
      extraArguments: ["-activeWorkoutTwoPersonFixture"],
      person: "Alex",
      lastSetOnFirstRow: 2,
      firstSetOnNextRow: 3)
    assertSetWrap(
      extraArguments: [],
      person: "Alex",
      lastSetOnFirstRow: 2,
      firstSetOnNextRow: 3)
  }

  func testParticipantControlsKeepFixedWidthAndVerticalAxis() {
    let onePersonFrame = assertParticipantControlAlignment(
      extraArguments: ["-activeWorkoutOnePersonFixture"],
      person: "Alex")
    let twoPersonFrame = assertParticipantControlAlignment(
      extraArguments: ["-activeWorkoutTwoPersonFixture"],
      person: "Alex")
    let threePersonFrame = assertParticipantControlAlignment(
      extraArguments: [],
      person: "Alex")

    XCTAssertLessThan(abs(onePersonFrame.width - twoPersonFrame.width), 2)
    XCTAssertLessThan(abs(twoPersonFrame.width - threePersonFrame.width), 2)
    XCTAssertLessThan(onePersonFrame.midX, app.frame.midX)
  }

  func testParticipantStatusKeepsRepValuesAlignedAndMovesSetButtonsDown() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()
    let normalFirstSet = app.buttons["participant-set-Alex-1"]
    XCTAssertTrue(normalFirstSet.waitForExistence(timeout: 5))
    let normalFirstSetMinY = normalFirstSet.frame.minY

    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture",
      "-activeWorkoutFixture",
      "-activeWorkoutThreeSetSkippedLastSetFixture",
    ]
    app.launch()

    let alexReps = app.textFields["Base reps for Alex"]
    let jordanReps = app.textFields["Base reps for Jordan"]
    let alexFirstSet = app.buttons["participant-set-Alex-1"]
    let jordanFirstSet = app.buttons["participant-set-Jordan-1"]
    XCTAssertTrue(alexReps.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Last set skipped"].exists)
    XCTAssertLessThan(abs(alexReps.frame.midY - jordanReps.frame.midY), 2)
    XCTAssertLessThan(abs(alexFirstSet.frame.midY - jordanFirstSet.frame.midY), 2)
    XCTAssertGreaterThan(alexFirstSet.frame.minY, normalFirstSetMinY)
  }

  func testExerciseArrowNavigationTracksCurrentExercise() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture",
      "-activeWorkoutFixture",
      "-activeWorkoutNavigationFixture",
    ]
    app.launch()

    let benchNext = app.buttons["next-exercise-Bench Press"]
    let squatNext = app.buttons["next-exercise-Barbell Back Squat"]
    let previous = app.buttons["previous-exercise"]
    let alexPicker = app.buttons["participant-picker-Alex"]

    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 5))
    XCTAssertTrue(waitForHittable(benchNext))
    XCTAssertFalse(previous.exists)
    XCTAssertTrue(alexPicker.isHittable)
    benchNext.tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 3))
    XCTAssertTrue(waitForHittable(squatNext))
    XCTAssertTrue(previous.waitForExistence(timeout: 2))
    XCTAssertTrue(alexPicker.isHittable)

    previous.tap()
    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 3))
    XCTAssertTrue(waitForHittable(benchNext))
    XCTAssertFalse(previous.exists)

    benchNext.tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 3))
    XCTAssertTrue(waitForHittable(squatNext))
    squatNext.tap()
    XCTAssertTrue(app.navigationBars["Fixture Custom Curl"].waitForExistence(timeout: 3))

    previous.tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 3))
  }

  func testCalendarOpensEveryWorkoutForSelectedDay() {
    let multiWorkoutDay = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "2 workouts")
    ).firstMatch
    XCTAssertTrue(multiWorkoutDay.waitForExistence(timeout: 5))
    XCTAssertEqual(
      multiWorkoutDay.value as? String, "Lower Body, Basic Workout; Multiple people")
    multiWorkoutDay.tap()

    XCTAssertTrue(app.navigationBars["2 Workouts"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Lower Body"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Basic Workout"].exists)
    XCTAssertFalse(app.staticTexts["Barbell Back Squat"].exists)
    XCTAssertFalse(app.staticTexts["Bench Press"].exists)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "7:00")).firstMatch.exists
    )
    XCTAssertTrue(app.staticTexts["2 people"].exists)
    XCTAssertTrue(app.staticTexts["4 of 6 sets completed"].exists)
    XCTAssertEqual(
      app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "select-completed-workout-")
      ).count, 2)

    app.staticTexts["Basic Workout"].tap()
    XCTAssertTrue(app.navigationBars["Basic Workout"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["delete-completed-workout"].exists)
    XCTAssertTrue(app.staticTexts["Alex"].exists)
    XCTAssertTrue(app.staticTexts["Jordan"].exists)
    XCTAssertTrue(app.staticTexts["65 lb × 10 reps"].exists)
    XCTAssertFalse(app.staticTexts["Set 3"].exists)

    let cleanupButton = app.buttons["delete-uncompleted-sets"]
    scrollToHittable(cleanupButton)
    app.swipeUp()
    cleanupButton.tap()

    let confirmCleanupButton = app.buttons["Delete Sets"]
    XCTAssertTrue(confirmCleanupButton.waitForExistence(timeout: 2))
    confirmCleanupButton.tap()
    XCTAssertTrue(cleanupButton.waitForNonExistence(timeout: 2))
  }

  func testDeletingWorkoutFromPickerReturnsHome() {
    let multiWorkoutDay = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "2 workouts")
    ).firstMatch
    XCTAssertTrue(multiWorkoutDay.waitForExistence(timeout: 5))
    multiWorkoutDay.tap()

    XCTAssertTrue(app.navigationBars["2 Workouts"].waitForExistence(timeout: 5))
    app.staticTexts["Basic Workout"].tap()
    XCTAssertTrue(app.navigationBars["Basic Workout"].waitForExistence(timeout: 5))

    app.buttons["delete-completed-workout"].tap()
    let confirmDelete = app.alerts.buttons["Delete Workout"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 2))
    confirmDelete.tap()

    XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.navigationBars["2 Workouts"].exists)
  }

  func testCalendarNavigatesBetweenFourWeekPeriods() {
    XCTAssertFalse(app.staticTexts["Recent workouts"].exists)
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "resume-recent-workout"))
        .firstMatch.exists)

    let previousButton = app.buttons["activity-previous-period"]
    let nextButton = app.buttons["activity-next-period"]
    XCTAssertTrue(previousButton.waitForExistence(timeout: 5))
    XCTAssertTrue(nextButton.exists)
    XCTAssertFalse(nextButton.isEnabled)

    previousButton.tap()
    XCTAssertTrue(nextButton.isEnabled)

    nextButton.tap()
    XCTAssertFalse(nextButton.isEnabled)
  }

  func testSoftDeleteFromProgressExcludesCalendarAndRestores() {
    app.tabBars.buttons["Progress"].tap()

    let workoutRow = app.buttons["workout-history-Basic Workout"].firstMatch
    XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
    scrollToHittable(workoutRow)
    workoutRow.swipeLeft()

    let deleteButton = app.buttons["Delete"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    deleteButton.tap()

    let confirmButton = app.buttons["Delete Workout"]
    XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
    confirmButton.tap()

    app.tabBars.buttons["Workout"].tap()
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2 workouts")).firstMatch
        .exists)
    let deletedWorkoutsButton = app.buttons["Deleted Workouts (1)"]
    XCTAssertTrue(deletedWorkoutsButton.waitForExistence(timeout: 5))
    scrollToHittable(deletedWorkoutsButton)
    deletedWorkoutsButton.tap()

    let restoreButton = app.buttons["restore-workout-Basic Workout"]
    XCTAssertTrue(restoreButton.waitForExistence(timeout: 5))
    restoreButton.tap()
    XCTAssertFalse(restoreButton.exists)
  }

  func testSoftDeleteAndRestoreCustomExercise() {
    app.tabBars.buttons["Exercises"].tap()

    let exerciseRow = app.buttons["exercise-Fixture Custom Curl"]
    XCTAssertTrue(exerciseRow.waitForExistence(timeout: 5))
    exerciseRow.swipeLeft()

    let deleteButton = app.buttons["delete-custom-exercise-Fixture Custom Curl"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    deleteButton.tap()

    let deletedExercisesButton = app.buttons["Deleted Custom Exercises (1)"]
    XCTAssertTrue(deletedExercisesButton.waitForExistence(timeout: 5))
    deletedExercisesButton.tap()

    let restoreButton = app.buttons["restore-custom-exercise-Fixture Custom Curl"]
    XCTAssertTrue(restoreButton.waitForExistence(timeout: 5))
    restoreButton.tap()
    XCTAssertFalse(restoreButton.exists)
  }

  private func assertSetWrap(
    extraArguments: [String],
    person: String,
    lastSetOnFirstRow: Int,
    firstSetOnNextRow: Int
  ) {
    app.terminate()
    app.launchArguments =
      ["-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutWrappingFixture"]
      + extraArguments
    app.launch()

    let first = app.buttons["participant-set-\(person)-1"]
    let lastOnFirstRow = app.buttons["participant-set-\(person)-\(lastSetOnFirstRow)"]
    let firstOnNextRow = app.buttons["participant-set-\(person)-\(firstSetOnNextRow)"]
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    XCTAssertTrue(lastOnFirstRow.exists)
    XCTAssertTrue(firstOnNextRow.exists)
    XCTAssertLessThan(abs(first.frame.midY - lastOnFirstRow.frame.midY), 2)
    XCTAssertGreaterThan(firstOnNextRow.frame.minY, first.frame.maxY)
  }

  private func assertParticipantControlAlignment(
    extraArguments: [String],
    person: String
  ) -> CGRect {
    app.terminate()
    app.launchArguments =
      ["-basicWorkoutFixture", "-activeWorkoutFixture"] + extraArguments
    app.launch()

    let load = app.textFields["Pounds for \(person)"]
    let reps = app.textFields["Base reps for \(person)"]
    let loadMinus = app.buttons["measurement-minus-\(person)"]
    let repsMinus = app.buttons["base-reps-minus-\(person)"]
    let firstSet = app.buttons["participant-set-\(person)-1"]
    let secondSet = app.buttons["participant-set-\(person)-2"]
    XCTAssertTrue(load.waitForExistence(timeout: 5))
    XCTAssertTrue(reps.exists)
    XCTAssertTrue(firstSet.exists)
    XCTAssertTrue(secondSet.exists)

    let setPairMidX = (firstSet.frame.midX + secondSet.frame.midX) / 2
    XCTAssertLessThan(abs(loadMinus.frame.midX - repsMinus.frame.midX), 2)
    XCTAssertLessThan(abs(load.frame.midX - reps.frame.midX), 2)
    XCTAssertLessThan(abs(reps.frame.midX - setPairMidX), 2)
    return load.frame
  }

  private func scrollToHittable(_ element: XCUIElement) {
    for _ in 0..<8 where !element.isHittable {
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }

  private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"),
      object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }
}
