---
phase: 07-intro-and-credits-skip
plan: 01
subsystem: playback
tags: [brightscript, scenegraph, skip-intro, skip-credits, markers, overlay]

requires:
  - phase: 06-audio-and-subtitles
    provides: "TrackSelectionPanel overlay, VideoPlayer infrastructure"
  - phase: 02-playback-foundation
    provides: "VideoPlayer component, playback infrastructure, position tracking"
provides:
  - "Skip Intro button during intro marker timespan with OK-to-seek"
  - "Skip Credits button during credits marker timespan with OK-to-seek"
  - "Marker pre-fetching via /library/metadata/{ratingKey}/markers API at playback start"
  - "Position-based marker range checking in onPositionChange"
  - "Fade-in/fade-out animation (0.3s) for skip button appearance"
  - "Focus management: skip button takes focus unless TrackSelectionPanel is open"
  - "Back key dismisses skip button without seeking"
affects: [08-autoplay-next]

tech-stack:
  added: []
  patterns: ["Position-based overlay trigger via onPositionChange", "FloatFieldInterpolator fade animation for timed UI", "Fire-and-forget marker fetch parallel to playback start"]

key-files:
  created: []
  modified:
    - SimPlex/components/widgets/VideoPlayer.xml
    - SimPlex/components/widgets/VideoPlayer.brs

key-decisions:
  - "Markers fetched in parallel with playback start (fire-and-forget, arrive during early playback)"
  - "Position checking in onPositionChange is lightweight — integer range comparisons only"
  - "Skip button positioned at bottom-right [1520, 940] to avoid progress bar overlap"
  - "Focus ring uses Plex gold accent color from constants"
  - "Skip button respects TrackSelectionPanel — does not steal focus when panel is open"
  - "Graceful absence when no markers exist (no error, no button)"

patterns-established:
  - "fetchMarkers: PlexApiTask GET to /library/metadata/{ratingKey}/markers"
  - "checkMarkers: Position-based range check in onPositionChange for timed overlay triggers"
  - "showSkipButton/hideSkipButton: Fade animation with focus management for temporary overlays"
  - "handleSkipPress: Seek to marker end position on OK press"

requirements-completed: [PLAY-10, PLAY-11]

duration: 3min
completed: 2026-03-10
---

# Phase 7 Plan 1: Intro and Credits Skip Buttons Summary

**Skip buttons that appear during Plex marker timespans with fade animation, position-based triggering, and single-press seek behavior**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-10
- **Completed:** 2026-03-10
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Skip button overlay added to VideoPlayer.xml with Rectangle background, Label text, and focus highlight
- Fade-in/fade-out animations (0.3s, inOutQuad easing) via FloatFieldInterpolator
- fetchMarkers() fires PlexApiTask at playback start to pre-fetch intro/credits markers
- onMarkersLoaded() parses MediaContainer.Marker array for "intro" and "credits" types
- checkMarkers() in onPositionChange() compares position against marker ranges
- showSkipButton() displays "Skip Intro" or "Skip Credits" with fade-in and focus management
- hideSkipButton() fades out and returns focus to video node
- handleSkipPress() seeks to marker end position on OK press
- Back key dismisses button without seeking
- Skip button does not steal focus from TrackSelectionPanel when panel is open
- Marker state reset on stopPlayback()
- Graceful handling when no markers exist (no error, no button shown)

## Task Commits

Each task was committed atomically:

1. **Task 1: Skip button UI and marker integration** - `5001e53` (feat)

## Files Created/Modified
- `SimPlex/components/widgets/VideoPlayer.xml` - Added skipButton Group with Rectangle, Label, focus ring, and fade animations
- `SimPlex/components/widgets/VideoPlayer.brs` - fetchMarkers(), onMarkersLoaded(), checkMarkers(), showSkipButton(), hideSkipButton(), handleSkipPress(), onSkipFadeOutComplete()

## Decisions Made
- Markers fetched as fire-and-forget parallel to playback start
- Skip button at [1520, 940] in bottom-right corner
- Focus ring uses FOCUS_RING constant (Plex gold accent)
- checkMarkers() kept lightweight for ~250ms position update frequency

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Skip button infrastructure can be extended for Phase 8 auto-play next episode
- Credits marker end position available for Phase 8 countdown trigger
- Marker fetch pattern reusable for any Plex chapter-based features

## Self-Check: PASSED

All 2 modified files verified present. Task commit (5001e53) verified in git log.

---
*Phase: 07-intro-and-credits-skip*
*Completed: 2026-03-10*
