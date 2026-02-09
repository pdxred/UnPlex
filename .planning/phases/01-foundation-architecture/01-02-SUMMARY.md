---
phase: 01-foundation-architecture
plan: 02
subsystem: data-transformation
tags: [contentnode, normalizers, capabilities, api-abstraction]
dependency_graph:
  requires: [utils.brs, constants.brs]
  provides: [normalizers.brs, capabilities.brs, SafeGet]
  affects: [future API consumers, all UI components]
tech_stack:
  added: [SafeGet helper function]
  patterns: [JSON-to-ContentNode normalization, server capability detection]
key_files:
  created:
    - PlexClassic/source/normalizers.brs
    - PlexClassic/source/capabilities.brs
  modified:
    - PlexClassic/source/utils.brs
decisions:
  - Added SafeGet to utils.brs for null-safe field access
  - Normalizers use camelCase field names (id, title, posterUrl, itemType, watched)
  - Standard itemType values: movie, show, season, episode, unknown
  - Capability detection based on version parsing (major.minor.patch)
  - Intro/Credits markers require PMS 1.30+
metrics:
  duration_minutes: 2
  tasks_completed: 2
  files_created: 2
  files_modified: 1
  commits: 2
  completed: 2026-02-09
---

# Phase 01 Plan 02: ContentNode Normalizers and Server Capabilities Summary

**One-liner:** Created JSON-to-ContentNode normalizers with camelCase field mapping and server capability detection for graceful degradation.

## Objective Achieved

Created ContentNode normalizers and server capability detection per CONTEXT.md decisions. These provide the core data transformation patterns (API JSON → UI-ready ContentNode) and feature detection (hide unsupported UI elements) used by all subsequent phases.

## Tasks Completed

### Task 1: Create normalizers.brs with ContentNode converters
**Status:** Complete
**Commit:** 42ff6a4
**Duration:** ~1 minute

Created `PlexClassic/source/normalizers.brs` with 5 normalizer functions:
- `NormalizeMovieList` - Convert movie arrays to ContentNode trees
- `NormalizeShowList` - Convert TV show arrays to ContentNode trees
- `NormalizeSeasonList` - Convert season arrays with parent show reference
- `NormalizeEpisodeList` - Convert episode arrays with show/season references
- `NormalizeOnDeck` - Convert mixed-type Continue Watching items

**Key implementation details:**
- All functions accept JSON arrays from Plex API responses
- Return ContentNode trees ready for grid/list binding
- Field mapping: `ratingKey` → `id`, `thumb` → `posterUrl`, `viewCount` → `watched`
- Standard `itemType` field with values: movie, show, season, episode
- Episode nodes include resume position via `viewOffset`
- Shows/seasons track watched progress via `leafCount`/`viewedLeafCount`

**Files created:**
- `PlexClassic/source/normalizers.brs` (133 lines)

**Files modified:**
- `PlexClassic/source/utils.brs` - Added `SafeGet` helper function

### Task 2: Create capabilities.brs for server feature detection
**Status:** Complete
**Commit:** 99bbe86
**Duration:** ~1 minute

Created `PlexClassic/source/capabilities.brs` with server capability detection:
- `ParseServerCapabilities` - Extract version and feature flags from root endpoint
- `HasCapability` - Boolean check for specific features (introMarkers, creditsMarkers, chapters, hls)
- `GetMinVersionForFeature` - Return minimum version string for feature
- `MeetsMinVersion` - Compare server version to minimum requirement

**Key implementation details:**
- Parses version string format: "1.32.5.7349-xyz" → major=1, minor=32, patch=5
- Intro/Credits markers require PMS 1.30+
- HLS transcoding and chapters assumed available (standard features)
- Returns safe defaults when response invalid

**Usage pattern:**
1. Fetch root endpoint `/` via PlexApiTask
2. Parse with `ParseServerCapabilities(response)`
3. Store in `m.global.serverCaps`
4. UI components call `HasCapability(caps, "introMarkers")` to show/hide features

