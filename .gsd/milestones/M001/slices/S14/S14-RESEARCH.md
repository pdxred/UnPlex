# S14 Research: TV Show Navigation Overhaul

**Slice:** S14 — TV Show Navigation Overhaul
**Milestone:** M001 — SimPlex v1.1 Polish & Navigation
**Depth:** Light (established patterns, known code, surgical changes)
**Confidence:** HIGH

## Summary

TV show grid taps currently route through DetailScreen before reaching EpisodeScreen — a two-hop flow. S14 removes the intermediate DetailScreen hop for TV shows: grid tap → EpisodeScreen directly. DetailScreen remains accessible via an "Info" option from the EpisodeScreen options key menu, and from HomeScreen's options key context menu on show items.

All routing infrastructure already exists. MainScene already handles `action: "episodes"` (line 445). EpisodeScreen already accepts `ratingKey` + `showTitle` interface fields. The ContentNode items in both the poster grid and hub rows already carry `itemType` and `title` fields. This is a routing-only change — no new components, no new API calls, no new task nodes.

## Requirements Addressed

| Requirement | How S14 Delivers |
|---|---|
| **NAV-01** (Seasons as grid/list screen) | Already delivered by existing EpisodeScreen — S14 makes it the primary entry point |
| **NAV-02** (Select season to see episodes) | Already delivered — EpisodeScreen season LabelList + episode MarkupList |
| **NAV-03** (Watch/progress state on season/episode screens) | Already delivered — EpisodeScreen has `onWatchStateUpdate` observer |
| **NAV-04** (Back button through Show → Seasons → Episodes) | S14 simplifies: grid → EpisodeScreen → back to grid. DetailScreen accessible via options key creates grid → EpisodeScreen → DetailScreen → back chain when user wants it |

## Recommendation

Three targeted edits across two files. No architectural changes.

## Implementation Landscape

### Change 1: HomeScreen Grid Selection — Route Shows to EpisodeScreen

**File:** `SimPlex/components/screens/HomeScreen.brs`
**Function:** `onGridItemSelected()` (line 1013)
**Current:** Lines 1046-1049 send `action: "detail"` for all non-collection, non-playlist, non-resumable items.
**Change:** Before the catch-all `action: "detail"`, check `item.itemType = "show"` and emit `action: "episodes"` with `ratingKey` and `title` instead.

```brightscript
' Current (line 1046-1049):
m.top.itemSelected = {
    action: "detail"
    ratingKey: item.ratingKey
    itemType: item.itemType
}

' After:
if item.itemType = "show"
    m.top.itemSelected = {
        action: "episodes"
        ratingKey: item.ratingKey
        title: item.title
    }
else
    m.top.itemSelected = {
        action: "detail"
        ratingKey: item.ratingKey
        itemType: item.itemType
    }
end if
```

**Data available:** `item.ratingKey` (string), `item.title` (string), `item.itemType` (string, = `"show"` for TV shows, from Plex API `item.type`). All populated in `processLibraryResults()` at line 664.

### Change 2: HomeScreen Hub Row Selection — Route Shows to EpisodeScreen

**File:** `SimPlex/components/screens/HomeScreen.brs`
**Function:** `onHubRowItemSelected()` (approx line 405-430)
**Current:** Lines 424-428 send `action: "detail"` for all non-continue-watching hub items.
**Change:** Same pattern — check `itemContent.itemType = "show"` and route to `action: "episodes"`.

```brightscript
' Current (line 424-428):
m.top.itemSelected = {
    action: "detail"
    ratingKey: itemContent.ratingKey
    itemType: itemContent.itemType
}

' After:
if itemContent.itemType = "show"
    m.top.itemSelected = {
        action: "episodes"
        ratingKey: itemContent.ratingKey
        title: itemContent.title
    }
else
    m.top.itemSelected = {
        action: "detail"
        ratingKey: itemContent.ratingKey
        itemType: itemContent.itemType
    }
end if
```

**Data available:** Hub row ContentNodes are built in `addHubRow()` (line 349) with `itemType: item.type` and `title: item.title`.

### Change 3: EpisodeScreen Options Key — Add "Show Info" Action

**File:** `SimPlex/components/screens/EpisodeScreen.brs`
**Function:** `showEpisodeOptionsMenu()` (approx line 378) and `onEpisodeOptionsButton()` (approx line 393)
**Current:** Options menu offers only [watched/unwatched toggle, "Cancel"].
**Change:** Add "Show Info" button that emits `{ action: "detail", ratingKey: m.top.ratingKey, itemType: "show" }` via `m.top.itemSelected`.

```brightscript
' In showEpisodeOptionsMenu — add "Show Info" before "Cancel":
dialog.buttons = [watchedLabel, "Show Info", "Cancel"]

' In onEpisodeOptionsButton — handle index 1:
else if index = 1
    ' Navigate to show detail screen
    m.top.itemSelected = {
        action: "detail"
        ratingKey: m.top.ratingKey
        itemType: "show"
    }
```

