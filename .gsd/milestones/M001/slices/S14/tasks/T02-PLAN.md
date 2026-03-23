---
estimated_steps: 2
estimated_files: 1
skills_used: []
---

# T02: Add "Show Info" option to EpisodeScreen options menu

**Slice:** S14 — TV Show Navigation Overhaul
**Milestone:** M001

## Description

Add a "Show Info" button to the EpisodeScreen episode options menu so users can navigate to DetailScreen from within EpisodeScreen. This is the reverse path: since S14 makes EpisodeScreen the primary entry point for TV shows, users need a way to reach the full show detail view.

EpisodeScreen already has `m.top.ratingKey` (the show's rating key) and `m.top.itemSelected` (assocarray field for navigation actions). MainScene already dispatches `action: "detail"` to `showDetailScreen(data.ratingKey, data.itemType)`.

## Steps

1. **In `showEpisodeOptionsMenu()` (~line 325-341):** Change the buttons array from `[watchedLabel, "Cancel"]` to `[watchedLabel, "Show Info", "Cancel"]`:
   ```brightscript
   dialog.buttons = [watchedLabel, "Show Info", "Cancel"]
   ```

2. **In `onEpisodeOptionsButton()` (~line 343-380):** The current handler has index 0 = watched toggle, index 1 = cancel (which just closes dialog). Insert handling for index 1 = "Show Info" and shift cancel to index 2. Add after the index 0 block:
   ```brightscript
   else if index = 1
       ' Navigate to show detail screen
       m.top.itemSelected = {
           action: "detail"
           ratingKey: m.top.ratingKey
           itemType: "show"
       }
   ```
   The dialog close happens at the top of the handler (line ~346: `m.top.getScene().dialog.close = true`) before the index checks, so it fires for all buttons including "Show Info". The existing cancel path (was index 1, now implicitly index 2) doesn't need explicit handling — it just closes the dialog, which already happened.

## Must-Haves

- [ ] EpisodeScreen options menu shows "Show Info" button between watched toggle and Cancel
- [ ] "Show Info" emits `{ action: "detail", ratingKey: m.top.ratingKey, itemType: "show" }` via `m.top.itemSelected`
- [ ] Watched toggle (index 0) still works unchanged
- [ ] Cancel (now index 2) still closes dialog
- [ ] No Animation nodes introduced

## Verification

- `grep -c "Show Info" SimPlex/components/screens/EpisodeScreen.brs` returns >= 1
- `grep "action.*detail" SimPlex/components/screens/EpisodeScreen.brs` shows the new "Show Info" handler emitting detail action
- `grep -rn "Animation" SimPlex/components/screens/EpisodeScreen.brs` shows no new Animation node creation

## Inputs

- `SimPlex/components/screens/EpisodeScreen.brs` — existing file with `showEpisodeOptionsMenu()` and `onEpisodeOptionsButton()`

## Expected Output

- `SimPlex/components/screens/EpisodeScreen.brs` — modified with "Show Info" button in options menu and detail action handler
