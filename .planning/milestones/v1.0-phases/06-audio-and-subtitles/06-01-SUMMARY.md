---
phase: 06-audio-and-subtitles
plan: 01
subsystem: playback
tags: [brightscript, scenegraph, track-selection, audio, subtitles, sidecar]

requires:
  - phase: 02-playback-foundation
    provides: "VideoPlayer component, playback infrastructure, progress reporting"
  - phase: 01-infrastructure
    provides: "BrighterScript build pipeline, constants pattern"
provides:
  - "TrackSelectionPanel slide-in component with audio and subtitle LabelLists"
  - "Stream metadata parsing from Plex API response (streamType 2=audio, 3=subtitle)"
  - "Audio track switching via Roku Video node audioTrack field"
  - "SRT subtitle sidecar delivery via ContentNode subtitleTracks"
  - "Options (*) key toggles panel with pause/resume behavior"
  - "Checkmark + accent highlight for active track selection"
  - "Cross-list focus navigation between audio and subtitle sections"
  - "PGS subtitle request signaling via pgsRequested interface field"
affects: [07-intro-credits-skip]

tech-stack:
  added: []
  patterns: ["LabelList for track selection with ContentNode addFields for stream metadata", "FloatFieldInterpolator slide animation for panel", "Sidecar subtitle URL via /library/streams/{id}"]

key-files:
  created:
    - SimPlex/components/widgets/TrackSelectionPanel.xml
    - SimPlex/components/widgets/TrackSelectionPanel.brs
  modified:
    - SimPlex/components/widgets/VideoPlayer.xml
    - SimPlex/components/widgets/VideoPlayer.brs

key-decisions:
  - "Panel width 440px with 24px padding, positioned at x=1480 when open"
  - "LabelList with floatingFocus style for smooth scrolling in track lists"
  - "Stream metadata parsed once in processMediaInfo and cached in m.audioStreams/m.subtitleStreams"
  - "SRT sidecar URL format: {server}/library/streams/{id}?X-Plex-Token={token}"
  - "PGS selections flagged via pgsRequested field for Plan 02 transcode pivot (not silently ignored)"
  - "pausedForPanel flag distinguishes panel-triggered pause from user pause"
  - "Audio track switch uses Video node audioTrack string index"

patterns-established:
  - "parseStreams: Iterate Part.Stream[], filter by streamType, build typed AA arrays with isBitmap flag"
  - "buildSidecarUrl: Construct /library/streams/{id} URL with token for text subtitle delivery"
  - "handleAudioTrackChange: Map stream ID to array index, set Video.audioTrack"
  - "handleTextSubtitleChange: Build sidecar URL, set ContentNode.subtitleTracks, enable subtitle track"
  - "onPanelVisibleChange: Pause/resume coordination with pausedForPanel flag"

requirements-completed: [PLAY-06, PLAY-07, PLAY-08]

duration: 3min
completed: 2026-03-10
---

# Phase 6 Plan 1: TrackSelectionPanel and Audio/SRT Subtitle Selection Summary

**TrackSelectionPanel slide-in component with audio track switching and SRT sidecar subtitle delivery, wired into VideoPlayer via Options key**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-10
- **Completed:** 2026-03-10
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- TrackSelectionPanel component with slide-in animation from right edge (440px wide, 0.25s ease-in-out)
- Audio section on top, Subtitles section below with "Off" option, separated by divider
- Active track marked with checkmark (unicode 10003) and Plex gold accent color
- Stream metadata parsed from Plex API Part.Stream[] array (streamType 2=audio, 3=subtitle)
- Audio track switching via Roku Video node audioTrack field
- SRT subtitle sidecar delivery via ContentNode subtitleTracks with /library/streams/{id} URL
- Options (*) key pauses playback and opens panel; closing resumes playback
- Cross-list focus navigation: bottom of audio list moves to subtitle list, top of subtitle list moves back
- PGS subtitle requests signaled via pgsRequested interface field for Plan 02

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TrackSelectionPanel component** - `77cc521` (feat)
2. **Task 2: Wire TrackSelectionPanel into VideoPlayer** - `06a7e01` (feat)

## Files Created/Modified
- `SimPlex/components/widgets/TrackSelectionPanel.xml` - Panel layout with LabelLists, slide animation, interface fields
- `SimPlex/components/widgets/TrackSelectionPanel.brs` - Stream population, selection handling, focus navigation, slide animation
- `SimPlex/components/widgets/VideoPlayer.xml` - Added TrackSelectionPanel child, audioStreams/subtitleStreams/pgsRequested interface fields
- `SimPlex/components/widgets/VideoPlayer.brs` - parseStreams(), track change handlers, Options key integration, sidecar subtitle setup

## Decisions Made
- Panel width 440px matches Plex-style side panel aesthetic
- LabelList floatingFocus for smooth scrolling rather than fixed grid
- Stream metadata cached in m.audioStreams/m.subtitleStreams arrays for efficient panel updates
- PGS requests flagged via interface field rather than silently ignored

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- m.partId cached for Plan 02 track persistence via PUT /library/parts/{id}
- m.cachedPart and m.cachedMediaInfo preserved for PGS revert scenario
- m.isTranscoding and m.isTranscodePivotInProgress flags initialized for Plan 02
- pgsRequested interface field ready for Plan 02 to observe

## Self-Check: PASSED

All 4 files verified present. Both task commits (77cc521, 06a7e01) verified in git log.

---
*Phase: 06-audio-and-subtitles*
*Completed: 2026-03-10*
