---
id: T01
parent: S14
milestone: M001
provides:
  - TV show grid/hub selection routes to EpisodeScreen via action "episodes"
  - "Show Info" option in HomeScreen context menu for shows routes to DetailScreen
key_files:
  - SimPlex/components/screens/HomeScreen.brs
key_decisions:
  - Show-type check uses itemType = "show" with fallthrough to detail for non-matching items (safe degradation)
patterns_established:
  - Options menu button index shifts when extra buttons are inserted for specific item types — cancel handler uses restoreFocusAfterDialog at function end rather than specific index check
observability_surfaces:
  - "grep -c 'action.*episodes' SimPlex/components/screens/HomeScreen.brs" confirms routing wiring (expected: 2)
  - m.pendingOptionsItem.itemType at dialog selection time reveals which path was taken
duration: 12m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T01: Route TV shows to EpisodeScreen from HomeScreen grid and hub rows

**TV show selections in library grid and hub rows now emit action "episodes" to open EpisodeScreen directly; options key on shows offers "Show Info" to reach DetailScreen.**

## What Happened

Modified four functions in HomeScreen.brs:

1. **`onHubItemSelected`** — Added `else if itemContent.itemType = "show"` branch between the continue-watching play action and the default detail action. Shows now emit `{ action: "episodes", ratingKey, title }`.

2. **`onGridItemSelected`** — Added `if item.itemType = "show"` check before the catch-all detail emission (after collection, playlist, and resume-dialog early returns). Shows emit episodes action; everything else still emits detail.

3. **`showOptionsMenu`** — For show items, the dialog buttons array becomes `[watchedLabel, "Show Info", "Cancel"]` instead of `[watchedLabel, "Cancel"]`.

4. **`onOptionsMenuButton`** — Added `else if index = 1 and m.pendingOptionsItem.itemType = "show"` handler that emits `{ action: "detail", ratingKey, itemType: "show" }`. The cancel button (now index 2 for shows) doesn't need explicit handling — `restoreFocusAfterDialog()` runs unconditionally at the end.

MainScene was NOT modified — it already handles both `action: "episodes"` (line 445) and `action: "detail"` (line 443).

## Verification

All T01 verification checks pass:
- `grep -c "action.*episodes"` returns 2 (grid + hub routing) ✅
- `grep -c "Show Info"` returns 2 (button label + handler comment) ✅
- No `CreateObject.*Animation` matches — no Animation nodes introduced ✅
- MainScene lines 443/445 unchanged ✅
- `action.*detail` still present (4 occurrences — non-show grid, non-show hub, resume dialog "Go to Details", and "Show Info" handler) ✅

T02 checks (EpisodeScreen) expectedly not passing yet — that's the next task.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -c 'action.*episodes' SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (2) | <1s |
| 2 | `grep -c 'Show Info' SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (2) | <1s |
| 3 | `grep -c 'CreateObject.*Animation' SimPlex/components/screens/HomeScreen.brs` | 1 | ✅ pass (0 matches) | <1s |
| 4 | `grep -n 'action.*episodes\|action.*detail' SimPlex/components/MainScene.brs` | 0 | ✅ pass (lines 443, 445) | <1s |
| 5 | `grep -c 'action.*detail' SimPlex/components/screens/HomeScreen.brs` | 0 | ✅ pass (4 — non-show paths preserved) | <1s |

## Diagnostics

- **Routing inspection:** `grep -n 'action.*episodes' SimPlex/components/screens/HomeScreen.brs` shows exactly where show routing is wired.
- **Options menu:** If "Show Info" doesn't appear, check that `m.pendingOptionsItem.itemType` equals `"show"` — the button is only added for show items.
- **Fallthrough behavior:** Items without `itemType = "show"` route to `action: "detail"` — this is intentional safe degradation, not a bug.

## Deviations

None. The plan matched the code structure exactly.

## Known Issues

None.

## Files Created/Modified

- `SimPlex/components/screens/HomeScreen.brs` — Added show-specific routing in onGridItemSelected and onHubItemSelected (episodes action), plus "Show Info" in options menu for shows
- `.gsd/milestones/M001/slices/S14/S14-PLAN.md` — Added Observability / Diagnostics section, failure-path verification check, marked T01 done
- `.gsd/milestones/M001/slices/S14/tasks/T01-PLAN.md` — Added Observability Impact section
