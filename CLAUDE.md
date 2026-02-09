# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PlexClassic** is a side-loadable Roku channel that serves as a custom Plex Media Server client. It replaces the official Plex Roku app with a clean, fast, grid-based UI inspired by the old "Plex Classic" Roku client.

## Technology Stack

- **Language:** BrightScript (`.brs` files for logic)
- **UI Framework:** Roku SceneGraph (`.xml` files for components)
- **Target Platform:** Roku devices (FHD 1920x1080)
- **API:** Plex Media Server REST API + plex.tv authentication

**This is NOT JavaScript, Python, or any web technology. Roku apps use BrightScript exclusively.**

## Project Structure

```
PlexClassic/
├── manifest                 # Roku app manifest (version, icons, settings)
├── source/                  # Main BrightScript source files
│   ├── main.brs            # Entry point - creates screen and message loop
│   ├── utils.brs           # Shared helpers (auth, URLs, headers)
│   └── constants.brs       # Colors, sizes, API constants
├── components/              # SceneGraph components
│   ├── MainScene.xml/.brs  # Root scene, screen stack management
│   ├── screens/            # Full-screen views (Home, Detail, Episodes, Search, Settings)
│   ├── widgets/            # Reusable UI components (Sidebar, PosterGrid, VideoPlayer)
│   └── tasks/              # Background Task nodes for HTTP requests
└── images/                  # App icons, splash screen, placeholders
```

## Architecture

### Component Pattern
Each SceneGraph component consists of:
- `.xml` file: Defines layout, children, and `<interface>` fields for data binding
- `.brs` file: Contains logic, linked via `<script>` tag in XML

### Task Nodes (Background Threading)
**All HTTP requests MUST run in Task nodes.** Using `roUrlTransfer` on the render thread causes rendezvous crashes.

- `PlexAuthTask` - PIN-based OAuth flow with plex.tv
- `PlexApiTask` - General PMS API requests (library browsing, metadata)
- `PlexSearchTask` - Search queries with debouncing
- `PlexSessionTask` - Playback progress reporting
- `ImageCacheTask` - Poster image prefetching

### Observer Pattern
Task→UI communication uses field observers:
```brightscript
task.observeField("state", "onTaskStateChange")
task.control = "run"
```

### Screen Stack
MainScene maintains an array of screen nodes. Back button pops the stack. Focus position is preserved when returning to previous screens.

## Critical Rules

1. **Never use `roUrlTransfer` on render thread** - only in Task nodes
2. **Always set HTTPS certificates:**
   ```brightscript
   url.SetCertificatesFile("common:/certs/ca-bundle.crt")
   url.InitClientCertificates()
   ```
3. **Include ALL X-Plex-* headers** on every Plex API call (use `GetPlexHeaders()`)
4. **Paginate library fetches** - use `X-Plex-Container-Start` and `X-Plex-Container-Size=50`
5. **Use built-in grid/list components** (`MarkupGrid`, `PosterGrid`, `RowList`, `LabelList`) - don't build custom scrolling
6. **Request resized poster images** via `/photo/:/transcode?width=240&height=360`
7. **Store persistent data in `roRegistrySection("PlexClassic")`** - always call `.Flush()` after writes
8. **Use ContentNode trees** to populate all lists and grids

## Key Constants

```brightscript
' Layout (FHD)
SIDEBAR_WIDTH: 280
POSTER_WIDTH: 240
POSTER_HEIGHT: 360
GRID_COLUMNS: 6

' Colors (0xRRGGBBAA)
BG_PRIMARY: "0x1A1A2EFF"
ACCENT: "0xE5A00DFF"  ' Plex gold - used for focus rings
```

## Plex API Essentials

### Authentication Flow
1. POST `https://plex.tv/api/v2/pins` with `strong=true` → get PIN code
2. User enters code at plex.tv/link
3. Poll GET `https://plex.tv/api/v2/pins/{id}` until `authToken` is populated
4. GET `https://plex.tv/api/v2/resources?includeHttps=1` to discover servers

### Common Endpoints
- `/library/sections` - List libraries
- `/library/sections/{id}/all` - Browse library (paginate!)
- `/library/metadata/{ratingKey}` - Item details
- `/library/onDeck` - Continue watching
- `/hubs/search?query={term}` - Search

### Playback
- Direct play: `{server}{partKey}?X-Plex-Token={token}`
- Transcode: `{server}/video/:/transcode/universal/start.m3u8?path={key}&protocol=hls...`
- Progress: PUT `/:/timeline?ratingKey={id}&state=playing&time={ms}`

## SceneGraph Quick Reference

- `m.top` = reference to component's root node
- `m.global` = global node for shared state
- `node.setFocus(true)` = give focus to a node
- `onKeyEvent(key, press)` = handle remote buttons, return `true` to consume
- Key strings: "OK", "back", "left", "right", "up", "down", "play", "pause", "options"

## Build & Deploy

To side-load to a Roku in developer mode:
1. Enable developer mode on Roku (Home 3x, Up 2x, Right, Left, Right, Left, Right)
2. Zip the project: `zip -r PlexClassic.zip manifest source components images`
3. Upload via browser to `http://{roku-ip}:8060`

Or use Roku's `make` tooling if available.
