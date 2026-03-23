---
id: T02
parent: S14
milestone: M001
provides:
  - "Show Info" option in EpisodeScreen context menu routes to DetailScreen via action "detail"
key_files:
  - SimPlex/components/screens/EpisodeScreen.brs
key_decisions:
  - "Show Info" uses m.top.ratingKey (show-level key already on EpisodeScreen) rather than episode-level ratingKey — navigates to the show's DetailScreen, not the episode's
patterns_established:
  - Same options menu button insertion pattern as T01 — "Show Info" at index 1, Cancel shifts to index 2, cancel needs no explicit handler because dialog close and focus restore both run unconditionally
observability_surfaces:
  - "grep -c 'Show Info' SimPlex/components/screens/EpisodeScreen.brs" confirms button presence (expected: 1)
  - m.top.itemSelected emitted with action "detail" and ratingKey = m.top.ratingKey when "Show Info" is selected — observable from MainScene onItemSelected handler
duration: 5m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T02: Add "Show Info" option to EpisodeScreen options menu

**EpisodeScreen options menu now includes "Show Info" between the watched toggle and Cancel, navigating to DetailScreen with the show's ratingKey.**

## What Happened

Modified two functions in EpisodeScreen.brs:

1. **`showEpisodeOptionsMenu()`** — Changed buttons array from `[watchedLabel, "Cancel"]` to `[watchedLabel, "Show Info", "Cancel"]`. Cancel shifts from index 1 to index 2.

2. **`onEpisodeOptionsButton()`** — Added `else if index = 1` handler that emits `{ action: "detail", ratingKey: m.top.ratingKey, itemType: "show" }` via `m.top.itemSelected`. The dialog close fires at the top of the handler (before any index checks), and focus restoration runs unconditionally at the bottom — so Cancel at index 2 needs no explicit handling, matching the T01 pattern.

MainScene already dispatches `action: "detail"` to `showDetailScreen()` (line 443), so no changes needed there.

## Verification

All slice verification checks pass. "Show Info" appears in EpisodeScreen, the `action: "detail"` emission is present in the new handler, no Animation nodes were introduced in either changed file, and MainScene dispatch lines remain untouched.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -c 'Show Info' SimPlex/components/screens/EpisodeScreen.brs` | 0 | ✅ pass (1) | <1s |
| 2 | `grep -n 'action.*detail' SimPlex/components/screens/EpisodeScreen.brs` | 0 | ✅ pass (lines 312, 375) | <1s |
| 3 | `grep -c 'CreateObject.*Animation' SimPlex/components/screens/EpisodeScreen.brs` | 1 | ✅ pass (0 matches) | <1s |
| 4 | `grep -c 'action.*episodes' SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (2) | <1s |
| 5 | `grep -c 'Show Info' SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (2) | <1s |
| 6 | `grep -c 'Animation' SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (2 — pre-existing focus style properties, not node creation) | <1s |
| 7 | `grep -n 'action.*episodes\|action.*detail' SimPlex/components/MainScene.brs` | 0 | ✅ pass (lines 443, 445 unchanged) | <1s |
| 8 | `grep -n 'CreateObject.*Animation' SimPlex/components/screens/HomeScreen.brs SimPlex/components/screens/EpisodeScreen.brs` | 1 | ✅ pass (0 matches — no Animation nodes created) | <1s |

## Diagnostics

- **Options menu inspection:** `grep -n 'Show Info' SimPlex/components/screens/EpisodeScreen.brs` confirms the button is wired. If it doesn't appear at runtime, check that the `showEpisodeOptionsMenu()` function is being called (triggered by options key press in `onKeyEvent`).
- **Navigation signal:** When "Show Info" is selected, `m.top.itemSelected` emits `{ action: "detail", ratingKey: m.top.ratingKey, itemType: "show" }`. If DetailScreen opens for the wrong item, inspect `m.top.ratingKey` — it should be the show's ratingKey, not an episode's.
- **Fallthrough safety:** Cancel at index 2 has no explicit handler. Dialog close fires before index checks, and `m.episodeList.setFocus(true)` runs unconditionally at the end — so Cancel works correctly without a dedicated branch.

## Deviations

None. The plan matched the code structure exactly.

## Known Issues

None.

## Files Created/Modified

- `SimPlex/components/screens/EpisodeScreen.brs` — Added "Show Info" button to options menu and detail action handler at index 1
