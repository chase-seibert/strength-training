# StrengthLog analytics

Analytics is disabled by default. The project uses
`Config/AnalyticsConfig.xcconfig`, which optionally includes the ignored
`Config/AnalyticsConfig.local.xcconfig`; CI can override the same settings.
Xcode maps the `ANALYTICS_*` values into the app's Info.plist. Enable collection
only after the analytics server provisions a LiftChase namespace and key. The client fails
closed when configuration is missing or malformed. The example file contains
placeholders only; never commit a real HMAC key.

The initial catalog is intentionally small and uses aggregate or categorical
properties only:

- `app.open`: once on launch and again when the app returns to the foreground.
- `onboarding.completed`: whether starter routines were added and their count.
- `routine.started`: source category, whether the routine is custom or imported,
  the routine name, and stable IDs for bundled catalog exercises; only for a newly
  saved workout session.
- `workout.completed`: bounded duration bucket and exercise/completed/skipped set
  counts plus stable IDs for bundled catalog exercises actually used; emitted
  only after the completion save succeeds.
- `workout.discarded`: explicit active-workout discard only, after its save succeeds.
- `routine.created` and `routine.edited`: exercise count and routine name.
- `exercise.created`: name and selected details (category, equipment, primary
  muscle, tracking unit, rep-counting mode, and whether it was duplicated),
  emitted after a new custom exercise is saved.
- `hevy_import.completed`: aggregate routine, workout, and mapped/unmapped counts.
- `healthkit.export_setting_changed`: the new on/off setting only.

Event construction validates property names and categorical values centrally.
Routine names and newly created custom exercise names are sent only on the
corresponding routine and exercise lifecycle events. Exercise IDs are limited
to stable IDs from the bundled catalog; local SwiftData model IDs are not sent.
Exercise creation sends only the selected categorical details listed above; it
does not send exercise notes or instructions. The client does not send
participant names, profile/model IDs, other notes, search text, set-level
measurements, workout records, or imported file data. Queue storage is separate from SwiftData and excluded from device
backup. Prepared compressed bytes and signatures are persisted and reused for
retries. The local queue retains the most recent 100 events with their queued,
uploaded, or rejected state. Developer Menu → Analytics diagnostics
shows up to 50 recent safe summaries and a persisted lifetime count of events
accepted by the server. Existing queue files migrate with that count set to zero.
Rejected events are removed from the retry queue; diagnostics keep the HTTP
status and server error code so a rejected request is distinguishable from an
event waiting to upload. The gzip encoder wraps Apple's raw DEFLATE stream in a
gzip header and trailer before hashing and signing the request bytes.

Before enabling a build, provision and confirm the namespace slug, stable app
slug, endpoint, key ID/secret, audience, and production consent/opt-out policy.
An app-bundled HMAC key can be extracted, so it must be app-scoped, revocable,
and rotatable.
