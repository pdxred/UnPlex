# SimPlex

## What This Is

A full-featured, personal-use Plex Media Server client for Roku 4K TV, side-loaded as a developer channel. It replaces the official Plex Roku app with a clean, fast, grid-based UI inspired by the "Plex Classic" experience — sidebar navigation, poster grids, and direct access to media without fighting the UI. Shipped v1.0 with complete movie and TV show browsing, playback with resume/progress/watched state, hub rows, audio/subtitle selection, intro/credits skip, auto-play, collections, playlists, and managed user support.

## Core Value

Fast, intuitive library browsing and playback on a single personal Plex server with tens of thousands of media items.

## Requirements

### Validated

- ✓ BrighterScript toolchain with F5 deploy — v1.0
- ✓ Constants cached in m.global — v1.0
- ✓ Concurrent API task pattern — v1.0
- ✓ Resume playback from last position — v1.0
- ✓ Progress bar overlays on poster items — v1.0
- ✓ Watched/unwatched badges — v1.0
- ✓ Hub rows (Continue Watching, Recently Added, On Deck) — v1.0
- ✓ Loading spinners, empty states, retry, server reconnect — v1.0
- ✓ Library filter/sort (genre, year, unwatched, sort order) — v1.0
- ✓ Audio track selection during playback — v1.0
- ✓ Subtitle track selection (SRT sidecar + PGS burn-in) — v1.0
- ✓ Track preference persistence — v1.0
- ✓ Skip Intro / Skip Credits buttons — v1.0
- ✓ Auto-play next episode with countdown — v1.0 (fixed in S12)
- ✓ Collections browsing — v1.0
- ✓ Playlist browsing and sequential playback — v1.0
- ✓ Managed user switching with PIN entry — v1.0
- ✓ Sidebar navigation, poster grids, screen stack — pre-v1.0 scaffold
- ✓ PIN-based OAuth, server discovery, persistent auth — pre-v1.0 scaffold
- ✓ Video playback with direct play and transcode fallback — pre-v1.0 scaffold
- ✓ Search with debounced queries — pre-v1.0 scaffold

### Active

**Current Milestone: v1.1 Polish & Navigation**

**Goal:** Fix v1.0 bugs, overhaul TV show navigation, clean up codebase, refresh branding, and document for GitHub.

**Target features:**
- TV show navigation overhaul (Show → Season list → Episode grid)
- Bug fixes: collections, search layout, thumbnail aspect ratios, auto-play wiring, watch state propagation
- Server switching: fix or remove cleanly
- App branding: bolder font with gray stroke, gradient backgrounds on icon/splash
- Codebase cleanup: orphaned code, brittle patterns, inefficiencies
- Full documentation (user guide + developer/architecture), publish to GitHub

**Future Features**
- [ ] Music: album/artist browse, track list, playback queue, now-playing bar
- [ ] Photos: grid, full-screen viewer, slideshow
- [ ] Live TV: EPG guide grid, channel tuning, DVR recordings list
- [ ] Library grid/list toggle view
- [ ] Pre-roll detection and playback
- [ ] Artwork caching and performance profiling
- [ ] ASS subtitle support

### Out of Scope

- Channel store submission or certification — sideload only
- Multi-server support — single personal server
- Mobile companion app — Roku only
- Cloud relay playback — direct server connection only
- BrighterScript v1.0.0-alpha migration — defer until stable release
- Watch Together — rarely used feature
- Maestro MVVM — deprecated (Nov 2023); plain BrightScript + SceneGraph is idiomatic and sufficient

## Context

Shipped v1.0 MVP with 11,385 LOC across BrightScript and SceneGraph XML.
Tech stack: BrighterScript 0.70.x (compile-time), plain BrightScript + SceneGraph (runtime), Roku OS 11.5+.
30-day development cycle (2026-02-09 → 2026-03-10), 10 phases, 17 plans.

Known gaps (post-S12): HomeScreen and PlaylistScreen still use old `playbackComplete` boolean (not migrated to `playbackResult`/PostPlayScreen pattern). 5 files use inline hardcoded accent color `0xE5A00D` instead of the `ACCENT` constant `0xF3B125`.

## Constraints

- **Platform:** Roku 4K TV, Roku OS 11.5+, FHD 1920x1080
- **Language:** BrighterScript 0.70.x (compiles to BrightScript)
- **Deployment:** Sideloaded developer channel via F5 from VSCode
- **Server:** Single Plex Media Server, locally hosted
- **Threading:** All HTTP via Task nodes — no roUrlTransfer on render thread
- **API format:** Prefer JSON (Accept: application/json) over XML
- **Storage:** roRegistrySection("SimPlex") with Flush() after every write
- **Commit format:** feat(phaseN): description

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Sidebar navigation pattern | Matches classic Plex, efficient for library browsing | ✓ Good |
| Plain BrightScript over Maestro MVVM | Maestro deprecated Nov 2023; scaffold already plain BS; migration adds scope with no benefit | ✓ Good |
| BrighterScript 0.70.x as compile-time upgrade | Superset of BrightScript, no rewrite needed, adds type safety | ✓ Good |
| Direct play first, transcode fallback | Simpler path, covers most content | ✓ Good |
| JSON over XML for Plex API | Cleaner parsing, modern API pattern | ✓ Good |
| Video-only for v1.0 | Focused scope, user's primary use case | ✓ Good |
| plex.tv resource discovery over GDM | Works across network segments, existing pattern | ✓ Good |
| PUT via X-HTTP-Method-Override | Roku doesn't support PUT directly | ✓ Good |
| PGS transcode pivot with position preservation | Stop direct play, start HLS transcode at offset, revert on failure | ✓ Good |
| Track persistence fire-and-forget | PUT /library/parts/{id} after every change, no error handling needed | ✓ Good |
| Forced PGS subtitles skipped at initial load | Avoids unexpected transcode on first play | ✓ Good |
| Three-zone focus model (sidebar/hubs/grid) | Clean focus management for hub row + library coexistence | ✓ Good |
| Optimistic UI for watched state | Instant visual feedback, API in background | ✓ Good |
| 30-second fixed threshold for auto-play | Triggers reliably without credits markers; covers short and long episodes equally | ✓ Good |
| Admin token preserved separately | Enables managed user switching without re-auth | ✓ Good |

---
*Last updated: 2026-03-22 after S12 completion and memory audit*
