## User requirements

- As a parent, I want my child’s Apple Watch to show the exercise currently selected on the parent’s phone and the exercise information for every participant in that exercise, so that the child can swipe between profile cards and view their own information without a separate person picker.
- As a watch wearer, I want to swipe left and right between the participants on the current exercise, so that I can make my own profile the current card while the exercise remains the one selected in the parent’s workout.
- As a family, we want a child’s Family Sharing-managed watch to receive this current workout state, so that the watch can follow along without the child having a paired iPhone of their own.
- Assume “family plan” means Apple Family Sharing / Apple Watch For Your Kids. Link and authorize the child’s Apple Account/watch to the app’s shared workout data; do not associate that watch with exactly one StrengthLog person profile. Swiping among people is watch-local presentation state, not a separate exercise position for each participant.

## Architecture and data model

StrengthLog currently has one iOS app target, local SwiftData storage, no watchOS target, and no CloudKit or Watch Connectivity integration. `ActiveWorkoutView` owns the selected exercise in transient phone view state. `WorkoutSession` stores the active participant set and participant logs, but logs identify people by name. Family Sharing does not automatically grant an app access to workout records. A Family Setup / Apple Watch For Your Kids watch can operate without the child’s iPhone, while ordinary Watch Connectivity is intended for a watchOS app and its companion iOS app; it is not sufficient as the sole transport for this managed-watch scenario.

Add an independent-capable watchOS app and a minimal CloudKit sharing path. Keep the parent’s SwiftData workout as the source of truth. Publish one compact snapshot of the globally selected exercise and the participant cards for that exercise. Each card should contain the stable person ID, display name, and only the exercise values/progress the watch needs to render. Do not include other exercises or workout history. Share the snapshot with the child’s Apple Account using a private, read-only CloudKit share. The watch account is authorized for the shared workout data as a whole; the wearer swipes among participant cards and the watch may remember the last viewed card locally. The watch does not independently advance the exercise.

Add a stable optional person ID to participant logs or an equivalent durable mapping so cards remain tied to profiles if names change. Resolve existing name-only logs only when there is one unambiguous profile match; leave ambiguous or unmatched legacy data unchanged. No broad workout-store migration or replacement is required.

The parent app writes the CloudKit snapshot when the selected exercise changes and when relevant participant data changes. Use a CloudKit database subscription for remote-change push hints, fetch the latest snapshot when the watch app opens or resumes, and optionally request system-scheduled background refresh. This is event-driven delivery, not continuous polling; CloudKit pushes may be delayed or coalesced and watchOS may defer background work. Show a last-updated time and stale/offline state, and do not make local workout saves depend on cloud availability. If a hard near-real-time guarantee is required, evaluate an authenticated service separately.

Family Sharing setup supplies the family relationship and child account but does not link StrengthLog data. Add an app-level flow in which the parent chooses a child Apple Account to invite to the private share, and the child accepts while signed in to that account on the managed watch. The flow authorizes the watch account to see all participant cards in the shared active exercise; it does not ask the child to choose a StrengthLog profile during setup. Include a way for the parent to inspect and revoke access. Validate the share-invitation and acceptance experience on a real Family Setup watch; if the watch cannot accept the invitation directly, define a supported acceptance step on another device signed in to the child’s account.

## Basic test cases

- Parent links a child’s Apple Account to a private, read-only workout share; after acceptance, the watch shows the current exercise and cards for all participants in that exercise.
- The wearer swipes left and right through participant cards; the exercise stays fixed, each card shows the matching profile’s values, and returning to the watch restores the last viewed card if that behavior is implemented.
- Parent advances the selected exercise; the watch fetches and displays the new exercise and its participants, eventually when backgrounded and promptly when open and connected. No fixed background update deadline is assumed.
- Parent edits participant values or set progress; the corresponding card refreshes without exposing other exercises or workout history.
- The child has not accepted the share, is signed out, or is offline; show setup guidance or the last update as stale, and keep the parent’s local workout usable.
- Parent closes or completes the workout; clear the active snapshot or show a clear completed state so an old exercise is not presented as current.
- A profile is renamed after a workout; the card continues to identify the same profile by stable ID. Ambiguous or unmatched legacy names are not attached to the wrong person.
- Parent removes the child account’s share access; subsequent watch fetches no longer expose the snapshot.
- Confirm that a Family Setup watch can install/open the app, accept or otherwise complete app-level linking, fetch CloudKit data, and recover after offline time. A simulator or normally paired watch alone is insufficient evidence.

## High-level implementation details

1. Confirm which participant values/progress belong on each card and whether the watch should remember the last viewed profile. Keep the selected exercise global to the parent’s workout; the wearer’s swipe changes only the visible participant card. Verify supported watch models, OS, region, and Apple Account requirements for the intended Family Setup configuration.
2. Add the independent watchOS target and focused participant-card UI. Provide horizontal swipe navigation, clear profile identity, and visible last-sync/offline status; do not add a profile picker or independent exercise navigation.
3. Add stable participant-to-profile identity with safe legacy name resolution. Test rename, duplicate-name, and missing-profile handling.
4. Define a versioned, minimal snapshot for the selected exercise and all participant cards. Publish on session start, exercise changes, relevant value/progress edits, and session close/completion. Handle retries, share/account errors, stale state, and access revocation without blocking SwiftData saves.
5. Add parent-side app linking: choose/invite the child’s Apple Account, create/manage the private read-only share, and explain that this is separate from Family Sharing setup. Implement child-side share acceptance and watch-account binding without requiring the child to select a StrengthLog profile.
6. Subscribe for CloudKit remote-change notifications, fetch the latest record when notified and on foreground/resume, and use system-scheduled refresh only as an opportunistic fallback. Avoid fixed-interval polling and represent freshness honestly.
7. Verify model/snapshot behavior with focused tests; build both targets; exercise invitation acceptance, swipe/card correctness, update delivery, offline recovery, profile rename, session close, and revocation on a real Family Setup watch. Use repository Make targets and deploy the successful iOS build to the iPhone as required by project guidance.

Material risks are CloudKit’s eventual notification delivery, Family Setup account/app compatibility, acceptance UX on a watch without its own iPhone, and legacy name-only participant records. The main product decision still needed is exactly which participant values and set-progress details appear on each card.
