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

  func testResumeCompletedWorkout() {
    let resumeButton = app.buttons["resume-recent-workout-Basic Workout"]
    XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
    resumeButton.tap()

    XCTAssertTrue(app.buttons["close-active-workout"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Basic Workout"].exists)
  }

  func testSoftDeleteAndRestoreRecentWorkout() {
    let workoutRow = app.buttons["resume-recent-workout-Basic Workout"]
    XCTAssertTrue(workoutRow.waitForExistence(timeout: 5))
    workoutRow.swipeLeft()

    let deleteButton = app.buttons["delete-recent-workout-Basic Workout"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    deleteButton.tap()

    let confirmButton = app.buttons["Delete Workout"]
    XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))
    confirmButton.tap()

    XCTAssertTrue(app.buttons["Deleted Workouts (1)"].waitForExistence(timeout: 5))
    app.buttons["Deleted Workouts (1)"].tap()

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
}
