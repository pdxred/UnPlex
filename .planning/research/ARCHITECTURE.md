# Architecture Research: Roku Plex Client

**Domain:** Roku SceneGraph Media Browsing/Playback Application
**Researched:** 2026-02-09
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         UI Layer (Render Thread)                     │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────┐                                                        │
│  │MainScene │  Screen Stack Manager                                 │
│  └────┬─────┘                                                        │
│       │                                                              │
│  ┌────┴──────┬──────────┬──────────┬──────────┬──────────┐         │
│  │           │          │          │          │          │          │
│  │HomeScreen │ Detail   │ Episodes │ Search   │ Settings │ ...      │
│  │           │ Screen   │ Screen   │ Screen   │ Screen   │          │
│  └─────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┘         │
│        │          │          │          │          │                │
│  ┌─────┴──────────┴──────────┴──────────┴──────────┴─────┐         │
│  │     Shared Widgets (Sidebar, PosterGrid, etc.)        │         │
│  └────────────────────────────┬───────────────────────────┘         │
│                               │ observeField()                      │
├───────────────────────────────┼─────────────────────────────────────┤
│         Task Layer (Background Threads - Max 100)                   │
├───────────────────────────────┴─────────────────────────────────────┤
│  ┌───────────┐  ┌──────────┐  ┌────────────┐  ┌─────────────┐     │
│  │ PlexAuth  │  │ PlexAPI  │  │ PlexSearch │  │ PlexSession │     │
│  │   Task    │  │   Task   │  │    Task    │  │    Task     │     │
│  └─────┬─────┘  └────┬─────┘  └──────┬─────┘  └──────┬──────┘     │
│        │             │               │               │             │
│        └─────────────┴───────────────┴───────────────┘             │
│                              │                                      │
│                    roUrlTransfer (HTTPS)                            │
├──────────────────────────────┴──────────────────────────────────────┤
│                     External Services                                │
│              Plex Media Server API + plex.tv                         │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **MainScene** | Root scene, screen stack management, global state initialization | Single SceneGraph Group node with screen array, back button handling |
| **Screen Components** | Full-screen views (Home, Detail, Episodes, Search, Settings) | SceneGraph Group nodes with focused state, key event handling, screen-specific layouts |
| **Widget Components** | Reusable UI elements (Sidebar, PosterGrid, VideoPlayer, FilterBar) | SceneGraph components with interface fields for data binding |
| **Task Nodes** | Background HTTP operations, API communication, data transformation | SceneGraph Task nodes extending Task base class, run in separate threads |
| **Utility Layer** | Shared helpers (auth tokens, URL building, header generation) | BrightScript .brs files in source/ directory with namespace functions |
| **Global State** | App-wide shared state (auth token, server URL, user preferences) | m.global node with custom fields, accessed via m.global.fieldName |

## Recommended Project Structure

```
PlexClassic/
├── manifest                    # App metadata, SceneGraph version (RSG 1.3 required by Oct 2026)
├── source/                     # BrightScript utility files (render thread)
│   ├── main.brs               # Entry point - creates MainScene, message loop
│   ├── utils.brs              # Shared helpers (GetPlexHeaders, BuildPlexUrl, etc.)
│   └── constants.brs          # Colors, sizes, API endpoints
├── components/                 # SceneGraph components (.xml + .brs pairs)
│   ├── MainScene.xml          # Root scene
│   ├── MainScene.brs          # Screen stack logic, navigation
│   ├── screens/               # Full-screen views
│   │   ├── HomeScreen.xml/.brs
│   │   ├── DetailScreen.xml/.brs
│   │   ├── EpisodesScreen.xml/.brs
│   │   ├── SearchScreen.xml/.brs
│   │   └── SettingsScreen.xml/.brs
│   ├── widgets/               # Reusable UI components
│   │   ├── Sidebar.xml/.brs
│   │   ├── PosterGrid.xml/.brs
│   │   ├── VideoPlayer.xml/.brs
│   │   └── FilterBar.xml/.brs
│   └── tasks/                 # Background Task nodes
│       ├── PlexAuthTask.xml/.brs      # PIN auth + server discovery
│       ├── PlexApiTask.xml/.brs       # General API requests
│       ├── PlexSearchTask.xml/.brs    # Search with debouncing
│       ├── PlexSessionTask.xml/.brs   # Playback progress reporting
│       └── ImageCacheTask.xml/.brs    # Poster prefetching
└── images/                     # App icons, splash, placeholders
    ├── splash_hd.jpg
    ├── mm_icon_focus_hd.png
    └── poster_placeholder.png
```

