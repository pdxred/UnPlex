---
id: S13
milestone: M001
status: ready
---

# S13: Search, Collections, and Thumbnails — Context

## Goal

Overhaul SearchScreen to use grouped RowList results with hub-type headers, keyboard collapse/restore, smart type-based routing, and parentThumb for episode results; fix the collections dead-end with user feedback; make PosterGrid respect its gridWidth field for dynamic column calculation.

## Why this Slice

Search is the primary discovery mechanism and currently has multiple UX gaps: stretched episode thumbnails, no type context in results, a narrow 4-column grid stuck beside the keyboard, and all results routing to DetailScreen regardless of type. Collections has a silent dead-end when no library is selected. These are visible user-facing rough edges that need polish before the app is GitHub-publishable. Fixing these now (after S12's auto-play/watch state work) means the core playback and navigation loops are solid, and this slice polishes the discovery and browsing layer that feeds into them.

## Scope

### In Scope

- **Search grouped results:** Replace the flat PosterGrid in SearchScreen with a RowList that groups results by hub type (Movies, TV Shows, Episodes). Each hub type gets its own horizontal scrolling row with a label header, matching the HomeScreen hub row pattern.
- **Episode parentThumb:** Episode search results use `item.parentThumb` (the parent show's portrait poster) instead of `item.thumb` (landscape episode still) to avoid aspect ratio distortion in the portrait poster grid. Fall back to `item.thumb` at portrait dimensions if `parentThumb` is absent.
- **Hub type filtering:** Only show Movies, TV Shows, and Episodes hub types in search results. Exclude artists, albums, tracks, and other content types.
- **Default API result count:** Use the Plex search API's default item count per hub (typically 5–10). No extra API calls to request more.
- **Keyboard collapse on right-press:** When the user presses right from the keyboard into the results, hide the keyboard and expand the results area to full screen width. The RowList rows gain the full width.
- **Keyboard restore on left-press:** From the first column/edge of the results RowList, pressing left brings the keyboard back and shrinks the results area. Natural spatial navigation.
- **Block collapse when empty:** Right arrow from the keyboard does nothing when there are no search results. Prevents a blank full-screen state.
- **Smart routing by type:** Search result selection routes by `itemType`: TV shows → EpisodeScreen directly (matching S14's planned direct navigation), episodes → DetailScreen, movies → DetailScreen. Collections from search → browse collection contents (not "Play").
- **Collections search routing:** When a collection appears in search results, route to collection contents (via HomeScreen's existing `loadCollectionContents`) instead of showing a "Play" button on DetailScreen.
- **Collections sidebar feedback:** When the user taps "Collections" in the sidebar without a library selected, show a dialog/toast message ("Select a library first to view its collections") and return focus to the sidebar. Remove the silent dead-end.
- **PosterGrid gridWidth dynamic columns:** Make `PosterGrid.brs` compute `numColumns` from the `gridWidth` field (`Int(gridWidth / (POSTER_WIDTH + GRID_H_SPACING))`). This fixes the existing bug where `gridWidth` is declared in the interface but ignored. All screens using PosterGrid benefit, but SearchScreen (if it still uses PosterGrid for any sub-view) and HomeScreen are the primary consumers.

### Out of Scope

- **Music/photo search results:** Artists, albums, tracks, photos are excluded from search results display.
- **Search result pagination / "show more":** No "load more" or infinite scroll within search hub rows. Default API count is sufficient.
- **Full-text search within collections:** Collections are browsed by navigating into them, not searched.
- **Global collections (cross-library):** Collections remain scoped to the currently selected library. No cross-library collection aggregation.
- **Season poster grid:** Upgrading the season LabelList in EpisodeScreen to a poster grid is S14 scope.
- **Search history / recent searches:** No persistence of search queries.
- **RowList item component changes:** The RowList rows use PosterGridItem (same as hub rows on HomeScreen). No new item component for search.
- **Animated keyboard collapse/expand:** Use instant show/hide and translation changes. No Animation nodes (per BusySpinner SIGSEGV decision).

## Constraints

- **No Animation nodes** for keyboard collapse/restore. Use instant visibility toggle and translation changes only. Animation nodes are safe per D-record, but the keyboard transition is simple enough that instant show/hide is fine and avoids unnecessary complexity.
- **No BusySpinner** — use existing LoadingSpinner widget (Label+Rectangle overlay with 300ms delay).
- **Plex search API returns `Hub[]`** — each hub has a `type` field and `Metadata[]` array. The hub structure naturally maps to RowList rows. Hub types include `movie`, `show`, `episode`, `artist`, `album`, `track`, etc.
- **PosterGrid `gridWidth` field** already exists in the interface (default 1620). Making it functional must not break existing screens that rely on the current 6-column default.
- **RowList pattern** is already established in HomeScreen for hub rows — reuse the same item sizing, spacing, and PosterGridItem component.
- **Collections require `m.currentSectionId`** — the Plex API endpoint is `/library/sections/{id}/collections`. There is no cross-library collections endpoint.

## Integration Points

### Consumes

- `PlexSearchTask` — existing task that calls `/hubs/search?query=`. Returns `MediaContainer.Hub[]` with typed hub groups.
- `PosterGridItem` — existing item component used in RowList rows for search results (same as HomeScreen hubs).
- `HomeScreen.loadCollectionContents()` — existing function to browse collection contents. Search collection routing needs to trigger this flow.
- `MainScene.showEpisodeScreen()` — existing function for direct TV show navigation from search.
- `MainScene.showDetailScreen()` — existing function for movie/episode detail from search.
- `LoadingSpinner` — existing safe loading indicator widget.
- `Sidebar.specialAction = "viewCollections"` — existing event that triggers collections view in HomeScreen.
- `GetRatingKeyStr()` from `utils.brs` — ratingKey coercion helper.
- `BuildPosterUrl()` from `utils.brs` — poster URL builder with server URI and auth token.

### Produces

- **SearchScreen with RowList** — grouped search results with hub-type headers, keyboard collapse/restore, smart routing.
- **PosterGrid with dynamic columns** — `gridWidth` field now controls `numColumns` calculation. All consumers benefit from accurate column counts.
- **Collections sidebar feedback** — dialog shown when no library is selected, preventing the silent dead-end.
- **Search → collection routing** — collections found via search navigate to collection contents instead of showing "Play" on DetailScreen.

## Open Questions

- **RowList row height for search results** — HomeScreen hub rows use `itemSize = [1540, 510]` and `rowItemSize = [[240, 390]]`. The search RowList should match, but the available height depends on whether the search query label and title are above the RowList. Will be determined during layout implementation — follow HomeScreen's established pattern.
- **Collection items in search results** — Plex search API may or may not return collections as a hub type. If it does, they need to be handled with the browse-collection routing. If not, collection routing from search is moot and only the sidebar feedback fix applies. Verify against live API response during implementation.
- **Focus behavior after keyboard collapse** — When the keyboard collapses and the RowList expands, focus should land on the first item of the first result row. If the RowList has focus management quirks (e.g., focus jumps to a non-visible row), this may need explicit `jumpToRowItem` calls. Test on device.
