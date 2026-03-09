# Architecture Patterns

**Domain:** Roku Plex Media Client (scaling from ~20 to ~40+ components)
**Researched:** 2026-03-08

## Recommended Architecture

**Stay with enhanced MVC + Observer pattern. Do NOT migrate to Maestro MVVM.**

The existing architecture is sound and follows Roku-idiomatic patterns. The codebase already has clean separation: MainScene as controller, screens as views, tasks as I/O layer, normalizers as data transform layer. Maestro MVVM adds BrighterScript compilation, IOC containers, and binding syntax that increase build complexity and learning curve with limited benefit for a single-developer sideloaded channel. The ~20 existing components would need full rewrites. The ROI is negative for this project's scope.

Instead, invest in three targeted architectural improvements: (1) a centralized API service layer, (2) media-type-polymorphic screen design, and (3) a task pool for reuse.

### System Diagram

```
+----------------------------------------------------------+
|  MainScene (Controller / Router)                          |
|  - Screen stack management                                |
|  - Navigation routing (onItemSelected dispatcher)         |
|  - Auth flow orchestration                                |
|  - Global state coordination                              |
+--+-------+-------+-------+-------+-------+-------+-------+
   |       |       |       |       |       |       |
   v       v       v       v       v       v       v
+------+ +------+ +------+ +------+ +------+ +------+ +------+
| Home | |Detail| |Episo.| |Search| |Music | |Photo | |LiveTV|
|Screen| |Screen| |Screen| |Screen| |Screen| |Screen| |Guide |
+--+---+ +--+---+ +--+---+ +--+---+ +--+---+ +--+---+ +--+---+
   |         |         |         |         |         |       |
   v         v         v         v         v         v       v
+--------------------------------------------------------------+
|  Widgets Layer                                                |
|  Sidebar | PosterGrid | MediaRow | VideoPlayer | MusicPlayer |
|  FilterBar | EpisodeItem | TrackList | PhotoViewer | EPGGrid |
|  SubtitleOverlay | PlaybackOverlay | NowPlayingBar           |
+--------------------------------------------------------------+
   |         |         |         |
   v         v         v         v
+--------------------------------------------------------------+
|  API Service Layer (source/api/)                              |
|  PlexApiService.brs  - endpoint builders, response routing    |
|  PlexPlaybackService.brs - playback URL construction          |
|  PlexMediaService.brs - media type detection, codec checks    |
+--------------------------------------------------------------+
   |
   v
+--------------------------------------------------------------+
|  Task Layer (components/tasks/)                               |
|  PlexApiTask (pooled, reused) | PlexSessionTask               |
|  PlexSearchTask | PlexAuthTask | ServerConnectionTask         |
+--------------------------------------------------------------+
   |
   v
+--------------------------------------------------------------+
|  Data Layer (source/)                                         |
|  normalizers.brs  - JSON to ContentNode transforms            |
|  utils.brs        - auth, headers, URL builders               |
|  constants.brs    - all magic numbers and config              |
|  capabilities.brs - server feature detection                  |
|  logger.brs       - structured logging                        |
+--------------------------------------------------------------+
   |
   v
+--------------------------------------------------------------+
|  Persistence Layer                                            |
|  roRegistrySection("SimPlex") - auth, server, user prefs      |
+--------------------------------------------------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | Data Direction |
|-----------|---------------|-------------------|----------------|
| **MainScene** | Screen lifecycle, navigation stack, auth routing, global state | All screens (creates/destroys), m.global | Downward: pushes screen params. Upward: observes `itemSelected`, `navigateBack` |
| **Screens** | Full-screen UI for one feature. Own their child widgets and task instances | MainScene (via interface fields), widgets (via child nodes), tasks (via observer) | Down to widgets: sets `.content`, calls functions. Up to MainScene: sets `itemSelected` |
| **Widgets** | Reusable UI building blocks. Stateless where possible | Parent screen (via interface fields) | Up: fires events (`itemSelected`, `loadMore`). Down: receives `.content` ContentNode |
| **Tasks** | Background HTTP I/O exclusively. No UI references | Screens/widgets (via field observers), utils.brs | In: `endpoint`, `params`. Out: `status`, `response`, `error` |
| **Normalizers** | Transform raw JSON to ContentNode trees | Called by screens after task completion | In: JSON array. Out: ContentNode tree |
| **Utils/Services** | Shared helper functions included via `<script>` | Available to all components that include them | Stateless function calls |

### Communication Rules

1. **Screens to MainScene**: Always via `itemSelected` (assocarray with `action` field) or `navigateBack` (boolean). Never call MainScene methods directly.
2. **Widgets to Screens**: Via observable interface fields defined in widget XML. Never reference parent screen.
3. **Tasks to Screens**: Via `status` field observer. Task sets `status = "completed"` or `"error"`, screen reads `response`/`error` fields.
4. **Cross-screen communication**: Via `m.global` fields only (e.g., `authRequired`, current user context). Keep this minimal.
5. **No Task-to-Task communication**: All task coordination flows through the render thread.

## Data Flow for New Features

### Hub Rows (Continue Watching, Recently Added)

```
HomeScreen.init()
  -> fetch /hubs via PlexApiTask
  -> onHubsLoaded(): for each hub in response
     -> create MediaRow widget
     -> set MediaRow.content = NormalizeHubRow(hub.Metadata)
     -> MediaRow handles horizontal scroll internally
  -> MediaRow.itemSelected fires -> HomeScreen routes to detail
