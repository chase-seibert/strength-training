# Design

## Product character

StrengthLog should feel energetic and fast without adopting the dense, black-and-neon look common to lifting apps. The visual system uses a deep navy foundation, electric coral actions, mint completion states, soft grouped backgrounds, and rounded cards.

## Interaction principles

- Live logging optimizes for one-handed taps between sets.
- The brand hero belongs to the welcome step. Workout presents routine choice first, the four-week activity card second, and a conditional Deleted Workouts link last.
- Onboarding offers three unselected starter-routine cards after people setup; continuing without templates is equally prominent.
- One participant occupies one compact row per exercise, even with several sets.
- Routines are person-agnostic and contain exercise structure only; weights, reps, and sets are configured per person from the latest workout.
- Starting a workout defaults to its most recent crew. People can be toggled on and off quickly; turning off someone with completed sets warns first and keeps their data available if they are turned back on.
- Set buttons remain individually visible; there is no picker or menu for common completion actions. Completion proceeds in order, and only the latest completed set can be removed.
- Measurement and reps remain editable in place. A numbered next-set control follows the existing sets and completes the extra set in one tap; removing a completed set also clears every later incomplete set.
- Exercise thumbnails are visible in the workout; tapping one opens a full-size, swipeable position gallery.
- An open workout becomes a distraction-free app root with no tab bar; Done restores normal navigation.
- Routine and open-workout exercise lists expose standard edit-mode reordering. Routine edit mode exposes name, exercise addition, and a dedicated appearance sheet with a curated icon and color grid, plus a bottom destructive action, while hiding Start Routine. The sheet remains interactive while the exercise list is in reorder mode. Exercise addition, deletion, reordering, and appearance changes refresh the draft immediately but persist only through Save; Cancel restores the stored routine. Routine deletion moves it out of active views into Deleted Routines, which appears as a conditional link at the bottom of the Routines list and offers an explicit Restore action.
- Participant selection happens when starting and can be changed from the live screen without deleting hidden data.
- Change People, Reorder, and Add Exercise sit in the scrollable footer of an open workout, leaving the top bar focused on Done.
- Workout logs save continuously. Close is lightweight navigation, and reopening is immediate; neither requires confirmation.
- Workout history supports swipe-to-delete from Progress, plus confirmed delete actions from session details and the bottom of an open workout. Deleting a workout removes it from the calendar and activity counts but never removes its routine or catalog exercises; the conditional Deleted Workouts link on Workout supports restoration.
- The activity card uses a Sunday-through-Saturday calendar with a weekday header and exactly four compact week rows. Previous and next controls page in four-week increments, stopping at the current four-week period. Boxes omit day numbers, use each routine's configured symbol and color when available, fall back to a short acronym when no symbol is configured, add a count badge for multiple workouts on one date, and show a small two-person glyph when more than one person participated that day. Deleted workouts are excluded, and any elapsed date opens every routine, person, exercise, set, rep, and measurement recorded that day. Each workout on the completed-day screen uses separate fully rounded header and body cards; the header matches the symbol-and-color routine tile used on Home without its play button. Completed-set glyphs reuse the active-workout check styling at a smaller size and use the recorded person's color. When any exercise has unfinished sets, one action at the bottom of the entire day presents an arrow-anchored confirmation popover and removes unfinished sets across every exercise shown.
- CSV import begins with routine selection. The complete exercise list then filters to those routines, defaults to frequency order, can be sorted by recency or name, and can be displayed for all history or the last 30, 60, or 90 days relative to the newest selected workout. The display filter does not change import scope. Each exercise opens a name-only searchable mapping override with explicit skip and create-custom options.
- Exercise search matches exercise names only. Muscle and equipment remain explicit filters or metadata rather than implicit search terms.

## Accessibility

- System type supports Dynamic Type.
- Status is conveyed with both symbols/text and color.
- Participant badges expose full-name accessibility labels.
- The activity calendar exposes date, workout count, routines, and multi-person participation per cell.
- Controls use standard SwiftUI button, picker, stepper, and text-field semantics.

## App icon

The master is a 1024×1024, high-contrast barbell/progress mark with no text or baked corner mask. It was generated with the built-in image generation tool from a `logo-brand` prompt requesting a central geometric barbell, upward progress gesture, deep neutral background, coral symbol, bold silhouette, and recognition at 40 px.
