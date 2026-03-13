---
phase: 04-error-states
plan: 02
subsystem: networking
tags: [brightscript, scenegraph, error-handling, retry, network, dialog]

requires:
  - phase: 04-error-states
    plan: 01
    provides: LoadingSpinner, empty state patterns
  - phase: 01-foundation-architecture
    provides: PlexApiTask, ServerConnectionTask, screen scaffolding
provides:
  - Silent auto-retry on network failures (one attempt before user notification)
  - Contextual error dialogs with Retry/Dismiss on all content screens
  - Inline retry fallback after dialog dismissal
  - Server disconnect detection and reconnect flow in MainScene
  - Global serverReconnected signal for automatic screen data re-fetch
affects: [future screens needing error handling, playback error handling]

tech-stack:
  added: []
  patterns: [retry context pattern for re-creating failed requests, global signal pattern for cross-screen coordination]

key-files:
  created: []
  modified:
    - SimPlex/components/screens/HomeScreen.xml
    - SimPlex/components/screens/HomeScreen.brs
    - SimPlex/components/screens/DetailScreen.xml
    - SimPlex/components/screens/DetailScreen.brs
    - SimPlex/components/screens/EpisodeScreen.xml
    - SimPlex/components/screens/EpisodeScreen.brs
    - SimPlex/components/screens/SearchScreen.xml
    - SimPlex/components/screens/SearchScreen.brs
    - SimPlex/components/MainScene.brs

key-decisions:
  - "Network errors (responseCode < 0) route to MainScene server disconnect flow; HTTP errors (4xx/5xx) use per-screen error dialogs"
  - "Silent auto-retry once before notifying user, prevents false alarms on transient failures"
  - "Server List button in disconnect dialog fetches fresh server list from plex.tv before navigating"
  - "SearchScreen creates new PlexSearchTask per search (never reuses failed task nodes)"
  - "Playback screens excluded from server disconnect dialog to avoid interrupting video"

patterns-established:
  - "retryContext pattern: store endpoint/params/handler before each API call for replay on failure"
  - "Global serverUnreachable/serverReconnected signals for MainScene-coordinated disconnect recovery"
  - "Dialog guard pattern: check m.top.getScene().dialog <> invalid before creating new dialogs"

requirements-completed: [ERR-03, ERR-04]

duration: 4min
completed: 2026-03-10
---

# Phase 4 Plan 2: Network Error Handling and Server Disconnect Recovery Summary

**Silent auto-retry with contextual error dialogs and server disconnect reconnection flow across all content screens**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-10T03:41:24Z
- **Completed:** 2026-03-10T03:45:32Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- All content screens (HomeScreen, DetailScreen, EpisodeScreen, SearchScreen) silently auto-retry once on any failure
- On second failure, network errors trigger server disconnect flow in MainScene; HTTP errors show per-screen contextual error dialog
- Error dialogs provide Retry (re-attempt request) and Dismiss (show inline retry) options
- Inline retry UI group with centered message and Retry button on all screens
- MainScene runs silent background connectivity test via ServerConnectionTask before showing disconnect dialog
- Server disconnect dialog offers "Try Again" (re-test connection) and "Server List" (switch servers)
- Successful reconnection sets global serverReconnected signal, all screens automatically re-fetch their data
- Dialog stacking prevented via guard checks on all dialog creation
- Focus properly restored after every dialog interaction

## Task Commits

Each task was committed atomically:

1. **Task 1: Add error retry logic with silent auto-retry to all content screens** - `84be88d` (feat)
2. **Task 2: Add server disconnect detection and reconnect flow in MainScene** - `2d36847` (feat)

## Files Modified
- `SimPlex/components/screens/HomeScreen.xml` - retryGroup with inline retry UI
- `SimPlex/components/screens/HomeScreen.brs` - retryCount, retryContext, error dialog, inline retry, server reconnect observer
- `SimPlex/components/screens/DetailScreen.xml` - retryGroup with inline retry UI
- `SimPlex/components/screens/DetailScreen.brs` - retryCount, retryContext, error dialog, inline retry, server reconnect observer
- `SimPlex/components/screens/EpisodeScreen.xml` - retryGroup with inline retry UI
- `SimPlex/components/screens/EpisodeScreen.brs` - retryCount, retryContext, error dialog, inline retry, server reconnect observer
- `SimPlex/components/screens/SearchScreen.xml` - retryGroup with inline retry UI
- `SimPlex/components/screens/SearchScreen.brs` - retryCount, retryContext, error dialog, inline retry, server reconnect observer
- `SimPlex/components/MainScene.brs` - serverUnreachable/serverReconnected globals, connectivity test, disconnect dialog, server list navigation

## Decisions Made
- Network errors (responseCode < 0) go to MainScene disconnect flow; HTTP errors stay per-screen
- Silent auto-retry once before any user notification
- Server List button fetches fresh server list from plex.tv API
- SearchScreen creates new PlexSearchTask per retry (avoids task node reuse pitfall)
- Playback screens excluded from disconnect dialog interruption

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 04 (Error States) complete with all ERR-01 through ERR-04 requirements satisfied
- Loading spinners, empty states, error dialogs, retry logic, and server disconnect recovery all in place
- Ready for Phase 05

## Self-Check: PASSED

All 9 modified files verified present. Both task commits (84be88d, 2d36847) confirmed in git log.