### Structure Rationale

- **source/ for utilities**: BrightScript files here are loaded on the render thread at startup. Use for stateless helper functions only (no HTTP operations).
- **components/ organized by role**: Screens vs widgets vs tasks creates clear boundaries. Screens are full-screen views, widgets are reusable, tasks are background workers.
- **XML + BRS pairs**: Every SceneGraph component consists of `.xml` (layout + interface) and `.brs` (logic). Keep them adjacent for maintainability.
- **tasks/ directory isolation**: Makes it obvious which components run in background threads. Critical for avoiding render thread blocking.

## Architectural Patterns

### Pattern 1: Screen Stack Navigation

**What:** MainScene maintains an array of screen component nodes. Pushing/popping this stack handles navigation and back button behavior.

**When to use:** All multi-screen Roku apps. Roku has no built-in back stack like Android/iOS, so manual implementation is required.

**Trade-offs:**
- **Pros:** Full control over navigation flow, focus restoration, screen lifecycle
- **Cons:** More code than platform-provided navigation, must handle memory cleanup manually

**Example:**
```brightscript
' MainScene.brs
sub pushScreen(screenType as string, params = {} as object)
    screen = createObject("roSGNode", screenType)
    for each key in params
        screen[key] = params[key]
    end for

    ' Hide current screen if exists
    if m.screenStack.count() > 0
        m.screenStack.peek().visible = false
    end if

    m.screenStack.push(screen)
    m.top.appendChild(screen)
    screen.setFocus(true)
end sub

sub popScreen()
    if m.screenStack.count() > 1
        oldScreen = m.screenStack.pop()
        m.top.removeChild(oldScreen)

        ' Restore focus to previous screen
        currentScreen = m.screenStack.peek()
        currentScreen.visible = true
        currentScreen.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press and key = "back"
        popScreen()
        return true ' Consume event
    end if
    return false ' Allow propagation
end function
```

### Pattern 2: Task Node Communication (Observer Pattern)

**What:** UI components create Task nodes, observe their output fields, then trigger execution. Task nodes fetch data asynchronously and update observable fields when complete.

**When to use:** All HTTP requests, any operation taking >16ms (one frame at 60fps). Roku's render thread MUST remain responsive.

**Trade-offs:**
- **Pros:** Non-blocking UI, avoids rendezvous crashes, follows Roku best practices
- **Cons:** More verbose than synchronous code, requires field observer setup/cleanup

**Example:**
```brightscript
' HomeScreen.brs
sub init()
    m.apiTask = createObject("roSGNode", "PlexApiTask")
    m.apiTask.observeField("content", "onContentLoaded")
    m.apiTask.observeField("error", "onApiError")
end sub

sub loadLibrary(sectionId as integer)
    m.apiTask.endpoint = "/library/sections/" + sectionId.toStr() + "/all"
    m.apiTask.params = {
        "X-Plex-Container-Start": 0,
        "X-Plex-Container-Size": 50
    }
    m.apiTask.control = "run" ' Triggers Task execution
end sub

sub onContentLoaded(event as object)
    contentNode = event.getData()
    m.posterGrid.content = contentNode ' Bind to UI
    ' IMPORTANT: Unobserve to prevent memory leaks in long-running apps
    ' m.apiTask.unobserveField("content")
end sub
```

### Pattern 3: ContentNode Data Trees

**What:** Use ContentNode hierarchies instead of associative arrays for structured data. ContentNodes are passed by reference (not copied), improving performance for large datasets.

**When to use:** Populating grids, lists, or any UI component consuming structured data. Required for MarkupGrid, PosterGrid, RowList, LabelList components.