**Files created:**
- `PlexClassic/source/capabilities.brs` (97 lines)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added SafeGet to utils.brs**
- **Found during:** Task 1 implementation
- **Issue:** Normalizers depend on SafeGet() function but it didn't exist in utils.brs
- **Fix:** Added SafeGet function to utils.brs with null-safe field access and default values
- **Files modified:** PlexClassic/source/utils.brs
- **Commit:** 42ff6a4 (combined with Task 1)
- **Rationale:** Critical dependency - normalizers can't function without SafeGet

## Verification Results

All success criteria met:
- ✓ Normalizers convert Plex JSON arrays to ContentNode trees
- ✓ Field names mapped: ratingKey→id, thumb→posterUrl, viewCount→watched
- ✓ Standard itemType field with values: movie, show, season, episode
- ✓ Server capabilities parseable from root endpoint
- ✓ Feature detection enables graceful degradation pattern
- ✓ All files follow BrightScript syntax
- ✓ 5 normalizer functions created
- ✓ 4 capability functions created
- ✓ SafeGet used 37 times across normalizers
- ✓ No circular dependencies between files

## Key Technical Decisions

1. **Normalizer Input/Output:** Normalizers accept raw JSON arrays from tasks, return ContentNode trees. Clean separation of concerns.

2. **Field Naming Convention:** camelCase aligned with Roku conventions (title, posterUrl, itemType) rather than Plex's snake_case.

3. **Watched Status Logic:** Movies/episodes use `viewCount > 0`, shows always false (tracked at episode level), On Deck items always false by definition.

4. **Parent References:** Flat structure with `showId`/`seasonId` references rather than nested trees. Separate API requests per navigation level.

5. **Capability Detection:** Version-based for intro/credits markers (1.30+), assumed true for standard features (HLS, chapters).

6. **SafeGet Pattern:** Three-level safety: check object validity, field existence, value validity. Returns default if any check fails.

## Integration Notes

**For future task developers:**

1. **Using normalizers:**
   ```brightscript
   ' In component .brs file
   ' Include: <script type="text/brightscript" uri="pkg:/source/utils.brs" />
   ' Include: <script type="text/brightscript" uri="pkg:/source/normalizers.brs" />

   ' After task completes with JSON response
   metadata = task.response.MediaContainer.Metadata
   content = NormalizeMovieList(metadata)
   m.posterGrid.content = content
   ```

2. **Using capabilities:**
   ```brightscript
   ' Store server caps in global
   m.global.addFields({ serverCaps: ParseServerCapabilities(response) })

   ' Check in UI components
   if HasCapability(m.global.serverCaps, "introMarkers")
       m.skipIntroButton.visible = true
   end if
   ```

3. **Field availability:**
   - All items: id, title, posterUrl, itemType
   - Movies/episodes: watched, duration, summary, viewOffset
   - Shows/seasons: leafCount, viewedLeafCount
   - Episodes: showId, seasonId, episodeNumber, seasonNumber
   - On Deck episodes: showTitle

## Files Summary

**Created (2 files):**
- PlexClassic/source/normalizers.brs - JSON to ContentNode converters
- PlexClassic/source/capabilities.brs - Server feature detection

**Modified (1 file):**
- PlexClassic/source/utils.brs - Added SafeGet helper

**Total lines added:** ~240 lines of BrightScript

## Performance Impact

- Normalizers operate on arrays, O(n) complexity
- ContentNode creation is Roku-optimized
- No network I/O in normalizers (accept pre-fetched JSON)
- Capability parsing happens once per server connection
- Memory efficient: flat structures with references vs. deep nesting

## Next Steps

Phase 01 Plan 03 will likely cover:
- PlexApiTask implementation using these normalizers
- Task node patterns with observer callbacks
- Error handling and logging integration

These normalizers and capability functions are now available for all future API-consuming components.

---

## Self-Check: PASSED

All files verified:
- ✓ PlexClassic/source/normalizers.brs exists
- ✓ PlexClassic/source/capabilities.brs exists
- ✓ Commit 42ff6a4 exists
- ✓ Commit 99bbe86 exists

---

*Plan executed: 2026-02-09*
*Duration: 2 minutes*
*Commits: 42ff6a4, 99bbe86*
