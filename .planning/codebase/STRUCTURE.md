# Codebase Structure

**Analysis Date:** 2026-03-08

## Directory Layout

```
SimPlex/                            # Repo root
├── .claude/                        # Claude Code configuration (agents, commands, hooks)
├── .planning/                      # GSD planning documents
│   ├── codebase/                   # Codebase analysis docs (this file)
│   └── STATE.md                    # Project state tracking
├── CLAUDE.md                       # Project instructions for Claude Code
└── SimPlex/                        # Roku channel package root (zipped for sideload)
    ├── manifest                    # Roku app manifest (version, icons, resolution)
    ├── source/                     # Shared BrightScript source files
    │   ├── main.brs               # App entry point and message loop
    │   ├── utils.brs              # Auth, URL builders, safe access helpers
    │   ├── constants.brs          # Colors, sizes, API URLs, pagination config
    │   ├── logger.brs             # LogEvent() / LogError() console logging
    │   ├── normalizers.brs        # JSON-to-ContentNode converters
    │   └── capabilities.brs       # PMS version parsing and feature flags
    ├── components/                 # SceneGraph components (XML + BRS pairs)
    │   ├── MainScene.xml          # Root scene layout (background + screenContainer)
    │   ├── MainScene.brs          # Screen stack, navigation, auth routing
    │   ├── screens/               # Full-screen views
    │   │   ├── HomeScreen.xml/.brs        # Library browsing (sidebar + grid + filters)
    │   │   ├── DetailScreen.xml/.brs      # Item detail (poster, metadata, play buttons)
    │   │   ├── EpisodeScreen.xml/.brs     # Season/episode browser for TV shows
    │   │   ├── SearchScreen.xml/.brs      # Keyboard + debounced search results
    │   │   ├── PINScreen.xml/.brs         # plex.tv PIN auth flow
    │   │   ├── ServerListScreen.xml/.brs  # Server selection after auth
    │   │   └── SettingsScreen.xml/.brs    # Switch server, sign out
    │   ├── widgets/               # Reusable UI components
    │   │   ├── Sidebar.xml/.brs           # Left nav: libraries, hubs, settings
    │   │   ├── PosterGrid.xml/.brs        # Paginated poster grid with infinite scroll
    │   │   ├── PosterGridItem.xml/.brs    # Individual poster cell renderer
    │   │   ├── EpisodeItem.xml/.brs       # Episode list item renderer
    │   │   ├── FilterBar.xml/.brs         # Library filter controls
    │   │   ├── VideoPlayer.xml/.brs       # Playback: direct play/transcode, progress
    │   │   ├── LoadingSpinner.xml/.brs    # Loading indicator animation
    │   │   ├── MediaRow.xml/.brs          # Horizontal media row
    │   │   └── KeyboardDialog.xml/.brs    # Text input dialog
    │   └── tasks/                 # Background Task nodes (HTTP I/O)
    │       ├── PlexApiTask.xml/.brs       # General PMS REST client
    │       ├── PlexAuthTask.xml/.brs      # PIN auth + server discovery
    │       ├── PlexSearchTask.xml/.brs    # Search endpoint
    │       ├── PlexSessionTask.xml/.brs   # Playback progress reporting
    │       ├── ServerConnectionTask.xml/.brs  # Connection testing (local/remote/relay)
    │       └── ImageCacheTask.xml/.brs    # Poster image prefetching
    └── images/                    # Static assets
        ├── icon_focus_fhd.png     # Channel icon (focused state)
        ├── icon_side_fhd.png      # Channel icon (side panel)
        ├── splash_fhd.jpg         # Splash screen (1920x1080)
        └── README.txt             # Image asset notes
```

## Directory Purposes

**`SimPlex/source/`:**
- Purpose: Shared BrightScript functions available to all components
- Contains: Utility functions, constants, logging, data normalizers
- Key files: `utils.brs` (most heavily used - auth, URLs, SafeGet), `constants.brs` (all magic numbers)
- Inclusion: Files are included in components via `<script type="text/brightscript" uri="pkg:/source/filename.brs" />` tags in XML

**`SimPlex/components/screens/`:**
- Purpose: Full-screen views that occupy the entire display
- Contains: Paired .xml (layout + interface) and .brs (logic) files
- Key pattern: Every screen exposes `itemSelected` (assocarray) and `navigateBack` (boolean) interface fields for MainScene to observe

**`SimPlex/components/widgets/`:**
- Purpose: Reusable UI building blocks composed into screens
- Contains: Paired .xml/.brs files for each widget
- Key pattern: Widgets communicate upward via observable interface fields, receive data via content fields

**`SimPlex/components/tasks/`:**
- Purpose: Background-threaded HTTP I/O (required by Roku to avoid render thread crashes)
- Contains: Paired .xml/.brs files for each task type
- Key pattern: Set input fields -> `control = "run"` -> observe `status` for completion

**`SimPlex/images/`:**
- Purpose: Static image assets required by manifest and UI
- Contains: Channel icons, splash screen
- Generated: No
- Committed: Yes

## Key File Locations

**Entry Points:**
- `SimPlex/source/main.brs`: App bootstrap - creates screen, message loop, passes launch args
- `SimPlex/components/MainScene.brs`: Scene controller - auth check, screen routing, navigation stack
- `SimPlex/manifest`: Roku app metadata (version, resolution, icons)

**Configuration:**
- `SimPlex/source/constants.brs`: All app constants (colors, layout dimensions, API URLs, pagination size)
- `SimPlex/manifest`: App version (`major_version`, `minor_version`, `build_version`), resolution (`ui_resolutions=fhd`), SceneGraph version (`rsg_version=1.3`)

