---
id: T01
parent: S13
milestone: M001
provides:
  - Dynamic PosterGrid column count computed from gridWidth field
  - Search keyboard collapse/expand on focus transitions
  - Episode thumbnail grandparentThumb → parentThumb → thumb fallback in search results
key_files:
  - SimPlex/components/widgets/PosterGrid.brs
  - SimPlex/components/screens/SearchScreen.brs
key_decisions:
  - PosterGrid column count derived from gridWidth at runtime with floor guard (numColumns ≥ 1)
  - Keyboard collapse uses instant property assignment (no Animation nodes) to avoid SIGSEGV
  - Thumb field still stored on ContentNode for detail screen use; HDPosterUrl uses fallback chain separately
patterns_established:
  - PosterGrid observes its own gridWidth interface field for dynamic column recalculation — any parent can resize the grid at runtime
  - Search layout toggle pattern: hide/show keyboard + reposition grid/labels with instant translation/width changes
observability_surfaces:
  - m.grid.numColumns observable in SceneGraph inspector — reflects actual column count based on current gridWidth
  - m.keyboard.visible toggled on focus transitions — visible in SceneGraph inspector
  - ContentNode HDPosterUrl path indicates which thumb fallback was selected (grandparentThumb/parentThumb/thumb)
duration: 15m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T01: Fix search layout — keyboard collapse, grid expansion, and episode thumbnail priority

**PosterGrid now computes columns dynamically from gridWidth; SearchScreen collapses keyboard on right-nav and uses grandparentThumb→parentThumb→thumb fallback for episode posters**

## What Happened

Implemented three changes across two files:

1. **PosterGrid.brs — dynamic column count:** Replaced hardcoded `c.GRID_COLUMNS` with `Int(gridWidth / (POSTER_WIDTH + GRID_H_SPACING))` in `init()`. Added `onGridWidthChange` observer so column count recalculates when a parent changes gridWidth at runtime. Updated `onItemFocused` load-more threshold to use `m.grid.numColumns` instead of the constant. Added a `numColumns < 1` floor guard for safety.

2. **SearchScreen.brs — keyboard collapse/expand:** In `onKeyEvent()`, when `key = "right"` (focus to grid): hide keyboard, reposition grid to `[80, 200]`, set gridWidth to 1760, reposition searchQueryLabel/emptyState/retryGroup to centered positions. When `key = "left"` (focus to keyboard): reverse all changes. All using instant property assignment — no Animation nodes.

3. **SearchScreen.brs — episode thumbnail fallback:** In `processSearchResults()`, replaced the simple `item.thumb` → `HDPosterUrl` assignment with a grandparentThumb → parentThumb → thumb priority chain matching HomeScreen's `addHubRow()` pattern. Episodes now show the show poster instead of a stretched 16:9 screenshot.

**Math verification:**
- gridWidth=1620 (library default): 1620/260 = 6.23 → Int() = 6 columns ✓ (unchanged)
- gridWidth=1760 (expanded search): 1760/260 = 6.76 → Int() = 6 columns ✓
- gridWidth=1140 (search with keyboard): 1140/260 = 4.38 → Int() = 4 columns ✓

## Verification

All task-level and applicable slice-level verification checks pass:

- `grep -c "gridWidth" PosterGrid.brs` → 8 (≥3 required) ✓
- `grep -c "grandparentThumb" SearchScreen.brs` → 3 (≥1 required) ✓
- `grep -c "m.keyboard.visible" SearchScreen.brs` → 2 (≥2, one true + one false) ✓
- `grep "numColumns" PosterGrid.brs` shows calculation from gridWidth, not `c.GRID_COLUMNS` ✓
- No Animation nodes found in changed files ✓

Slice-level checks 1-2 (keyboard collapse/expand) and check 4 (episode poster fallback) are code-verified. Check 3 (collections auto-select) is T02 scope. Sideload verification deferred to device testing.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -c "gridWidth" SimPlex/components/widgets/PosterGrid.brs` | 0 | ✅ pass (8 ≥ 3) | <1s |
| 2 | `grep -c "grandparentThumb" SimPlex/components/screens/SearchScreen.brs` | 0 | ✅ pass (3 ≥ 1) | <1s |
| 3 | `grep -c "m.keyboard.visible" SimPlex/components/screens/SearchScreen.brs` | 0 | ✅ pass (2 ≥ 2) | <1s |
| 4 | `grep "numColumns" SimPlex/components/widgets/PosterGrid.brs` | 0 | ✅ pass (dynamic calc, no c.GRID_COLUMNS) | <1s |
| 5 | `grep -in "Animation" PosterGrid.brs SearchScreen.brs` (filtered) | 1 | ✅ pass (no Animation nodes) | <1s |

## Diagnostics

- **Column count:** Inspect `m.grid.numColumns` in SceneGraph inspector after navigating to Search and pressing right/left. Should toggle between 4 (keyboard visible) and 6 (keyboard hidden).
- **Keyboard state:** `m.keyboard.visible` in SceneGraph inspector shows current collapse state.
- **Thumbnail selection:** Check any search result ContentNode's `HDPosterUrl` — the URL path reveals which thumb was selected. Episode results should show `/grandparentThumb/` paths instead of `/thumb/` screenshot paths.
- **Load-more threshold:** If infinite scroll breaks, verify `m.grid.numColumns` returns a sensible value (should match visible column count).

## Deviations

- Added a `node.addFields({ thumb: item.thumb })` call to preserve the raw thumb on the ContentNode even though `HDPosterUrl` now uses the fallback chain. This keeps the original thumb available if the detail screen or other consumers need the episode-specific screenshot. The plan didn't mention this, but it avoids breaking existing field expectations.
- Added `numColumns < 1` floor guard in both init and observer handler — the plan didn't mention this edge case but it prevents a potential crash if gridWidth is ever 0 or negative.

## Known Issues

None.

## Files Created/Modified

- `SimPlex/components/widgets/PosterGrid.brs` — Dynamic column count from gridWidth with observer; load-more threshold uses m.grid.numColumns
- `SimPlex/components/screens/SearchScreen.brs` — Keyboard collapse/expand in onKeyEvent; grandparentThumb→parentThumb→thumb fallback in processSearchResults
- `.gsd/milestones/M001/slices/S13/S13-PLAN.md` — Added Observability / Diagnostics section and diagnostic verification checks (pre-flight fix)
- `.gsd/milestones/M001/slices/S13/tasks/T01-PLAN.md` — Added Observability Impact section (pre-flight fix)
