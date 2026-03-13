---
phase: 01-infrastructure
plan: 02
subsystem: infra
tags: [brightscript, scenegraph, constants-caching, task-concurrency]

requires:
  - phase: 01-infrastructure-01
    provides: "BrighterScript toolchain for compilation verification"
provides:
  - "Cached constants in m.global for zero per-call allocation"
  - "Create-per-request PlexApiTask pattern for concurrent API safety"
affects: [all-phases]

tech-stack:
  added: []
  patterns: [m.global.constants caching, create-per-request task pattern, named task references]

key-files:
  created: []
  modified: [SimPlex/components/MainScene.brs, SimPlex/source/utils.brs, SimPlex/components/screens/HomeScreen.brs, SimPlex/components/screens/DetailScreen.brs, SimPlex/components/screens/EpisodeScreen.brs, SimPlex/components/screens/SearchScreen.brs, SimPlex/components/screens/SettingsScreen.brs, SimPlex/components/widgets/Sidebar.brs, SimPlex/components/widgets/PosterGrid.brs, SimPlex/components/widgets/VideoPlayer.brs]

key-decisions:
  - "Defensive fallback in GetPlexHeaders() -- if m.global.constants unavailable, falls back to GetConstants() for edge cases"
  - "EpisodeScreen split into separate season/episode task callbacks instead of requestId-based routing"

patterns-established:
  - "Access constants via m.global.constants (never call GetConstants() directly from components)"
  - "Create fresh PlexApiTask per request with named m.* references to prevent GC and enable concurrency"

requirements-completed: [INFRA-02, INFRA-03]

duration: 3min
completed: 2026-03-09
---

# Phase 1 Plan 2: Constants Caching & API Task Concurrency Summary

**Cached GetConstants() in m.global at startup and replaced shared m.apiTask with create-per-request pattern across all screens/widgets**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-09T01:17:46Z
- **Completed:** 2026-03-09T01:21:04Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- Constants cached once at startup via m.global.addFields in MainScene.init(), eliminating per-call GC pressure
- All 10 component files updated to read m.global.constants instead of calling GetConstants()
- Shared m.apiTask singleton removed from all 6 screens/widgets that used PlexApiTask
- Each API request now creates a fresh PlexApiTask instance, preventing concurrent request clobbering

## Task Commits

Each task was committed atomically:

1. **Task 1: Cache constants in m.global and replace all GetConstants() calls** - `a314c90` (refactor)
2. **Task 2: Fix API task collision with create-per-request pattern** - `e3ccf06` (fix)

## Files Created/Modified
- `SimPlex/components/MainScene.brs` - Added m.global.addFields({ constants: GetConstants() }) as first init() line
- `SimPlex/source/utils.brs` - GetPlexHeaders() uses m.global.constants with fallback
- `SimPlex/components/screens/HomeScreen.brs` - Constants cached, 3 API calls create fresh tasks (m.currentApiTask)
- `SimPlex/components/screens/DetailScreen.brs` - Constants cached, metadata fetch creates fresh task (m.metadataTask)
- `SimPlex/components/screens/EpisodeScreen.brs` - Constants cached, split into m.seasonsTask and m.episodesTask
- `SimPlex/components/screens/SearchScreen.brs` - Constants cached (uses PlexSearchTask, not PlexApiTask)
- `SimPlex/components/screens/SettingsScreen.brs` - Split into m.discoverTask and m.connectionTestTask
- `SimPlex/components/widgets/Sidebar.brs` - Constants cached, library fetch creates fresh task (m.libraryTask)
- `SimPlex/components/widgets/PosterGrid.brs` - Constants cached (no API task usage)
- `SimPlex/components/widgets/VideoPlayer.brs` - Constants cached, media info fetch creates fresh task (m.mediaInfoTask)

## Decisions Made
- Added defensive fallback in GetPlexHeaders() so if m.global.constants is unavailable (e.g. task thread edge case), it falls back to GetConstants() call
- Split EpisodeScreen's single onApiTaskStateChange callback (which used requestId routing) into two separate callbacks (onSeasonsTaskStateChange, onEpisodesTaskStateChange) for cleaner separation and true concurrency support

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Infrastructure phase complete (both plans done)
- Constants caching and concurrent API patterns established for all future development
- BrighterScript compilation passes with zero errors
- No blockers

---
*Phase: 01-infrastructure*
*Completed: 2026-03-09*

## Self-Check: PASSED

All 10 modified files verified present. Both task commits (a314c90, e3ccf06) verified in git log.
