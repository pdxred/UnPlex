# Phase 9: Collections and Playlists - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can browse Plex collections within libraries and browse playlists, with sequential playback from playlists advancing to the next item automatically. This phase adds collection and playlist browsing screens and playlist-aware playback. It does not add playlist creation, editing, or smart playlist management.

</domain>

<decisions>
## Implementation Decisions

### Collection browsing entry point
- Collections accessible from within a library via the existing filter/sort bar -- add a "Collections" view toggle alongside the grid view
- Selecting "Collections" replaces the poster grid with collection posters fetched from `/library/sections/{id}/collections`
- Selecting a collection opens the existing grid view filtered to that collection's contents via `/library/collections/{ratingKey}/children`
- Collection poster uses the collection's composite art from Plex (thumb field)

### Playlist presentation
- Playlists get a dedicated sidebar item (like Home, Settings) since playlists span multiple libraries
- Playlist list screen shows all playlists from `/playlists` endpoint in a vertical list with poster art, title, item count, and duration
- Selecting a playlist opens a detail-style screen showing playlist items in a scrollable list (similar to EpisodeScreen layout for ordered items)
- Playlist items show index number, title, duration, and progress bar if partially watched

### Sequential playlist playback
- Reuse the auto-play next episode pattern from Phase 8 but without the countdown -- playlist items advance immediately after completion (no 10-second countdown)
- VideoPlayer receives a `playlistItems` array and `playlistIndex` integer via interface fields
- On playback complete, if playlist context exists, automatically load the next item and start playback
- Back key during playlist playback returns to the playlist screen (not to a countdown)
- Playlist playback scrobbles each item individually (existing scrobble pattern)

### Claude's Discretion
- Exact layout dimensions for playlist item rows
- Collection grid column count (likely same as library grid: 6 columns)
- Empty state messaging for libraries with no collections or empty playlists
- Whether to show a "Now Playing" indicator on the current playlist item

</decisions>

<specifics>
## Specific Ideas

- Collections should feel like browsing a sub-library -- same poster grid, same interactions, just scoped to the collection contents
- Playlist playback should feel seamless -- no countdown, no overlay, just the next item starts playing
- The sidebar playlist entry should use the Plex playlist icon or a simple label, consistent with existing sidebar items

</specifics>

<deferred>
## Deferred Ideas

- Playlist creation and editing from within the app -- future phase
- Smart playlists / auto-generated playlists -- future phase
- Shuffle playback mode -- future enhancement
- Queue management (add to Up Next) -- future phase

</deferred>

---

*Phase: 09-collections-and-playlists*
*Context gathered: 2026-03-10*
