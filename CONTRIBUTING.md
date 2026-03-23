# Contributing to SimPlex

Thank you for your interest in contributing to SimPlex! This guide covers everything you need to set up a development environment, build and deploy the app, and understand the codebase conventions.

## Development Setup

### Prerequisites

- **[Node.js](https://nodejs.org/)** (v16 or later) — used for the BrighterScript compiler and deployment tooling
- **A Roku device in developer mode** — required for testing (there is no desktop simulator)

### Enable Developer Mode on Your Roku

1. Using your Roku remote, press: **Home** (3×), **Up** (2×), **Right**, **Left**, **Right**, **Left**, **Right**
2. The Developer Settings screen will appear — enable the installer and set a developer password
3. Note your Roku's IP address (Settings → Network → About)

### Clone and Install

```bash
git clone https://github.com/your-username/SimPlex.git
cd SimPlex
npm install
```

### Configure Deployment Target

Edit `bsconfig.json` to point at your Roku device:

```json
{
  "host": "192.168.1.XXX",
  "password": "your-developer-password"
}
```

Replace the IP and password with the values from your Roku's developer settings. **Do not commit `bsconfig.json` with real credentials.**

## Build & Deploy

SimPlex uses the [BrighterScript](https://github.com/RokuCommunity/brighterscript) compiler (`bsc`) for compilation and [roku-deploy](https://github.com/RokuCommunity/roku-deploy) for side-loading.

| Command | Description |
|---------|-------------|
| `npm run build` | Compile BrighterScript → BrightScript output in `out/staging` |
| `npm run deploy` | Compile and side-load to the Roku device configured in `bsconfig.json` |
| `npm run lint` | Type-check without emitting (catches type errors and missing references) |

**Build configuration** is in `bsconfig.json`:
- `rootDir: "SimPlex"` — source app directory
- `stagingDir: "out/staging"` — compiled output (not committed)
- Source maps are enabled for debugging
- Diagnostic filters suppress certain BrightScript-specific warnings (1105, 1045, 1140)

**Debugging:** Connect to your Roku via telnet on port 8085 to see debug console output. All `LogEvent()` and `LogError()` calls in the app print timestamped messages to this console.

## Code Conventions

### Component Pattern

Every SceneGraph component is a pair of files:
- **`.xml`** — defines the visual layout, child nodes, and `<interface>` fields for data binding
- **`.brs`** — contains the component's logic, linked via `<script>` tags in the XML

Script includes follow a standard order in each XML file:

```xml
<script type="text/brightscript" uri="pkg:/source/utils.brs" />
<script type="text/brightscript" uri="pkg:/source/constants.brs" />
<script type="text/brightscript" uri="pkg:/source/logger.brs" />
<script type="text/brightscript" uri="ComponentName.brs" />
```

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Component files | PascalCase | `HomeScreen.brs`, `PosterGrid.xml` |
| Utility files | camelCase | `utils.brs`, `logger.brs`, `normalizers.brs` |
| Functions | camelCase | `GetAuthToken()`, `BuildPlexUrl()` |
| Event handlers | `on` prefix | `onItemSelected()`, `onTaskStateChange()` |
| Constants | SCREAMING_SNAKE_CASE | `SIDEBAR_WIDTH`, `BG_PRIMARY` |
| Variables | camelCase | `m.screenStack`, `m.currentLibraryId` |
| ContentNode fields | camelCase | `ratingKey`, `posterUrl`, `itemType` |
| Directories | lowercase plural | `screens/`, `widgets/`, `tasks/` |

### Critical Rules

These rules are non-negotiable — violating them causes crashes or broken behavior:

1. **All HTTP requests MUST run in Task nodes.** Using `roUrlTransfer` on the render thread causes rendezvous crashes. Create a Task node, set its input fields, call `task.control = "run"`, and observe its status field for results.

2. **Always set HTTPS certificates** on every `roUrlTransfer` instance:
   ```brightscript
   url.SetCertificatesFile("common:/certs/ca-bundle.crt")
   url.InitClientCertificates()
   ```

3. **Include all X-Plex-* headers** on every Plex API request. Use the `GetPlexHeaders()` helper from `utils.brs` — it builds the full header set including product name, version, device info, and auth token.

4. **Call `.Flush()` after every registry write.** The `roRegistrySection` write buffer is not flushed automatically:
   ```brightscript
   sec = CreateObject("roRegistrySection", "SimPlex")
   sec.Write("key", "value")
   sec.Flush()  ' Required!
   ```

5. **Never use the BusySpinner widget.** It causes native firmware SIGSEGV crashes on certain Roku devices. The LoadingSpinner component has been disabled in all screens for this reason.

6. **Paginate library fetches.** Use `X-Plex-Container-Start` and `X-Plex-Container-Size` headers (default page size: 50). Never fetch an entire library in one request.

7. **Use ContentNode trees** to populate all grids and lists. SceneGraph components like `MarkupGrid`, `PosterGrid`, and `RowList` expect ContentNode hierarchies for data binding.

### Error Handling

- Use `SafeGet(obj, field, default)` for defensive access to API response fields
- Check for `invalid` before accessing nested objects
- Task nodes should set `m.top.status` to `"error"` and populate `m.top.error` on failure
- HTTP 401 responses should trigger `m.global.authRequired = true` to restart the auth flow

### Logging

Use the logging helpers from `logger.brs`:
- `LogEvent(message)` — key milestones, state transitions, successful operations
- `LogError(message)` — failures, authentication issues, unexpected responses

Keep logging focused on errors and key events. Avoid verbose debug logging in committed code.

## Project Structure

```
SimPlex/
├── manifest                     # Roku app metadata (title, version, icons, splash)
├── source/                      # BrightScript entry point and shared utilities
│   ├── main.brs                # App entry — creates roSGScreen, runs event loop
│   ├── utils.brs               # Auth storage, URL builders, Plex headers, safe access
│   ├── constants.brs           # Colors, layout dimensions, API metadata, pagination
│   ├── logger.brs              # LogEvent / LogError functions
│   ├── normalizers.brs         # JSON → ContentNode tree transformers
│   └── capabilities.brs        # Device capability detection
├── components/
│   ├── MainScene.brs/.xml      # Root scene — screen stack, auth flow, global state
│   ├── screens/                # Full-screen views
│   │   ├── HomeScreen          # Library browsing with sidebar + poster grid + hubs
│   │   ├── DetailScreen        # Item metadata, play button, watch state
│   │   ├── EpisodeScreen       # Season/episode list for TV shows
│   │   ├── SearchScreen        # Debounced search input + results grid
│   │   ├── PlaylistScreen      # Playlist item browsing
│   │   ├── SettingsScreen      # User, server, and library management
│   │   ├── PINScreen           # OAuth PIN code display and polling
│   │   ├── UserPickerScreen    # Managed user selection
│   │   └── ServerListScreen    # Server discovery and connection
│   ├── widgets/                # Reusable UI components
│   │   ├── Sidebar             # Library nav list (MarkupList-based)
│   │   ├── PosterGrid          # Movie/show poster grid with badges
│   │   ├── VideoPlayer         # Playback, track selection, auto-play
│   │   ├── FilterBar           # Genre/sort controls
│   │   ├── KeyboardDialog      # Soft keyboard for text input
│   │   ├── LoadingSpinner      # Loading indicator (currently disabled)
│   │   └── [12 more widgets]   # TrackSelectionPanel, EpisodeItem, MediaRow, etc.
│   └── tasks/                  # Background HTTP Task nodes
│       ├── PlexApiTask         # General library/metadata API calls
│       ├── PlexAuthTask        # PIN polling + plex.tv auth + server discovery
│       ├── PlexSearchTask      # Search queries
│       ├── PlexSessionTask     # Playback progress reporting
│       ├── ServerConnectionTask # Server URI validation
│       └── ImageCacheTask      # Poster image prefetching
├── fonts/                       # Bundled Inter Bold (SIL OFL licensed)
└── images/                      # App icons (FHD + HD), splash screen
```

**Codebase scale:** ~8,978 lines of BrightScript across 33 `.brs` files, ~1,348 lines of SceneGraph XML across 32 `.xml` files, plus the manifest, fonts, and image assets.

## Known Limitations

- **BusySpinner crash** — The Roku `BusySpinner` widget causes native firmware SIGSEGV on certain devices. LoadingSpinner is disabled in all screens as a workaround. A custom spinner replacement is needed.
- **Auto-play next episode** — The auto-play countdown logic exists in VideoPlayer but is not fully wired. EpisodeScreen and DetailScreen do not pass the required `parentRatingKey` and `grandparentRatingKey` fields to the player.
- **No multi-server support** — SimPlex connects to one Plex Media Server at a time. Switching servers requires re-authenticating.
- **Fixed FHD layout** — The UI is designed for 1920×1080 displays. HD (720p) and 4K displays are not dynamically supported.
- **No automated tests** — Roku does not have a standard unit testing framework. Testing is manual via build-deploy-verify cycles on real hardware.
- **Watch state propagation** — Marking an item as watched on the DetailScreen does not immediately update the parent grid. The grid refreshes on a 2-minute timer or on next navigation.
