# Architecture

**Analysis Date:** 2026-03-13

## Pattern Overview

**Overall:** SceneGraph Component-Based Architecture with Task-Driven Async Communication

**Key Characteristics:**
- **Component-based UI**: Each screen and widget is a SceneGraph component (XML interface + BrightScript logic)
- **Task-driven architecture**: All HTTP requests run in separate Task nodes (background threads) - never on render thread
- **Observer pattern**: Field observers enable loose coupling between components and background tasks
- **Screen stack management**: MainScene manages a navigation stack of Screen components with focus preservation
- **Global state propagation**: `m.global` node disseminates authentication, server connectivity, and data updates across the app
- **Data transformation layer**: Normalizers convert Plex API JSON responses into ContentNode trees for UI binding

## Layers

**Presentation Layer (Screens):**
- Purpose: Full-screen views that manage complex user interactions and coordinate multiple widgets
- Location: `SimPlex/components/screens/`
- Contains: Screen components (HomeScreen, DetailScreen, SearchScreen, etc.) that extend `Group` or `Scene`
- Depends on: Utility functions, constants, Task nodes for API calls, child widgets
- Used by: MainScene via screen stack management

**Widget Layer (Reusable Components):**
- Purpose: Reusable UI components for grids, sidebars, dialogs, and media controls
- Location: `SimPlex/components/widgets/`
- Contains: Focused components like PosterGrid, Sidebar, VideoPlayer, FilterBar, TrackSelectionPanel
- Depends on: Constants for styling, parent screen logic via field observers
- Used by: Screens that compose multiple widgets for complex UIs

**Task Layer (Background Threading):**
- Purpose: Isolated HTTP request handling to prevent render thread blocking
- Location: `SimPlex/components/tasks/`
- Contains: Task nodes (PlexApiTask, PlexAuthTask, PlexSearchTask, PlexSessionTask, ServerConnectionTask, ImageCacheTask)
- Depends on: Utility functions for URL building, header construction, JSON parsing
- Used by: Screens and widgets observe task fields (endpoint, status, response) to trigger UI updates

**Utilities Layer (Shared Code):**
- Purpose: Cross-cutting functions for auth management, URL building, data transformation, logging
- Location: `SimPlex/source/`
- Contains:
  - `main.brs`: Entry point, creates screen, runs event loop
  - `utils.brs`: Auth token/server URI storage (registry), Plex header generation, URL builders, safe field access
  - `constants.brs`: Colors, layout dimensions, API endpoints, Plex product metadata
  - `logger.brs`: Log/LogError/LogEvent functions
  - `normalizers.brs`: JSON-to-ContentNode transformers (movie lists, episodes, on-deck, etc.)
  - `capabilities.brs`: Device capability detection
- Depends on: Roku SceneGraph APIs
- Used by: All screens, widgets, and tasks

**Root Coordinator:**
- Purpose: Screen navigation, auth flow, global state management
- Location: `SimPlex/components/MainScene.brs`
- Contains: Screen stack, focus management, auth check, server connection handling
- Depends on: Utility functions, Task nodes for single-server auto-connect
- Used by: main.brs

## Data Flow

**Authentication Flow:**

1. MainScene.init() calls `checkAuthAndRoute()` - checks stored credentials
2. If no token/server: Show PINScreen
3. PINScreen spawns PlexAuthTask (PIN polling) → on success, get servers from plex.tv
4. Multiple servers: Show ServerListScreen with ServerConnectionTask validation
5. Single server: Auto-connect with ServerConnectionTask
6. On success: Save serverUri/authToken to registry, show HomeScreen
7. If auth token expires (401): Global `authRequired` signal triggers PINScreen again

**Screen Navigation:**

1. Screens push/pop from MainScene.screenStack array
2. Each screen maintains its UI state and component references
3. Back button pops current screen, restores focus to previous screen's saved focus position
4. DetailScreen → play → VideoPlayer modal overlay
5. HomeScreen → sidebar "Collections" → show collection grid in same screen

