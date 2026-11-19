## User requirements

- As a user, I want the app’s dark appearance to use the logo’s deep navy background with teal and orange as its primary brand colors, so that the app feels like it belongs with its icon.
- As a user, I want the light appearance to use teal as the main background and navy where the dark appearance uses teal, while retaining orange as an accent, so that both appearances feel like coordinated inversions of the logo palette.
- Assume these palettes follow the device’s Light/Dark appearance automatically. The task does not request a manual appearance picker or changes to the logo itself. Preserve secondary colors where they communicate distinct states, provided the result remains cohesive and legible.

## Architecture and data model

No material data-model, persistence, or migration change is required. This is a presentation change; do not store a palette preference unless a later product decision asks for manual selection.

Extend the existing centralized `Theme` definitions in `StrengthLog/Models.swift` with semantic, appearance-aware brand colors and surface roles. Resolve them from SwiftUI’s current color scheme so views can use the same semantic role in both appearances. Keep person and routine colors, warning/success states, and system text legible and distinguishable. Audit places that bypass `Theme` with fixed `Color` values or UIKit colors, and identify which should adopt brand roles versus remain intentionally state-specific. Check app-owned surfaces in widgets and Live Activities separately because their rendering and color APIs differ from regular SwiftUI screens.

Use these representative samples from the bundled 1024×1024 logo as initial brand values. The source has slight pixel variation, so verify the chosen values against the asset during implementation:

- Deep navy: `#010A31` (dark appearance canvas; sampled from the logo background).
- Teal: `#00A7B0` (dark appearance brand accent and light appearance canvas; sampled from the teal mark).
- Orange: `#FD4E10` (primary action/accent; sampled from the orange mark).

Suggested supporting values for prototyping the two skins; treat these as starting points and adjust after contrast review:

- Dark appearance card: `#111A2E`; elevated card: `#1B2840`; border/divider: `#34445E`.
- Dark appearance primary text: `#F5F7FA`; secondary text: `#B6C0D0`.
- Light appearance card: `#EAF7F5`; elevated card: `#F7FCFB`; border/divider: `#6F9FA0`.
- Light appearance primary text: `#010A31`; secondary text: `#38515A`.
- Optional semantic status colors: success `#1D7A57`, warning `#F2B84B`, destructive/error `#D6423A`.
- Optional secondary chart series: blue `#4B7BEC`, purple `#8B69C6`.

These supporting colors are proposed UI values, not sampled logo colors. Check contrast in both appearances, particularly on the teal light canvas, and retain distinct status meaning if alternatives are needed.

## Basic test cases

- With the device in Dark appearance, the main app surfaces use deep navy, prominent actions and controls use orange and teal as deliberate primary accents, and text/icons remain readable.
- With the device in Light appearance, the main brand surface becomes teal, navy provides the corresponding contrasting brand role, and orange remains a visible accent.
- Switching system appearance while the app is running or after relaunch updates the palette without losing workout, routine, or profile data and without requiring a settings change.
- Review Home, Routines, an active workout, Progress, Settings, onboarding, and workout completion in both appearances; grouped cards, lists, navigation, dialogs, charts, disabled controls, and completion states remain visually distinct.
- Confirm participant and routine colors, warnings, personal-record markers, and success/completion indicators remain distinguishable from the new brand colors and are not conveyed by color alone.
- Check contrast and legibility for small labels, secondary text, selected and disabled controls, and accessibility text sizes. Check widget and Live Activity surfaces for consistency where they are independently styled.

## High-level implementation details

1. Use the bundled app icon and `docs/design.md` as palette references. Confirm the logo’s navy, teal, and orange values from the source asset rather than approximating them from screenshots. The current `Theme` contains navy, coral, and mint, while the design notes describe navy/coral/mint styling; reconcile those existing roles with the logo palette without erasing colors that carry non-brand meaning.
2. Define semantic light/dark brand and surface colors centrally, using appearance-aware color resolution. Decide whether the user’s “teal background” means the primary app canvas or selected brand surfaces; keep text and cards readable against it and document the chosen hierarchy in `docs/design.md` as part of implementation.
3. Trace usages of `Theme.navy`, `Theme.coral`, `Theme.mint`, system grouped backgrounds, and fixed colors through the main screens and shared components. Migrate brand uses to semantic roles, retaining profile colors and intentional status colors. Review onboarding and celebration treatments for deliberate palette choices.
4. Review the separately defined colors in `LiveActivityWidget.swift`, `ProgressWidget.swift`, and related shared widget code. Update compatible surfaces so the brand remains coherent without assuming app-level dynamic colors automatically reach extensions.
5. Verify Dark and Light appearance on simulator, including a runtime appearance switch, then run the repository’s appropriate app verification (`make sim-build` and `make phone-deploy` after a successful build). Inspect the affected screens on Chase’s iPhone 17 Pro after deployment. Adjust the palette for contrast or ambiguous state colors found during review; no data migration is expected.
