# Technology Stack

**Analysis Date:** 2026-03-13

## Languages

**Primary:**
- BrightScript (`.brs` files) - All application logic and business logic
- SceneGraph XML (`.xml` files) - UI component definitions and layout

**Node Version:**
- Node.js (for build tooling only - NOT runtime for the app)

## Runtime

**Environment:**
- Roku OS (FHD 1920x1080 resolution, RSG version 1.3)
- Roku devices with SceneGraph support

**Build System:**
- BrighterScript compiler - Type-checking and code validation
- Roku deployment tools - Package and deploy to Roku devices

## Frameworks

**Core:**
- Roku SceneGraph (v1.3) - UI framework built into Roku OS
  - Component-based architecture with XML for layout
  - Built-in nodes: MarkupGrid, PosterGrid, RowList, LabelList, VideoPlayer
  - Message-based communication between components

**Development:**
- BrighterScript v0.70.3 - BrightScript dialect with type annotations and ES6 features
- Roku Deploy v3.16.1 - Side-load and deploy packages to Roku devices

## Key Dependencies

**Build/Tooling:**
- brighterscript v0.70.3 - Compiler and language enhancement
- roku-deploy v3.16.1 - Deployment to Roku devices
- @rokucommunity/bslib v0.1.1 - BrightScript standard library
- @rokucommunity/logger v0.3.11 - Logging utilities
- chalk v4.1.2 - Terminal color output for logging

**Indirect:**
- @babel/runtime - Runtime for BrighterScript transpilation
- date-fns v2.30.0 - Date formatting in logger
- fs-extra v10.0.0 - File system utilities
- serialize-error v8.1.0 - Error serialization

## Configuration

**Environment:**
- Settings stored in persistent `roRegistrySection("SimPlex")` registry
- No `.env` files - all configuration is embedded in code or set via registry
- Device UUID auto-generated on first run via `roDeviceInfo().GetRandomUUID()`

**Build:**
- `bsconfig.json` - BrighterScript compiler configuration
  - Input: `SimPlex/manifest`, `SimPlex/source/**/*.brs`, `SimPlex/components/**/*`
  - Output: `out/staging` (not retained between builds)
  - Source maps enabled for debugging
  - Diagnostic filters suppress specific linter codes (1105, 1045, 1140)

**Manifest:**
- `SimPlex/manifest` - Roku channel manifest
  - Version: 1.0.1
  - UI Resolution: FHD (1920x1080)
  - Icons: Focus and side icons for FHD and HD
  - Splash screen: `splash_fhd.jpg` (1500ms minimum display time)

## Platform Requirements

**Development:**
- Node.js environment for running build tools
- Text editor or IDE with BrightScript syntax support
- Roku device in developer mode for testing

**Production:**
- Roku device with SceneGraph support (most modern Rokus)
- FHD resolution support (1920x1080)
- HTTPS certificate bundle at `common:/certs/ca-bundle.crt` for SSL connections
- Network connectivity to Plex Media Server and plex.tv

## HTTP & Network

**Protocol:**
- HTTPS required for all external requests (Plex API and plex.tv)
- HTTP allowed for local Plex Media Server connections (common in home networks)
- Certificates configured via `url.SetCertificatesFile("common:/certs/ca-bundle.crt")`

**Request Handling:**
- All HTTP requests run in background Task nodes (not render thread)
- Async request pattern: `roUrlTransfer` with `roMessagePort` for callbacks
- Timeout: 30 seconds for API requests, 15 seconds for server discovery
- Custom X-Plex-* headers required on all Plex requests

## Persistent Storage

**Registry Storage:**
- Storage location: `roRegistrySection("SimPlex")`
- Flushes to disk immediately via `.Flush()` calls
- Stores: `deviceId`, `authToken`, `adminToken`, `serverUri`, `activeUserName`, `pinnedLibraries`, `sidebarLibraries`, `serverClientId`
- No database - registry is key-value only

## Media Playback

**Video:**
- Built-in `VideoPlayer` SceneGraph component
- Supports both direct play and HLS transcode streams from Plex Media Server
- Progress tracking via `/:/timeline` endpoint

**Images:**
- Built-in Roku image caching system
- Poster images fetched via `/photo/:/transcode?width={w}&height={h}` with token
- Lazy loading and prefetching via `ImageCacheTask`

---

*Stack analysis: 2026-03-13*
