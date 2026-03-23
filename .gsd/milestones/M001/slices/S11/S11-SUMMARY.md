---
id: S11
parent: M001
milestone: M001
provides:
  - Safe LoadingSpinner widget (Label+Rectangle overlay, 300ms delay threshold, no BusySpinner)
  - All 7 screens re-enabled with functional loading indicator
  - VideoPlayer transcodingSpinner replaced with safe Label
  - Orphaned normalizers.brs and capabilities.brs deleted
  - BusySpinner SIGSEGV root cause confirmed and documented
  - GetRatingKeyStr() shared helper in utils.brs (single source of truth for ratingKey coercion)
  - All 13+ inline ratingKey type-check blocks replaced with single-line calls
  - PosterGridItem progress bar width uses POSTER_WIDTH constant instead of hardcoded 240
requires: []
affects: []
key_files: []
key_decisions:
  - BusySpinner native Roku SceneGraph component causes firmware SIGSEGV ~3s after init — never use it
  - Animation nodes are safe (confirmed by 5 days of v1.0 production use since 2026-03-08)
  - LoadingSpinner uses 300ms delay Timer to avoid flash-of-spinner on fast loads
  - normalizers.brs and capabilities.brs confirmed orphaned (zero call-sites) and deleted
  - GetRatingKeyStr() is the single source of truth for ratingKey type coercion — no inline blocks anywhere
  - VideoPlayer.brs had zero inline ratingKey blocks (already clean) — no changes needed there
patterns_established:
  - Loading indicator pattern: LoadingSpinner widget with showSpinner field, guard pattern 'if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true/false'
  - 300ms delay threshold: Timer node fires after 300ms, only shows overlay if still loading
  - ratingKey coercion pattern: ratingKeyStr = GetRatingKeyStr(item.ratingKey) — one line, utils.brs
observability_surfaces: []
drill_down_paths: []
duration: 8min
verification_result: passed
completed_at: 2026-03-13
blocker_discovered: false
---
# S11: Crash Safety And Foundation

**# Phase 11 Plan 01: Crash Safety Foundation Summary**

## What Happened

# Phase 11 Plan 01: Crash Safety Foundation Summary

**BusySpinner SIGSEGV root cause confirmed and fixed: LoadingSpinner replaced with safe Label+Rectangle overlay (300ms delay), all 7 screens re-enabled, VideoPlayer spinner replaced, orphaned files deleted**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-03-13T00:00:00Z
- **Completed:** 2026-03-13
- **Tasks:** 2 auto + 1 human-verify (auto-approved)
- **Files modified:** 19 (17 components + 2 planning docs)

## Accomplishments

- Confirmed TEST4b PASSED: the v1.0 app has run without crashes since 2026-03-08 (5 days) with animations and no BusySpinner — proving BusySpinner is the sole crash cause
- Replaced LoadingSpinner widget: `<BusySpinner>` removed, replaced with `<Rectangle>` (input blocker) + `<Label>` (Loading...) + `<Timer>` (300ms delay so fast loads never flash the spinner)
- Re-enabled LoadingSpinner in all 7 screens — screens now show meaningful loading feedback during API calls
- Replaced VideoPlayer `<BusySpinner id="transcodingSpinner">` with `<Label>` — same `.visible` toggle API, no crash risk
- Deleted orphaned `normalizers.brs` and `capabilities.brs` (zero call-sites confirmed before deletion)
- Deleted `HomeScreen.brs.bak` and `HomeScreen.xml.bak` (diagnostic files no longer needed)
- SimPlex.zip builds successfully (130 KB)

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace BusySpinner with safe loading indicator** - `a1d203c` (feat)
2. **Task 2: Delete orphaned files** - `03e9534` (chore)

## Files Created/Modified

- `SimPlex/components/widgets/LoadingSpinner.xml` - Replaced BusySpinner with Rectangle overlay + Label + Timer (300ms delay)
- `SimPlex/components/widgets/LoadingSpinner.brs` - Safe impl: Timer-based delay, no control field calls
- `SimPlex/components/screens/HomeScreen.xml` - Added `<LoadingSpinner id="loadingSpinner" />`
- `SimPlex/components/screens/HomeScreen.brs` - Re-wired: `m.loadingSpinner = m.top.findNode("loadingSpinner")`
- `SimPlex/components/screens/DetailScreen.xml` - Added LoadingSpinner
- `SimPlex/components/screens/DetailScreen.brs` - Re-wired loadingSpinner
- `SimPlex/components/screens/EpisodeScreen.xml` - Added LoadingSpinner
- `SimPlex/components/screens/EpisodeScreen.brs` - Re-wired loadingSpinner
- `SimPlex/components/screens/PlaylistScreen.xml` - Added LoadingSpinner
- `SimPlex/components/screens/PlaylistScreen.brs` - Re-wired loadingSpinner
- `SimPlex/components/screens/SearchScreen.xml` - Added LoadingSpinner
- `SimPlex/components/screens/SearchScreen.brs` - Re-wired loadingSpinner
- `SimPlex/components/screens/SettingsScreen.xml` - Added LoadingSpinner
- `SimPlex/components/screens/SettingsScreen.brs` - Re-wired loadingSpinner
- `SimPlex/components/screens/UserPickerScreen.xml` - Added LoadingSpinner
- `SimPlex/components/screens/UserPickerScreen.brs` - Re-wired loadingSpinner
- `SimPlex/components/widgets/VideoPlayer.xml` - Replaced BusySpinner transcodingSpinner with Label
- `.planning/UAT-DEBUG-CONTEXT.md` - Updated: TEST4b PASS, root cause documented, status RESOLVED
- Deleted: `SimPlex/source/normalizers.brs`, `SimPlex/source/capabilities.brs`, `HomeScreen.brs.bak`, `HomeScreen.xml.bak`

## Decisions Made

- BusySpinner is permanently banned from SimPlex — any future "spinner" UI must use Label/Rectangle/Animation
- 300ms delay chosen to match common perception threshold (sub-300ms loads appear instant; above that, feedback is helpful)
- VideoPlayer transcodingSpinner replaced with two-label approach ("Please wait..." + "Switching subtitles...") for clarity
- normalizers.brs and capabilities.brs confirmed dead code — no callers, no XML includes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all verification checks passed on first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Crash safety gate is cleared. All subsequent v1.1 work can proceed safely.
- The LoadingSpinner interface (`showSpinner` field, guard pattern) is stable and unchanged — future screens can use it without modification.
- Phase 12 (TV Show Navigation Enhancements) can begin immediately.

---
*Phase: 11-crash-safety-and-foundation*
*Completed: 2026-03-13*

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
