---
id: S13
milestone: M001
status: done
completed_at: 2026-03-23
tasks_completed: [T01, T02]
requirements_validated: [FIX-04, FIX-05, FIX-06]
---

# S13: Search, Collections, and Thumbnails

**Fixed three independent UI bugs: search keyboard collapse/expand with dynamic grid columns, collections auto-select when no library active, and episode thumbnail fallback for portrait posters in search results.**

## What Was Delivered

### 1. Dynamic PosterGrid Column Count (T01)

PosterGrid no longer hardcodes column count from `c.GRID_COLUMNS`. It computes columns at runtime: `Int(gridWidth / (POSTER_WIDTH + GRID_H_SPACING))` with a `numColumns ≥ 1` floor guard. A `gridWidth` observer recalculates on dynamic resize. The load-more threshold in `onItemFocused` uses `m.grid.numColumns` instead of the constant.

**Column math:** 1620px → 6 cols (library default, unchanged), 1760px → 6 cols (expanded search), 1140px → 4 cols (search with keyboard).

### 2. Search Keyboard Collapse/Expand (T01)

SearchScreen.brs `onKeyEvent()` toggles the keyboard on left/right navigation:
- **Right (to grid):** Hide keyboard, reposition grid to x=80, set gridWidth=1760, reposition labels/empty-state/retry.
- **Left (to keyboard):** Show keyboard, reposition grid to x=700, set gridWidth=1140, reposition labels back.

All repositioning uses instant property assignment — no Animation nodes (SIGSEGV-safe per S11 rule).

### 3. Episode Thumbnail Fallback (T01)

`processSearchResults()` now applies grandparentThumb → parentThumb → thumb fallback for `HDPosterUrl`, matching the existing HomeScreen `addHubRow()` pattern. Episodes show the portrait show poster instead of a stretched 16:9 screenshot. The raw `thumb` is still stored on the ContentNode for detail screen use.

### 4. Collections Auto-Select First Library (T02)

Sidebar.xml gained a `libraries` interface field (assocarray with `items` array). Sidebar.brs `processLibraries()` populates it after building the library list. HomeScreen.brs `onSpecialAction("viewCollections")` checks `m.currentSectionId` — if empty, reads `m.sidebar.libraries` to auto-select the first library's sectionId/sectionType, then proceeds with `loadCollections()`. Guarded against empty/pending library fetch (tap is a safe no-op). Diagnostic print fires on auto-select.

## Patterns Established

- **PosterGrid dynamic resize:** Any parent can change `gridWidth` at runtime and PosterGrid recalculates columns automatically via observer. Use this pattern for any future layout that needs responsive grids.
- **Sidebar.libraries interface field:** Cross-component access to loaded library metadata without reaching into Sidebar internals. Read-only assocarray, populated after API response.
- **Search layout toggle:** Hide/show keyboard + reposition grid/labels with instant translation/width changes. No animations needed for layout state transitions on Roku.

## Key Decisions

- PosterGrid column count derived from gridWidth at runtime with floor guard — no hardcoded constant.
- Keyboard collapse uses instant property assignment only (no Animation nodes) to avoid SIGSEGV risk.
- Libraries exposed as assocarray (not ContentNode) for simplicity and cross-component readability.
- Raw `thumb` preserved on ContentNode alongside fallback `HDPosterUrl` to avoid breaking detail screen expectations.

## Files Modified

| File | Changes |
|------|---------|
| `SimPlex/components/widgets/PosterGrid.brs` | Dynamic column count from gridWidth with observer; load-more uses m.grid.numColumns |
| `SimPlex/components/screens/SearchScreen.brs` | Keyboard collapse/expand in onKeyEvent; grandparentThumb→parentThumb→thumb fallback |
| `SimPlex/components/widgets/Sidebar.xml` | Added `libraries` assocarray interface field |
| `SimPlex/components/widgets/Sidebar.brs` | Populate m.top.libraries in processLibraries() |
| `SimPlex/components/screens/HomeScreen.brs` | Auto-select first library for collections when none active |

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "gridWidth" PosterGrid.brs` → 8 (≥3 required) | ✅ |
| `grep -c "grandparentThumb\|parentThumb" SearchScreen.brs` → 5 (≥1 required) | ✅ |
| `grep -c "libraries" Sidebar.xml` → 1 (≥1 required) | ✅ |
| `grep -n "numColumns" PosterGrid.brs` — dynamic calc, no GRID_COLUMNS | ✅ |
| `grep -c "m.keyboard.visible" SearchScreen.brs` → 2 (true + false) | ✅ |
| `grep -n "m.sidebar.libraries\|m.top.libraries"` — wiring confirmed | ✅ |
| No Animation nodes in changed files | ✅ |

## What the Next Slice Should Know

- **PosterGrid is now width-responsive.** If S14 (TV Show Navigation) introduces new grid layouts, set `gridWidth` on PosterGrid and columns adapt automatically. No need to hardcode column counts.
- **Sidebar.libraries is available.** Any screen that needs the library list can read it from the Sidebar interface field. It's an assocarray `{ items: [...] }` where each item has `key`, `title`, `type` (section metadata).
- **Search layout has two states.** `m.keyboard.visible` tracks which state is active. If adding new elements to SearchScreen, they need positioning for both keyboard-visible and keyboard-hidden states.
- **Episode thumb fallback is search-only.** HomeScreen hub rows already had this pattern. Library grids don't need it (they show show-level posters by default). If other screens start showing mixed content types, apply the same grandparentThumb → parentThumb → thumb chain.

## Known Issues

None introduced. All changes are backward-compatible with existing library grid behavior (6 columns at 1620px default width).
