# SimPlex

## What This Is

A full-featured, personal-use Plex Media Server client for Roku 4K TV, side-loaded as a developer channel. It replaces the discontinued official Plex Roku app with a clean, fast, grid-based UI inspired by the "Plex Classic" experience — sidebar navigation, poster grids, and direct access to media without fighting the UI.

## Core Value

Fast, intuitive library browsing and playback on a single personal Plex server with tens of thousands of media items.

## Requirements

### Validated

<!-- Inferred from existing codebase (Phase 1 scaffold) -->

- ✓ App bootstrap and SceneGraph screen creation — existing (`SimPlex/source/main.brs`)
- ✓ MainScene with screen stack navigation (push/pop/focus preservation) — existing
- ✓ PIN-based OAuth flow via plex.tv/api/v2/pins with polling — existing (`PINScreen`, `PlexAuthTask`)
- ✓ Server discovery via plex.tv/api/v2/resources with connection priority (local > remote > relay) — existing (`ServerListScreen`, `ServerConnectionTask`)
- ✓ Persistent auth token and server URI storage in roRegistry — existing (`utils.brs`)
- ✓ General-purpose Plex API task with auth headers, JSON parsing, 401 handling — existing (`PlexApiTask`)
- ✓ Sidebar navigation with library list from /library/sections — existing (`Sidebar`)
- ✓ Poster grid with paginated loading (50 items/page, infinite scroll) — existing (`PosterGrid`, `PosterGridItem`)
- ✓ Home screen with library browsing and filter bar — existing (`HomeScreen`)
- ✓ Detail screen with metadata display — existing (`DetailScreen`)
- ✓ Episode browser with season/episode navigation — existing (`EpisodeScreen`, `EpisodeItem`)
- ✓ Search with debounced queries — existing (`SearchScreen`, `PlexSearchTask`)
- ✓ Video playback with direct play and transcode fallback — existing (`VideoPlayer`)
- ✓ Playback progress reporting every 10 seconds — existing (`PlexSessionTask`)
- ✓ Image cache prefetching — existing (`ImageCacheTask`)
- ✓ Settings screen with server switch and sign out — existing (`SettingsScreen`)
- ✓ Global 401 handler with re-auth routing — existing
- ✓ Data normalizers for movies, shows, seasons, episodes, on-deck — existing (`normalizers.brs`)
- ✓ Server capability detection and version parsing — existing (`capabilities.brs`)
- ✓ Structured logging with ISO timestamps — existing (`logger.brs`)
- ✓ Constants module with layout, color, and API config — existing (`constants.brs`)
- ✓ Audio track selection during playback — Phase 6
- ✓ Subtitle track selection during playback — Phase 6
- ✓ Sidecar SRT subtitle injection — Phase 6
- ✓ PGS bitmap subtitle burn-in via transcode fallback — Phase 6
- ✓ Track preference persistence to Plex server — Phase 6
- ✓ Forced subtitle auto-enable based on device locale — Phase 6
- ✓ Skip Intro button during intro marker timespan — Phase 7
- ✓ Skip Credits button during credits marker timespan — Phase 7
- ✓ Auto-play next episode with 10-second countdown overlay — Phase 8
- ✓ Cancel auto-play countdown via Back key — Phase 8
- ✓ 90% duration fallback when no credits marker exists — Phase 8

### Active

<!-- Phases 2-19 from brief — building on existing scaffold -->

**Playback Enhancements**
- [ ] Resume from last position with progress bar
- [ ] Mark watched/unwatched toggle from detail screen
- [ ] Intro skip user preference (auto-skip without button press)
- [ ] Auto-play next episode with countdown
- [ ] ASS subtitle support (currently SRT only)

**Navigation & UI**
- [ ] Hub rows on home screen from /hubs endpoint (continue watching, recently added)
- [ ] Library grid/list toggle view
- [ ] Filter/sort controls (unwatched, genre, year, sort order)
- [ ] Collections browsing within libraries
- [ ] Playlists browsing and playback

