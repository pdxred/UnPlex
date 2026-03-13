# Phase 12: Auto-play and Watch State - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire auto-play next episode from both entry points (DetailScreen and EpisodeScreen) with a cancellable countdown, and propagate watch state changes back to all visible parent screens (poster grids, hub rows, detail/episode screens). Auto-play also applies to playlist items.

</domain>

<decisions>
## Implementation Decisions

### Countdown overlay
- Small card in bottom-right corner of the screen while video continues playing behind it
- Card shows: next episode thumbnail, title (e.g., S2E5 "Title"), and countdown number
- 10-second countdown timer
- Thin progress bar underneath the countdown that shrinks as the timer counts down
- For playlists, show position info (e.g., "Next: Item 4 of 12")
- When crossing season boundaries, show notice (e.g., "Starting Season 2")

### Post-play behavior
- Countdown triggers at the last 30 seconds of playback (fixed threshold, no credits detection)
- Video continues playing behind the countdown overlay — no pause or dim
- Auto-play works for TV episodes AND playlist items
- Auto-play crosses season boundaries seamlessly with a "Starting Season X" notice in the countdown card
- When no next item exists (last episode/movie), show "series complete" or "playlist complete" message then transition to post-play screen

### Cancel interaction
- Back button cancels countdown AND returns to previous screen (DetailScreen or EpisodeScreen)
- OK button cancels countdown AND stays on a post-play info screen
- Post-play info screen shows four actions: Play Next Episode, Replay Episode, Back to Library, Play from Timestamp
- Post-play screen appears after EVERY video ends (not just when auto-play was cancelled) — consistent experience
- When no next episode exists, post-play screen omits "Play Next Episode" button

### Watch state badges
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

</decisions>

<specifics>
## Specific Ideas

- Countdown card style: small, unobtrusive corner overlay — not a full-screen takeover
- Netflix-like binge experience with seamless season transitions
- Post-play screen is a universal endpoint for all video playback, providing consistent navigation options
- Progress bar on posters should match the existing PosterGridItem progress bar pattern

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-auto-play-and-watch-state*
*Context gathered: 2026-03-13*
