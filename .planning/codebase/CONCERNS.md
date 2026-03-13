# Codebase Concerns

**Analysis Date:** 2026-03-13

## Critical Issues

### SIGSEGV Firmware Crash on HomeScreen Init

**Issue:** HomeScreen causes native firmware crash (signal 11) when sideloaded to Roku device. Not a BrightScript error but a native Roku OS crash.

**Files:** `SimPlex/components/screens/HomeScreen.brs`, `SimPlex/components/screens/HomeScreen.xml`, `SimPlex/components/screens/DetailScreen.brs`

**Root Cause:** Bisection identified that `LoadingSpinner` component with `BusySpinner` widget is the culprit. Additionally, a `visible` field in LoadingSpinner, FilterBottomSheet, and TrackSelectionPanel interfaces shadowed the built-in Node.visible property causing field conflicts.

**Current Mitigation:**
- LoadingSpinner removed from HomeScreen (line 7: `m.loadingSpinner = invalid`)
- DetailScreen has same mitigation (line 10)
- BusySpinner references renamed to `showSpinner`, `showSheet`, `showPanel` in all 7 screen files (37 total references updated)
- HomeScreen.brs and HomeScreen.xml in diagnostic state with `.bak` backup files saved

**Scaling Impact:** Blocks full HomeScreen functionality and hub row rendering until resolved

**Safe Modification:**
1. Test if issue persists with current visible field renames
2. If LoadingSpinner still causes crash, replace with simple rotating Poster or ASCII spinner (no BusySpinner)
3. If animations cause crash, create them dynamically at runtime instead of in XML
4. Once crash fixed, restore HomeScreen from `.bak` files and re-add all task logic

---

## Unsatisfied Requirements (v1.0 Milestone)

### Auto-Play Next Episode Not Wired

**Issue:** Auto-play countdown never triggers. EpisodeScreen and DetailScreen never set `parentRatingKey` and `grandparentRatingKey` on VideoPlayer node.

**Requirements:** PLAY-12, PLAY-13

**Files:** `SimPlex/components/screens/EpisodeScreen.brs` (line 465: TODO comment), `SimPlex/components/screens/DetailScreen.brs`, `SimPlex/components/widgets/VideoPlayer.brs` (line 967 checks `grandparentRatingKey`)

**Evidence:** VideoPlayer.brs line 967-969 checks if `m.top.grandparentRatingKey` is empty - always true because callers never set it. Auto-play logic at VideoPlayer.brs line 965-981 unreachable.

**Impact:**
- Skip intro/credits → Auto-play next flow completely broken
- End-of-episode flow breaks into main screen instead of starting next episode
- Affects end-to-end flow: "Hub Row → Resume → Skip Intro → Auto-play"

**Fix Approach:** Both `EpisodeScreen.startPlayback()` and `DetailScreen.startPlayback()` must set these fields before starting playback:
```brightscript
m.player.parentRatingKey = seasonRatingKey
m.player.grandparentRatingKey = showRatingKey
m.player.episodeIndex = episodeNumber
m.player.seasonIndex = seasonNumber
```

---

### Watch State Not Propagated to Parent Screens

**Issue:** Marking watched/unwatched on DetailScreen doesn't propagate to parent grid/hub rows. DetailScreen has `watchStateChanged` field but parent screens never observe it.

**Requirements:** PLAY-04, PLAY-05

**Files:** `SimPlex/components/screens/DetailScreen.brs`, `SimPlex/components/screens/HomeScreen.brs`

**Evidence:** Stale UI on back navigation - grid items still show unwatched state after marking watched on detail screen

**Impact:** User confusion - watched status inconsistency until auto-refresh (2 minute timer)

**Fix Approach:** HomeScreen must observe `watchStateChanged` field from child DetailScreen and update grid/hub row UI immediately on back navigation

---

## Orphaned Code

### Unused Source Files

