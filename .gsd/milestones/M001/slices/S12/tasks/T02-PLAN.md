# T02: 12-auto-play-and-watch-state 02

**Slice:** S12 — **Milestone:** M001

## Description

Emit watch state updates from VideoPlayer after scrobble and add a watched checkmark badge to PosterGridItem, ensuring watch state changes propagate to all visible parent screens.

Purpose: FIX-03 (watch state changes propagate to poster grids and hub rows)
Output: VideoPlayer emits watchStateUpdate, PosterGridItem renders checkmark for fully watched items

## Must-Haves

- [ ] "After an episode finishes, the poster in the library grid updates its watched badge"
- [ ] "After an episode finishes, the Continue Watching hub row updates or removes the item"
- [ ] "Fully watched items show a checkmark badge on their poster"
- [ ] "Unwatched items show the gold dot badge (existing behavior preserved)"
- [ ] "Partially watched items show the progress bar (existing behavior preserved)"

## Files

- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/components/widgets/PosterGridItem.xml`
- `SimPlex/components/widgets/PosterGridItem.brs`
