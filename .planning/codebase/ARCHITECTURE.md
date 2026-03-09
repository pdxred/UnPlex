# Architecture

**Analysis Date:** 2026-03-08

## Pattern Overview

**Overall:** Component-based MVC with Observer Pattern and Background Task Threading

**Key Characteristics:**
- Roku SceneGraph component model: each UI element is an XML layout + BrightScript logic pair
- Strict render-thread / task-thread separation: all HTTP I/O runs in Task nodes
- Observer-based communication between layers (field observers replace callbacks/events)
- Screen stack navigation managed by a central scene controller (`MainScene`)
- Shared utility functions injected via `<script>` includes (no module system)

## Layers

**Entry Point (Bootstrap):**
- Purpose: Create the SceneGraph screen, wire the message loop, pass launch args
- Location: `SimPlex/source/main.brs`
- Contains: `Main()` subroutine, message port loop, screen close handling
- Depends on: Roku SDK (`roSGScreen`, `roMessagePort`)
- Used by: Roku runtime (called on channel launch)

**Scene Controller (Navigation & Routing):**
- Purpose: Manage screen lifecycle, screen stack, navigation, auth routing
- Location: `SimPlex/components/MainScene.brs`, `SimPlex/components/MainScene.xml`
- Contains: Screen factory methods (`showHomeScreen`, `showDetailScreen`, etc.), push/pop stack, `onItemSelected` router, auth flow orchestration, exit dialog
- Depends on: All screen components, `utils.brs`, `constants.brs`, `logger.brs`
- Used by: `main.brs` (creates the scene), screens (via `itemSelected`/`navigateBack` fields)

**Screens (Views):**
- Purpose: Full-screen UI views, each responsible for one user-facing feature
- Location: `SimPlex/components/screens/`
- Contains:
  - `HomeScreen` - Library browsing with sidebar + poster grid + filter bar
  - `DetailScreen` - Item metadata display, play/resume/mark-watched actions
  - `EpisodeScreen` - Season/episode browser for TV shows
  - `SearchScreen` - Keyboard input with debounced search results
  - `PINScreen` - plex.tv PIN-based authentication flow
  - `ServerListScreen` - Server selection after authentication
  - `SettingsScreen` - Switch server, sign out
- Depends on: Widget components, Task nodes, `utils.brs`, `constants.brs`
- Used by: `MainScene` (creates and pushes onto screen stack)

**Widgets (Reusable UI Components):**
- Purpose: Shared UI building blocks composed into screens
- Location: `SimPlex/components/widgets/`
- Contains:
  - `Sidebar` - Library navigation list with hubs and settings links
  - `PosterGrid` - Paginated grid of poster items with infinite scroll
  - `PosterGridItem` - Individual poster cell renderer
  - `EpisodeItem` - Episode list item renderer
  - `FilterBar` - Library filter controls
  - `LoadingSpinner` - Loading indicator
  - `VideoPlayer` - Playback with direct play/transcode, progress reporting, scrobble
  - `MediaRow` - Horizontal media row
  - `KeyboardDialog` - Text input dialog
- Depends on: `constants.brs`, `utils.brs`
- Used by: Screen components

**Tasks (Background I/O):**
- Purpose: Run HTTP requests off the render thread to avoid rendezvous crashes
- Location: `SimPlex/components/tasks/`
- Contains:
  - `PlexApiTask` - General-purpose PMS REST client (GET/POST, auth headers, JSON parse, 401 handling)
  - `PlexAuthTask` - plex.tv PIN auth flow (request PIN, poll, fetch resources/servers)
  - `PlexSearchTask` - Search endpoint with URL encoding
  - `PlexSessionTask` - Playback timeline/progress reporting (PUT via POST + method override)
  - `ServerConnectionTask` - Test server connections (local -> remote -> relay priority)
  - `ImageCacheTask` - Prefetch poster images to warm Roku's image cache
- Depends on: `utils.brs`, `constants.brs`, `logger.brs`
- Used by: Screens and widgets (created via `CreateObject("roSGNode", "TaskName")`)