**Data available:** `m.top.ratingKey` is the show's ratingKey (set when EpisodeScreen is created). `m.top.showTitle` available if needed for any additional context.

### Change 4 (Optional): HomeScreen Options Menu — Add "Show Info" for Show Items

**File:** `SimPlex/components/screens/HomeScreen.brs`
**Function:** `showOptionsMenu()` (line 1127) and `onOptionsMenuButton()` (line 1155)
**Current:** Options menu offers only [watched toggle, "Cancel"].
**Change:** For show items, add "Show Info" button that routes to DetailScreen.

```brightscript
' In showOptionsMenu — for shows, add "Show Info" button:
if item.itemType = "show"
    dialog.buttons = [watchedLabel, "Show Info", "Cancel"]
else
    dialog.buttons = [watchedLabel, "Cancel"]
end if

' In onOptionsMenuButton — handle index 1 for shows:
else if index = 1 and m.pendingOptionsItem.itemType = "show"
    m.top.itemSelected = {
        action: "detail"
        ratingKey: m.pendingOptionsItem.ratingKey
        itemType: "show"
    }
```

This ensures DetailScreen is always accessible for shows via options key from HomeScreen, complementing the same capability in EpisodeScreen.

### Change 5: HomeScreen Resume Dialog — Route Shows Correctly

**File:** `SimPlex/components/screens/HomeScreen.brs`
**Function:** `onResumeDialogButton()` (line 1071)
**Current:** "Go to Details" (button index 2) sends `action: "detail"`. For show-type items with `viewOffset > 0` this is correct — the user wants the detail view (which has "Browse Seasons" button). No change needed here.

**Note:** Shows normally don't have `viewOffset` (individual episodes do, shows don't), so the resume dialog won't fire for shows from the library grid. Hub rows with continue-watching items are episodes, not shows, so they go through the resume/play flow correctly.

## Constraints

1. **No Animation nodes.** All changes are routing logic only — no UI animations per S11 SIGSEGV rule.
2. **MainScene needs no changes.** `onItemSelected()` already dispatches `action: "episodes"` to `showEpisodeScreen()` (line 445-446).
3. **EpisodeScreen interface unchanged.** `ratingKey` and `showTitle` fields already exist on the interface.
4. **Watch state propagation works.** S12 already wired `onWatchStateUpdate` in EpisodeScreen. When user pops back to HomeScreen after navigating through EpisodeScreen, hub refresh and grid watch state update are handled by existing `onServerReconnected` / `loadHubs()` patterns.

## Seams for Task Decomposition

This is naturally one task — all changes are interdependent (routing shows to EpisodeScreen and providing the reverse path via "Show Info" option). However, if splitting:

- **T01:** HomeScreen routing changes (grid selection + hub selection + options menu "Show Info") — all in HomeScreen.brs
- **T02:** EpisodeScreen options menu "Show Info" — all in EpisodeScreen.brs

T01 and T02 are independent files but should be verified together (grid tap on show → lands on EpisodeScreen → options → "Show Info" → lands on DetailScreen → back returns to EpisodeScreen → back returns to HomeScreen).

## Verification

```bash
# 1. Grid items route shows to episodes action
grep -n "action.*episodes" SimPlex/components/screens/HomeScreen.brs
# Should show new routing in onGridItemSelected

# 2. Hub items route shows to episodes action  
grep -A5 "itemContent.itemType.*show" SimPlex/components/screens/HomeScreen.brs
# Should show episodes routing for hub shows

# 3. EpisodeScreen options menu has "Show Info"
grep -n "Show Info" SimPlex/components/screens/EpisodeScreen.brs
# Should appear in showEpisodeOptionsMenu

# 4. EpisodeScreen emits detail action for show info
grep -n "action.*detail.*show" SimPlex/components/screens/EpisodeScreen.brs
# Should appear in onEpisodeOptionsButton

# 5. No Animation nodes introduced
grep -rn "Animation\|createObject.*Animation" SimPlex/components/screens/HomeScreen.brs SimPlex/components/screens/EpisodeScreen.brs
# Should return nothing new

# 6. MainScene still handles both actions
grep -n "action.*episodes\|action.*detail" SimPlex/components/MainScene.brs
# Should show existing handlers (no changes needed)
```

## Files Modified

| File | Scope |
|------|-------|
| `SimPlex/components/screens/HomeScreen.brs` | `onGridItemSelected()`, `onHubRowItemSelected()` hub else branch, `showOptionsMenu()`, `onOptionsMenuButton()` |
| `SimPlex/components/screens/EpisodeScreen.brs` | `showEpisodeOptionsMenu()`, `onEpisodeOptionsButton()` |

## What Won't Change

- `MainScene.brs` — already handles both `action: "episodes"` and `action: "detail"`
- `DetailScreen.brs` — untouched, still works as show detail when reached via options key
- `EpisodeScreen.xml` — interface fields already sufficient
- `VideoPlayer.brs` — no playback changes
- Task nodes — no API changes

---
*Researched: 2026-03-23*
*Ready for planning: yes*
