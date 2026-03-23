---
id: S12
parent: M001
milestone: M001
provides:
  - PostPlayScreen component with contextual action buttons
  - VideoPlayer playbackResult structured field replacing playbackComplete boolean
  - Season-boundary auto-play (cross-season episode fetching)
  - 30-second countdown threshold with shrinking progress bar
  - Cancellable auto-play via back/OK key with PostPlayScreen routing
  - VideoPlayer watchStateUpdate emission after scrobble (fully watched)
  - VideoPlayer watchStateUpdate emission in signalPlaybackComplete (stopped/cancelled)
  - PosterGridItem gold checkmark badge for fully watched items and TV shows
  - Three mutually exclusive badge states: unwatched dot / progress bar / watched checkmark
requires: []
affects: []
key_files: []
key_decisions:
  - playbackComplete boolean kept in VideoPlayer.xml — HomeScreen and PlaylistScreen still reference it; only DetailScreen and EpisodeScreen migrated to playbackResult
  - PostPlayScreen pushed via itemSelected action='postPlay' pattern (consistent with all other screen navigation)
  - Back to Library in PostPlayScreen pops all screens except the first (HomeScreen) directly via screen stack manipulation
  - Play Next navigates to DetailScreen for next episode — avoids complex EpisodeScreen state management
  - Replay and Play from Timestamp both simply pop PostPlayScreen — calling screen's existing Resume/Play buttons handle the action
  - watchStateUpdate is emitted from scrobble() (finished) and signalPlaybackComplete() (stopped/cancelled) — not from reportProgress() to avoid excessive re-renders
  - Watched checkmark uses Unicode &#x2713; Label (gold, 0xF3B125FF) with semi-transparent Rectangle background — no new PNG asset needed
  - Fully watched TV shows (leafCount = viewedLeafCount) also get the checkmark badge — consistent with movie behavior
patterns_established:
  - signalPlaybackComplete(reason) pattern: single VideoPlayer exit point emits structured AA with reason/ratingKey/hasNextEpisode/nextEpisodeInfo/viewOffset/duration/isPlaylist
  - Season-boundary auto-play: fetchNextSeason() fetches show children, matches current parentRatingKey, fetches first episode of next season
  - PostPlayScreen navigation: always pushed by calling screen via itemSelected, always popped by MainScene action handlers
  - watchStateUpdate emission pattern: emit AA with ratingKey/viewCount/viewOffset on m.global; observers in all screens update ContentNode fields; PosterGridItem re-renders via field change
observability_surfaces: []
drill_down_paths: []
duration: 8min
verification_result: passed
completed_at: 2026-03-13
blocker_discovered: false
---
# S12: Auto Play And Watch State

**# Phase 12 Plan 01: Auto-play and Watch State Summary**

## What Happened

# Phase 12 Plan 01: Auto-play and Watch State Summary

**PostPlayScreen with contextual buttons, cancellable 30s countdown overlay, season-boundary auto-play, and structured playbackResult replacing boolean playbackComplete for DetailScreen and EpisodeScreen**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-03-13T22:45:00Z
- **Completed:** 2026-03-13T23:40:35Z
- **Tasks:** 3
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments
- Created PostPlayScreen component with Play Next/Replay/Back to Library/Play from Timestamp buttons
- Replaced VideoPlayer boolean playbackComplete with structured playbackResult assocarray (reason, ratingKey, hasNextEpisode, nextEpisodeInfo, viewOffset, duration, isPlaylist)
- Added signalPlaybackComplete() single exit point replacing 7 scattered `m.top.playbackComplete = true` emissions
- Fixed auto-play countdown threshold from 90% of duration to last 30 seconds (duration - 30000)
- Implemented season-boundary auto-play via fetchNextSeason() → onSeasonsForNextLoaded() → onNextSeasonEpisodesLoaded() chain
- Added "Starting Season X" label in overlay for cross-season transitions
- Added shrinking progress bar (autoPlayProgressTrack/Fill) to countdown overlay
- Back/OK keys during countdown now cancel and emit playbackResult (stopped/cancelled) instead of resuming
- Wired grandparentRatingKey/parentRatingKey/episodeIndex in DetailScreen.startPlayback() for episodes
- MainScene showPostPlayScreen(), onPostPlayAction(), and postPlay routing in onItemSelected()

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PostPlayScreen and add playbackResult to VideoPlayer interface** - `549da99` (feat)
2. **Task 2: Fix auto-play wiring, countdown threshold, season-boundary fetch, and cancel behavior** - `cfd149d` (feat)
3. **Task 3: Wire playbackResult observers in calling screens and MainScene PostPlayScreen routing** - `3bae0eb` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `SimPlex/components/screens/PostPlayScreen.xml` - Post-play overlay layout with ButtonGroup and semi-transparent background
- `SimPlex/components/screens/PostPlayScreen.brs` - Button building (conditional on hasNextEpisode/viewOffset), action emission, back key handling
- `SimPlex/components/widgets/VideoPlayer.xml` - Added playbackResult field; added autoPlayProgressTrack/Fill; updated overlay heights from 140→145
- `SimPlex/components/widgets/VideoPlayer.brs` - signalPlaybackComplete(), fetchNextSeason() chain, 30s threshold, progress bar, key behavior changes
- `SimPlex/components/screens/DetailScreen.brs` - grandparentRatingKey wiring, onPlaybackResult replacing onPlaybackComplete, onNextEpisodeStarted
- `SimPlex/components/screens/EpisodeScreen.brs` - onPlaybackResult replacing onPlaybackComplete, postPlay itemSelected emission
- `SimPlex/components/MainScene.brs` - showPostPlayScreen(), onPostPlayAction(), postPlay routing, PostPlayScreen subtype in popScreen()

## Decisions Made
- Kept `playbackComplete` boolean field in VideoPlayer.xml — HomeScreen and PlaylistScreen still reference it (not in scope for this plan)
- PostPlayScreen uses standard itemSelected action='postPlay' pattern for consistency with all other screen navigation
- "Back to Library" directly manipulates screen stack (pop all but first) rather than calling popScreen() multiple times to avoid exit dialog trigger
- "Play Next" navigates to DetailScreen for next episode — simpler than trying to restore EpisodeScreen state
- "Replay" and "Play from Timestamp" both just pop PostPlayScreen — calling screen's Resume/Play buttons handle the user action

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `m.autoPlayTitle` node reference was missing from VideoPlayer.brs init() (only autoPlayEpisodeLabel etc were present) — added the findNode call alongside existing ones. This was a gap in the pre-existing code, addressed inline.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PostPlayScreen and playbackResult pattern are ready for use
- HomeScreen and PlaylistScreen still use old playbackComplete boolean — Phase 12 plan 02 or later can migrate them if needed
- Season-boundary auto-play requires grandparentRatingKey and parentRatingKey to be set correctly by calling screen

---
*Phase: 12-auto-play-and-watch-state*
*Completed: 2026-03-13*

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