```

**Key decision:** Hub rows load as a single batch request to `/hubs`, not individual requests per hub. This minimizes task thread round-trips. The response contains multiple hub sections; normalize each into a separate ContentNode tree and assign to individual MediaRow widgets.

### Subtitle and Audio Track Selection

```
VideoPlayer receives media metadata (already fetched)
  -> processMediaInfo() extracts Stream[] from Part[0]
  -> Filter streams by streamType: 1=video, 2=audio, 3=subtitle
  -> Store in m.audioStreams[], m.subtitleStreams[]

User presses * (options) during playback
  -> Show PlaybackOverlay widget (new)
  -> PlaybackOverlay displays audio/subtitle track lists
  -> User selects track -> PlaybackOverlay.trackSelected fires
  -> VideoPlayer sets subtitle/audio via:
     - Embedded: m.video.globalCaptionMode / subtitleTrack
     - Sidecar SRT: fetch via PlexApiTask, inject into ContentNode
     - Burn-in: rebuild transcode URL with subtitleStreamID param
```

**Important:** Roku's built-in `Video` node supports embedded SRT/WebVTT subtitles natively. For ASS/SSA or PGS image-based subtitles, the only option is server-side burn-in via Plex transcode. Do NOT attempt to render these client-side.

### Music Playback

```
MusicScreen (new)
  -> Sidebar shows music libraries (type="artist" from /library/sections)
  -> Browse: /library/sections/{id}/all -> NormalizeArtistList()
  -> ArtistScreen -> /library/metadata/{id}/children -> NormalizeAlbumList()
  -> AlbumScreen -> /library/metadata/{id}/children -> NormalizeTrackList()

MusicPlayer (new widget, distinct from VideoPlayer)
  -> Uses roAudioPlayer (NOT roVideo) for audio-only content
  -> Manages play queue as ContentNode array
  -> NowPlayingBar (persistent widget in MainScene, not screen-scoped)
     -> Visible during music playback across all screens
     -> Shows track info, play/pause, progress
     -> Communicates with MusicPlayer via m.global fields
```

**Critical:** MusicPlayer must be a separate widget from VideoPlayer. `roVideo` works for music but wastes GPU resources. Audio playback also needs queue management (next/previous/shuffle/repeat) which is fundamentally different from video's single-item model. The NowPlayingBar must live in MainScene (outside screen stack) so it persists across screen navigation.

### Live TV and DVR

```
LiveTVScreen (new)
  -> Fetch /tv.plex.provider.epg/grid via PlexApiTask
  -> EPGGrid (new widget): time-based grid, channels on Y, time on X
  -> Channel select -> tune via /livetv/sessions (transcode-only, HLS)
  -> DVR: /media/subscriptions for recordings list -> standard grid browse

EPGGrid considerations:
  -> Large dataset: 100+ channels x 24 hours = 2400+ cells
  -> Must virtualize: only render visible portion
  -> Use Timer to shift grid as time progresses
  -> Roku MarkupGrid can handle this with careful ContentNode management
```

**Build order implication:** Live TV is the most complex new media type. It requires a custom EPGGrid widget that nothing else uses. Defer to a late phase.

### Photos

```
PhotoScreen (new)
  -> Browse: standard grid (reuse PosterGrid with different aspect ratio)
  -> Full-screen viewer: single Poster node, scaled to fit
  -> Slideshow: Timer-driven advancement through photo list
  -> No playback state management needed (simplest media type)
