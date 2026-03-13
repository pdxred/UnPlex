---
phase: 12-auto-play-and-watch-state
verified: 2026-03-13T23:59:00Z
status: human_needed
score: 4/4 must-haves verified
re_verification: false
human_verification:
  - test: "Play episode from DetailScreen, seek to last 30 seconds, confirm countdown overlay appears"
    expected: "Auto-play overlay fades in with 'Up Next', episode title, shrinking gold progress bar, and 10-second countdown. No crash."
    why_human: "Cannot execute BrightScript on Roku device programmatically; requires physical device playback"
  - test: "Play episode from EpisodeScreen, seek to last 30 seconds, confirm countdown overlay appears"
    expected: "Same auto-play overlay as DetailScreen. Both entry points behave identically."
    why_human: "Requires physical device playback to confirm both code paths reach showAutoPlayOverlay()"
  - test: "During countdown, press Back, then press Back again on PostPlayScreen"
    expected: "Back during countdown cancels overlay, PostPlayScreen appears. Back on PostPlayScreen returns to calling screen (DetailScreen or EpisodeScreen)."
    why_human: "Key event sequencing and screen stack transitions require live device testing"
  - test: "During countdown, press OK"
    expected: "Countdown cancelled, PostPlayScreen appears with contextual buttons (Play Next if next episode exists, Replay, Back to Library, Play from Timestamp if viewOffset > 0)."
    why_human: "Button layout depends on runtime state (hasNextEpisode, viewOffset) that requires live playback"
  - test: "Watch an episode to completion from EpisodeScreen, return to library grid, inspect poster badge"
    expected: "Poster shows gold checkmark badge (Unicode checkmark on dark background). Previously unwatched posters showed a gold dot; that dot should now be replaced by the checkmark."
    why_human: "Visual rendering on physical Roku; badge visibility depends on ContentNode field propagation via global watchStateUpdate"
  - test: "Watch an episode partially, stop playback (Back key), return to library grid"
    expected: "Poster shows gold progress bar (not checkmark, not dot). Continue Watching hub row reflects updated viewOffset."
    why_human: "Progress bar vs badge coexistence logic and hub ContentNode update require live verification"
---

# Phase 12: Auto-play and Watch State Verification Report

**Phase Goal:** Auto-play next episode fires correctly from every entry point and watch state changes reach all visible screens
**Verified:** 2026-03-13T23:59:00Z
**Status:** human_needed — all automated checks passed; live Roku testing required to confirm runtime behaviour
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from Phase 12 Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Playing an episode from DetailScreen and reaching the auto-play threshold triggers the countdown to the next episode | ✓ VERIFIED | `DetailScreen.startPlayback()` sets `grandparentRatingKey`, `parentRatingKey`, `episodeIndex` on VideoPlayer for episodes (lines 290-300). VideoPlayer uses `m.duration - 30000` threshold and calls `showAutoPlayOverlay()` when in credits range with a valid `m.nextEpisodeInfo`. |
| 2 | Playing an episode from EpisodeScreen and reaching the threshold also triggers the countdown | ✓ VERIFIED | `EpisodeScreen.startPlayback()` sets `grandparentRatingKey = m.top.ratingKey` and `parentRatingKey` from current season (lines 389-397). Same VideoPlayer code path applies. |
| 3 | User can press any remote button during the countdown to cancel and stay on the post-play screen | ✓ VERIFIED | VideoPlayer `onKeyEvent()`: OK key calls `cancelAutoPlay() -> stopPlayback() -> signalPlaybackComplete("cancelled")`; Back key calls `cancelAutoPlay() -> stopPlayback() -> signalPlaybackComplete("stopped")`. Both result in `playbackResult` being emitted, which causes calling screen to push PostPlayScreen via `action="postPlay"`. |
| 4 | Marking an episode watched from EpisodeScreen updates the badge on the poster in the library grid and in the Continue Watching hub row | ✓ VERIFIED | VideoPlayer `scrobble()` emits `m.global.watchStateUpdate` with `viewCount=1`. HomeScreen observes `watchStateUpdate` via `onWatchStateUpdate()` which iterates hub RowList ContentNodes and posterGrid ContentNodes, setting `viewCount`/`viewOffset`. PosterGridItem re-renders with gold checkmark badge when `viewCount > 0`. |

