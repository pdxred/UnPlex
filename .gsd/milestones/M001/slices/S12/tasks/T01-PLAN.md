# T01: 12-auto-play-and-watch-state 01

**Slice:** S12 — **Milestone:** M001

## Description

Wire auto-play next episode from both entry points (DetailScreen and EpisodeScreen) with a cancellable 30-second countdown, create PostPlayScreen for consistent post-playback navigation, and add season-boundary auto-play.

Purpose: FIX-01 (auto-play fires from both screens) and FIX-02 (countdown is cancellable with proper post-play UX)
Output: PostPlayScreen component, redesigned VideoPlayer finish/cancel flow, DetailScreen grandparentRatingKey wiring

## Must-Haves

- [ ] "Playing an episode from DetailScreen triggers auto-play countdown at last 30 seconds"
- [ ] "Playing an episode from EpisodeScreen triggers auto-play countdown at last 30 seconds"
- [ ] "Back button during countdown cancels and returns to calling screen"
- [ ] "OK button during countdown cancels and shows PostPlayScreen"
- [ ] "PostPlayScreen appears after every video ends with Play Next, Replay, Back to Library, Play from Timestamp"
- [ ] "Auto-play crosses season boundaries with Starting Season X notice"
- [ ] "When no next episode exists, PostPlayScreen omits Play Next button"

## Files

- `SimPlex/components/screens/PostPlayScreen.xml`
- `SimPlex/components/screens/PostPlayScreen.brs`
- `SimPlex/components/widgets/VideoPlayer.xml`
- `SimPlex/components/widgets/VideoPlayer.brs`
- `SimPlex/components/screens/DetailScreen.brs`
- `SimPlex/components/screens/EpisodeScreen.brs`
- `SimPlex/components/MainScene.xml`
- `SimPlex/components/MainScene.brs`
