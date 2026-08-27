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
}
