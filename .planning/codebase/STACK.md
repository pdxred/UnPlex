# Technology Stack

**Analysis Date:** 2026-03-08

## Languages

**Primary:**
- BrightScript (`.brs`) - All application logic, event handling, API communication, data normalization

**Secondary:**
- Roku SceneGraph XML (`.xml`) - UI component layout, interface field definitions, child node declarations

## Runtime

**Environment:**
- Roku OS (SceneGraph RSG version 1.3, per `SimPlex/manifest` line `rsg_version=1.3`)
- Target resolution: FHD 1920x1080 (`ui_resolutions=fhd`)

**Package Manager:**
- None. Roku apps have no dependency management system. All code is first-party BrightScript.
- No lockfile, no package manifest beyond `SimPlex/manifest`.

## Frameworks

**Core:**
- Roku SceneGraph - Native Roku UI framework. Component-based architecture with XML layouts and BrightScript logic files.
- No third-party frameworks. Pure SceneGraph with built-in nodes (`MarkupGrid`, `LabelList`, `Video`, `Timer`, `Task`, `ContentNode`, `StandardMessageDialog`).

**Testing:**
- None detected. No test files, no test framework configuration, no test runner.

**Build/Dev:**
- Manual zip packaging: `cd SimPlex && zip -r ../SimPlex.zip manifest source components images`
- Side-loaded via HTTP to Roku device at `http://{roku-ip}:8060`
- No Makefile, no build scripts, no CI/CD configuration detected.

## Key Dependencies

**Critical (all built into Roku OS, no external packages):**
- `roUrlTransfer` - HTTP client for all API calls (must run in Task nodes only)
- `roSGScreen` / `roSGNode` - SceneGraph rendering engine
- `roRegistrySection` - Persistent key-value storage on device (registry name: `"SimPlex"`)
- `roDeviceInfo` - Device identification for Plex headers
- `roMessagePort` - Event loop and async message handling

**Infrastructure:**
- `common:/certs/ca-bundle.crt` - Roku's built-in CA certificate bundle for HTTPS
- Built-in JSON parser: `ParseJson()` / `FormatJson()` (global BrightScript functions)

## Configuration

**Environment:**
- No `.env` files. Roku apps cannot use environment variables.
- All configuration is compile-time constants in `SimPlex/source/constants.brs` via `GetConstants()` function.
- Runtime secrets (auth token, server URI, device ID) stored in Roku registry section `"SimPlex"` via helpers in `SimPlex/source/utils.brs`.

**Key constants defined in `SimPlex/source/constants.brs`:**
- `PLEX_TV_URL`: `"https://plex.tv"` - Authentication server
- `PLEX_PRODUCT`: `"SimPlex"` - Client identification
- `PLEX_VERSION`: `"1.0.0"` - Client version
- `PLEX_PLATFORM`: `"Roku"` - Platform identification
- `PAGE_SIZE`: `50` - API pagination size
- `PROGRESS_REPORT_INTERVAL`: `10` - Playback progress report interval (seconds)
- Layout constants: `SIDEBAR_WIDTH: 280`, `POSTER_WIDTH: 240`, `POSTER_HEIGHT: 360`, `GRID_COLUMNS: 6`
- Color palette: `BG_PRIMARY: "0x1A1A2EFF"`, `ACCENT: "0xE5A00DFF"` (Plex gold)

**Build:**
- `SimPlex/manifest` - Roku app manifest (version 1.0.1, title, icons, splash screen, resolution)

## Platform Requirements

**Development:**
- A Roku device in developer mode (Home 3x, Up 2x, Right, Left, Right, Left, Right)
- Network access to the Roku device on port 8060
- Ability to create a zip file containing `manifest`, `source/`, `components/`, `images/`
- No SDK installation required beyond a text editor; no compilation step

**Production:**
- Side-loaded only (not published to Roku Channel Store)
- Roku device running firmware that supports SceneGraph RSG 1.3+
- Network connectivity to Plex Media Server and plex.tv for authentication

## Source Files

**`SimPlex/source/` (shared utility modules, loaded globally):**
- `main.brs` - App entry point, creates `roSGScreen`, message loop
- `constants.brs` - `GetConstants()` function returning all app constants
- `utils.brs` - Auth token storage, Plex header builder, URL construction, safe field access
- `logger.brs` - `LogEvent()` and `LogError()` via `print` statements (console debug output)
- `normalizers.brs` - JSON-to-ContentNode converters for movies, shows, seasons, episodes, on-deck
- `capabilities.brs` - Plex server version parsing and feature flag detection

---

*Stack analysis: 2026-03-08*
