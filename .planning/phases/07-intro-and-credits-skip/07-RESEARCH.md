# Phase 7: Intro and Credits Skip - Research

**Researched:** 2026-03-10
**Status:** Complete

## Phase Requirements

- **PLAY-10:** User sees "Skip Intro" button during intro marker timespan
- **PLAY-11:** User sees "Skip Credits" / "Next Episode" button at credits marker

## User Constraints (from CONTEXT.md)

- Skip buttons appear in bottom-right corner
- OK/Select seeks to marker end position
- Button captures focus when it appears (unless another overlay is active)
- Back button dismisses without seeking
- Markers pre-fetched before/at playback start
- Fade-in/fade-out animation (0.3s)
- "Skip Intro" and "Skip Credits" labels

## Plex Markers API

### Endpoint: /library/metadata/{ratingKey}/markers

Returns chapter markers including intro and credits timespans.

**Request:**
```
GET /library/metadata/{ratingKey}/markers
Accept: application/json
X-Plex-Token: {token}
```

**Response structure (from Plex API analysis):**
```json
{
  "MediaContainer": {
    "Marker": [
      {
        "id": 12345,
        "type": "intro",
        "startTimeOffset": 30000,
        "endTimeOffset": 90000,
        "final": true
      },
      {
        "id": 12346,
        "type": "credits",
        "startTimeOffset": 2520000,
        "endTimeOffset": 2580000,
        "final": true
      }
    ]
  }
}
```

**Key fields:**
- `type`: "intro" or "credits"
- `startTimeOffset`: Start of marker in milliseconds
- `endTimeOffset`: End of marker in milliseconds
- `final`: Whether marker has been finalized by Plex analysis

**Alternative endpoint:** Some Plex server versions expose markers inline in the metadata response at `/library/metadata/{ratingKey}` within the `Marker` array at the item level. The dedicated `/markers` endpoint is more reliable.

**Fallback:** If no markers exist, the Marker array is empty or absent. Graceful absence — no error.

### Marker Availability

- Intro markers require Plex Pass and server-side analysis
- Not all content has markers (analysis must complete first)
- Movies typically don't have intro markers (TV episodes only)
- Credits markers are newer and less universally available
- The `final` field indicates analysis is complete

## Roku SceneGraph Implementation Patterns

### Position-Based Trigger

The VideoPlayer already has `onPositionChange` which fires with current position. This can be extended to check markers.

**Current pattern (from VideoPlayer.brs):**
```brightscript
sub onPositionChange(event as Object)
    position = event.getData()
    m.currentPosition = position * 1000  ' Convert to ms
end sub
```

**Extension approach:** Add marker checking to `onPositionChange`:
```brightscript
sub onPositionChange(event as Object)
    position = event.getData()
    m.currentPosition = position * 1000
    checkMarkers()
end sub
```

**Performance consideration:** `onPositionChange` fires frequently (every ~250ms during playback). Marker checking should be lightweight — simple range comparison, not complex logic.

### Overlay Button Component

**Approach: Group with Rectangle + Label**

SceneGraph doesn't have a native "Button" for overlay use. Standard pattern is Group containing:
- Rectangle background (semi-transparent with rounded corners via `cornerRadius` if Roku OS 12+)
- Label for text
- Focus handling via onKeyEvent

**Position:** Bottom-right, above the trickplay bar area. Suggested translation: `[1520, 940]` for a ~300px wide button at bottom-right with padding.

### Animation

SceneGraph Animation node with OpacityFieldInterpolator for fade-in/fade-out:

```xml
<Animation id="fadeIn" duration="0.3" easeFunction="inOutQuad">
    <FloatFieldInterpolator key="[0.0, 1.0]" keyValue="[0.0, 1.0]" fieldToInterp="skipButton.opacity" />
</Animation>
```

### Focus Management

When skip button appears:
- If no other overlay is active (TrackSelectionPanel not visible), button takes focus
- If TrackSelectionPanel is visible, button is visible but unfocused
- When button is focused, OK press triggers seek
- Back key while button focused hides button and returns focus to video

### Timer-Based Approach vs Position-Based

**Position-based (recommended):** Check in `onPositionChange`. Pros: Natural, already fires frequently. Cons: Slightly noisy.

**Timer-based alternative:** Separate Timer node checking position every second. Pros: Controlled frequency. Cons: Extra timer, position might be stale.

**Recommendation:** Position-based with a simple "was showing / is now in range" check to avoid re-triggering.

## Codebase Integration Points

### VideoPlayer.xml additions needed:
- SkipButton Group with Rectangle, Label, and fade animations
- Interface fields for markers data

### VideoPlayer.brs additions needed:
- `fetchMarkers()` — API call to get markers at playback start
- `onMarkersLoaded()` — Parse and store intro/credits markers
- `checkMarkers()` — Called from `onPositionChange`, show/hide button
- `onSkipButtonPress()` — Seek to marker end position
- `showSkipButton(type)` / `hideSkipButton()` — Fade animation control

### processMediaInfo() extension:
- After loading media metadata, fire off markers fetch in parallel
- Store `m.introMarker` and `m.creditsMarker` (start/end times)

### onKeyEvent() extension:
- When skip button visible and focused: OK → seek, Back → dismiss

### Existing patterns to reuse:
- `PlexApiTask` for markers API call
- `onPositionChange` for position tracking
- `m.video.seek` for seeking
- Animation pattern from TrackSelectionPanel (FloatFieldInterpolator)
- `m.transcodingOverlay` pattern for temporary overlay display

## Edge Cases

1. **User seeks past intro during button display** → Button should auto-hide (position leaves range)
2. **User seeks backward into intro** → Button should re-appear
3. **Very short markers** (< 3 seconds) → Still show button, user may not have time to react
4. **Markers fetch fails** → Silently ignore, no skip buttons (graceful degradation)
5. **Both intro and credits active simultaneously** → Unlikely but handle by prioritizing credits (closer to end)
6. **PGS transcode pivot in progress** → Don't show skip button during overlay
7. **Credits skip vs Phase 8 auto-play** → Phase 7 just seeks past credits; Phase 8 adds countdown

## Plan Structure Recommendation

**Single plan (07-01):** The feature is self-contained within VideoPlayer with no new component files needed (just a Group added to VideoPlayer.xml). Two tasks:

1. **Task 1:** Fetch markers at playback start, store intro/credits data
2. **Task 2:** Skip button overlay UI, position-based trigger, seek behavior, fade animation

Alternatively, this could be one task since the marker fetch and button display are tightly coupled.

---

*Phase: 07-intro-and-credits-skip*
*Researched: 2026-03-10*
