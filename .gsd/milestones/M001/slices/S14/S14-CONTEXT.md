---
id: S14
milestone: M001
status: ready
---

# S14: TV Show Navigation Overhaul — Context

## Goal

Route TV show taps directly to EpisodeScreen (skipping DetailScreen), add "Show Info" to the episode options menu, fix watch state propagation to hub rows, display season progress counts, and polish the EpisodeScreen layout — reducing the show navigation stack from 3 levels to 2.

## Why this Slice

TV shows currently require an unnecessary DetailScreen intermediate hop (HomeScreen → DetailScreen → EpisodeScreen). This is the single biggest navigation friction in the app — users expect grid tap → season/episode screen → play, matching every major TV media client. S12 completed auto-play and watch state emission from VideoPlayer, and S13 establishes the search routing pattern. S14 wires the remaining HomeScreen and hub row routing so the entire show navigation path is cohesive. S15 (Server Switching Removal) depends on S14 being stable so the test surface is smaller.

## Scope

### In Scope

- **HomeScreen grid routing:** TV shows (`itemType = "show"`) emit `{action:"episodes", ratingKey, title}` instead of `{action:"detail"}`. Movies, episodes, and other types continue to route to DetailScreen as before. MainScene already has the `action:"episodes"` → `showEpisodeScreen()` branch — no MainScene routing change needed.
- **Hub row routing:** Non-Continue Watching hub rows (Recently Added, On Deck, etc.) also route shows directly to EpisodeScreen. Continue Watching items remain as-is (episodes launch playback directly).
- **Search result routing:** TV shows selected from search results route to EpisodeScreen. S13 plans this as "smart routing by type" — S14 ensures the HomeScreen routing logic is consistent so both paths work. If S13 has already landed this, S14 verifies it; if not, S14 implements it for search as well.
- **Resume dialog adaptation:** When a partially-watched show is tapped, the resume dialog's "Go to Details" button changes to "Browse Episodes" and routes to EpisodeScreen instead of DetailScreen. Resume/Start from Beginning still launch playback directly for the show-level item.
- **Options key "Show Info":** Add "Show Info" to the existing episode options menu (the `*` key dialog on EpisodeScreen). Pressing it emits `{action:"detail", ratingKey: m.top.ratingKey, itemType:"show"}` to push DetailScreen for the show's metadata. This sits alongside the existing "Mark as Watched/Unwatched" option.
- **Season progress labels:** Season labels in the LabelList show watched progress in the format "Season 1 (6/10)" using `leafCount` and `viewedLeafCount` from the `/library/metadata/{id}/children` API response. These fields are already returned by Plex — they just need to be parsed in `processSeasons()`.
- **Hub row watch state propagation:** Extend `HomeScreen.onWatchStateUpdate` to walk the hub RowList ContentNode tree (rows as children, items as grandchildren) in addition to the poster grid tree. After playback or watched toggle, Continue Watching and On Deck hub rows update immediately — no waiting for the hub refresh timer.
- **EpisodeScreen layout polish:** Improve spacing and metadata display on EpisodeScreen:
  - Better season list sizing and spacing (currently `itemSize="[200, 50]"` — may need adjustment for progress text)
  - Show summary and/or year below the show title label
  - Ensure episode watched badges (unwatched dot, progress bar, watched checkmark) render correctly on EpisodeItem — verify the badge states match PosterGridItem's three-state logic
- **EpisodeScreen episode watched badges:** Verify `EpisodeItem.brs` correctly renders the three badge states (unwatched dot, progress bar, watched checkmark) consistent with PosterGridItem. If missing, add the watched checkmark state.

### Out of Scope

