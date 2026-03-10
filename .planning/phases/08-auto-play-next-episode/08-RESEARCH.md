# Phase 8: Auto-play Next Episode - Research

**Researched:** 2026-03-10
**Status:** Complete

## Phase Requirements

- **PLAY-12:** Auto-play next episode with 10-second countdown at end of episode
- **PLAY-13:** User can cancel auto-play countdown

## User Constraints (from CONTEXT.md)

- Countdown triggers at credits marker or 90% duration fallback
- 10-second countdown timer
- Bottom-right overlay showing next episode info
- Cancel via Back button
- Only for TV episodes, not movies
- Scrobble current episode before transition
- Countdown replaces Skip Credits button

## Plex API for Next Episode

### Option 1: /library/metadata/{ratingKey} with includeRelated

The metadata response for a TV episode includes `grandparentRatingKey` (show) and parent info. Can use this to fetch adjacent episodes.

### Option 2: Episode Children Endpoint

```
GET /library/metadata/{showRatingKey}/allLeaves
```

Returns all episodes for a show. Can find current episode and determine next by index/seasonEpisode ordering.

### Option 3: On-Deck Endpoint (Recommended)

After the current episode completes (or during credits), Plex's on-deck logic already knows what comes next:

```
GET /library/metadata/{ratingKey}
```

The metadata response for a TV episode includes a `grandparentRatingKey` field. Using:

```
GET /library/metadata/{grandparentRatingKey}/children
```

Gets seasons. Then for the current season:

```
GET /library/metadata/{seasonRatingKey}/children
```

Gets episodes. Navigate to next episode by index.

### Simplest Approach: Sequential Episode Lookup

For the current episode, the Plex API metadata includes:
- `index` (episode number within season)
- `parentIndex` (season number)
- `parentRatingKey` (season ratingKey)
- `grandparentRatingKey` (show ratingKey)

**Algorithm:**
1. At credits/90%, fetch `/library/metadata/{parentRatingKey}/children` (episodes in current season)
2. Find episode with `index = currentIndex + 1`
3. If not found (last episode of season), fetch `/library/metadata/{grandparentRatingKey}/children` (seasons)
4. Find season with `index = currentSeasonIndex + 1`
5. If found, fetch that season's children and get first episode
6. If not found (last season), no next episode — don't show countdown

## Roku SceneGraph Implementation

### Timer Node for Countdown

SceneGraph Timer node for 1-second ticks:
```brightscript
m.countdownTimer = CreateObject("roSGNode", "Timer")
m.countdownTimer.duration = 1
m.countdownTimer.repeat = true
m.countdownTimer.observeField("fire", "onCountdownTick")
```

### Countdown Overlay

Group containing:
- Semi-transparent background Rectangle
- "Up Next" or "Next Episode" label
- Episode title (e.g., "S2 E5 - Episode Title")
- Countdown number (large, updating each second)
- "Cancel" hint text

### Integration with Phase 7 Skip Button

When credits marker is reached:
1. Phase 7 shows "Skip Credits" button
2. Phase 8 should replace this with the countdown overlay
3. The countdown overlay serves dual purpose: it IS the credits-phase action

**Approach:** When credits marker triggers and next episode exists, show countdown overlay instead of skip button. The "Skip Credits" behavior is subsumed by "play next episode."

### VideoPlayer Interface Extension

Need to signal MainScene to start the next episode. Options:
- New interface field `nextEpisode` (assocarray with ratingKey, mediaKey, title)
- When countdown completes, set this field
- MainScene observes it and initiates new playback

### Detecting TV vs Movie

The VideoPlayer currently receives `ratingKey` and `mediaKey`. Need additional context about whether the current item is a TV episode. Options:
- Add `itemType` field to VideoPlayer interface ("movie" or "episode")
- Check for `grandparentRatingKey` in metadata response (episodes have it, movies don't)
- Pass from calling screen (DetailScreen/EpisodeScreen knows the content type)

**Recommendation:** Add `parentRatingKey` and `grandparentRatingKey` fields to VideoPlayer interface. These are set by the calling screen. If `grandparentRatingKey` is non-empty, it's a TV episode and auto-play logic applies.

## Edge Cases

1. **Last episode of season** → Try next season's first episode
2. **Last episode of series** → No countdown, episode ends normally
3. **Next episode fetch fails** → Silently skip countdown
4. **User pauses during countdown** → Pause countdown timer, resume when unpaused
5. **User opens TrackSelectionPanel during countdown** → Countdown continues but button unfocused
6. **Credits marker very short** → Countdown starts immediately, may not complete before episode ends
7. **Episode ends before countdown finishes** → Auto-play immediately (don't wait for timer)
8. **User presses Skip Credits while countdown is showing** → Equivalent to immediate auto-play (skip to next)

## Plan Structure

**Single plan (08-01):** Two tasks:
1. **Task 1:** Next episode fetch logic + VideoPlayer interface extensions + countdown overlay UI
2. **Task 2:** Countdown timer, credits integration, auto-play transition, cancel behavior

Or single task since the fetch and UI are tightly coupled.

---

*Phase: 08-auto-play-next-episode*
*Researched: 2026-03-10*