**Trade-offs:**
- **Pros:** Much faster than associative arrays (reference vs copy), extends easily with custom fields
- **Cons:** Slightly more verbose than plain AA, requires understanding node field API

**Example:**
```brightscript
' PlexApiTask.brs - Convert JSON response to ContentNode tree
function buildContentNode(jsonData as object) as object
    rootNode = createObject("roSGNode", "ContentNode")

    for each item in jsonData.Metadata
        child = createObject("roSGNode", "ContentNode")
        child.title = item.title
        child.hdPosterUrl = buildPosterUrl(item.thumb, 240, 360)
        child.description = item.summary
        child.ratingKey = item.ratingKey
        child.contentType = item.type

        ' Custom fields for Plex-specific data
        child.addFields({
            plexKey: item.key,
            year: item.year,
            rating: item.contentRating
        })

        rootNode.appendChild(child)
    end for

    return rootNode
end function
```

### Pattern 4: API Abstraction Layer (Service Pattern)

**What:** Centralize API logic in Task nodes that expose clean interfaces. UI components request operations via Task fields, not raw HTTP details.

**When to use:** Any app consuming external APIs. Future-proofs against API changes, reduces duplication.

**Trade-offs:**
- **Pros:** Single source of truth for API logic, easier testing, cleaner UI code
- **Cons:** Extra layer of indirection, requires planning interface fields

**Example:**
```brightscript
' PlexApiTask.xml - Interface definition
<interface>
    <field id="endpoint" type="string" />
    <field id="params" type="assocarray" />
    <field id="method" type="string" value="GET" />

    <field id="content" type="node" alwaysNotify="true" />
    <field id="error" type="string" alwaysNotify="true" />
</interface>

' PlexApiTask.brs - Implementation
sub execute()
    url = m.global.serverUrl + m.top.endpoint

    ' Add query params
    if m.top.params <> invalid and m.top.params.count() > 0
        url = url + "?" + buildQueryString(m.top.params)
    end if

    transfer = createObject("roUrlTransfer")
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()

    ' Add Plex headers (abstracted via utility function)
    headers = GetPlexHeaders(m.global.authToken)
    for each key in headers
        transfer.AddHeader(key, headers[key])
    end for

    response = transfer.GetToString()
    if response <> ""
        xmlData = ParseXml(response)
        m.top.content = buildContentNode(xmlData)
    else
        m.top.error = "Network request failed"
    end if
end sub
```

### Pattern 5: Global State via m.global

**What:** Use the global node (m.global) for app-wide state like auth tokens, server URLs, and user preferences. Accessible from all components.

**When to use:** Data needed across multiple screens/components. Avoid for local component state.

**Trade-offs:**
- **Pros:** Simple shared state, observable fields trigger updates across app
- **Cons:** Global state can become dumping ground, requires discipline to keep clean

**Example:**
```brightscript
' MainScene.brs - Initialize global state
sub init()
    m.global = m.top.getGlobalNode()
    m.global.addFields({
        authToken: "",
        serverUrl: "",
        userName: "",
        isAuthenticated: false
    })

    ' Load from registry (persistent storage)
    registry = createObject("roRegistrySection", "PlexClassic")
    if registry.Exists("authToken")
        m.global.authToken = registry.Read("authToken")
        m.global.serverUrl = registry.Read("serverUrl")
        m.global.isAuthenticated = true
    end if
end sub

' Any component can access
sub someFunction()
    token = m.global.authToken
    if m.global.isAuthenticated
        ' Proceed with authenticated request
    end if
end sub
```

## Data Flow

### Request Flow (API Data Fetching)

```
[User Action] (e.g., select library in Sidebar)
    ↓
[Screen Component] (e.g., HomeScreen.brs:onLibrarySelected)
    ↓ Set Task fields
[Task Node] (e.g., PlexApiTask.endpoint = "/library/sections/1/all")
    ↓ m.task.control = "run"
[Task Thread Executes]
    ↓ roUrlTransfer HTTP request
[Plex Media Server] returns XML/JSON
    ↓
[Task parses response] → ContentNode tree
    ↓ m.top.content = contentNode
[Field Observer Fires] (Screen observes Task.content)
    ↓
[Screen Updates UI] m.posterGrid.content = contentNode
    ↓
[User sees posters] rendered by built-in PosterGrid
```

