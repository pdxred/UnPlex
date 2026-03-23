# S12: Auto Play And Watch State

**Goal:** Wire auto-play next episode from both entry points (DetailScreen and EpisodeScreen) with a cancellable 30-second countdown, create PostPlayScreen for consistent post-playback navigation, and add season-boundary auto-play.
**Demo:** Wire auto-play next episode from both entry points (DetailScreen and EpisodeScreen) with a cancellable 30-second countdown, create PostPlayScreen for consistent post-playback navigation, and add season-boundary auto-play.

## Must-Haves


## Tasks

- [x] **T01: 12-auto-play-and-watch-state 01** `est:55min`
  - Wire auto-play next episode from both entry points (DetailScreen and EpisodeScreen) with a cancellable 30-second countdown, create PostPlayScreen for consistent post-playback navigation, and add season-boundary auto-play.

Purpose: FIX-01 (auto-play fires from both screens) and FIX-02 (countdown is cancellable with proper post-play UX)
Output: PostPlayScreen component, redesigned VideoPlayer finish/cancel flow, DetailScreen grandparentRatingKey wiring
- [x] **T02: 12-auto-play-and-watch-state 02** `est:8min`
  - Emit watch state updates from VideoPlayer after scrobble and add a watched checkmark badge to PosterGridItem, ensuring watch state changes propagate to all visible parent screens.

Purpose: FIX-03 (watch state changes propagate to poster grids and hub rows)
Output: VideoPlayer emits watchStateUpdate, PosterGridItem renders checkmark for fully watched items

## Files Likely Touched

- `SimPlex/components/screens/PostPlayScreen.xml`
- `SimPlex/components/screens/PostPlayScreen.brs`
- `SimPlex/components/widgets/VideoPlayer.xml`
- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/components/screens/DetailScreen.brs`
- `SimPlex/components/screens/EpisodeScreen.brs`
- `SimPlex/components/MainScene.xml`
- `SimPlex/components/MainScene.brs`
- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/components/widgets/PosterGridItem.xml`
- `SimPlex/components/widgets/PosterGridItem.brs`
