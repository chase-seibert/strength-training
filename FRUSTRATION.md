# Frustration log

## 2026-08-26 — Xcode tools fail inside the restricted shell sandbox

An ordinary simulator build reported missing CoreSimulator runtimes, and SwiftData macros failed with `swift-plugin-server produced malformed response`. The app code was not the cause: both `actool` and Swift macro plugins require access denied by the shell sandbox. Re-running `xcodebuild` with the approved Xcode project prefix outside that sandbox restored simulator services and produced a successful full build.

## 2026-08-26 — Repository metadata path is read-only

This workspace began without Git metadata, but the environment exposes the project `.git` path as read-only. `git init` therefore fails with `Operation not permitted`. Leave repository initialization to a session with write access to `.git`; do not try to work around it by creating metadata elsewhere.