### Playback Flow

```
[User selects item] in PosterGrid
    ↓
[Screen pushes DetailScreen] with ratingKey
    ↓
[DetailScreen loads metadata] via PlexApiTask
    ↓
[User presses Play]
    ↓
[DetailScreen pushes VideoPlayer] with streamUrl + metadata
    ↓
[VideoPlayer.brs sets content]
    m.player.content = createPlaybackContentNode(streamUrl, metadata)
    m.player.control = "play"
    ↓
[Native Roku Video Node] begins playback
    ↓
[VideoPlayer observes position] m.player.observeField("position")
    ↓
[PlexSessionTask reports progress] PUT /:/timeline every 10 seconds
    ↓
[On playback end/back] pop VideoPlayer, restore DetailScreen focus
```

### State Management Flow

```
[App Launch]
    ↓
[MainScene.init()]
    ↓ Initialize m.global fields
    ↓ Read roRegistrySection("PlexClassic")
    ↓
[If authenticated] → Push HomeScreen
[Else] → Push AuthScreen
    ↓
[AuthScreen] creates PlexAuthTask
    ↓ Observe authToken field
    ↓ Task polls plex.tv PIN endpoint
    ↓
[On auth success] Task sets m.global.authToken
    ↓ Field observer fires in AuthScreen
    ↓ Write to registry.Write("authToken")
    ↓ registry.Flush()
    ↓
[MainScene observes m.global.isAuthenticated]
    ↓ Pop AuthScreen
    ↓ Push HomeScreen
```

### Key Data Flows

1. **UI → Task → API → Task → UI (Observer)**: All external data fetching follows this pattern. UI never blocks on network.
2. **m.global as shared state**: Auth state, server config, user prefs flow through global node fields with observers.
3. **ContentNode trees for lists/grids**: Data from API transforms to ContentNode hierarchies, bound to UI components via .content field.
4. **Registry for persistence**: On auth success or settings change, write to roRegistrySection and call .Flush(). Read on app launch.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-10K items | Standard ContentNode trees work fine. Use pagination (X-Plex-Container-Start/Size=50) on library fetches. |
| 10K-100K items | Implement lazy loading: only fetch visible items + buffer. Use ImageCacheTask to prefetch next page of posters. Monitor memory via Roku Resource Monitor. |
| 100K+ items | Virtual scrolling may be needed. Consider RowList for section-based browsing instead of flat PosterGrid. Profile with Perfetto to identify bottlenecks. |

### Scaling Priorities

1. **First bottleneck: Image memory usage**
   - **Problem:** Loading too many high-res posters causes memory pressure on low-tier Roku devices.
   - **Solution:** Request resized images via Plex transcode API (`/photo/:/transcode?width=240&height=360`). Implement image cache eviction in ImageCacheTask.

2. **Second bottleneck: ContentNode deep-copy overhead**
   - **Problem:** Accessing node fields triggers deep copies on render thread, slowing down large datasets.
   - **Solution:** Use Roku OS 15.0+ APIs to move associative arrays by reference instead of copying. Minimize field accesses in loops. Prefer task thread data manipulation.

## Anti-Patterns

### Anti-Pattern 1: HTTP on Render Thread

**What people do:** Call roUrlTransfer.GetToString() directly in screen component .brs file.

**Why it's wrong:** Blocks render thread for duration of network request (100ms-5s+). Causes UI freezes, dropped frames, and rendezvous crashes under load. Fails Roku certification testing.

**Do this instead:** Always use Task nodes for HTTP. Example:
```brightscript
' WRONG - Render thread blocks
sub loadData()
    url = createObject("roUrlTransfer")
    url.SetUrl("https://...")
    response = url.GetToString() ' BLOCKS UI!
    parseResponse(response)
end sub

' CORRECT - Task node
sub loadData()
    m.apiTask.endpoint = "/data"
    m.apiTask.control = "run" ' Non-blocking
end sub
```

