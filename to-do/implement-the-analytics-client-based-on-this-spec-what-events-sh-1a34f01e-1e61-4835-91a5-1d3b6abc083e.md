## User requirements

- As a user, I want StrengthLog to keep recording useful product events when I am offline, so that analytics can upload later without slowing or interrupting workouts.
- As a user, I want workout use and completion to remain private and independent of analytics availability, so that missing configuration or a server outage never changes workout behavior.
- As a product maintainer, I want a small set of events that explains onboarding, workout starts and completions, and feature adoption, so that I can improve the app without collecting personal workout details.
- Assumption: collection is enabled only when a valid build/deployment configuration is present; the product owner still needs to decide the production namespace and whether production collection needs an in-app opt-out or consent flow.

Recommended initial event catalog, using stable lowercase event names and only categorical or aggregate properties:

- `app.open`: emit once when an app session enters the foreground, not for repeated view appearances.
- `onboarding.completed`: include only aggregate setup choices such as whether starter routines were added and a count, never profile names.
- `routine.started`: emit only after a new workout session is created; include a source category such as `home`, `shortcut`, or `app_intent`, and whether the routine is built-in or custom.
- `workout.completed`: emit only after the explicit completion is saved; include bounded duration and counts for exercises, completed sets, and skipped sets.
- `workout.discarded`: emit only for an explicit discard/delete action, with a categorical source; do not treat app backgrounding or an unfinished session as a discard.
- `routine.created` and `routine.edited`: record the action and aggregate exercise count, not routine names or exercise lists.
- `exercise.search_result`: record only a result-count bucket and whether a result was selected; never send the query. Add this only if search discoverability is a product question.
- `hevy_import.completed`: include aggregate imported workout/routine counts and mapped/unmapped exercise counts; never include CSV rows or imported notes.
- `healthkit.export_setting_changed` and `watch.workout_action`: optional integration-adoption events, limited to setting state or action category and emitted only where a successful action can be distinguished.

Do not send participant/profile names, routine or exercise titles, stable model IDs, notes, search strings, set-level weights/reps, raw workout history, Health data, file paths, or full URLs. Avoid per-view appearance events and per-set events in the first release; add them only to answer a specific product question.

## Architecture and data model

Implementation contract: `/Users/cseibert/projects/analytics-server/docs/client-spec.md`.

Add a process-wide analytics service created by `StrengthLogApp` and injected into the app's SwiftUI root and the feature services that emit events. It accepts lightweight events synchronously, then performs queue writes, JSON encoding, gzip compression, SHA-256/HMAC signing, and network uploads asynchronously. Event emission must never be a prerequisite for saving or completing a workout.

Load a typed analytics configuration from build/deployment configuration, with test/preview overrides and an explicit disabled state for missing or malformed values. Keep real secrets out of Swift source and source control; use placeholder examples for local setup and CI secret injection. The referenced spec lists namespaces for other apps but none for StrengthLog, so provision and confirm this app's namespace, stable `app.name`, key ID, endpoint, and audience before enabling production uploads. A bundled iOS signing key is extractable and must be scoped, revocable, and rotatable if that deployment choice is made.

Persist queued events and prepared batch bytes under `Application Support/Analytics/`, excluded from device backup. Persist retry count/time, redirect URL, stop-logging state, and a bounded sanitized diagnostics history. Keep this queue separate from SwiftData workout history; no workout schema migration or changes to authoritative workout records are required. Retain unsent production events for at least 90 days, with bounded storage and oldest-first eviction only when necessary.

Implement the spec's v1 request contract: one audience per batch; at most 500 events and the stated compressed/uncompressed size limits; gzip UTF-8 JSON; SHA-256 over the exact compressed bytes; HMAC-SHA256 over namespace, API version, batch ID, and payload hash; required headers; and reuse of the persisted bytes/signature on retry. Treat 202 and duplicate 200 as success. Retry network failures, 5xx, every 429 (including non-JSON AWS throttles), `INGEST_PAUSED`, and `pause_uploads` with persisted exponential backoff, jitter, and server `Retry-After` minimums. Do not retry permanent validation 4xx responses unchanged. Honor redirect and stop-logging actions, retaining events during pause and stopping collection only on explicit stop or disabled configuration.

Add a debug/internal diagnostics section in Settings showing config status, sync state, queue counts/age, retry and redirect state, and a bounded recent event list. Redact secrets, signatures, payloads, identifiers, URLs, paths, and app-specific private content. Include refresh, upload-now, and copy-summary actions; any clear-queue action must be debug-only.

## Basic test cases

- With no config or malformed config, analytics reports disabled and launch, workout save, and completion still work.
- With valid test configuration, a successful routine start emits one `routine.started`; reopening or resuming that session does not emit another start.
- Completing a workout emits one `workout.completed` only after local persistence succeeds. A failed save emits no completion event; discarding an active workout emits the discard event only after the explicit action succeeds.
- Event payloads contain the approved categories and aggregates and exclude names, model IDs, free text, set-level load/reps, and source file contents.
- Enqueue while offline, terminate and relaunch, then restore connectivity: queued events remain and upload in order. A restart reuses the exact prepared batch bytes, batch ID, hash, and signature.
- Accept 202 and duplicate 200 as success and remove that batch from the retry queue. Exercise network/timeout, 5xx, JSON and non-JSON 429, `INGEST_PAUSED`, `pause_uploads`, `Retry-After`, permanent 4xx, redirect, and stop-logging paths; verify retry scheduling and queue retention/deletion rules.
- Verify one audience per batch, nonempty batches, event and body size limits, gzip/hash/signature/header correctness, and correct retry behavior at the 90-day retention boundary and storage-pressure eviction boundary.
- Verify diagnostics show useful queue state while redacting secrets, request contents, identifiers, URLs, paths, and private workout details; production builds do not expose debug-only clearing.

## High-level implementation details

1. Use `/Users/cseibert/projects/analytics-server/docs/client-spec.md` as the transport, retry, privacy, and diagnostics contract. Confirm the StrengthLog namespace, stable analytics app slug, endpoint, key ID/secret provisioning, audience by build channel, and production consent/opt-out policy. Add only placeholder config examples and ignored local/CI secret inputs.
2. Add typed config, event/payload models, and an injectable analytics protocol/service. Keep event properties constrained to safe typed values and centralize the event catalog.
3. Implement durable queue and prepared-batch storage, backup exclusion, bounded diagnostics, batching, gzip/hash/HMAC preparation, upload, response-action handling, and persisted retry policy using native platform facilities where suitable.
4. Wire the service into `StrengthLogApp` and emit events at successful domain actions in onboarding, `WorkoutSessionStarter` and its Home/shortcut/app-intent call sites, explicit workout completion/discard, routine editing, optional exercise search/import, and integration actions. Avoid view `onAppear` as a proxy for meaningful user action.
5. Add the debug/internal diagnostics UI in `SettingsView` and ensure all displayed/exported diagnostics are redacted.
6. Add focused unit tests for config, event privacy/catalog, queue persistence, deterministic prepared-batch retries, signature/request construction, retry/response actions, and instrumentation call sites. Run the repository's appropriate verification and, after successful app verification, follow `make phone-deploy`; visually inspect the diagnostics UI on device when it is user-visible.

Material risks are accidental collection of free text or model identifiers, duplicate events from SwiftUI lifecycle callbacks or resumed sessions, loss of retry state across relaunch, mismatched app namespace/key configuration, and CPU/disk/network work leaking onto the main workout path. Keep analytics nonblocking and fail closed when configuration is invalid.
