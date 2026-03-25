# UnPlex

A side-loadable Roku channel that serves as a custom Plex Media Server client. UnPlex replaces the official Plex Roku app with a clean, fast, grid-based UI inspired by the classic "Plex Classic" Roku client — sidebar navigation, poster grids, and direct access to your media without fighting the interface.

Built with BrightScript and Roku SceneGraph for FHD (1920×1080) displays.

## Features

**Library Browsing**
- Browse movies, TV shows, and music libraries with poster grid layouts
- Hub rows: Continue Watching, Recently Added, On Deck
- Collections and playlists browsing
- Filter and sort by genre, year, unwatched status, and sort order
- Sidebar navigation for quick library switching

**Playback**
- Direct play with automatic transcode fallback (HLS)
- Resume from last playback position
- Progress bar overlays on poster items
- Watched/unwatched badges
- Audio track selection during playback
- Subtitle track selection (SRT sidecar + PGS burn-in)
- Track preference persistence across sessions
- Skip Intro and Skip Credits buttons
- Auto-play next episode with countdown

**User Management**
- PIN-based OAuth authentication via plex.tv/link
- Managed user switching with PIN entry
- Persistent authentication across sessions

**Search**
- Debounced search queries across all libraries
- Results displayed by media type

## Installation

UnPlex is installed by side-loading it onto a Roku device in developer mode. No channel store submission is required.

### 1. Enable Developer Mode on Your Roku

1. Using your Roku remote, press: **Home** (3×), **Up** (2×), **Right**, **Left**, **Right**, **Left**, **Right**
2. The Developer Settings screen will appear
3. Enable the installer and set a developer password
4. Note your Roku's IP address (Settings → Network → About)

### 2. Build the Channel Package

Make sure you have [Node.js](https://nodejs.org/) installed, then:

```bash
git clone https://github.com/pdxred/UnPlex.git
cd UnPlex
npm install
npm run build
```

### 3. Side-Load to Your Roku

**Option A — Automated deploy:**

```bash
npm run deploy
```

This uses [roku-deploy](https://github.com/RokuCommunity/roku-deploy) to build, package, and install to your Roku in one step. Configure the target Roku IP and password in `bsconfig.json`.

**Option B — Manual upload:**

1. Open a web browser and navigate to `http://<your-roku-ip>:8060`
2. Upload the `UnPlex.zip` file through the installer page
3. The channel will install and launch automatically

### 4. Authenticate with Plex

1. On first launch, UnPlex displays a PIN code
2. Visit [plex.tv/link](https://www.plex.tv/link) on any device and enter the PIN
3. UnPlex automatically discovers your Plex Media Server and begins loading your libraries

## Usage

### Remote Control

| Button | Action |
|--------|--------|
| **OK** | Select / Confirm |
| **Back** | Go to previous screen |
| **Left/Right** | Navigate sidebar / grid columns |
| **Up/Down** | Navigate grid rows / lists |
| **Play/Pause** | Toggle playback |
| **Options (*)** | Context menu (audio/subtitle selection) |

### Navigation

- **Sidebar** — Press **Left** from any screen to access the sidebar with your pinned libraries, hub sections (Home, On Deck), and settings
- **Library browsing** — Select a library to view its content in a poster grid. Use the filter/sort options to narrow results by genre, year, or watched status
- **TV Shows** — Navigate from Show → Season list → Episode grid
- **Search** — Select the search option from the sidebar. Type to search across all libraries with debounced results

### Playback

- Select any movie or episode to view its detail screen, then press **Play** or **OK** to start playback
- Playback resumes from your last position automatically
- Press **Options (*)** during playback to select audio tracks or subtitles
- Skip Intro and Skip Credits buttons appear automatically when markers are available
- For TV shows, the next episode plays automatically after a countdown at the end of the current episode

## Building from Source

### Prerequisites

- [Node.js](https://nodejs.org/) (LTS recommended)
- A Roku device in developer mode (for testing)

### Setup

```bash
git clone https://github.com/pdxred/UnPlex.git
cd UnPlex
npm install
```

### Available Scripts

| Command | Description |
|---------|-------------|
| `npm run build` | Compile BrighterScript source via `bsc` |
| `npm run deploy` | Compile and deploy to a Roku device via `bsc --deploy` |
| `npm run lint` | Run BrighterScript linter (no output) via `bsc --noEmit` |

### Project Structure

```
UnPlex/
├── manifest                 # Roku app manifest (version, icons, settings)
├── source/                  # Main BrightScript source files
│   ├── main.brs            # Entry point — screen creation and message loop
│   ├── utils.brs           # Shared helpers (auth, URLs, HTTP headers)
│   └── constants.brs       # Colors, sizes, API constants
├── components/              # SceneGraph components
│   ├── MainScene.xml/.brs  # Root scene and screen stack management
│   ├── screens/            # Full-screen views (Home, Detail, Episodes, Search, Settings)
│   ├── widgets/            # Reusable UI (Sidebar, PosterGrid, VideoPlayer)
│   └── tasks/              # Background Task nodes for HTTP requests
├── fonts/                   # Bundled fonts (Inter Bold)
└── images/                  # App icons, splash screen, placeholders
```

### Build Configuration

The BrighterScript compiler is configured via `bsconfig.json`:
- **Input:** `UnPlex/manifest`, `UnPlex/source/**/*.brs`, `UnPlex/components/**/*`
- **Output:** `out/staging` (generated at build time, not committed)
- Source maps are enabled for debugging

## Architecture

UnPlex is built on Roku's SceneGraph framework. Each UI component is a pair of files: an `.xml` file defining layout and interface fields, and a `.brs` file containing the component's logic.

**Key architectural patterns:**

- **Screen stack** — MainScene maintains an array of screen nodes. The Back button pops the stack, preserving focus position when returning to previous screens.
- **Task-based HTTP** — All network requests run in background Task nodes (`PlexAuthTask`, `PlexApiTask`, `PlexSearchTask`, `PlexSessionTask`) to avoid render-thread blocking.
- **Observer pattern** — Task nodes communicate results to UI components via field observers, enabling asynchronous data flow.
- **ContentNode trees** — All lists and grids are populated through Roku's ContentNode data model.
- **Registry persistence** — User settings and authentication tokens are stored in `roRegistrySection("UnPlex")`.

For a detailed technical breakdown, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

UnPlex is released under the [MIT License](LICENSE).

This project includes [Inter](https://rsms.me/inter/) Bold font by Rasmus Andersson, licensed under the [SIL Open Font License 1.1](https://openfontlicense.org/).

## Acknowledgments

- [Plex](https://www.plex.tv/) — Media server platform and API
- [Inter](https://rsms.me/inter/) by Rasmus Andersson — UI typeface (SIL Open Font License)
- [Roku Developer Platform](https://developer.roku.com/) — SceneGraph framework and documentation
- [BrighterScript](https://github.com/RokuCommunity/brighterscript) — Enhanced BrightScript compiler
- [roku-deploy](https://github.com/RokuCommunity/roku-deploy) — Deployment tooling
