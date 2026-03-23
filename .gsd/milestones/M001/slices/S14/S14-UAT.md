# S14: TV Show Navigation Overhaul — UAT Script

## Preconditions

- SimPlex sideloaded on Roku dev device
- Plex server reachable with at least one TV show library containing multiple shows, seasons, and episodes
- At least one movie library also available (to verify non-show routing is unaffected)
- User is authenticated and on HomeScreen

---

## Test Cases

### TC-01: Library grid — TV show opens EpisodeScreen directly

1. Navigate to a TV show library via sidebar
2. Select any TV show poster in the grid
3. **Expected:** EpisodeScreen opens showing the show's seasons/episodes — NOT DetailScreen
4. Press Back
5. **Expected:** Returns to the library grid with focus on the same poster

### TC-02: Library grid — Movie still opens DetailScreen

1. Navigate to a movie library via sidebar
2. Select any movie poster in the grid
3. **Expected:** DetailScreen opens (unchanged behavior)
4. Press Back
5. **Expected:** Returns to library grid

### TC-03: Hub row — TV show opens EpisodeScreen directly

1. Return to HomeScreen (sidebar → Home)
2. Navigate to a hub row (Recently Added, On Deck) that contains a TV show item
3. Select the TV show item
4. **Expected:** EpisodeScreen opens — NOT DetailScreen
5. Press Back
6. **Expected:** Returns to HomeScreen with focus restored to the hub row

### TC-04: Hub row — Continue Watching episode still plays directly

1. On HomeScreen, navigate to the "Continue Watching" hub row
2. Select an in-progress episode
3. **Expected:** Playback starts immediately (unchanged behavior — episodes in Continue Watching play, not navigate)

### TC-05: HomeScreen options menu — "Show Info" for TV show

1. Navigate to a TV show library grid
2. Focus a TV show poster
3. Press the Options key (asterisk/star button on Roku remote)
4. **Expected:** Dialog appears with buttons: `[Mark as Watched/Unwatched, "Show Info", "Cancel"]`
5. Select "Show Info"
6. **Expected:** DetailScreen opens for that TV show (showing full metadata, cast, etc.)
7. Press Back
8. **Expected:** Returns to library grid (not EpisodeScreen — DetailScreen was opened from grid context)

### TC-06: HomeScreen options menu — Movie has no "Show Info"

1. Navigate to a movie library grid
2. Focus a movie poster
3. Press the Options key
4. **Expected:** Dialog appears with buttons: `[Mark as Watched/Unwatched, "Cancel"]` — NO "Show Info" button
5. Select Cancel
6. **Expected:** Dialog closes, focus returns to poster

### TC-07: EpisodeScreen options menu — "Show Info"

1. Open any TV show (tap poster → EpisodeScreen opens per TC-01)
2. Focus an episode in the episode list
3. Press the Options key
4. **Expected:** Dialog appears with buttons: `[Mark as Watched/Unwatched, "Show Info", "Cancel"]`
5. Select "Show Info"
6. **Expected:** DetailScreen opens for the **show** (not the individual episode)
7. Press Back
8. **Expected:** Returns to EpisodeScreen (not HomeScreen)

### TC-08: EpisodeScreen options menu — Cancel

1. From EpisodeScreen, focus an episode
2. Press Options key
3. Select "Cancel" (index 2)
4. **Expected:** Dialog closes, focus returns to episode list — no navigation occurs

### TC-09: EpisodeScreen options menu — Mark Watched toggle

1. From EpisodeScreen, focus an unwatched episode
2. Press Options key
3. Select "Mark as Watched" (index 0)
4. **Expected:** Episode's watched state toggles, dialog closes, focus returns to episode list
5. Repeat and select "Mark as Unwatched"
6. **Expected:** State toggles back

### TC-10: Hub row — TV show with missing itemType falls through safely

1. (This is a defensive edge case — if Plex returns a show item without `itemType = "show"`, the code falls through to the default `action: "detail"` path)
2. **Expected behavior:** DetailScreen opens instead of EpisodeScreen — no crash
3. **Verification:** This is safe degradation by design. A show appearing in DetailScreen instead of EpisodeScreen indicates the content node's `itemType` wasn't populated — not a crash condition.

---

## Edge Cases

### EC-01: Collection items in grid
1. Navigate to a library and select a Collection item
2. **Expected:** Collection screen opens (unchanged — collections have `itemType = "collection"`, not `"show"`)

### EC-02: Playlist items in grid
1. Select a Playlist item from sidebar or grid
2. **Expected:** Playlist screen opens (unchanged routing)

### EC-03: Rapid show selection
1. Quickly select multiple TV shows in succession (tap, back, tap different show)
2. **Expected:** Each opens EpisodeScreen for the correct show; no stuck screens or wrong content

---

## Pass Criteria

All TC-01 through TC-09 must pass. TC-10 is informational (safe degradation). EC-01 through EC-03 confirm no regressions.
