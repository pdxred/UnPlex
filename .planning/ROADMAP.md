# Roadmap: PlexClassic

## Overview

PlexClassic ships in 10 phases, starting with architectural foundation and Task node patterns, progressing through authentication and navigation framework, building library browsing and detail views, implementing playback (basic then advanced), adding search, enhancing content organization, and finishing with auto-play polish. Each phase delivers working, verifiable functionality that builds on previous work. The roadmap derives directly from 27 v1 requirements, with 100% coverage and no orphaned features.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation & Architecture** - Project scaffolding, Task patterns, API abstraction layer
- [ ] **Phase 2: Authentication** - PIN-based OAuth, server discovery, token persistence
- [ ] **Phase 3: Navigation Framework** - MainScene screen stack, sidebar, back button handling
- [ ] **Phase 4: Library Browsing** - Poster grid, library sections, pagination, On Deck, Recently Added
- [ ] **Phase 5: Media Detail Views** - Detail screen, TV show seasons, episode browser
- [ ] **Phase 6: Basic Playback** - Direct Play, transcode fallback, progress tracking, resume
- [ ] **Phase 7: Advanced Playback** - Audio/subtitle tracks, intro/credits skip, chapters, number key jump
- [ ] **Phase 8: Search** - Search screen, PlexSearchTask with debouncing, results grid
- [ ] **Phase 9: Content Organization** - Filters, sort, Collections, Playlists
- [ ] **Phase 10: Auto-Play & Polish** - Next episode countdown, unwatched indicators, focus restoration

## Phase Details

### Phase 1: Foundation & Architecture
**Goal**: Establish project structure, Task node patterns, and API abstraction layer that all subsequent phases depend on.
**Depends on**: Nothing (first phase)
**Requirements**: ARCH-01, ARCH-02, ARCH-03
**Success Criteria** (what must be TRUE):
  1. Project builds and side-loads to Roku device without errors
  2. Task nodes handle all HTTP requests (no render thread blocking)
  3. PlexApiTask can make authenticated requests with proper headers and SSL certificates
  4. API responses are normalized to ContentNode trees before reaching UI components
  5. App gracefully handles missing Plex server features (version detection works)
**Plans:** 2 plans

Plans:
- [ ] 01-01-PLAN.md — Enhanced PlexApiTask with POST support, logger, SafeGet utilities
- [ ] 01-02-PLAN.md — ContentNode normalizers and server capability detection

