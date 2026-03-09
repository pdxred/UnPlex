# Roadmap: SimPlex

## Overview

SimPlex transforms a working scaffold (auth, browsing, playback) into a daily-driver Plex client for Roku. Phases 1-4 make the app viable enough to replace the official Plex app. Phases 5-8 bring video feature parity. Phases 9-10 add content organization and household support. Each phase delivers a coherent, testable capability that builds on the previous.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Infrastructure** - BrighterScript compiler, constants caching, API task fix
- [ ] **Phase 2: Playback Foundation** - Resume, progress indicators, watched state
- [ ] **Phase 3: Hub Rows** - Continue Watching, Recently Added, On Deck
- [ ] **Phase 4: Error States** - Loading spinners, empty states, network error handling
- [ ] **Phase 5: Filter and Sort** - Library sorting and filtering controls
- [ ] **Phase 6: Audio and Subtitles** - Track selection with PGS burn-in fallback
- [ ] **Phase 7: Intro and Credits Skip** - Skip buttons via Plex chapter markers
- [ ] **Phase 8: Auto-play Next Episode** - End-of-episode countdown and advance
- [ ] **Phase 9: Collections and Playlists** - Content organization and sequential playback
- [ ] **Phase 10: Managed Users** - User picker, switching, PIN entry

## Phase Details

### Phase 1: Infrastructure
**Goal**: Reliable build toolchain and runtime foundation that eliminates technical debt before feature work begins
**Depends on**: Nothing (existing scaffold is the starting point)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04
**Success Criteria** (what must be TRUE):
  1. BrighterScript compiles all existing .brs files with zero errors and F5 deploys to Roku
  2. Constants are loaded once at startup and accessed from m.global without per-call allocation
  3. Two or more API requests can run concurrently without one clobbering the other's callback
  4. Developer presses F5 in VSCode and the app appears on Roku with no manual zip/upload steps
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — BrighterScript toolchain setup and VSCode F5 deploy configuration
- [ ] 01-02-PLAN.md — Constants caching in m.global and API task collision fix

### Phase 2: Playback Foundation
**Goal**: Users can resume where they left off and see at a glance what they have and haven't watched
**Depends on**: Phase 1
**Requirements**: PLAY-01, PLAY-02, PLAY-03, PLAY-04, PLAY-05
**Success Criteria** (what must be TRUE):
  1. Selecting a partially-watched item starts playback from the last position (not the beginning)
  2. Poster items in grids show a progress bar indicating how much of the item has been watched
  3. Poster items show a watched/unwatched badge based on view count
  4. User can mark an item as watched or unwatched from the detail screen and the badge updates immediately
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD

### Phase 3: Hub Rows
**Goal**: Home screen surfaces personalized "what to watch next" content without requiring library browsing
**Depends on**: Phase 2 (progress/watched state needed for meaningful hub row display)
**Requirements**: HOME-01, HOME-02, HOME-03
**Success Criteria** (what must be TRUE):
  1. Home screen displays a Continue Watching row with partially-watched items showing progress bars
  2. Home screen displays a Recently Added row with new content across libraries
  3. Home screen displays an On Deck row for TV shows (next unwatched episode)
  4. Hub rows load without freezing the UI or causing visible stutter on navigation
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: Error States
**Goal**: Every async operation communicates its status clearly and failures are recoverable without restarting the app
**Depends on**: Phase 3 (error handling should cover all screens including hub rows)
**Requirements**: ERR-01, ERR-02, ERR-03, ERR-04
**Success Criteria** (what must be TRUE):
  1. Every screen that fetches data shows a loading spinner until content appears
  2. Empty libraries and searches display a clear "no items" message instead of a blank screen
  3. Network failures show an error message with a retry option that re-attempts the failed request
  4. Server unreachable state shows a message with a reconnect option that re-tests server connectivity
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Filter and Sort
**Goal**: Users can find specific content in large libraries without scrolling through thousands of items
**Depends on**: Phase 4 (error states needed for empty filter results)
**Requirements**: LIB-01, LIB-02, LIB-03, LIB-04
**Success Criteria** (what must be TRUE):
  1. User can sort a library by title, date added, year, or rating and the grid re-populates accordingly
  2. User can filter to show only unwatched items
  3. User can filter by genre and see only matching items
  4. User can filter by year or decade and see only matching items
  5. Active filters are visually indicated and can be cleared
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: Audio and Subtitles
**Goal**: Users can select audio and subtitle tracks during playback, with bitmap subtitles handled transparently
**Depends on**: Phase 2 (playback infrastructure)
**Requirements**: PLAY-06, PLAY-07, PLAY-08, PLAY-09
**Success Criteria** (what must be TRUE):
  1. User can open a track selection overlay during playback and switch audio tracks
  2. User can select a subtitle track from the overlay and subtitles appear on screen
  3. SRT/text subtitles render correctly via sidecar delivery without transcoding
  4. PGS/bitmap subtitle selection automatically triggers transcode with burn-in (no silent failure)
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD

### Phase 7: Intro and Credits Skip
**Goal**: Users can skip intros and credits with a single button press, matching the official Plex experience
**Depends on**: Phase 6 (reuses PlaybackOverlay widget and overlay focus management)
**Requirements**: PLAY-10, PLAY-11
**Success Criteria** (what must be TRUE):
  1. A "Skip Intro" button appears during the intro marker timespan and pressing it jumps past the intro
  2. A "Skip Credits" or "Next Episode" button appears at the credits marker timespan
  3. Skip buttons appear promptly (markers pre-fetched before playback, not after)
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

### Phase 8: Auto-play Next Episode
**Goal**: TV show binge-watching flows seamlessly from one episode to the next
**Depends on**: Phase 7 (credits marker triggers the countdown)
**Requirements**: PLAY-12, PLAY-13
**Success Criteria** (what must be TRUE):
  1. At the end of an episode, a 10-second countdown appears offering to play the next episode
  2. User can cancel the countdown and remain on the current episode's end screen
  3. If the countdown completes, the next episode begins playing automatically
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

### Phase 9: Collections and Playlists
**Goal**: Users can browse organized content groups and play items sequentially from playlists
**Depends on**: Phase 5 (library browsing infrastructure), Phase 8 (sequential playback pattern)
**Requirements**: LIB-05, LIB-06, LIB-07
**Success Criteria** (what must be TRUE):
  1. User can browse collections within a library and see collection contents in a grid
  2. User can browse playlists and see playlist contents
  3. Playing an item from a playlist automatically advances to the next playlist item
**Plans**: TBD

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD

### Phase 10: Managed Users
**Goal**: Household members can switch between managed Plex users without re-authenticating
**Depends on**: All prior phases (user switch resets app state; all features must handle token swap)
**Requirements**: USER-01, USER-02, USER-03
**Success Criteria** (what must be TRUE):
  1. A user picker screen shows all managed users from the Plex Home account
  2. Selecting a managed user switches the active session and reloads all content for that user
  3. PIN-protected managed users require PIN entry before switching
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 > 2 > 3 > 4 > 5 > 6 > 7 > 8 > 9 > 10

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Infrastructure | 0/2 | Not started | - |
| 2. Playback Foundation | 0/2 | Not started | - |
| 3. Hub Rows | 0/2 | Not started | - |
| 4. Error States | 0/2 | Not started | - |
| 5. Filter and Sort | 0/2 | Not started | - |
| 6. Audio and Subtitles | 0/2 | Not started | - |
| 7. Intro and Credits Skip | 0/1 | Not started | - |
| 8. Auto-play Next Episode | 0/1 | Not started | - |
| 9. Collections and Playlists | 0/2 | Not started | - |
| 10. Managed Users | 0/1 | Not started | - |