```

### Managed Users

```
UserPickerScreen (new, shown after server connection)
  -> Fetch /api/v2/home/users via PlexApiTask (plex.tv endpoint)
  -> Display user avatars in grid
  -> If user has PIN: show PINDialog (numeric keypad widget)
  -> On user selected: switch X-Plex-Token to user-specific token
  -> Store selected user in registry
  -> m.global.currentUser field for cross-component access
```

**Data flow impact:** Managed users change the auth token used for all API requests. `GetPlexHeaders()` in utils.brs must read the current user's token, not just the admin token. This is a cross-cutting concern that affects every API call.

## Patterns to Follow

### Pattern 1: Task Node Pooling

**What:** Reuse task nodes instead of creating new ones for each request.

**When:** Any screen that makes multiple sequential API calls (most screens).

**Why:** Creating a new `roSGNode("PlexApiTask")` allocates memory for the node, its fields, and its thread. Roku's garbage collection is not aggressive. Reusing tasks avoids this churn.

**Current state:** HomeScreen already does this correctly (creates `m.apiTask` once in `init()` and reuses). VideoPlayer creates a fire-and-forget task for scrobble. The scrobble pattern is acceptable for one-shot calls but should not be the default.

**Example:**
```brightscript
' GOOD: Reuse task (already done in HomeScreen)
sub init()
    m.apiTask = CreateObject("roSGNode", "PlexApiTask")
    m.apiTask.observeField("status", "onApiTaskStateChange")
end sub

sub loadData()
    m.apiTask.endpoint = "/some/endpoint"
    m.apiTask.params = { key: "value" }
    m.apiTask.control = "run"
end sub

' BAD: Creating new task per request
sub loadData()
    task = CreateObject("roSGNode", "PlexApiTask")  ' memory churn
    task.observeField("status", "onTaskDone")
    task.endpoint = "/some/endpoint"
    task.control = "run"
end sub
```

### Pattern 2: Normalizer-per-Media-Type

**What:** One normalizer function per Plex content type. Each returns a ContentNode tree with type-specific fields.

**When:** Adding support for new media types (music, photos, live TV).

**Why:** The existing normalizers (`NormalizeMovieList`, `NormalizeShowList`, etc.) establish this pattern well. Extending it keeps the data transform layer consistent and testable. Normalizers should be the ONLY place where raw Plex JSON field names appear.

**New normalizers needed:**
```brightscript
' source/normalizers.brs - add these
function NormalizeArtistList(jsonArray) as Object    ' music
function NormalizeAlbumList(jsonArray) as Object      ' music
function NormalizeTrackList(jsonArray) as Object      ' music
function NormalizePhotoList(jsonArray) as Object      ' photos
function NormalizeHubRow(jsonArray) as Object         ' hub rows (mixed types)
function NormalizeChannelList(jsonArray) as Object    ' live TV
function NormalizeEPGData(jsonArray) as Object        ' live TV guide
function NormalizePlaylist(jsonArray) as Object       ' playlists
function NormalizeUserList(jsonArray) as Object       ' managed users
```

### Pattern 3: Screen Interface Contract

**What:** Every screen exposes the same interface fields for MainScene to observe.

**When:** Adding any new screen.

**Why:** MainScene's `pushScreen()` blindly observes `itemSelected` and `navigateBack` on every screen. This contract must be maintained for the navigation stack to work.

**Required interface for all screens:**
```xml
<interface>
    <field id="itemSelected" type="assocarray" alwaysNotify="true" />
    <field id="navigateBack" type="boolean" alwaysNotify="true" />
</interface>
```

**Additional per-screen interface fields** (for MainScene to pass data in):
```xml
<!-- DetailScreen -->
<field id="ratingKey" type="string" />
<field id="itemType" type="string" />

<!-- MusicScreen (new) -->
<field id="sectionId" type="string" />

<!-- UserPickerScreen (new) -->
<field id="users" type="assocarray" />
```

### Pattern 4: Widget Cleanup Protocol

**What:** Every screen implements a `cleanup()` function that unobserves all fields, stops tasks, and releases resources.

**When:** On every `popScreen()` call.

**Why:** Roku leaks memory when observers are left connected to removed nodes. The existing `cleanupScreen()` in MainScene calls `screen.callFunc("cleanup")` if the field exists. This pattern must be followed consistently.

**Example:**
```brightscript
sub cleanup()
    ' Stop all tasks
    if m.apiTask <> invalid
        m.apiTask.control = "stop"
        m.apiTask.unobserveField("status")
    end if

    ' Unobserve child widgets
    m.sidebar.unobserveField("selectedLibrary")
    m.posterGrid.unobserveField("itemSelected")
    m.posterGrid.unobserveField("loadMore")
