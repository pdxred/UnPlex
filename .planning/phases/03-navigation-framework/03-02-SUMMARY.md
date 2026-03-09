---
phase: 03-navigation-framework
plan: 02
subsystem: navigation
tags: [rowlist, hub-rows, focus-management, auto-refresh, sidebar-toggle, progress-bar]

dependency_graph:
  requires:
    - phase: 01-infrastructure
      provides: BrighterScript toolchain, constants caching, PlexApiTask
  provides:
    - Hub row rendering via RowList with /hubs API integration
    - Hub item selection (play vs detail routing)
    - Three-zone focus management (sidebar, hubs, grid)
    - Auto-refresh timer and refresh-on-return
    - Sidebar view toggle (hubGrid vs libraryOnly)
    - PosterGridItem progress bar overlay
  affects:
    - Phase 02 (playback -- play action routing needs VideoPlayer wiring)
    - Future phases that add screens (follow cleanup pattern)

tech_stack:
  added: []
  patterns:
    - RowList with dynamic numRows and ContentNode tree for hub rows
    - Three-zone focus management via m.focusArea state variable
    - Timer node for periodic data refresh
    - View mode toggle via m.viewMode with visibility and repositioning

key_files:
  created: []
  modified:
    - SimPlex/components/screens/HomeScreen.xml
    - SimPlex/components/screens/HomeScreen.brs
    - SimPlex/components/widgets/PosterGridItem.xml
    - SimPlex/components/widgets/PosterGridItem.brs
    - SimPlex/components/widgets/Sidebar.brs
    - SimPlex/components/MainScene.brs

key_decisions:
  - "Hub rows use single /hubs API call with client-side hubIdentifier filtering"
  - "Three-zone focus model (sidebar/hubs/grid) replaces binary focusOnSidebar boolean"
  - "Play action routes to detail screen until VideoPlayer is wired in playback phase"
  - "Sidebar hub section replaced with single Home item for view toggle"

patterns_established:
  - "RowList numRows set BEFORE content assignment to prevent layout bugs"
  - "Scroll position preservation via savedHubFocus/jumpToRowItem on refresh"
  - "View mode toggle via visibility + repositioning (no content destruction)"

requirements-completed: [HOME-01, HOME-02, HOME-03]

duration: 4min
completed: 2026-03-09
---

# Phase 03 Plan 02: Hub Row Interactions Summary

**Interactive hub rows with item selection, three-zone focus management, 2-minute auto-refresh, and sidebar view toggle between hub+grid and library-only modes**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-09T09:20:43Z
- **Completed:** 2026-03-09T09:24:58Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Hub rows fully interactive: Continue Watching items dispatch play action with viewOffset, On Deck/Recently Added items dispatch detail action
- Three-zone focus management enables clean navigation between sidebar, hub rows, and library grid via arrow keys
- Hub rows auto-refresh every 2 minutes via Timer node and reload on screen return from playback/detail
- Sidebar view toggle: Home item returns to hub+grid view, library selection switches to library-only mode
- PosterGridItem shows gold progress bar for partially-watched items

## Task Commits

Each task was committed atomically:

1. **Task 1: Hub item selection, focus management, and auto-refresh** - `adbea55` (feat)
2. **Task 2: Sidebar view toggle between hub+grid and library-only modes** - `51e96e1` (feat)

## Files Created/Modified
- `SimPlex/components/screens/HomeScreen.xml` - Added RowList hubRowList component above FilterBar/PosterGrid
- `SimPlex/components/screens/HomeScreen.brs` - Hub fetching, item selection, three-zone focus management, auto-refresh timer, view mode toggle
- `SimPlex/components/widgets/PosterGridItem.xml` - Added progressBg and progressBar Rectangle elements
- `SimPlex/components/widgets/PosterGridItem.brs` - Added updateProgressBar() for viewOffset/duration display
- `SimPlex/components/widgets/Sidebar.brs` - Replaced On Deck/Recently Added with Home item, viewHome action
- `SimPlex/components/MainScene.brs` - Added play action routing to onItemSelected

## Decisions Made
- Hub rows use single `/hubs` API call with case-insensitive partial matching on hubIdentifier (handles PMS version variations)
- Three-zone focus model (`m.focusArea` = sidebar/hubs/grid) replaces binary `m.focusOnSidebar` for cleaner navigation state
- Play action routes to detail screen as interim until VideoPlayer is wired in playback phase
- Sidebar hub section consolidated from 2 items (On Deck, Recently Added) to 1 item (Home) since hub rows display that content directly
- Removed loadOnDeck() and loadRecentlyAdded() functions (replaced by /hubs endpoint)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Prerequisite hub row infrastructure from 03-01 not yet executed**
- **Found during:** Task 1 (plan start)
- **Issue:** Plan 03-02 depends on 03-01 (hub row RowList, /hubs API, progress bar) which had not been executed -- HomeScreen had no hubRowList, no loadHubs(), no progress bar
- **Fix:** Implemented all 03-01 prerequisites inline: added RowList to HomeScreen.xml, hub fetching/rendering to HomeScreen.brs, progress bar to PosterGridItem
- **Files modified:** HomeScreen.xml, HomeScreen.brs, PosterGridItem.xml, PosterGridItem.brs
- **Verification:** Build compiles cleanly
- **Committed in:** adbea55 (Task 1 commit, combined with 03-02 Task 1 work)

**2. [Rule 2 - Missing Critical] MainScene missing play action handler**
- **Found during:** After Task 2 (verification)
- **Issue:** MainScene onItemSelected had no handler for action="play", so Continue Watching hub row items would do nothing when selected
- **Fix:** Added play action routing to showDetailScreen as interim (until VideoPlayer is wired)
- **Files modified:** SimPlex/components/MainScene.brs
- **Verification:** Build compiles cleanly
- **Committed in:** 34938fe

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Both fixes necessary for functionality. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Hub rows are fully interactive and auto-refreshing
- Play action routing is a stub (routes to detail screen) -- needs VideoPlayer wiring when playback phase executes
- All screens follow cleanup pattern established in 03-01
- View toggle foundation ready for future UX enhancements

---
*Phase: 03-navigation-framework*
*Completed: 2026-03-09*

## Self-Check: PASSED

**Modified files verified:**
- FOUND: SimPlex/components/screens/HomeScreen.xml
- FOUND: SimPlex/components/screens/HomeScreen.brs
- FOUND: SimPlex/components/widgets/PosterGridItem.xml
- FOUND: SimPlex/components/widgets/PosterGridItem.brs
- FOUND: SimPlex/components/widgets/Sidebar.brs
- FOUND: SimPlex/components/MainScene.brs

**Commits verified:**
- FOUND: adbea55 (Task 1: hub infrastructure + interactions)
- FOUND: 51e96e1 (Task 2: sidebar view toggle)
- FOUND: 34938fe (Deviation: play action routing)

All files exist, all commits found in git log.