**Score:** 4/4 truths have supporting implementation

---

## Required Artifacts

### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `SimPlex/components/screens/PostPlayScreen.xml` | Post-play action screen layout | ✓ VERIFIED | Exists, 62 lines, full layout with overlay Rectangle, title/subtitle Labels, ButtonGroup. Interface has all required fields: `itemTitle`, `ratingKey`, `grandparentRatingKey`, `hasNextEpisode`, `nextEpisodeInfo`, `viewOffset`, `duration`, `isPlaylist`, `action` (alwaysNotify), `navigateBack` (alwaysNotify). |
| `SimPlex/components/screens/PostPlayScreen.brs` | Post-play action handling and key events | ✓ VERIFIED | Exists, 85 lines. Has `init()`, `buildButtons()`, `onButtonSelected()`, `onKeyEvent()`. `buildButtons()` conditionally includes "Play Next Episode" (when `hasNextEpisode=true`) and "Play from Timestamp" (when `viewOffset > 0`). Back key sets `navigateBack = true`. |
| `SimPlex/components/widgets/VideoPlayer.xml` | `playbackResult` interface field | ✓ VERIFIED | Line 21: `<field id="playbackResult" type="assocarray" alwaysNotify="true" />`. Both progress bar nodes (`autoPlayProgressTrack`, `autoPlayProgressFill`) present in overlay. Heights updated to 145/151 as planned. |
| `SimPlex/components/widgets/VideoPlayer.brs` | `signalPlaybackComplete()`, 30s threshold, season-boundary fetch | ✓ VERIFIED | `signalPlaybackComplete(reason)` exists at line 580 — builds structured AA and sets `m.top.playbackResult`. Threshold uses `m.duration - 30000` (3 confirmed occurrences in grep). `fetchNextSeason()` exists at line 1204. `showAutoPlayOverlay()` sets `autoPlayTitle.text` to "Starting Season X" or "Up Next". `onCountdownTick()` updates `autoPlayProgressFill.width`. |
| `SimPlex/components/screens/DetailScreen.brs` | `grandparentRatingKey` wiring + `playbackResult` observer | ✓ VERIFIED | `startPlayback()` lines 290-300: episode-type guard, sets `grandparentRatingKey`, `parentRatingKey`, `episodeIndex`. Line 302: `observeField("playbackResult", "onPlaybackResult")`. `onPlaybackResult()` at line 311 emits `itemSelected` with `action: "postPlay"`. |
| `SimPlex/components/screens/EpisodeScreen.brs` | `playbackResult` observer replacing `playbackComplete` | ✓ VERIFIED | Line 399: `observeField("playbackResult", "onPlaybackResult")`. `onPlaybackResult()` at line 415 emits `itemSelected` with `action: "postPlay"`. No remaining `playbackComplete` observer in startPlayback(). |
| `SimPlex/components/MainScene.brs` | `PostPlayScreen` routing via `onItemSelected` | ✓ VERIFIED | `showPostPlayScreen()` exists at line 227, creates `PostPlayScreen`, sets all fields, observes `action` and `navigateBack`. `onPostPlayAction()` handles all four actions. `onItemSelected()` at line 455: `else if data.action = "postPlay"` routes to `showPostPlayScreen(data)`. |

### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `SimPlex/components/widgets/VideoPlayer.brs` | `watchStateUpdate` emission in `scrobble()` | ✓ VERIFIED | Lines 534-539: `m.global.watchStateUpdate = { ratingKey, viewCount: 1, viewOffset: 0 }` after `task.control = "run"` in `scrobble()`. Also emitted in `signalPlaybackComplete()` for stopped/cancelled (lines 582-588). |
| `SimPlex/components/widgets/PosterGridItem.xml` | `watchedBadge` Label and `watchedBadgeBg` Rectangle nodes | ✓ VERIFIED | Lines 57-74: `watchedBadgeBg` Rectangle and `watchedBadge` Label with `&#x2713;` text, gold color `0xF3B125FF`, both `visible="false"`. |
| `SimPlex/components/widgets/PosterGridItem.brs` | Three-state badge logic with checkmark for watched | ✓ VERIFIED | `init()` finds both nodes. `updateBadge()`: (1) progress-bar guard hides all four badge nodes; (2) fully watched shows checkmark + bg; (3) TV show fully-watched (leafCount=viewedLeafCount) shows checkmark; (4) unwatched shows gold dot. Mutually exclusive. |

---

## Key Link Verification

### Plan 01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DetailScreen.brs` | `VideoPlayer` | `grandparentRatingKey/parentRatingKey/episodeIndex` set in `startPlayback()` | ✓ WIRED | Lines 290-300 confirmed. Guard `if m.itemData.type = "episode"` protects movie playback. |
| `VideoPlayer.brs` | calling screen | `playbackResult` field (replaces `playbackComplete`) | ✓ WIRED | `m.top.playbackResult = result` in `signalPlaybackComplete()` (line 603). Both DetailScreen and EpisodeScreen observe `playbackResult` not `playbackComplete`. |
| `DetailScreen.brs / EpisodeScreen.brs` | `MainScene.brs` | `itemSelected` with `action="postPlay"` | ✓ WIRED | Both `onPlaybackResult()` handlers emit `m.top.itemSelected = { action: "postPlay", ... }`. MainScene `onItemSelected()` routes to `showPostPlayScreen()`. |
| `MainScene.brs` | `PostPlayScreen` | `showPostPlayScreen()` called from `onItemSelected` | ✓ WIRED | `showPostPlayScreen()` pushes PostPlayScreen to screen stack, observes `action` and `navigateBack`. `onPostPlayAction()` handles all four button actions. `onNavigateBack()` calls `popScreen()`. |

### Plan 02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `VideoPlayer.brs` | `m.global.watchStateUpdate` | `scrobble()` emits watchStateUpdate AA | ✓ WIRED | `m.global.watchStateUpdate = { ratingKey, viewCount: 1, viewOffset: 0 }` in `scrobble()` confirmed. |
| `HomeScreen.brs` | `PosterGridItem` | `onWatchStateUpdate` updates ContentNode fields → PosterGridItem re-renders | ✓ WIRED | HomeScreen `onWatchStateUpdate()` (line 1475) iterates hub rows and poster grid ContentNodes, sets `viewCount`/`viewOffset`. PosterGridItem responds to `itemContent` field change, re-calls `updateBadge()`. |
| `PosterGridItem.brs` | `watchedBadge`/`watchedBadgeBg` nodes | `updateBadge()` sets visibility based on `viewCount` | ✓ WIRED | `updateBadge()` confirmed: `m.watchedBadge.visible = true` and `m.watchedBadgeBg.visible = true` when `viewCount > 0`. |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| FIX-01 | 12-01-PLAN.md | Auto-play next episode fires correctly from both EpisodeScreen and DetailScreen (grandparentRatingKey wiring) | ✓ SATISFIED | `DetailScreen.startPlayback()` now sets `grandparentRatingKey`/`parentRatingKey`/`episodeIndex` for episodes. Both screens observe `playbackResult`. VideoPlayer has season-boundary fetch via `fetchNextSeason()`. |
| FIX-02 | 12-01-PLAN.md | Auto-play countdown can be cancelled by user | ✓ SATISFIED | Back key during countdown: `cancelAutoPlay() -> stopPlayback() -> signalPlaybackComplete("stopped")`. OK key: `signalPlaybackComplete("cancelled")`. Both route to PostPlayScreen. `onNavigateBack` pops PostPlayScreen on Back press. |
| FIX-03 | 12-02-PLAN.md | Watch state changes propagate to parent screens (poster grids and hub rows) | ✓ SATISFIED | VideoPlayer emits `m.global.watchStateUpdate` in `scrobble()` (finished) and `signalPlaybackComplete()` (stopped/cancelled). HomeScreen and EpisodeScreen both observe and update ContentNodes. PosterGridItem shows checkmark for watched, progress bar for in-progress. |

