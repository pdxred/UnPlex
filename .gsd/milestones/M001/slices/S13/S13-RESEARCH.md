# S13 Research: Search, Collections, and Thumbnails

**Slice:** S13 — Search, Collections, and Thumbnails
**Milestone:** M001 — SimPlex v1.1 Polish & Navigation
**Researched:** 2026-03-23
**Confidence:** HIGH — all findings from live codebase inspection, no speculation
**Depth:** Targeted — known technology, known codebase, three distinct bug fixes

## Summary

S13 contains three independent bug fixes in SearchScreen, HomeScreen (collections routing), and SearchScreen/PosterGridItem (thumbnail aspect ratios). All three are well-scoped with clear root causes identified in the code. No new components are needed — all changes modify existing files. The three fixes are independent of each other and can be worked in parallel or any order.

## Requirements Addressed

| Requirement | Description | Role |
|-------------|-------------|------|
| **FIX-04** | Collections menu item navigates to collections browsing screen | Primary fix — remove library-selection prerequisite |
| **FIX-05** | Search results display without occluding search controls and are navigable | Primary fix — keyboard collapse + dynamic column count |
| **FIX-06** | Thumbnail aspect ratio adapts based on image type | Primary fix — use parentThumb for episodes in search results |

## Recommendation

Implement all three fixes as separate tasks (they touch different files/subsections). No new components or architecture changes needed. All fixes are surgical edits to existing code.

## Implementation Landscape

### Fix 1: Search Layout — Keyboard Collapse and Dynamic Column Count

**Root Cause Analysis:**

Two separate problems in SearchScreen:

1. **No keyboard collapse behavior.** When the user presses `right` to move focus to the results grid (line 240-242 of SearchScreen.brs), the code sets `m.focusOnKeyboard = false` and calls `m.resultsGrid.setFocus(true)` — but the keyboard node stays visible and the grid stays at x=700 with gridWidth=1140. The grid never expands.

2. **PosterGrid ignores its `gridWidth` field.** PosterGrid.xml declares an interface field `gridWidth` (default 1620), and SearchScreen.xml passes `gridWidth="1140"`. But PosterGrid.brs `init()` ignores this field entirely — it always sets `m.grid.numColumns = c.GRID_COLUMNS` (6). With 6 columns × 260px each = 1560px, this overflows the 1140px available space, causing items to clip or overlap.

**What the fix needs to do:**

A. **SearchScreen.brs** — Add keyboard collapse/expand behavior:
   - When `m.focusOnKeyboard` changes to `false`: hide the Keyboard node, reposition the grid to x=80 (where keyboard was), expand gridWidth to ~1760px (1920 - 80 - 80 padding).
   - When `m.focusOnKeyboard` changes to `true`: show the Keyboard node, reposition the grid back to x=700, set gridWidth back to 1140.
   - Move the `searchQueryLabel` to stay above the grid in both states (collapsed: x=80, expanded: x=700).

B. **PosterGrid.brs** — Compute `numColumns` from `gridWidth`:
   - In `init()`, after reading constants, compute: `numColumns = Int(m.top.gridWidth / (c.POSTER_WIDTH + c.GRID_H_SPACING))`
   - Set `m.grid.numColumns = numColumns`
   - Also observe `gridWidth` field changes so that when SearchScreen updates `gridWidth` dynamically, the grid reconfigures.

**Current layout math:**
- Keyboard visible: grid starts at x=700, available width = 1920 - 700 = 1220. Grid set to 1140px. With 260px per column → **4 columns** fit.
- Keyboard hidden: grid starts at x=80, available width = 1920 - 80 = 1840. With 260px per column → **7 columns** fit, but 6 is standard and matches the library grid.

**Files affected:**
- `SimPlex/components/screens/SearchScreen.brs` — add collapse/expand logic in `onKeyEvent()` when focus transitions
- `SimPlex/components/screens/SearchScreen.xml` — no changes (layout positions are initial defaults, BRS overrides at runtime)
- `SimPlex/components/widgets/PosterGrid.brs` — compute numColumns from gridWidth, observe gridWidth changes

**Constraint:** The `searchQueryLabel` (showing "Search: {query}") currently sits at translation [700, 120]. When the keyboard collapses, it should move to show the current query at the top of the expanded grid area. When the keyboard is visible again, it returns.

