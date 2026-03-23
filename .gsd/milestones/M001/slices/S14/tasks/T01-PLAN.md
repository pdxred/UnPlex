---
estimated_steps: 4
estimated_files: 1
skills_used: []
---

# T01: Route TV shows to EpisodeScreen from HomeScreen grid and hub rows

**Slice:** S14 — TV Show Navigation Overhaul
**Milestone:** M001

## Description

Change HomeScreen routing so TV show selections go directly to EpisodeScreen instead of DetailScreen. This applies to both the library poster grid (`onGridItemSelected`) and hub rows (`onHubRowItemSelected`). Also add a "Show Info" option to the HomeScreen options key context menu for show items, so users can still reach DetailScreen when they want full metadata.

MainScene already handles `action: "episodes"` (line 445-446, dispatches to `showEpisodeScreen(data.ratingKey, data.title)`). No changes needed there. The emitted action AA must use field name `title` (not `showTitle`) because that's what MainScene reads.

## Steps

1. **In `onGridItemSelected()` (~line 1044-1050):** Before the catch-all `m.top.itemSelected = { action: "detail" ... }` block, add an `if item.itemType = "show"` check that emits:
   ```brightscript
   m.top.itemSelected = {
       action: "episodes"
       ratingKey: item.ratingKey
       title: item.title
   }
   ```
   Wrap the existing detail action in an `else` block. Collections and playlists are handled earlier (with `return`), and resume-dialog items have `viewOffset > 0` (shows don't), so those paths are unaffected.

2. **In `onHubRowItemSelected()` (~line 424-429):** In the `else` branch (non-continue-watching hubs), add the same `itemContent.itemType = "show"` check before the `action: "detail"` emission:
   ```brightscript
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

3. **In `showOptionsMenu()` (~line 1127-1152):** For show items, insert "Show Info" between the watched toggle label and "Cancel":
   ```brightscript
   if item.itemType = "show"
       dialog.buttons = [watchedLabel, "Show Info", "Cancel"]
   else
       dialog.buttons = [watchedLabel, "Cancel"]
   end if
   ```

4. **In `onOptionsMenuButton()` (~line 1155-1178):** Handle the new "Show Info" button (index 1 for shows). Before the existing `restoreFocusAfterDialog()`, add:
   ```brightscript
   else if index = 1 and m.pendingOptionsItem.itemType = "show"
       m.top.itemSelected = {
           action: "detail"
           ratingKey: m.pendingOptionsItem.ratingKey
           itemType: "show"
       }
   ```
   The existing cancel handler (was index 1, now index 2 for shows) uses `restoreFocusAfterDialog()` at the end of the function which fires regardless of which button was pressed, so no special cancel handling needed — the dialog closes on any button selection.

## Must-Haves

- [ ] TV show items in library grid emit `action: "episodes"` with `ratingKey` and `title`
- [ ] TV show items in hub rows emit `action: "episodes"` with `ratingKey` and `title`
- [ ] Non-show items (movies, episodes, collections, playlists) still emit `action: "detail"` unchanged
- [ ] HomeScreen options menu for shows includes "Show Info" that emits `action: "detail"` with `itemType: "show"`
- [ ] No Animation nodes introduced

## Verification

- `grep -c "action.*episodes" SimPlex/components/screens/HomeScreen.brs` returns >= 2 (grid + hub routing)
- `grep -c "Show Info" SimPlex/components/screens/HomeScreen.brs` returns >= 1 (options menu button)
- `grep -rn "Animation" SimPlex/components/screens/HomeScreen.brs` shows no new Animation node creation
- Non-show routing paths are unchanged: `grep -c 'action.*detail' SimPlex/components/screens/HomeScreen.brs` still shows detail routing for non-show items

## Inputs

- `SimPlex/components/screens/HomeScreen.brs` — existing file with `onGridItemSelected()`, `onHubRowItemSelected()`, `showOptionsMenu()`, `onOptionsMenuButton()`

## Expected Output

- `SimPlex/components/screens/HomeScreen.brs` — modified with show-specific routing in grid/hub handlers and "Show Info" in options menu
