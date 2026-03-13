---
phase: 12-auto-play-and-watch-state
plan: 02
subsystem: ui
tags: [brightscript, scenegraph, watch-state, badges, poster-grid, videoplayer, roku]

# Dependency graph
requires:
  - phase: 12-auto-play-and-watch-state/12-01
    provides: PostPlayScreen, signalPlaybackComplete(), playbackResult structured field
  - phase: 11-crash-safety-and-foundation
    provides: GetRatingKeyStr(), crash-safe component patterns
provides:
  - VideoPlayer watchStateUpdate emission after scrobble (fully watched)
  - VideoPlayer watchStateUpdate emission in signalPlaybackComplete (stopped/cancelled)
  - PosterGridItem gold checkmark badge for fully watched items and TV shows
  - Three mutually exclusive badge states: unwatched dot / progress bar / watched checkmark
affects:
  - HomeScreen.brs onWatchStateUpdate() already observes m.global.watchStateUpdate — now receives data
  - Phase 13 watch-state sync — watch state propagation pattern established

# Tech tracking
tech-stack:
  added: []
  patterns:
    - watchStateUpdate global field emission: VideoPlayer emits m.global.watchStateUpdate AA with ratingKey/viewCount/viewOffset; observers in HomeScreen/PlaylistScreen update ContentNode fields
    - Three-state badge exclusion: progress bar check runs first; watched checkmark replaces "clean poster" for fully watched items; unwatched dot is the fallback

key-files:
  created: []
  modified:
    - SimPlex/components/widgets/VideoPlayer.brs
    - SimPlex/components/widgets/PosterGridItem.xml
    - SimPlex/components/widgets/PosterGridItem.brs

key-decisions:
  - "watchStateUpdate is emitted from scrobble() (finished) and signalPlaybackComplete() (stopped/cancelled) — not from reportProgress() to avoid excessive re-renders"
  - "Watched checkmark uses Unicode &#x2713; Label (gold, 0xF3B125FF) with semi-transparent Rectangle background — no new PNG asset needed"
  - "Fully watched TV shows (leafCount = viewedLeafCount) also get the checkmark badge — consistent with movie behavior"

patterns-established:
  - "watchStateUpdate emission pattern: emit AA with ratingKey/viewCount/viewOffset on m.global; observers in all screens update ContentNode fields; PosterGridItem re-renders via field change"

requirements-completed: [FIX-03]

# Metrics
duration: 8min
completed: 2026-03-13
---

# Phase 12 Plan 02: Watch State Badges Summary

**watchStateUpdate global field emission from VideoPlayer scrobble/stop and gold Unicode checkmark badge on PosterGridItem for fully watched items**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-13T23:43:21Z
- **Completed:** 2026-03-13T23:51:00Z
- **Tasks:** 2 (1 auto + 1 checkpoint auto-approved)
- **Files modified:** 3

## Accomplishments
- VideoPlayer.scrobble() now emits m.global.watchStateUpdate with viewCount=1 after marking an item watched on Plex
- VideoPlayer.signalPlaybackComplete() emits watchStateUpdate with current viewOffset for stopped/cancelled exits, enabling progress bar updates without page refresh
- PosterGridItem shows a gold (0xF3B125FF) Unicode checkmark (&#x2713;) badge with semi-transparent dark background for fully watched items
- Fully watched TV shows (all episodes watched: leafCount = viewedLeafCount) also show the checkmark badge
- All three badge states (unwatched dot, progress bar, watched checkmark) are mutually exclusive — progress bar check gates first

## Task Commits

Each task was committed atomically:

1. **Task 1: Add watchStateUpdate emission and watched checkmark badge** - `51552d2` (feat)
2. **Task 2: Verify auto-play and watch state on Roku** - auto-approved (checkpoint:human-verify, auto_advance=true)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `SimPlex/components/widgets/VideoPlayer.brs` - scrobble() emits watchStateUpdate; signalPlaybackComplete() emits watchStateUpdate for stopped/cancelled
- `SimPlex/components/widgets/PosterGridItem.xml` - Added watchedBadgeBg Rectangle and watchedBadge Label nodes
- `SimPlex/components/widgets/PosterGridItem.brs` - init() refs for new nodes; updateBadge() three-state logic with checkmark for watched

## Decisions Made
- watchStateUpdate not emitted on every reportProgress() call (every 10s) — that would cause excessive re-renders of all visible grid items
- Used Unicode checkmark character (&#x2713;) in a Label node rather than a new PNG asset — avoids adding image files and works consistently across Roku firmware versions
- Fully watched TV shows at the show level also show the checkmark, consistent with how movie-level watched state works

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Watch state propagation is complete: VideoPlayer emits, HomeScreen.onWatchStateUpdate() receives and updates ContentNodes, PosterGridItem re-renders with correct badge
- HomeScreen and PlaylistScreen both still use old playbackComplete boolean in addition to the new playbackResult — this can be cleaned up in a future phase if needed
- Physical Roku verification of the complete auto-play + watch state system (Plans 01+02) should be done before Phase 13

---
*Phase: 12-auto-play-and-watch-state*
*Completed: 2026-03-13*
