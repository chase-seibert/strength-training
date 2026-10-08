# Dynamic Island countdown visibility with Overcast

## User requirements

- As a user, I want the active rest countdown to remain visible in the Dynamic Island while Overcast is active, so that I can check how much rest remains without opening StrengthLog.
- As a user, I want the countdown to stay readable in each Dynamic Island presentation the system assigns while multiple Live Activities are active, so that another app's activity does not leave me with only an uninformative icon.
- The provided screenshot shows a timer symbol in the main Dynamic Island area and Overcast artwork in the adjacent capsule, with no remaining-time digits visible. “Counter” is treated as the active rest countdown supplied by the StrengthLog Live Activity.

## Architecture and data model

No material architecture, persistence, schema, or migration change is expected. `LiveActivityManager` already supplies the rest end date to the ActivityKit content state, and `LiveActivityWidget` renders the Lock Screen, expanded Island, compact trailing, and minimal presentations. The screenshot's timer-symbol-only area matches the current icon-only minimal presentation, while Overcast artwork is visible in the adjacent capsule. Update the minimal widget presentation to use the existing end date and show the remaining time; do not add duplicate timer state.

## Basic test cases

- With a StrengthLog rest timer running and no competing activity, the compact Island continues to show the countdown.
- With Overcast active and its artwork visible in the adjacent capsule, StrengthLog shows remaining-time digits in the main Dynamic Island area instead of only the timer symbol shown in the screenshot.
- As the countdown approaches and reaches zero, its display remains bounded and understandable; expiry still ends the Live Activity as it does today.
- The expanded Dynamic Island and Lock Screen continue to show the existing countdown and workout details.
- With Live Activities unavailable or disabled, the workout rest timer continues to function in StrengthLog without a crash or a new persistence dependency.

## High-level implementation details

1. Use the supplied screenshot as the visual reference and confirm the timer-symbol-only state against the current `LiveActivityWidget` layouts.
2. Update the minimal Dynamic Island view in `StrengthLog/LiveActivityWidget.swift` to show the remaining-time digits in the main area beside Overcast's adjacent activity capsule. Preserve the existing expanded and compact layouts unless device inspection reveals a related issue.
3. Build and lint with the repository's Makefile targets, then deploy the successful build with `make phone-deploy` as required for app changes.
4. On the iPhone 17 Pro, start a rest timer and activate Overcast so both Live Activities compete for Dynamic Island space. Visually verify StrengthLog's minimal countdown, then inspect the solo, expanded, and Lock Screen presentations. A simulator build alone cannot confirm the multi-activity Dynamic Island behavior.

The main risk is the narrow, system-controlled minimal presentation: a full timer may not fit or remain readable at every duration. Choose a concise format that fits the screenshot's main area and verify it on the phone with Overcast active; report physical-device verification separately from build success if the phone is unavailable or locked.
