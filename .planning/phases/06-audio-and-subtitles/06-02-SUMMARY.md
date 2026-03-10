---
phase: 06-audio-and-subtitles
plan: 02
subsystem: playback
tags: [brightscript, scenegraph, pgs, transcode, burn-in, track-persistence, forced-subtitles]

requires:
  - phase: 06-audio-and-subtitles
    provides: "TrackSelectionPanel, stream metadata parsing, audio/SRT subtitle switching"
  - phase: 02-playback-foundation
    provides: "VideoPlayer component, playback infrastructure"
provides:
  - "PGS bitmap subtitle burn-in via transcode pivot with position preservation"
  - "Transcode failure revert with error toast and previous state restoration"
  - "PUT method support in PlexApiTask via X-HTTP-Method-Override"
  - "Track persistence via PUT /library/parts/{id} (fire-and-forget)"
  - "Forced subtitle auto-enable based on device locale vs audio language"
  - "Fallback display titles for streams with missing language metadata"
  - "Switching subtitles... spinner overlay during PGS transcode"
  - "Direct play revert when switching from PGS back to SRT or Off"
affects: [07-intro-credits-skip, 08-autoplay-next]

tech-stack:
  added: []
  patterns: ["X-HTTP-Method-Override for PUT requests", "transcode pivot with previousPlaybackState for revert", "roDeviceInfo GetCurrentLocale() for language detection"]

key-files:
  created: []
  modified:
    - SimPlex/components/tasks/PlexApiTask.brs
    - SimPlex/components/widgets/VideoPlayer.xml
    - SimPlex/components/widgets/VideoPlayer.brs

key-decisions:
  - "PUT method via X-HTTP-Method-Override header (same pattern as PlexSessionTask)"
  - "PGS transcode uses subtitleStreamID + subtitles=burn + offset params"
  - "isTranscodePivotInProgress guard prevents rapid PGS switching race conditions"
  - "previousPlaybackState stores full revert info (url, format, position, selected tracks)"
  - "Forced PGS subtitles skipped at initial load (user can manually select from panel)"
  - "Track persistence is fire-and-forget per established scrobble pattern"
  - "Fallback displayTitle constructed as 'Language (CODEC Nch)' for audio, 'Language (CODEC)' for subtitle"

patterns-established:
  - "buildTranscodeUrlWithSubtitles: Transcode URL with subtitleStreamID + subtitles=burn + offset"
  - "handlePgsSubtitleRequest: Full pivot flow — store state, stop, show spinner, start transcode, update selection"
  - "revertFromTranscodePivot: Restore previous content URL and position on transcode failure"
  - "switchFromTranscodeToDirectPlay: Return to direct play when user deselects PGS"
  - "persistTrackSelection: Fire-and-forget PUT to /library/parts/{id} with stream IDs"
  - "checkForcedSubtitles: Compare audio languageTag to device locale, auto-enable forced text subs"

requirements-completed: [PLAY-09, PLAY-06, PLAY-07]

duration: 3min
completed: 2026-03-10
---

# Phase 6 Plan 2: PGS Transcode Pivot, Track Persistence, Forced Subtitles Summary

**PGS bitmap subtitle burn-in via transcode pivot, track preference persistence via Plex API, and forced subtitle auto-enable based on device locale**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-10
- **Completed:** 2026-03-10
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- PlexApiTask now supports PUT method via X-HTTP-Method-Override header
- PGS subtitle selection triggers full transcode pivot: stop playback, show "Switching subtitles..." spinner, start HLS transcode with burn-in params, hide spinner on success
- Playback position preserved across direct-play-to-transcode switch via offset parameter
- Transcode failure shows "Subtitle Unavailable" StandardMessageDialog and reverts to previous playback state
- Switching from PGS back to SRT or Off restores direct play with position preservation
- Race condition guard (isTranscodePivotInProgress) prevents rapid PGS switching issues
- Track preferences persist to Plex server via PUT /library/parts/{id} after every track change
- Forced subtitles auto-enable when audio language differs from device locale (text subs only)
- Fallback display titles for streams with missing language metadata

## Task Commits

Each task was committed atomically:

1. **Task 1: PlexApiTask PUT + PGS transcode pivot** - `613b471` (feat)
2. **Task 2: Track persistence + forced subtitles + fallback labels** - `d097241` (feat)

## Files Created/Modified
- `SimPlex/components/tasks/PlexApiTask.brs` - Added PUT method handling via X-HTTP-Method-Override
- `SimPlex/components/widgets/VideoPlayer.xml` - Added transcodingOverlay group with BusySpinner and label
- `SimPlex/components/widgets/VideoPlayer.brs` - PGS pivot, revert, direct play switch-back, persistence, forced subs, fallback titles

## Decisions Made
- PUT uses X-HTTP-Method-Override for consistency with PlexSessionTask pattern
- PGS forced subtitles skipped at initial load to avoid transcode on first play
- Transcode overlay uses existing BusySpinner component pattern from Phase 4
- Track persistence is fire-and-forget (no error handling on PUT failure)

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All PLAY-06, PLAY-07, PLAY-08, PLAY-09 requirements complete
- TrackSelectionPanel and transcode infrastructure ready for Phase 7 overlay patterns
- PlexApiTask PUT support available for future API needs

## Self-Check: PASSED

All 3 modified files verified present. Both task commits (613b471, d097241) verified in git log.

---
*Phase: 06-audio-and-subtitles*
*Completed: 2026-03-10*