**Files:** `SimPlex/source/normalizers.brs`, `SimPlex/source/capabilities.brs`

**What's Unused:**
- `normalizers.brs` - 5 functions (NormalizeMovieList, NormalizeShowList, NormalizeSeasonList, NormalizeEpisodeList, NormalizeOnDeck) never imported or called anywhere in codebase
- `capabilities.brs` - 4 functions (ParseServerCapabilities, HasCapability, GetMinVersionForFeature, MeetsMinVersion) never imported or called anywhere

**Risk:**
- Dead code increases maintenance burden
- No verification that these functions work (never executed)
- Creates confusion about available utilities

**Fix Approach:** Either integrate into active code paths or remove entirely. If server capabilities feature needed in future, rebuild rather than rely on untested code.

---

## UX Gaps

### Collections Require Library Selection First

**Issue:** Collections cannot be browsed without first selecting a library. No feedback when user clicks Collections from sidebar.

**Files:** `SimPlex/components/screens/HomeScreen.brs` (line 59-60: collections view state), `SimPlex/components/widgets/Sidebar.brs`

**Evidence:** Collections view requires `collectionRatingKey` to be populated first; sidebar has no "browse all collections" action, only library-specific collection browsing

**Impact:** Collections appear in sidebar but aren't directly accessible - UX dead-end

**Improvement Path:**
1. Add "All Collections" action to sidebar that doesn't require library selection
2. Load top-level collections list from `/library/collections`
3. Show collections grid without library context

---

### Continue Watching Routes to Detail Instead of Direct Playback

**Issue:** Continue Watching (On Deck) items route to DetailScreen instead of starting playback directly.

**Files:** `SimPlex/components/screens/HomeScreen.brs` (startPlaybackFromHub flow)

**Evidence:** Gap documented in v1.0 milestone audit as deliberate interim decision never revisited

**Impact:** Extra click required for resume playback - friction in primary use case

**Improvement Path:** Distinguish between "resume" items (go straight to playback) and "new" items (go to detail). Use `viewOffset > 0` to signal resume vs fresh start.

---

## Tech Debt

### No Pagination Limits on Large Libraries

**Issue:** While pagination headers (`X-Plex-Container-Start`, `X-Plex-Container-Size`) are implemented, there's no protection against unbounded library fetches.

**Files:** `SimPlex/components/screens/HomeScreen.brs` (560-561, 790-791, 904-905), `SimPlex/components/tasks/PlexApiTask.brs`

**Risk:** Users with 10,000+ item libraries could cause memory spikes or timeout on initial browse

**Current Approach:** PAGE_SIZE = 50 (from constants), but no maximum total fetch or lazy-load boundary

**Improvement Path:** Implement "stop loading after 5 pages" logic with "Load More" button for large libraries

---

### HomeScreen Complexity

**Issue:** HomeScreen.brs is 1,685 lines (largest component). Contains mixed concerns: hub loading, library browsing, filter/sort logic, grid management, screen stacking.

**Files:** `SimPlex/components/screens/HomeScreen.brs`

**Risk:**
- Hard to debug (bisection required 4 test iterations)
- Single-point-of-failure for app startup
- Difficult to test individual features in isolation

**Fragile Areas:**
- Hub refresh timer lifecycle (line 87-91)
- Focus delegation chain (multiple screens, sidebar, filters)
- Filter bottom sheet creation on-demand

**Safe Modification Path:**
1. Extract hub-specific logic to HubScreenState module
2. Extract filter/sort logic to FilterScreenState module
3. Keep HomeScreen as orchestrator only
4. Add comprehensive logging at state transition boundaries

---

### VideoPlayer Complexity

**Issue:** VideoPlayer.brs is 1,365 lines. Contains playback, seeking, track selection, intro/credits skip, auto-play, transcoding, and session reporting logic.

**Files:** `SimPlex/components/widgets/VideoPlayer.brs`

