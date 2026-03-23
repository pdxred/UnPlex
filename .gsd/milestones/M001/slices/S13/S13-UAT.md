# S13 UAT: Search, Collections, and Thumbnails

**Preconditions:**
- SimPlex sideloaded on Roku in developer mode
- Connected to a Plex Media Server with at least one movie library and one TV show library
- At least one TV show with multiple episodes exists (for thumbnail testing)
- At least one collection exists in any library
- Roku remote available (or Roku Remote app)
- Roku Developer Console open at `http://{roku-ip}:8085` for diagnostic output

---

## Test 1: Search Keyboard Collapse on Right Navigation

**Steps:**
1. From HomeScreen, navigate to Search in the sidebar and press OK.
2. Type any search query (e.g., "the") using the on-screen keyboard. Wait for results to appear.
3. Press **Right** on the remote.

**Expected:**
- On-screen keyboard disappears.
- Search results grid expands to fill the full screen width (~6 columns visible).
- Focus moves to the first search result item.
- Search query label remains visible at the top of the screen.

---

## Test 2: Search Keyboard Reappear on Left Navigation

**Precondition:** Complete Test 1 (focus is on the search results grid, keyboard hidden).

**Steps:**
1. Press **Left** on the remote.

**Expected:**
- On-screen keyboard reappears on the left side.
- Search results grid shrinks to ~4 columns, positioned to the right of the keyboard.
- Focus returns to the keyboard.
- Previous search query and results remain intact.

---

## Test 3: Keyboard Toggle Round-Trip

**Steps:**
1. From Search with a query entered and results visible, press **Right** (keyboard hides).
2. Press **Left** (keyboard shows).
3. Press **Right** again (keyboard hides).
4. Press **Left** again (keyboard shows).

**Expected:**
- Each toggle is instant (no animation lag or visual glitches).
- Grid column count toggles between ~4 (keyboard visible) and ~6 (keyboard hidden) on each transition.
- No crashes or visual corruption after multiple toggles.

---

## Test 4: Library Grid Column Count Unchanged

**Steps:**
1. From HomeScreen, select any library from the sidebar (e.g., "Movies").
2. Observe the poster grid.

**Expected:**
- Grid displays 6 columns (unchanged from pre-S13 behavior).
- Poster sizing and spacing identical to previous behavior.

---

## Test 5: Episode Thumbnail Shows Portrait Poster in Search

**Steps:**
1. Navigate to Search.
2. Type the name of a known TV episode (or a TV show name that returns episode results).
3. Look at the poster thumbnails for episode results.

**Expected:**
- Episode search results display portrait show artwork (the TV show's poster), NOT a stretched 16:9 episode screenshot.
- Movie results still show their normal poster artwork.

**Diagnostic:** In SceneGraph inspector, select an episode search result ContentNode and check `HDPosterUrl`. The URL path should contain `/grandparentThumb/` or `/parentThumb/` (not `/thumb/` pointing to an episode screenshot).

---

## Test 6: Collections from Home Hub (No Library Selected)

**Steps:**
1. Launch SimPlex fresh (or navigate to HomeScreen showing hub rows — Continue Watching, Recently Added, etc.).
2. **Do NOT select any library from the sidebar** — stay on the Home hub view.
3. Using the sidebar, navigate to "Collections" and press OK.

**Expected:**
- Collections load from the first available library (not an error or blank screen).
- Roku debug console shows: `Collections auto-selected library: {title} (section {key})`.
- Collection posters appear in the grid.

---

## Test 7: Collections from Library View (Library Already Selected)

**Steps:**
1. From HomeScreen, select a library from the sidebar (e.g., "Movies").
2. Navigate to "Collections" in the sidebar and press OK.

**Expected:**
- Collections load from the currently selected library (same behavior as before S13).
- No auto-select diagnostic print in debug console.

---

## Test 8: Collections with Slow Library Fetch

**Steps:**
1. Launch SimPlex with a slow or remote PMS connection.
2. Immediately (before hub rows finish loading) try tapping "Collections" from the sidebar.

**Expected:**
- If libraries haven't loaded yet, the tap is a safe no-op (no crash, no error dialog).
- Once libraries load, tapping "Collections" works normally.

---

## Test 9: Search Empty State and Error Positioning

**Steps:**
1. Navigate to Search. Do not type anything — observe empty state message.
2. Press **Right** — keyboard should collapse.
3. Verify empty state / "no results" message repositions to the center of the expanded area.
4. Press **Left** — keyboard reappears, message repositions back.

**Expected:**
- Empty state text and retry group (if visible) reposition correctly in both keyboard-visible and keyboard-hidden layouts.
- No text clipping or off-screen positioning.

---

## Test 10: Search Error with Keyboard Collapsed

**Steps:**
1. Navigate to Search and type a query.
2. Disconnect PMS (or block network).
3. Wait for search error to surface (retry dialog or inline retry group).
4. Press **Right** if keyboard is still visible.
5. Verify error/retry elements are positioned correctly in the expanded layout.

**Expected:**
- Error messaging and retry elements respect the current layout state (collapsed or expanded keyboard).
- Dismissing the error and reconnecting PMS allows retry to work normally.

---

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Search with 0 results, toggle keyboard | Empty state repositions correctly both ways |
| Very long search query (fills label) | Query label doesn't overflow in either layout state |
| Single-library server, collections tap | Auto-select picks the only library, loads its collections |
| Server with no collections | Empty state shown (existing behavior), no crash |
| Rapid right-left-right toggling | No visual glitches or crashes — instant property changes are atomic |
