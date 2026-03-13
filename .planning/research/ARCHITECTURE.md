# Architecture Research

**Domain:** Roku SceneGraph / BrightScript Plex client — v1.1 Polish & Navigation
**Researched:** 2026-03-13
**Confidence:** HIGH (analysis of live codebase, no speculation)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MainScene (root)                              │
│  screenStack: []   focusStack: []   m.global.constants              │
├─────────────────────────────────────────────────────────────────────┤
│                       Screen Layer (push/pop)                        │
│  ┌───────────┐  ┌────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │HomeScreen │  │DetailScreen│  │EpisodeScreen│  │ SearchScreen │  │
│  │(sidebar + │  │(movie/ep   │  │(season list │  │(keyboard +   │  │
│  │ grid/hubs)│  │ detail)    │  │ + ep list)  │  │ PosterGrid)  │  │
│  └───────────┘  └────────────┘  └─────────────┘  └──────────────┘  │
│  ┌───────────┐  ┌────────────┐  ┌─────────────┐                     │
│  │Settings   │  │UserPicker  │  │Playlist     │                     │
│  │Screen     │  │Screen      │  │Screen       │                     │
│  └───────────┘  └────────────┘  └─────────────┘                     │
├─────────────────────────────────────────────────────────────────────┤
│                       Widget Layer (reusable)                        │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │PosterGrid│  │EpisodeItem │  │VideoPlayer│  │TrackSelectionPanel│ │
│  │(MarkupGrid│  │(MarkupList │  │(Video +  │  │(audio/subtitle)   │ │
│  │+GridItem)│  │ item comp) │  │ overlays)│  │                   │ │
│  └──────────┘  └────────────┘  └──────────┘  └────────────────────┘ │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐                         │
│  │Sidebar   │  │FilterBar   │  │AlphaNav  │                         │
│  └──────────┘  └────────────┘  └──────────┘                         │
├─────────────────────────────────────────────────────────────────────┤
│                        Task Layer (background HTTP)                  │
│  ┌──────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │PlexApiTask│  │PlexSearch  │  │PlexAuthTask  │  │PlexSession   │  │
│  │(general) │  │Task        │  │(PIN OAuth)   │  │Task (progress│  │
│  └──────────┘  └────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────┐                                                         │
│  │ServerConn│                                                         │
│  │ectionTask│                                                         │
│  └──────────┘                                                         │
├─────────────────────────────────────────────────────────────────────┤
│                       Persistence Layer                              │
│  roRegistrySection("SimPlex") — authToken, adminToken, serverUri,   │
│  serverClientId, activeUserName, deviceId, pinnedLibraries,         │
│  sidebarLibraries                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | v1.1 Status |
|-----------|----------------|-------------|
| `MainScene` | Screen stack (push/pop/clear), auth routing, server disconnect/reconnect, dialog owner | Stable — minor extension for new popScreen type checks |
| `HomeScreen` | Sidebar + hub rows + library grid (three-zone focus) | **Modified** — TV show tap routing change |
| `DetailScreen` | Movie/episode detail + playback buttons + watched state toggle | Stable |
| `EpisodeScreen` | Season list (LabelList) + episode list (MarkupList/EpisodeItem) + inline playback | **Modified** — overhaul target |
| `SearchScreen` | Keyboard (left) + PosterGrid results (right) — left/right focus split | **Modified** — layout fix |
| `PosterGrid` | MarkupGrid wrapper — pagination trigger, focus delegation | **Bug fix** — progress bar width |
| `PosterGridItem` | Poster + title + progress bar + unwatched badge | **Bug fix** — hardcoded 240 width |
| `EpisodeItem` | 16:9 thumbnail + title + summary + duration + progress + badge | Stable |
| `VideoPlayer` | Video node + skip intro/credits + auto-play overlay + track panel + session reporting | Stable |
| `SettingsScreen` | Auth, server discovery, library manager, user context | **Modified** — server switching simplified |
| `PlexApiTask` | All PMS and plex.tv HTTP | Stable |

---

## TV Show Navigation: Current State and Overhaul Target

### Current Flow (v1.0)

```
HomeScreen grid → itemSelected {action:"detail", itemType:"show"}
    → MainScene.showDetailScreen()
        → DetailScreen loads /library/metadata/{id}
        → buildButtons() sees type="show" → adds "Browse Seasons" button
        → user presses Browse Seasons → itemSelected {action:"episodes", ratingKey, title}
            → MainScene.showEpisodeScreen()
                → EpisodeScreen: LabelList seasons (top) + MarkupList episodes (below)
```

**Stack depth for TV show:** HomeScreen → DetailScreen → EpisodeScreen (3 levels)

**Problem:** DetailScreen is an unnecessary intermediate screen for TV shows. The "Browse Seasons" button is non-obvious for a TV remote — users expect: grid tap → season/episode screen → play. The extra hop adds friction and the detail screen layout (poster left, metadata right, buttons below) is designed for movies, not for shows with season structure.

### Overhaul Target (v1.1): Direct Navigation

From the grid, TV show taps go directly to EpisodeScreen. DetailScreen remains accessible via an "Info" action from within EpisodeScreen.

```
HomeScreen grid → itemSelected {action:"episodes", ratingKey, title}  [for shows]
    → MainScene.showEpisodeScreen(ratingKey, title)
        → EpisodeScreen: season selector + episode list
        → user can press * (options) → "Show Info" → pushes DetailScreen
```

**Stack depth for TV show:** HomeScreen → EpisodeScreen (2 levels, same as movies)

### Integration Requirements

**`HomeScreen.brs`:**
In `onGridItemSelected` and hub row selection handlers, the current logic fires `{action:"detail"}` for all item types. Change the type check so shows fire `{action:"episodes"}` instead:

```brightscript
' Current (v1.0):
m.top.itemSelected = {action: "detail", ratingKey: ratingKey, itemType: itemType}

' Target (v1.1) — add type branch:
if itemType = "show"
    m.top.itemSelected = {action: "episodes", ratingKey: ratingKey, title: title}
else
    m.top.itemSelected = {action: "detail", ratingKey: ratingKey, itemType: itemType}
end if
```

**`MainScene.brs`:**
`onItemSelected` already has the `action:"episodes"` branch routing to `showEpisodeScreen`. No change needed.

**`EpisodeScreen.brs`:**
Add options key handler that fires `{action:"detail", ratingKey: m.top.ratingKey, itemType:"show"}` for users who want the show metadata screen. This makes DetailScreen an optional destination, not a required step.

**Watch state propagation fix:**
EpisodeScreen should emit `m.global.watchStateUpdate` after playback completes (same structure DetailScreen uses). HomeScreen already observes this field. The payload should include the show's `ratingKey` (the `m.top.ratingKey` in EpisodeScreen) so HomeScreen can update the show poster's unwatched episode badge.

### Season/Episode Layout

Currently EpisodeScreen uses:
- `LabelList` — horizontal season tabs at top (numRows=1, items [200, 50])
- `MarkupList` — vertical full-width episode rows using `EpisodeItem`

The two-zone layout (tabs above, list below) is the right pattern and should be kept. The v1.1 work is layout polish: ensure the season list scrolls correctly if there are many seasons, add keyboard shortcut hints, and verify `EpisodeItem.brs` is correctly wired. The XML references `EpisodeItem.brs` via a `<script>` tag but the file must exist and have an `onItemContentChange` handler — verify this is in place.

---

## Search Layout Restructure

### Current Layout Problem

```
SearchScreen (1920x1080):
  Keyboard: translation="[80, 120]"   (~620px wide)
  PosterGrid: translation="[700, 200]", gridWidth="1140"
    → 6-column grid in 1140px = only 4 full columns fit (240px * 4 = 960, 5th clips)
  Focus: left key → keyboard, right key → grid
```

The `PosterGrid` is instantiated with `gridWidth="1140"` but PosterGrid.brs sets `numColumns = c.GRID_COLUMNS` (6). This means only ~4 full posters fit in the 1140px right zone. The `gridWidth` field exists in the PosterGrid interface but currently has no effect on column count — it is just stored, never read.

Additionally, search results flatten all Hub types (movies, shows, episodes, artists) into a single grid using the 240x360 portrait poster. Episodes appear with portrait frames for landscape thumbnails, which looks wrong.

### Recommended Fix (v1.1)

**Step 1 — Fix column count in search:** Make `PosterGrid.brs` read `gridWidth` and compute columns:

```brightscript
' In PosterGrid.brs onGridWidthChange() or in init():
availableWidth = m.top.gridWidth
columnWidth = c.POSTER_WIDTH + c.GRID_H_SPACING
m.grid.numColumns = Int(availableWidth / columnWidth)  ' = 4 for 1140px
```

This makes the 4-column layout intentional rather than accidental clipping.

**Step 2 — Keyboard collapse on grid focus:** When user moves right into the grid, hide the keyboard and expand the grid to full width:

```brightscript
' In SearchScreen.brs onKeyEvent:
else if key = "right" and m.focusOnKeyboard
    m.focusOnKeyboard = false
    m.keyboard.visible = false
    ' Reposition grid to full width
    m.resultsGrid.translation = [80, 160]
    m.top.findNode("searchQueryLabel").translation = [80, 80]
    m.resultsGrid.setFocus(true)
    return true
else if key = "left" and not m.focusOnKeyboard
    m.focusOnKeyboard = true
    m.keyboard.visible = true
    m.resultsGrid.translation = [700, 200]
    m.top.findNode("searchQueryLabel").translation = [700, 120]
    m.keyboard.setFocus(true)
    return true
```

Full-width grid (1760px) at 6 columns shows the same density as the library grid, which makes result browsing feel consistent.

**Step 3 — Search result type grouping (optional):** Rather than mixing all types into one flat grid, consider labeling sections ("Movies", "Shows") using a RowList or section headers. This is medium complexity and can be deferred if scope is tight.

---

## Thumbnail Aspect Ratio Changes

### Problem

`PosterGrid` and `PosterGridItem` hardcode 240x360 (2:3 portrait). This is correct for movies and TV shows. It fails for episodes (16:9) which appear pinched in portrait frames.

### Current Thumbnail Requests by Context

| Context | Requested Size | Ratio | Source |
|---------|---------------|-------|--------|
| Library grid (movies/shows) | 240x360 | 2:3 portrait | `PosterGridItem.brs` via `HDPosterUrl` |
| Episode list thumbnails | 320x180 | 16:9 landscape | `EpisodeScreen.brs` line 247 |
| Detail screen poster | 640x360 | 16:9 landscape | `DetailScreen.brs` line 172 |
| Search results (mixed) | 240x360 | 2:3 portrait (wrong for episodes) | `SearchScreen.brs` line 149 |

### Bug: Hardcoded Width in PosterGridItem

`PosterGridItem.brs` line 57 hardcodes:
```brightscript
m.progressFill.width = Int(240 * progress)
```

This should use the actual poster width from constants:
```brightscript
m.progressFill.width = Int(m.constants.POSTER_WIDTH * progress)
```

One-line fix, no dependencies.

### Aspect Ratio for v1.1 Scope

The `EpisodeItem` widget already uses 213x120 (16:9) thumbnails — this is the right place for episode thumbnails. The issue is that collections browsed through the library grid occasionally show up in search results with wrong ratios, and episodes should never appear in a portrait PosterGrid.

**For v1.1:** Fix the progress bar width bug. Ensure search results only show movies and shows (filter episodes and other types from `processSearchResults`), so the portrait grid issue is avoided rather than solved. A landscape `PosterGrid` variant is a future enhancement.

---

## Server Switching Architecture

### Current State

"Switch Server" appears in `SettingsScreen.brs` (index 4 in the settings list → `discoverServers()`). This function:
1. Fires `PlexApiTask` to `plex.tv/api/v2/resources`
2. Iterates servers and connections via `tryServerConnection()` / `onConnectionTestComplete()`
3. On success: calls `SetServerUri()` (writes registry) but does NOT update `m.global.serverUri`
4. Fires `m.top.authComplete = true` — which MainScene interprets as full re-auth complete → clears screen stack and shows home

**Bugs:**
- `m.global.serverUri` (if cached) is not updated after `SetServerUri()` in `onConnectionTestComplete`. Screens that use `GetServerUri()` (reads registry directly) are fine. Tasks that cache the URI during their init are not.
- The discovery logic in SettingsScreen (`discoverServers()`, `tryServerConnection()`, `onConnectionTestComplete()`) duplicates the logic in `MainScene.navigateToServerList()` / `MainScene.autoConnectToServer()`.
- Sequential connection testing (one at a time, fallback to next) is slow for a single-server use case.

### Fix Decision: Remove "Switch Server", Keep "Re-authenticate"

Since multi-server is explicitly out of scope (PROJECT.md), "Switch Server" is unnecessary complexity. The right user action for changing servers is to sign out and sign back in, which already works.

**Replace** SettingsScreen item index 4 ("Switch Server") with either:
- Nothing (remove from the menu), or
- "Re-authenticate" which calls `signOut()` and `requestPin()` — identical to signing out

This removes ~80 lines of duplicate discovery/connection logic from SettingsScreen and eliminates the stale `m.global.serverUri` bug.

**If keep for future:** The fix is to add a global update helper in utils.brs:
```brightscript
sub UpdateServerUri(uri as String)
    SetServerUri(uri)
    if m.global <> invalid
        m.global.serverUri = uri
    end if
end sub
```
And call this instead of `SetServerUri()` everywhere a new server URI is established.

---

## Watch State Propagation Gap

### Problem

When returning from EpisodeScreen (after watching episodes), HomeScreen's grid still shows old progress/watched state for the show poster. The `onWatchStateUpdate` observer in HomeScreen works for individual item updates (DetailScreen → HomeScreen path), but EpisodeScreen → HomeScreen is missing.

### Current Propagation Paths

| Source | Signal | Observer |
|--------|--------|----------|
| DetailScreen marks watched | `m.global.watchStateUpdate = {ratingKey, viewCount, viewOffset}` | HomeScreen.onWatchStateUpdate, EpisodeScreen.onWatchStateUpdate |
| EpisodeScreen playback ends | `loadEpisodes()` called — episode list refreshed | Nothing propagates to HomeScreen |
| EpisodeScreen options menu watched toggle | `m.episodeList.content = m.episodeList.content` (force re-render) | Nothing propagates to HomeScreen |

### Fix

After `onPlaybackComplete` in EpisodeScreen refreshes the episode list, it should also emit a watch state signal for the show itself. Since EpisodeScreen holds `m.top.ratingKey` (the show's ratingKey), it can emit:

```brightscript
' In EpisodeScreen.onPlaybackComplete(), after loadEpisodes():
watchUpdate = {
    ratingKey: m.top.ratingKey  ' show ratingKey
    viewCount: -1               ' -1 = "needs refresh", not a known value
    viewOffset: 0
}
m.global.watchStateUpdate = watchUpdate
```

HomeScreen's `onWatchStateUpdate` already scans its ContentNode grid by ratingKey and updates the matching item. The `-1` viewCount convention signals "re-fetch this item's data" vs an optimistic update. Alternatively, HomeScreen can simply reload the current library page when it returns to focus via a `onFocusChange` observer — simpler but causes a flash.

---

## Auto-Play Wiring Gap

### Problem (Known from PROJECT.md)

`grandparentRatingKey` is correctly passed to VideoPlayer from EpisodeScreen (line 416):
```brightscript
m.player.grandparentRatingKey = m.top.ratingKey  ' Show ratingKey
m.player.parentRatingKey = seasonKey             ' Season ratingKey
m.player.episodeIndex = episode.episodeNumber
m.player.seasonIndex = m.currentSeasonIndex
```

The gap is that when VideoPlayer auto-plays the next episode and fires `nextEpisodeStarted`, EpisodeScreen's `onNextEpisodeStarted` handler calls `loadEpisodes(currentSeason)` but does not check if the new episode is in the *next* season. If auto-play crosses a season boundary, the episode list shows the wrong season.

### Fix

VideoPlayer's `nextEpisodeStarted` field should carry metadata about the next episode:
```brightscript
' VideoPlayer should set:
m.top.nextEpisodeStarted = {
    ratingKey: nextEpisode.ratingKey
    seasonIndex: nextEpisode.seasonIndex  ' 0-based
    episodeIndex: nextEpisode.index
}
```

EpisodeScreen's `onNextEpisodeStarted` should update `m.currentSeasonIndex` and reload episodes if the season changed:
```brightscript
sub onNextEpisodeStarted(event as Object)
    data = event.getData()
    if data <> invalid and data.seasonIndex <> invalid
        if data.seasonIndex <> m.currentSeasonIndex
            m.currentSeasonIndex = data.seasonIndex
            m.seasonList.jumpToItem = data.seasonIndex
        end if
    end if
    ' Always refresh current season's episode list
    loadEpisodes(m.seasons[m.currentSeasonIndex].ratingKey)
end sub
```

---

## Codebase Cleanup: Orphaned and Brittle Patterns

### Orphaned Files

| File | Issue | Action |
|------|-------|--------|
| `source/normalizers.brs` | Functions defined (NormalizeMovieList, NormalizeShowList, etc.) but never called — all screens do inline JSON→ContentNode conversion | **Delete** |
| `source/capabilities.brs` | `ParseServerCapabilities()` defined but never called | **Delete** |

Both files were written during planning phase as forward-looking scaffolding. They contradict the actual pattern that evolved (inline normalization per screen). Leaving them in creates confusion about which pattern to follow. Delete them; if future phases need normalizers, reintroduce with a clear adoption plan.

### Brittle Patterns to Fix

**1. ratingKey type coercion — duplicated in 8+ locations**

Every screen repeats:
```brightscript
if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
    seasonKey = season.ratingKey
else
    seasonKey = season.ratingKey.ToStr()
end if
```

`DetailScreen.brs` already has this as a local function `getRatingKeyString()`. Promote it to `utils.brs` as `GetRatingKeyStr(key as Dynamic) as String` and replace all instances.

**2. Dead spinner code in every screen**

Every screen has:
```brightscript
' LoadingSpinner removed - BusySpinner causes firmware SIGSEGV crashes on Roku
m.loadingSpinner = invalid
```
...followed by guards like `if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true`.

These guards are dead code. Remove all spinner-related lines from all screens. If loading indication is needed in a future phase, use a safe approach (a Rectangle + opacity animation).

**3. Task creation pattern — new task per request**

Several screens create a new `PlexApiTask` node for every request:
```brightscript
task = CreateObject("roSGNode", "PlexApiTask")
task.endpoint = endpoint
task.observeField("status", "handler")
task.control = "run"
m.someTask = task
```

HomeScreen already uses the better pattern (single task created in `init()`, reused). The "create per request" pattern is not catastrophically wrong (SceneGraph GC handles it), but it creates memory churn on large libraries. For v1.1 cleanup, EpisodeScreen and SearchScreen are the highest-traffic screens and should be updated to use a single reused task.

**4. `showError()` vs `showErrorDialog()` inconsistency**

Several screens have both `showError(message)` (no buttons, just OK) and `showErrorDialog(title, message)` (Retry/Dismiss buttons). They're slightly different dialogs used in slightly different contexts. Consolidate into one pattern: always show Retry/Dismiss, remove the standalone `showError`.

---

## Data Flow

### TV Show Navigation Flow (after v1.1 overhaul)

```
User selects TV show in grid (HomeScreen)
    ↓
HomeScreen.onGridItemSelected:
    itemType = "show" → m.top.itemSelected = {action:"episodes", ratingKey, title}
    ↓
MainScene.onItemSelected → showEpisodeScreen(ratingKey, title)
    ↓
EpisodeScreen.onRatingKeyChange → loadSeasons(ratingKey)
    ↓ [PlexApiTask: /library/metadata/{id}/children]
EpisodeScreen.processSeasons() → LabelList populated → loadEpisodes(season[0].ratingKey)
    ↓ [PlexApiTask: /library/metadata/{seasonKey}/children]
EpisodeScreen.processEpisodes() → MarkupList populated via EpisodeItem
    ↓
User selects episode → showResumeDialog (if offset > 5%) or startPlayback()
    ↓
startPlayback() → VideoPlayer appended to scene root, setFocus, control="play"
    ↓
VideoPlayer.onPlaybackComplete → EpisodeScreen.onPlaybackComplete
    ↓
EpisodeScreen: loadEpisodes(currentSeason) + emit m.global.watchStateUpdate  [NEW]
    ↓
HomeScreen.onWatchStateUpdate → scan grid ContentNode, update show's badge/progress
```

### Search Flow (after v1.1 layout fix)

```
SearchScreen pushed → keyboard visible (left), PosterGrid (right, 4 cols)
    ↓
User types → onTextChange → debounceTimer → performSearch()
    ↓ [PlexSearchTask: /hubs/search?query=...]
processSearchResults():
    - flatten hub.Metadata (filter to movies + shows only, skip episodes/artists)
    - build ContentNode, set HDPosterUrl with 240x360 portrait dimensions
    ↓
PosterGrid.content set → 4-column grid in right zone
    ↓
User presses right key:
    m.focusOnKeyboard = false
    keyboard.visible = false
    resultsGrid repositioned to full width (1760px, 6 cols)
    resultsGrid.setFocus(true)
    ↓
User selects item → m.top.itemSelected = {action:"detail"|"episodes", ratingKey, itemType}
    ↓
MainScene routes to DetailScreen or EpisodeScreen based on itemType
```

### Watch State Global Signal Flow

```
DetailScreen / EpisodeScreen (after watched toggle or playback)
    ↓
m.global.watchStateUpdate = {ratingKey, viewCount, viewOffset}
    ↓
All active observers fire simultaneously:
  - HomeScreen.onWatchStateUpdate: scan grid ContentNode children by ratingKey, update
  - EpisodeScreen.onWatchStateUpdate: scan episodeList ContentNode children by ratingKey, update
```

---

## Component Boundaries: New vs Modified for v1.1

### New Components

None required. All v1.1 features integrate into existing components.

### Modified Components

| Component | Change Type | Description | Complexity |
|-----------|------------|-------------|------------|
| `HomeScreen.brs` | Routing logic | TV show taps → `{action:"episodes"}` instead of `{action:"detail"}` | XS — 5-line change |
| `EpisodeScreen.brs` | Feature + bug fix | Watch state emission, auto-play season boundary fix, options key "Info" action | M |
| `EpisodeScreen.xml` | Layout polish | Season list spacing, episode list visual improvements | S |
| `SearchScreen.brs` | Layout + filter | Keyboard collapse on grid focus, filter episodes from results | S-M |
| `SearchScreen.xml` | Layout | Coordinate adjustments if keyboard collapse is implemented | XS |
| `PosterGridItem.brs` | Bug fix | `Int(240 * progress)` → `Int(m.constants.POSTER_WIDTH * progress)` | XS — 1-line |
| `PosterGrid.brs` | Enhancement | Read `gridWidth` field to compute column count | XS |
| `SettingsScreen.brs` | Simplification | Remove "Switch Server" discovery flow (~80 lines) | S |
| `utils.brs` | Cleanup | Promote `getRatingKeyString` → `GetRatingKeyStr`, add `UpdateServerUri` if server switching kept | S |
| `MainScene.brs` | Minor | `popScreen` type string check — verify covers all screen subtypes | XS |
| `source/normalizers.brs` | Delete | Orphaned file | — |
| `source/capabilities.brs` | Delete | Orphaned file | — |

### Not Touched in v1.1

- `VideoPlayer.xml/.brs` — Auto-play fix is a data-passing change in EpisodeScreen. VideoPlayer's `nextEpisodeStarted` field already fires; the fix is to enrich its payload.
- `PlexApiTask.brs` — No changes needed.
- `DetailScreen.xml/.brs` — Still used for movies and episode detail. No structural changes.
- `Sidebar`, `FilterBar`, `AlphaNav`, `TrackSelectionPanel` — v1.1 does not touch these.
- `PlexSessionTask`, `PlexAuthTask`, `ServerConnectionTask` — No changes.

---

## Suggested Build Order

Build in dependency order to avoid blocked work:

**1. utils.brs cleanup** (no dependencies)
- Promote `GetRatingKeyStr()` helper
- Remove dead spinner-related code from utils.brs if any

**2. Delete orphaned files** (no dependencies)
- Remove `normalizers.brs`, `capabilities.brs`

**3. PosterGridItem progress bar bug fix** (no dependencies)
- One-line change — do early to avoid merge conflicts

**4. SettingsScreen server switching removal** (no dependencies)
- Isolated change — remove "Switch Server" and discovery logic from SettingsScreen

**5. Watch state propagation fix in EpisodeScreen** (depends on: utils.brs cleanup)
- Add `m.global.watchStateUpdate` emission after playback and watched state toggle
- HomeScreen already has the observer in place — this just wires the source

**6. TV show direct navigation — HomeScreen tap routing** (depends on: watch state fix)
- Change show tap from `{action:"detail"}` to `{action:"episodes"}`
- Watch state must be in place so HomeScreen updates properly when EpisodeScreen pops

**7. EpisodeScreen overhaul** (depends on: direct navigation in place)
- Layout improvements, "Info" options key action, auto-play season fix
- Do after direct navigation so EpisodeScreen is being actively exercised as the entry point

**8. Search layout fix** (independent — can be done at any point after utils.brs)
- Keyboard collapse, column count fix, episode type filtering

**9. Branding / assets** (independent — no code dependencies)
- Icon/splash gradient, font changes, manifest version bump

**10. Documentation** (do last — after code is stable)
- User guide and developer/architecture docs for GitHub publish

---

## Anti-Patterns to Avoid in v1.1

### Anti-Pattern 1: Replacing MarkupList with Custom Scrolling

**What people do:** Build a custom scrollable container because MarkupList "feels limiting."
**Why it's wrong:** Custom scrolling on Roku's render thread is jittery and brittle. BusySpinner proved that deviating from built-in components causes firmware crashes (SIGSEGV).
**Do this instead:** Use `MarkupList` for episodes, `MarkupGrid` for grids. Customize via `itemComponentName`.

### Anti-Pattern 2: Moving HTTP Calls to the Render Thread

**What people do:** Call `roUrlTransfer` synchronously in a BRS callback to "simplify" code.
**Why it's wrong:** Causes rendezvous crashes. This is a hard platform constraint.
**Do this instead:** Always use a Task node. PlexApiTask handles all cases.

### Anti-Pattern 3: Proliferating m.global Signals

**What people do:** Add new global signals for every cross-screen communication need (e.g., `m.global.episodeWatched`, `m.global.seasonChanged`).
**Why it's wrong:** Global signals fire on all screens simultaneously, including hidden/stale screens still in the stack. Too many global observers create performance issues and debugging nightmares.
**Do this instead:** Use the existing `watchStateUpdate` signal for watch state. For other coordination, pass data via screen interface fields before navigation.

### Anti-Pattern 4: Rebuilding ContentNode Tree on Every Watch State Change

**What people do:** On `onWatchStateUpdate`, call the API to re-fetch the library page and rebuild the entire grid ContentNode.
**Why it's wrong:** Network round-trip + full grid flash. Destroys the "instant feedback" feel.
**Do this instead:** Scan children by `ratingKey`, mutate only the matching child's fields in-place. MarkupGrid re-renders only the changed item. This is the existing pattern — keep it.

---

## Integration Points

### External Service: Plex Media Server

| Endpoint | Used By | Notes |
|----------|---------|-------|
| `/library/metadata/{id}` | DetailScreen | Movie/episode/show metadata |
| `/library/metadata/{id}/children` | EpisodeScreen | Seasons (children of show), episodes (children of season) |
| `/hubs/search?query=` | SearchScreen | Returns Hub array — flatten Metadata for grid |
| `/:/scrobble`, `/:/unscrobble` | DetailScreen, EpisodeScreen | Watched state toggle; fire-and-forget |
| `plex.tv/api/v2/resources` | MainScene, SettingsScreen | Server discovery — remove from SettingsScreen in v1.1 |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Screen → MainScene (navigate forward) | `m.top.itemSelected = {action, ratingKey, ...}` | Standard pattern, stable |
| Screen → MainScene (navigate back) | `m.top.navigateBack = true` | Standard pattern, stable |
| Screen → Screen (watch state) | `m.global.watchStateUpdate = {ratingKey, viewCount, viewOffset}` | Fires on all screens; keep payload minimal |
| Task → Screen | `task.observeField("status", "handler")` | Standard async pattern |
| SettingsScreen → MainScene (user switch) | `m.top.itemSelected = {action:"switchUser"}` | Routed via MainScene.onItemSelected |
| SettingsScreen → MainScene (auth complete) | `m.top.authComplete = true` | Triggers clearScreenStack + showHomeScreen |
| SettingsScreen → MainScene (server switch BUG) | `m.top.authComplete = true` after server test | Triggers full auth flow — this is the server-switch bug (correct behavior after fix is removal) |

---

## Sources

- Live codebase analysis: `SimPlex/components/screens/`, `SimPlex/components/widgets/`, `SimPlex/source/` — HIGH confidence
- `.planning/PROJECT.md` — v1.1 target features and known issues — HIGH confidence
- `CLAUDE.md` — architecture constraints and platform rules — HIGH confidence

---

*Architecture research for: SimPlex v1.1 Polish & Navigation*
*Researched: 2026-03-13*
