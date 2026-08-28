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
    let firstSharedSet = app.descendants(matching: .any)["shared-set-1"]
    let secondSharedSet = app.descendants(matching: .any)["shared-set-2"]
    XCTAssertTrue(firstSharedSet.exists)
    XCTAssertTrue(secondSharedSet.exists)
    XCTAssertTrue(app.buttons["previous-exercise"].exists)
    XCTAssertLessThan(app.buttons["previous-exercise"].frame.midY, app.frame.midY)

    app.buttons["reps-plus-Alex-1"].tap()
    XCTAssertEqual(app.textFields["Reps for Alex, set 2"].value as? String, "9")

    XCTAssertTrue(app.buttons["next-exercise-Bench Press"].exists)
    XCTAssertFalse(app.buttons["complete-exercise-Bench Press"].exists)
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertEqual(app.buttons["participant-set-\(name)-1"].label, "Complete set")
      XCTAssertEqual(app.buttons["participant-set-\(name)-2"].label, "Complete set")
    }

    firstSharedSet.tap()
    secondSharedSet.tap()
    secondSharedSet.tap()
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertTrue(app.buttons["participant-set-\(name)-2"].exists)
      XCTAssertEqual(app.buttons["participant-set-\(name)-2"].label, "Complete set")
    }

    let historyButton = app.buttons["exercise-history-Bench Press"]
    historyButton.tap()
    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 3))
    app.buttons["Done"].tap()

    app.buttons["add-shared-set"].tap()
    let thirdSharedSet = app.descendants(matching: .any)["shared-set-3"]
    XCTAssertTrue(thirdSharedSet.waitForExistence(timeout: 2))
    thirdSharedSet.swipeLeft()
    let deleteThirdSet = app.buttons["delete-set-3"]
    XCTAssertTrue(deleteThirdSet.waitForExistence(timeout: 2))
    deleteThirdSet.tap()
    XCTAssertTrue(thirdSharedSet.waitForNonExistence(timeout: 2))
  }

  func testExerciseArrowNavigationTracksCurrentExercise() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture",
      "-activeWorkoutFixture",
      "-activeWorkoutNavigationFixture",
    ]
    app.launch()

    let benchTitle = app.staticTexts["Bench Press"]
    let squatTitle = app.staticTexts["Barbell Back Squat"]
    let curlTitle = app.staticTexts["Fixture Custom Curl"]
    let benchNext = app.buttons["next-exercise-Bench Press"]
    let squatNext = app.buttons["next-exercise-Barbell Back Squat"]
    let previous = app.buttons["previous-exercise"]

    XCTAssertTrue(waitForHittable(benchTitle))
    benchNext.tap()
    XCTAssertTrue(waitForHittable(squatTitle))

    previous.tap()
    XCTAssertTrue(waitForHittable(benchTitle))

    benchNext.tap()
    XCTAssertTrue(waitForHittable(squatTitle))
    squatNext.tap()
    XCTAssertTrue(waitForHittable(curlTitle))

    previous.tap()
    XCTAssertTrue(waitForHittable(squatTitle))
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
