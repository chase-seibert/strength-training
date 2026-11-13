# Create a web page for App Store release

## User requirements

- As a lifter, I want fast, 100% offline workout logging, so that I can record a strength session without relying on an account or internet connection.
- As a parent, child, or couple, I want to log up to three people's activities in the same routine while keeping each person's sets and progress separate, so that we can work out together without combining our records.
- As an App Store visitor, I want a public privacy page that matches the app's actual data practices, so that I can understand what stays on my device and what may be shared.
- As the app owner, I want one set of simulator screenshots to serve both the website and App Store listing, so that the product is represented consistently in both places.
- As a release owner, I want the site hosted from the existing public GitHub repository without a custom domain, so that the Privacy Policy URL is available for App Store Connect.

**Market research and proposed positioning.** Hevy and Strong foreground workout logging, routines, exercise libraries, history, charts, and integrations; Fitbod differentiates with generated workouts and recommendations based on training history, goals, and equipment. Against those offers, lead with this app's combination of fast, offline logging and one routine that tracks up to three people side by side. Make the family/couple use case concrete: a parent and child or two partners can follow the same routine while each person's sets, values, and progress stay separate. Avoid claiming the feature is unique across the whole market without a broader competitor audit.

- **Primary value proposition:** Fast, 100% offline strength logging for up to three people in one routine.
- **Supporting line:** Work out together. Keep everyone's sets and progress their own.
- **Proof points:** no account or connection required for core logging; choose one, two, or three participants for a session; log each person's sets side by side; carry each person's latest values forward; review individual workout history and progress.
- **Audience:** explicitly show parents and kids and couples; solo training remains supported.
- **Claim boundary:** the repository describes optional analytics and optional cloud coaching. Verify the release configuration and distinguish these opt-in network features from the offline workout logging claim; do not imply that optional cloud features work offline.
- **Naming assumption:** `LiftChase` is the preferred working name in `docs/app-name-brainstorm.md`; confirm the release name before final copy because the repository and current app display still use StrengthLog variants.