**Data Fetch Pattern (HomeScreen Library Browsing):**

1. User selects library from Sidebar → `onLibrarySelected()` event
2. Screen creates PlexApiTask with endpoint="/library/sections/{id}/all", params={start: 0, size: 50}
3. Task.control="run" → task runs async in background
4. Task observes "status" field → "loading", "success", "error"
5. On "success": Task has response field with raw JSON
6. Screen calls normalizer (e.g., `NormalizeMovieList(rawJson)`) → ContentNode tree
7. Bind ContentNode to PosterGrid.content
8. PosterGrid displays items
9. User scrolls → onLoadMore event → fetch next 50 items
10. Paginate with X-Plex-Container-Start and X-Plex-Container-Size headers

**Watch State Update Propagation:**

1. DetailScreen plays video, reports progress via PlexSessionTask
2. When user marks watched/unwatched: PlexApiTask scrobble/unscrobble endpoint
3. DetailScreen posts `m.global.watchStateUpdate = { ratingKey, watched, viewOffset }`
4. HomeScreen and EpisodeScreen observe watchStateUpdate
5. Screens update poster badge nodes in-place (visual feedback immediately)
6. No need to re-fetch entire grid

**Server Reconnection:**

1. Any task gets 401 or connection error
2. Task posts `m.global.authRequired = true`
3. MainScene observes → shows PINScreen
4. OR task posts `m.global.serverUnreachable = true`
5. MainScene observes → screens can show retry buttons
6. User fixes server, global `serverReconnected = true` triggers refresh

**State Management:**

- **Registry persistence**: Auth tokens, server URI, user name, pinned libraries stored in `roRegistrySection("SimPlex")`
- **Global node fields**: Auth state, server reachability, data update signals (watch state, hub refresh, sidebar refresh)
- **Screen-local state**: Each screen maintains its own state for current library, filters, sort, focus position, scroll offset
- **Widget-local state**: PosterGrid tracks selection, FilterBar tracks applied filters, Sidebar tracks pinned libraries

## Key Abstractions

**Task Node Pattern:**
- Purpose: Encapsulate async HTTP logic away from render thread
- Examples: `PlexApiTask.brs`, `PlexAuthTask.brs`, `PlexSessionTask.brs`
- Pattern: Task reads input fields (endpoint, params, body), sets status field to "loading", makes HTTP request, sets response/error fields, sets status to "success"/"error". Caller observes status field to react.

**Normalizer Functions:**
- Purpose: Transform Plex API response JSON into SceneGraph ContentNode trees for UI binding
- Examples: `NormalizeMovieList()`, `NormalizeEpisodeList()`, `NormalizeOnDeck()`
- Pattern: Accept raw JSON array from API response, iterate items, create ContentNode children with standardized field names (id, title, posterUrl, itemType, watched, etc.), return root ContentNode

**ContentNode Trees:**
- Purpose: Hierarchical data binding for grids and lists
- Used by: PosterGrid (content field), RowList (content field for hub rows)
- Pattern: Each node has children nodes; PosterGrid iterates children and binds to individual PosterGridItem components

**Observer Pattern:**
- Purpose: Decouple async operations from UI updates
- Pattern: Screen creates task, calls `task.observeField("status", "onTaskStatusChange")`, sets task.control="run"; callback invoked when field changes
- Example: `m.posterGrid.observeField("itemSelected", "onGridItemSelected")` triggers navigation to DetailScreen

**Registry Wrapper Functions:**
- Purpose: Abstract `roRegistrySection` access for auth and config persistence
- Examples: `GetAuthToken()`, `SetAuthToken()`, `GetPinnedLibraries()`, `SetPinnedLibraries()`
- Pattern: Functions use `CreateObject("roRegistrySection", "SimPlex")`, Read/Write/Delete, Flush()

**Safe Field Access:**
- Purpose: Prevent crashes on malformed Plex API responses (missing fields, null values)
- Functions: `SafeGet(obj, field, default)`, `SafeGetMetadata(response)`
- Pattern: Check if object is valid, check if field exists, return default if missing

