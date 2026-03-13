# Pitfalls Research

**Domain:** Roku/BrightScript Plex client — v1.1 Polish & Navigation milestone
**Researched:** 2026-03-13
**Confidence:** HIGH (all findings grounded in existing codebase, known firmware behavior, and Roku platform constraints)

---

## Critical Pitfalls

### Pitfall 1: EpisodeScreen Navigation Refactor Severs VideoPlayer Context Fields

**What goes wrong:**
`EpisodeScreen` already implements a combined season/episode screen. If the refactor splits it into separate Season and Episode screens pushed onto the stack, the VideoPlayer launch in `startPlayback()` stops receiving the five context fields it needs: `grandparentRatingKey`, `parentRatingKey`, `episodeIndex`, `seasonIndex`, and `mediaKey`. Auto-play next episode silently stops working — `onNextEpisodeStarted` fires but the wrong season reloads, or auto-play does nothing.

**Why it happens:**
The EpisodeScreen holds `m.seasons`, `m.currentSeasonIndex`, and `m.top.ratingKey` (the show's ratingKey) all in one component. A new SeasonScreen sitting between HomeScreen and EpisodeScreen would own the season array but not the episode list, creating a boundary that severs the season-to-VideoPlayer context chain. The existing `startPlayback()` at EpisodeScreen.brs line 408 depends on `m.seasons` and `m.currentSeasonIndex` being in scope.

**How to avoid:**
Audit whether three separate screens are necessary before committing to the structure. If EpisodeScreen can be enhanced in-place (larger season list, season artwork column), prefer that over splitting. If splitting is required, the screen that launches the VideoPlayer must own or receive all five context fields. After refactoring, run a focused test: play episode from season 2, let auto-play fire, verify it advances within season 2 and not season 1.

**Warning signs:**
- Auto-play next episode fires but jumps back to season 1 episode 1
- `VideoPlayer.grandparentRatingKey` is `""` or `"0"` after the refactor
- `nextEpisodeStarted` event fires but `loadEpisodes` reloads the wrong season

**Phase to address:** TV Show Navigation Overhaul

---

### Pitfall 2: Focus Recovery After VideoPlayer Closure Breaks Under Navigation Refactor

**What goes wrong:**
`VideoPlayer` is appended directly to the scene root (`m.top.getScene().appendChild(m.player)`) — it bypasses the `pushScreen`/`popScreen` focus stack entirely. After playback, `onPlaybackComplete` calls `m.episodeList.setFocus(true)`. If a SeasonScreen is added as a proper stack entry and EpisodeScreen is popped before VideoPlayer completes, then `m.episodeList` is already removed from the scene when the callback fires. `setFocus(true)` on a detached node is a silent no-op — the user has no focus.

**Why it happens:**
The VideoPlayer lifecycle is outside the screen stack. Any navigation refactor that changes which screen owns the episode list invalidates the hardcoded focus restore target in `onPlaybackComplete`.

**How to avoid:**
Keep the VideoPlayer lifecycle independent of the screen stack (append to scene root, remove on complete). After playback, focus must be restored to whatever the current top-of-stack screen considers its "default focus target" via `getCurrentScreen().setFocus(true)`, not to a specific node that may no longer be in scope. Alternatively, have each screen implement a `restoreFocus()` callFunc that MainScene invokes after VideoPlayer removes itself.

**Warning signs:**
- Back button after playback does nothing (no focused component)
- Remote buttons unresponsive after returning from video
- Debug console shows focus set to a node that returns `invalid` from `findNode`

**Phase to address:** TV Show Navigation Overhaul

---

### Pitfall 3: Watch State Propagation Does Not Reach Hub Rows

**What goes wrong:**
`m.global.watchStateUpdate` propagates from DetailScreen. `HomeScreen.onWatchStateUpdate` exists but only patches the poster grid ContentNodes. Hub row ContentNodes (the RowList populated by `loadHubs`) are a separate ContentNode tree and are not walked by the current handler. After marking an episode watched in DetailScreen and returning to HomeScreen, "Continue Watching" still shows the episode and the progress bar is still visible on its hub row poster.

**Why it happens:**
Hub rows are loaded into a dynamically-created RowList whose content is built in `processHubs()`. The poster grid and the hub RowList are two separate ContentNode trees. `onWatchStateUpdate` was written to patch the poster grid. Extending it to walk the hub RowList requires iterating `m.hubRowList.content` children and their children, which is a different tree shape.

**How to avoid:**
Fix watch state propagation before adding more navigation depth. The hub row walker needs to: (1) iterate each hub row ContentNode, (2) for each row, iterate its child ContentNodes, (3) match on `ratingKey`, (4) update `viewCount`, `viewOffset`, and `watched` fields. Add a test: mark watched in Detail; return to Home; "Continue Watching" hub must not show that item (either removed or shows watched badge).

**Warning signs:**
- "Continue Watching" shows a just-finished episode
- Progress bar persists on hub row poster after watching from Detail
- On Deck shows an episode that was marked watched

**Phase to address:** Bug Fixes — Watch State Propagation

---

### Pitfall 4: Collections Handler Dispatch Mismatch Sends Users to Wrong Screen

**What goes wrong:**
When a collection is selected from the poster grid, `HomeScreen.onGridItemSelected` fires. If `itemType` is `"collection"`, MainScene routes it to `showDetailScreen`. DetailScreen's `buildButtons()` only explicitly handles `item.type = "show"` — everything else falls to the movie/episode branch which shows "Play" (not "Browse Collection"). Collections are not playable; pressing "Play" on a collection causes an error or sends `mediaKey` for a collection ratingKey to VideoPlayer, which fails.

**Why it happens:**
The Plex API returns `type: "collection"` for collection items, but `buildButtons()` in DetailScreen has no branch for it. The `browseSeasons` action path only fires for `type = "show"`. There is no `browseCollection` action defined in either DetailScreen or MainScene.

**How to avoid:**
Add an explicit `type = "collection"` branch in `buildButtons()` showing a "Browse Collection" button with `action: "browseCollection"`. Add a handler in MainScene `onItemSelected` for `action: "browseCollection"` that calls `showHomeScreen()` in collection mode by passing `collectionRatingKey`. HomeScreen already has `m.isCollectionsView` and `m.collectionRatingKey` — wire them from the navigation action. Verify the full loop: Home → collection item → Detail → "Browse Collection" → collection contents → item Detail.

**Warning signs:**
- Selecting a collection shows "Play" as the only action button
- "Play" on a collection causes a VideoPlayer error
- `isCollectionsView` never evaluates to `true` via navigation

**Phase to address:** Bug Fixes — Collections Handler

---

### Pitfall 5: Search Grid Shows Stretched Episode Thumbnails Alongside Portrait Posters

**What goes wrong:**
Search results mix movies (2:3 portrait), TV shows (2:3 portrait), and episodes (16:9 landscape) in a single MarkupGrid with `itemSize: [240, 360]`. Episode `thumb` values are built with `BuildPosterUrl(item.thumb, 320, 180)` in `processSearchResults()` but assigned to `HDPosterUrl` on a 240x360 cell. The Roku image scaler stretches the 16:9 thumbnail to fill the 2:3 cell, producing distorted episode thumbnails.

**Why it happens:**
`processSearchResults()` in SearchScreen.brs line 149 builds all posters with `c.POSTER_WIDTH, c.POSTER_HEIGHT` (240x360) regardless of item type. Episode thumbnails are inherently landscape. The grid itemSize assumes portrait.

**How to avoid:**
For search result items where `item.type = "episode"`, use `item.parentThumb` (the parent show's poster, portrait art) instead of `item.thumb`. If `parentThumb` is absent, fall back to `thumb` at portrait dimensions and accept letterboxing. The Plex API search response always includes `parentThumb` for episode results — use `hub.Metadata[i].parentThumb`. This eliminates the ratio mismatch without changing grid layout.

**Warning signs:**
- Episode results in search appear taller than wide but distorted
- Movie and show results look correct but episode results look squashed
- Different item rows in the search grid have visually inconsistent poster sizes

**Phase to address:** Bug Fixes — Search Layout

---

### Pitfall 6: Deleting Orphaned BRS Files Crashes the Channel If Any XML Still References Them

**What goes wrong:**
Deleting `normalizers.brs` or `capabilities.brs` (documented orphans in PROJECT.md) causes a black screen on next launch if any `.xml` component still has `<script type="text/brightscript" uri="pkg:/source/normalizers.brs" />`. BrightScript compile errors on Roku do not produce a BrightScript stack trace — the channel simply fails to start with "compile error: file not found" in the debug console.

**Why it happens:**
SceneGraph XML components reference `.brs` source files via `<script>` tags. These are checked at compile time. Removing a file without removing all its XML references is a hard compile failure. The error is easy to miss if the developer does not check the debug console after the sideload.

**How to avoid:**
Before deleting any `.brs` file: (1) search all `.xml` files for the filename, (2) search all `.brs` files for any function names defined in the target file. Delete only after confirming zero references. After deletion, do a full sideload and check the debug console on port 8085 for compile errors before proceeding. Treat each file deletion as a separate deploy-test cycle.

**Warning signs:**
- Channel shows black screen immediately on launch after cleanup
- Debug console (port 8085) shows "compile error" or "file not found"
- No BrightScript error — pure compilation failure

**Phase to address:** Codebase Cleanup

---

### Pitfall 7: Removing Server Switching Requires Touching Four Codepaths Simultaneously

**What goes wrong:**
Server switching logic is distributed across four places: (1) `MainScene.navigateToServerList()` called from the disconnect dialog, (2) `onDisconnectDialogButton` index 1 routing, (3) `onPINScreenState` in MainScene when `servers.count() > 1` (after initial auth), (4) `PINScreen.brs` own post-auth routing. If server switching is removed by deleting `ServerListScreen` without patching all four paths, any path that previously routed to `ServerListScreen` either crashes (calls a missing `showServerListScreen` sub) or silently fails to navigate.

**Why it happens:**
There is no single "server switching module." The logic is woven into auth flow, disconnect recovery, and PINScreen state management. It looks removable by deleting the screen, but the call sites remain.

**How to avoid:**
Removal sequence: (1) patch `onPINScreenState` to auto-connect to `servers[0]` regardless of count (log a warning if count > 1 but proceed), (2) replace the "Server List" button in the disconnect dialog with "Sign Out" or remove it, (3) delete `showServerListScreen` and `navigateToServerList` subs, (4) delete `ServerListScreen.xml/.brs`. Only delete the screen after all call sites are patched. Do a full auth flow test with a plex.tv account that has two registered servers.

**Warning signs:**
- Auth flow crashes immediately after authenticating with a multi-server plex.tv account
- "Server List" button in disconnect dialog routes to blank screen
- `showServerListScreen` call appears in a file after the sub is deleted

**Phase to address:** Server Switching — Fix or Remove

---

### Pitfall 8: BusySpinner SIGSEGV Root Cause Is Still Unconfirmed

**What goes wrong:**
The UAT debug context documents an active firmware crash: `BusySpinner` (or its associated fade animations) causes SIGSEGV signal 11 on the test Roku. All production screens already have `m.loadingSpinner = invalid` with comments. However, `LoadingSpinner.xml/.brs` still exists. TEST4b (fade animations, no spinner) was pending at the time of the v1.0 close. If either BusySpinner or animated Group nodes are re-added to any v1.1 screen without resolving the root cause, that screen will SIGSEGV within 3-5 seconds of init.

**Why it happens:**
Roku firmware has known stability issues with `BusySpinner` on certain firmware versions and with animated SceneGraph Group nodes that use `Animation` nodes containing `Vector2DFieldInterpolator`. The exact trigger is not yet pinned.

**How to avoid:**
Do not add `BusySpinner` or `Animation` nodes to any screen in v1.1 until the root cause is confirmed. For loading feedback, use a static `Label` with text toggled visible/invisible — zero crash risk. If animation is desired, use a `Timer` node that cycles a label through "Loading.", "Loading..", "Loading..." text states. The crash is blocking and must be resolved in the first v1.1 phase before any other screen work.

**Warning signs:**
- SIGSEGV signal 11 in debug console (not a BrightScript error — native firmware crash)
- Crash occurs 3-5 seconds after screen init, not immediately
- Crash does not produce a BrightScript stack trace; channel silently exits

**Phase to address:** Must be resolved in Phase 1 before all other screen work

---

### Pitfall 9: Auto-Play Wiring Gap Remains in DetailScreen Even Though EpisodeScreen Was Fixed

**What goes wrong:**
PROJECT.md documents the auto-play gap as a known issue. Checking the code: `EpisodeScreen.startPlayback()` now sets all five VideoPlayer context fields (line 416–432, fix already present). However, `DetailScreen.startPlayback()` sets only `ratingKey`, `mediaKey`, `startOffset`, and `itemTitle`. When an episode is played from DetailScreen (e.g., via "Go to Details" from EpisodeScreen's resume dialog, or via direct DetailScreen navigation for an episode ratingKey), VideoPlayer receives no `grandparentRatingKey` and auto-play cannot find the next episode.

**Why it happens:**
DetailScreen handles both movies and episodes with the same `startPlayback()` sub. Movies don't need parent/grandparent context. The episode-specific context was never added to DetailScreen, only to EpisodeScreen.

**How to avoid:**
In `DetailScreen.startPlayback()`, check `m.itemData.type`. If `"episode"`, populate `grandparentRatingKey` from `m.itemData.grandparentRatingKey`, `parentRatingKey` from `m.itemData.parentRatingKey`, `episodeIndex` from `m.itemData.index`, and `seasonIndex` by fetching the season's index from `m.itemData.parentIndex`. The metadata response already includes these fields — they just need to be passed forward. Verify by playing an episode from DetailScreen and checking that auto-play advances correctly.

**Warning signs:**
- Auto-play works when playing from EpisodeScreen but not from DetailScreen
- `onNextEpisodeStarted` never fires after playing from DetailScreen
- VideoPlayer `grandparentRatingKey` field is `""` when launched from Detail

**Phase to address:** Bug Fixes — Auto-Play Wiring

---

### Pitfall 10: Icon/Splash Branding Requires All Four Variants Updated Simultaneously

**What goes wrong:**
The manifest references four icon files: `icon_focus_fhd.png` (540x405), `icon_side_fhd.png` (248x140), `icon_focus_hd.png` (336x240), `icon_side_hd.png` (210x120). The splash is `splash_fhd.jpg` (must be exactly 1920x1080). If only the FHD variants are updated and the HD variants are left unchanged, the Roku home screen shows mismatched branding — old icon on HD-resolution Roku devices, new icon on FHD. Even for a sideloaded channel, the home screen pulls the appropriate resolution variant automatically.

**Why it happens:**
FHD is the target development resolution so FHD icons are naturally updated first. HD variants are easy to forget because no dev testing is done on HD displays. The Roku firmware silently falls back to HD icons when FHD is not found — or vice versa — making the mismatch non-obvious until tested on a different device.

**How to avoid:**
Export all four icon sizes from the same source file in a single pass every time branding changes. Use a single Figma/Sketch/Inkscape source file with named export presets for all four sizes. Splash must be exactly 1920x1080 JPEG — verify pixel dimensions before sideloading. After any branding change, test on the actual Roku device and view the home screen channel tile.

**Warning signs:**
- Channel icon looks different on the test TV vs. another Roku in the house
- Icon appears blurry or wrong aspect ratio on the Roku home screen tile
- Splash shows black bars, crops, or stretching artifacts on first load

**Phase to address:** App Branding

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `ratingKey` type-coercion repeated in every screen (6+ identical blocks) | Defensive; works regardless of API return type | Any change to the pattern requires 6+ edits; `getRatingKeyString()` already exists in `DetailScreen.brs` but is not shared | Extract to `utils.brs` — one refactor, done |
| Duplicate `showErrorDialog`/`showInlineRetry` in every screen | Each screen self-contained | Same ~40-line block in 6+ screens; fixing a dialog bug requires 6 changes | Acceptable for v1.1; extract to shared utility in v1.2 |
| `BuildPosterUrl` reads registry on every call | No setup needed | 2 registry reads per image URL; on a 300-item grid that's 600 registry reads per load | Cache `serverUri` and `authToken` at screen init; pass as parameters |
| Task nodes created but never explicitly released | Simple; Roku handles GC | Task node count grows during paginated browsing; potential memory pressure on low-RAM devices (Roku Express: 256MB) | Acceptable for short-lived tasks; add explicit cleanup for pagination tasks |
| `m.global.watchStateUpdate` as a single shared event | Simple propagation | Does not reach hub row ContentNode trees; any observer fires on every update regardless of relevance | Fix hub row coverage before adding more navigation depth |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Plex API — Collections | Routing `type: "collection"` to DetailScreen and expecting play buttons | Add explicit `type = "collection"` branch in `buildButtons()`; show "Browse Collection" routed to collection contents endpoint |
| Plex API — Search results | Using `item.thumb` for episodes produces 16:9 thumbnails in a 2:3 grid | Use `item.parentThumb` for `type: "episode"` search results to get the parent show's portrait poster |
| Plex API — Episode metadata | Assuming `grandparentRatingKey` is always present | Check for `invalid` before use; some library configurations omit it. Fall back to re-fetching the show via `/library/metadata/{parentRatingKey}` |
| Roku manifest — Icon filenames | Renaming icon files without updating manifest paths | Manifest hardcodes exact filenames; always update manifest and image file together |
| roRegistrySection — Sign-out gaps | `ClearAuthData()` deletes a fixed list of keys; new keys added in v1.1 are not in that list | Maintain a canonical key list or use `deleteSection()` as the nuclear option |
| GitHub publish — HAR files | `plex.owlfarm.ad.har` is in the untracked files list; HAR files contain full HTTP sessions including auth tokens | Add `*.har` to `.gitignore` before first push; never commit HAR files |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Season navigation fires `loadEpisodes` on every focus event | Network spam when arrowing through seasons; brief grid flicker | Guard exists (`index <> m.currentSeasonIndex`) — do not remove this guard during refactor | With 10+ seasons and rapid navigation, 10+ in-flight requests stack up |
| `m.episodeList.content = m.episodeList.content` to force re-render | Visible flash on episode list update for watched state toggle | Update individual ContentNode child directly; MarkupList observes child field changes | Visible flash on 20+ episode lists; cascades if called multiple times |
| `BuildPosterUrl` reads registry per call | Slow grid initial load; noticeable on Roku Express | Cache `serverUri` and `authToken` in `m` at screen init | Noticeable on grids > 100 items on devices with slow flash storage |
| Observer accumulation on global fields | Callbacks fire for all screens in stack, not just the top screen | Unobserve global fields when screen is hidden; re-observe when focused | Hard to detect; symptom is multiple screens updating on a single watchStateUpdate |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Auth token visible in poster image URLs in debug logs | If anyone reads the Roku debug console output (port 8085), auth tokens in poster URLs expose credentials | Never log full `BuildPosterUrl` results; log only the path without query string |
| `LogEvent` calls left in production code | Auth headers and server URIs may appear in debug logs accessible to anyone on the local network | Audit all `LogEvent` calls before GitHub publish; remove or conditionalize verbose logging |
| `plex.owlfarm.ad.har` committed to GitHub | HAR files contain full HTTP request/response logs including X-Plex-Token values for every request captured during the session | Add `*.har` to `.gitignore` immediately; if already tracked, use `git rm --cached` |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Season list shows only one horizontal row (LabelList `numRows="1"`) | For shows with 10+ seasons, user must scroll horizontally with no count indicator | Add season count label; consider showing all seasons in a scrollable list with the count visible |
| Auto-play countdown fires while user is actively browsing episode list | User is startled by sudden playback beginning while navigating | Auto-play countdown must cancel immediately on any key press or focus move to episode list |
| "Mark as Watched" optimistic update allows double-tap race condition | Two toggles in flight produce final state opposite of intent | Disable button (or set flag) during in-flight API call; re-enable in `onWatchedStateChange` |
| Episode thumbnails in search (16:9) distort the grid layout | Visual inconsistency makes search results look broken for TV shows | Use `parentThumb` for episode search results — portrait poster gives consistent grid |

---

## "Looks Done But Isn't" Checklist

- [ ] **TV show navigation:** Episode playback from BOTH `EpisodeScreen` AND `DetailScreen` passes all five VideoPlayer context fields — `grandparentRatingKey`, `parentRatingKey`, `episodeIndex`, `seasonIndex` are non-empty for every episode play path
- [ ] **Auto-play next episode:** Works correctly after playing from EpisodeScreen; also works after playing from DetailScreen via "Go to Details" path
- [ ] **Collections fix:** Selecting a collection from BOTH HomeScreen poster grid AND SearchScreen routes to collection contents — verify both entry points
- [ ] **Watch state propagation:** Mark watched in DetailScreen; return to HomeScreen; "Continue Watching" hub row must not show that item (hub row ContentNodes must be walked, not just the poster grid)
- [ ] **Server switching removal:** Full auth flow tested with a plex.tv account that has multiple servers registered — flow completes without crash or hang
- [ ] **BusySpinner crash:** Root cause confirmed (BusySpinner vs. Animation nodes); any new screens in v1.1 use safe loading feedback pattern (Label toggle, not BusySpinner)
- [ ] **Branding update:** All four icon variants updated and verified on actual Roku hardware home screen; splash exactly 1920x1080
- [ ] **File deletion cleanup:** Full sideload test after EACH file deletion; debug console checked for compile errors before proceeding to next deletion
- [ ] **GitHub publish:** `*.har` in `.gitignore`; no auth tokens in any committed file; `LogEvent` calls audited for credential leakage

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Broken `<script>` reference after file deletion | LOW | Re-add deleted file or remove XML reference; sideload to confirm; re-delete correctly |
| Focus permanently lost after navigation refactor | MEDIUM | Add `LogEvent` to all `onFocusChange` observers; trace focus chain; revert last focus-related change; re-apply incrementally |
| Auto-play broken by navigation refactor | MEDIUM | Log all VideoPlayer fields at `control = "play"` time; compare pre/post refactor to identify which context field is now missing |
| SIGSEGV from adding new component | HIGH | Revert to last known-good state; use bisection pattern from UAT debug context (TEST1→TEST2→etc.); test one new SceneGraph node type at a time |
| Collections dispatch loop | LOW | Add `LogEvent` to `onItemSelected` in MainScene; log `data.action` and `data.itemType` for every selection; trace the full dispatch chain |
| HAR file accidentally committed | HIGH | Before repo is public: `git filter-repo` to remove from history; rotate exposed auth token via plex.tv account settings immediately |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| VideoPlayer context severed by navigation refactor | TV Show Navigation Overhaul | Auto-play fires correctly from all episode play entry points |
| Focus lost after playback closure | TV Show Navigation Overhaul | Back from player restores focus to last-focused episode; remote buttons respond |
| Watch state not propagating to hub rows | Bug Fixes — Watch State | Mark watched in Detail; "Continue Watching" hub row removes item on return to Home |
| Collections handler dispatch mismatch | Bug Fixes — Collections | Collections accessible from both HomeScreen grid and SearchScreen |
| Search grid mixed aspect ratios | Bug Fixes — Search Layout | Episode results in search show portrait posters, not stretched thumbnails |
| Orphaned file deletion crashes compile | Codebase Cleanup | Sideload test after each deletion; zero compile errors in debug console |
| Server switching partial removal | Server Switching Phase | Full auth flow with multi-server account completes without crash |
| Icon/splash variant mismatch | App Branding | All four icon variants visually correct on actual Roku home screen |
| BusySpinner SIGSEGV unresolved | Phase 1 — must precede all other work | 10-minute session with no SIGSEGV in any screen |
| Auto-play gap in DetailScreen | Bug Fixes — Auto-Play | Episode played from DetailScreen auto-plays next episode correctly |
| HAR file in repo | Documentation / GitHub Phase | `*.har` in `.gitignore`; `git status` shows no HAR files tracked |

---

## Sources

- Direct codebase analysis: `EpisodeScreen.brs`, `DetailScreen.brs`, `MainScene.brs`, `SearchScreen.brs`, `VideoPlayer.brs`, `utils.brs`, `constants.brs`, `HomeScreen.brs`, `PosterGrid.brs`, all `.xml` layouts
- `.planning/PROJECT.md` — documented known gaps (auto-play wiring, watch state propagation, orphaned files, collections bug)
- `.planning/UAT-DEBUG-CONTEXT.md` — BusySpinner SIGSEGV active investigation, bisection results (TEST4b pending), crash characteristics
- Roku SceneGraph documentation — focus chain behavior, `BusySpinner` instability notes, `Animation` node constraints
- Plex API field reference — `parentThumb` vs. `thumb` for search results, collection endpoint structure, episode metadata fields

---
*Pitfalls research for: SimPlex v1.1 Polish & Navigation — Roku/BrightScript Plex client*
*Researched: 2026-03-13*
