## User requirements

- As a user, I want to choose a specific saved routine from a Shortcut, so that I can start it without navigating through the app.
- As a user, I want my available routines in the StrengthLog Home Screen icon's long-press menu, so that I can start a routine directly from that menu.
- Assume both entry points open the app and use its existing workout setup and navigation. Confirm how to handle a shortcut for a routine that was deleted or has no visible exercises, and what to do when a different workout is already active.

## Architecture and data model

Add an App Intents representation of a routine that resolves by the model's stable UUID and exposes active routines for selection in Shortcuts. Publish an App Shortcut that invokes the start-routine intent. Populate the Home Screen long-press menu with bounded dynamic quick actions for eligible routines and handle their selections through the existing `UIApplicationDelegateAdaptor` path.

Both entry points should converge on `WorkoutSessionStarter.start` and the root workout presentation flow. Resolve the selected UUID against the current SwiftData store before starting; do not trust a displayed routine name or stale quick-action payload. The existing `Routine.id`, `deletedAt`, and visible exercise data provide the needed identity and eligibility. No SwiftData schema or migration change is expected. The project targets iOS 17, so keep the integration compatible with that minimum. Confirm the platform's dynamic quick-action display limit and choose which routines to expose when there are more eligible routines.

## Basic test cases

- In Shortcuts, select a routine by name and run the shortcut; the resulting active workout belongs to that routine and opens in the workout screen.
- Long-press the app icon after routines exist; selecting a routine quick action starts that routine and opens the same workout screen.
- Rename a routine after a quick action was published; selecting its stable-ID action starts the renamed routine, while its label refreshes on the next action-list update.
- Delete a routine or remove all its visible exercises after an action was published; invoking the stale action does not start a different routine or create an invalid workout, and gives a safe return to the app.
- With no eligible routine, the shortcut reports that none can be started and the dynamic menu has no routine actions.
- With an active workout already present, verify the chosen behavior explicitly and ensure invocation never creates a second active session.
- Verify first launch/onboarding and app launch from both a cold and warm state so the request is handled only after the model store and root navigation are ready.

## High-level implementation details

1. Add a routine `AppEntity`, query, and start-routine `AppIntent` using the routine UUID as its identity and a user-readable routine name in the Shortcuts picker. Add the matching `AppShortcutsProvider` phrase and metadata, and register its shortcut parameters during app initialization if required by the selected App Intents pattern.
2. Add a small Home Screen quick-action publisher that derives a bounded list from current, nondeleted routines with visible exercises. Refresh it after routine changes and before the app backgrounds; include only the stable routine ID in each action payload.
3. Extend the existing app delegate/scene routing to accept a selected quick action, validate the ID against SwiftData after launch, and deliver a one-shot start request to the root view. Share the same validated start path with the App Intent so both use `WorkoutSessionStarter` and `presentActiveWorkout` rather than duplicating workout construction.
4. Preserve existing participant selection, history seeding, and save/error behavior. Define user-visible handling for unavailable routines and no configured people, and decide whether an invocation while a workout is active opens that workout or reports that the requested routine cannot start.
5. Add focused coverage for routine entity lookup, stale IDs, action-list eligibility/limits, request delivery on cold and warm launch, and exactly-one-session behavior. Run the relevant Makefile verification and exercise both system entry points on an iOS 17+ device or simulator; long-press menu visibility should be confirmed on device because the system presents those actions.
