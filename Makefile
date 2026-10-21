PROJECT := StrengthLog.xcodeproj
SCHEME := StrengthLog
CONFIGURATION := Debug
DERIVED_DATA := build
APP_NAME := StrengthLog
BUNDLE_ID := com.cseibert.StrengthLog

SIM_DEVICE_NAME ?= iPhone 17 Pro
SIM_DESTINATION ?= platform=iOS Simulator,name=$(SIM_DEVICE_NAME)
SIMULATOR_APP ?= $(shell xcode-select -p)/Applications/Simulator.app
UI_TEST_FILTER ?= StrengthLogUITests
UI_DERIVED_DATA ?= build-ui-tests
GENERIC_SIM_DESTINATION := generic/platform=iOS Simulator

DEVICE_ID ?= 00008150-000E41422E40401C
WATCH_DEVICE_ID := 00008310-000A18983C40E01E
DEVELOPMENT_TEAM ?= 96NAC4VTEN

.PHONY: metal-setup watch-build watch-deploy confetti-ui-test workout-profile workout-profile-graph rep-counting-ui-test exercise-unit-ui-test exercise-timer-ui-test cross-routine-history-ui-test pr-sticker-ui-test progress-widget-check setup build run format lint test catalog-check exercise-images-check bundle-exercise-images hevy-import-check sim-build sim-launch workout-navigation-ui-test active-workout-regression-ui-test active-workout-performance-ui-test phone-build phone-install phone-launch phone-deploy clean

setup: catalog-check exercise-images-check

metal-setup:
	xcodebuild -downloadComponent MetalToolchain

build: sim-build

run: sim-launch

format:
	xcrun swift-format format --in-place --recursive StrengthLog StrengthLogUITests KidsWatch

lint: catalog-check exercise-images-check hevy-import-check
	plutil -lint $(PROJECT)/project.pbxproj
	xcrun swift-format lint --recursive StrengthLog StrengthLogUITests KidsWatch

test: catalog-check exercise-images-check progress-widget-check sim-build

progress-widget-check:
	@set -eu; \
	TEMP_DIR=$$(mktemp -d); \
	trap 'rm -rf "$$TEMP_DIR"' EXIT; \
	xcrun swiftc StrengthLog/ProgressWidgetShared.swift scripts/validate-progress-widget-snapshot.swift -o "$$TEMP_DIR/validate-progress-widget-snapshot"; \
	"$$TEMP_DIR/validate-progress-widget-snapshot"

catalog-check:
	@jq -e 'all(.[]; (.repCountingMode // "standard") as $$mode | ($$mode == "standard" or $$mode == "perSide") and (if $$mode == "perSide" then (.unit == "pounds" or .unit == "kilograms" or .unit == "repetitions") else true end))' StrengthLog/Resources/exercise-catalog.json >/dev/null
	@jq -e 'length == 873 and ([.[].imagePaths | length] | add) == 1746 and all(.[]; has("name") and has("unit") and has("instructions") and (.imagePaths | length == 2) and (if .unit == "seconds" then (.defaultDurationSeconds | type == "number" and . > 0 and . == floor) else (has("defaultDurationSeconds") | not) end))' StrengthLog/Resources/exercise-catalog.json >/dev/null
	@echo "Catalog OK: 873 exercises, 1,746 image references"

exercise-images-check:
	@./scripts/validate-exercise-images.sh

bundle-exercise-images:
	@./scripts/bundle-exercise-images.sh

hevy-import-check:
	@set -eu; \
	TEMP_DIR=$$(mktemp -d); \
	trap 'rm -rf "$$TEMP_DIR"' EXIT; \
	xcrun swiftc StrengthLog/HevyCSVParser.swift scripts/validate-hevy-import.swift -o "$$TEMP_DIR/validate-hevy-import"; \
	"$$TEMP_DIR/validate-hevy-import"