end sub
```

### Pattern 5: Action Routing via itemSelected

**What:** Screens signal navigation intent by setting `m.top.itemSelected = { action: "actionName", ...params }`. MainScene's `onItemSelected` dispatches to the appropriate `show*Screen()` method.

**When:** Adding new navigation targets.

**Why:** This is the existing pattern and it works well. It keeps screens decoupled from each other - a screen never creates another screen directly.

**Extending for new screens:**
```brightscript
' In MainScene.onItemSelected():
sub onItemSelected(event as Object)
    data = event.getData()
    if data <> invalid
        if data.action = "detail"
            showDetailScreen(data.ratingKey, data.itemType)
        else if data.action = "episodes"
            showEpisodeScreen(data.ratingKey, data.title)
        else if data.action = "search"
            showSearchScreen()
        else if data.action = "settings"
            showSettingsScreen()
        ' NEW actions:
        else if data.action = "artist"
            showArtistScreen(data.ratingKey)
        else if data.action = "album"
            showAlbumScreen(data.ratingKey)
        else if data.action = "playlist"
            showPlaylistScreen(data.ratingKey)
        else if data.action = "livetv"
            showLiveTVScreen()
        else if data.action = "photo"
            showPhotoScreen(data.ratingKey)
        else if data.action = "users"
            showUserPickerScreen()
        end if
    end if
end sub
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: God Screen

**What:** Putting all media-type-specific logic in a single screen (e.g., making HomeScreen handle music browse, photo browse, and video browse differently based on content type).

**Why bad:** BrightScript has no classes or inheritance. A single screen handling 5 media types becomes an unmaintainable if/else chain. Focus management becomes a nightmare.

**Instead:** Create separate screens per media type with shared widgets. `MusicScreen`, `PhotoScreen`, `LiveTVScreen` each compose `Sidebar`, `PosterGrid`, etc. as needed. Duplication of 10 lines of widget setup is preferable to 500 lines of conditional branching.

### Anti-Pattern 2: Task-to-Task Communication

**What:** Having one task node communicate directly with another task node.

**Why bad:** Roku requires all inter-task communication to go through the render thread, doubling rendezvous count. It also creates implicit dependencies between tasks.

**Instead:** Screen orchestrates: Task A completes -> screen processes -> sets up Task B. Sequential, explicit, debuggable.

### Anti-Pattern 3: Storing State in m.global

**What:** Using `m.global` as a general-purpose state store for user preferences, current library, current filter state, etc.

**Why bad:** Every field set on `m.global` triggers a rendezvous. Too many global observers create performance bottlenecks. State becomes hard to reason about when any component can read/write it.

**Instead:** Use `m.global` only for truly cross-cutting concerns: `authRequired` (boolean), `currentUserToken` (string), `nowPlaying` (assocarray for music bar). Everything else stays in screen-scoped `m.*` variables or is passed via interface fields.

### Anti-Pattern 4: Creating Renderable Nodes in Tasks

**What:** Building UI nodes (Labels, Posters, Rectangles) inside a Task thread.

**Why bad:** Every property set on a renderable node from a Task thread triggers a full rendezvous with the render thread. This serializes execution and destroys performance.

**Instead:** Tasks should return raw data (JSON parsed to associative arrays). Normalizers in the render thread build ContentNode trees. ContentNodes are non-renderable and can be created in either thread, but creating them in the render thread after task completion is simpler and avoids confusion.

### Anti-Pattern 5: Deep Observer Chains

**What:** Widget A observes Widget B, which observes Widget C, creating a chain of observer-triggered updates.

**Why bad:** Debugging becomes impossible. Field changes cascade unpredictably. One change triggers multiple re-renders.

**Instead:** Keep observer chains shallow (max 2 levels). Screen observes its direct child widgets. Widgets do NOT observe sibling widgets. If two widgets need to coordinate, the parent screen mediates.

## Maestro MVVM Migration Assessment

**Recommendation: Do NOT migrate. Confidence: HIGH.**

### Arguments For Maestro
- View lifecycle management (onShow, onHide, onFocus hooks)
- MVVM binding reduces boilerplate observer setup
- IOC container for dependency injection
- Unit testable view models via Rooibos
- Navigation framework (TabController, NavController)