**Media Types**
- [ ] Music: album/artist browse, track list, playback queue, now-playing bar
- [ ] Photos: grid, full-screen viewer, slideshow
- [ ] Live TV: EPG guide grid, channel tuning, DVR recordings list

**User Management**
- [ ] Managed users: user picker screen, PIN entry dialog

**Infrastructure**
- [ ] Pre-roll detection and playback
- [ ] PlayQueue extras
- [ ] Settings: quality, subtitle defaults, server config with roRegistry storage
- [ ] Error handling: spinners, retry logic, empty states across all screens
- [ ] Artwork caching and performance profiling
- [ ] Focus edge case fixes
- [ ] CI packaging script

### Out of Scope

- Channel store submission or certification — sideload only
- Multi-server support — single personal server
- Mobile companion app or remote control features — Roku only
- Cloud relay or plex.tv hosted playback — direct server connection only
- BrighterScript v1.0.0-alpha migration — defer until stable release
- Automated test suite — stretch goal for Phase 19 only (Rooibos)
- Watch Together — rarely used feature
- Parental controls / PIN protection — defer to v2

## Context

The official Plex Roku app (new release) is slow, buggy, and has inefficient UI navigation. SimPlex recaptures the fast, clean experience of the classic Plex sidebar-driven interface.

**Current state:** Phase 1 scaffold is complete in plain BrightScript + SceneGraph. The codebase has working auth, server connection, library browsing, detail/episode screens, search, video playback with direct play and transcode, progress reporting, and settings. All HTTP I/O runs in Task nodes.

**Technology note:** The project brief specifies BrighterScript ^0.69.x and Maestro MVVM (v0.72.0) as target technologies. The existing Phase 1 scaffold uses plain BrightScript without Maestro. This technology migration decision must be resolved before Phase 2 planning — either migrate the scaffold or continue with plain BrightScript.

**Reference repositories:** plexinc/roku-client-public (primary Plex API reference), ljunkie/rarflix (community patches), rokucommunity/brighterscript (compiler), georgejecook/maestro-roku (framework).

**Target content:** Movies and TV shows primarily. Music, photos, and live TV are later phases.

## Constraints

- **Platform:** Roku 4K TV, Roku OS 11.5+, FHD 1920x1080
- **Language:** BrightScript (existing scaffold); brief targets BrighterScript ^0.69.x — migration TBD
- **Framework:** Brief targets Maestro MVVM v0.72.0 — migration TBD
- **Deployment:** Sideloaded developer channel via F5 from VSCode
- **Server:** Single Plex Media Server, locally hosted
- **Threading:** All HTTP via Task nodes — no roUrlTransfer on render thread
- **API format:** Prefer JSON (Accept: application/json) over XML
- **Storage:** roRegistrySection("SimPlex") with Flush() after every write
- **Commit format:** feat(phaseN): description

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Sidebar navigation pattern | Matches classic Plex, efficient for library browsing | ✓ Good — implemented in Phase 1 |
| Plain BrightScript vs BrighterScript + Maestro | Brief specifies BS/Maestro but scaffold is plain BrightScript. Migration adds significant scope. | — Pending |
| Direct play first, transcode fallback | Simpler path, covers most content | ✓ Good — implemented in Phase 1 |
| JSON over XML for Plex API | Cleaner parsing, modern API pattern | ✓ Good — implemented in Phase 1 |
| Video-only for early phases | Focused scope, user's primary use case | — Pending |
| GDM discovery vs manual IP | Brief prefers GDM UDP broadcast on port 32414; current code uses plex.tv resource discovery | — Pending |
| PUT via X-HTTP-Method-Override | Roku doesn't support PUT directly; same pattern as PlexSessionTask | ✓ Good — Phase 6 |
| PGS transcode pivot with position preservation | Stop direct play, record position, start HLS transcode at offset, revert on failure | ✓ Good — Phase 6 |
| Track persistence fire-and-forget | PUT /library/parts/{id} after every track change, no error handling needed | ✓ Good — Phase 6 |
| Forced PGS subtitles skipped at initial load | Avoids unexpected transcode on first play; user can manually select from panel | ✓ Good — Phase 6 |

---
*Last updated: 2026-03-10 after Phase 8*