sim-build:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(GENERIC_SIM_DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  build

watch-build:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme KidsWatch \
	  -configuration $(CONFIGURATION) \
	  -destination 'generic/platform=watchOS Simulator' \
	  -derivedDataPath $(DERIVED_DATA) \
	  build

watch-deploy:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme KidsWatch \
	  -configuration $(CONFIGURATION) \
	  -destination 'platform=watchOS,id=$(WATCH_DEVICE_ID)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  CODE_SIGN_STYLE=Automatic \
	  DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
	  -allowProvisioningUpdates \
	  -allowProvisioningDeviceRegistration \
	  build
	xcrun devicectl device install app --device $(WATCH_DEVICE_ID) "$(DERIVED_DATA)/Build/Products/Debug-watchos/KidsWatch.app"
	xcrun devicectl device process launch --device $(WATCH_DEVICE_ID) com.cseibert.StrengthLog.KidsWatch

sim-launch: sim-build
	@set -eu; \
	UDID=$$(xcrun simctl list devices available | awk -F '[()]' -v name="$(SIM_DEVICE_NAME)" '{ display=$$1; sub(/^[[:space:]]+/, "", display); sub(/[[:space:]]+$$/, "", display); if (display == name && $$0 !~ /unavailable/) { print $$2; exit } }'); \
	if [ -z "$$UDID" ]; then \
	  echo "No available simulator named $(SIM_DEVICE_NAME)."; \
	  xcrun simctl list devices available; \
	  exit 1; \
	fi; \
	xcrun simctl boot "$$UDID" >/dev/null 2>&1 || true; \
	xcrun simctl bootstatus "$$UDID" -b; \
	  if [ -d "$(SIMULATOR_APP)" ]; then \
	    open -a "$(SIMULATOR_APP)" --args -CurrentDeviceUDID "$$UDID"; \
	  else \
	    echo "Simulator.app is not installed in this Xcode; continuing with simctl."; \
	  fi; \
	  xcrun simctl install "$$UDID" "$(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(APP_NAME).app"; \
	xcrun simctl launch "$$UDID" $(BUNDLE_ID)

rep-counting-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testRepCountingUpdatesRunningWorkout \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testRenameAndDuplicateExercisePreserveOriginalIdentity \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testPlankDefaultsAndMasterUnitEditingDuringWorkout \
	  test

confetti-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testWorkoutConfettiExpiresAndSummaryRemainsUsable \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testWorkoutConfettiAllowsImmediateDismissal \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testWorkoutConfettiRespectsReduceMotion \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testDeveloperMenuReplaysLatestCompletedWorkoutCelebration \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testDeveloperMenuCelebrationPreviewWithoutCompletedWorkout \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testCompletingWorkoutShowsCelebrationSummary \
	  test

workout-navigation-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:$(UI_TEST_FILTER) \
	  test

pr-sticker-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testPhoneHistoryFixtureCalendarPRBadgeAndDetails \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testPhoneHistoryFixtureProgressUsesCombinedHistoryBadgesAndClearChart \
	  test

exercise-unit-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testPlankDefaultsAndMasterUnitEditingDuringWorkout \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testLibraryUnitEditUpdatesResumedWorkout \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testRapidRepEditPersistsWhenWorkoutCloses \
	  test

exercise-timer-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testTimedExerciseCountdownStartsStopsAndConvertsMinutes \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testTimedExerciseExpiryCompletesOneSetAndStartsRest \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testManualSetCompletionDuringTimerPreRollCancelsTimer \
	  test

cross-routine-history-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testSameExerciseHistorySeedsAcrossRoutinesPerPerson \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testLoadAndRepValuesHighlightWhenChangedFromLatestExerciseHistory \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testLegacyIDLessExerciseHistorySeedsAcrossRoutines \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testCrossRoutineHistoryWithoutCompletedSetsUsesDefaults \
	  test

active-workout-regression-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testExerciseArrowNavigationTracksCurrentExercise \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testLiveWorkoutHeaderShowsRestTimer \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testRapidRepEditPersistsWhenWorkoutCloses \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testCompletingWorkoutShowsCelebrationSummary \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testRecentlyCompletedWorkoutCanBeResumedFromWorkoutScreen \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testSinglePersonWorkoutUsesHorizontalFullWidthCard \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testStartCloseAndResumeActiveWorkout \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testTwoPersonColumnsAndScrolledPillsShareHorizontalCenters \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testThreePersonWorkoutMatrixAndSharedCompletion \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testCompleteOneSetForEveryoneCatchesUpParticipants \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testSetCompletionControlsWrapByParticipantCount \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testParticipantStatusKeepsRepValuesAlignedAndMovesSetButtonsDown \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testTimedExerciseCountdownStartsStopsAndConvertsMinutes \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testWeightFieldInitializationPreservesSetOverrideAndPrecision \
	  test

PROFILE_DEVICE ?=
PROFILE_LABEL ?= working-tree
PROFILE_HISTORY ?= 48
PROFILE_DENSE ?= 0
PROFILE_RESULTS ?=

workout-profile:
	python3 scripts/workout-profile.py run --label "$(PROFILE_LABEL)" --history $(PROFILE_HISTORY) --dense $(PROFILE_DENSE) $(if $(PROFILE_DEVICE),--device $(PROFILE_DEVICE))

workout-profile-graph:
	python3 scripts/workout-profile.py graph

active-workout-performance-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO SWIFT_OPTIMIZATION_LEVEL=-O \
	  -parallel-testing-enabled NO \
	  -enableCodeCoverage NO \
	  $(if $(PROFILE_RESULTS),-resultBundlePath "$(PROFILE_RESULTS)") \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testActiveWorkoutScrollPerformance \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testActiveWorkoutButtonPerformance \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testActiveWorkoutSharedSetCompletionPerformance \
	  test

phone-build:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination 'platform=iOS,id=$(DEVICE_ID)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  CODE_SIGN_STYLE=Automatic \
	  DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) \
	  -allowProvisioningUpdates \
	  -allowProvisioningDeviceRegistration \
	  build

phone-install:
	xcrun devicectl device install app --device $(DEVICE_ID) "$(DERIVED_DATA)/Build/Products/Debug-iphoneos/$(APP_NAME).app"

phone-launch:
	xcrun devicectl device process launch --device $(DEVICE_ID) --terminate-existing $(BUNDLE_ID)

phone-deploy: phone-build phone-install phone-launch

clean:
	rm -rf "$(DERIVED_DATA)"