### Anti-Pattern 2: Forgetting to Unobserve Fields

**What people do:** Call observeField() on Task nodes but never unobserveField(), especially in components created/destroyed frequently.

**Why it's wrong:** Each observeField() adds a callback. Repeated calls without unobserve accumulate callbacks, causing the same function to fire multiple times and creating memory leaks. Long-running channels slow down or crash.

**Do this instead:** Unobserve when observer is no longer needed or component is destroyed.
```brightscript
' WRONG - Leaks observers
sub loadData()
    m.apiTask.observeField("content", "onContentLoaded") ' Called repeatedly
    m.apiTask.control = "run"
end sub

' CORRECT - Cleanup
sub loadData()
    m.apiTask.unobserveField("content") ' Remove old observers first
    m.apiTask.observeField("content", "onContentLoaded")
    m.apiTask.control = "run"
end sub

sub onContentLoaded(event as object)
    ' Process data
    m.apiTask.unobserveField("content") ' Clean up after use
end sub
```

### Anti-Pattern 3: Storing Associative Arrays in Node Fields

**What people do:** Store large data structures as associative arrays in SceneGraph node fields, accessing them frequently.

**Why it's wrong:** Every field access deep-copies the entire associative array. For large datasets, this causes severe performance degradation on the render thread. As noted in Roku docs: "myVar = myNode.myField marshals/unmarshals the structure underneath."

**Do this instead:** Use ContentNode trees (passed by reference) or perform data manipulation in Task threads.
```brightscript
' WRONG - Deep copy on every access
m.dataNode.movieList = largeAssociativeArray ' Copy on write
for i = 0 to m.dataNode.movieList.count() - 1 ' Copy on read!
    movie = m.dataNode.movieList[i] ' Copy again!
end for

' CORRECT - ContentNode tree (by reference)
contentNode = createObject("roSGNode", "ContentNode")
for each movie in jsonData
    child = createObject("roSGNode", "ContentNode")
    child.title = movie.title
    contentNode.appendChild(child) ' No copies
end for
m.posterGrid.content = contentNode ' Reference assignment
```

### Anti-Pattern 4: Creating Node Reference Cycles

**What people do:** Store references to ancestor nodes in child fields, or create circular references between nodes.

**Why it's wrong:** Creates memory leaks. Roku's garbage collector can't free nodes in isolated cycles, even when the app no longer references them. Channels accumulate leaked nodes and eventually crash.

**Do this instead:** Use one-way references (parent → child only). Set fields to invalid when done.
```brightscript
' WRONG - Circular reference
m.childNode.parentRef = m.top ' Child references ancestor

' CORRECT - One-way only
' Child communicates up via interface fields parent observes
m.top.observeField("childEvent", "onChildEvent")
' No direct parent reference stored in child

' Cleanup when removing nodes
sub removeScreen(screen)
    screen.visible = false
    m.top.removeChild(screen)
    screen = invalid ' Break reference
end sub
```

### Anti-Pattern 5: Using SGDEX for Custom Requirements

**What people do:** Adopt SceneGraph Developer Extensions (SGDEX) framework to quickly scaffold an app, then struggle to implement custom features.

**Why it's wrong:** SGDEX is designed for simple, template-based channels. It handles common cases well but becomes a limiting factor when custom navigation, complex state management, or unique UI patterns are required. Developers end up fighting the framework.

