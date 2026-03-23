# SimPlex Architecture

This document describes the internal architecture of SimPlex — a Roku BrightScript application built on the SceneGraph framework. It covers the layer model, threading, navigation, data flow, and key design patterns that shape the codebase.

## System Overview

SimPlex follows a layered component architecture. All UI is built with Roku SceneGraph XML components backed by BrightScript logic. All network I/O runs in background Task nodes to avoid blocking the render thread.

```
┌─────────────────────────────────────────────────────────┐
│                    Roku SceneGraph                       │
│   ┌───────────────────────────────────────────────────┐ │
│   │              MainScene (Root)                     │ │
│   │   Screen stack · Auth routing · Global state      │ │
│   ├───────────────────────────────────────────────────┤ │
│   │               Screens (10)                        │ │
│   │   HomeScreen · DetailScreen · EpisodeScreen       │ │
│   │   SearchScreen · PINScreen · SettingsScreen ...   │ │
│   ├───────────────────────────────────────────────────┤ │
│   │               Widgets (15+)                       │ │
│   │   PosterGrid · Sidebar · VideoPlayer              │ │
│   │   FilterBar · KeyboardDialog · TrackPanel ...     │ │
│   ├───────────────────────────────────────────────────┤ │
│   │             Task Nodes (6)                        │ │
│   │   PlexApiTask · PlexAuthTask · PlexSearchTask     │ │
│   │   PlexSessionTask · ServerConnectionTask          │ │
│   │   ImageCacheTask                                  │ │
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
| **PlexApiTask** | General PMS API calls | Paginated library browsing, metadata fetches, scrobble/unscrobble |
| **PlexAuthTask** | Authentication | PIN request → polling → token acquisition → server discovery |
| **PlexSearchTask** | Search | Queries `/hubs/search` with term and limit |
| **PlexSessionTask** | Playback tracking | Reports progress via `/:/timeline` every 10 seconds |
| **ServerConnectionTask** | Connection validation | Tests server URI reachability before committing to it |
| **ImageCacheTask** | Image prefetch | Prefetches poster images to local cache for grid performance |

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
                    ├── Single server → auto-connect → HomeScreen
                    └── Multiple servers → ServerListScreen → user picks → HomeScreen
```

Tokens are stored in `roRegistrySection("SimPlex")` and persist across app restarts. A separate admin token supports managed user switching.

### Library Browsing

1. HomeScreen loads the user's library list via `PlexApiTask` → `GET /library/sections`
2. The Sidebar populates with library names (Movies, TV Shows, Music, etc.)
3. When the user selects a library, HomeScreen fetches the first page:
   - `GET /library/sections/{id}/all` with `X-Plex-Container-Start=0` and `X-Plex-Container-Size=50`
4. The raw JSON response passes through a normalizer function (e.g., `NormalizeMovieList()`) that creates a ContentNode tree
5. The ContentNode tree is bound to the PosterGrid's `content` field
6. As the user scrolls near the bottom, an `onLoadMore` event triggers the next page fetch
7. Hub rows (Continue Watching, Recently Added) are fetched separately and refresh on a 2-minute timer

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

### Watch State Updates

When a user marks an item watched/unwatched on the DetailScreen, the change is posted to PMS and broadcast via `m.global.watchStateUpdate`. Other screens observe this global field and update their poster badge nodes in-place — no full re-fetch required for immediate visual feedback.

## Key Patterns

### ContentNode Trees

Roku's built-in grid and list components (`MarkupGrid`, `PosterGrid`, `RowList`, `LabelList`) expect data in the form of ContentNode hierarchies. Normalizer functions in `normalizers.brs` transform Plex API JSON arrays into ContentNode trees with standardized field names (`id`, `title`, `posterUrl`, `itemType`, `watched`, `viewOffset`, `ratingKey`).

```
ContentNode (root)
├── ContentNode (Movie 1) { title: "...", posterUrl: "...", watched: true }
├── ContentNode (Movie 2) { title: "...", posterUrl: "...", watched: false }
└── ContentNode (Movie 3) { ... }
```

### Registry Persistence

