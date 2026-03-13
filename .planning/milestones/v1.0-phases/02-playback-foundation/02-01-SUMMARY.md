---
phase: 02-playback-foundation
plan: 01
subsystem: ui
tags: [brightscript, scenegraph, progress-bar, badge, watch-state]

requires:
  - phase: 01-foundation-architecture
    provides: "BrighterScript build pipeline, constants pattern, PosterGridItem/EpisodeItem components"
provides:
  - "Progress bar overlays on PosterGridItem and EpisodeItem"
  - "Triangle unwatched badge with episode count for TV shows"
  - "Watch-state data flow (viewCount, duration, leafCount, viewedLeafCount) through HomeScreen and EpisodeScreen"
  - "Watch State UI constants (PROGRESS_BAR_HEIGHT_*, PROGRESS_MIN_PERCENT, BADGE_SIZE)"
affects: [02-playback-foundation, 04-detail-screens]

tech-stack:
  added: []
  patterns: ["updateProgressBar/updateBadge pattern for watch-state UI", "blendColor tinting for theme-aware badge icons"]

key-files:
  created:
    - SimPlex/images/badge-unwatched.png
  modified:
    - SimPlex/source/constants.brs
    - SimPlex/components/widgets/PosterGridItem.xml
    - SimPlex/components/widgets/PosterGridItem.brs
    - SimPlex/components/widgets/EpisodeItem.xml
    - SimPlex/components/widgets/EpisodeItem.brs
    - SimPlex/components/screens/HomeScreen.brs
    - SimPlex/components/screens/EpisodeScreen.brs

key-decisions:
  - "All accent colors reference m.global.constants.ACCENT for future theme support"
  - "5% minimum threshold for progress bar visibility (below 5% = treat as not started)"
  - "Coexistence rule: progress bar and badge never appear simultaneously"

patterns-established:
  - "updateProgressBar/updateBadge: Paired subs called in order, badge checks progressTrack.visible for coexistence rule"
  - "blendColor tinting: White PNG assets tinted via Poster.blendColor for theme support"

requirements-completed: [PLAY-02, PLAY-03]

duration: 3min
completed: 2026-03-09
---

# Phase 2 Plan 1: Watch State Indicators Summary

**Gold progress bar overlays and triangle unwatched badges on poster grid items and episode thumbnails with 5% threshold and coexistence rule**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-09T21:46:59Z
- **Completed:** 2026-03-09T21:49:36Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Poster grid items show gold progress bar at bottom when partially watched (>=5%), triangle badge in top-right when unwatched
- TV show posters display unwatched episode count inside the triangle badge
- Episode thumbnails show matching progress bar and badge indicators
- All accent colors reference constants for future theme support
- Watch-state fields (viewCount, duration, leafCount, viewedLeafCount) flow through HomeScreen and EpisodeScreen data pipelines

## Task Commits

Each task was committed atomically:

1. **Task 1: Create triangle PNG asset and add watch-state constants** - `d8992bd` (feat)
2. **Task 2: Add progress bars and triangle badges to PosterGridItem and EpisodeItem** - `a12b74e` (feat)

## Files Created/Modified
- `SimPlex/images/badge-unwatched.png` - 40x40 white right-angle triangle PNG for blendColor tinting
- `SimPlex/source/constants.brs` - Watch State UI constants (bar heights, min percent, badge sizes)
- `SimPlex/components/widgets/PosterGridItem.xml` - Progress bar rectangles and triangle badge Poster+Label nodes
- `SimPlex/components/widgets/PosterGridItem.brs` - updateProgressBar and updateBadge subs with coexistence logic
- `SimPlex/components/widgets/EpisodeItem.xml` - Progress bar and triangle badge on episode thumbnails
- `SimPlex/components/widgets/EpisodeItem.brs` - Episode watch-state indicator logic
- `SimPlex/components/screens/HomeScreen.brs` - Pass viewCount, duration, leafCount, viewedLeafCount to content nodes
- `SimPlex/components/screens/EpisodeScreen.brs` - Pass viewCount to episode content nodes

## Decisions Made
- All accent colors reference m.global.constants.ACCENT (not hardcoded) for future theme support
- 5% minimum threshold for progress bar display (below = treat as not started)
- Progress bar and badge never coexist (progress bar takes priority)
- TV show badges show unwatched episode count; movie/episode badges show triangle only

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Watch state indicators ready for visual verification on device
- Progress bars will reflect real viewOffset/duration from Plex API
- Badge tinting via blendColor enables future theme customization
- Detail screen progress bar (PROGRESS_BAR_HEIGHT_DETAIL constant) ready for Phase 4

## Self-Check: PASSED

All 7 files verified present. Both task commits (d8992bd, a12b74e) verified in git log.

---
*Phase: 02-playback-foundation*
*Completed: 2026-03-09*
