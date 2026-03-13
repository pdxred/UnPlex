---
phase: 02-playback-foundation
plan: 02
subsystem: ui
tags: [brightscript, scenegraph, resume-dialog, options-menu, progress-bar, optimistic-updates]

requires:
  - phase: 02-playback-foundation
    provides: "Progress bar overlays, badge indicators, watch-state constants, watch-state data flow"
  - phase: 01-foundation-architecture
    provides: "BrighterScript build pipeline, constants pattern, VideoPlayer component"
provides:
  - "Resume dialog on grid/episode selection for partially-watched items"
  - "Options (*) key context menu for mark watched/unwatched on grids and episode lists"
  - "Detail screen progress bar with remaining time text"
  - "Optimistic UI updates for watched state changes"
  - "watchStateChanged interface field on DetailScreen for parent screen propagation"
affects: [03-navigation-framework, 04-detail-screens]

tech-stack:
  added: []
  patterns: ["showResumeDialog/onResumeDialogButton for grid resume flow", "optimistic update with background API fire-and-forget", "StandardMessageDialog as context menu"]

key-files:
  created: []
  modified:
    - SimPlex/components/screens/HomeScreen.brs
    - SimPlex/components/screens/EpisodeScreen.brs
    - SimPlex/components/screens/DetailScreen.brs
    - SimPlex/components/screens/DetailScreen.xml

key-decisions:
  - "Resume dialog only on grid/episode list selections, NOT detail screen (locked user decision)"
  - "Detail screen uses separate buttons for Resume and Play, not a dialog"
  - "Resume button appears first when item is partially watched"
  - "StandardMessageDialog used for options context menu (MVP approach)"
  - "Optimistic UI updates: change immediately, fire API in background, only show error on failure"

patterns-established:
  - "showResumeDialog: Check viewOffset > 0 and progress >= 5%, show dialog with Resume/Start/Details"
  - "showOptionsMenu: Options (*) key triggers StandardMessageDialog with watched toggle"
  - "fireScrobbleApi: Fire-and-forget pattern for scrobble/unscrobble API calls"
  - "watchStateChanged: Detail screen propagates state changes to parent via interface field"

requirements-completed: [PLAY-01, PLAY-04, PLAY-05]

duration: 4min
completed: 2026-03-09
---

# Phase 2 Plan 2: Resume Dialog, Options Menu, and Detail Screen Enhancements Summary

**Resume dialog on grid/episode selection, options key mark watched/unwatched, detail screen progress bar with remaining time, and optimistic UI updates across all screens**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-09T21:52:12Z
- **Completed:** 2026-03-09T21:55:59Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Grid and episode list selections for partially-watched items show resume dialog with Resume/Start from Beginning/Go to Details options
- Options (*) remote key shows context menu for Mark Watched/Unwatched on grids, hub rows, and episode lists
- Detail screen displays progress bar with "X min remaining" text for partially-watched items
- Resume button appears first on detail screen, Play from Beginning second
- All watch state changes apply optimistically with instant visual feedback
- Detail screen propagates watch state changes to parent screens via watchStateChanged interface field

## Task Commits

Each task was committed atomically:

1. **Task 1: Add resume dialog and options key context menu** - `682ee05` (feat)
2. **Task 2: Enhance DetailScreen with progress bar, remaining time, and optimistic updates** - `424d33e` (feat)

## Files Created/Modified
- `SimPlex/components/screens/HomeScreen.brs` - Resume dialog, options key context menu, grid playback, scrobble API calls
- `SimPlex/components/screens/EpisodeScreen.brs` - Resume dialog, options menu, modified startPlayback to accept offset parameter
- `SimPlex/components/screens/DetailScreen.brs` - Progress bar, remaining time, optimistic mark watched/unwatched, watchStateChanged propagation
- `SimPlex/components/screens/DetailScreen.xml` - Progress bar nodes, remaining time label, watchStateChanged interface field, adjusted button group position

## Decisions Made
- Resume dialog only appears on grid/episode list selections (per locked user decision), detail screen uses separate buttons
- Resume button placed first (before Play from Beginning) on detail screen for faster access
- StandardMessageDialog used as MVP context menu (per research recommendation)
- Optimistic updates: UI changes instantly, API fires in background, error shown only on failure
- TV show mark-watched labels prefixed with "Mark Show as" for clarity on scope

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Resume dialog and options menu ready for on-device testing
- watchStateChanged interface field ready for HomeScreen to observe when returning from detail screen
- Progress bar uses constants.ACCENT for theme-aware coloring
- All dialog interactions properly restore focus after dismiss

## Self-Check: PASSED

All 4 modified files verified present. Both task commits (682ee05, 424d33e) verified in git log.

---
*Phase: 02-playback-foundation*
*Completed: 2026-03-09*