**Shared Utilities (Cross-cutting):**
- Purpose: Helper functions available to all components via script include
- Location: `SimPlex/source/`
- Contains:
  - `utils.brs` - Auth token CRUD, Plex header construction, URL building, time formatting, `SafeGet`/`SafeGetMetadata` for safe property access
  - `constants.brs` - `GetConstants()` returning colors, layout sizes, API URLs, pagination config
  - `logger.brs` - `LogEvent()` and `LogError()` with ISO timestamps to `print`
  - `normalizers.brs` - JSON-to-ContentNode converters (`NormalizeMovieList`, `NormalizeShowList`, `NormalizeSeasonList`, `NormalizeEpisodeList`, `NormalizeOnDeck`)
  - `capabilities.brs` - Parse PMS version, feature flag queries (`HasCapability`, `MeetsMinVersion`)

## Data Flow

**Library Browsing (Home Screen):**

1. `Sidebar` fetches `/library/sections` via `PlexApiTask`, renders library list
2. User selects library -> `Sidebar.selectedLibrary` field fires -> `HomeScreen.onLibrarySelected()`
3. `HomeScreen` builds paginated request (`/library/sections/{id}/all` + filters) -> sets `PlexApiTask.endpoint` + `params` -> `control = "run"`
4. `PlexApiTask` runs on background thread: builds URL via `BuildPlexUrl()`, adds `GetPlexHeaders()`, makes async HTTP request, parses JSON
5. Task sets `status = "completed"` -> observer fires `HomeScreen.onApiTaskStateChange()` -> `processApiResponse()`
6. `HomeScreen` builds `ContentNode` tree from JSON metadata, sets `PosterGrid.content`
7. `PosterGrid` renders items; on scroll near bottom, fires `loadMore` -> triggers next page fetch

**Authentication:**

1. `MainScene.checkAuthAndRoute()` reads registry for stored `authToken` + `serverUri`
2. If missing: `showPINScreen()` -> `PINScreen` creates `PlexAuthTask` with action `"requestPin"`
3. `PlexAuthTask` POSTs to `plex.tv/api/v2/pins` -> returns PIN code + ID
4. `PINScreen` displays code, starts 2-second poll timer -> each tick runs `PlexAuthTask` with action `"checkPin"`
5. When user authorizes at plex.tv/link: `authToken` appears in poll response -> stored via `SetAuthToken()`
6. `PlexAuthTask` action `"fetchResources"` -> fetches server list from `plex.tv/api/v2/resources`
7. If multiple servers: `MainScene` shows `ServerListScreen`; if single: auto-connects via `ServerConnectionTask`
8. `ServerConnectionTask` tests connections in priority order (local -> remote -> relay) with timeouts
9. Successful URI stored via `SetServerUri()` -> `MainScene.showHomeScreen()`

**Playback:**

1. User selects item in grid -> `HomeScreen.onGridItemSelected()` fires `itemSelected` with `action: "detail"`
2. `MainScene.onItemSelected()` routes to `showDetailScreen(ratingKey, itemType)`
3. `DetailScreen` fetches `/library/metadata/{ratingKey}` via `PlexApiTask`
4. User presses Play -> `DetailScreen.startPlayback()` creates `VideoPlayer` widget, appends to scene
5. `VideoPlayer.loadMedia()` fetches media metadata -> `processMediaInfo()` checks codec support via `checkDirectPlay()`
6. Direct play: builds URL from `part.key` + token; Transcode: builds HLS URL via `buildTranscodeUrl()`
7. Sets `roVideo.content` ContentNode with URL + streamFormat -> `control = "play"`
8. `PlexSessionTask` reports progress every 10 seconds via PUT to `/:/timeline`
9. On finish: `scrobble()` marks watched, fires `playbackComplete` -> parent removes player

**State Management:**
- Persistent state: `roRegistrySection("SimPlex")` stores `authToken`, `serverUri`, `serverClientId`, `deviceId`
- Session state: Component-scoped `m.*` variables (e.g., `m.screenStack`, `m.currentSectionId`, `m.isLoading`)
- Global state: `m.global` node fields for `authRequired` signal (cross-component 401 handling)
- UI state: ContentNode trees bound to grid/list components

## Key Abstractions

**Screen Stack:**
- Purpose: Manage navigation history with focus preservation
- Implementation: `m.screenStack` (array) + `m.focusStack` (array) in `SimPlex/components/MainScene.brs`
- Pattern: `pushScreen()` hides current, appends new, saves deep-focused child; `popScreen()` removes current, restores previous visibility and focus
- All screens share interface fields: `itemSelected` (assocarray, alwaysNotify) and `navigateBack` (boolean, alwaysNotify)