## Entry Points

**Application Entry Point:**
- Location: `SimPlex/source/main.brs`
- Triggers: User launches SimPlex from Roku home
- Responsibilities:
  1. Create roSGScreen and message port
  2. Create MainScene component
  3. Pass launch args (deep-linking support)
  4. Observe MainScene.close field
  5. Enter event loop: wait for screen close or node events

**Authentication Entry Point:**
- Location: `SimPlex/components/MainScene.brs`, `checkAuthAndRoute()` function
- Triggers: App launch or auth token expiration (401 response)
- Responsibilities:
  1. Check stored auth token and server URI
  2. If missing: Show PINScreen
  3. If present: Validate server is reachable (ServerConnectionTask)
  4. On success: Navigate to HomeScreen

**Navigation Entry Point:**
- Location: `SimPlex/components/MainScene.brs`, screen manager functions (`showHomeScreen()`, `showDetailScreen()`, etc.)
- Triggers: User navigates between screens (sidebar selection, grid item selection, back button)
- Responsibilities:
  1. Create screen component node with initial data (ratingKey, itemType, etc.)
  2. Attach field observers to screen for child events (itemSelected, navigateBack, authRequired)
  3. Push screen to stack, set MainScene.currentScreen for debugging
  4. Set initial focus if needed

**Widget Entry Points:**
- Sidebar.init(): Loads library list, builds nav content, sets up selection observers
- PosterGrid.init(): Sets up grid rendering and selection observers
- VideoPlayer.init(): Initializes video node, session tracking, playback controls
- FilterBar.init(): Builds filter options, sets up filter change observers

## Error Handling

**Strategy:** Defensive response handling at task level, global state signaling for auth/connection errors, inline retry buttons

**Patterns:**

**HTTP Error Responses:**
- Task checks HTTP response code
- 401 (Unauthorized): Post `m.global.authRequired = true` → MainScene shows PINScreen
- 5xx or connection timeout: Post task.error with message, set status to "error"
- Empty 200 response: Task treats as success and returns `{}`

**Malformed API Response:**
- `SafeGet()` used throughout to prevent crashes on missing fields
- `SafeGetMetadata()` safely accesses nested MediaContainer.Metadata structure
- Normalizers handle invalid input arrays, return empty ContentNode

**UI-Level Error Handling:**
- Screens observe task.status field: "loading", "success", "error"
- On error: Show inline error message or retry button
- HomeScreen has retry button for failed library loads
- SettingsScreen has retry for failed user switch

**Server Unreachability:**
- Tasks catch connection errors, post `m.global.serverUnreachable = true`
- MainScene observes, can trigger reconnect workflow
- Screens can show "Checking server..." spinner during reconnect

## Cross-Cutting Concerns

**Logging:**
- Framework: `roDeviceInfo().PrintDebugMessage()` via console; print statements visible in Roku telnet debug
- Patterns: `LogEvent()` for key milestones (auth success, screen push, API calls), `LogError()` for failures
- Files affected: `SimPlex/source/logger.brs`
- Usage: All screens and tasks call LogEvent/LogError to trace execution

**Validation:**
- No explicit input validation layer; Plex API responses are trusted
- Safe field access (`SafeGet()`) prevents crashes on unexpected response structure
- ItemType validation occurs in normalizers (movie/show/episode/etc.)
- Playback transcode validation in VideoPlayer (direct play vs. transcode mode)

**Authentication:**
- Tokens stored in registry (persistent across app restarts)
- Every Plex API request includes `X-Plex-Token` header via `GetPlexHeaders()`
- 401 response triggers re-authentication (PINScreen)
- Admin token stored separately from user token (supports user switching)

**Configuration:**
- Layout constants cached in `m.global.constants` for all components
- Plex product metadata (PLEX_PRODUCT, PLEX_VERSION, PLEX_PLATFORM) in constants
- Device info (model, OS version, friendly name) retrieved at header-building time
- No external config files; all settings in manifest and registry

---

*Architecture analysis: 2026-03-13*