**Constraint:** Keyboard collapse should NOT use Animation nodes (SIGSEGV risk from S11 findings). Use instant property changes (translation, visible) rather than animated transitions.

### Fix 2: Collections Sidebar Navigation

**Root Cause Analysis:**

In `Sidebar.brs`, "Collections" is a global nav item (alongside Home, Playlists, Search, Settings). When selected, it emits `m.top.specialAction = "viewCollections"`. HomeScreen's `onSpecialAction()` handler (line 507-516) guards collections with:

```brightscript
if m.currentSectionId <> ""
    m.isCollectionsView = true
    ...
    loadCollections()
```

The problem: `m.currentSectionId` starts as `""` (line 47) and is only set when a user selects a specific library from the sidebar. If the user taps "Collections" without first selecting a library, nothing happens — the guard silently returns.

The Plex `/library/sections/{id}/collections` endpoint is library-specific — there is no global `/library/collections` endpoint. So collections are inherently per-library.

**What the fix needs to do:**

Two viable approaches:

**Option A (Recommended): Auto-select the first library when Collections is tapped with no library selected.**
- In `onSpecialAction`, when `action = "viewCollections"` and `m.currentSectionId = ""`:
  - Read `m.sidebar` libraries list (available via `m.sidebar.findNode("navList")` content)
  - Or: store a reference to loaded libraries in a place accessible to HomeScreen
  - Pick the first movie library's sectionId
  - Set `m.currentSectionId` to it
  - Proceed with `loadCollections()`
- Sidebar already loads libraries in `processLibraries()` and stores them in local `m.libraries`. HomeScreen needs access to this — either via a new Sidebar interface field or by HomeScreen also fetching `/library/sections`.

**Simpler sub-approach:** Sidebar already emits `selectedLibrary` when a library is tapped (with sectionId, sectionType, title). HomeScreen can track `m.lastLibraryId` set from `onLibrarySelected()`. Then in `viewCollections`, use `m.lastLibraryId` if `m.currentSectionId` is empty. But this doesn't help on fresh launch where no library has been visited.

**Best sub-approach:** Add a `libraries` interface field to Sidebar that exposes the loaded library list. In HomeScreen's `onSpecialAction("viewCollections")`, if `m.currentSectionId = ""`, read `m.sidebar.libraries` and pick the first one.

**Option B: Show a library picker dialog.** When Collections is tapped without a library selected, show a dialog asking the user to pick a library first. This adds complexity and a dialog step.

**Recommended: Option A** — auto-select first library. It's the least friction for the user.

**Files affected:**
- `SimPlex/components/widgets/Sidebar.xml` — add `libraries` field to interface
- `SimPlex/components/widgets/Sidebar.brs` — set `m.top.libraries` after `processLibraries()`
- `SimPlex/components/screens/HomeScreen.brs` — update `onSpecialAction("viewCollections")` to auto-select library

### Fix 3: Episode Thumbnail Aspect Ratios in Search Results

**Root Cause Analysis:**

In `SearchScreen.brs` `processSearchResults()` (lines 140-141):
```brightscript
if item.thumb <> invalid and item.thumb <> ""
    node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
end if
```

For episode search results, `item.thumb` is the episode's screenshot (16:9 landscape). This gets forced into a 240×360 portrait PosterGridItem, causing severe distortion (stretched vertically).

The Plex search API returns these fields for episodes:
- `item.thumb` — episode screenshot (16:9)
- `item.parentThumb` — season poster (2:3 portrait)
- `item.grandparentThumb` — show poster (2:3 portrait)

**Compare with hub rows:** HomeScreen's `addHubRow()` (line ~298-308) already has the correct pattern:
```brightscript
posterThumb = invalid
if item.grandparentThumb <> invalid and item.grandparentThumb <> ""
    posterThumb = item.grandparentThumb
else if item.parentThumb <> invalid and item.parentThumb <> ""
    posterThumb = item.parentThumb
else if item.thumb <> invalid and item.thumb <> ""
    posterThumb = item.thumb
end if
```

**What the fix needs to do:**

