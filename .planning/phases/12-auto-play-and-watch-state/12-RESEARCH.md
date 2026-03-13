# Phase 12: Auto-play and Watch State - Research

**Researched:** 2026-03-13
**Domain:** BrightScript / Roku SceneGraph — VideoPlayer auto-play wiring, post-play screen, watch state propagation
**Confidence:** HIGH (all findings derived from direct codebase inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Countdown overlay:**
- Small card in bottom-right corner of the screen while video continues playing behind it
- Card shows: next episode thumbnail, title (e.g., S2E5 "Title"), and countdown number
- 10-second countdown timer
- Thin progress bar underneath the countdown that shrinks as the timer counts down
- For playlists, show position info (e.g., "Next: Item 4 of 12")
- When crossing season boundaries, show notice (e.g., "Starting Season 2")

**Post-play behavior:**
- Countdown triggers at the last 30 seconds of playback (fixed threshold, no credits detection)
- Video continues playing behind the countdown overlay — no pause or dim
- Auto-play works for TV episodes AND playlist items
- Auto-play crosses season boundaries seamlessly with a "Starting Season X" notice in the countdown card
- When no next item exists (last episode/movie), show "series complete" or "playlist complete" message then transition to post-play screen

**Cancel interaction:**
- Back button cancels countdown AND returns to previous screen (DetailScreen or EpisodeScreen)
- OK button cancels countdown AND stays on a post-play info screen
- Post-play info screen shows four actions: Play Next Episode, Replay Episode, Back to Library, Play from Timestamp
- Post-play screen appears after EVERY video ends (not just when auto-play was cancelled) — consistent experience
- When no next episode exists, post-play screen omits "Play Next Episode" button

**Watch state badges:**
- Individual episodes: gold dot badge in corner when unwatched
- Series/season posters: numbered count badge showing unwatched episode count
- Partially watched: progress bar along bottom edge of poster
- Fully watched: small checkmark badge
- Watch state propagates to ALL visible screens in the stack: library poster grid, Continue Watching hub row, detail screens, episode screens

### Claude's Discretion
- Countdown card exact dimensions and positioning within bottom-right area
- Animation/transition effects for countdown appearance/disappearance
- Post-play screen layout and button styling
- Badge icon sizes and exact positioning on posters
- How to efficiently walk the screen stack to propagate watch state changes

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FIX-01 | Auto-play next episode fires correctly from both EpisodeScreen and DetailScreen (grandparentRatingKey wiring) | DetailScreen.startPlayback() does not set grandparentRatingKey/parentRatingKey/episodeIndex on VideoPlayer — VideoPlayer's fetchNextEpisode() gates on parentRatingKey being non-empty, so auto-play never fires from DetailScreen. Fix: pass these fields in DetailScreen.startPlayback(). |
| FIX-02 | Auto-play countdown can be cancelled by user | Countdown exists in VideoPlayer but: (a) back key cancels overlay but then propagates up and exits the player entirely instead of returning to the calling screen; (b) OK key calls startNextEpisode() instead of navigating to post-play screen. Needs redesigned key handler and a new PostPlayScreen. |
| FIX-03 | Watch state changes propagate to parent screens (poster grids and hub rows) | Infrastructure is already in place (m.global.watchStateUpdate, HomeScreen and EpisodeScreen observers). Gap: VideoPlayer's scrobble() after auto-play does not emit watchStateUpdate. Also after playback completes naturally, no watchStateUpdate is emitted. Badge rendering (unwatched dot, checkmark) needs image assets and PosterGridItem/.brs logic. |
</phase_requirements>

---

## Summary

Phase 12 addresses three tightly related bugs in the playback and watch-state systems. All three bugs are confirmed by direct codebase inspection — the infrastructure partially exists but has specific wiring gaps.

**FIX-01 (grandparentRatingKey wiring):** `DetailScreen.startPlayback()` creates a VideoPlayer and sets `ratingKey`, `mediaKey`, `startOffset`, and `itemTitle`, but does NOT set `grandparentRatingKey`, `parentRatingKey`, or `episodeIndex`. VideoPlayer's `fetchNextEpisode()` guards on `m.top.parentRatingKey <> ""` — so auto-play never triggers from DetailScreen. The fix is to fetch the episode's season/show context when launching from DetailScreen and pass all three fields. EpisodeScreen.startPlayback() already sets these correctly (lines 389-397) and does work, so the gap is DetailScreen-only.

**FIX-02 (cancellable countdown + post-play screen):** The countdown overlay already exists in VideoPlayer.xml/brs with a 10-second timer. The current cancel behaviour (`cancelAutoPlay()`) just hides the overlay — it does not navigate to a post-play screen or back to the calling screen. The `back` key in `onKeyEvent` calls `cancelAutoPlay()` and then falls through to `stopPlayback()` + `playbackComplete = true`, which exits the player entirely. Separate navigation intent (`navigateBack` vs `showPostPlay`) is needed. A new PostPlayScreen component must be created. The user decision specifies post-play appears after EVERY video end, so VideoPlayer must always signal this rather than emitting `playbackComplete` directly.

**FIX-03 (watch state propagation):** The global `watchStateUpdate` field and observers already exist in HomeScreen and EpisodeScreen. However, `scrobble()` in VideoPlayer fires a silent API call with no corresponding `watchStateUpdate` emission. After auto-play advances episodes or after natural completion, the parent screens are never told the current episode is watched. The fix: emit `watchStateUpdate` from VideoPlayer after scrobble, and ensure PosterGridItem renders the new badge types (checkmark for fully watched, unwatched count for series). Badge images `badge-unwatched.png` already exists; `badge-watched.png` (checkmark) does not yet exist.

**Primary recommendation:** Fix all three in two plans — Plan 01 handles FIX-01 (grandparentRatingKey wiring) and FIX-02 (post-play screen architecture), Plan 02 handles FIX-03 (watch state emission + badge rendering).

---

## Standard Stack

This is a pure BrightScript/SceneGraph project — no external libraries. The "stack" is Roku platform primitives.

### Core Platform Primitives

| Component | Version | Purpose | Usage Pattern |
|-----------|---------|---------|---------------|
| Roku SceneGraph | Platform | UI component tree | XML + .brs pairs |
| BrightScript Timer node | Platform | Countdown ticking | duration=1, repeat=true, observeField("fire") |
| BrightScript Animation node | Platform | Fade in/out of overlays | FloatFieldInterpolator on opacity |
| m.global | Platform | Cross-screen signal bus | addFields + observeField |
| ContentNode | Platform | Data binding to MarkupGrid/LabelList | createChild + addFields |

### Existing Components This Phase Touches

| Component | File | Role |
|-----------|------|------|
| VideoPlayer | widgets/VideoPlayer.xml + .brs | Auto-play logic, countdown overlay, key handling |
| DetailScreen | screens/DetailScreen.brs | Launches player — missing grandparentRatingKey wiring |
| EpisodeScreen | screens/EpisodeScreen.brs | Launches player — already wired correctly |
| HomeScreen | screens/HomeScreen.brs | Observes watchStateUpdate, updates hub rows and grid |
| PosterGridItem | widgets/PosterGridItem.xml + .brs | Renders badges — needs checkmark badge support |
| EpisodeItem | widgets/EpisodeItem.xml | Renders episode-level unwatched badge |
| MainScene | components/MainScene.brs | Screen stack, pushes PostPlayScreen |

### New Components Required

| Component | File | Role |
|-----------|------|------|
| PostPlayScreen | screens/PostPlayScreen.xml + .brs | Post-play action menu (Play Next, Replay, Library, Timestamp) |
| badge-watched.png | images/badge-watched.png | Checkmark badge for fully-watched items |

---

## Architecture Patterns

### Current Auto-play Architecture (What Exists)

VideoPlayer contains all countdown/auto-play logic internally:

```
checkMarkers() [called from onPositionChange every tick]
  └── if inCredits and grandparentRatingKey set
        └── fetchNextEpisode() [PlexApiTask to /library/metadata/{parentRatingKey}/children]
              └── onNextEpisodeLoaded() → sets m.nextEpisodeInfo
                    └── showAutoPlayOverlay() → starts 10-second countdown Timer
                          └── onCountdownTick() → startNextEpisode() at 0
```

The threshold is currently `m.duration * 0.9` (90%). User decision changes this to a fixed **last 30 seconds**: `m.currentPosition >= m.duration - 30000`.

### Pattern 1: grandparentRatingKey Wiring in DetailScreen

**What:** DetailScreen must fetch season/show context before launching VideoPlayer when the item is a TV episode.

**When to use:** Only when `m.itemData.type = "episode"`.

**Current gap:** `DetailScreen.startPlayback()` does not set any of `grandparentRatingKey`, `parentRatingKey`, `episodeIndex`:

```brightscript
' CURRENT (broken for auto-play from DetailScreen)
sub startPlayback(offset as Integer)
    ratingKeyStr = GetRatingKeyStr(m.itemData.ratingKey)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = ratingKeyStr
    m.player.mediaKey = "/library/metadata/" + ratingKeyStr
    m.player.startOffset = offset
    m.player.itemTitle = m.itemData.title
    m.player.observeField("playbackComplete", "onPlaybackComplete")
    ' NOTE: grandparentRatingKey, parentRatingKey, episodeIndex NOT SET
    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub
```

**Fix — use metadata already in m.itemData:**

The episode metadata from `/library/metadata/{ratingKey}` includes `parentRatingKey` (season) and `grandparentRatingKey` (show) and `index` (episode number) directly. `m.itemData` is already populated when `startPlayback` is called.

```brightscript
' FIXED
sub startPlayback(offset as Integer)
    ratingKeyStr = GetRatingKeyStr(m.itemData.ratingKey)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = ratingKeyStr
    m.player.mediaKey = "/library/metadata/" + ratingKeyStr
    m.player.startOffset = offset
    m.player.itemTitle = m.itemData.title

    ' Wire auto-play fields from episode metadata (type = "episode" only)
    if m.itemData.type = "episode"
        if m.itemData.grandparentRatingKey <> invalid
            m.player.grandparentRatingKey = GetRatingKeyStr(m.itemData.grandparentRatingKey)
        end if
        if m.itemData.parentRatingKey <> invalid
            m.player.parentRatingKey = GetRatingKeyStr(m.itemData.parentRatingKey)
        end if
        if m.itemData.index <> invalid
            m.player.episodeIndex = m.itemData.index
        end if
    end if

    m.player.observeField("playbackComplete", "onPlaybackComplete")
    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub
```

**Confidence:** HIGH — `parentRatingKey` and `grandparentRatingKey` are standard Plex API fields returned for episode items, confirmed by how EpisodeScreen parses them via `m.seasons` array (the season's `ratingKey` is the `parentRatingKey`). The `m.itemData` AA from `/library/metadata/{ratingKey}` for an episode includes these directly.

### Pattern 2: Post-play Signal vs playbackComplete

**Current behaviour:** VideoPlayer emits `m.top.playbackComplete = true` when the video ends. The calling screen (DetailScreen or EpisodeScreen) observes this and removes the VideoPlayer from the scene.

**Required behaviour:** Post-play screen must appear after every video end. VideoPlayer should signal the calling screen with rich context (what just played, is there a next episode, etc.) so the calling screen can push PostPlayScreen.

**Option A — VideoPlayer emits structured result (recommended):**

Add a new interface field `playbackResult` (assocarray, alwaysNotify). VideoPlayer sets this instead of bare `playbackComplete`. The calling screen observes it and pushes PostPlayScreen with the context.

```brightscript
' In VideoPlayer.xml <interface>:
' <field id="playbackResult" type="assocarray" alwaysNotify="true" />

' In VideoPlayer.brs, replace bare playbackComplete:
sub signalPlaybackComplete(reason as String)
    result = {
        reason: reason          ' "finished", "stopped", "error"
        ratingKey: m.top.ratingKey
        itemTitle: m.top.itemTitle
        hasNextEpisode: (m.nextEpisodeInfo <> invalid)
        nextEpisodeInfo: m.nextEpisodeInfo  ' may be invalid
        grandparentRatingKey: m.top.grandparentRatingKey
    }
    m.top.playbackResult = result
end sub
```

**Option B — Keep playbackComplete, add separate postPlayContext field:**

Less disruptive to existing code. VideoPlayer always sets `postPlayContext` before `playbackComplete = true`.

**Recommendation:** Use Option A — a single structured result is cleaner. All existing `playbackComplete` observers (DetailScreen, EpisodeScreen) are replaced with `playbackResult` observers.

### Pattern 3: PostPlayScreen

PostPlayScreen is a new full-screen component that receives context from the calling screen.

**Interface fields:**
```xml
<field id="itemTitle" type="string" />
<field id="ratingKey" type="string" />
<field id="grandparentRatingKey" type="string" />
<field id="hasNextEpisode" type="boolean" value="false" />
<field id="nextEpisodeInfo" type="assocarray" />
<field id="startOffset" type="integer" value="0" />
<field id="action" type="string" alwaysNotify="true" />
```

**Actions:** `"playNext"`, `"replay"`, `"backToLibrary"`, `"playFromTimestamp"`.

MainScene handles the `action` field by navigating appropriately. Back button on PostPlayScreen fires `navigateBack`.

**Pushed from calling screens** after they receive `playbackResult`:

```brightscript
' In DetailScreen / EpisodeScreen:
sub onPlaybackResult(event as Object)
    result = event.getData()
    if result = invalid then return

    ' Remove video player
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if

    ' Push post-play screen via MainScene
    m.top.itemSelected = {
        action: "postPlay"
        ratingKey: result.ratingKey
        itemTitle: result.itemTitle
        hasNextEpisode: result.hasNextEpisode
        nextEpisodeInfo: result.nextEpisodeInfo
        grandparentRatingKey: result.grandparentRatingKey
        startOffset: m.lastPlayedOffset  ' stored during playback
    }
end sub
```

### Pattern 4: Countdown Threshold Change

**Current threshold:** `m.duration * 0.9` (90% of duration).

**Required threshold:** Last 30 seconds — `m.currentPosition >= m.duration - 30000`.

Change is in `checkMarkers()` in VideoPlayer.brs:

```brightscript
' CURRENT (line ~966-971):
if m.top.grandparentRatingKey <> "" and m.top.grandparentRatingKey <> invalid
    if currentPos >= m.duration * 0.9
        inCredits = true
    end if
end if

' FIXED:
if m.top.grandparentRatingKey <> "" and m.top.grandparentRatingKey <> invalid
    if m.duration > 0 and currentPos >= m.duration - 30000
        inCredits = true
    end if
end if
```

### Pattern 5: Watch State Emission from VideoPlayer

**Current gap:** `scrobble()` fires a silent API call, but does NOT write to `m.global.watchStateUpdate`. Parent screens (HomeScreen, EpisodeScreen) observe `watchStateUpdate` and are ready to receive updates — but the VideoPlayer never sends one.

**Fix:** After `scrobble()` in VideoPlayer, emit the update:

```brightscript
sub scrobble()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": m.top.ratingKey
    }
    task.control = "run"

    ' Emit watch state update to propagate to all visible screens
    m.global.watchStateUpdate = {
        ratingKey: m.top.ratingKey
        viewCount: 1
        viewOffset: 0
    }
end sub
```

### Pattern 6: Season-boundary Auto-play

**Current behaviour:** `fetchNextEpisode()` looks for the next episode within the current season (`parentRatingKey`). If not found, it sets `m.noNextEpisode = true` — no cross-season advance.

**Required behaviour:** When last episode of a season is detected, fetch the next season from the show (`grandparentRatingKey`), get its first episode, and show "Starting Season X" notice in the countdown card.

**Logic to add in `onNextEpisodeLoaded()`:**

When `nextEp = invalid` (not found in current season), instead of `m.noNextEpisode = true`:
1. Fetch show children (`/library/metadata/{grandparentRatingKey}/children`) to get all seasons.
2. Find the season after current (`parentIndex + 1`).
3. If found, fetch that season's children.
4. Take first episode as `m.nextEpisodeInfo`, set `m.nextEpisodeIsNewSeason = true` and `m.nextSeasonNumber`.
5. In `showAutoPlayOverlay()`, check `m.nextEpisodeIsNewSeason` and set a "Starting Season X" notice label.

This requires two additional API calls (season list, then new season episodes). Both are small metadata-only requests.

### Pattern 7: Watch State Badge Rendering

**Existing badge infrastructure in PosterGridItem.xml:**
- `unwatchedBadge` (Poster, `badge-unwatched.png`) — translucent dot, visible when `watched = false`
- `unwatchedCount` (Label) — count overlay on the dot
- `progressTrack` / `progressFill` — partially watched bar

**Missing:**
- `badge-watched.png` — checkmark icon (needs to be created as a PNG image)
- Logic in PosterGridItem.brs to show checkmark when `viewCount > 0 and viewOffset = 0`

**Badge display rules (from CONTEXT.md):**
```
if viewCount > 0 and viewOffset = 0     → show checkmark badge
if viewOffset > PROGRESS_MIN_PERCENT    → show progress bar (already exists)
if viewCount = 0 and viewOffset = 0     → show unwatched dot (already exists for episodes)
for series/season posters               → show unwatchedCount number badge
```

**PosterGridItem.brs update needed:**

```brightscript
' In onItemContentChange (already exists, extend it):
sub updateWatchState(item as Object)
    c = m.global.constants

    viewCount = 0
    viewOffset = 0
    if item.viewCount <> invalid then viewCount = item.viewCount
    if item.viewOffset <> invalid then viewOffset = item.viewOffset

    duration = 0
    if item.duration <> invalid then duration = item.duration

    ' Progress bar (partially watched)
    progress = 0
    if duration > 0 then progress = viewOffset / duration
    showProgress = (progress >= c.PROGRESS_MIN_PERCENT and viewCount = 0)
    m.progressTrack.visible = showProgress
    m.progressFill.visible = showProgress
    if showProgress
        m.progressFill.width = Int(c.POSTER_WIDTH * progress)
    end if

    ' Watched checkmark
    m.watchedBadge.visible = (viewCount > 0)

    ' Unwatched dot (episode items where viewCount = 0)
    ' For series: show unwatched count
    showDot = (viewCount = 0 and viewOffset = 0)
    m.unwatchedBadge.visible = showDot
end sub
```

### Anti-Patterns to Avoid

- **Re-running Task nodes:** `task.control = "run"` a second time does nothing — always create a fresh Task node (pattern already established in scrobble/reportProgress).
- **Writing m.global from a Task node:** All m.global writes must happen on the render thread, not in Task nodes. scrobble() is a render-thread function, so writing m.global.watchStateUpdate there is safe.
- **Animation nodes on buttons during SIGSEGV concern:** Phase 11 confirmed BusySpinner (native SceneGraph) causes SIGSEGV. Float interpolator animations on Group opacity (as used by skip button / auto-play overlay) have been in use since before Phase 11 and are confirmed working. Do NOT replace them.
- **Blocking back navigation with playbackComplete:** VideoPlayer's current `back` key handler calls `stopPlayback()` then sets `playbackComplete = true`. After this phase, `back` during non-countdown playback should set `playbackResult` with `reason: "stopped"`, which navigates to PostPlayScreen. Do NOT emit both `playbackResult` and the old `playbackComplete` — pick one consistently.
- **Cross-season fetch before grandparentRatingKey is confirmed set:** Always guard `fetchNextEpisode()` and season-boundary fetches on both `parentRatingKey` and `grandparentRatingKey` being non-empty strings.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Countdown timer | Custom position-tracking loop | Roku Timer node (duration=1, repeat=true) | Already implemented in VideoPlayer — just change the threshold |
| Screen transitions | Custom animation sequence | Existing MainScene pushScreen/popScreen | Already handles focus stack and visibility |
| Watch state persistence | Custom local cache | Plex server is the source of truth — just emit m.global.watchStateUpdate after API call | Server already updated; just broadcast to visible screens |
| Badge images | Programmatic circle/checkmark drawing | PNG assets in images/ | Roku Poster node loads PNGs efficiently; drawing shapes is expensive in BrightScript |

---

## Common Pitfalls

### Pitfall 1: DetailScreen itemData Type Assumptions
**What goes wrong:** If `m.itemData.type` is not `"episode"` (it could be `"movie"`) and the code unconditionally tries to read `parentRatingKey`, it reads `invalid` and either crashes or passes empty string to VideoPlayer.
**Why it happens:** DetailScreen shows both movies and episodes.
**How to avoid:** Guard `if m.itemData.type = "episode"` before setting grandparentRatingKey/parentRatingKey/episodeIndex.
**Warning signs:** Auto-play triggering for movies, or nil dereference crash.

### Pitfall 2: episodeIndex vs parentIndex Confusion
**What goes wrong:** `episodeIndex` on VideoPlayer.xml is the episode's number within a season (e.g., episode 3 of season 2 = index 3). `seasonIndex` is the array index into `m.seasons`. `parentIndex` from Plex API is the season number (e.g., season 2 = parentIndex 2). These are different things.
**Why it happens:** The Plex API uses "parentIndex" to mean season number; VideoPlayer internally uses "episodeIndex" to mean episode number within the season.
**How to avoid:** In DetailScreen, set `m.player.episodeIndex = m.itemData.index` (episode number). Don't confuse it with parentIndex. The existing EpisodeScreen code correctly uses `episode.episodeNumber` which maps to `episode.index` from API.
**Warning signs:** Auto-play skipping to episode 2 when episode 1 just played, or failing to find next episode.

### Pitfall 3: playbackResult Race During Cross-Season Fetch
**What goes wrong:** Video finishes while the cross-season fetch is in flight. `onVideoStateChange("finished")` fires, but `m.nextEpisodeInfo = invalid` and `m.fetchingNextEpisode = true`. The current code handles this via the `m.fetchingNextEpisode` guard — but PostPlayScreen now needs to launch even if fetching is still in progress.
**Why it happens:** Two async operations (video ending + API fetch) racing.
**How to avoid:** When video finishes and fetch is still in-flight, show PostPlayScreen immediately with `hasNextEpisode = false`. If the fetch returns and finds a next episode, the user can choose Play Next from the post-play screen. Don't block the post-play screen on the fetch completing.

### Pitfall 4: Back Key After Video Stops
**What goes wrong:** VideoPlayer's `back` key calls `stopPlayback()` which sets `m.video.control = "stop"`. If PostPlayScreen is then pushed, and the user presses back on PostPlayScreen, MainScene pops it and reveals the calling screen. But VideoPlayer is still in the scene tree (the calling screen hasn't removed it yet). Two screens overlap.
**Why it happens:** VideoPlayer is appended to the scene root, not pushed via MainScene's screen stack.
**How to avoid:** Calling screen removes VideoPlayer from scene BEFORE pushing PostPlayScreen. Order: (1) remove VideoPlayer, (2) push PostPlayScreen.

### Pitfall 5: EpisodeScreen onPlaybackComplete Still Shows TODO
**What goes wrong:** `EpisodeScreen.onPlaybackComplete()` has a `' TODO: Auto-play next episode with countdown` comment and currently just restores focus to episodeList. If PostPlayScreen is introduced, the calling screens need consistent handling.
**Why it happens:** The TODO was deferred to this phase.
**How to avoid:** Replace `onPlaybackComplete` with `onPlaybackResult` in both DetailScreen and EpisodeScreen in the same task — don't leave one screen partially updated.

### Pitfall 6: m.global.watchStateUpdate is an AssocArray (not alwaysNotify by design)
**What goes wrong:** If watchStateUpdate is set to the same value twice (same ratingKey, same viewCount), observers may not fire (BrightScript only notifies on change by default).
**Why it happens:** Standard field observer semantics.
**How to avoid:** The field is declared without `alwaysNotify` in MainScene.addFields — but since we always pass a fresh AA with potentially different values this is unlikely to be a problem. If it does become a problem, add a `timestamp` field to the AA to ensure it's always "changed".

---

## Code Examples

### Setting grandparentRatingKey from Plex metadata AA

```brightscript
' Source: Direct codebase inspection — DetailScreen.brs processMetadata()
' m.itemData is the AA from response.MediaContainer.Metadata[0]
' Fields available for type="episode": parentRatingKey, grandparentRatingKey, index
if m.itemData.type = "episode"
    if m.itemData.grandparentRatingKey <> invalid
        m.player.grandparentRatingKey = GetRatingKeyStr(m.itemData.grandparentRatingKey)
    end if
    if m.itemData.parentRatingKey <> invalid
        m.player.parentRatingKey = GetRatingKeyStr(m.itemData.parentRatingKey)
    end if
    if m.itemData.index <> invalid
        m.player.episodeIndex = m.itemData.index
    end if
end if
```

### Emitting watchStateUpdate after scrobble

```brightscript
' Source: Direct codebase inspection — VideoPlayer.brs scrobble() +
' MainScene.brs global field setup + HomeScreen.brs onWatchStateUpdate
sub scrobble()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": m.top.ratingKey
    }
    task.control = "run"
    ' Broadcast to all screen observers
    m.global.watchStateUpdate = {
        ratingKey: m.top.ratingKey
        viewCount: 1
        viewOffset: 0
    }
end sub
```

### 30-second threshold in checkMarkers()

```brightscript
' Source: Direct codebase inspection — VideoPlayer.brs checkMarkers() lines 966-971
' Replace existing 90% threshold:
if m.top.grandparentRatingKey <> "" and m.top.grandparentRatingKey <> invalid
    if m.duration > 0 and currentPos >= m.duration - 30000
        inCredits = true
    end if
end if
```

### Creating PostPlayScreen from DetailScreen/EpisodeScreen

```brightscript
' Source: Pattern consistent with existing MainScene.brs onItemSelected dispatch
' DetailScreen/EpisodeScreen onPlaybackResult handler:
sub onPlaybackResult(event as Object)
    result = event.getData()
    if result = invalid then return

    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if

    m.top.itemSelected = {
        action: "postPlay"
        ratingKey: result.ratingKey
        itemTitle: result.itemTitle
        hasNextEpisode: result.hasNextEpisode
        nextEpisodeInfo: result.nextEpisodeInfo
        grandparentRatingKey: result.grandparentRatingKey
    }
end sub
```

### PosterGridItem checkmark badge (addFields pattern)

```brightscript
' Source: Direct codebase inspection — PosterGridItem.xml existing badge nodes
' Add to PosterGridItem.xml:
' <Poster id="watchedBadge" translation="[200, 0]" width="40" height="40"
'         uri="pkg:/images/badge-watched.png" visible="false" />

' PosterGridItem.brs — in onItemContentChange:
viewCount = 0
if item.viewCount <> invalid then viewCount = item.viewCount
viewOffset = 0
if item.viewOffset <> invalid then viewOffset = item.viewOffset

m.watchedBadge.visible = (viewCount > 0 and viewOffset = 0)
m.unwatchedBadge.visible = (viewCount = 0 and viewOffset = 0)
```

---

## State of the Art

| Old Approach | Current Approach | Phase Impact |
|--------------|------------------|--------------|
| 90% duration threshold for credits | Last 30 seconds (fixed) | Change one line in checkMarkers() |
| playbackComplete (bare boolean) | playbackResult (structured AA) | New field on VideoPlayer.xml, all observers updated |
| No post-play screen | PostPlayScreen component | New screen pushed via MainScene |
| scrobble() silent-only | scrobble() + m.global.watchStateUpdate | One-line addition to existing scrobble() |
| No checkmark badge | badge-watched.png + PosterGridItem update | New image asset + PosterGridItem.brs |

---

## Open Questions

1. **Does DetailScreen already store viewOffset during playback (needed for "Play from Timestamp" on PostPlayScreen)?**
   - What we know: VideoPlayer tracks `m.currentPosition` internally. DetailScreen currently doesn't store the offset reached during playback.
   - What's unclear: PostPlayScreen needs to know the last position for "Play from Timestamp".
   - Recommendation: Include `viewOffset` in `playbackResult` struct — VideoPlayer can emit `m.currentPosition` as part of the result.

2. **badge-watched.png asset — create from scratch or reuse existing?**
   - What we know: `badge-unwatched.png` exists (gold dot). No checkmark asset exists.
   - What's unclear: Whether to use a Unicode checkmark character in a Label (simpler) vs a PNG image (consistent with existing badge pattern).
   - Recommendation: Use a Label with Unicode checkmark ("✓") styled with Plex gold color — avoids needing a new image asset and is consistent with the accent color scheme. Position it at the same corner as `unwatchedBadge`.

3. **Season boundary: how many API calls are acceptable during credits?**
   - What we know: Current code does 1 API call to fetch next episode from current season. Season boundary requires 2 more calls (show seasons list, then new season episodes).
   - What's unclear: Whether 2-3 API calls during the last 30 seconds of playback are fast enough to complete before the countdown hits zero.
   - Recommendation: Initiate the season-boundary fetch eagerly at the 30-second threshold (same as single-season fetch). Given typical LAN Plex latency (<100ms per call), 3 calls should resolve in under 500ms, well before the 10-second countdown expires.

4. **PostPlayScreen navigation: who manages focus return to EpisodeScreen vs DetailScreen?**
   - What we know: MainScene's screen stack will have: HomeScreen → DetailScreen/EpisodeScreen → PostPlayScreen. Back from PostPlayScreen pops to DetailScreen/EpisodeScreen.
   - What's unclear: If user picks "Back to Library" from PostPlayScreen, should it pop to DetailScreen/EpisodeScreen first, or go directly to HomeScreen?
   - Recommendation: "Back to Library" pops all the way to HomeScreen (clear stack above HomeScreen). Back button pops only to DetailScreen/EpisodeScreen.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — VideoPlayer.brs (all 1366 lines) — auto-play architecture, countdown, key handling
- Direct codebase inspection — DetailScreen.brs — startPlayback() missing fields confirmed at lines 280-305
- Direct codebase inspection — EpisodeScreen.brs — correct wiring at lines 381-405, TODO at line 422
- Direct codebase inspection — MainScene.brs — screen stack, watchStateUpdate field at line 18
- Direct codebase inspection — HomeScreen.brs — onWatchStateUpdate at lines 1475-1505
- Direct codebase inspection — PosterGridItem.xml — existing badge nodes confirmed
- Direct codebase inspection — constants.brs — PROGRESS_MIN_PERCENT, ACCENT, FOCUS_RING, BADGE_SIZE

### Secondary (MEDIUM confidence)
- Plex API field names (`parentRatingKey`, `grandparentRatingKey`, `index`) inferred from EpisodeScreen.brs usage patterns and consistent with Plex Media Server API documentation conventions

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- FIX-01 root cause: HIGH — confirmed by direct code inspection; the gap is a missing 3-line block
- FIX-02 architecture: HIGH — current code paths traced completely; PostPlayScreen design is straightforward BrightScript
- FIX-03 watch state: HIGH — global field exists, observers exist, scrobble() confirmed missing watchStateUpdate emission
- Season-boundary auto-play: MEDIUM — logic is clear but untested; multiple API call chain during playback has unknowns
- Badge rendering: HIGH — existing pattern in PosterGridItem.xml is the template; only checkmark badge is new

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable codebase, no external dependencies)
