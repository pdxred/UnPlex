# SimPlex

## What This Is

A side-loadable Roku channel that serves as a full replacement Plex Media Server client. Replaces the official Plex Roku app with a clean, fast, grid-based UI inspired by the old "Plex Classic" Roku client, using a left sidebar navigation pattern for intuitive library browsing.

## Core Value

Fast, intuitive library browsing and playback. Getting to your media quickly without fighting the UI.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Authentication & Connection**
- [ ] PIN-based OAuth flow via plex.tv/link
- [ ] Server discovery with local/remote/relay connection fallback
- [ ] Persistent token and server storage
- [ ] Server version detection for capability awareness

**Library Browsing**
- [ ] Sidebar navigation (libraries, On Deck, Recently Added, Search, Settings)
- [ ] Poster grid with paginated loading (50 items per page)
- [ ] Collections browsing within libraries
- [ ] Playlists browsing and playback
- [ ] Filters: unwatched, genre, year, sort order
- [ ] Search across all libraries

**Media Viewing**
- [ ] Detail screen with full metadata (poster, title, year, runtime, rating, genres, plot)
- [ ] Episode browser with season tabs for TV shows
- [ ] Episode list with thumbnails, titles, plots, durations
- [ ] Unwatched indicators on items

**Playback**
- [ ] Direct play for Roku-compatible formats (H.264, HEVC, VP9, AAC, AC3, EAC3)
- [ ] Transcode fallback via HLS for incompatible formats
- [ ] Progress tracking every 10 seconds
- [ ] Resume from last position
- [ ] Mark watched on completion
- [ ] Intro skip button (when Plex chapter markers detected)
- [ ] Credits skip button (when Plex chapter markers detected)
- [ ] Jump-to-time via number keys (0-9 on remote)
- [ ] Chapter navigation menu (separate from jump-to-time)
- [ ] Audio track selection during playback
- [ ] Subtitle track selection during playback
- [ ] Auto-play next episode with countdown

**Architecture**
- [ ] API abstraction layer (all Plex calls through service layer)
- [ ] Response normalization to internal models
- [ ] Graceful degradation for missing server features

### Out of Scope

- Music library support — video-only client for v1
- Photo library support — video-only client for v1
- Multiple home users/profiles — single-user for v1
- Live TV & DVR — not a core browsing use case
- Watch Together — rarely used feature
- Trailers & Extras — not essential for replacement
- Prerolls — not essential for replacement
- Parental controls / PIN protection — defer to v2

## Context

The official Plex Roku app (new release) is slow, buggy, and has inefficient/non-intuitive UI navigation. The goal is to recapture the fast, clean experience of older Plex clients that used a simple sidebar navigation pattern.

This is a BrightScript + SceneGraph project. Roku apps use `.brs` files for logic and `.xml` files for UI components. This is NOT JavaScript, Python, or any web technology.

Target content: Movies and TV Shows libraries. User's Plex server does not use Music or Photos.

## Constraints

- **Platform:** Roku devices only, FHD 1920x1080 resolution
- **Tech stack:** BrightScript + SceneGraph exclusively
- **Deployment:** Side-loaded channel (not in Roku Channel Store)
- **Threading:** All HTTP requests must run in Task nodes (render thread blocking causes crashes)
- **Components:** Use built-in Roku components (MarkupGrid, PosterGrid, RowList, LabelList) for virtualization
- **Images:** Request resized posters via Plex transcode endpoint, never full resolution
- **Storage:** Use roRegistrySection("PlexClassic") for persistent data, always Flush() after writes
- **Navigation:** Back button always pops screen stack, no wrap-around on grids/lists

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Sidebar navigation pattern | Matches classic Plex feel, efficient for library browsing | — Pending |
| API abstraction layer | Future-proofs against Plex API changes, isolates maintenance | — Pending |
| Number keys for jump-to-time | Fastest input method, most Roku remotes have number pad | — Pending |
| Chapters as separate menu | Cleaner UX, different use case from arbitrary timestamp jumps | — Pending |
| Video-only for v1 | Focused scope, user's primary use case | — Pending |

---
*Last updated: 2025-02-09 after initialization*