### Arguments Against Maestro (for this project)
1. **Rewrite scope:** Every existing component needs conversion to BrighterScript + Maestro node classes. This is not incremental - it is a full rewrite of ~20 working components before any new features can be added.
2. **Build toolchain:** Requires `bsc` (BrighterScript compiler) + `maestro-cli` + `ropm` package manager. Current project deploys by zipping a folder. Adding a build step for a sideloaded personal channel adds friction with no offsetting team-productivity benefit.
3. **Single developer:** MVVM's benefits (testability, separation of concerns, team velocity) are most impactful on multi-developer projects. A solo developer already holds the full mental model.
4. **Debugging cost:** Maestro's generated code makes debugger stack traces harder to read. The compilation step adds a translation layer between what you write and what runs on the device.
5. **Lifecycle hooks already exist:** The current `cleanup()` pattern, `init()`, and `onKeyEvent()` provide the lifecycle hooks this app needs. Adding Maestro's `onShow`/`onHide`/`onFirstShow` hooks is nice but not necessary given the simple screen stack model.
6. **Project constraint:** PROJECT.md explicitly lists "BrighterScript v1.0.0-alpha migration -- defer until stable release" as out of scope. Maestro requires BrighterScript.

### What to Adopt Instead
Cherry-pick Maestro's best ideas without the framework:
- **Cleanup protocol:** Already implemented. Ensure consistency across all new screens.
- **Focus management:** Add a `saveFocusState()` / `restoreFocusState()` helper to utils.brs for screens that need to preserve complex focus positions.
- **Style centralization:** Keep using `GetConstants()` for all style values. Consider adding a `GetStyles()` function if component-level styling becomes repetitive.

## Suggested Component Inventory (Target ~40 Components)

### Screens (13 total, 6 new)

| Screen | Status | Dependencies | Phase Implication |
|--------|--------|-------------|-------------------|
| HomeScreen | Existing | Sidebar, PosterGrid, FilterBar, MediaRow | Enhance with hub rows early |
| DetailScreen | Existing | VideoPlayer | Enhance with resume, watched toggle |
| EpisodeScreen | Existing | EpisodeItem | Enhance with auto-play next |
| SearchScreen | Existing | PosterGrid | Stable |
| PINScreen | Existing | PlexAuthTask | Stable |
| ServerListScreen | Existing | ServerConnectionTask | Stable |
| SettingsScreen | Existing | None | Enhance with prefs |
| MusicScreen | **New** | Sidebar, PosterGrid/TrackList | Requires MusicPlayer widget first |
| PhotoScreen | **New** | PosterGrid, PhotoViewer | Relatively independent |
| LiveTVScreen | **New** | EPGGrid, VideoPlayer | Most complex, defer |
| PlaylistScreen | **New** | PosterGrid, TrackList | After music basics |
| UserPickerScreen | **New** | PINDialog | Early-ish (affects auth flow) |
| CollectionScreen | **New** | PosterGrid | Simple, reuses existing widgets |

### Widgets (16 total, 7 new)

| Widget | Status | Used By |
|--------|--------|---------|
| Sidebar | Existing | HomeScreen, MusicScreen |
| PosterGrid | Existing | HomeScreen, SearchScreen, PhotoScreen, CollectionScreen |
| PosterGridItem | Existing | PosterGrid |
| EpisodeItem | Existing | EpisodeScreen |
| FilterBar | Existing | HomeScreen |
| VideoPlayer | Existing | DetailScreen, LiveTVScreen |
| LoadingSpinner | Existing | All screens |
| MediaRow | Existing | HomeScreen (hub rows) |
| KeyboardDialog | Existing | SearchScreen |
| PlaybackOverlay | **New** | VideoPlayer (audio/subtitle selection, intro skip) |
| SubtitleRenderer | **New** | VideoPlayer (sidecar SRT display) |
| MusicPlayer | **New** | MusicScreen, MainScene (persists) |
| NowPlayingBar | **New** | MainScene (persistent during music playback) |
| PhotoViewer | **New** | PhotoScreen |
| EPGGrid | **New** | LiveTVScreen |
| TrackList | **New** | MusicScreen, PlaylistScreen |

### Tasks (6 total, 0 new)

| Task | Status | Notes |
|------|--------|-------|
| PlexApiTask | Existing | General-purpose, handles all new endpoints |
| PlexAuthTask | Existing | Extend for managed user token switching |
| PlexSearchTask | Existing | Stable |
| PlexSessionTask | Existing | Extend for music scrobbling |
| ServerConnectionTask | Existing | Stable |
| ImageCacheTask | Existing | Stable |

