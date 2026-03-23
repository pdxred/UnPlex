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

- [x] **T01: Fix search layout — keyboard collapse, grid expansion, and episode thumbnail priority** `est:25m`
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

## Observability / Diagnostics

- **Search layout state:** The keyboard collapse/expand is driven by `m.focusOnKeyboard` boolean and `m.keyboard.visible`. On-device, inspect the Roku developer console for SceneGraph focus chain to verify which node holds focus after right/left navigation.
- **Dynamic column count:** PosterGrid's `m.grid.numColumns` is observable via the SceneGraph inspector — verify it changes from 4→6 when gridWidth transitions between 1140→1760.
- **Thumbnail fallback chain:** If search results show wrong thumbnails, inspect the ContentNode's `HDPosterUrl` field in SceneGraph inspector to see which thumb path was chosen. The fallback priority (grandparentThumb→parentThumb→thumb) determines whether the URL points to a show poster or episode screenshot.
- **Collections auto-select:** If collections fail to load when no library is selected, the `m.currentSectionId` will be empty string. The fix writes a diagnostic `print` when auto-selecting the first library so it appears in the Roku debug console.
- **Failure visibility:** Search errors surface via `StandardMessageDialog` (first attempt retries silently, second shows dialog). Inline retry group becomes visible on dismiss. All error paths are already covered by S10 resilience — no new failure modes introduced.
- **Redaction:** No auth tokens or user data are logged; only library section IDs and search query lengths.

## Verification (Diagnostics)

- Code review: `grep -n "m.keyboard.visible" SimPlex/components/screens/SearchScreen.brs` shows both `true` and `false` assignments (collapse/expand)
- Code review: `grep -n "m.grid.numColumns" SimPlex/components/widgets/PosterGrid.brs` shows dynamic calculation, not hardcoded constant
- Sideload and trigger a search error (disconnect PMS): verify inline retry group repositions correctly when keyboard is collapsed vs expanded

## Files Likely Touched

- `SimPlex/components/screens/SearchScreen.brs`
- `SimPlex/components/widgets/PosterGrid.brs`
- `SimPlex/components/widgets/Sidebar.xml`
- `SimPlex/components/widgets/Sidebar.brs`
- `SimPlex/components/screens/HomeScreen.brs`
