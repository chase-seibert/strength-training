import XCTest

final class WorkoutNavigationUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["-basicWorkoutFixture"]
    app.launch()
  }

  func testNewExerciseFormIsGuidedAndCaptureScreenshot() {
    app.tabBars.buttons["Exercises"].tap()
    let addButton = app.buttons["Custom exercise"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    addButton.tap()
    XCTAssertTrue(app.navigationBars["New Exercise"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.staticTexts["Exercise name"].exists)
    XCTAssertTrue(app.staticTexts["Workout logging"].exists)
    XCTAssertTrue(app.staticTexts["Optional details"].exists)
    XCTAssertTrue(app.staticTexts["Main muscle"].exists)
    XCTAssertTrue(app.staticTexts["Equipment"].exists)
    app.buttons["More details"].tap()
    XCTAssertTrue(app.staticTexts["Exercise type"].exists)

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "guided-new-exercise-form"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testWorkoutSettingsShowDefaultSetAndRepCounts() {
    app.tabBars.buttons["Settings"].tap()

    XCTAssertTrue(app.staticTexts["Default sets"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Default reps"].exists)
    let defaultSets = app.steppers.matching(
      NSPredicate(format: "label CONTAINS %@", "Default sets")
    ).firstMatch
    let defaultReps = app.steppers.matching(
      NSPredicate(format: "label CONTAINS %@", "Default reps")
    ).firstMatch
    XCTAssertTrue(defaultSets.exists)
    XCTAssertTrue(defaultReps.exists)
    XCTAssertTrue(
      defaultSets.label.contains("3") || String(describing: defaultSets.value).contains("3"))
    XCTAssertTrue(
      defaultReps.label.contains("8") || String(describing: defaultReps.value).contains("8"))
    XCTAssertTrue(app.switches["Rest timer notifications"].exists)
    XCTAssertTrue(app.staticTexts["Apple Health"].exists)
    XCTAssertTrue(app.switches["apple-health-workout-export-toggle"].exists)
  }

  func testRoutineRestTimerCanBeConfigured() {
    app.tabBars.buttons["Routines"].tap()
    app.staticTexts["Basic Workout"].tap()
    app.buttons["Edit"].tap()

    XCTAssertTrue(app.staticTexts["Rest timer"].waitForExistence(timeout: 3))
    XCTAssertTrue(
      app.staticTexts[
        "Starts after each completed set and uses the same duration throughout this routine."
      ].exists)
  }

  func testLiveWorkoutHeaderShowsRestTimer() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-restTimerFixture",
      "-activeWorkoutNavigationFixture",
    ]
    app.launch()

    app.buttons.matching(
      NSPredicate(
        format: "identifier == %@ AND label == %@", "participant-set-Alex-1",
        "Complete Bench Press set 1")
    ).firstMatch.tap()
    XCTAssertTrue(app.otherElements["live-workout-header"].waitForExistence(timeout: 3))
    let nextExercise = app.buttons["next-exercise-Bench Press"]
    XCTAssertTrue(waitForHittable(nextExercise))
    nextExercise.tap()
    XCTAssertTrue(app.buttons["workout-exercise-menu"].waitForExistence(timeout: 3))
    let skip = app.buttons["Skip"]
    XCTAssertTrue(skip.waitForExistence(timeout: 3))
    XCTAssertTrue(skip.isHittable)
    XCTAssertGreaterThanOrEqual(skip.frame.width, 44)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "rest-timer-full-skip-label"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    skip.tap()
    XCTAssertTrue(skip.waitForNonExistence(timeout: 3))
    XCTAssertFalse(app.otherElements["live-workout-header"].exists)
  }

  func testTimedExerciseCountdownStartsStopsAndConvertsMinutes() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutOnePersonFixture",
      "-activeWorkoutTimedSecondsFixture", "-activeWorkoutNavigationFixture", "-restTimerFixture",
    ]
    app.launch()

    app.buttons.matching(
      NSPredicate(
        format: "identifier == %@ AND label == %@", "participant-set-Alex-1",
        "Complete Bench Press set 1")
    ).firstMatch.tap()
    let skipRest = app.buttons["Skip"]
    XCTAssertTrue(skipRest.waitForExistence(timeout: 3))
    let secondsStart = app.buttons["start-exercise-timer-Bench Press"]
    XCTAssertTrue(secondsStart.waitForExistence(timeout: 5))
    XCTAssertTrue(secondsStart.label.contains("45 sec"), secondsStart.label)
    secondsStart.tap()
    let preRoll = app.staticTexts["exercise-timer-preroll"]
    XCTAssertTrue(preRoll.waitForExistence(timeout: 3), app.debugDescription)
    XCTAssertTrue(app.buttons["Cancel exercise timer countdown"].isHittable)
    app.buttons["Cancel exercise timer countdown"].tap()
    XCTAssertTrue(preRoll.waitForNonExistence(timeout: 3))
    let timerText = app.staticTexts["exercise-countdown"]
    XCTAssertFalse(timerText.exists)
    XCTAssertTrue(skipRest.exists)

    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutOnePersonFixture",
      "-activeWorkoutTimedMinutesFixture",
    ]
    app.launch()
    let minutesStart = app.buttons["start-exercise-timer-Bench Press"]
    XCTAssertTrue(minutesStart.waitForExistence(timeout: 5))
    XCTAssertTrue(minutesStart.label.contains("2 min"))
    minutesStart.tap()
    XCTAssertTrue(app.staticTexts["exercise-timer-preroll"].waitForExistence(timeout: 3))
    let minutesTimerText = app.staticTexts["exercise-countdown"]
    XCTAssertTrue(minutesTimerText.waitForExistence(timeout: 8), app.debugDescription)
    let minutesTimerValue = minutesTimerText.value as? String ?? ""
    XCTAssertTrue(
      minutesTimerValue.contains("2:00") || minutesTimerValue.contains("1:59"),
      minutesTimerText.debugDescription)
    let stop = app.buttons["stop-exercise-timer"]
    XCTAssertTrue(stop.isHittable)
    stop.tap()
    XCTAssertTrue(minutesTimerText.waitForNonExistence(timeout: 3))
  }

  func testTimedExerciseExpiryCompletesOneSetAndStartsRest() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutOnePersonFixture",
      "-activeWorkoutTimedSecondsFixture", "-restTimerFixture",
      "-exerciseTimerShortExpiryFixture",
    ]
    app.launch()

    app.buttons["start-exercise-timer-Bench Press"].tap()
    XCTAssertTrue(app.staticTexts["exercise-timer-preroll"].waitForExistence(timeout: 3))
    let timerText = app.staticTexts["exercise-countdown"]
    XCTAssertTrue(timerText.waitForExistence(timeout: 8), app.debugDescription)
    let firstSet = app.buttons["participant-set-Alex-1"]
    let firstSetCompleted = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Remove completed Bench Press set 1"),
      object: firstSet)
    XCTAssertEqual(XCTWaiter.wait(for: [firstSetCompleted], timeout: 8), .completed)
    XCTAssertEqual(app.buttons["participant-set-Alex-2"].label, "Complete Bench Press set 2")
    XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 3))
  }

  func testManualSetCompletionDuringTimerPreRollCancelsTimer() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutOnePersonFixture",
      "-activeWorkoutTimedSecondsFixture",
    ]
    app.launch()

    app.buttons["start-exercise-timer-Bench Press"].tap()
    let preRoll = app.staticTexts["exercise-timer-preroll"]
    XCTAssertTrue(preRoll.waitForExistence(timeout: 3))
    let firstSet = app.buttons["participant-set-Alex-1"]
    XCTAssertTrue(firstSet.isHittable)
    firstSet.tap()
    XCTAssertTrue(preRoll.waitForNonExistence(timeout: 3))
    XCTAssertEqual(firstSet.label, "Remove completed Bench Press set 1")
    XCTAssertEqual(app.buttons["participant-set-Alex-2"].label, "Complete Bench Press set 2")
    XCTAssertFalse(app.staticTexts["exercise-countdown"].exists)
  }

  func testExerciseFilterMenuOrdersCustomAfterAllAndExcludesCatalogExercises() {
    app.tabBars.buttons["Exercises"].tap()
    let filterMenu = app.buttons["exercise-filter-menu"]
    XCTAssertTrue(filterMenu.waitForExistence(timeout: 5))
    filterMenu.tap()

    let allFilter = app.buttons["All"]
    let customFilter = app.buttons["Custom"]
    XCTAssertTrue(allFilter.waitForExistence(timeout: 2))
    XCTAssertTrue(customFilter.exists)
    XCTAssertLessThan(allFilter.frame.minY, customFilter.frame.minY)

    customFilter.tap()
    XCTAssertTrue(app.buttons["exercise-Fixture Custom Curl"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["exercise-Bench Press"].exists)
    XCTAssertFalse(app.buttons["exercise-Barbell Back Squat"].exists)
  }

  func testRenameAndDuplicateExercisePreserveOriginalIdentity() {
    app.tabBars.buttons["Exercises"].tap()
    let originalRow = app.buttons["exercise-Bench Press"]
    XCTAssertTrue(originalRow.waitForExistence(timeout: 5))
    originalRow.tap()

    changeRepCounting(to: "Per side")

    let editButton = app.buttons["Edit"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 3))
    editButton.tap()
    XCTAssertTrue(app.navigationBars["Edit Exercise"].waitForExistence(timeout: 2))

    let nameField = app.textFields["exercise-name-field"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 2))
    nameField.tap()
    nameField.typeText(
      Array(repeating: XCUIKeyboardKey.delete.rawValue, count: 30).joined())
    nameField.typeText("Chest Press")
    app.buttons["Save"].tap()

    XCTAssertTrue(app.staticTexts["Chest Press"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Originally Bench Press"].exists)

    let moreButton = app.buttons["More"]
    XCTAssertTrue(moreButton.exists)
    moreButton.tap()
    app.buttons["Duplicate Exercise"].tap()
    XCTAssertTrue(app.navigationBars["Duplicate Exercise"].waitForExistence(timeout: 2))
    XCTAssertEqual(app.textFields["exercise-name-field"].value as? String, "Chest Press Copy")
    app.buttons["Save"].tap()

    app.navigationBars.buttons.element(boundBy: 0).tap()
    let duplicateRow = app.buttons["exercise-Chest Press Copy"]
    XCTAssertTrue(duplicateRow.waitForExistence(timeout: 3))
    duplicateRow.tap()
    XCTAssertTrue(app.staticTexts["Duplicate of Bench Press"].waitForExistence(timeout: 3))
    XCTAssertEqual(
      app.descendants(matching: .any).matching(identifier: "exercise-rep-counting").firstMatch.value
        as? String,
      "Per side")

    app.tabBars.buttons["Routines"].tap()
    let routine = app.staticTexts["Basic Workout"]
    XCTAssertTrue(routine.waitForExistence(timeout: 3))
    routine.tap()
    XCTAssertTrue(app.staticTexts["Chest Press"].waitForExistence(timeout: 3))
  }

  func testStartCloseAndResumeActiveWorkout() {
    let startButton = app.buttons["start-routine-Basic Workout"]
    XCTAssertTrue(startButton.waitForExistence(timeout: 5))
    startButton.tap()

    let closeButton = app.buttons["close-active-workout"]
    XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    XCTAssertLessThan(closeButton.frame.midX, app.frame.midX)
    XCTAssertTrue(app.navigationBars["Bench Press"].exists)

    closeButton.tap()

    let resumeButton = app.buttons["resume-active-workout"]
    XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
    resumeButton.tap()

    XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Bench Press"].exists)
  }

  func testRapidRepEditPersistsWhenWorkoutCloses() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    let reps = app.textFields["Base reps for Alex"]
    XCTAssertTrue(reps.waitForExistence(timeout: 5))
    app.buttons["base-reps-plus-Alex"].tap()
    XCTAssertEqual(reps.value as? String, "9")

    app.buttons["close-active-workout"].tap()
    let resume = app.buttons["resume-active-workout"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    resume.tap()

    XCTAssertTrue(reps.waitForExistence(timeout: 5))
    XCTAssertEqual(reps.value as? String, "9")
  }

  func testSameExerciseHistorySeedsAcrossRoutinesPerPerson() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-crossRoutineHistoryFixture", "-activeWorkoutFixture",
      "-activeWorkoutTwoPersonFixture",
    ]
    app.launch()

    let alexWeight = app.textFields["Pounds for Alex"]
    let alexReps = app.textFields["Base reps for Alex"]
    let jordanWeight = app.textFields["Pounds for Jordan"]
    let jordanReps = app.textFields["Base reps for Jordan"]
    XCTAssertTrue(alexWeight.waitForExistence(timeout: 5))
    XCTAssertTrue(alexReps.exists)
    XCTAssertTrue(jordanWeight.exists)
    XCTAssertTrue(jordanReps.exists)
    XCTAssertEqual(alexWeight.value as? String, "140")
    XCTAssertEqual(alexReps.value as? String, "6")
    XCTAssertEqual(jordanWeight.value as? String, "80")
    XCTAssertEqual(jordanReps.value as? String, "10")
    XCTAssertTrue(app.buttons["participant-set-Alex-2"].exists)
    XCTAssertTrue(app.buttons["participant-set-Jordan-2"].exists)
    XCTAssertFalse(app.buttons["participant-set-Alex-3"].exists)
    XCTAssertFalse(app.buttons["participant-set-Jordan-3"].exists)
  }

  func testLoadAndRepValuesHighlightWhenChangedFromLatestExerciseHistory() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-crossRoutineHistoryFixture", "-activeWorkoutFixture",
      "-activeWorkoutTwoPersonFixture",
    ]
    app.launch()

    let alexWeight = app.textFields["Pounds for Alex"]
    let alexReps = app.textFields["Base reps for Alex"]
    let jordanWeight = app.textFields["Pounds for Jordan"]
    let jordanReps = app.textFields["Base reps for Jordan"]
    XCTAssertTrue(alexWeight.waitForExistence(timeout: 5))
    XCTAssertTrue(jordanWeight.exists)
    XCTAssertTrue(jordanReps.exists)
    XCTAssertEqual(alexWeight.value as? String, "140")
    XCTAssertEqual(alexReps.value as? String, "6")
    XCTAssertFalse(app.textFields["measurement-value-Alex-updated"].exists)
    XCTAssertFalse(app.textFields["base-reps-value-Alex-updated"].exists)

    app.buttons["measurement-plus-Alex"].tap()
    XCTAssertEqual(alexWeight.value as? String, "145")
    XCTAssertTrue(app.textFields["measurement-value-Alex-updated"].exists)
    XCTAssertFalse(app.textFields["base-reps-value-Alex-updated"].exists)
    XCTAssertFalse(app.textFields["measurement-value-Jordan-updated"].exists)

    app.buttons["base-reps-plus-Alex"].tap()
    XCTAssertEqual(alexReps.value as? String, "7")
    XCTAssertTrue(app.textFields["base-reps-value-Alex-updated"].exists)
    XCTAssertTrue(app.textFields["measurement-value-Alex-updated"].exists)
    XCTAssertFalse(app.textFields["base-reps-value-Jordan-updated"].exists)

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "active-workout-values-changed-from-history"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    app.buttons["measurement-minus-Alex"].tap()
    XCTAssertEqual(alexWeight.value as? String, "140")
    XCTAssertFalse(app.textFields["measurement-value-Alex-updated"].exists)
    app.buttons["base-reps-minus-Alex"].tap()
    XCTAssertEqual(alexReps.value as? String, "6")
    XCTAssertFalse(app.textFields["base-reps-value-Alex-updated"].exists)
  }

  func testLegacyIDLessExerciseHistorySeedsAcrossRoutines() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-crossRoutineLegacyHistoryFixture", "-activeWorkoutFixture",
      "-activeWorkoutOnePersonFixture",
    ]
    app.launch()

    let weight = app.textFields["Pounds for Alex"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "150")
    XCTAssertEqual(app.textFields["Base reps for Alex"].value as? String, "7")
  }

  func testCrossRoutineHistoryWithoutCompletedSetsUsesDefaults() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-crossRoutineUncompletedHistoryFixture", "-activeWorkoutFixture",
      "-activeWorkoutOnePersonFixture",
    ]
    app.launch()

    let weight = app.textFields["Pounds for Alex"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "160")
    XCTAssertEqual(app.textFields["Base reps for Alex"].value as? String, "8")
    XCTAssertTrue(app.buttons["participant-set-Alex-3"].exists)
    XCTAssertFalse(app.buttons["participant-set-Alex-4"].exists)
  }

  func testWeightControlsJumpToStandardSizes() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    let weight = app.textFields["Pounds for Alex"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "100")

    app.buttons["measurement-plus-Alex"].tap()
    XCTAssertEqual(weight.value as? String, "105")
    app.buttons["measurement-minus-Alex"].tap()
    XCTAssertEqual(weight.value as? String, "100")

    weight.tap()
    weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "22.5")
    XCTAssertEqual(weight.value as? String, "22.5")
    app.buttons["Increase value"].tap()
    XCTAssertEqual(weight.value as? String, "25")
    app.buttons["Decrease value"].tap()
    XCTAssertEqual(weight.value as? String, "20")

    app.buttons["Hide keyboard"].tap()
    app.buttons["exercise-details-Bench Press"].tap()
    changeExerciseUnit(to: "Weight (kg) + reps")
    app.navigationBars.buttons.element(boundBy: 0).tap()

    let kilograms = app.textFields["Kilograms for Alex"]
    XCTAssertTrue(kilograms.waitForExistence(timeout: 5))
    XCTAssertEqual(kilograms.value as? String, "20")
    app.buttons["measurement-plus-Alex"].tap()
    XCTAssertEqual(kilograms.value as? String, "22.5")
    app.buttons["measurement-minus-Alex"].tap()
    XCTAssertEqual(kilograms.value as? String, "20")

    kilograms.tap()
    kilograms.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "11")
    app.buttons["Increase value"].tap()
    XCTAssertEqual(kilograms.value as? String, "12.5")
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "weight-stepping-keyboard-fractional-kg"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["Decrease value"].tap()
    XCTAssertEqual(kilograms.value as? String, "10")
    app.buttons["Hide keyboard"].tap()

    app.buttons["close-active-workout"].tap()
    let resume = app.buttons["resume-active-workout"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    resume.tap()
    XCTAssertTrue(kilograms.waitForExistence(timeout: 5))
    XCTAssertEqual(kilograms.value as? String, "10")
  }

  func testPlankDefaultsAndMasterUnitEditingDuringWorkout() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-plankWorkoutFixture", "-validatePersistenceFixture",
    ]
    app.launch()

    let seconds = app.textFields["Base sec for Alex"]
    XCTAssertTrue(seconds.waitForExistence(timeout: 5))
    XCTAssertEqual(seconds.value as? String, "60")
    XCTAssertFalse(app.textFields["Base reps for Alex"].exists)
    app.buttons["exercise-details-Plank"].tap()
    changeExerciseUnit(to: "Reps only")
    app.navigationBars.buttons.element(boundBy: 0).tap()

    let reps = app.textFields["Base reps for Alex"]
    XCTAssertTrue(reps.waitForExistence(timeout: 5))
    XCTAssertEqual(reps.value as? String, "60")
    app.buttons["exercise-details-Plank"].tap()
    changeExerciseUnit(to: "Time in seconds")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(seconds.waitForExistence(timeout: 5))
    XCTAssertEqual(seconds.value as? String, "60")
    app.buttons["base-reps-plus-Alex"].tap()
    XCTAssertEqual(seconds.value as? String, "61")
    app.buttons["last-set-menu-Alex"].tap()
    app.buttons["Customize Last Set…"].tap()
    let lastSetSeconds = app.textFields["Last set sec for Plank"]
    XCTAssertTrue(lastSetSeconds.waitForExistence(timeout: 3))
    XCTAssertEqual(lastSetSeconds.value as? String, "61")
    app.buttons["Done"].tap()
    app.buttons["close-active-workout"].tap()
    app.buttons["resume-active-workout"].tap()
    XCTAssertTrue(seconds.waitForExistence(timeout: 5))
    XCTAssertEqual(seconds.value as? String, "61")
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "plank-seconds-after-master-unit-edit"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testLibraryUnitEditUpdatesResumedWorkout() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()
    app.buttons["close-active-workout"].tap()
    app.tabBars.buttons["Exercises"].tap()
    app.buttons["exercise-Bench Press"].tap()
    changeExerciseUnit(to: "Time in seconds")
    app.tabBars.buttons["Workout"].tap()
    app.buttons["resume-active-workout"].tap()

    let seconds = app.textFields["Base sec for Alex"]
    XCTAssertTrue(seconds.waitForExistence(timeout: 5))
    XCTAssertEqual(seconds.value as? String, "8")
    XCTAssertFalse(app.textFields["Pounds for Alex"].exists)
    XCTAssertFalse(app.textFields["Base reps for Alex"].exists)
  }

  func testRepCountingUpdatesRunningWorkout() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-repCountingWorkoutFixture", "-validatePersistenceFixture",
    ]
    app.launch()
    let perSide = app.textFields["Base reps/side for Alex"]
    XCTAssertTrue(perSide.waitForExistence(timeout: 5))
    XCTAssertTrue(app.textFields["Base reps/side for Jordan"].exists)
    XCTAssertEqual(perSide.value as? String, "8")
    app.buttons["base-reps-minus-Alex"].tap()
    XCTAssertEqual(perSide.value as? String, "7")  // Odd counts are valid on each side.
    app.buttons["participant-set-Alex-1"].tap()
    XCTAssertEqual(
      app.buttons["participant-set-Alex-1"].label, "Remove completed Cable Russian Twists set 1")
    app.buttons["last-set-menu-Alex"].tap()
    app.buttons["Customize Last Set…"].tap()
    XCTAssertTrue(
      app.textFields["Last set reps/side for Cable Russian Twists"].waitForExistence(timeout: 3))
    app.buttons["Done"].tap()

    // Tapping the name edits the one master, without closing/recreating the workout.
    app.buttons["exercise-details-Cable Russian Twists"].tap()
    changeRepCounting(to: "Standard")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let standard = app.textFields["Base reps for Alex"]
    XCTAssertTrue(standard.waitForExistence(timeout: 5))
    XCTAssertEqual(standard.value as? String, "7")
    XCTAssertTrue(app.textFields["Base reps for Jordan"].exists)
    XCTAssertEqual(
      app.buttons["participant-set-Alex-1"].label, "Remove completed Cable Russian Twists set 1")

    // Editing from the library also updates the resumed workout.
    app.buttons["close-active-workout"].tap()
    app.tabBars.buttons["Exercises"].tap()
    app.buttons["exercise-Cable Russian Twists"].tap()
    changeRepCounting(to: "Per side")
    app.tabBars.buttons["Workout"].tap()
    app.buttons["resume-active-workout"].tap()
    XCTAssertTrue(perSide.waitForExistence(timeout: 5))
    XCTAssertEqual(perSide.value as? String, "7")
    XCTAssertEqual(
      app.buttons["participant-set-Alex-1"].label, "Remove completed Cable Russian Twists set 1")
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "per-side-after-master-edit"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testSideTotalRepReminderTogglesForEveryParticipantWithoutChangingTotal() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-sideTotalRepsWorkoutFixture"]
    app.launch()

    let alexReps = app.textFields["Base total reps for Alex"]
    let jordanReps = app.textFields["Base total reps for Jordan"]
    let alexReminder = app.buttons["side-total-reps-reminder-Alex"]
    let jordanReminder = app.buttons["side-total-reps-reminder-Jordan"]
    XCTAssertTrue(alexReps.waitForExistence(timeout: 5))
    XCTAssertEqual(alexReps.value as? String, "24")
    XCTAssertEqual(jordanReps.value as? String, "24")
    XCTAssertTrue(alexReminder.label.contains("24 total reps, both sides"))

    alexReminder.tap()
    XCTAssertTrue(alexReminder.label.contains("12 reps each side"))
    XCTAssertTrue(jordanReminder.label.contains("12 reps each side"))
    XCTAssertEqual(alexReps.value as? String, "24")
    XCTAssertEqual(jordanReps.value as? String, "24")

    jordanReminder.tap()
    XCTAssertTrue(alexReminder.label.contains("24 total reps, both sides"))
    XCTAssertTrue(jordanReminder.label.contains("24 total reps, both sides"))
    XCTAssertEqual(alexReps.value as? String, "24")
    XCTAssertEqual(jordanReps.value as? String, "24")

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "side-total-reps-reminder-in-simulator"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    app.buttons["exercise-details-Cable Russian Twists"].tap()
    app.buttons["Edit"].tap()
    let reminderSetting = app.switches["exercise-side-total-reps-reminder-toggle"]
    XCTAssertTrue(reminderSetting.waitForExistence(timeout: 3))
    XCTAssertEqual(reminderSetting.value as? String, "1")
    app.swipeUp()
    reminderSetting.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    XCTAssertEqual(reminderSetting.value as? String, "0")
    app.buttons["Save"].tap()
    app.buttons["Edit"].tap()
    XCTAssertEqual(
      app.switches["exercise-side-total-reps-reminder-toggle"].value as? String, "0")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.textFields["Base reps for Alex"].waitForExistence(timeout: 5))
    XCTAssertFalse(alexReminder.exists)

    app.buttons["exercise-details-Cable Russian Twists"].tap()
    app.buttons["Edit"].tap()
    app.swipeUp()
    app.switches["exercise-side-total-reps-reminder-toggle"]
      .coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    app.buttons["Save"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.textFields["Base total reps for Alex"].waitForExistence(timeout: 5))
    XCTAssertTrue(alexReminder.waitForExistence(timeout: 3))
    XCTAssertEqual(alexReps.value as? String, "24")
  }

  private func changeRepCounting(to title: String) {
    let edit = app.buttons["Edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
    edit.tap()
    app.buttons["exercise-rep-counting-picker"].tap()
    app.buttons[title].tap()
    app.buttons["Save"].tap()
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
  }

  private func changeExerciseUnit(to title: String) {
    let edit = app.buttons["Edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
    edit.tap()
    app.buttons["exercise-unit-picker"].tap()
    app.buttons[title].tap()
    app.buttons["Save"].tap()
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
  }

  private func changeDumbbellReminder(to isEnabled: Bool, screenshotName: String? = nil) {
    let edit = app.buttons["Edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
    edit.tap()
    let reminderToggle = app.switches["exercise-dumbbell-reminder-toggle"]
    XCTAssertTrue(reminderToggle.waitForExistence(timeout: 3))
    let currentValue = reminderToggle.value as? String == "1"
    if currentValue != isEnabled {
      reminderToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }
    XCTAssertEqual(reminderToggle.value as? String, isEnabled ? "1" : "0")
    if let screenshotName {
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = screenshotName
      screenshot.lifetime = .keepAlways
      add(screenshot)
    }
    app.buttons["Save"].tap()
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
  }

  func testCompletingWorkoutShowsCelebrationSummary() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-celebrationFormattingFixture",
    ]
    app.launch()

    for name in ["Alex", "Jordan", "Owen"] {
      let set = app.buttons["participant-set-\(name)-1"]
      XCTAssertTrue(set.waitForExistence(timeout: 5))
      set.tap()
    }
    app.buttons["Complete Workout"].tap()

    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["THIS WORKOUT"].exists)
    XCTAssertTrue(app.staticTexts["10,880 lb"].exists)
    XCTAssertTrue(app.staticTexts["10,000 lb"].exists)
    XCTAssertTrue(app.staticTexts["10,000 lb·reps"].exists)
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertTrue(app.staticTexts[name.capitalized].waitForExistence(timeout: 5))
    }
    app.scrollViews.firstMatch.swipeUp()
    XCTAssertTrue(app.staticTexts["RECENT MOMENTUM · 4 WEEKS"].waitForExistence(timeout: 5))
    let recentVolume = app.staticTexts["workout-celebration-stat-volume"]
    XCTAssertTrue(recentVolume.label.contains(","))
    XCTAssertTrue(recentVolume.label.hasSuffix(" lb"))
    app.scrollViews.firstMatch.swipeUp()
    let recentAlexRow = app.descendants(matching: .any)["workout-celebration-recent-alex"]
    XCTAssertTrue(recentAlexRow.exists)
    XCTAssertTrue(recentAlexRow.label.contains(","))
    XCTAssertTrue(recentAlexRow.label.contains(" lb"))
    app.buttons["workout-celebration-done"].tap()
    XCTAssertTrue(app.buttons["start-routine-Basic Workout"].waitForExistence(timeout: 5))
  }

  func testWorkoutConfettiExpiresAndSummaryRemainsUsable() {
    showConfettiCelebration(arguments: ["-confettiSnapshotFixture"])
    keepCelebrationScreenshot(named: "workout-confetti-metal")

    // Capture the same summary after the overlay's finite lifetime, for visual comparison.
    Thread.sleep(forTimeInterval: 6)
    keepCelebrationScreenshot(named: "workout-confetti-finished")
    XCTAssertTrue(app.staticTexts["THIS WORKOUT"].exists)
    app.buttons["workout-celebration-done"].tap()
    XCTAssertTrue(app.buttons["start-routine-Basic Workout"].waitForExistence(timeout: 5))
  }

  func testWorkoutConfettiAllowsImmediateDismissal() {
    showConfettiCelebration(arguments: ["-confettiSnapshotFixture"])
    app.buttons["workout-celebration-done"].tap()
    XCTAssertTrue(app.buttons["start-routine-Basic Workout"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Workout complete"].exists)
  }

  func testWorkoutConfettiRespectsReduceMotion() {
    showConfettiCelebration(arguments: ["-confettiReduceMotionFixture"])
    keepCelebrationScreenshot(named: "workout-confetti-reduce-motion")
    XCTAssertTrue(app.staticTexts["THIS WORKOUT"].exists)
    app.buttons["workout-celebration-done"].tap()
    XCTAssertTrue(app.buttons["start-routine-Basic Workout"].waitForExistence(timeout: 5))
  }

  private func showConfettiCelebration(arguments: [String]) {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"] + arguments
    app.launch()
    for name in ["Alex", "Jordan", "Owen"] {
      let set = app.buttons["participant-set-\(name)-1"]
      XCTAssertTrue(set.waitForExistence(timeout: 5))
      set.tap()
    }
    app.buttons["Complete Workout"].tap()
    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
  }

  func testDeveloperMenuReplaysLatestCompletedWorkoutCelebration() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-recentCompletedWorkoutFixture", "-confettiSnapshotFixture",
    ]
    app.launch()
    openDeveloperMenu()

    // Reopening the same completed workout should launch a fresh burst each time.
    for replay in 1...2 {
      app.buttons["developer-preview-workout-celebration"].tap()
      XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts["Basic Workout"].exists)
      XCTAssertEqual(app.staticTexts["workout-celebration-stat-total-volume"].label, "760 lb")
      XCTAssertTrue(app.staticTexts["1 completed set"].exists)
      keepCelebrationScreenshot(named: "developer-workout-celebration-replay-\(replay)")
      app.buttons["Back to Developer Menu"].tap()
      XCTAssertTrue(
        app.buttons["developer-preview-workout-celebration"].waitForExistence(timeout: 5))
    }
  }

  func testDeveloperMenuCelebrationPreviewWithoutCompletedWorkout() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-emptyWorkoutHistoryFixture"]
    app.launch()
    openDeveloperMenu()
    app.buttons["developer-preview-workout-celebration"].tap()
    let notice = app.alerts["Workout Celebration"]
    XCTAssertTrue(notice.waitForExistence(timeout: 3))
    XCTAssertTrue(
      notice.staticTexts["Complete a workout first to preview its celebration."].exists)
    notice.buttons["OK"].tap()
    XCTAssertTrue(app.buttons["developer-preview-workout-celebration"].exists)
    XCTAssertFalse(app.staticTexts["Workout complete"].exists)
  }

  private func openDeveloperMenu() {
    app.tabBars.buttons["Settings"].tap()
    let menu = app.buttons["Developer Menu"]
    for _ in 0..<5 {
      if menu.isHittable { break }
      app.collectionViews.firstMatch.swipeUp()
    }
    XCTAssertTrue(menu.isHittable)
    menu.tap()
    XCTAssertTrue(
      app.buttons["developer-preview-workout-celebration"].waitForExistence(timeout: 5))
  }

  private func keepCelebrationScreenshot(named name: String) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testAddingExerciseToActiveWorkoutUpdatesRoutine() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 5))
    app.buttons["Add Exercise"].tap()

    let searchField = app.searchFields["Exercise name"]
    XCTAssertTrue(searchField.waitForExistence(timeout: 3))
    searchField.tap()
    searchField.typeText("Barbell Back Squat")

    let squat = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "Barbell Back Squat")
    ).firstMatch
    XCTAssertTrue(squat.waitForExistence(timeout: 3))
    squat.tap()

    XCTAssertTrue(app.buttons["next-exercise-Bench Press"].waitForExistence(timeout: 3))
    for name in ["Alex", "Jordan", "Owen"] {
      let set = firstHittableElement(
        in: app.buttons.matching(
          NSPredicate(format: "identifier == %@", "participant-set-\(name)-1")))
      XCTAssertNotNil(set)
      set?.tap()
    }
    let completeWorkout = app.buttons["Complete Workout"]
    for _ in 0..<5 {
      if completeWorkout.isHittable { break }
      app.collectionViews.firstMatch.swipeUp()
    }
    XCTAssertTrue(completeWorkout.isHittable)
    completeWorkout.tap()
    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
    app.buttons["workout-celebration-done"].tap()

    let startButton = app.buttons["start-routine-Basic Workout"]
    XCTAssertTrue(startButton.waitForExistence(timeout: 5))
    startButton.tap()
    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 5))

    let nextExercise = app.buttons["next-exercise-Bench Press"]
    XCTAssertTrue(nextExercise.waitForExistence(timeout: 3))
    nextExercise.tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 3))
  }

  func testWeightFieldInitializationPreservesSetOverrideAndPrecision() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-measurementOverrideFixture",
    ]
    app.launch()
    let weight = app.textFields["Pounds for Alex"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "95.1")
    app.buttons["participant-set-Alex-1"].tap()
    app.buttons["participant-set-Alex-2"].tap()
    app.buttons["Complete Workout"].tap()
    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
    // 123.5 × 8 + 95.06 × 8 = 1,748.48, displayed rounded to 1,748.5.
    // Reinitialization must preserve both the per-set override and the base precision.
    XCTAssertTrue(app.staticTexts["1,748.5 lb"].firstMatch.waitForExistence(timeout: 5))
  }

  func testCommittedBaseWeightClearsSetOverrides() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-measurementOverrideFixture",
    ]
    app.launch()

    let weight = app.textFields["Pounds for Alex"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "95.1")

    weight.tap()
    weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "120")
    XCTAssertEqual(weight.value as? String, "120")
    app.buttons["Hide keyboard"].tap()

    app.buttons["participant-set-Alex-1"].tap()
    app.buttons["participant-set-Alex-2"].tap()
    app.buttons["Complete Workout"].tap()
    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["1,920 lb"].firstMatch.waitForExistence(timeout: 5))
  }

  func testArmTotalReminderTogglesForAllParticipantsAcrossUnits() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-dumbbellLoadFixture",
      "-measurementOverrideFixture", "-validatePersistenceFixture",
    ]
    app.launch()

    let participantLoads = [
      app.textFields["Pounds for Alex"],
      app.textFields["Pounds for Jordan"],
      app.textFields["Pounds for Owen"],
    ]
    let alexLoad = participantLoads[0]
    for load in participantLoads {
      XCTAssertTrue(load.waitForExistence(timeout: 5))
    }
    let originalLoads = participantLoads.map { $0.value as? String }
    XCTAssertEqual(alexLoad.value as? String, "95.1")
    XCTAssertFalse(
      app.descendants(matching: .any).matching(identifier: "dumbbell-arm-count").firstMatch.exists
    )
    let alexCallout = app.descendants(matching: .any).matching(
      identifier: "arm-total-load-reminder-Alex"
    ).firstMatch
    let jordanCallout = app.descendants(matching: .any).matching(
      identifier: "arm-total-load-reminder-Jordan"
    ).firstMatch
    let owenCallout = app.descendants(matching: .any).matching(
      identifier: "arm-total-load-reminder-Owen"
    ).firstMatch
    XCTAssertEqual(
      alexCallout.label,
      "47.5 lb per arm"
    )
    for name in ["Alex", "Jordan", "Owen"] {
      let callout = app.descendants(matching: .any).matching(
        identifier: "arm-total-load-reminder-\(name)"
      ).firstMatch
      XCTAssertTrue(callout.waitForExistence(timeout: 3))
      XCTAssertTrue(callout.label.contains("per arm"))
      let unitLabel = app.staticTexts["measurement-unit-\(name)"]
      XCTAssertTrue(unitLabel.waitForExistence(timeout: 3))
      XCTAssertEqual(unitLabel.label, "lb")
    }
    alexCallout.tap()
    XCTAssertEqual(alexLoad.value as? String, "95.1")
    XCTAssertEqual(
      alexCallout.label,
      "95.1 lb total for both arms"
    )
    for callout in [alexCallout, jordanCallout, owenCallout] {
      XCTAssertTrue(callout.label.contains("total for both arms"))
    }
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "arm-total-reminders-switch-together"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    for (load, originalLoad) in zip(participantLoads, originalLoads) {
      XCTAssertEqual(load.value as? String, originalLoad)
    }
    jordanCallout.tap()
    for callout in [alexCallout, jordanCallout, owenCallout] {
      XCTAssertTrue(callout.label.contains("per arm"))
    }
    for (load, originalLoad) in zip(participantLoads, originalLoads) {
      XCTAssertEqual(load.value as? String, originalLoad)
    }
    XCTAssertEqual(
      alexCallout.label,
      "47.5 lb per arm"
    )

    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutOnePersonFixture",
      "-kilogramDumbbellLoadFixture",
    ]
    app.launch()
    let kilogramLoad = app.textFields["Kilograms for Alex"]
    XCTAssertTrue(kilogramLoad.waitForExistence(timeout: 5))
    let kilogramCallout = app.descendants(matching: .any).matching(
      identifier: "arm-total-load-reminder-Alex"
    ).firstMatch
    XCTAssertTrue(kilogramCallout.waitForExistence(timeout: 3))
    XCTAssertEqual(kilogramCallout.label, "50 kg per arm")
    kilogramCallout.tap()
    XCTAssertEqual(kilogramLoad.value as? String, "100")
    XCTAssertEqual(kilogramCallout.label, "100 kg total for both arms")
    XCTAssertEqual(app.staticTexts["measurement-unit-Alex"].label, "kg")

    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()
    XCTAssertTrue(app.textFields["Pounds for Alex"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["measurement-unit-Alex"].label, "lb")
    XCTAssertFalse(
      app.descendants(matching: .any).matching(identifier: "arm-total-load-reminder-Alex")
        .firstMatch
        .exists
    )
  }

  func testExerciseEditorControlsArmTotalReminderPerExercise() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    let alexLoad = app.textFields["Pounds for Alex"]
    XCTAssertTrue(alexLoad.waitForExistence(timeout: 5))
    let originalLoad = alexLoad.value as? String
    XCTAssertFalse(app.buttons["arm-total-load-reminder-Alex"].exists)

    app.buttons["exercise-details-Bench Press"].tap()
    changeDumbbellReminder(to: true, screenshotName: "exercise-arm-total-reminder-setting-enabled")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let alexReminder = app.buttons["arm-total-load-reminder-Alex"]
    XCTAssertTrue(alexReminder.waitForExistence(timeout: 3))
    XCTAssertEqual(alexLoad.value as? String, originalLoad)

    app.buttons["exercise-details-Bench Press"].tap()
    changeDumbbellReminder(to: false)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(alexReminder.waitForNonExistence(timeout: 3))
    XCTAssertEqual(alexLoad.value as? String, originalLoad)
  }

  func testActiveWorkoutScrollPerformance() {
    launchActiveWorkoutPerformanceFixture(scenario: "scroll")
    startPerformanceRestTimer()
    app.buttons["complete-one-set"].firstMatch.tap()
    XCTAssertTrue(app.buttons["Skip"].exists)
    // First pass warms image decoding and reusable rows; not part of the scroll window.
    app.swipeUp(velocity: .fast)
    app.swipeDown(velocity: .fast)
    app.buttons["profile-scroll-start"].tap()
    let options = XCTMeasureOptions()
    options.iterationCount = 5
    measure(
      metrics: [
        XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app),
        XCTStorageMetric(application: app),
        XCTOSSignpostMetric.scrollingAndDecelerationMetric,
      ], options: options
    ) {
      app.swipeUp(velocity: .fast)
      app.swipeDown(velocity: .fast)
    }
    app.buttons["profile-scroll-end"].tap()
    XCTAssertTrue(app.buttons["Skip"].exists)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "scroll-with-rest-timer"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testActiveWorkoutSustainedFlickTrace() {
    launchActiveWorkoutPerformanceFixture(scenario: "scroll-trace")
    startPerformanceRestTimer()

    // Leave a deterministic attachment window for an external Instruments trace.
    Thread.sleep(forTimeInterval: 5)
    for _ in 0..<4 {
      app.swipeUp(velocity: .fast)
      app.swipeDown(velocity: .fast)
    }
    Thread.sleep(forTimeInterval: 2)
    XCTAssertTrue(app.buttons["Skip"].exists)
  }

  func testActiveWorkoutButtonPerformance() {
    launchActiveWorkoutPerformanceFixture(scenario: "individual")
    startPerformanceRestTimer()
    let options = XCTMeasureOptions()
    options.iterationCount = 5
    options.invocationOptions = [.manuallyStop]
    measure(
      metrics: [
        XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app),
        XCTStorageMetric(application: app),
        XCTOSSignpostMetric(
          subsystem: "com.cseibert.StrengthLog.performance",
          category: "Workout", name: "SetCompletion"),
      ], options: options
    ) {
      let button = app.buttons["participant-set-Alex-2"].firstMatch
      button.tap()
      stopMeasuring()
      XCTAssertEqual(button.label, "Remove completed Bench Press set 2")
      button.tap()  // Undo outside the measurement; reset to the same visible button.
      XCTAssertEqual(button.label, "Complete Bench Press set 2")
    }
    XCTAssertTrue(app.buttons["Skip"].exists)
  }

  func testActiveWorkoutSharedSetCompletionPerformance() {
    launchActiveWorkoutPerformanceFixture(scenario: "shared")
    startPerformanceRestTimer()
    // Catch up the other participants before measuring equal-progress group completions.
    app.buttons["complete-one-set"].firstMatch.tap()
    let options = XCTMeasureOptions()
    options.iterationCount = 5
    options.invocationOptions = [.manuallyStop]
    measure(
      metrics: [
        XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app),
        XCTStorageMetric(application: app),
        XCTOSSignpostMetric(
          subsystem: "com.cseibert.StrengthLog.performance",
          category: "Workout", name: "SetCompletion"),
      ], options: options
    ) {
      app.buttons["complete-one-set"].firstMatch.tap()
      stopMeasuring()
      for name in ["Alex", "Jordan", "Owen"] {
        let button = app.buttons["participant-set-\(name)-2"].firstMatch
        XCTAssertEqual(button.label, "Remove completed Bench Press set 2")
        button.tap()  // Reset all three participants outside the measured interval.
      }
    }
    XCTAssertTrue(app.buttons["Skip"].exists)
  }

  func testRecentlyCompletedWorkoutCanBeResumedFromWorkoutScreen() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-recentCompletedWorkoutFixture"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Resume workout"].waitForExistence(timeout: 5))
    let resumeButton = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH 'resume-completed-workout-'")
    ).firstMatch
    XCTAssertTrue(resumeButton.waitForExistence(timeout: 3))
    XCTAssertTrue(resumeButton.label.contains("1 set completed"))
    XCTAssertFalse(resumeButton.label.contains(" of "))
    resumeButton.tap()

    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Bench Press"].exists)
  }

  func testThreePersonWorkoutMatrixAndSharedCompletion() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 5))
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertTrue(app.staticTexts[name].exists)
    }
    XCTAssertTrue(app.buttons["workout-exercise-menu"].exists)

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

  func testCompleteOneSetForEveryoneCatchesUpParticipants() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    let completeOneSet = app.buttons["complete-one-set"]
    XCTAssertTrue(completeOneSet.waitForExistence(timeout: 5))

    // Put one participant ahead, then use the shared action to catch up the others.
    app.buttons["participant-set-Alex-1"].tap()
    completeOneSet.tap()
    XCTAssertEqual(
      app.buttons["participant-set-Alex-2"].label,
      "Complete Bench Press set 2")
    for name in ["Jordan", "Owen"] {
      XCTAssertEqual(
        app.buttons["participant-set-\(name)-1"].label,
        "Remove completed Bench Press set 1")
    }

    // Once everyone is caught up, the next press advances everyone together.
    completeOneSet.tap()
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertEqual(
        app.buttons["participant-set-\(name)-2"].label,
        "Remove completed Bench Press set 2")
    }
  }

  func testParticipantWithCompletedSetsTogglesWithoutConfirmation() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    let alexSet = app.buttons["participant-set-Alex-1"]
    let alexPicker = app.buttons["participant-picker-Alex"]
    XCTAssertTrue(alexSet.waitForExistence(timeout: 5))
    alexSet.tap()

    alexPicker.tap()
    XCTAssertTrue(app.textFields["Base reps for Alex"].waitForNonExistence(timeout: 2))
    XCTAssertEqual(alexPicker.label, "Alex, excluded")
    XCTAssertFalse(app.buttons["Hide Person"].exists)
    XCTAssertLessThan(app.buttons["participant-picker-Jordan"].frame.minX, alexPicker.frame.minX)
    XCTAssertLessThan(app.buttons["participant-picker-Owen"].frame.minX, alexPicker.frame.minX)

    alexPicker.tap()
    XCTAssertTrue(alexSet.waitForExistence(timeout: 2))
    XCTAssertEqual(alexSet.label, "Remove completed Bench Press set 1")
  }

  func testSinglePersonWorkoutUsesHorizontalFullWidthCard() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture",
      "-activeWorkoutFixture",
      "-activeWorkoutOnePersonFixture",
      "-activeWorkoutNavigationFixture",
      "-activeWorkoutWrappingFixture",
    ]
    app.launch()

    let benchHistory = app.buttons["exercise-history-Bench Press"]
    let benchImages = app.buttons["exercise-images-Bench Press"]
    let load = firstHittableElement(
      in: app.textFields.matching(NSPredicate(format: "label == %@", "Pounds for Alex")))
    let reps = firstHittableElement(
      in: app.textFields.matching(NSPredicate(format: "label == %@", "Base reps for Alex")))
    let loadMinus = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "measurement-minus-Alex")))
    let firstSet = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "participant-set-Alex-1")))
    let eighthSet = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "participant-set-Alex-8")))
    let ninthSet = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "participant-set-Alex-9")))
    let tenthSet = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "participant-set-Alex-10")))
    let loadPlus = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "measurement-plus-Alex")))
    let repsMinus = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "base-reps-minus-Alex")))
    let setOptions = firstHittableElement(
      in: app.buttons.matching(
        NSPredicate(format: "identifier == %@", "last-set-menu-Alex")))
    XCTAssertTrue(benchHistory.waitForExistence(timeout: 5))
    XCTAssertTrue(benchImages.exists)
    XCTAssertNotNil(load)
    XCTAssertNotNil(reps)
    XCTAssertNotNil(loadMinus)
    XCTAssertNotNil(firstSet)
    XCTAssertNotNil(eighthSet)
    XCTAssertNotNil(ninthSet)
    XCTAssertNotNil(tenthSet)
    XCTAssertNotNil(loadPlus)
    XCTAssertNotNil(repsMinus)
    XCTAssertNotNil(setOptions)
    XCTAssertLessThan(abs((load?.frame.midY ?? 0) - (reps?.frame.midY ?? 0)), 2)
    XCTAssertLessThan(load?.frame.midX ?? 0, reps?.frame.midX ?? 0)
    XCTAssertLessThan(abs((firstSet?.frame.minX ?? 0) - (loadMinus?.frame.minX ?? 0)), 2)
    XCTAssertLessThan(abs((firstSet?.frame.midY ?? 0) - (eighthSet?.frame.midY ?? 0)), 2)
    XCTAssertGreaterThan(ninthSet?.frame.minY ?? 0, firstSet?.frame.maxY ?? 0)
    XCTAssertGreaterThanOrEqual(
      (repsMinus?.frame.minX ?? 0) - (loadPlus?.frame.maxX ?? 0), 0)
    XCTAssertLessThan(
      (repsMinus?.frame.minX ?? 0) - (loadPlus?.frame.maxX ?? 0), 20)
    XCTAssertGreaterThan(setOptions?.frame.minX ?? 0, tenthSet?.frame.maxX ?? 0)
    XCTAssertLessThan(abs((setOptions?.frame.midY ?? 0) - (ninthSet?.frame.midY ?? 0)), 2)

    app.buttons["next-exercise-Bench Press"].tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 2))
    RunLoop.current.run(until: Date().addingTimeInterval(0.7))
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].exists)
  }

  func testTwoPersonColumnsAndScrolledPillsShareHorizontalCenters() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture",
      "-activeWorkoutFixture",
      "-activeWorkoutTwoPersonFixture",
      "-activeWorkoutNavigationFixture",
      "-activeWorkoutLongNamesFixture",
    ]
    app.launch()

    let benchNext = app.buttons["next-exercise-Bench Press"]
    XCTAssertTrue(benchNext.waitForExistence(timeout: 5))
    benchNext.tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 5))
    let alexanderLoads = app.textFields.matching(
      NSPredicate(format: "label == %@", "Pounds for Alexander"))
    let danielleLoads = app.textFields.matching(
      NSPredicate(format: "label == %@", "Pounds for Danielle"))
    let alexanderLoad = (0..<alexanderLoads.count)
      .map { alexanderLoads.element(boundBy: $0) }
      .first(where: { $0.isHittable })
    let danielleLoad = (0..<danielleLoads.count)
      .map { danielleLoads.element(boundBy: $0) }
      .first(where: { $0.isHittable })
    XCTAssertNotNil(alexanderLoad)
    XCTAssertNotNil(danielleLoad)

    let alexanderPicker = app.buttons["participant-picker-Alexander"]
    let daniellePicker = app.buttons["participant-picker-Danielle"]
    let benjaminPicker = app.buttons["participant-picker-Benjamin"]
    XCTAssertTrue(alexanderPicker.exists)
    XCTAssertTrue(daniellePicker.exists)
    XCTAssertTrue(benjaminPicker.exists)
    XCTAssertLessThan(
      abs(alexanderPicker.frame.midX - (alexanderLoad?.frame.midX ?? 0)), 2)
    XCTAssertLessThan(
      abs(daniellePicker.frame.midX - (danielleLoad?.frame.midX ?? 0)), 2)
    XCTAssertGreaterThan(
      (danielleLoad?.frame.midX ?? 0) - (alexanderLoad?.frame.midX ?? 0), 140)
    XCTAssertGreaterThan(alexanderPicker.frame.width, 108)
    XCTAssertGreaterThan(benjaminPicker.frame.minX, app.frame.maxX - 48)
    XCTAssertLessThan(benjaminPicker.frame.minX, app.frame.maxX)
  }

  func testSetCompletionControlsWrapByParticipantCount() {
    assertSetWrap(
      extraArguments: ["-activeWorkoutOnePersonFixture"],
      person: "Alex",
      lastSetOnFirstRow: 8,
      firstSetOnNextRow: 9)
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
      person: "Alex",
      usesHorizontalSinglePersonLayout: true)
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

  func testExerciseMenuJumpsToAndMarksCurrentExercise() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture",
      "-activeWorkoutFixture",
      "-activeWorkoutNavigationFixture",
    ]
    app.launch()

    let benchNext = app.buttons["next-exercise-Bench Press"]
    let squatNext = app.buttons["next-exercise-Barbell Back Squat"]
    let exerciseMenu = app.buttons["workout-exercise-menu"]
    let alexPicker = app.buttons["participant-picker-Alex"]

    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 5))
    XCTAssertTrue(waitForHittable(benchNext))
    XCTAssertTrue(exerciseMenu.isHittable)
    XCTAssertTrue(alexPicker.isHittable)
    let initialCurrentExerciseScreenshot = XCTAttachment(screenshot: app.screenshot())
    initialCurrentExerciseScreenshot.name = "active-workout-current-exercise-bench-press"
    initialCurrentExerciseScreenshot.lifetime = .keepAlways
    add(initialCurrentExerciseScreenshot)

    exerciseMenu.tap()
    let benchItem = app.buttons["workout-exercise-menu-Bench Press"]
    let squatItem = app.buttons["workout-exercise-menu-Barbell Back Squat"]
    let customItem = app.buttons["workout-exercise-menu-Fixture Custom Curl"]
    XCTAssertTrue(benchItem.waitForExistence(timeout: 2))
    XCTAssertTrue(squatItem.exists)
    XCTAssertTrue(customItem.exists)
    XCTAssertTrue(benchItem.label.contains("Current exercise"), benchItem.label)
    XCTAssertLessThan(benchItem.frame.minY, squatItem.frame.minY)
    XCTAssertLessThan(squatItem.frame.minY, customItem.frame.minY)
    let menuScreenshot = XCTAttachment(screenshot: app.screenshot())
    menuScreenshot.name = "active-workout-exercise-menu-aligned-labels"
    menuScreenshot.lifetime = .keepAlways
    add(menuScreenshot)
    squatItem.tap()

    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 3))
    XCTAssertTrue(waitForHittable(squatNext))
    let changedCurrentExerciseScreenshot = XCTAttachment(screenshot: app.screenshot())
    changedCurrentExerciseScreenshot.name = "active-workout-current-exercise-barbell-back-squat"
    changedCurrentExerciseScreenshot.lifetime = .keepAlways
    add(changedCurrentExerciseScreenshot)
    XCTAssertTrue(exerciseMenu.isHittable)
    exerciseMenu.tap()
    XCTAssertTrue(
      app.buttons["workout-exercise-menu-Barbell Back Squat"].label.contains("Current exercise"))
    app.buttons["workout-exercise-menu-Fixture Custom Curl"].tap()
    XCTAssertTrue(app.navigationBars["Fixture Custom Curl"].waitForExistence(timeout: 3))
    XCTAssertTrue(waitForHittable(app.buttons["exercise-details-Fixture Custom Curl"]))

    exerciseMenu.tap()
    let selectedCustom = app.buttons["workout-exercise-menu-Fixture Custom Curl"]
    XCTAssertTrue(selectedCustom.label.contains("Current exercise"), selectedCustom.label)
    selectedCustom.tap()
    XCTAssertTrue(app.navigationBars["Fixture Custom Curl"].waitForExistence(timeout: 2))

    exerciseMenu.tap()
    app.buttons["workout-exercise-menu-Bench Press"].tap()
    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 3))

    XCTAssertTrue(waitForHittable(benchNext))
    benchNext.tap()
    XCTAssertTrue(app.navigationBars["Barbell Back Squat"].waitForExistence(timeout: 3))
    XCTAssertTrue(waitForHittable(squatNext))
    XCTAssertTrue(alexPicker.isHittable)
    let alexLoads = app.textFields.matching(
      NSPredicate(format: "label == %@", "Pounds for Alex"))
    let alexLoad = (0..<alexLoads.count)
      .map { alexLoads.element(boundBy: $0) }
      .first(where: { $0.isHittable })
    XCTAssertNotNil(alexLoad)
    XCTAssertLessThan(abs(alexPicker.frame.width - 108), 2)
    XCTAssertLessThan(abs(alexPicker.frame.midX - (alexLoad?.frame.midX ?? 0)), 2)
    squatNext.tap()
    XCTAssertTrue(app.navigationBars["Fixture Custom Curl"].waitForExistence(timeout: 3))
  }

  func testWorkoutReorderScreenSavesAndCancels() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutReorderFixture",
      "-validatePersistenceFixture", "-validateCoordinatedExerciseOrderOnly",
    ]
    app.launch()

    let completedSet = app.buttons["participant-set-Alex-1"].firstMatch
    XCTAssertTrue(completedSet.waitForExistence(timeout: 5))
    completedSet.tap()

    func openReorder() {
      let button = app.buttons["reorder-workout-exercises"]
      for _ in 0..<10 {
        if button.isHittable { break }
        app.collectionViews.firstMatch.swipeUp()
      }
      XCTAssertTrue(button.isHittable)
      button.tap()
      XCTAssertTrue(app.navigationBars["Reorder Exercises"].waitForExistence(timeout: 3))
    }

    func row(_ name: String) -> XCUIElement {
      app.descendants(matching: .any).matching(identifier: "reorder-exercise-\(name)").firstMatch
    }

    func moveCurlToTop() {
      let source = app.cells.containing(.any, identifier: "reorder-exercise-Fixture Custom Curl")
        .firstMatch
      let target = app.cells.containing(.any, identifier: "reorder-exercise-Bench Press").firstMatch
      source.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        .press(
          forDuration: 0.8,
          thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.2)))
      XCTAssertTrue(
        NSPredicate(format: "value == 'Position 1 of 3'").evaluate(
          with: row("Fixture Custom Curl")))
    }

    openReorder()
    for name in ["Bench Press", "Barbell Back Squat", "Fixture Custom Curl"] {
      XCTAssertTrue(row(name).isHittable)
    }
    XCTAssertFalse(app.textFields["Pounds for Alex"].exists)
    XCTAssertFalse(app.scrollViews["sticky-participant-picker"].exists)
    XCTAssertTrue(
      app.staticTexts[
        "Saved order applies to this workout and future workouts from this routine."
      ].exists)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "compact-workout-reorder"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    moveCurlToTop()
    app.buttons["cancel-workout-reorder"].tap()

    openReorder()
    XCTAssertEqual(row("Bench Press").value as? String, "Position 1 of 3")
    app.buttons["save-workout-reorder"].tap()
    openReorder()
    XCTAssertEqual(row("Bench Press").value as? String, "Position 1 of 3")
    moveCurlToTop()
    app.buttons["save-workout-reorder"].tap()
    app.buttons["close-active-workout"].tap()
    app.buttons["resume-active-workout"].tap()
    XCTAssertTrue(app.navigationBars["Fixture Custom Curl"].waitForExistence(timeout: 5))
    let next = app.buttons["next-exercise-Fixture Custom Curl"]
    XCTAssertTrue(waitForHittable(next))
    next.tap()
    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 3))
    let preservedSet = app.buttons.matching(
      NSPredicate(
        format: "identifier == %@ AND label == %@", "participant-set-Alex-1",
        "Remove completed Bench Press set 1")
    ).firstMatch
    XCTAssertTrue(preservedSet.waitForExistence(timeout: 3))

    let completeWorkout = app.buttons["Complete Workout"]
    for _ in 0..<8 {
      if completeWorkout.isHittable { break }
      app.collectionViews.firstMatch.swipeUp()
    }
    XCTAssertTrue(completeWorkout.isHittable)
    completeWorkout.tap()
    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
    app.buttons["workout-celebration-done"].tap()
    let startRoutine = app.buttons["start-routine-Basic Workout"]
    XCTAssertTrue(startRoutine.waitForExistence(timeout: 5))
    startRoutine.tap()
    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Fixture Custom Curl"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["next-exercise-Bench Press"].waitForExistence(timeout: 3))
  }

  func testCalendarOpensEveryWorkoutForSelectedDay() {
    let multiWorkoutDay = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "2 workouts")
    ).firstMatch
    XCTAssertTrue(multiWorkoutDay.waitForExistence(timeout: 5))
    XCTAssertEqual(
      multiWorkoutDay.value as? String,
      "Lower Body, Basic Workout; Multiple people; 5 personal records")
    multiWorkoutDay.tap()

    XCTAssertTrue(app.navigationBars["2 Workouts"].waitForExistence(timeout: 10))
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

  func testProgressUsesCompactDurationMenuAndPersonSeries() {
    app.tabBars.buttons["Progress"].tap()

    let rangeMenu = app.buttons["progress-range-menu"]
    XCTAssertTrue(rangeMenu.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Training volume"].exists)

    let progressScreenshot = XCTAttachment(screenshot: app.screenshot())
    progressScreenshot.name = "personal-records-progress"
    progressScreenshot.lifetime = .keepAlways
    add(progressScreenshot)

    rangeMenu.tap()

    XCTAssertTrue(app.buttons["12 weeks"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.buttons["1 year"].exists)
    XCTAssertFalse(app.buttons["4 weeks"].exists)
    XCTAssertFalse(app.buttons["All time"].exists)
    XCTAssertFalse(app.staticTexts["Person"].exists)
    XCTAssertFalse(app.staticTexts["Routine"].exists)
  }

  func testActiveWorkoutWeightedHistoryUsesPRScoreAndShowsSelectedSet() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-weightedHistoryCompetitionFixture", "-activeWorkoutFixture",
      "-activeWorkoutOnePersonFixture",
    ]
    app.launch()

    let historyButton = app.buttons["exercise-history-Bench Press"]
    XCTAssertTrue(historyButton.waitForExistence(timeout: 8))
    historyButton.tap()

    let chartTitle = app.staticTexts["lb·reps"]
    XCTAssertTrue(chartTitle.waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Pounds"].exists)
    XCTAssertFalse(app.staticTexts["Best reps"].exists)
    let chart = app.descendants(matching: .any)["exercise-history-chart-lb·reps"].firstMatch
    XCTAssertTrue(chart.waitForExistence(timeout: 3), app.debugDescription)
    XCTAssertTrue(chart.isHittable)
    let chartScreenshot = XCTAttachment(screenshot: app.screenshot())
    chartScreenshot.name = "active-workout-weighted-history-chart"
    chartScreenshot.lifetime = .keepAlways
    add(chartScreenshot)
    chart.coordinate(withNormalizedOffset: CGVector(dx: 0.49, dy: 0.15)).tap()

    let selectedPoint = app.staticTexts["exercise-history-selected-point"]
    XCTAssertTrue(selectedPoint.waitForExistence(timeout: 3), app.debugDescription)
    XCTAssertTrue(
      selectedPoint.label.contains("15 pounds, 12 reps"), selectedPoint.debugDescription)
    XCTAssertNotNil(
      selectedPoint.label.range(
        of: #"[A-Z][a-z]{2} \d{1,2}, \d{4}"#, options: .regularExpression),
      selectedPoint.debugDescription)

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "active-workout-weighted-history-selected-point"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    let initialSelection = selectedPoint.label
    let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.49, dy: 0.15))
    let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15))
    start.press(forDuration: 0.1, thenDragTo: end)
    XCTAssertNotEqual(selectedPoint.label, initialSelection)
    XCTAssertTrue(selectedPoint.label.contains("5 pounds, 8 reps"), selectedPoint.debugDescription)
  }

  func testPhoneHistoryFixtureCalendarPRBadgeAndDetails() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-prStickerPhoneFixture"]
    app.launch()
    let prDay = app.buttons.matching(
      NSPredicate(format: "value CONTAINS[c] %@", "personal record")
    ).firstMatch
    XCTAssertTrue(prDay.waitForExistence(timeout: 10))
    scrollToHittable(prDay)

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "phone-history-calendar-pr-badges"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    let isMultiWorkoutDay = prDay.label.localizedCaseInsensitiveContains("2 workouts")
    prDay.tap()
    if isMultiWorkoutDay {
      let workoutChoice = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "select-completed-workout-")
      ).firstMatch
      XCTAssertTrue(workoutChoice.waitForExistence(timeout: 5))
      workoutChoice.tap()
    }
    XCTAssertTrue(
      app.descendants(matching: .any)["day-workout-summary"].firstMatch.waitForExistence(
        timeout: 5)
    )
  }

  func testPhoneHistoryFixtureProgressUsesCombinedHistoryBadgesAndClearChart() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-prStickerPhoneFixture"]
    app.launch()
    app.tabBars.buttons["Progress"].tap()

    let chart = app.descendants(matching: .any)["progress-volume-chart"].firstMatch
    XCTAssertTrue(chart.waitForExistence(timeout: 10))
    let recordBadge = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] %@", "personal record")
    ).firstMatch
    XCTAssertTrue(recordBadge.waitForExistence(timeout: 5))
    XCTAssertFalse(chart.label.localizedCaseInsensitiveContains("personal record"))

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "phone-history-progress-pr-badges"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    app.buttons["progress-range-menu"].tap()
    app.buttons["1 year"].tap()
    XCTAssertTrue(recordBadge.waitForExistence(timeout: 5))
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
    XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2 workouts")).firstMatch
        .exists)
    let deletedWorkoutsButton = app.buttons["Deleted Workouts (1)"]
    XCTAssertTrue(deletedWorkoutsButton.waitForExistence(timeout: 10))
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

  private func launchActiveWorkoutPerformanceFixture(scenario: String = "trace") {
    app.terminate()
    app.launchArguments =
      [
        "-basicWorkoutFixture",
        "-activeWorkoutFixture",
        "-activeWorkoutPerformanceFixture",
        "-restTimerFixture",
        "-diskWorkoutPerformanceFixture",
        "-workoutPerformanceProbe",
      ]
    if ProcessInfo.processInfo.environment["WORKOUT_PROFILE_DENSE"] == "1" {
      app.launchArguments.append("-denseWorkoutPerformanceFixture")
    }
    app.launchEnvironment["WORKOUT_PROFILE_SCENARIO"] = scenario
    app.launchEnvironment["WORKOUT_PROFILE_HISTORY"] =
      ProcessInfo.processInfo.environment["WORKOUT_PROFILE_HISTORY"] ?? "48"
    app.launch()
    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 30))
  }

  private func startPerformanceRestTimer() {
    let firstSet = app.buttons["participant-set-Alex-1"].firstMatch
    XCTAssertTrue(firstSet.waitForExistence(timeout: 5))
    XCTAssertEqual(firstSet.label, "Complete Bench Press set 1")
    firstSet.tap()
    XCTAssertEqual(firstSet.label, "Remove completed Bench Press set 1")
    XCTAssertTrue(app.otherElements["live-workout-header"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Skip"].exists)
  }

  private func assertParticipantControlAlignment(
    extraArguments: [String],
    person: String,
    usesHorizontalSinglePersonLayout: Bool = false
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

    if usesHorizontalSinglePersonLayout {
      XCTAssertLessThan(abs(load.frame.midY - reps.frame.midY), 2)
      XCTAssertGreaterThan(repsMinus.frame.midX, loadMinus.frame.midX)
      XCTAssertLessThan(abs(firstSet.frame.minX - loadMinus.frame.minX), 2)
    } else {
      let setPairMidX = (firstSet.frame.midX + secondSet.frame.midX) / 2
      XCTAssertLessThan(abs(loadMinus.frame.midX - repsMinus.frame.midX), 2)
      XCTAssertLessThan(abs(load.frame.midX - reps.frame.midX), 2)
      XCTAssertLessThan(abs(reps.frame.midX - setPairMidX), 2)
    }
    return load.frame
  }

  func testRoutineExerciseVisibilitySavesCancelsAndRestores() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutReorderFixture"]
    app.launch()
    app.tabBars.buttons["Routines"].tap()
    app.staticTexts["Basic Workout"].tap()

    let manage = app.descendants(matching: .any)
      .matching(identifier: "manage-routine-exercises").firstMatch
    scrollToHittable(manage)
    manage.tap()
    XCTAssertTrue(app.navigationBars["Manage Exercises"].waitForExistence(timeout: 3))
    let curlToggle = app.buttons["toggle-routine-exercise-Fixture Custom Curl"]
    XCTAssertTrue(curlToggle.waitForExistence(timeout: 3))
    XCTAssertEqual(curlToggle.label, "Hide")
    app.buttons["cancel-manage-routine-exercises"].tap()
    XCTAssertTrue(app.staticTexts["Fixture Custom Curl"].waitForExistence(timeout: 3))

    scrollToHittable(manage)
    manage.tap()
    app.buttons["toggle-routine-exercise-Fixture Custom Curl"].tap()
    app.buttons["save-manage-routine-exercises"].tap()
    XCTAssertTrue(app.navigationBars["Basic Workout"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["Fixture Custom Curl"].exists)

    app.buttons["start-routine-detail"].tap()
    XCTAssertTrue(app.navigationBars["Bench Press"].waitForExistence(timeout: 5))
    let menu = app.buttons["workout-exercise-menu"]
    XCTAssertTrue(menu.waitForExistence(timeout: 3))
    menu.tap()
    XCTAssertTrue(app.buttons["workout-exercise-menu-Barbell Back Squat"].exists)
    XCTAssertFalse(app.buttons["workout-exercise-menu-Fixture Custom Curl"].exists)
  }

  func testHidingEveryRoutineExerciseKeepsUnhideAvailableAndDisablesStart() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutReorderFixture"]
    app.launch()
    app.tabBars.buttons["Routines"].tap()
    app.staticTexts["Basic Workout"].tap()
    let manage = app.descendants(matching: .any)
      .matching(identifier: "manage-routine-exercises").firstMatch
    scrollToHittable(manage)
    manage.tap()

    for name in ["Bench Press", "Barbell Back Squat", "Fixture Custom Curl"] {
      app.buttons["toggle-routine-exercise-\(name)"].tap()
    }
    app.buttons["save-manage-routine-exercises"].tap()

    XCTAssertFalse(app.staticTexts["Bench Press"].exists)
    XCTAssertFalse(app.buttons["start-routine-detail"].isEnabled)
    scrollToHittable(manage)
    manage.tap()
    for name in ["Bench Press", "Barbell Back Squat", "Fixture Custom Curl"] {
      XCTAssertEqual(app.buttons["toggle-routine-exercise-\(name)"].label, "Unhide")
    }
    app.buttons["toggle-routine-exercise-Bench Press"].tap()
    app.buttons["save-manage-routine-exercises"].tap()
    XCTAssertTrue(app.staticTexts["Bench Press"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["start-routine-detail"].isEnabled)
  }

  private func scrollToHittable(_ element: XCUIElement) {
    for _ in 0..<8 where !element.isHittable || element.frame.midY > app.frame.height * 0.72 {
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }

  private func firstHittableElement(in query: XCUIElementQuery) -> XCUIElement? {
    (0..<query.count)
      .map { query.element(boundBy: $0) }
      .first(where: \.isHittable)
  }

  private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"),
      object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }
}
