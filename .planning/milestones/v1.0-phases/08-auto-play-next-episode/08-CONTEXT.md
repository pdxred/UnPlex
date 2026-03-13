# Phase 8: Auto-play Next Episode - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

At the end of a TV episode, a countdown overlay appears offering to play the next episode automatically. User can cancel the countdown to stay on the current episode. If the countdown completes, the next episode begins playing seamlessly. This phase covers the countdown UI, next episode fetching, and automatic episode transition. Skip button integration with credits marker is inherited from Phase 7.

</domain>

<decisions>
## Implementation Decisions

### Countdown trigger and timing
- Countdown triggers when playback enters the credits marker timespan (reuses Phase 7 marker detection)
- If no credits marker exists, countdown triggers at 90% of episode duration (fallback)
- 10-second countdown timer per success criteria
- Countdown only appears for TV episodes, not movies
- If next episode doesn't exist (last episode of series/season), no countdown appears

### Countdown UI presentation
- Overlay appears in the bottom-right area of the screen (similar position to skip button)
- Shows: "Next Episode" label, episode title/number, countdown timer (10, 9, 8...)
- Semi-transparent dark background matching the skip button aesthetic
- "Cancel" option clearly indicated (Back button or dedicated cancel label)
- Countdown replaces the "Skip Credits" button when it triggers (both use credits marker timespan)
- Fade-in animation consistent with skip button (0.3s)

### Next episode data
- Next episode fetched when credits marker is detected (or at 90% threshold)
- Use Plex API to determine next episode (via on-deck endpoint or sequential episode lookup)
- Cache next episode metadata (ratingKey, title, season/episode numbers) for overlay display
- If fetch fails, silently skip auto-play (no error shown, episode just ends normally)

### Transition behavior
- When countdown reaches 0: stop current episode, start next episode playback
- Next episode starts from beginning (offset 0) unless it has a resume position
- Playback transition should feel seamless — minimal gap between episodes
- Current episode is scrobbled (marked as watched) before transition
- Cancel (Back press during countdown) dismisses the overlay and resumes normal end-of-episode behavior

### Claude's Discretion
- Exact overlay dimensions and layout
- Whether to show episode thumbnail in the overlay
- Animation style for countdown number changes
- How to handle the gap between stopping current and starting next episode
- Timer implementation (SceneGraph Timer node vs position-based)

</decisions>

<specifics>
## Specific Ideas

- Match the Netflix/Plex auto-play pattern: small overlay in corner with countdown, not a full-screen modal
- Countdown should feel unobtrusive — user can keep watching credits if they want
- The transition from "Skip Credits" button to "Next Episode" countdown should be smooth, not jarring

</specifics>

<deferred>
## Deferred Ideas

- "Play from beginning" option for next episode (if it has a partial watch) -- add to backlog
- Binge-watching mode toggle in settings (enable/disable auto-play) -- add to backlog
- Post-play screen showing what was just watched -- add to backlog

</deferred>

---

*Phase: 08-auto-play-next-episode*
*Context gathered: 2026-03-10*
