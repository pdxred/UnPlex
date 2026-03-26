# UnPlex Architecture

This document describes the internal architecture of UnPlex — a Roku BrightScript application built on the SceneGraph framework. It covers the layer model, threading, navigation, data flow, and key design patterns that shape the codebase.

## System Overview

UnPlex follows a layered component architecture. All UI is built with Roku SceneGraph XML components backed by BrightScript logic. All network I/O runs in background Task nodes to avoid blocking the render thread.

```
┌─────────────────────────────────────────────────────────┐
│                    Roku SceneGraph                       │
│   ┌───────────────────────────────────────────────────┐ │
│   │              MainScene (Root)                     │ │
│   │   Screen stack · Auth routing · Global state      │ │
│   ├───────────────────────────────────────────────────┤ │
│   │               Screens (10)                        │ │
│   │   HomeScreen · DetailScreen · ShowScreen           │ │
│   │   SearchScreen · PINScreen · SettingsScreen ...   │ │
│   ├───────────────────────────────────────────────────┤ │
│   │               Widgets (15)                        │ │
│   │   PosterGrid · Sidebar · VideoPlayer              │ │
│   │   FilterBar · AlphaNav · TrackPanel ...           │ │
│   ├───────────────────────────────────────────────────┤ │
│   │             Task Nodes (5)                        │ │
│   │   PlexApiTask · PlexAuthTask · PlexSearchTask     │ │
│   │   PlexSessionTask · ServerConnectionTask          │ │
│   └───────────────────────────────────────────────────┘ │
│                         │                               │
│                    HTTP(S) / JSON                        │
│                         ▼                               │
│              ┌─────────────────────┐                    │
│              │  Plex Media Server  │                    │
│              │  + plex.tv API      │                    │
│              └─────────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

**Utilities** (`source/*.brs`) are shared across all layers via `<script>` includes in each component's XML file. They provide auth storage, URL construction, Plex header generation, JSON-to-ContentNode normalization, and logging.

## Screen Stack

MainScene manages navigation through an array-based screen stack. Each screen is a SceneGraph `Group` node that represents a full-screen view.

### Push / Pop Navigation

```
Push: screenStack.push(newScreen) → set focus to newScreen
Pop:  screenStack.pop()           → restore focus to previous screen
```

- **Push** happens when the user navigates deeper (e.g., library → detail → playback). MainScene creates the target screen node, attaches field observers for events like `itemSelected` and `navigateBack`, pushes it onto the stack, and sets focus.
- **Pop** happens when the user presses **Back**. MainScene removes the topmost screen and restores focus to the previous screen's last focused child element.

### Focus Preservation

Each screen tracks its own focus state. When a screen regains focus after a pop, it restores focus to the previously focused child — typically the grid item or list row the user was on before drilling in. This is handled in each screen's `onFocusChange()` callback.

The Sidebar preserves scroll position across focus transitions — `setFocus(true)` alone restores focus to the previously-focused item without resetting `jumpToItem`. After item deletion, grids set `jumpToItem` to the adjacent item index (same position, or last item if the deleted one was at the end).

### Key Event Routing

Remote control input flows through the SceneGraph focus chain. Each component can implement `onKeyEvent(key, press)` and return `true` to consume the event or `false` to let it bubble up. MainScene handles the **Back** key at the top level to pop the screen stack.

Key strings: `"OK"`, `"back"`, `"left"`, `"right"`, `"up"`, `"down"`, `"play"`, `"pause"`, `"options"`

## Task Threading Model

**All HTTP requests must run in Task nodes.** This is the most important architectural constraint in the codebase. Roku's SceneGraph runs UI on a single render thread. If you create an `roUrlTransfer` object and call `GetToString()` on the render thread, it blocks until the HTTP response arrives — causing a rendezvous crash or frozen UI.

### How Task Nodes Work

A Task node is a SceneGraph component that extends `Task`. It runs its designated function on a separate OS thread, isolated from the render thread. Communication happens exclusively through field observers on the node's interface.

**Lifecycle:**

1. **Create** — The calling screen creates the Task node:
   ```brightscript
   task = CreateObject("roSGNode", "PlexApiTask")
   ```
2. **Configure** — Set input fields on the task:
   ```brightscript
   task.endpoint = "/library/sections"
   task.method = "GET"
   ```
3. **Observe** — Attach a callback for when the task's status changes:
   ```brightscript
   task.observeField("status", "onTaskStateChange")
   ```
4. **Run** — Start the background thread:
   ```brightscript
   task.control = "run"
   ```
5. **Complete** — The task sets its `status` field to `"completed"` or `"error"`, which fires the observer callback on the render thread. The screen reads `task.response` or `task.error`.

### Task Inventory

| Task | Purpose | Key Behavior |
|------|---------|-------------|
| **PlexApiTask** | General PMS API calls | Paginated library browsing, metadata fetches, scrobble/unscrobble, PUT/DELETE via `SetRequest()` |
| **PlexAuthTask** | Authentication | PIN request → polling → token acquisition → server discovery |
| **PlexSearchTask** | Search | Queries `/hubs/search` with term and limit |
| **PlexSessionTask** | Playback tracking | Reports progress via `/:/timeline` every 10 seconds |
| **ServerConnectionTask** | Connection validation | Tests server URI reachability before committing to it |

### Error Handling in Tasks

Every task checks the HTTP response code:
- **401 Unauthorized** → sets `m.global.authRequired = true`, which MainScene observes to trigger re-authentication
- **Negative response code** → network failure. Sets `task.error` with the failure reason from `roUrlTransfer`
- **Empty 200 response** → treated as success (expected for scrobble/timeline endpoints)
- **Parse failure** → `ParseJson()` returns `invalid`; task sets status to `"error"`
- **Timeout** → 30-second `wait()` timeout; if exceeded, task reports timeout error

## Data Flow

### Authentication

```
App Launch
    │
    ▼
Check Registry (authToken + serverUri)
    │
    ├── Both present → ServerConnectionTask validates → HomeScreen
    │
    └── Missing → PINScreen
                    │
                    ▼
              PlexAuthTask: POST /api/v2/pins → get PIN code
              Display PIN → user visits plex.tv/link
              PlexAuthTask: poll GET /api/v2/pins/{id}
                    │
                    ▼
              Token received → fetch server list
              GET /api/v2/resources?includeHttps=1&includeRelay=1
                    │
                    └── Auto-connect to first server → HomeScreen
```

Tokens are stored in `roRegistrySection("UnPlex")` and persist across app restarts. A separate admin token supports managed user switching.

### Library Browsing

1. HomeScreen loads the user's library list via `PlexApiTask` → `GET /library/sections`
2. The Sidebar populates with library names (Movies, TV Shows, Music, etc.)
3. When the user selects a library, HomeScreen fetches the first page:
   - `GET /library/sections/{id}/all` with `X-Plex-Container-Start=0` and `X-Plex-Container-Size=50`
4. The raw JSON response passes through a normalizer function (e.g., `NormalizeMovieList()`) that creates a ContentNode tree
5. The ContentNode tree is bound to the PosterGrid's `content` field
6. As the user scrolls near the bottom, an `onLoadMore` event triggers the next page fetch
7. Hub rows (Continue Watching, Recently Added) are fetched separately and refresh on a 2-minute timer

For TV shows, selecting a show from HomeScreen or SearchScreen navigates to ShowScreen, which displays season posters in a horizontal row. Focusing a season loads its episodes as landscape thumbnail cards in a grid below. Selecting an episode navigates to DetailScreen.

### Playback

```
DetailScreen → Play button → create VideoPlayer node
    │
    ├── Direct Play: {serverUri}{partKey}?X-Plex-Token={token}
    │
    └── Transcode: {serverUri}/video/:/transcode/universal/start.m3u8
         ?path={key}&protocol=hls&...
    │
    ▼
PlexSessionTask begins progress reporting
    PUT /:/timeline?ratingKey={id}&state=playing&time={ms}
    (every 10 seconds)
    │
    ▼
On stop/complete: report final position → update watched state
```

- **Direct play** is attempted first. The Roku `Video` node streams the file directly from PMS.
- **Transcode fallback** kicks in when the media format is incompatible. PMS transcodes to HLS on the fly.
- **Progress reporting** runs via PlexSessionTask on a 10-second interval, reporting `state` (playing/paused/stopped) and `time` (milliseconds) to the server.
- **Scrobble** (mark as watched) happens automatically when playback reaches the end, or manually via the DetailScreen.

### Auto-Play Next Episode

For TV episodes, the VideoPlayer fetches the next episode during the credits region and displays a 10-second countdown overlay. Key behaviors:

- **Episode index propagation:** `startNextEpisode()` updates `episodeIndex`, `seasonIndex`, and `parentRatingKey` on the VideoPlayer so the next credits cycle correctly identifies the successor episode.
- **Cross-season transitions:** When no next episode exists in the current season, the player fetches the show's season list and starts the first episode of the next season.
- **Last episode handling:** `handleNoNextEpisode()` is called whenever no successor is found. If the video has already reached "finished" state while the fetch was in flight, the helper calls `signalPlaybackComplete("finished")` to prevent the player from getting stuck.
- **Back-press bypass:** Pressing Back during playback returns directly to the calling screen (DetailScreen or ShowScreen) with focus restored and metadata refreshed. PostPlayScreen is only shown for natural completion, cancellation, and error cases.

### Watch State Updates

When a user marks an item watched/unwatched on the DetailScreen, the change is posted to PMS and broadcast via `m.global.watchStateUpdate`. Other screens observe this global field and update their poster badge nodes in-place — no full re-fetch required for immediate visual feedback.

### Item Deletion

When a user deletes an item from DetailScreen, `m.global.itemDeleted` is set to the deleted item's ratingKey. HomeScreen and ShowScreen observe this field and immediately remove matching ContentNodes from their hub rows, poster grids, and episode grids. A content reassignment (`content = content`) forces the grid to re-render. Focus is set to the adjacent item (same index, or last item if the deleted one was at the end).

## Key Patterns

### ContentNode Trees

Roku's built-in grid and list components (`MarkupGrid`, `PosterGrid`, `RowList`, `LabelList`) expect data in the form of ContentNode hierarchies. API response handlers transform Plex API JSON arrays into ContentNode trees with standardized field names (`title`, `posterUrl`, `itemType`, `viewOffset`, `viewCount`, `ratingKey`).

```
ContentNode (root)
├── ContentNode (Movie 1) { title: "...", posterUrl: "...", watched: true }
├── ContentNode (Movie 2) { title: "...", posterUrl: "...", watched: false }
└── ContentNode (Movie 3) { ... }
```

### Registry Persistence

All persistent state (auth tokens, server URI, user name, pinned libraries) is stored in `roRegistrySection("UnPlex")` via wrapper functions in `utils.brs`:

- `GetAuthToken()` / `SetAuthToken(token)` — current user's Plex token
- `GetServerUri()` / `SetServerUri(uri)` — active PMS connection
- `GetPinnedLibraries()` / `SetPinnedLibraries(libs)` — sidebar library configuration

Every write operation must call `.Flush()` to commit changes to disk.

### Observer Pattern for Async Communication

Field observers are the primary communication mechanism between components:

- **Task → Screen:** Screen observes `task.status`. When the task completes, the callback reads `task.response`.
- **Widget → Screen:** Screen observes widget events like `itemSelected` or `filterChanged`.
- **Global signals:** Any component can observe `m.global.authRequired`, `m.global.watchStateUpdate`, or `m.global.serverReconnected` for cross-cutting state changes.

```brightscript
' Screen sets up observer
task.observeField("status", "onTaskStateChange")
task.control = "run"

' Callback fires when status changes
sub onTaskStateChange(event as Object)
    status = event.getData()
    if status = "completed"
        data = m.apiTask.response
        ' process data...
    else if status = "error"
        ' handle error...
    end if
end sub
```

### Global State via m.global

The `m.global` node is accessible from every component and carries app-wide state:

| Field | Purpose |
|-------|---------|
| `constants` | Cached layout/color/API constants (set once at startup) |
| `authRequired` | Set to `true` when a 401 is received; MainScene observes to show PINScreen |
| `serverUnreachable` | Set to `true` when the PMS connection fails; screens show retry UI |
| `serverReconnected` | Set to `true` when a server comes back online; screens can refresh |
| `watchStateUpdate` | Carries `{ ratingKey, viewCount, viewOffset }` after a watch state change |
| `itemDeleted` | Carries the ratingKey of a deleted item; HomeScreen/ShowScreen remove matching ContentNodes immediately |
| `hubsNeedRefresh` | Triggers hub row re-fetch on HomeScreen (e.g. after library config change) |
| `sidebarNeedRefresh` | Triggers sidebar library list reload |
| `logBuffer` | In-memory ring buffer (max 500 entries) for debug log export |

### Poster Image Transcoding

To avoid loading full-resolution artwork (which can be very large), UnPlex requests resized poster images from PMS:

```
{serverUri}/photo/:/transcode?width=240&height=360&url={posterUrl}&X-Plex-Token={token}
```

This reduces bandwidth and memory usage. The `BuildPosterUrl()` helper in `utils.brs` constructs these URLs.

### Safe Field Access

Plex API responses can have missing or null fields depending on server version and media type. The `SafeGet(obj, field, default)` function prevents crashes by checking for `invalid` objects and missing fields before access. `SafeGetMetadata(response)` safely extracts the `MediaContainer.Metadata` array that most endpoints return.

`SafeStr(value)` coerces any Dynamic value to String — handling String, Integer, Float, LongInteger, Double, and Boolean types. This is essential for Plex API fields like `frameRate` that arrive as Float instead of String. Use `SafeStr(SafeGet(obj, "field", invalid))` when the result will be compared to `""`.

### Themed Dialogs

All dialogs use `CreateThemedDialog()` from `utils.brs` instead of raw `StandardMessageDialog` construction. The helper applies an `RSGPalette` with UnPlex colors (charcoal background, gold focus ring, neutral gray text) for visual consistency across all 18 dialog instances in the codebase.

### Type-Branching in DetailScreen

DetailScreen displays type-specific metadata by branching on `item.type`. On each item load, `hideTypeSpecificLabels()` resets all 6 type-specific Label nodes to hidden, then a type-specific populate function runs:

- **Movies:** `populateMovieMetadata()` — tagline, cast (up to 5 names from `Role[]`), director + writer crew line, studio
- **Episodes:** `populateEpisodeMetadata()` — "S{parentIndex} · E{index} — {grandparentTitle}" context, formatted air date
- **Shows:** `populateShowMetadata()` — "{childCount} Seasons · {leafCount} Episodes" context, studio
- **Clips/Unknown:** All type-specific labels stay hidden — generic metadata (title, year, runtime, rating, summary) still renders

The metadata group uses a `LayoutGroup` with `layoutDirection="vert"` instead of fixed Y-offsets, so variable-height summaries don't break the layout (D008).

Nested Plex API arrays (e.g., `Role[]`, `Director[]`) require a 4-level null-guard pattern: check parent `<> invalid`, check `count() > 0`, check element `<> invalid`, check element field `<> invalid`.

### ShowScreen Dual-Focus Areas

ShowScreen manages two focus areas: a season poster row (PosterGrid, numRows=1) and an episode grid (EpisodeGrid, a custom widget replacing the built-in MarkupGrid). When the user navigates down from the season row, focus transfers to the episode grid via explicit `setFocus(false)` on the season row followed by `setFocus(true)` on the episode grid. The `drawFocusFeedback` flag toggles on each area to provide visual feedback for which area is active.

When a different season gains focus in the season row, PosterGrid's `itemFocused` interface field fires, triggering an episode reload for that season. The first season with unwatched episodes is auto-focused on initial load.

## Component Inventory

### Screens (10)

| Screen | Purpose |
|--------|---------|
| **HomeScreen** | Main library browsing — sidebar, poster grid, hub rows, filter/sort |
| **DetailScreen** | Item metadata display — type-specific fields for movies (tagline, cast, director, crew, studio), episodes (season/show context, air date), shows (season/episode counts, studio). LayoutGroup auto-stacking for variable-height content (D008). Delete button with confirmation dialog and 403 handling. Get Info button navigates to MediaInfoScreen. Supports `autoAction` field for triggering Delete or Get Info directly from the options menu. Back-press from playback returns here with focus restored and metadata refreshed |
| **ShowScreen** | TV show browsing — season poster row (PosterGrid numRows=1) + episode landscape grid (EpisodeGrid custom widget replacing MarkupGrid) with auto-focus on first unwatched season |
| **SearchScreen** | Search — custom keyboard input with filter buttons and results grid |
| **PlaylistScreen** | Playlist item browsing and playback |
| **SettingsScreen** | User and library management. About row displays app version via GetAppVersion() |
| **PINScreen** | OAuth authentication — displays PIN code and polls for token |
| **UserPickerScreen** | Managed user selection with optional PIN entry |
| **MediaInfoScreen** | Technical metadata display — full-screen view showing file path, container format, video/audio codecs, resolution, bitrate, audio channels, subtitle streams, and file size. Data sourced from nested Media[].Part[].Stream[] arrays in the Plex API response |
| **PostPlayScreen** | Post-play — next episode countdown with replay, back-to-show, and auto-play options |
| **(MainScene)** | Root coordinator — screen stack, auth routing, global state management |

### Widgets (15)

| Widget | Purpose |
|--------|---------|
| **Sidebar** | Library navigation list with pinned libraries and nav items |
| **SidebarNavItem** | Custom MarkupList item renderer for the Sidebar |
| **PosterGrid** | Scrollable poster grid with selection, badges, dynamic column sizing, and itemFocused notification |
| **PosterGridItem** | Individual poster with progress bar and watched badge |
| **VideoPlayer** | Full playback — seeking, track selection, skip intro/credits, auto-play next |
| **TrackSelectionPanel** | Audio and subtitle track picker during playback |
| **FilterBar** | Genre/year/sort filter controls above the grid |
| **FilterBottomSheet** | Modal filter options panel |
| **EpisodeGrid** | Custom episode grid widget with manual item layout, keyboard focus management, and landscape card rendering via EpisodeGridItem components |
| **EpisodeGridItem** | Landscape episode card (320×180) with thumbnail, episode number + title, duration, progress bar, watched badge |
| **PlaylistItem** | Single playlist entry |
| **UserAvatarItem** | User avatar and name for the user picker |
| **LibrarySettingItem** | Pinned library toggle in settings |
| **LoadingSpinner** | Safe loading indicator (Label + Rectangle + Timer with 300ms delay) |
| **AlphaNav** | A–Z alphabetic jump navigation |

### Task Nodes (5)

| Task | Purpose |
|------|---------|
| **PlexApiTask** | General PMS REST API calls (library, metadata, scrobble). Supports PUT and DELETE methods via `SetRequest()` for media management |
| **PlexAuthTask** | PIN-based OAuth flow and server discovery via plex.tv |
| **PlexSearchTask** | Search queries with configurable limits |
| **PlexSessionTask** | Playback progress reporting (10-second intervals) |
| **ServerConnectionTask** | Server URI validation and reachability testing |

### Utility Modules (4)

| Module | Purpose |
|--------|---------|
| **main.brs** | App entry point — creates `roSGScreen`, instantiates MainScene, runs event loop |
| **utils.brs** | Registry access, URL builders, Plex header generation, safe field access (`SafeGet`, `SafeStr`), `FormatFileSize()` byte formatting, `GetAppVersion()` manifest reader, `CreateThemedDialog()` palette helper |
| **constants.brs** | Layout constants (FHD dimensions), colors, API metadata, pagination settings |
| **logger.brs** | `LogEvent()` and `LogError()` for console-based tracing |
