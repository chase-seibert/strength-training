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

  func testCalendarOpensEveryWorkoutForSelectedDay() {
    let multiWorkoutDay = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "2 workouts")
    ).firstMatch
    XCTAssertTrue(multiWorkoutDay.waitForExistence(timeout: 5))
    XCTAssertEqual(
      multiWorkoutDay.value as? String, "Lower Body, Basic Workout; Multiple people")
    multiWorkoutDay.tap()

    XCTAssertTrue(app.staticTexts["Lower Body"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Basic Workout"].exists)
    XCTAssertTrue(app.staticTexts["Alex"].exists)
    XCTAssertTrue(app.staticTexts["Jordan"].exists)
    XCTAssertTrue(app.staticTexts["145 lb × 5 reps"].exists)
    XCTAssertTrue(app.staticTexts["65 lb × 10 reps"].exists)

    let cleanupButton = app.buttons["delete-uncompleted-sets"]
    scrollToHittable(cleanupButton)
    cleanupButton.tap()

    let confirmCleanupButton = app.buttons["confirm-delete-uncompleted-sets"]
    XCTAssertTrue(confirmCleanupButton.waitForExistence(timeout: 2))
    confirmCleanupButton.tap()
    XCTAssertTrue(cleanupButton.waitForNonExistence(timeout: 2))
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
}