**Do this instead:** For custom apps like PlexClassic, build components from scratch using base SceneGraph. Only use SGDEX if requirements exactly match its templates.
```brightscript
' SGDEX is good for: Simple grid → detail → video flow with no custom logic
' Custom SceneGraph is required for:
'   - Custom screen stack navigation
'   - Complex authentication flows (PIN-based OAuth)
'   - Multi-server management
'   - Advanced filtering/search
'   - Custom video player controls
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **Plex Media Server** | REST API via PlexApiTask (Task node) | All requests need X-Plex-* headers. Use GetPlexHeaders() utility. Paginate with X-Plex-Container-Start/Size. |
| **plex.tv** | OAuth PIN flow via PlexAuthTask | POST /api/v2/pins, poll GET /api/v2/pins/{id}, GET /api/v2/resources for server discovery. Strong PIN recommended. |
| **Image CDN** | Plex photo transcode API | Request `/photo/:/transcode?url={thumb}&width=240&height=360` for resized posters. Reduces memory usage. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **Screen ↔ Task** | Field observers (observeField/unobserveField) | Screen sets Task input fields, observes output fields. Task updates fields when work completes. |
| **Screen ↔ Widget** | Interface fields + observers | Widgets expose interface fields (e.g., PosterGrid.content). Screens set fields and observe events (itemSelected). |
| **MainScene ↔ Screen** | Direct function calls (pushScreen/popScreen) | Screens call m.top.getParent() to access MainScene, then invoke navigation functions. Alternative: MainScene observes screen.navigateEvent field. |
| **Any component ↔ Global State** | m.global.fieldName | Read/write global fields directly. Observe for reactive updates. No message passing needed. |
| **Utility functions ↔ Components** | Direct function calls | utils.brs functions are loaded at startup, callable from any .brs file via namespace or direct name. |

## Build Order & Dependencies

### Phase 1: Foundation (No UI dependencies)

**Build first:**
1. **manifest** - Defines app metadata, SceneGraph version (declare RSG 1.3 support)
2. **source/constants.brs** - Colors, sizes, API endpoints
3. **source/utils.brs** - GetPlexHeaders(), BuildPlexUrl(), registry helpers
4. **components/tasks/PlexAuthTask.xml/.brs** - PIN auth, can be tested standalone
5. **components/tasks/PlexApiTask.xml/.brs** - General API requests

**Why this order:** Tasks have no UI dependencies. Can be tested via Roku debug console before building screens. Establishes data layer first.

### Phase 2: Core UI (Depends on Foundation)

**Build next:**
6. **components/MainScene.xml/.brs** - Initialize m.global, implement screen stack
7. **components/screens/AuthScreen.xml/.brs** - Uses PlexAuthTask
8. **components/widgets/Sidebar.xml/.brs** - Reusable navigation widget
9. **components/screens/HomeScreen.xml/.brs** - Uses PlexApiTask + Sidebar

**Why this order:** MainScene is root, must exist first. AuthScreen can function with just PlexAuthTask. Sidebar is independent, used by HomeScreen.

### Phase 3: Content Browsing (Depends on Core UI + Foundation)

**Build next:**
10. **components/widgets/PosterGrid.xml/.brs** - Uses built-in MarkupGrid
11. **components/screens/DetailScreen.xml/.brs** - Uses PlexApiTask
12. **components/screens/EpisodesScreen.xml/.brs** - Uses PlexApiTask + PosterGrid

**Why this order:** PosterGrid is reused by multiple screens. DetailScreen is entry point to EpisodesScreen.

### Phase 4: Advanced Features (Depends on all previous)

**Build last:**
13. **components/tasks/PlexSearchTask.xml/.brs** - Debounced search
14. **components/screens/SearchScreen.xml/.brs** - Uses PlexSearchTask
15. **components/widgets/VideoPlayer.xml/.brs** - Wraps built-in Video node
16. **components/tasks/PlexSessionTask.xml/.brs** - Playback progress reporting
17. **components/tasks/ImageCacheTask.xml/.brs** - Poster prefetching optimization
18. **components/screens/SettingsScreen.xml/.brs** - Configuration UI

**Why this order:** Search and video playback depend on stable data layer and navigation. Image caching is performance optimization, not core functionality. Settings is last as it's non-critical.

### Dependency Graph

```
manifest + constants.brs + utils.brs
    ↓
PlexAuthTask + PlexApiTask (no UI dependencies)
    ↓
MainScene (depends on: utils, constants)
    ↓
AuthScreen (depends on: MainScene, PlexAuthTask)
    ↓
Sidebar (independent widget)
    ↓
HomeScreen (depends on: MainScene, PlexApiTask, Sidebar)
    ↓
PosterGrid (independent widget)
    ↓
DetailScreen (depends on: MainScene, PlexApiTask, PosterGrid)
    ↓
