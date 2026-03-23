---
estimated_steps: 5
estimated_files: 2
skills_used: []
---

# T01: Fix search layout — keyboard collapse, grid expansion, and episode thumbnail priority

**Slice:** S13 — Search, Collections, and Thumbnails
**Milestone:** M001

## Description

Fix two SearchScreen bugs (FIX-05, FIX-06) and one PosterGrid bug. Currently: (1) when the user presses right to move focus from the keyboard to search results, the keyboard stays visible and the grid stays cramped at 1140px with 6 hardcoded columns that overflow; (2) episode search results display the episode screenshot (16:9) forced into a portrait poster slot, causing severe distortion.

The fix has three parts:
- Make PosterGrid compute its column count dynamically from its `gridWidth` interface field instead of hardcoding `c.GRID_COLUMNS` (6).
- Add keyboard collapse/expand behavior in SearchScreen — when focus moves right to the results grid, hide the Keyboard node and expand the grid to fill the screen; when focus moves left back to the keyboard, restore the original layout.
- Apply the grandparentThumb → parentThumb → thumb poster fallback chain in SearchScreen's `processSearchResults()` function, matching the existing pattern in HomeScreen's `addHubRow()`.

## Steps

1. **PosterGrid.brs — dynamic column count from gridWidth.** In `init()`, replace `m.grid.numColumns = c.GRID_COLUMNS` with a calculation: `numColumns = Int(m.top.gridWidth / (c.POSTER_WIDTH + c.GRID_H_SPACING))`. Then `m.grid.numColumns = numColumns`. Also add an `observeField("gridWidth", "onGridWidthChange")` observer in init(), and create a `sub onGridWidthChange()` handler that recalculates and sets `m.grid.numColumns` the same way. Also update the `onItemFocused` load-more threshold to use the dynamic column count instead of `c.GRID_COLUMNS`:
   ```brightscript
   itemsPerRow = m.grid.numColumns
   ```
   **Math check:** Default gridWidth=1620, POSTER_WIDTH=240, GRID_H_SPACING=20 → 1620/260=6.23 → Int()=6. ✓ Existing library grids unchanged.

2. **SearchScreen.brs — keyboard collapse/expand in onKeyEvent().** When `key = "right" and m.focusOnKeyboard` (focus moving to grid):
   - Set `m.keyboard.visible = false`
   - Set `m.resultsGrid.translation = [80, 200]`
   - Set `m.resultsGrid.gridWidth = 1760` (1920 - 80 left padding - 80 right padding)
   - Set `m.searchQueryLabel.translation = [80, 120]`
   - Set `m.emptyState.translation = [960, 440]` (re-center empty state)
   
   When `key = "left" and not m.focusOnKeyboard` (focus moving back to keyboard):
   - Set `m.keyboard.visible = true`
   - Set `m.resultsGrid.translation = [700, 200]`
   - Set `m.resultsGrid.gridWidth = 1140`
   - Set `m.searchQueryLabel.translation = [700, 120]`
   - Set `m.emptyState.translation = [1270, 440]` (original position)
   
   **Critical:** Use only instant property changes — NO Animation nodes (SIGSEGV risk per KNOWLEDGE.md). The `m.focusOnKeyboard` flag and `setFocus()` calls already exist in the current code — add the layout changes around them.

3. **SearchScreen.brs — episode thumbnail fallback in processSearchResults().** Replace the simple thumb check:
   ```brightscript
   if item.thumb <> invalid and item.thumb <> ""
       node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
   end if
   ```
   With the same priority chain used in HomeScreen.addHubRow():
   ```brightscript
   posterThumb = invalid
   if item.grandparentThumb <> invalid and item.grandparentThumb <> ""
       posterThumb = item.grandparentThumb
   else if item.parentThumb <> invalid and item.parentThumb <> ""
       posterThumb = item.parentThumb
   else if item.thumb <> invalid and item.thumb <> ""
       posterThumb = item.thumb
   end if
   if posterThumb <> invalid
       node.HDPosterUrl = BuildPosterUrl(posterThumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
   end if
   ```
   This ensures episodes show the show poster (grandparentThumb) or season poster (parentThumb) instead of the landscape episode screenshot.

