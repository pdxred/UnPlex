# S13: Search, Collections, and Thumbnails

**Goal:** Fix three independent UI bugs: search layout (keyboard collapse + dynamic column count), collections sidebar navigation (auto-select library), and episode thumbnail aspect ratios in search results.
**Demo:** Search → type query → press right: keyboard hides, grid expands to 6 columns. Press left: keyboard returns, grid shrinks to 4 columns. Tap "Collections" from Home (no library selected): collections load from first library. Search for a TV episode: poster shows portrait show artwork, not a stretched screenshot.

## Must-Haves

- Keyboard collapses when user navigates right to search results grid; grid expands to fill available width
- Keyboard reappears when user navigates left back from grid; grid shrinks to fit beside keyboard
- PosterGrid computes column count dynamically from its `gridWidth` field (not hardcoded to 6)
- Collections sidebar item works even when no library has been previously selected (auto-selects first library)
- Episode search results use grandparentThumb → parentThumb → thumb fallback chain for portrait poster artwork
- No Animation nodes used (SIGSEGV risk per S11/KNOWLEDGE.md)
- Existing library grid behavior unchanged (still 6 columns at default 1620px width)

## Verification

- Sideload to Roku and verify:
  1. Search → type → press right → keyboard disappears, grid fills screen (~6 columns)
  2. Press left → keyboard reappears, grid shrinks (~4 columns)
  3. From Home hub (no library selected), tap Collections → loads collections from first library
  4. Search for a known TV episode → poster shows portrait artwork (show poster), not stretched screenshot
- Code review: `grep -n "numColumns" SimPlex/components/widgets/PosterGrid.brs` shows column calculation from gridWidth
- Code review: `grep -n "grandparentThumb\|parentThumb" SimPlex/components/screens/SearchScreen.brs` shows thumb fallback chain
- Code review: `grep -n "libraries" SimPlex/components/widgets/Sidebar.xml` shows new interface field

## Tasks

- [ ] **T01: Fix search layout — keyboard collapse, grid expansion, and episode thumbnail priority** `est:25m`
  - Why: Addresses FIX-05 (search results occlude controls / not navigable) and FIX-06 (episode thumbnails stretched). Both fixes modify SearchScreen.brs (different functions) and PosterGrid.brs.
  - Files: `SimPlex/components/screens/SearchScreen.brs`, `SimPlex/components/widgets/PosterGrid.brs`
  - Do: (1) In PosterGrid.brs init(), compute numColumns from gridWidth field instead of hardcoded GRID_COLUMNS. Add gridWidth observer to recalculate on dynamic changes. (2) In SearchScreen.brs onKeyEvent(), when focus moves right to grid: hide keyboard, reposition grid to x=80, set gridWidth to ~1760, reposition searchQueryLabel. When focus moves left to keyboard: show keyboard, reposition grid to x=700, set gridWidth to 1140, reposition searchQueryLabel. Use instant property changes only (no Animation nodes). (3) In SearchScreen.brs processSearchResults(), apply grandparentThumb → parentThumb → thumb fallback chain (same pattern as HomeScreen addHubRow).
  - Verify: `grep -c "gridWidth" SimPlex/components/widgets/PosterGrid.brs` returns ≥3 (field read + observer + handler). `grep -c "grandparentThumb" SimPlex/components/screens/SearchScreen.brs` returns ≥1.
  - Done when: PosterGrid dynamically computes columns from gridWidth, SearchScreen collapses/expands keyboard on focus transitions, and episode search results use portrait poster thumbs.

- [ ] **T02: Fix collections navigation — auto-select first library when none active** `est:15m`
  - Why: Addresses FIX-04 (collections menu item silently fails when no library selected). Requires exposing Sidebar's loaded libraries to HomeScreen.
  - Files: `SimPlex/components/widgets/Sidebar.xml`, `SimPlex/components/widgets/Sidebar.brs`, `SimPlex/components/screens/HomeScreen.brs`
  - Do: (1) Add `libraries` assocarray field to Sidebar.xml interface. (2) In Sidebar.brs processLibraries(), after building m.libraries array, set m.top.libraries to expose it. (3) In HomeScreen.brs onSpecialAction("viewCollections"), when m.currentSectionId is empty, read m.sidebar.libraries to get the first library's sectionId/sectionType, set m.currentSectionId and m.currentSectionType, then proceed with loadCollections(). Guard against empty libraries (fetch still loading).
  - Verify: `grep -c "libraries" SimPlex/components/widgets/Sidebar.xml` returns ≥1. `grep -n "m.sidebar.libraries\|m.top.libraries" SimPlex/components/widgets/Sidebar.brs SimPlex/components/screens/HomeScreen.brs` shows wiring.
  - Done when: Tapping "Collections" from Home hub view (no library previously selected) loads collections from the first available library.

## Files Likely Touched

- `SimPlex/components/screens/SearchScreen.brs`
- `SimPlex/components/widgets/PosterGrid.brs`
- `SimPlex/components/widgets/Sidebar.xml`
- `SimPlex/components/widgets/Sidebar.brs`
- `SimPlex/components/screens/HomeScreen.brs`