**Risk:** Same as HomeScreen - high complexity makes bugs hard to isolate

**Fragile Areas:**
- Transcode pivot logic (isTranscodePivotInProgress state machine)
- Auto-play countdown timer and rounding (multiple timer interactions)
- Skip button appearance/focus during playback
- Session reporting with 10-second flush logic

**Test Coverage Gap:** Transcode pivot workflow never tested in UAT (Phase 6 verification missing)

---

## Missing Verification

### Phases 6-10 Never Tested in UAT

**Issues:**
- Phase 6 (Audio/Subtitles) - marked "likely satisfied" but never verified
- Phase 7 (Intro/Credits Skip) - marked "likely satisfied" but never verified
- Phase 8 (Auto-play Next) - marked "unsatisfied" due to wiring gap
- Phase 9 (Collections/Playlists) - marked "likely satisfied" but never verified
- Phase 10 (Managed Users) - marked "likely satisfied" but never verified

**Files:** `.planning/v1.0-MILESTONE-AUDIT.md` (lines 173-179)

**Impact:** Unknown count of silent bugs in 50% of v1.0 features

**Verification Path:** Create comprehensive UAT test cases for each phase that weren't covered in Phase 4 verification

---

## Error Handling Gaps

### No Graceful Recovery from Network Errors

**Issue:** If PMS becomes unreachable mid-session, app doesn't provide user-facing recovery UI (only retry button on specific screens).

**Files:** All task nodes (`SimPlex/components/tasks/*.brs`), HomeScreen error handling

**Current Approach:** Global `serverReconnected` signal observed by screens, but no active reconnection retry loop

**Risk:** Users see stuck/frozen UI until manually restarting app

**Improvement Path:** Implement exponential backoff retry for failed API calls with visual countdown

---

## Performance Concerns

### No Image Cache Cleanup

**Issue:** ImageCacheTask prefetches poster images but there's no cache eviction policy.

**Files:** `SimPlex/components/tasks/ImageCacheTask.brs`

**Risk:** Devices with low storage could fill temp cache over extended sessions

**Current Approach:** Cache to `/tmp/` but no TTL or size limit

**Improvement Path:**
1. Implement 24-hour TTL on cached images
2. Add 500MB size limit with LRU eviction
3. Clear cache on app exit

---

### Hub Refresh Every 2 Minutes

**Issue:** HomeScreen refreshes hub rows every 120 seconds (line 88) regardless of visibility or user activity.

**Files:** `SimPlex/components/screens/HomeScreen.brs` (87-91)

**Impact:** Network traffic and battery drain on idle screen

**Improvement Path:**
1. Pause timer when screen not in focus
2. Allow user configuration (30 sec to 10 min interval)
3. Manual refresh button instead of forced auto-refresh

---

## Security Considerations

### Tokens Stored in Registry Without Encryption

**Issue:** Auth tokens stored in plain text in Roku registry via `roRegistrySection`.

**Files:** `SimPlex/source/utils.brs` (lines 14-24, 39-50)

**Risk:** If registry is compromised or device stolen, attacker gains access to user's Plex library and all shared libraries

**Current Mitigation:** Roku devices are typically in trusted home network, registry access requires physical device

**Recommendation:** This is acceptable for a side-loaded Roku app but document this risk clearly

**Long-term Improvement:** Request Roku provide encrypted registry or request users disable this device in their Plex account when decommissioning

---

### X-Plex-Token Exposed in URLs

**Issue:** Auth token passed as URL query parameter in some calls.

**Files:** `SimPlex/source/utils.brs` (line 145: BuildPlexUrl includes token in URL)

**Risk:** Tokens logged in server logs, browser history, etc.

**Mitigation:** HTTPS used for all connections, but token still visible in logs

**Recommendation:** Implement X-Plex-Token header for all requests instead of query parameter

---

## Scaling Limits

### Fixed Grid Dimensions

