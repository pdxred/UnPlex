# Requirements: PlexClassic

**Defined:** 2025-02-09
**Core Value:** Fast, intuitive library browsing and playback. Getting to your media quickly without fighting the UI.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication & Connection

- [ ] **AUTH-01**: User can authenticate via PIN code at plex.tv/link
- [ ] **AUTH-02**: App discovers available Plex servers (local, remote, relay fallback)
- [ ] **AUTH-03**: Auth token and server URI persist across app restarts
- [ ] **AUTH-04**: App detects server version for capability awareness
- [ ] **AUTH-05**: App redirects to re-auth when token expires (401 handling)

### Navigation & Browsing

- [ ] **NAV-01**: User can browse libraries via sidebar navigation
- [ ] **NAV-02**: User can view library content in paginated poster grid (50 items/page)
- [ ] **NAV-03**: User can access On Deck / Continue Watching
- [ ] **NAV-04**: User can access Recently Added
- [ ] **NAV-05**: User can browse Collections within libraries
- [ ] **NAV-06**: User can browse and play Playlists
- [ ] **NAV-07**: User can filter content by unwatched, genre, year
- [ ] **NAV-08**: User can sort content by title, year, date added
- [ ] **NAV-09**: User sees unwatched indicators on content items
- [ ] **NAV-10**: Focus position is preserved when navigating back

### Media Viewing

- [ ] **MEDIA-01**: User can view full metadata for movies (poster, title, year, runtime, rating, genres, plot)
- [ ] **MEDIA-02**: User can browse TV show seasons via tabs
- [ ] **MEDIA-03**: User can view episode list with thumbnails, titles, plots, durations
- [ ] **MEDIA-04**: Next episode auto-plays with 10-second countdown after current episode ends

### Playback

- [ ] **PLAY-01**: Video plays via Direct Play for Roku-compatible formats (H.264, HEVC, VP9)
- [ ] **PLAY-02**: Video transcodes via HLS for incompatible formats
- [ ] **PLAY-03**: Playback progress is tracked every 10 seconds
- [ ] **PLAY-04**: User can resume from last position
- [ ] **PLAY-05**: Content is marked watched on completion
- [ ] **PLAY-06**: User can select audio tracks during playback
- [ ] **PLAY-07**: User can select subtitles during playback
- [ ] **PLAY-08**: Intro skip button appears when Plex markers detected
- [ ] **PLAY-09**: Credits skip button appears when Plex markers detected
- [ ] **PLAY-10**: User can navigate to chapters via separate menu
- [ ] **PLAY-11**: User can jump to specific time via number keys on remote

### Search

- [ ] **SRCH-01**: User can search across all libraries
- [ ] **SRCH-02**: Search results display in poster grid

### Architecture

- [ ] **ARCH-01**: All Plex API calls go through abstraction layer
- [ ] **ARCH-02**: API responses are normalized to internal models
- [ ] **ARCH-03**: App gracefully degrades for missing server features

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Authentication

- **AUTH-06**: User can switch between multiple Plex servers

### Search

- **SRCH-03**: Search results update as user types (debounced 500ms)

### Future Enhancements

- **FUT-01**: Music library support
- **FUT-02**: Photo library support
- **FUT-03**: Multiple home user profiles
- **FUT-04**: Parental controls / PIN protection

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Music library | Video-only client for v1, user's primary use case |
| Photo library | Video-only client for v1, user's primary use case |
| Multiple profiles | Single-user for v1, complexity deferred |
| Live TV & DVR | Not core browsing use case |
| Watch Together | Rarely used, high complexity |
| Trailers & Extras | Not essential for replacement |
| Prerolls | Not essential for replacement |
| Parental controls | Defer to v2 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ARCH-01 | Phase 1 | Pending |
| ARCH-02 | Phase 1 | Pending |
| ARCH-03 | Phase 1 | Pending |
| AUTH-01 | Phase 2 | Pending |
| AUTH-02 | Phase 2 | Pending |
| AUTH-03 | Phase 2 | Pending |
| AUTH-04 | Phase 2 | Pending |
| AUTH-05 | Phase 2 | Pending |
| NAV-10 | Phase 3 | Pending |
| NAV-01 | Phase 4 | Pending |
| NAV-02 | Phase 4 | Pending |
| NAV-03 | Phase 4 | Pending |
| NAV-04 | Phase 4 | Pending |
| NAV-09 | Phase 4 | Pending |
| MEDIA-01 | Phase 5 | Pending |
| MEDIA-02 | Phase 5 | Pending |
| MEDIA-03 | Phase 5 | Pending |
| PLAY-01 | Phase 6 | Pending |
| PLAY-02 | Phase 6 | Pending |
| PLAY-03 | Phase 6 | Pending |
| PLAY-04 | Phase 6 | Pending |
| PLAY-05 | Phase 6 | Pending |
| PLAY-06 | Phase 7 | Pending |
| PLAY-07 | Phase 7 | Pending |
| PLAY-08 | Phase 7 | Pending |
| PLAY-09 | Phase 7 | Pending |
| PLAY-10 | Phase 7 | Pending |
| PLAY-11 | Phase 7 | Pending |
| SRCH-01 | Phase 8 | Pending |
| SRCH-02 | Phase 8 | Pending |
| NAV-05 | Phase 9 | Pending |
| NAV-06 | Phase 9 | Pending |
| NAV-07 | Phase 9 | Pending |
| NAV-08 | Phase 9 | Pending |
| MEDIA-04 | Phase 10 | Pending |

**Coverage:**
- v1 requirements: 27 total
- Mapped to phases: 27
- Unmapped: 0

**Coverage: 100% (all v1 requirements mapped)**

---
*Requirements defined: 2025-02-09*
*Last updated: 2026-02-09 after roadmap creation*
