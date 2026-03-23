---
id: T02
parent: S11
milestone: M001
provides:
  - GetRatingKeyStr() shared helper in utils.brs (single source of truth for ratingKey coercion)
  - All 13+ inline ratingKey type-check blocks replaced with single-line calls
  - PosterGridItem progress bar width uses POSTER_WIDTH constant instead of hardcoded 240
requires: []
affects: []
key_files: []
key_decisions: []
patterns_established: []
observability_surfaces: []
drill_down_paths: []
duration: 8min
verification_result: passed
completed_at: 2026-03-13
blocker_discovered: false
---
# T02: 11-crash-safety-and-foundation 02

**# Phase 11 Plan 02: Utility Deduplication Summary**

## What Happened

# Phase 11 Plan 02: Utility Deduplication Summary

**GetRatingKeyStr() extracted to utils.brs as single source of truth, replacing 13 inline 4-6 line type-check blocks across 5 files; PosterGridItem progress bar now uses POSTER_WIDTH constant**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-13T19:08:00Z
- **Completed:** 2026-03-13T19:16:48Z
- **Tasks:** 2 auto
- **Files modified:** 7

## Accomplishments

- Added `GetRatingKeyStr(ratingKey as Dynamic) as String` to `utils.brs` as the single source of truth for ratingKey type coercion (Plex API returns ratingKey as integer or string inconsistently)
- Replaced all 13 inline 4-6 line type-check blocks across EpisodeScreen.brs (6), HomeScreen.brs (4), PlaylistScreen.brs (1), SearchScreen.brs (1), and DetailScreen.brs (local function delete + 6 call site renames)
- Confirmed VideoPlayer.brs had zero inline ratingKey blocks — already clean, no changes needed
- Fixed PosterGridItem.brs: replaced `Int(240 * progress)` with `Int(m.constants.POSTER_WIDTH * progress)` — m.constants already cached in init()
- SimPlex.zip builds successfully at 130 KB

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract GetRatingKeyStr to utils.brs and replace all inline duplicates** - `2f58dd0` (refactor)
2. **Task 2: Fix progress bar hardcoded width in PosterGridItem** - `1ca07c7` (refactor)

## Files Created/Modified

- `SimPlex/source/utils.brs` - Added GetRatingKeyStr() function at end of file (after SafeGetMetadata)
- `SimPlex/components/screens/DetailScreen.brs` - Deleted local getRatingKeyString function; renamed 6 call sites to GetRatingKeyStr()
- `SimPlex/components/screens/EpisodeScreen.brs` - Replaced 6 inline blocks (processSeasons, processEpisodes, onSeasonFocused, startPlayback, onNextEpisodeStarted, onPlaybackComplete)
- `SimPlex/components/screens/HomeScreen.brs` - Replaced 4 inline blocks (hub rows, grid items, collections, playlists)
- `SimPlex/components/screens/PlaylistScreen.brs` - Replaced 1 inline block in processPlaylistItems
- `SimPlex/components/screens/SearchScreen.brs` - Replaced 1 inline block in processSearchResults
- `SimPlex/components/widgets/PosterGridItem.brs` - Changed Int(240 * progress) to Int(m.constants.POSTER_WIDTH * progress)

## Decisions Made

- VideoPlayer.brs required no changes — it does not contain inline ratingKey type-check blocks (it receives already-coerced ratingKey strings from its callers)
- The local `getRatingKeyString` function in DetailScreen.brs used lowercase 'g' and a longer name — replaced uniformly with the shared `GetRatingKeyStr` (capital G, shorter name per Plex utils convention)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all verification checks passed on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Codebase is now DRY for ratingKey handling. Any future screen work that processes Plex API responses should call `GetRatingKeyStr(item.ratingKey)` — never inline the type-check.
- Phase 11 complete. Phase 12 (TV Show Navigation Enhancements) can begin immediately.

## Self-Check: PASSED

- `SimPlex/source/utils.brs` — contains `function GetRatingKeyStr`: FOUND
- `SimPlex/components/widgets/PosterGridItem.brs` — contains `m.constants.POSTER_WIDTH`: FOUND
- Commit `2f58dd0` (Task 1): FOUND
- Commit `1ca07c7` (Task 2): FOUND
- Zero inline `type(.*ratingKey.*) = .roString` patterns in screens/VideoPlayer: VERIFIED

---
*Phase: 11-crash-safety-and-foundation*
*Completed: 2026-03-13*