4. **SearchScreen.brs — also update the emptyState/retryGroup repositioning.** The `retryGroup` also needs to reposition when keyboard collapses/expands. In the same onKeyEvent blocks:
   - Keyboard hidden: `m.retryGroup.translation = [960, 440]`
   - Keyboard visible: `m.retryGroup.translation = [1270, 440]`

5. **Verify** the math and code by reviewing the final files. Confirm:
   - PosterGrid with default gridWidth=1620 still produces 6 columns
   - PosterGrid with gridWidth=1760 produces Int(1760/260) = 6 columns
   - PosterGrid with gridWidth=1140 produces Int(1140/260) = 4 columns

## Must-Haves

- [ ] PosterGrid.brs computes numColumns from gridWidth field (not hardcoded GRID_COLUMNS)
- [ ] PosterGrid.brs observes gridWidth changes and recalculates columns dynamically
- [ ] SearchScreen.brs hides keyboard and expands grid when focus moves right to results
- [ ] SearchScreen.brs shows keyboard and shrinks grid when focus moves left
- [ ] No Animation nodes used anywhere in the changes
- [ ] SearchScreen.brs processSearchResults() uses grandparentThumb → parentThumb → thumb fallback
- [ ] PosterGrid load-more threshold uses dynamic column count, not hardcoded GRID_COLUMNS

## Verification

- `grep -c "gridWidth" SimPlex/components/widgets/PosterGrid.brs` returns ≥3
- `grep -c "grandparentThumb" SimPlex/components/screens/SearchScreen.brs` returns ≥1
- `grep -c "m.keyboard.visible" SimPlex/components/screens/SearchScreen.brs` returns ≥2 (one true, one false)
- `grep "numColumns" SimPlex/components/widgets/PosterGrid.brs` shows calculation from gridWidth, not `c.GRID_COLUMNS`

## Inputs

- `SimPlex/components/screens/SearchScreen.brs` — current search screen with no keyboard collapse and simple thumb assignment
- `SimPlex/components/screens/SearchScreen.xml` — layout reference for initial positions (x=700 for grid, x=80 for keyboard)
- `SimPlex/components/widgets/PosterGrid.brs` — current grid with hardcoded GRID_COLUMNS
- `SimPlex/components/widgets/PosterGrid.xml` — gridWidth field declaration (default 1620)
- `SimPlex/source/constants.brs` — POSTER_WIDTH=240, POSTER_HEIGHT=360, GRID_COLUMNS=6, GRID_H_SPACING=20

## Expected Output

- `SimPlex/components/widgets/PosterGrid.brs` — dynamic column count from gridWidth with observer
- `SimPlex/components/screens/SearchScreen.brs` — keyboard collapse/expand in onKeyEvent + thumb fallback in processSearchResults

## Observability Impact

- **New signal:** `m.grid.numColumns` is now dynamically computed and observable in SceneGraph inspector — reflects actual column count based on current gridWidth rather than a static constant.
- **New signal:** `m.keyboard.visible` is toggled on focus transitions — visible in SceneGraph inspector and Roku debug console focus chain output.
- **Inspection surface:** When debugging thumbnail selection, inspect any search result ContentNode's `HDPosterUrl` — the URL path will contain `/grandparentThumb/`, `/parentThumb/`, or `/thumb/` indicating which fallback was selected.
- **Failure state:** If gridWidth is set to 0 or negative, `Int()` will produce 0 columns. The code guards against this by only recalculating when gridWidth > 0.
- **No new error paths:** All changes are UI layout adjustments and data mapping — no new HTTP calls or async flows introduced.
