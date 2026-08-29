# Frustration log

## 2026-08-26 — Xcode tools fail inside the restricted shell sandbox

An ordinary simulator build reported missing CoreSimulator runtimes, and SwiftData macros failed with `swift-plugin-server produced malformed response`. The app code was not the cause: both `actool` and Swift macro plugins require access denied by the shell sandbox. Re-running `xcodebuild` with the approved Xcode project prefix outside that sandbox restored simulator services and produced a successful full build.

## 2026-08-26 — Repository metadata path is read-only

This workspace began without Git metadata, but the environment exposes the project `.git` path as read-only. `git init` therefore fails with `Operation not permitted`. Leave repository initialization to a session with write access to `.git`; do not try to work around it by creating metadata elsewhere.

## 2026-08-28 — Simulator UI tests can stall behind device-service noise

The compact workout UI test reached and dismissed its new last-set sheet, but the XCTest runner stalled before printing a final result while CoreSimulator repeatedly logged a passcode-protected device-service warning. A broader UI run also stopped on an unrelated existing calendar assertion. For visual prototypes, use `make sim-build`, launch with `simctl`, capture a screenshot, and treat the UI-test result as indeterminate until the simulator service is healthy.

## 2026-08-28 — New SwiftData property crashes on an existing phone store

Adding the nonoptional `WorkoutSet.isSkipped` property without a versioned SwiftData migration caused the installed phone build to fail during `ModelContainer` initialization. The simulator fixture used an in-memory store and did not expose the incompatibility. Existing device data must be migrated; deleting the app or clearing its data is only a last-resort workaround because it can remove workout history.
