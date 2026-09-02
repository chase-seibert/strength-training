PROJECT := StrengthLog.xcodeproj
SCHEME := StrengthLog
CONFIGURATION := Debug
DERIVED_DATA := build
APP_NAME := StrengthLog
BUNDLE_ID := com.cseibert.StrengthLog

SIM_DEVICE_NAME ?= iPhone 17 Pro
SIM_DESTINATION ?= platform=iOS Simulator,name=$(SIM_DEVICE_NAME)
UI_TEST_FILTER ?= StrengthLogUITests
UI_DERIVED_DATA ?= build-ui-tests
GENERIC_SIM_DESTINATION := generic/platform=iOS Simulator

DEVICE_ID ?= 00008150-000E41422E40401C
DEVELOPMENT_TEAM ?= 96NAC4VTEN

.PHONY: exercise-unit-ui-test setup build run format lint test catalog-check exercise-images-check bundle-exercise-images hevy-import-check sim-build sim-launch workout-navigation-ui-test active-workout-regression-ui-test active-workout-performance-ui-test phone-build phone-install phone-launch phone-deploy clean

setup: catalog-check exercise-images-check

build: sim-build

run: sim-launch

format:
	xcrun swift-format format --in-place --recursive StrengthLog StrengthLogUITests

lint: catalog-check exercise-images-check hevy-import-check
	plutil -lint $(PROJECT)/project.pbxproj
	xcrun swift-format lint --recursive StrengthLog StrengthLogUITests

test: catalog-check exercise-images-check sim-build

catalog-check:
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
	  CODE_SIGNING_ALLOWED=NO \
	  build

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
	open -a Simulator --args -CurrentDeviceUDID "$$UDID"; \
	xcrun simctl install "$$UDID" "$(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(APP_NAME).app"; \
	xcrun simctl launch "$$UDID" $(BUNDLE_ID)

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
	  test

active-workout-performance-ui-test:
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -configuration $(CONFIGURATION) \
	  -destination '$(SIM_DESTINATION)' \
	  -derivedDataPath $(UI_DERIVED_DATA) \
	  CODE_SIGNING_ALLOWED=NO \
	  -parallel-testing-enabled NO \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testActiveWorkoutScrollPerformance \
	  -only-testing:StrengthLogUITests/WorkoutNavigationUITests/testActiveWorkoutButtonPerformance \
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
