# Phase 9: Collections and Playlists - Research

**Researched:** 2026-03-10
**Focus:** Plex API endpoints for collections/playlists, screen architecture patterns, playlist playback integration

## Plex API: Collections

### Listing Collections Within a Library
- **Endpoint:** `GET /library/sections/{sectionId}/collections`
- **Response:** `MediaContainer.Metadata[]` with `subtype: "collection"`, `ratingKey`, `title`, `thumb`, `childCount`
- **Params:** Standard pagination with `X-Plex-Container-Start` and `X-Plex-Container-Size`

### Collection Contents
- **Endpoint:** `GET /library/collections/{ratingKey}/children`
- **Response:** `MediaContainer.Metadata[]` — same item schema as library items (movies, shows)
- **Items have:** `ratingKey`, `title`, `thumb`, `viewOffset`, `viewCount`, `duration`, `type`, etc.

### Collection Metadata
- **Endpoint:** `GET /library/metadata/{collectionRatingKey}`
- **Has:** `title`, `thumb` (composite poster), `summary`, `childCount`

## Plex API: Playlists

### Listing All Playlists
- **Endpoint:** `GET /playlists`
- **Response:** `MediaContainer.Metadata[]` with `type: "playlist"`, `ratingKey`, `title`, `thumb`, `leafCount`, `duration`, `playlistType` (video, audio, photo)
- **Filter video playlists:** `playlistType = "video"`

### Playlist Contents
- **Endpoint:** `GET /playlists/{ratingKey}/items`
- **Response:** `MediaContainer.Metadata[]` — ordered list of items with `playlistItemID`, `ratingKey`, `title`, `thumb`, `type`, `duration`, `viewOffset`, `viewCount`
- **Items include:** `grandparentTitle` (show name for episodes), `parentTitle` (season), `index` (episode number)

### Key Difference from Library Items
- Playlist items have `playlistItemID` — unique to their position in the playlist
- Items can be mixed types (movies + episodes in same playlist)

## Codebase Architecture Patterns

### Screen Navigation (MainScene.brs)
- `pushScreen(screen)` / `popScreen()` manages screen stack with focus preservation
- Each screen has `itemSelected` (assocarray) and `navigateBack` (boolean) interface fields
- `onItemSelected()` routes actions: "play", "detail", "episodes", "search", "settings"
- New screens need corresponding `show{Screen}()` function and routing in `onItemSelected()`

### Sidebar (Sidebar.brs)
- Three LabelList sections: `libraryList` (dynamic), `hubList` (Home), `bottomList` (Search, Settings)
- `specialAction` interface field fires events like "viewHome", "search", "settings"
- Adding "Playlists" should go in the hub/middle section alongside "Home"
- Layout calculated dynamically in `layoutLists()` based on item counts

### HomeScreen Library Grid Pattern
- `loadLibrary()` builds API request with endpoint + params, creates PlexApiTask
- `processApiResponse()` creates ContentNode tree from MediaContainer.Metadata
- PosterGrid renders items via PosterGridItem component
- Infinite scroll via `loadMore` observer with offset tracking
- Filter state integrated via filterBar.activeFilters params

### PosterGrid (PosterGrid.xml)
- Wraps a MarkupGrid with `PosterGridItem` component
- 6 columns, 240x360 poster size
- Fires `itemSelected` and `loadMore` events
- Takes `content` (ContentNode tree) as input

### VideoPlayer Playlist Integration Points
- `m.top.ratingKey`, `m.top.mediaKey`, `m.top.startOffset` control what plays
- `playbackComplete` signals end of playback to calling screen
- `nextEpisodeStarted` signals auto-play transition (Phase 8)
- `startNextEpisode()` pattern: scrobble, stop, update fields, call `loadMedia()`
- This pattern is directly reusable for playlist sequential playback

### EpisodeScreen Pattern (for PlaylistScreen reference)
- Season list (LabelList) + Episode list (MarkupList with EpisodeItem)
- Split pane layout with left selection and right details
- `startPlayback()` creates VideoPlayer, appends to scene, observes `playbackComplete`
- Resume dialog for partially watched items
- This is the closest analog for playlist item list display

## Key Implementation Insights

### Collections Integration
- Collections fit naturally into the existing HomeScreen flow
- The HomeScreen already has `m.viewMode` toggling between "hubGrid" and "libraryOnly"
- Adding a "Collections" mode just needs another viewMode value and different API endpoint
- The Sidebar `onSpecialAction` can handle a "viewCollections" action
- OR: Add a toggle in the filterBar area when viewing a library (simpler)
- Collection items render in the same PosterGrid with same PosterGridItem component

### Playlist Screen Design
- Needs a new PlaylistListScreen (list of playlists) and PlaylistScreen (playlist contents)
- PlaylistListScreen: Simple grid of playlist posters — reuse PosterGrid
- PlaylistScreen: Ordered item list — similar to EpisodeScreen layout
- Each item shows: index, title, type indicator (movie/episode), duration, progress

### Playlist Sequential Playback
- VideoPlayer needs new interface fields: `playlistItems` (array), `playlistIndex` (integer)
- On `state = "finished"`: if playlistItems exists, load next item instead of signaling playbackComplete
- No countdown overlay — immediate transition per CONTEXT.md decision
- Scrobble each item before advancing (existing pattern)
- Back key should stop playlist playback and return to PlaylistScreen

### File Impact Analysis
- **New files (4):** PlaylistListScreen.xml/.brs, PlaylistScreen.xml/.brs
- **Modified files (6):** Sidebar.xml/.brs, HomeScreen.brs, MainScene.brs, VideoPlayer.xml/.brs
- Collections don't need new screen components — reuse existing PosterGrid in HomeScreen

### Dependency Analysis
- Plan 1 (Collections + Playlist browsing): Independent data layer, can start immediately
- Plan 2 (Playlist playback): Depends on PlaylistScreen from Plan 1 for testing

## Risks and Mitigations

1. **Mixed-type playlists:** Playlist items can be movies OR episodes — PlaylistScreen must handle both types in the same list. Mitigation: Use item.type to determine display format.
2. **Playlist item deletion:** If a playlist item is deleted from the library, the playlist API returns a gap. Mitigation: Filter invalid items (no ratingKey).
3. **Large playlists:** Playlists can have hundreds of items. Mitigation: Paginate the playlist items API call, same pattern as library browsing.

---
*Phase: 09-collections-and-playlists*
*Researched: 2026-03-10*
