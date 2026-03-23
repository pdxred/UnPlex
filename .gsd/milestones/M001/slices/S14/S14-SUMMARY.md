---
id: S14
milestone: M001
status: done
completed_at: 2026-03-23
tasks_completed: [T01, T02]
provides:
  - TV show grid selection routes directly to EpisodeScreen (skips DetailScreen)
  - TV show hub row selection routes directly to EpisodeScreen
  - HomeScreen options menu includes "Show Info" for TV shows → navigates to DetailScreen
  - EpisodeScreen options menu includes "Show Info" → navigates to DetailScreen
  - Non-show items (movies, episodes, collections, playlists) routing unchanged
key_files:
  - SimPlex/components/screens/HomeScreen.brs
  - SimPlex/components/screens/EpisodeScreen.brs
patterns_established:
  - Options menu button index shifting — when inserting type-specific buttons (e.g. "Show Info" for shows), Cancel shifts to a higher index but needs no explicit handler because dialog close and focus restore both run unconditionally at function end
  - itemType-based routing branching — check itemType before the catch-all detail action, with safe fallthrough for items missing the field
---

# S14: TV Show Navigation Overhaul — Summary

**Grid tap on TV shows now navigates directly to EpisodeScreen; DetailScreen is accessible via the options key "Show Info" action from both HomeScreen and EpisodeScreen.**

## What Was Delivered

Two targeted edits to HomeScreen.brs and EpisodeScreen.brs changed the TV show navigation flow without touching MainScene (which already dispatched both `action: "episodes"` and `action: "detail"`).

### T01: HomeScreen routing + options menu
- **`onHubItemSelected`** — New `itemType = "show"` branch emits `action: "episodes"` instead of `action: "detail"`.
- **`onGridItemSelected`** — Same show check before the catch-all detail emission.
- **`showOptionsMenu`** — For show items, buttons become `[watchedLabel, "Show Info", "Cancel"]`.
- **`onOptionsMenuButton`** — Index 1 for shows emits `action: "detail"` with the show's ratingKey.

### T02: EpisodeScreen options menu
- **`showEpisodeOptionsMenu`** — Buttons become `[watchedLabel, "Show Info", "Cancel"]`.
- **`onEpisodeOptionsButton`** — Index 1 emits `action: "detail"` with `m.top.ratingKey` (show-level key).

### Safety
- No Animation nodes introduced (SIGSEGV rule from S11).
- Items without `itemType = "show"` fall through to the default `action: "detail"` path — safe degradation, no crash.
- MainScene.brs was not modified.

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| Grid+hub routing | `grep -c 'action.*episodes' HomeScreen.brs` | 2 ✅ |
| HomeScreen Show Info | `grep -c 'Show Info' HomeScreen.brs` | 2 ✅ |
| EpisodeScreen Show Info | `grep -c 'Show Info' EpisodeScreen.brs` | 1 ✅ |
| EpisodeScreen detail action | `grep -c 'action.*detail' EpisodeScreen.brs` | 2 ✅ |
| No Animation nodes created | `grep -n 'CreateObject.*Animation' HomeScreen.brs EpisodeScreen.brs` | 0 ✅ |
| MainScene unchanged | Lines 443, 445 present and unmodified | ✅ |

## What the Next Slice Should Know

- **Navigation flow is now:** Grid/Hub → EpisodeScreen (for shows) or DetailScreen (for everything else). DetailScreen is one options-key hop away from either HomeScreen or EpisodeScreen for shows.
- **`itemType` field on ContentNodes is the routing discriminator.** If a new content type needs special routing, follow the same pattern: add an `if itemType = "..."` branch before the catch-all detail block.
- **Options menu button indices are context-sensitive.** Show items have 3 buttons `[watchedLabel, "Show Info", "Cancel"]`; non-show items have 2 `[watchedLabel, "Cancel"]`. The cancel handler doesn't need an explicit branch — `restoreFocusAfterDialog()` runs unconditionally.
- **MainScene dispatching is stable.** Both `action: "episodes"` and `action: "detail"` are already handled. New actions can be added there but the existing two don't need changes.

## Deviations

None. Both tasks matched the plan exactly.

## Known Issues

None introduced. Pre-existing: HomeScreen direct playback path still uses old `playbackComplete` observer (documented in KNOWLEDGE.md gotchas).