- **Season poster artwork row:** Replacing the LabelList with a horizontal poster row showing season thumbnail art. Keep the text-based LabelList for now.
- **EpisodeScreen structural changes:** No splitting into separate Season and Episode screens. Keep the two-panel layout (LabelList + MarkupList).
- **Animated transitions:** No slide-in or crossfade between screens. Instant show/hide only (per BusySpinner SIGSEGV decision).
- **Season-level mark all watched:** Bulk actions deferred to v2+.
- **Custom episode sorting/filtering:** Rely on Plex server ordering.
- **Continue Watching direct-to-EpisodeScreen routing:** Continue Watching items are individual episodes and should keep launching playback directly, not routing to EpisodeScreen.
- **HomeScreen `startPlaybackFromGrid` migration to `playbackResult`:** HomeScreen and PlaylistScreen still use the old `playbackComplete` boolean. Migrating them is a separate cleanup task, not part of navigation overhaul.

## Constraints

- **Do not split EpisodeScreen into multiple screens.** The two-panel layout (LabelList seasons + MarkupList episodes) stays as a single component. Splitting severs the five VideoPlayer context fields needed for auto-play (per Pitfall 1 in research).
- **No Animation nodes** for any visual changes. Use instant translation/visibility changes only.
- **MainScene routing is already wired.** `onItemSelected` already handles `action:"episodes"` → `showEpisodeScreen()`. The change is purely in HomeScreen emitting the correct action for shows.
- **Watch state propagation uses existing `m.global.watchStateUpdate` signal.** Do not add new global fields (per Anti-Pattern 3 in research). Extend the existing `onWatchStateUpdate` handler to also walk the hub RowList tree.
- **Season guard exists for rapid navigation.** `onSeasonFocused` already guards against redundant `loadEpisodes()` calls when `index = m.currentSeasonIndex`. Do not remove this guard during refactor.
- **EpisodeScreen receives `ratingKey` (show) and `showTitle` via interface fields.** These are set by MainScene's `showEpisodeScreen()`. No changes to the interface contract.

## Integration Points

### Consumes

- `MainScene.showEpisodeScreen(ratingKey, title)` — already exists, routes `action:"episodes"` to EpisodeScreen push.
- `MainScene.showDetailScreen(ratingKey, itemType)` — used for "Show Info" option from EpisodeScreen.
- `m.global.watchStateUpdate` — existing global signal emitted by VideoPlayer after scrobble/stop. HomeScreen already observes it for poster grid; needs extension for hub RowList.
- `EpisodeScreen.brs` — existing two-panel layout with season LabelList and episode MarkupList.
- `HomeScreen.onGridItemSelected()` — current routing logic that emits `action:"detail"` for all types.
- `HomeScreen.onHubItemSelected()` — current routing for hub row taps.
- `HomeScreen.showResumeDialog()` — current resume dialog with "Go to Details" button.
- Plex API `/library/metadata/{id}/children` — returns seasons with `leafCount` and `viewedLeafCount` fields.

### Produces

- **HomeScreen show routing** — TV shows emit `{action:"episodes"}` from grid, hub rows, and resume dialog.
- **EpisodeScreen "Show Info" option** — options menu includes "Show Info" alongside watched toggle, routing to DetailScreen.
- **Season progress labels** — "Season 1 (6/10)" format in LabelList.
- **Hub row watch state walker** — `onWatchStateUpdate` walks both poster grid and hub RowList ContentNode trees.
- **EpisodeScreen layout improvements** — better spacing, show metadata below title, episode badge verification.

## Open Questions

- **Hub RowList ContentNode tree shape** — The hub RowList tree structure (rows as children, items as grandchildren of rows) needs to be confirmed by reading `processHubs()` in HomeScreen.brs before writing the walker. This is a 15-minute code read, not a research gap. The poster grid walker provides the template; the RowList walker adds one level of nesting.
- **Season label width** — Current `itemSize="[200, 50]"` on the LabelList may be too narrow for "Season 10 (24/24)". Need to test whether the label truncates or wraps. May need to widen `itemSize` or switch to a shorter format like "S10 (24/24)".
- **Show summary source** — EpisodeScreen currently only receives `ratingKey` and `showTitle`. To display a show summary/year below the title, the show metadata needs to be fetched (which `processSeasons()` already calls via `/library/metadata/{id}/children` — check if the parent container includes `summary` and `year`). If not available from the children endpoint, a separate `/library/metadata/{id}` call may be needed.
