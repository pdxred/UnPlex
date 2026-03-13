# Codebase Structure

**Analysis Date:** 2026-03-13

## Directory Layout

```
SimPlex/
├── manifest                 # Roku app metadata (version, icons, splash)
├── source/                  # BrightScript utilities and entry point
│   ├── main.brs            # Entry point - creates screen and event loop
│   ├── utils.brs           # Auth, URL building, safe field access, Plex headers
│   ├── constants.brs       # Layout, colors, API metadata
│   ├── logger.brs          # LogEvent/LogError functions
│   ├── normalizers.brs     # JSON → ContentNode transformers
│   └── capabilities.brs    # Device capability detection
├── components/
│   ├── MainScene.brs/.xml  # Root scene, screen stack management, auth flow
│   ├── screens/            # Full-screen views
│   │   ├── HomeScreen.brs/.xml           # Library browsing with sidebar + grid + hubs
│   │   ├── DetailScreen.brs/.xml         # Item metadata + play button
│   │   ├── EpisodeScreen.brs/.xml        # Episode list for a show
│   │   ├── SearchScreen.brs/.xml         # Search input + results grid
│   │   ├── PlaylistScreen.brs/.xml       # Playlist item browsing
│   │   ├── SettingsScreen.brs/.xml       # User/server/library management
│   │   ├── PINScreen.brs/.xml            # OAuth PIN auth flow
│   │   ├── UserPickerScreen.brs/.xml     # User selection modal
│   │   └── ServerListScreen.brs/.xml     # Server discovery and selection
│   ├── widgets/            # Reusable components
│   │   ├── Sidebar.brs/.xml              # Library + nav list (MarkupList)
│   │   ├── SidebarNavItem.brs/.xml       # Custom MarkupList item for Sidebar
│   │   ├── PosterGrid.brs/.xml           # Grid of movie/show posters
│   │   ├── PosterGridItem.brs/.xml       # Single poster + progress badge
│   │   ├── VideoPlayer.brs/.xml          # Video playback + skip markers + auto-play
│   │   ├── TrackSelectionPanel.brs/.xml  # Audio/subtitle track selection
│   │   ├── FilterBar.brs/.xml            # Genre/sort filter controls
│   │   ├── FilterBottomSheet.brs/.xml    # Filter options modal
│   │   ├── EpisodeItem.brs/.xml          # Single episode in list
│   │   ├── MediaRow.brs/.xml             # Hub row with media items
│   │   ├── PlaylistItem.brs/.xml         # Single playlist in list
│   │   ├── UserAvatarItem.brs/.xml       # User avatar + name
│   │   ├── LibrarySettingItem.brs/.xml   # Pinned library in settings (MarkupList item)
│   │   ├── KeyboardDialog.brs/.xml       # Soft keyboard for text input
│   │   ├── LoadingSpinner.brs/.xml       # Loading animation
│   │   ├── AlphaNav.brs/.xml             # Alphabetic jump nav (A-Z)
│   │   └── [other widgets]
│   └── tasks/              # Background HTTP request nodes
│       ├── PlexApiTask.brs/.xml          # General library/metadata API calls
│       ├── PlexAuthTask.brs/.xml         # PIN polling + plex.tv auth
│       ├── PlexSearchTask.brs/.xml       # Search query with debouncing
│       ├── PlexSessionTask.brs/.xml      # Playback progress reporting
│       ├── ServerConnectionTask.brs/.xml # Server URI validation
│       └── ImageCacheTask.brs/.xml       # Poster image prefetching
└── images/
    ├── icon_focus_fhd.png       # Focus remote guide icon (1920x1080)
    ├── icon_side_fhd.png        # Side remote guide icon (1920x1080)
    ├── icon_focus_hd.png        # Focus remote guide icon (1280x720) - fallback
    ├── icon_side_hd.png         # Side remote guide icon (1280x720) - fallback
    └── splash_fhd.jpg           # Launch splash screen (1920x1080, 1.5s display)
```

## Directory Purposes