### Phase 2: Authentication
**Goal**: Users can authenticate via plex.tv PIN code and connect to their Plex server.
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05
**Success Criteria** (what must be TRUE):
  1. User can authenticate by entering PIN code at plex.tv/link
  2. App discovers available Plex servers (local connection prioritized, remote/relay fallback works)
  3. Auth token and selected server URI persist across app restarts
  4. App detects server version and adapts to available capabilities
  5. App redirects to re-authentication when token expires (401 responses handled)
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 3: Navigation Framework
**Goal**: MainScene screen stack enables navigation between views with back button support and focus restoration.
**Depends on**: Phase 2
**Requirements**: NAV-10 (focus preservation)
**Success Criteria** (what must be TRUE):
  1. MainScene manages screen stack (push new screens, pop on back button)
  2. Sidebar component displays library list and navigation options
  3. Back button returns to previous screen without losing focus position
  4. Screen cleanup prevents memory leaks (proper unobserveField and removeChild)
  5. Focus automatically moves to appropriate elements when screens change
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 4: Library Browsing
**Goal**: Users can browse Movies and TV Shows libraries in paginated poster grids with Continue Watching and Recently Added sections.
**Depends on**: Phase 3
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04, NAV-09
**Success Criteria** (what must be TRUE):
  1. User can browse library content in poster grid (6 columns, 240x360 posters)
  2. Library content loads in pages of 50 items (pagination prevents crashes with large libraries)
  3. User can access On Deck / Continue Watching section
  4. User can access Recently Added section
  5. Unwatched indicators appear on content items
  6. Poster images load at correct resolution (no memory exhaustion from full-res images)
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 5: Media Detail Views
**Goal**: Users can view full metadata for movies and browse TV show episodes organized by season.
**Depends on**: Phase 4
**Requirements**: MEDIA-01, MEDIA-02, MEDIA-03
**Success Criteria** (what must be TRUE):
  1. User can view full metadata for movies (poster, title, year, runtime, rating, genres, plot)
  2. User can browse TV show seasons via tabs
  3. User can view episode list with thumbnails, titles, plots, durations
  4. Selecting an item from library grid navigates to detail screen
  5. Detail screen provides clear play button to start playback
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 6: Basic Playback
**Goal**: Users can watch content via Direct Play or transcode, with progress tracking and resume capability.
**Depends on**: Phase 5
**Requirements**: PLAY-01, PLAY-02, PLAY-03, PLAY-04, PLAY-05
**Success Criteria** (what must be TRUE):
  1. Video plays via Direct Play for Roku-compatible formats (H.264, HEVC, VP9)
  2. Video automatically transcodes via HLS when Direct Play format is incompatible
  3. Playback progress is tracked every 10 seconds and sent to Plex server
  4. User can resume from last position when returning to partially watched content
  5. Content is marked watched on completion (90% threshold)
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 7: Advanced Playback
**Goal**: Users can control audio/subtitle tracks, skip intros/credits, navigate chapters, and jump to timestamps.
**Depends on**: Phase 6
**Requirements**: PLAY-06, PLAY-07, PLAY-08, PLAY-09, PLAY-10, PLAY-11
**Success Criteria** (what must be TRUE):
  1. User can select audio tracks during playback via on-screen menu
  2. User can select subtitle tracks during playback via on-screen menu
  3. Intro skip button appears when Plex intro markers are detected
  4. Credits skip button appears when Plex credits markers are detected
  5. User can navigate to chapters via separate chapter menu
  6. User can jump to specific time by entering numbers on remote (0-9 keys)
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 8: Search
**Goal**: Users can search across all libraries with debounced keyboard input and grid results display.
**Depends on**: Phase 7
**Requirements**: SRCH-01, SRCH-02
**Success Criteria** (what must be TRUE):
  1. User can access search screen from sidebar
  2. User can search across all libraries using on-screen keyboard
  3. Search results display in poster grid (same format as library browsing)
  4. PlexSearchTask debounces input to prevent excessive API calls
  5. Selecting search result navigates to detail screen (reuses Phase 5 screens)
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 9: Content Organization
**Goal**: Users can filter/sort library content, browse Collections, and play Playlists.
**Depends on**: Phase 8
**Requirements**: NAV-05, NAV-06, NAV-07, NAV-08
**Success Criteria** (what must be TRUE):
  1. User can browse Collections within libraries
  2. User can browse and play Playlists
  3. User can filter content by unwatched status, genre, and year
  4. User can sort content by title, year, and date added
  5. Filter and sort selections persist within current session
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

### Phase 10: Auto-Play & Polish
**Goal**: Next episode auto-plays with countdown, and all navigation refinements work smoothly.
**Depends on**: Phase 9
**Requirements**: MEDIA-04
**Success Criteria** (what must be TRUE):
  1. Next episode auto-plays with 10-second countdown after current episode ends
  2. User can cancel auto-play countdown to return to episode list
  3. All focus positions are preserved correctly throughout navigation
  4. App handles edge cases gracefully (missing metadata, network errors, etc.)
  5. Memory usage remains stable across extended browsing sessions
**Plans**: TBD

Plans:
- [ ] TBD during plan-phase

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Architecture | 0/2 | Planned | - |
| 2. Authentication | 0/0 | Not started | - |
| 3. Navigation Framework | 0/0 | Not started | - |
| 4. Library Browsing | 0/0 | Not started | - |
| 5. Media Detail Views | 0/0 | Not started | - |
| 6. Basic Playback | 0/0 | Not started | - |
| 7. Advanced Playback | 0/0 | Not started | - |
| 8. Search | 0/0 | Not started | - |
| 9. Content Organization | 0/0 | Not started | - |
| 10. Auto-Play & Polish | 0/0 | Not started | - |

---
*Created: 2026-02-09*
*Last updated: 2026-02-09*
