# Requirements: SimPlex

**Defined:** 2026-03-08
**Core Value:** Fast, intuitive library browsing and playback on a single personal Plex server

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Infrastructure

- [ ] **INFRA-01**: BrighterScript 0.70.x compiler set up with bsconfig.json and roku-deploy
- [ ] **INFRA-02**: GetConstants() cached in m.global to eliminate per-call GC pressure
- [ ] **INFRA-03**: API task collision pattern fixed (one task instance per concurrent request)
- [ ] **INFRA-04**: F5 deploy from VSCode works with zero manual steps

### Playback

- [ ] **PLAY-01**: User can resume playback from last position (viewOffset)
- [ ] **PLAY-02**: User sees progress bar overlay on poster items showing watch progress
- [ ] **PLAY-03**: User sees watched/unwatched badge on poster items (viewCount)
- [ ] **PLAY-04**: User can mark item as watched from detail screen
- [ ] **PLAY-05**: User can mark item as unwatched from detail screen
- [ ] **PLAY-06**: User can select audio track during playback
- [ ] **PLAY-07**: User can select subtitle track during playback
- [ ] **PLAY-08**: SRT/text subtitles render via sidecar delivery
- [ ] **PLAY-09**: PGS/bitmap subtitles trigger transcode with burn-in automatically
- [ ] **PLAY-10**: User sees "Skip Intro" button during intro marker timespan
- [ ] **PLAY-11**: User sees "Skip Credits" / "Next Episode" button at credits marker
- [ ] **PLAY-12**: Auto-play next episode with 10-second countdown at end of episode
- [ ] **PLAY-13**: User can cancel auto-play countdown

### Home Screen

- [ ] **HOME-01**: Home screen displays hub rows (Continue Watching, Recently Added)
- [ ] **HOME-02**: Home screen displays On Deck row for TV shows
- [ ] **HOME-03**: Hub rows load with staggered requests (no rendezvous cascade)

### Library

- [ ] **LIB-01**: User can sort library by title, date added, year, rating
- [ ] **LIB-02**: User can filter library by unwatched status
- [ ] **LIB-03**: User can filter library by genre
- [ ] **LIB-04**: User can filter library by year/decade
- [ ] **LIB-05**: User can browse collections within a library
- [ ] **LIB-06**: User can browse playlists
- [ ] **LIB-07**: User can play items from a playlist sequentially

### User Management

- [ ] **USER-01**: User picker screen shows managed users from Plex Home
- [ ] **USER-02**: User can switch between managed users
- [ ] **USER-03**: PIN entry dialog for PIN-protected managed users

### Error Handling

- [ ] **ERR-01**: Loading spinners shown during all async operations
- [ ] **ERR-02**: Empty state messages shown when no items found
- [ ] **ERR-03**: Network error messages with retry option
- [ ] **ERR-04**: Server unreachable messaging with reconnect option

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Music

- **MUSIC-01**: User can browse music library (artists, albums, tracks)
- **MUSIC-02**: User can play music tracks with queue management
- **MUSIC-03**: Now-playing bar persists across screen navigation
- **MUSIC-04**: Music player supports background audio during browsing

### Photos

- **PHOTO-01**: User can browse photo library in grid view
- **PHOTO-02**: User can view photos full-screen
- **PHOTO-03**: User can run slideshow with configurable timer

### Live TV

- **LIVE-01**: User can browse live TV channels
- **LIVE-02**: User can tune to a live channel and watch
- **LIVE-03**: User can browse DVR recordings
- **LIVE-04**: EPG grid shows program schedule

### Polish

- **POLISH-01**: Grid/list view toggle per library type
- **POLISH-02**: Pre-roll / cinema trailer playback via PlayQueue extras
- **POLISH-03**: Artwork caching and image prefetch optimization
- **POLISH-04**: Performance profiling and memory optimization
- **POLISH-05**: Rooibos unit test integration

## Out of Scope

| Feature | Reason |
|---------|--------|
| Maestro MVVM migration | Framework deprecated (Nov 2023); existing MVC + Observer is idiomatic and sufficient |
| BrighterScript v1.0.0-alpha | Unstable alpha with breaking changes between releases |
| Channel store submission | Sideload only; certification adds constraints |
| Multi-server browsing | Single personal server; server switching via settings only |
| Cloud relay playback | Direct server connection only per project constraints |
| Plex Discover / streaming integration | Personal media only; no third-party content |
| Social features (Watch Together) | Complexity with no value for personal/household use |
| Fancy animations / transitions | The official app's animations make it feel slow; instant transitions preferred |
| Horizontal tab navigation | Sidebar is the product identity; tabs are the #1 user complaint about the new Plex app |
| Offline downloads | Roku has no filesystem for media storage |
| DVR recording scheduling | High complexity, niche use case; browse recordings only if Live TV added |
| Parental controls / PIN protection | Defer to v2; Plex server handles restrictions at user level |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Pending |
| INFRA-04 | Phase 1 | Pending |
| PLAY-01 | Phase 2 | Pending |
| PLAY-02 | Phase 2 | Pending |
| PLAY-03 | Phase 2 | Pending |
| PLAY-04 | Phase 2 | Pending |
| PLAY-05 | Phase 2 | Pending |
| HOME-01 | Phase 3 | Pending |
| HOME-02 | Phase 3 | Pending |
| HOME-03 | Phase 3 | Pending |
| ERR-01 | Phase 4 | Pending |
| ERR-02 | Phase 4 | Pending |
| ERR-03 | Phase 4 | Pending |
| ERR-04 | Phase 4 | Pending |
| LIB-01 | Phase 5 | Pending |
| LIB-02 | Phase 5 | Pending |
| LIB-03 | Phase 5 | Pending |
| LIB-04 | Phase 5 | Pending |
| PLAY-06 | Phase 6 | Pending |
| PLAY-07 | Phase 6 | Pending |
| PLAY-08 | Phase 6 | Pending |
| PLAY-09 | Phase 6 | Pending |
| PLAY-10 | Phase 7 | Pending |
| PLAY-11 | Phase 7 | Pending |
| PLAY-12 | Phase 8 | Pending |
| PLAY-13 | Phase 8 | Pending |
| LIB-05 | Phase 9 | Pending |
| LIB-06 | Phase 9 | Pending |
| LIB-07 | Phase 9 | Pending |
| USER-01 | Phase 10 | Pending |
| USER-02 | Phase 10 | Pending |
| USER-03 | Phase 10 | Pending |

**Coverage:**
- v1 requirements: 34 total
- Mapped to phases: 34
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-08*
*Last updated: 2026-03-08 after initial definition*