**Core Logic:**
- `SimPlex/source/utils.brs`: Auth token CRUD, Plex header builder, URL constructors, safe property access
- `SimPlex/source/normalizers.brs`: Plex JSON to ContentNode conversion (movies, shows, seasons, episodes, on-deck)
- `SimPlex/source/capabilities.brs`: PMS version parsing and feature flag checking
- `SimPlex/components/tasks/PlexApiTask.brs`: Central HTTP client (GET/POST, headers, JSON parsing, 401 handling)
- `SimPlex/components/widgets/VideoPlayer.brs`: Playback logic (direct play detection, transcoding, progress reporting)

**Screen Logic:**
- `SimPlex/components/screens/HomeScreen.brs`: Library browsing, pagination, filter application
- `SimPlex/components/screens/DetailScreen.brs`: Metadata display, play/resume/watched actions
- `SimPlex/components/screens/PINScreen.brs`: Authentication flow with polling timer

**Testing:**
- No test files exist. No test framework is configured.

## Naming Conventions

**Files:**
- PascalCase for all component files: `HomeScreen.brs`, `PlexApiTask.xml`, `PosterGrid.brs`
- lowercase for source utility files: `main.brs`, `utils.brs`, `constants.brs`, `logger.brs`, `normalizers.brs`, `capabilities.brs`
- Every SceneGraph component has exactly two files: `ComponentName.xml` (layout) + `ComponentName.brs` (logic)

**Directories:**
- lowercase plural for category directories: `screens/`, `widgets/`, `tasks/`, `images/`
- PascalCase for the channel package directory: `SimPlex/`

**Components:**
- Screens: `{Feature}Screen` (e.g., `HomeScreen`, `DetailScreen`, `PINScreen`)
- Widgets: Descriptive noun (e.g., `Sidebar`, `PosterGrid`, `VideoPlayer`, `LoadingSpinner`)
- Tasks: `{Service}{Purpose}Task` (e.g., `PlexApiTask`, `PlexAuthTask`, `ServerConnectionTask`)

**Functions:**
- PascalCase for global utility functions: `GetAuthToken()`, `BuildPlexUrl()`, `SafeGet()`, `FormatTime()`
- camelCase for component-scoped functions: `loadLibrary()`, `processApiResponse()`, `onItemSelected()`
- Prefix `on` for observer callbacks: `onApiTaskStateChange()`, `onLibrarySelected()`, `onKeyEvent()`
- Prefix `show` for screen factory methods in MainScene: `showHomeScreen()`, `showDetailScreen()`

**Variables:**
- camelCase for local/member variables: `m.screenStack`, `m.currentSectionId`, `m.apiTask`
- UPPER_SNAKE_CASE for constants within `GetConstants()`: `BG_PRIMARY`, `POSTER_WIDTH`, `PAGE_SIZE`

**Interface Fields (XML):**
- camelCase: `itemSelected`, `navigateBack`, `ratingKey`, `authToken`, `status`

## Where to Add New Code

**New Screen:**
- Create paired files: `SimPlex/components/screens/{Feature}Screen.xml` and `SimPlex/components/screens/{Feature}Screen.brs`
- XML must extend `Group`, include interface fields `itemSelected` (assocarray, alwaysNotify) and `navigateBack` (boolean, alwaysNotify)
- Include shared scripts: `<script uri="pkg:/source/utils.brs" />`, `<script uri="pkg:/source/constants.brs" />`
- Add `show{Feature}Screen()` method to `SimPlex/components/MainScene.brs`
- Add routing case to `onItemSelected()` in `SimPlex/components/MainScene.brs`
- Add subtype check to `popScreen()` for `currentScreen` name update

**New Widget:**
- Create paired files: `SimPlex/components/widgets/{WidgetName}.xml` and `SimPlex/components/widgets/{WidgetName}.brs`
- XML must extend `Group` (or a built-in SceneGraph component)
- Define `<interface>` fields for data input and event output
- Include in parent screen's XML as a child element

**New Task (Background HTTP):**
- Create paired files: `SimPlex/components/tasks/{Name}Task.xml` and `SimPlex/components/tasks/{Name}Task.brs`
- XML must extend `Task`
- Define interface fields: at minimum `status` (string), `error` (string), plus inputs/outputs
- BRS must set `m.top.functionName = "run"` in `init()` and implement `run()` sub
- Include `pkg:/source/utils.brs`, `pkg:/source/constants.brs`, `pkg:/source/logger.brs` via script tags
- Always use `url.SetCertificatesFile("common:/certs/ca-bundle.crt")` and `url.InitClientCertificates()`
- Always add Plex headers via `GetPlexHeaders()`

**New Utility Function:**
- Add to `SimPlex/source/utils.brs` for auth/URL/data helpers
- Add to `SimPlex/source/normalizers.brs` for new Plex JSON-to-ContentNode converters
- Add to `SimPlex/source/capabilities.brs` for server feature detection
- New utility category: create `SimPlex/source/{category}.brs` and include via `<script>` tag in components that need it

**New Constant:**
- Add to the return object in `GetConstants()` in `SimPlex/source/constants.brs`

**New Image Asset:**
- Place in `SimPlex/images/`
- Reference as `pkg:/images/filename.ext` in XML or BrightScript

## Special Directories

**`.planning/`:**
- Purpose: GSD planning and codebase analysis documents
- Generated: By Claude Code agents
- Committed: Yes

**`.claude/`:**
- Purpose: Claude Code configuration (agents, commands, hooks, settings)
- Generated: By GSD framework
- Committed: Yes

**`SimPlex/` (inner):**
- Purpose: The deployable Roku channel package
- Generated: No (source code)
- Committed: Yes
- Note: This entire directory is zipped for sideloading: `cd SimPlex && zip -r ../SimPlex.zip manifest source components images`

---

*Structure analysis: 2026-03-08*