**Task Node Pattern:**
- Purpose: Background HTTP execution with status-based observer communication
- Examples: `SimPlex/components/tasks/PlexApiTask.xml`, `SimPlex/components/tasks/PlexSearchTask.xml`
- Pattern: Set input fields (`endpoint`, `params`) -> set `control = "run"` -> observe `status` field for `"completed"` / `"error"` -> read `response` / `error` fields

**ContentNode Trees:**
- Purpose: Data binding between API responses and SceneGraph list/grid components
- Examples: Used in `SimPlex/components/screens/HomeScreen.brs` (processApiResponse), `SimPlex/source/normalizers.brs`
- Pattern: Create root `ContentNode`, add children with `addFields({...})`, assign to component's `.content` field

**Safe Property Access:**
- Purpose: Prevent crashes from malformed/partial API responses
- Implementation: `SafeGet(obj, field, default)` and `SafeGetMetadata(response)` in `SimPlex/source/utils.brs`
- Pattern: All API response access uses `SafeGet()` for null-safe property reads

## Entry Points

**Application Launch:**
- Location: `SimPlex/source/main.brs` -> `Main(args)`
- Triggers: Roku runtime launches channel
- Responsibilities: Create `roSGScreen`, instantiate `MainScene`, pass deep-link args, run message loop

**Scene Initialization:**
- Location: `SimPlex/components/MainScene.brs` -> `init()`
- Triggers: `screen.CreateScene("MainScene")` in `main.brs`
- Responsibilities: Set up global fields, check auth, route to PIN screen or home screen

**Navigation Router:**
- Location: `SimPlex/components/MainScene.brs` -> `onItemSelected(event)`
- Triggers: Any screen setting its `itemSelected` field
- Responsibilities: Parse action type and route to appropriate `show*Screen()` method

**Remote Key Handler:**
- Location: `onKeyEvent(key, press)` function in every screen and widget `.brs` file
- Triggers: Roku remote button presses (propagates through focus chain)
- Responsibilities: Handle navigation (back), focus movement (left/right/up/down), playback controls

## Error Handling

**Strategy:** Defensive checks with user-facing error dialogs and structured logging

**Patterns:**
- **401 Unauthorized Global Handler:** `PlexApiTask` detects 401 responses -> clears stored token -> sets `m.global.authRequired = true` -> `MainScene` observes this and routes to `PINScreen` (`SimPlex/components/tasks/PlexApiTask.brs` lines 98-108, `SimPlex/components/MainScene.brs` lines 129-139)
- **Task Error Status:** All tasks set `status = "error"` and populate `error` field with descriptive message; screens observe status and show `StandardMessageDialog`
- **Safe Property Access:** `SafeGet()` prevents `invalid` crashes from missing JSON fields (`SimPlex/source/utils.brs` lines 113-118)
- **Error Dialogs:** Standard pattern using `CreateObject("roSGNode", "StandardMessageDialog")` with title, message array, and OK button
- **Request Timeouts:** `PlexApiTask` uses 30-second timeout; `ServerConnectionTask` uses 3-second (local) / 5-second (remote) timeouts

## Cross-Cutting Concerns

**Logging:** `LogEvent()` and `LogError()` in `SimPlex/source/logger.brs` -> prints to Roku debug console with ISO 8601 timestamps. Two levels only: EVENT (milestones) and ERROR (problems). Included in all tasks and screens via `<script>` tag.

**Validation:** Defensive null checks throughout. `SafeGet()` for all associative array access from API responses. Type-checking for `ratingKey` (can be string or integer from Plex API) occurs in multiple screens.

**Authentication:** Centralized in `SimPlex/source/utils.brs` (`GetAuthToken`, `SetAuthToken`, `GetServerUri`, `SetServerUri`, `ClearAuthData`). All API requests include `X-Plex-Token` and standard `X-Plex-*` headers via `GetPlexHeaders()`. Global 401 observer pattern enables any task to trigger re-authentication.

**Persistence:** `roRegistrySection("SimPlex")` with explicit `.Flush()` after every write. Keys: `authToken`, `serverUri`, `serverClientId`, `deviceId`.

---

*Architecture analysis: 2026-03-08*