**source/**
- Purpose: Shared utilities, entry point, and application-wide constants
- Contains: Main loop, auth management, API helpers, logging, data transformers
- Key files:
  - `main.brs`: App initialization and event loop
  - `utils.brs`: Registry access (auth tokens, server URI, pinned libraries), Plex header generation, URL builders, safe field access patterns
  - `constants.brs`: Colors (0xRRGGBBAA hex), layout dimensions (sidebar width 340, poster 240x360), Plex API metadata
  - `logger.brs`: Log/LogError/LogEvent utility functions
  - `normalizers.brs`: Converts Plex API JSON responses (movie lists, episodes, on-deck, etc.) to ContentNode trees

**components/screens/**
- Purpose: Full-screen views for major user flows
- Contains: Screen components that extend `Group` or `Scene`, manage multiple widgets, handle complex navigation
- Screens manage their own state (currentLibraryId, filters, focusPosition, etc.)
- Each screen observes child widget events (itemSelected, filterChanged, etc.) and coordinates MainScene navigation

**components/widgets/**
- Purpose: Reusable UI components composed into screens
- Contains: Focused components like grids, lists, sidebars, dialogs, media controls
- Widgets communicate upward to parent screen via field observers (itemSelected, filterChanged, etc.)
- Examples:
  - `PosterGrid` + `PosterGridItem`: Grid of movies/shows with optional progress badges
  - `Sidebar` + `SidebarNavItem`: Navigation sidebar with library list and action items (Home, Settings, etc.)
  - `VideoPlayer`: Full-screen video playback with skip markers, track selection, auto-play
  - `FilterBar` + `FilterBottomSheet`: Genre/sort filter controls with modal filter options

**components/tasks/**
- Purpose: Background HTTP request handling (never on render thread)
- Contains: Task nodes that read input fields, perform async HTTP work, write output to status/response/error fields
- All Plex API calls go through tasks (PlexApiTask, PlexAuthTask, etc.)
- Task pattern: Set control="run" to trigger execution, observe status field ("loading" → "success"/"error")

**images/**
- Purpose: Roku app assets (icons, splash screen)
- FHD (1920x1080): Primary resolution for modern Roku devices
- HD (1280x720): Fallback for older Roku devices
- Splash: 1920x1080 JPG, displays for `splash_min_time` (1500ms per manifest)

**manifest**
- Purpose: Roku app metadata and configuration
- Contains: App title, version (major.minor.build), icon/splash URIs, feature flags (input launch, RSG version)

## Key File Locations

**Entry Points:**
- `SimPlex/source/main.brs`: Application entry point - creates roSGScreen, instantiates MainScene, runs event loop
- `SimPlex/components/MainScene.brs`: Root coordinator - manages screen stack, auth flow, global state
- `SimPlex/source/constants.brs`: Cached in `m.global.constants` at MainScene.init() for all components to access

**Configuration:**
- `SimPlex/manifest`: App version, icons, splash screen, feature flags
- `SimPlex/source/constants.brs`: Colors, layout dimensions, Plex API metadata
- `SimPlex/source/utils.brs`: Registry functions for persistent auth and library settings

**Core Logic:**
- `SimPlex/components/screens/HomeScreen.brs`: Library browsing, hub display, sidebar interaction, filtering
- `SimPlex/components/screens/DetailScreen.brs`: Item metadata display, playback button, mark watched
- `SimPlex/components/screens/PINScreen.brs`: OAuth PIN polling and server discovery
- `SimPlex/components/MainScene.brs`: Screen navigation, auth state management, global field coordination

**Utilities:**
- `SimPlex/source/utils.brs`: Auth token/server URI persistence, URL builders, header generation, safe field access
- `SimPlex/source/normalizers.brs`: JSON to ContentNode transformers
- `SimPlex/source/logger.brs`: Logging functions

**Testing & Debugging:**
- No dedicated test directory; Roku development uses device-based testing
- Logs printed to console (visible via telnet debug console on Roku)
- Per `CLAUDE.md`: Use LogEvent for key milestones, LogError for failures

## Naming Conventions

**Files:**
- PascalCase for component names: `DetailScreen.brs`, `PosterGrid.brs`, `MainScene.brs`
- camelCase for utility files: `main.brs`, `utils.brs`, `constants.brs`, `logger.brs`, `normalizers.brs`
- XML paired with BrightScript: `DetailScreen.xml` + `DetailScreen.brs` in same directory

**Directories:**
- lowercase plurals: `screens/`, `widgets/`, `tasks/`, `components/`, `source/`, `images/`

**Function Names:**
- camelCase: `GetAuthToken()`, `SetServerUri()`, `BuildPlexUrl()`, `NormalizeMovieList()`
- Event handlers prefixed with `on`: `onLibrarySelected()`, `onItemSelected()`, `onTaskStateChange()`
- Init functions: `init()` (called by SceneGraph automatically)
- Logic functions: `show*Screen()`, `load*Data()`, `build*Content()`

**Variables (BrightScript):**
- camelCase: `m.posterGrid`, `m.currentLibraryId`, `m.isLoading`, `m.screenStack`
- m-scope: Component instance state (`m.top` = root node, `m.global` = global node)
- Temporary locals: `endpoint`, `url`, `response`, `server`

**Constants (constants.brs):**
- SCREAMING_SNAKE_CASE: `SIDEBAR_WIDTH`, `BG_PRIMARY`, `ACCENT`, `PLEX_PRODUCT`
- Hex colors: `0xRRGGBBAA` format (e.g., `0xF3B125FF` = Plex gold)

**ContentNode Fields:**
- Snake_case for standard fields: `id`, `title`, `posterUrl`, `itemType`, `watched`, `viewOffset`, `ratingKey`
- Plex type mapping: `itemType: "movie"`, `itemType: "show"`, `itemType: "episode"`, `itemType: "playlist"`

## Where to Add New Code

**New Screen (e.g., Collections Grid):**
1. Create component: `SimPlex/components/screens/CollectionsScreen.brs` and `.xml`
2. Extend `Group` or `Scene` in XML
3. Define interface fields (e.g., `collectionRatingKey`, `itemSelected`, `navigateBack`)
4. Link scripts: `<script>` tags for utils.brs, constants.brs, logger.brs, CollectionsScreen.brs
5. Add init() function, set up node references and observers
6. Add selection handlers that set `itemSelected` field (observed by MainScene)
7. In MainScene.brs, add `showCollectionsScreen()` function and call from appropriate trigger
8. Add to screen stack: `pushScreen(screen)` in MainScene

**New Widget (e.g., Custom Grid Component):**
1. Create component: `SimPlex/components/widgets/CustomGrid.brs` and `.xml`
2. Extend `Group` in XML
3. Define interface fields for input (e.g., `content`, `selectedIndex`) and output (e.g., `itemSelected`)
4. Add init(), set up MarkupGrid or RowList, add observers
5. Implement focus and selection logic
6. Use from screen: `<CustomGrid id="grid" />`, reference with `m.top.findNode("grid")`
7. Observe output fields in parent screen: `m.grid.observeField("itemSelected", "onGridItemSelected")`

**New Task (e.g., Custom API Endpoint):**
1. Create component: `SimPlex/components/tasks/CustomTask.brs` and `.xml`
2. Extend `Task` in XML
3. In BrightScript:
   - Set `m.top.functionName = "run"` in init()
   - Read input fields from `m.top` (e.g., `m.top.endpoint`)
   - Set `m.top.status = "loading"` at start
   - Make HTTP request (create roUrlTransfer, set headers, etc.)
   - On completion, set `m.top.response` or `m.top.error` and `m.top.status = "success"/"error"`
4. From screen:
   ```brightscript
   task = CreateObject("roSGNode", "CustomTask")
   task.endpoint = "/some/path"
   task.observeField("status", "onTaskStatus")
   task.control = "run"
   ```

**New Utility Function (e.g., Auth Helper):**
1. Add to `SimPlex/source/utils.brs`:
   ```brightscript
   function NewHelper(param as String) as String
       ' Implementation
   end function
   ```
2. Include in any screen/widget via: `<script type="text/brightscript" uri="pkg:/source/utils.brs" />`
3. Call as: `NewHelper("value")`

**New Constant:**
1. Add to `SimPlex/source/constants.brs` inside `GetConstants()` function return object
2. Access via `m.global.constants.NEW_CONSTANT` (cached in MainScene.init())
3. Or call `GetConstants()` for edge cases

**New Normalizer (e.g., Playlist List):**
1. Add function to `SimPlex/source/normalizers.brs`:
   ```brightscript
   function NormalizePlaylistList(jsonArray as Object) as Object
       content = CreateObject("roSGNode", "ContentNode")
       for each item in jsonArray
           node = content.createChild("ContentNode")
           node.addFields({
               id: SafeGet(item, "ratingKey", "")
               title: SafeGet(item, "title", "Unknown")
               ' ... other fields
           })
       end for
       return content
   end function
   ```
2. Call from screen after task.response: `contentTree = NormalizePlaylistList(response.MediaContainer.Metadata)`

## Special Directories

**node_modules/**
- Purpose: NPM dependencies (if project uses npm for build tooling)
- Generated: Yes (output of `npm install`)
- Committed: No (added to .gitignore)
- Note: Not used at runtime; Roku apps are pure BrightScript/SceneGraph

**images/**
- Purpose: App assets (icons, splash screen)
- Generated: No (source assets)
- Committed: Yes (required for app package)

**manifest**
- Purpose: Roku app metadata file (not a directory)
- Generated: No (source file)
- Committed: Yes (required for app package)

---

*Structure analysis: 2026-03-13*