Apply the same thumb priority logic from `addHubRow()` to `SearchScreen.processSearchResults()`:
- For episodes: prefer `grandparentThumb` (show poster) → `parentThumb` (season poster) → `thumb` (episode screenshot)
- For movies/shows: `thumb` is already correct (it's a poster)

This ensures all PosterGridItem items display portrait-format artwork.

**Files affected:**
- `SimPlex/components/screens/SearchScreen.brs` — update `processSearchResults()` to use the grandparentThumb → parentThumb → thumb fallback chain

**One-line scope note:** The milestone research (M001-RESEARCH.md) mentions this as FIX-06 with broader scope: "detect whether Plex is serving a poster vs screen grab and size accordingly." The simpler and more correct fix is to always prefer the portrait poster thumb for PosterGrid items, which is what this fix does. The broader "detect and resize" approach would require PosterGridItem to support two layout modes (portrait and landscape), which is significantly more complex and not needed — search results look correct when all items use portrait posters.

## File-Level Impact Map

| File | Change Type | Scope |
|------|-------------|-------|
| `SearchScreen.brs` | Modify | Keyboard collapse/expand logic + thumbnail priority fix |
| `SearchScreen.xml` | No change | Layout positions are initial defaults, overridden at runtime |
| `PosterGrid.brs` | Modify | Compute numColumns from gridWidth field; observe gridWidth changes |
| `PosterGrid.xml` | No change | gridWidth field already declared |
| `Sidebar.xml` | Modify | Add `libraries` interface field |
| `Sidebar.brs` | Modify | Set `m.top.libraries` after library fetch |
| `HomeScreen.brs` | Modify | Auto-select library for collections when no library active |

## Task Boundaries

The three fixes are fully independent:

1. **Task: Search Layout** — SearchScreen.brs + PosterGrid.brs. Keyboard collapse/expand and dynamic column count.
2. **Task: Collections Navigation** — Sidebar.xml + Sidebar.brs + HomeScreen.brs. Expose libraries, auto-select for collections.
3. **Task: Episode Thumbnails** — SearchScreen.brs only. Thumb priority chain in processSearchResults().

Tasks 1 and 3 both touch SearchScreen.brs but in different functions (onKeyEvent area vs processSearchResults). They can be sequenced as T1→T3 or merged into a single SearchScreen task.

**Suggested ordering:** Task 3 (smallest, ~5 lines) → Task 2 (moderate, ~15 lines across 3 files) → Task 1 (largest, ~40 lines across 2 files). Or: combine Tasks 1+3 into a single "Search fixes" task since both modify SearchScreen.brs.

## Verification Strategy

Each fix can be verified by sideloading to Roku and checking:

1. **Search Layout:** Navigate to Search → type query → press right to move to results. Keyboard should disappear, grid should expand to fill the screen width. Press left → keyboard returns, grid shrinks. Column count should match available width (4 with keyboard, 6 without).

2. **Collections:** From the Home hub view (no library selected), tap "Collections" in sidebar. Should load collections from the first available library (not silently fail).

3. **Episode Thumbnails:** Search for a known TV episode title. All search result posters should show portrait artwork (show/season poster), not stretched landscape screenshots.

## Constraints and Risks

- **No Animation nodes** — keyboard collapse must use instant property changes, not SceneGraph Animation (SIGSEGV risk per S11).
- **PosterGrid numColumns change affects HomeScreen too** — if PosterGrid.brs now computes from gridWidth, HomeScreen's library view (which uses gridWidth=1620 default) must still get 6 columns. Math: 1620 / 260 = 6.23 → Int() = 6. ✓ This is correct and unchanged.
- **HomeScreen `onViewModeChanged()` overrides grid numColumns directly** (line ~531-538). This code sets `gridNode.numColumns = 6` for library view. If PosterGrid.brs also observes gridWidth changes, these two mechanisms must not conflict. The HomeScreen override is fine because it directly sets the inner MarkupGrid's numColumns — it bypasses PosterGrid.brs entirely.
- **Sidebar `libraries` field timing** — libraries are fetched asynchronously in Sidebar.init(). If the user taps "Collections" before libraries finish loading, `m.sidebar.libraries` will be empty. HomeScreen should guard against this (show a brief "Loading libraries..." message or do nothing, which matches current behavior).

---
*Research completed: 2026-03-23*
*Ready for planning: yes*
