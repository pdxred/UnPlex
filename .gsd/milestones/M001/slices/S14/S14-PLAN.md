# S14: TV Show Navigation Overhaul

**Goal:** Grid tap on TV shows navigates directly to EpisodeScreen; DetailScreen accessible via options key "Show Info" action from both HomeScreen and EpisodeScreen.
**Demo:** Selecting a TV show in the library poster grid or hub rows opens EpisodeScreen immediately (no intermediate DetailScreen hop). Pressing the options key on a show in HomeScreen or EpisodeScreen offers "Show Info" to reach DetailScreen. Back button from EpisodeScreen returns to HomeScreen; back from DetailScreen returns to EpisodeScreen.

## Must-Haves

- Grid selection on TV show items emits `action: "episodes"` instead of `action: "detail"`
- Hub row selection on TV show items emits `action: "episodes"` instead of `action: "detail"`
- HomeScreen options menu for TV shows includes "Show Info" button that routes to DetailScreen
- EpisodeScreen options menu includes "Show Info" button that routes to DetailScreen
- Non-show items (movies, episodes, collections, playlists) are unaffected — routing unchanged
- No Animation nodes introduced (SIGSEGV safety per S11 rule)
- MainScene.brs is NOT modified (already handles both `action: "episodes"` and `action: "detail"`)

## Verification

```bash
# T01 — HomeScreen routing changes
grep -c 'action.*episodes' SimPlex/components/screens/HomeScreen.brs
# Expected: >= 2 (grid + hub)

grep -c 'Show Info' SimPlex/components/screens/HomeScreen.brs
# Expected: >= 1

# T02 — EpisodeScreen options menu
grep -c 'Show Info' SimPlex/components/screens/EpisodeScreen.brs
# Expected: >= 1

grep -c 'action.*detail' SimPlex/components/screens/EpisodeScreen.brs
# Expected: >= 1 (from Show Info handler)

# Safety — no Animation nodes in changed files
grep -c 'Animation' SimPlex/components/screens/HomeScreen.brs SimPlex/components/screens/EpisodeScreen.brs
# Expected: 0 per file (or only pre-existing non-node references)

# MainScene unchanged — still dispatches both actions
grep -n 'action.*episodes\|action.*detail' SimPlex/components/MainScene.brs
# Expected: lines 443, 445 (pre-existing, not modified)

# Failure-path: show items without itemType fall through to detail (safe degradation)
# Verify no crash-inducing Animation node creation in changed files
grep -n 'CreateObject.*Animation' SimPlex/components/screens/HomeScreen.brs SimPlex/components/screens/EpisodeScreen.brs
# Expected: 0 matches (no Animation nodes created)
```

## Tasks

- [x] **T01: Route TV shows to EpisodeScreen from HomeScreen grid and hub rows** `est:25m`
  - Why: Core navigation change — TV show taps should skip DetailScreen and go directly to EpisodeScreen. Also adds "Show Info" to the HomeScreen options menu so DetailScreen remains accessible for shows.
  - Files: `SimPlex/components/screens/HomeScreen.brs`
  - Do: In `onGridItemSelected()`, before the catch-all `action: "detail"` block (line ~1047), add an `if item.itemType = "show"` check that emits `{ action: "episodes", ratingKey: item.ratingKey, title: item.title }`. In `onHubRowItemSelected()`, in the else branch (line ~425), add the same `itemContent.itemType = "show"` check. In `showOptionsMenu()`, for show items add a "Show Info" button between the watched toggle and "Cancel". In `onOptionsMenuButton()`, handle the new button index for shows by emitting `{ action: "detail", ratingKey: item.ratingKey, itemType: "show" }`. No Animation nodes.
  - Verify: `grep -c "action.*episodes" SimPlex/components/screens/HomeScreen.brs` returns >= 2; `grep -c "Show Info" SimPlex/components/screens/HomeScreen.brs` returns >= 1
  - Done when: TV show items in grid and hub rows emit episodes action; options menu offers "Show Info" for shows; non-show routing unchanged.

- [ ] **T02: Add "Show Info" option to EpisodeScreen options menu** `est:15m`
  - Why: DetailScreen must remain accessible from EpisodeScreen for users who want full show metadata.
  - Files: `SimPlex/components/screens/EpisodeScreen.brs`
  - Do: In `showEpisodeOptionsMenu()`, add "Show Info" button between the watched toggle and "Cancel" (buttons become `[watchedLabel, "Show Info", "Cancel"]`). In `onEpisodeOptionsButton()`, handle the new index 1 by emitting `{ action: "detail", ratingKey: m.top.ratingKey, itemType: "show" }` via `m.top.itemSelected`. Shift the existing cancel logic to index 2. No Animation nodes.
  - Verify: `grep -c "Show Info" SimPlex/components/screens/EpisodeScreen.brs` returns >= 1; `grep "action.*detail" SimPlex/components/screens/EpisodeScreen.brs` shows the new handler
  - Done when: EpisodeScreen options menu shows "Show Info" and navigates to DetailScreen when selected.

## Files Likely Touched

- `SimPlex/components/screens/HomeScreen.brs`
- `SimPlex/components/screens/EpisodeScreen.brs`

## Observability / Diagnostics

- **Routing signals:** The `itemSelected` field on HomeScreen and EpisodeScreen emits associative arrays with an `action` key. Observing `itemSelected` in MainScene (lines 440-450) logs which action was dispatched. If a show tap emits `action: "episodes"` but EpisodeScreen doesn't appear, check MainScene's `onItemSelected` handler.
- **Options menu state:** `m.pendingOptionsItem` stores the item used for the context menu. If "Show Info" navigates to the wrong item, inspect `m.pendingOptionsItem.ratingKey` and `.itemType` at dialog selection time.
- **Failure visibility:** If `itemType` is missing or empty on a content node, the show-specific branches won't match and the item falls through to the default `action: "detail"` path — safe degradation, no crash. A show appearing in DetailScreen instead of EpisodeScreen indicates `itemType` wasn't set to `"show"` on that content node.
- **Diagnostic grep:** `grep -n 'action.*episodes' SimPlex/components/screens/HomeScreen.brs` confirms routing wiring. Zero matches means the routing change was lost or reverted.
- **No secrets or tokens involved** — routing changes are purely local UI navigation.