Research references: [Hevy's feature guide](https://help.hevyapp.com/hc/en-us/articles/33106320824727-Everything-You-Need-to-Know-About-the-Hevy-App-2026-Features-Guide), [Strong](https://www.strong.app/), [Fitbod's explanation of its workout recommendations](https://help.fitbod.me/hc/en-us/sections/360001078993-How-Fitbod-Works), and [Apple's App Privacy requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/).

## Architecture and data model

Build a small, static site in a dedicated repository directory, proposed as `site/`, with a landing page and a privacy page. Publish that directory through GitHub Pages on the existing public `chase-seibert/strength-training` repository; use the repository's GitHub Pages URL and no custom domain. Use ordinary HTML, CSS, and only minimal JavaScript if needed. No server, account system, or app data model changes are required. Present offline operation as a core benefit while accurately disclosing optional network-dependent features.

Place reusable simulator captures in a committed site asset directory and keep the generated masters as the source files used for the App Store listing. Reuse the existing deterministic UI-test fixture/launch-argument approach in `StrengthLogUITests/WorkoutNavigationUITests.swift`; add or refine a dedicated marketing screenshot fixture only if current fixtures do not produce clean, representative screens. Avoid participant names or personal workout data in captures.

Proposed five-image sequence, using one consistent fictional simulator fixture:

1. **Parent and child, mid-workout:** active exercise matrix with two columns, e.g. “Dad” and “Maya (12),” showing different loads/reps and completed sets. Caption: “One routine. Each of you keeps your own numbers.”
2. **Exercise library:** Exercises tab with the total count prominent and search visible. Caption: “874 exercises, ready to browse offline.” The checked-in catalog currently contains 873 records; reconcile the release count before capturing, and do not stage a misleading 874 count if the shipped catalog remains at 873.
3. **No account, fast local start:** first-run onboarding or first workout setup shown without a sign-in wall, paired with “No account. Your core workout log stays on your iPhone.” Verify the release build can set up and log offline; keep optional cloud/analytics behavior described separately.
4. **Choose today's people:** the onboarding “Who should we track?” step with three fictional profile names, showing that a session can include one, two, or three people. Caption: “Choose who's training today.”
5. **Progress for everyone:** Progress screen with multiple distinct participant series/legend entries and a readable volume chart. Caption: “See each person's progress over time.”

The screenshots should be app captures rather than composites that invent controls or data. Use short website captions outside the simulator image; retain the same approved, unaltered image masters for App Store Connect.

The privacy page must describe the shipping app, not just its offline-first default. Audit the current analytics implementation/configuration and `docs/analytics-client.md`, optional Apple Health export, and optional on-device/cloud Lift Coach behavior before writing policy copy. The current documentation says analytics is disabled by default, Health export is opt-in and write-only, and cloud coaching requires explicit provider/context sharing. Confirm production configuration, destinations, retention/deletion, and any third-party processing, then align the public policy, App Store privacy disclosures, and the in-app privacy link. Apple requires a publicly accessible privacy-policy URL for iOS apps and its review guidance requires the policy to explain collection, use, third-party sharing, and retention/deletion.

## Basic test cases

- Opening the GitHub Pages root loads the landing page over HTTPS, with working links to the privacy page and App Store listing when available.
- Opening the privacy path directly loads the complete policy, including when reached from a fresh browser session; there are no broken links or dependence on client-side routing.
- On narrow phone and desktop viewports, headline, value proposition, calls to action, screenshots, and policy text remain readable without horizontal scrolling; keyboard navigation and meaningful image alternatives work.
- With network access unavailable, a user can set up and log a core workout without an account or connection; the page's offline claim matches the verified release behavior.
- A solo user, a couple, and a parent with a child can select one, two, or three participants in the same routine. Their sets, latest values, and history remain separate in the shared workout display.
- The five fixture captures show the parent/child active workout, exercise library count, no-account offline setup, “Who should we track?” participant selection, and multi-person progress; all names and workout values are fictional and consistent across images.
- The exercise-count headline matches the catalog in the release build. The current checked-in catalog has 873 entries, so use 874 only if the release catalog is updated and verified to contain that count.
- The landing page leads with speed/offline use and shared logging for up to three, while accurately describing the shipped app and not implying that optional cloud coaching or analytics run offline.
- The privacy page matches the audited release configuration for local workout data, optional analytics, Apple Health writes, and any optional cloud coaching. Every collection/sharing claim agrees with App Store Connect disclosures and the in-app privacy entry point.
- Running the simulator capture flow from a clean fixture produces the approved screens with stable example values and no personal data. The same master image files are used in the site and App Store screenshot upload set, with correct dimensions and no stale captures.
- A static build/deployment preview serves both pages and all image assets from the GitHub Pages project path, including the repository-name path prefix; no custom domain or backend is needed.

## High-level implementation details

1. Confirm the final release app name, repository visibility/Pages availability, public repository URL, support contact, App Store URL (or temporary CTA behavior), and exact privacy contact/request process. Treat the current LiftChase name and no-domain GitHub Pages hosting as working assumptions until checked.
2. Use current category research to write concise page copy around “Fast, 100% offline strength logging for up to three people in one routine.” Support it with “Work out together. Keep everyone's sets and progress their own.” Show parents/kids and couples, side-by-side set logging, per-person defaults, and individual history. Verify the scope of the 100% offline claim against release code/configuration and clearly label any optional network-dependent features.
3. Audit the privacy-relevant code and release configuration. Verify analytics event properties and whether analytics will be enabled in the submitted build; verify HealthKit behavior and cloud coaching data flow/processor terms. Resolve policy wording and retention/deletion instructions from observed behavior before publication.
4. Add the static landing and privacy pages under `site/`, with responsive accessible layout, App Store call to action, navigation between pages, and policy sections for data handled, purposes, optional integrations, third parties, storage/retention, deletion/contact, and policy updates. The current source search found no in-app privacy-policy link, so track that as a separate app implementation/release dependency; Apple review requires one inside the app as well as in App Store Connect.
5. Define a stable simulator fixture with fictional parent/child and participant data for the five proposed screens, capture them from the iPhone simulator, review for legibility and personal data, and store the masters once. Reconcile the current 873-record catalog with the requested 874-exercise claim before capture. Reference those exact files from the website and use the same approved files for App Store Connect screenshots; keep captions outside the app captures and avoid maintaining separate edited copies.
6. Add a lightweight static-site validation/build command and GitHub Pages workflow for the `site/` directory. Preview the generated site under its project path before enabling Pages, then verify the public landing and privacy URLs, HTTPS, links, images, and mobile layout after deployment.

**Risks and open decisions:** final branding and App Store URL may still change; the “100% offline” claim must clearly apply to core logging if optional analytics/cloud coaching make network requests; privacy copy can become inaccurate if feature settings or retention terms change; GitHub Pages availability and repository settings must be confirmed; screenshot automation may currently retain XCTest attachments rather than export ready-to-use image files. Do not publish until offline behavior, policy facts, support/contact details, and release copy are verified. The landing page itself cannot replace App Review's requirement that the iOS app provide an in-app privacy-policy link.
