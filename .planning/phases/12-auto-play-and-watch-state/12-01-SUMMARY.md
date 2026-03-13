---
phase: 12-auto-play-and-watch-state
plan: 01
subsystem: ui
tags: [brightscript, scenegraph, videoplayer, auto-play, post-play, roku]

# Dependency graph
requires:
  - phase: 11-crash-safety-and-foundation
    provides: GetRatingKeyStr(), crash-safe component patterns, LoadingSpinner
provides:
  - PostPlayScreen component with contextual action buttons
  - VideoPlayer playbackResult structured field replacing playbackComplete boolean
  - Season-boundary auto-play (cross-season episode fetching)
  - 30-second countdown threshold with shrinking progress bar
  - Cancellable auto-play via back/OK key with PostPlayScreen routing
affects:
  - Phase 13 (watch-state sync) — uses PostPlayScreen and playbackResult
  - HomeScreen/PlaylistScreen — still use old playbackComplete field (not migrated in this plan)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - PostPlayScreen push pattern: calling screens emit itemSelected action='postPlay' with result data; MainScene routes to PostPlayScreen
    - playbackResult assocarray: structured playback exit data replaces boolean playbackComplete
    - signalPlaybackComplete(reason): single exit point for VideoPlayer that builds and emits playbackResult

key-files:
  created:
    - SimPlex/components/screens/PostPlayScreen.xml
    - SimPlex/components/screens/PostPlayScreen.brs
  modified:
    - SimPlex/components/widgets/VideoPlayer.xml
    - SimPlex/components/widgets/VideoPlayer.brs
    - SimPlex/components/screens/DetailScreen.brs
    - SimPlex/components/screens/EpisodeScreen.brs
    - SimPlex/components/MainScene.brs

key-decisions:
  - "playbackComplete boolean kept in VideoPlayer.xml — HomeScreen and PlaylistScreen still reference it; only DetailScreen and EpisodeScreen migrated to playbackResult"
  - "PostPlayScreen pushed via itemSelected action='postPlay' pattern (consistent with all other screen navigation)"
  - "Back to Library in PostPlayScreen pops all screens except the first (HomeScreen) directly via screen stack manipulation"
  - "Play Next navigates to DetailScreen for next episode — avoids complex EpisodeScreen state management"
  - "Replay and Play from Timestamp both simply pop PostPlayScreen — calling screen's existing Resume/Play buttons handle the action"

patterns-established:
  - "signalPlaybackComplete(reason) pattern: single VideoPlayer exit point emits structured AA with reason/ratingKey/hasNextEpisode/nextEpisodeInfo/viewOffset/duration/isPlaylist"
  - "Season-boundary auto-play: fetchNextSeason() fetches show children, matches current parentRatingKey, fetches first episode of next season"
  - "PostPlayScreen navigation: always pushed by calling screen via itemSelected, always popped by MainScene action handlers"

requirements-completed: [FIX-01, FIX-02]

# Metrics
duration: 55min
completed: 2026-03-13
---

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