No new task types needed. `PlexApiTask` is general-purpose enough to handle all new API endpoints. Adding new tasks would fragment HTTP handling unnecessarily.

## Build Order (Dependency-Driven)

The dependencies between new components dictate the order in which features can be built:

```
Phase order by dependency chain:

1. PlaybackOverlay widget
   |- No dependencies on new components
   |- Unlocks: subtitle selection, audio selection, intro skip

2. Hub rows on HomeScreen
   |- Requires: MediaRow (existing), NormalizeHubRow (new normalizer)
   |- No new components, just HomeScreen enhancement

3. Filters and sorting
   |- Requires: FilterBar (existing, enhance)
   |- No new components

4. Resume/watched toggle on DetailScreen
   |- No new components, DetailScreen enhancement

5. Auto-play next episode
   |- Requires: EpisodeScreen enhancement
   |- Depends on: VideoPlayer playbackComplete handling

6. UserPickerScreen
   |- Requires: PINDialog enhancement
   |- Cross-cutting: changes auth token flow in utils.brs
   |- Should be done before features that depend on user context

7. CollectionScreen + PlaylistScreen
   |- Reuses: PosterGrid, existing patterns
   |- Simple screen additions

8. MusicPlayer + NowPlayingBar + MusicScreen + TrackList
   |- MusicPlayer must come first (new audio engine)
   |- NowPlayingBar depends on MusicPlayer
   |- MusicScreen depends on both + TrackList
   |- This is a connected cluster, build together

9. PhotoScreen + PhotoViewer
   |- Independent from everything else
   |- Can be built anytime after core patterns established

10. LiveTVScreen + EPGGrid
    |- Most complex new feature
    |- EPGGrid is unique widget (nothing reuses it)
    |- Depends on server having Live TV capability
    |- Build last
```

## Scalability Considerations

| Concern | At current size (~20 components) | At target (~40 components) | Mitigation |
|---------|----------------------------------|---------------------------|------------|
| MainScene routing | 5-case if/else in onItemSelected | 12+ case if/else | Acceptable. BrightScript has no better dispatch mechanism. Keep cases alphabetically sorted. |
| Screen stack memory | 2-3 screens deep | 4-5 screens deep (Home -> Artist -> Album -> Detail -> Player) | Add max depth check. Call `cleanup()` on all popped screens. Consider collapsing unnecessary intermediate screens. |
| Observer count | ~20 active observers | ~40+ active observers | Ensure `cleanup()` unobserves everything. Only observe fields you actively need. |
| ContentNode trees | Hundreds of nodes (library grid) | Thousands (EPG grid, music library) | Paginate aggressively. Use `removeChildIndex()` to trim old pages if memory is tight. |
| Task concurrency | 1-2 tasks running simultaneously | 3-4 (API + session + search + image cache) | Acceptable for Roku. Do not exceed 5 concurrent tasks. |
| normalizers.brs size | ~130 lines, 5 functions | ~300 lines, 14 functions | Consider splitting into `normalizers-video.brs`, `normalizers-music.brs`, `normalizers-livetv.brs` if file exceeds 400 lines. |

## Sources

- [Roku SceneGraph Core Concepts](https://developer.roku.com/docs/developer-program/core-concepts/core-concepts.md) - HIGH confidence
- [Roku Optimization Techniques](https://developer.roku.com/docs/developer-program/performance-guide/optimization-techniques.md) - HIGH confidence (accessed via search summaries)
- [Maestro-roku Documentation](https://georgejecook.github.io/maestro-roku/index.html) - HIGH confidence
- [Maestro View Framework](https://georgejecook.github.io/maestro-roku/4.%20View%20Framework/index.html) - HIGH confidence
- [Roku SceneGraph Threads](https://sdkdocs-archive.roku.com/SceneGraph-Threads_4262152.html) - HIGH confidence (rendezvous patterns)
- [Roku SceneGraph Benchmarks: AA vs Node](https://medium.com/dazn-tech/rokus-scenegraph-benchmarks-aa-vs-node-9be5158474c1) - MEDIUM confidence
- [Plex Labs RSG Application](https://medium.com/plexlabs/xml-code-good-times-rsg-application-b963f0cec01b) - MEDIUM confidence

---

*Architecture research: 2026-03-08*
