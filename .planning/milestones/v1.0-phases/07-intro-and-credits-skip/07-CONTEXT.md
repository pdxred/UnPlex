# Phase 7: Intro and Credits Skip - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can skip intros and credits during TV episode playback with a single button press, matching the official Plex app experience. Skip buttons appear as timed overlays during marker timespans. This phase covers the skip UI and seek behavior only -- auto-play next episode is Phase 8.

</domain>

<decisions>
## Implementation Decisions

### Skip button appearance and timing
- "Skip Intro" button appears when playback position enters the intro marker timespan (from Plex chapter markers API)
- "Skip Credits" button appears when playback position enters the credits marker timespan
- Buttons auto-dismiss when the marker timespan ends (user didn't press skip)
- Buttons appear in the bottom-right corner of the screen, consistent with official Plex and streaming services
- Button shows for the full duration of the marker window -- no auto-hide timer independent of the marker

### Button interaction
- OK/Select press on the skip button seeks to the marker end position
- Button captures focus when it appears -- user can press OK immediately without navigating to it
- If user is interacting with another overlay (e.g., TrackSelectionPanel), skip button still appears but does not steal focus
- Back button dismisses the skip button without seeking (user wants to watch the intro/credits)

### Marker data fetching
- Markers pre-fetched before or at playback start (not lazily after playback begins) per success criteria
- Use Plex API endpoint for intro/credits markers (e.g., /library/metadata/{ratingKey}/markers or chapter data)
- Markers cached for the duration of the playback session
- If no markers exist for an item, no skip buttons appear (graceful absence, not an error)

### Visual design
- Semi-transparent button with white text, matching the Plex gold accent on focus
- Subtle fade-in/fade-out animation (0.3s) when appearing and dismissing
- Button text: "Skip Intro" and "Skip Credits" (standard labels)
- Button positioned to not obscure progress bar or other playback controls

### Claude's Discretion
- Exact button dimensions and padding
- Animation easing function
- How to handle edge case where intro and credits markers overlap (unlikely but possible)
- Whether to use a Group+Rectangle+Label or a custom component for the button
- Polling interval for position checking against marker timespans (timer-based vs state-change-based)

</decisions>

<specifics>
## Specific Ideas

- Match the official Plex app skip behavior: button appears, one press skips, position jumps to end of marker
- Skip buttons should feel responsive -- no noticeable delay between pressing OK and the seek completing
- Credits skip is separate from auto-play next (Phase 8) -- for now, skipping credits just seeks past them to the end of the episode

</specifics>

<deferred>
## Deferred Ideas

- Auto-play next episode countdown at credits -- Phase 8
- "Skip Recap" for recap markers if Plex supports them -- add to backlog
- User preference to auto-skip all intros without button press -- add to backlog

</deferred>

---

*Phase: 07-intro-and-credits-skip*
*Context gathered: 2026-03-10*