All three requirements claimed by Phase 12 are satisfied by code that is confirmed present and wired.

---

## Anti-Patterns Found

No stub or placeholder patterns found in any modified files. All modified files contain substantive implementations. No `TODO`/`FIXME`/`XXX` or empty handler patterns detected in the phase deliverables.

One notable design decision documented in SUMMARY: `playbackComplete` boolean field is kept in `VideoPlayer.xml` because `HomeScreen` and `PlaylistScreen` still reference it. This is intentional (documented as a key decision), not a gap. Those screens are not in scope for Phase 12.

---

## Human Verification Required

### 1. Auto-play countdown from DetailScreen

**Test:** Navigate to a TV episode via the library grid, open DetailScreen, press Play. Seek to within the last 30 seconds.
**Expected:** Auto-play overlay fades in showing "Up Next", the next episode title, a shrinking gold progress bar, and a countdown from 10. No crash or freeze.
**Why human:** Cannot execute BrightScript playback on a Roku device programmatically.

### 2. Auto-play countdown from EpisodeScreen

**Test:** Navigate to a TV show, enter EpisodeScreen, select an episode that has a known next episode. Seek to within the last 30 seconds.
**Expected:** Same countdown overlay appears. Both entry points must work.
**Why human:** Two separate code paths reach the same VideoPlayer logic — requires device confirmation that grandparentRatingKey is correctly passed from EpisodeScreen.

### 3. Cancel countdown with Back key

**Test:** While countdown overlay is visible, press Back.
**Expected:** Countdown stops, PostPlayScreen appears over a dark overlay. Pressing Back again dismisses PostPlayScreen and returns to the calling screen (DetailScreen or EpisodeScreen).
**Why human:** Key event sequencing and screen stack transitions (two Back presses, two screen pops) require live device testing.

### 4. Cancel countdown with OK key

**Test:** While countdown overlay is visible, press OK.
**Expected:** Countdown stops, PostPlayScreen appears with buttons: "Play Next Episode" (if there is a next episode), "Replay", "Back to Library", and "Play from Timestamp" (if playback was stopped with a viewOffset > 0).
**Why human:** Button set is dynamic based on runtime state; requires live playback state.

### 5. Watched badge after completing an episode

**Test:** Watch a TV episode to completion (let the video finish naturally). Navigate back to the library grid.
**Expected:** The poster for the watched episode shows a gold checkmark badge in the top-right corner. Previously it showed only a gold dot (unwatched) or nothing (if already watched without checkmark).
**Why human:** Badge visibility depends on ContentNode update propagating through the global watchStateUpdate to HomeScreen and then being reflected in PosterGridItem rendering on a physical Roku.

### 6. Progress badge after stopping midway

**Test:** Play a TV episode, watch approximately 30-60% of it, then press Back to stop. Return to the library grid.
**Expected:** The poster shows a gold progress bar at the bottom. The Continue Watching hub row should reflect the updated position. No checkmark badge should appear.
**Why human:** Coexistence of progress bar vs badge states, and hub row ContentNode update from watchStateUpdate with viewCount=0, requires live device confirmation.

---

## Gaps Summary

No gaps found. All must-have artifacts are present, substantive, and wired. All three requirements (FIX-01, FIX-02, FIX-03) have confirmed implementation evidence.

The phase is blocked on human verification only. The six test cases above cover all four success criteria listed in the phase brief. Once a human confirms the device tests pass, the phase can be marked complete.

---

_Verified: 2026-03-13T23:59:00Z_
_Verifier: Claude (gsd-verifier)_