**Issue:** Layout hardcoded to FHD 1920x1080. No support for HD or 4K devices.

**Files:** All XML components, `SimPlex/source/constants.brs`

**Constants:**
- SIDEBAR_WIDTH: 280 (fixed)
- POSTER_WIDTH: 240 (fixed)
- POSTER_HEIGHT: 360 (fixed)
- GRID_COLUMNS: 6 (fixed)

**Impact:** UI may be undersized on 4K displays, oversized on HD

**Scaling Path:** Detect display resolution at runtime and adjust constants

---

### No Offline Support

**Issue:** App requires PMS connection for all operations. No caching or offline browsing.

**Risk:** Users cannot browse library if network is slow or temporarily down

**Improvement Path:** Cache library metadata and allow read-only offline browsing (playback still requires stream)

---

## Dependencies at Risk

### Roku OS Compatibility

**Issue:** BusySpinner widget causes native firmware crash - indication that Roku compatibility layer needs review.

**Risk:** Future Roku OS updates could break more components

**Mitigation Strategy:**
1. Test on latest Roku firmware (currently targeting Roku 9+)
2. Maintain compatibility layer for UI components
3. Monitor Roku forums for component deprecations

---

### Plex API Stability

**Issue:** Direct dependency on Plex Media Server API endpoints. No versioning strategy or compatibility shim.

**Files:** All task nodes call specific endpoints (`/library/sections`, `/library/sections/{id}/all`, `/hubs/search`, etc.)

**Risk:** PMS API change breaks app across all installations

**Mitigation:** SafeGet() function provides defensive parsing, but no endpoint versioning

**Improvement Path:** Create API client abstraction layer that can detect server version and adapt endpoint calls

---

## Test Coverage Gaps

### No Unit Tests for BrightScript Code

**Issue:** Entire codebase is untested except for manual UAT of Phases 1-5.

**Files:** All `.brs` files

**Risk:** Regressions go undetected until manual UAT

**Barrier:** Roku testing frameworks are limited (no standard Jest/vitest equivalent)

**Improvement Path:**
1. Use bsc (Roku compiler) for syntax validation
2. Extract testable functions to utils (SafeGet, FormatTime, etc.)
3. Create simple BrightScript test harness for core utilities

---

### No Transcode Pivot Testing

**Issue:** Transcode pivot workflow (Phase 6) implemented but never executed in UAT.

**Files:** `SimPlex/components/widgets/VideoPlayer.brs` (transcode state machine: lines 44-46, 1181-1234)

**Fragile Areas:**
- Pivot trigger detection (subtitle type change during playback)
- State coordination between old and new video nodes
- Session reporting continuity across pivot

**Risk:** Silent failures during PGS subtitle selection

**Improvement Path:** Create scripted test case with transcoded PGS file, verify seamless pivot

---

### No Auto-Play Next Testing

**Issue:** Auto-play feature (Phase 8) not testable due to wiring gap. Can't verify countdown UI, audio cues, or skip behavior.

**Files:** `SimPlex/components/widgets/VideoPlayer.brs` (lines 965-981, auto-play trigger)

**Verification Path:** Once wiring fixed, test:
1. Countdown appears at 90% of episode duration
2. Sound cue plays
3. Skip button allows cancellation
4. Auto-skip moves to next episode
5. User can resume countdown from Settings

---

## Breaking Changes Risk

### Manifest Version Constraints

**Issue:** No version negotiation with PMS. App assumes certain API behavior without checking server version.

**Files:** `SimPlex/manifest` (version: auto-incremented on each build)

**Risk:** Older PMS versions (pre-1.30) don't have intro/credits markers but code doesn't detect this

**Current Mitigation:** capabilities.brs has version detection but it's never called (orphaned code)

**Improvement Path:**
1. Call ParseServerCapabilities on server connect
2. Store capabilities in m.global
3. Conditionally show UI features based on capabilities

---

*Concerns audit: 2026-03-13*