EpisodesScreen (depends on: MainScene, PlexApiTask, PosterGrid)
    ↓
PlexSearchTask + SearchScreen (depends on: all above)
    ↓
VideoPlayer + PlexSessionTask (depends on: all above)
    ↓
ImageCacheTask (performance optimization, depends on: all above)
    ↓
SettingsScreen (depends on: MainScene, registry utils)
```

## Sources

**Official Roku Documentation:**
- [Roku SceneGraph Overview](https://developer.roku.com/docs/developer-program/core-concepts/scenegraph-xml/overview.md) - Core concepts, HIGH confidence
- [Task Node Reference](https://developer.roku.com/docs/references/scenegraph/control-nodes/task.md) - Threading patterns, HIGH confidence
- [Component Architecture](https://developer.roku.com/docs/references/brightscript/language/component-architecture.md) - Component patterns, HIGH confidence
- [Data Management Guide](https://developer.roku.com/docs/developer-program/performance-guide/data-management.md) - ContentNode vs AA performance, HIGH confidence

**Official Roku Repositories:**
- [SceneGraph Master Sample](https://github.com/rokudev/scenegraph-master-sample) - Certification-compliant architecture example, HIGH confidence
- [SceneGraph Developer Extensions](https://github.com/rokudev/SceneGraphDeveloperExtensions) - SGDEX patterns and limitations, HIGH confidence
- [PosterGrid and Tasks Training](https://github.com/rymawby/SceneGraphTrainingPosterGridAndTasks) - Task node tutorial, MEDIUM confidence

**2026 Updates:**
- [New Roku Features 2026](https://www.oxagile.com/article/roku-features/) - RSG 1.3 requirement, OS 15.0 APIs, MEDIUM confidence
- [Developer Blog](https://blog.roku.com/developer) - Official announcements, HIGH confidence

**Architecture Patterns:**
- [Navigating Screen Stacks in Roku](https://medium.com/@amitdogra70512/navigating-screen-stacks-in-roku-a-guide-to-creating-and-managing-multiple-screens-using-arrays-1f9cbb736079) - Screen stack implementation, MEDIUM confidence
- [Understanding Threads in Roku Development](https://medium.com/@amitdogra70512/understanding-threads-in-roku-development-d890fa2fa9b5) - Task node threading, MEDIUM confidence
- [m.global Guide](https://medium.com/@amitdogra70512/m-vs-m-top-vs-m-global-in-brighscript-a389b4fb4d77) - Global state patterns, MEDIUM confidence
- [Component Initialization Order](https://medium.com/@amitdogra70512/understanding-component-initialization-order-in-roku-1ae0ed49472d) - Build dependencies, MEDIUM confidence

**Performance & Anti-Patterns:**
- [High-Performance Roku Development](https://www.tothenew.com/blog/revealing-the-secrets-to-high-performance-roku-development/) - Memory leaks, observer cleanup, MEDIUM confidence
- [Roku Resource Monitor](https://blog.roku.com/developer/resource-monitor) - Performance profiling tool, HIGH confidence
- [ContentNode Performance Discussion](http://forums.roku.com/viewtopic.php?t=101461) - AA vs ContentNode benchmarks, MEDIUM confidence

**Community Resources:**
- [Screen Stack Management](https://roku.home.blog/2019/01/02/back-stack-management-in-roku-using-scenegraph-component/) - Navigation patterns, MEDIUM confidence
- [Observer Pattern Best Practices](https://erpsolutionsoodles.medium.com/observe-field-in-roku-4d60b103d10b) - Field observation gotchas, MEDIUM confidence

**API Abstraction Examples:**
- [roku-fetch](https://github.com/briandunnington/roku-fetch) - Fetch-like abstraction, MEDIUM confidence
- [roku-requests](https://github.com/rokucommunity/roku-requests) - Requests-inspired abstraction, MEDIUM confidence
- [mParticle Roku SDK](https://github.com/mParticle/mparticle-roku-sdk) - Bridge pattern example, MEDIUM confidence

---
*Architecture research for: PlexClassic Roku Plex Client*
*Researched: 2026-02-09*
*All patterns verified against official Roku documentation and community best practices*
