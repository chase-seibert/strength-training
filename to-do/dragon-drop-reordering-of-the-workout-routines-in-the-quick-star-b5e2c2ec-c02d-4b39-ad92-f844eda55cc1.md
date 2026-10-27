## User requirements

- As a user, I want to drag workout routines into my preferred order from Quick Start and the Routines page, so that both places use the same order.
- As a user, I want the order to remain after closing and reopening the app, so that I do not have to arrange my routines again.
- Assumption: Quick Start currently shows only the first three active routines, so its direct reorder interaction rearranges those visible routines; the Routines page remains the place to arrange the full list.

## Architecture and data model

Add a persisted routine-level order value to `Routine`. Both active-routine queries should sort by that value, so the complete Routines list and the first three Quick Start cards share one source of truth. Initialize existing routines in their current `createdAt` order with a one-time, deterministic backfill; give newly created and starter routines positions after the current active routines. Keep a soft-deleted routine's order when it is deleted so restoring it returns it to its prior relative position. A defaulted integer attribute should support SwiftData's lightweight migration, with startup normalization handling existing rows that all receive the default value. No workout-session or exercise-order data needs to change.

## Basic test cases

- Drag two visible Quick Start routines into a new order; confirm the cards move immediately and the same order appears on the Routines page.
- Reorder routines on the Routines page, including moving a routine into or out of the first three; confirm Quick Start shows the new first three in that order.
- Close and reopen the app after reordering; confirm both screens retain the order.
- Install over a store with existing routines and no saved routine order; confirm the existing `createdAt` order is preserved on first launch and later reorders persist.
- Create a routine after arranging existing routines; confirm it appears at the end in both places. Delete and restore a routine; confirm its relative position is retained.
- Confirm empty, single-routine, and two-routine lists remain usable and cannot produce duplicate or missing order positions after a drag.

## High-level implementation details

1. Inspect the SwiftData model setup and routine creation paths, then add and initialize `Routine.sortOrder` with compatibility for existing stores. Normalize legacy routines once in their current creation order and append routines created later.
2. Change the active-routine queries in `HomeView` and `RoutinesView` to use the same saved ordering. Keep Quick Start's current three-routine limit and make its reorder affordance clear without interfering with starting a workout.
3. Add drag-and-drop reordering to both Quick Start and the Routines list. Persist the resulting full active-routine order through the model context, and recover or report a save failure without leaving the two surfaces with different orders.
4. Review starter-routine insertion, routine deletion/restoration, and any fixture creation so their positions remain unique and predictable. Preserve historical workout snapshots and routine identity.
5. Add focused UI and persistence coverage for dragging on both surfaces, shared order, relaunch persistence, legacy-store initialization, and create/delete/restore behavior. Run the appropriate repository checks, then deploy a successful app build with `make phone-deploy` and inspect the affected screens on the iPhone as required for implementation work.

The main interaction detail to settle during implementation is whether Quick Start should reorder only its three visible cards or provide a way to move any routine from the full list into those positions. The current home layout exposes only three cards; this plan assumes those cards are reordered directly.
