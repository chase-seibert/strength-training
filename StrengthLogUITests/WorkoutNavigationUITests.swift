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
    XCTAssertTrue(app.buttons["previous-exercise"].waitForExistence(timeout: 3))
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

  private func changeExerciseUnit(to title: String) {
    let edit = app.buttons["Edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
    edit.tap()
    app.buttons["exercise-unit-picker"].tap()
    app.buttons[title].tap()
    app.buttons["Save"].tap()
    XCTAssertTrue(edit.waitForExistence(timeout: 3))
  }

  func testCompletingWorkoutShowsCelebrationSummary() {
    app.terminate()
    app.launchArguments = ["-basicWorkoutFixture", "-activeWorkoutFixture"]
    app.launch()

    for name in ["Alex", "Jordan", "Owen"] {
      let set = app.buttons["participant-set-\(name)-1"]
      XCTAssertTrue(set.waitForExistence(timeout: 5))
      set.tap()
    }
    app.buttons["Complete Workout"].tap()

    XCTAssertTrue(app.staticTexts["Workout complete"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["THIS WORKOUT"].exists)
    for name in ["Alex", "Jordan", "Owen"] {
      XCTAssertTrue(app.staticTexts[name.capitalized].waitForExistence(timeout: 5))
    }
    app.scrollViews.firstMatch.swipeUp()
    XCTAssertTrue(app.staticTexts["RECENT MOMENTUM · 4 WEEKS"].waitForExistence(timeout: 5))
    app.buttons["workout-celebration-done"].tap()
    XCTAssertTrue(app.buttons["start-routine-Basic Workout"].waitForExistence(timeout: 5))
  }

  func testActiveWorkoutScrollPerformance() {
    launchActiveWorkoutPerformanceFixture()

    let options = XCTMeasureOptions()
    options.iterationCount = 5
    measure(
      metrics: [
        XCTClockMetric(),
        XCTCPUMetric(),
        XCTMemoryMetric(),
        XCTOSSignpostMetric.scrollDecelerationMetric,
      ],
      options: options
    ) {
      app.swipeUp(velocity: .fast)
      app.swipeDown(velocity: .fast)
    }
  }

  func testActiveWorkoutSustainedFlickTrace() {
    launchActiveWorkoutPerformanceFixture()

    // Leave a deterministic attachment window for an external Instruments trace.
    Thread.sleep(forTimeInterval: 5)
    for _ in 0..<4 {
      app.swipeUp(velocity: .fast)
      app.swipeDown(velocity: .fast)
    }
    Thread.sleep(forTimeInterval: 2)
  }

  func testActiveWorkoutButtonPerformance() {
    launchActiveWorkoutPerformanceFixture()
    let plus = app.buttons["base-reps-plus-Alex"].firstMatch
    let minus = app.buttons["base-reps-minus-Alex"].firstMatch
    XCTAssertTrue(plus.waitForExistence(timeout: 5))
    XCTAssertTrue(minus.exists)
    let plusCoordinate = plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let minusCoordinate = minus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

    let options = XCTMeasureOptions()
    options.iterationCount = 5
    measure(
      metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()],
      options: options
    ) {
      plusCoordinate.tap()
      minusCoordinate.tap()
    }
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
    let alexLoads = app.textFields.matching(
      NSPredicate(format: "label == %@", "Pounds for Alex"))
    let alexLoad = (0..<alexLoads.count)
      .map { alexLoads.element(boundBy: $0) }
      .first(where: { $0.isHittable })
    XCTAssertNotNil(alexLoad)
    XCTAssertLessThan(abs(alexPicker.frame.width - 108), 2)
    XCTAssertLessThan(abs(alexPicker.frame.midX - (alexLoad?.frame.midX ?? 0)), 2)

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

  func testWorkoutReorderScreenSavesAndCancels() {
    app.terminate()
    app.launchArguments = [
      "-basicWorkoutFixture", "-activeWorkoutFixture", "-activeWorkoutNavigationFixture",
      "-validatePersistenceFixture",
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
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "compact-workout-reorder"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    moveCurlToTop()
    app.buttons["cancel-workout-reorder"].tap()

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

  private func launchActiveWorkoutPerformanceFixture() {
    app.terminate()
    app.launchArguments =
      [
        "-basicWorkoutFixture",
        "-activeWorkoutFixture",
        "-activeWorkoutPerformanceFixture",
      ]
    app.launch()
    XCTAssertTrue(app.otherElements["active-workout-screen"].waitForExistence(timeout: 30))
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
