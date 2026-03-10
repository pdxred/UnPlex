---
phase: 08-auto-play-next-episode
plan: 01
subsystem: playback
tags: [brightscript, scenegraph, auto-play, countdown, next-episode, binge-watching]

requires:
  - phase: 07-intro-and-credits-skip
    provides: "Credits marker detection, skip button infrastructure, marker fetch"
  - phase: 02-playback-foundation
    provides: "VideoPlayer component, playback infrastructure, scrobble"
provides:
  - "10-second countdown overlay during credits marker timespan for TV episodes"
  - "Next episode fetch via /library/metadata/{parentRatingKey}/children API"
  - "Automatic episode transition with scrobble before advance"
  - "Cancel countdown via Back key (PLAY-13)"
  - "90% duration fallback when no credits marker exists"
  - "Countdown pauses on playback pause, resumes on resume"
  - "OK press during countdown starts next episode immediately"
  - "nextEpisodeStarted interface field for calling screen notification"
affects: []

tech-stack:
  added: []
  patterns: ["Timer node for 1-second countdown ticks", "Sequential episode lookup via parent children API", "Overlay replacement: countdown replaces skip credits button"]

key-files:
  created: []
  modified:
    - SimPlex/components/widgets/VideoPlayer.xml
    - SimPlex/components/widgets/VideoPlayer.brs

key-decisions:
  - "Countdown replaces Skip Credits button for TV episodes (dual-purpose overlay)"
  - "90% duration fallback when no credits marker exists"
  - "Cross-season auto-play deferred — sets noNextEpisode for last episode of season"
  - "nextEpisodeStarted interface field signals calling screen for state updates"
  - "Countdown timer pauses/resumes with playback pause/resume"
  - "startNextEpisode scrobbles current episode before transitioning"

patterns-established:
  - "fetchNextEpisode: Sequential episode lookup via season children endpoint"
  - "showAutoPlayOverlay: Countdown overlay with Timer node for 1-second ticks"
  - "startNextEpisode: Scrobble, reset state, update fields, call loadMedia()"
  - "cancelAutoPlay: Stop timer, hide overlay, return to normal playback"

requirements-completed: [PLAY-12, PLAY-13]

duration: 3min
completed: 2026-03-10
---

# Phase 8 Plan 1: Auto-play Next Episode Summary

**10-second countdown overlay during credits with next episode fetch, automatic transition, and cancel behavior**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-10
- **Completed:** 2026-03-10
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Auto-play countdown overlay added to VideoPlayer with "Up Next" header, episode title, countdown timer, and cancel hint
- Interface fields added: parentRatingKey, grandparentRatingKey, episodeIndex, seasonIndex, nextEpisodeStarted
- fetchNextEpisode() finds next episode via /library/metadata/{parentRatingKey}/children API
- onNextEpisodeLoaded() parses season children and locates next episode by index
- showAutoPlayOverlay() displays countdown with next episode info, replaces skip credits button
- 1-second Timer node ticks down from 10 with live label updates
- startNextEpisode() scrobbles current episode, resets all state, and calls loadMedia() for next episode
- cancelAutoPlay() stops timer and hides overlay on Back key press
- Countdown pauses when playback pauses, resumes when playback resumes
- 90% duration fallback when no credits marker exists
- No countdown for movies (checks grandparentRatingKey) or when no next episode exists
- Cross-season auto-play deferred (sets noNextEpisode flag for last episode)

## Task Commits

Each task was committed atomically:

1. **Task 1: Auto-play overlay and countdown logic** - `cab5ea9` (feat)

## Files Created/Modified
- `SimPlex/components/widgets/VideoPlayer.xml` - Added autoPlayOverlay Group, interface fields for episode context, fade animations
- `SimPlex/components/widgets/VideoPlayer.brs` - fetchNextEpisode(), showAutoPlayOverlay(), onCountdownTick(), startNextEpisode(), cancelAutoPlay(), checkMarkers() integration

## Decisions Made
- Countdown replaces skip credits button for TV episodes
- 90% duration fallback for episodes without credits markers
- Cross-season next episode deferred to future enhancement
- Timer pauses/resumes with playback state

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Auto-play infrastructure complete for Phase 9+ features
- nextEpisodeStarted field available for playlist sequential playback patterns
- Timer-based countdown pattern reusable for other timed overlays

## Self-Check: PASSED

All 2 modified files verified present. Task commit (cab5ea9) verified in git log.

---
*Phase: 08-auto-play-next-episode*
*Completed: 2026-03-10*