All persistent state (auth tokens, server URI, user name, pinned libraries) is stored in `roRegistrySection("SimPlex")` via wrapper functions in `utils.brs`:

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
| `serverReconnected` | Set to `true` when a server comes back online; screens can refresh |
| `watchStateUpdate` | Carries `{ ratingKey, watched, viewOffset }` after a watch state change |
| `hubRefresh` | Triggers hub row re-fetch on HomeScreen |
| `sidebarRefresh` | Triggers sidebar library list reload |

### Poster Image Transcoding

To avoid loading full-resolution artwork (which can be very large), SimPlex requests resized poster images from PMS:

```
{serverUri}/photo/:/transcode?width=240&height=360&url={posterUrl}&X-Plex-Token={token}
```

This reduces bandwidth and memory usage. The `BuildPosterUrl()` helper in `utils.brs` constructs these URLs.

### Safe Field Access

Plex API responses can have missing or null fields depending on server version and media type. The `SafeGet(obj, field, default)` function prevents crashes by checking for `invalid` objects and missing fields before access. `SafeGetMetadata(response)` safely extracts the `MediaContainer.Metadata` array that most endpoints return.

## Component Inventory

### Screens (10)

| Screen | Purpose |
|--------|---------|
| **HomeScreen** | Main library browsing — sidebar, poster grid, hub rows, filter/sort |
| **DetailScreen** | Item metadata display — poster, title, summary, play button, watch state |
| **EpisodeScreen** | TV show season/episode list — season picker, episode grid |
| **SearchScreen** | Search — text input with debounced results grid |
| **PlaylistScreen** | Playlist item browsing and playback |
| **SettingsScreen** | User, server, and library management |
| **PINScreen** | OAuth authentication — displays PIN code and polls for token |
| **UserPickerScreen** | Managed user selection with optional PIN entry |
| **ServerListScreen** | Server discovery — lists available PMS instances with connection testing |
| **(MainScene)** | Root coordinator — screen stack, auth routing, global state management |

### Widgets (15+)

| Widget | Purpose |
|--------|---------|
| **Sidebar** | Library navigation list with pinned libraries and nav items |
| **SidebarNavItem** | Custom MarkupList item renderer for the Sidebar |
| **PosterGrid** | Scrollable poster grid with selection, badges, and dynamic column sizing |
| **PosterGridItem** | Individual poster with progress bar and watched badge |
| **VideoPlayer** | Full playback — seeking, track selection, skip intro/credits, auto-play next |
| **TrackSelectionPanel** | Audio and subtitle track picker during playback |
| **FilterBar** | Genre/year/sort filter controls above the grid |
| **FilterBottomSheet** | Modal filter options panel |
| **EpisodeItem** | Single episode row in the episode list |
| **MediaRow** | Hub row of media items (Continue Watching, Recently Added) |
| **PlaylistItem** | Single playlist entry |
| **UserAvatarItem** | User avatar and name for the user picker |
| **LibrarySettingItem** | Pinned library toggle in settings |
| **KeyboardDialog** | On-screen keyboard for text input |
| **LoadingSpinner** | Loading animation (currently disabled due to firmware crash) |
| **AlphaNav** | A–Z alphabetic jump navigation |

### Task Nodes (6)

| Task | Purpose |
|------|---------|
| **PlexApiTask** | General PMS REST API calls (library, metadata, scrobble) |
| **PlexAuthTask** | PIN-based OAuth flow and server discovery via plex.tv |
| **PlexSearchTask** | Search queries with configurable limits |
| **PlexSessionTask** | Playback progress reporting (10-second intervals) |
| **ServerConnectionTask** | Server URI validation and reachability testing |
| **ImageCacheTask** | Background poster image prefetching |

### Utility Modules (6)

| Module | Purpose |
|--------|---------|
| **main.brs** | App entry point — creates `roSGScreen`, instantiates MainScene, runs event loop |
| **utils.brs** | Registry access, URL builders, Plex header generation, safe field access |
| **constants.brs** | Layout constants (FHD dimensions), colors, API metadata, pagination settings |
| **logger.brs** | `LogEvent()` and `LogError()` for console-based tracing |
| **normalizers.brs** | JSON response → ContentNode tree transformers |
| **capabilities.brs** | Server capability detection (currently unused — reserved for future version checks) |
