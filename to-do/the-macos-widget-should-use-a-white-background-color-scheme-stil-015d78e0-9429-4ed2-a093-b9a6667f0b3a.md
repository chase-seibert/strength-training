## User requirements

- As a user, I want the Mac widget to use a light, near-white background in light mode, so that it keeps the clean look it had before the teal-blue palette.
- As a user, I want the widget to keep the new color scheme in dark mode, so that it still fits the updated dark appearance.
- Keep the progress data, chart, history, and iPhone-to-Mac delivery behavior unchanged. Assumption: the requested light/dark treatment applies to the widget as displayed on Mac; preserve a distinct iPhone treatment only if WidgetKit provides a supported way to distinguish Mac rendering.

## Architecture and data model

No material architecture, data-flow, persistence, or data-model change is required. This is a presentation adjustment in `ProgressWidgetView` and `ProgressWidgetTheme` in `StrengthLog/ProgressWidget.swift`. Retain the current dark-mode palette and replace the light-mode teal canvas and its dependent text colors with a white or near-white canvas and readable dark foreground colors. Confirm whether WidgetKit exposes a supported rendering signal for a Mac-only override; if it does not, use the same light/dark palette on the shared widget rather than relying on undocumented platform detection.

## Basic test cases

- On the Mac desktop and in Notification Center, light appearance uses a white or near-white canvas with clear text, chart labels, legend, history, and PR badges.
- In dark appearance, the widget keeps the current dark canvas and coordinated foreground colors.
- Empty-data and unavailable states remain readable in both appearances.
- If Mac-only styling is supported, verify the iPhone widget keeps its current colors. Otherwise verify the shared widget's near-white light palette and current dark palette on iPhone too.
- Verify medium and large layouts, participant series colors, snapshot contents, and refresh behavior remain unchanged.

## High-level implementation details

1. Check WidgetKit's supported environment for distinguishing an iPhone widget rendered on Mac from one rendered on iPhone. Do not use undocumented device or process checks.
2. Update the adaptive theme in `StrengthLog/ProgressWidget.swift`: use a white or subtly off-white light canvas, dark text and secondary colors with adequate contrast, and preserve the current dark-mode palette. Keep participant series and PR colors intact unless contrast inspection shows a specific conflict.
3. Build the widget/app target and inspect medium and large widgets on Mac in light and dark appearance. Check iPhone appearance if styling is shared, and confirm data and refresh behavior are unaffected. Record any device, signing, or Continuity limitation that prevents visual verification.
