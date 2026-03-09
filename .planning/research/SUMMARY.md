# Project Research Summary

**Project:** SimPlex (Roku Plex Client)
**Domain:** Roku media client application (BrightScript / SceneGraph)
**Researched:** 2026-03-08
**Confidence:** HIGH

## Executive Summary

SimPlex is a sideloaded Roku channel replacing the official Plex app with a fast, sidebar-driven UI. The existing scaffold already covers authentication, server connection, library browsing, detail/episode screens, search, and video playback. Research confirms the current plain BrightScript + SceneGraph architecture is sound and should be enhanced, not replaced. The originally proposed Maestro MVVM framework is deprecated (confirmed dead since Nov 2023) and must not be adopted. BrighterScript 0.70.x should be added as a zero-cost compile-time upgrade for type checking, namespaces, and IDE support -- no code rewrite required.

The path from scaffold to daily-driver hinges on a specific feature sequence: resume playback, watch progress indicators, hub rows (Continue Watching / Recently Added), and error states must ship first. Without these, no user would switch from the official app. After that, filter/sort, audio/subtitle selection, intro skip, and auto-play next episode bring feature parity. Differentiators like music playback, collections, playlists, and managed users follow. Live TV and photos are low priority and high complexity -- defer them.

The dominant risks are Roku-platform-specific: PGS subtitle burn-in (silent failure if handled wrong), rendezvous timeouts from observer cascades when loading hub rows, memory pressure from large ContentNode trees, and the architectural requirement that music playback audio nodes must be parented to MainScene (not any screen) to survive navigation. All of these have known mitigations documented in the pitfalls research. The single most impactful infrastructure fix -- caching GetConstants() in m.global -- should happen before any feature work to eliminate GC pressure across all subsequent phases.

## Key Findings

### Recommended Stack

BrighterScript 0.70.x as the compiler, plain SceneGraph as the UI framework, no MVVM layer. This is a near-zero-risk adoption: BrighterScript is a superset of BrightScript, so every existing `.brs` file compiles unchanged. New files can use `.bs` extension for classes and namespaces. The build toolchain is `npm install brighterscript roku-deploy` and a `bsconfig.json` file.

**Core technologies:**
- **BrighterScript 0.70.3:** Compile-time type checking, namespaces, classes -- transpiles to standard BrightScript for Roku
- **SceneGraph RSG 1.3:** Roku's native UI framework -- no alternative exists
- **roku-deploy 3.16.1:** Automated zip-and-sideload for development iteration
- **Rooibos (deferred):** Unit testing framework, available when BrighterScript is in place -- adopt when testing phase begins

**What NOT to use:** Maestro MVVM (deprecated), BrighterScript 1.0.0-alpha (unstable), ropm for app dependencies (no third-party runtime deps needed).

### Expected Features

**Must have (table stakes -- users expect these from any Plex client):**
- Resume playback from last position (read `viewOffset`, pass `offset` to playback URL)
- Watch progress indicators on poster items (progress bar overlay, watched badge)
- Mark watched / unwatched (`/:/scrobble` and `/:/unscrobble` endpoints)
- Hub rows: Continue Watching, Recently Added (`/hubs` endpoint)
- On Deck for TV shows (`/library/onDeck`)
- Filter and sort libraries (genre, year, unwatched, sort by title/date/rating)
- Audio and subtitle track selection (with PGS burn-in handling)
- Auto-play next episode (10-second countdown at end of episode)
- Error states and empty states (loading, no items, network error, retry)
- Collections browsing

**Should have (differentiators -- better than the official app):**
- Intro skip button (Plex marker API with `includeMarkers=1`)
- Credits skip / auto-next trigger
- Playlists browse and play
- Managed user switching (Plex Home API)
- Grid/list view toggle per library

**Defer (v2+):**
- Music playback (high complexity, Roku audio limitations, requires persistent Audio node architecture)
- Photo browsing and slideshow
- Live TV / DVR (requires custom EPG grid, most complex feature)
- Pre-rolls / cinema trailers

### Architecture Approach

Stay with the existing enhanced MVC + Observer pattern. MainScene acts as controller/router with a screen stack. Screens own their widgets and task instances. Tasks handle all HTTP I/O. Normalizers transform Plex JSON into ContentNode trees. Communication flows through observable interface fields with a strict contract: every screen exposes `itemSelected` (assocarray) and `navigateBack` (boolean). Invest in three targeted improvements: (1) fix API task collision by using one task per request, (2) add normalizers for each new media type, (3) enforce cleanup protocol on all screens to prevent memory leaks.

**Major components:**
1. **MainScene** -- Screen lifecycle, navigation stack, auth routing, global state coordination
2. **Screens (13 total, 6 new)** -- Full-screen views: HomeScreen, DetailScreen, EpisodeScreen, SearchScreen, SettingsScreen, plus new MusicScreen, PhotoScreen, LiveTVScreen, PlaylistScreen, UserPickerScreen, CollectionScreen
3. **Widgets (16 total, 7 new)** -- Reusable UI: Sidebar, PosterGrid, VideoPlayer, plus new PlaybackOverlay, MusicPlayer, NowPlayingBar, PhotoViewer, EPGGrid, TrackList, SubtitleRenderer
4. **Tasks (6 total, 0 new)** -- PlexApiTask is general-purpose enough for all new endpoints; no new task types needed
5. **Data layer** -- normalizers.brs (extend with per-media-type normalizers), utils.brs, constants.brs

### Critical Pitfalls

1. **PGS/bitmap subtitles silently fail on Roku** -- Roku cannot render PGS subtitles; must detect codec and force transcode with `subtitles=burn`. This is the #1 Plex+Roku complaint. Test with MKV files containing PGS tracks.
2. **Rendezvous timeouts from observer cascades** -- Loading 8+ hub rows simultaneously cascades observer callbacks that block the render thread and crash low-end devices. Stagger row loads with 100-200ms Timer delays; build ContentNode trees in Task threads.
3. **Memory pressure from ContentNode trees** -- Large libraries (10K+ items) exhaust Roku's limited RAM. Paginate at 50 items, release ContentNode trees in cleanup(), request poster images at exact display size.
4. **Music audio stops on screen navigation** -- Audio node must be parented to MainScene, not to any screen. Design this before building any music screens.
5. **Intro skip timing race condition** -- Marker data must be pre-fetched with media metadata before playback starts, not after. Otherwise the skip button appears too late for short intros.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Infrastructure and Build Tooling
**Rationale:** Cache GetConstants() in m.global (pitfall #15 affects every subsequent phase). Set up BrighterScript compiler. Fix API task collision pattern.
**Delivers:** Clean build pipeline, eliminated GC pressure, reliable concurrent API requests
**Avoids:** Pitfall #15 (GC pressure), Pitfall #13 (task collisions)

### Phase 2: Playback Foundation (Resume + Progress + Watched State)
**Rationale:** Resume playback is the single most critical missing feature. Without it, no user switches from the official app. Watch progress indicators and mark-watched depend on the same `viewOffset`/`viewCount` fields.
**Delivers:** Resume from last position, progress bars on poster items, watched badges, mark watched/unwatched
**Addresses:** Features #1, #2, #3 from table stakes

### Phase 3: Home Screen Hub Rows
**Rationale:** The home screen must surface "what's next" to be useful as a daily driver. Hub rows (Continue Watching, Recently Added, On Deck) transform the home screen from a library browser into a personalized dashboard.
**Delivers:** Continue Watching row, Recently Added row, On Deck section
**Avoids:** Pitfall #2 (rendezvous cascade -- stagger loads), Pitfall #8 (RowList stutter -- pre-fetch ahead), Pitfall #13 (task collisions -- one task per row)
**Addresses:** Features #4, #5 from table stakes

### Phase 4: Error States and UI Polish
**Rationale:** Before adding more features, ensure existing and new functionality handles failures gracefully. Loading spinners, empty states, network error retry, server unreachable messaging.
**Delivers:** Comprehensive error handling across all screens
**Addresses:** Feature #10 from table stakes

### Phase 5: Filter and Sort
**Rationale:** Large libraries (10K+ items) are unusable without filtering. Depends on stable grid infrastructure from phases 2-3.
**Delivers:** Sort by title/date/year/rating, filter by genre/year/unwatched/content rating
**Avoids:** Pitfall #2 (rebuilding large grids -- build ContentNode in task, swap atomically)
**Addresses:** Feature #6 from table stakes

### Phase 6: Audio and Subtitle Track Selection
**Rationale:** Pairs naturally as same UI pattern (PlaybackOverlay widget). Subtitle handling requires careful PGS burn-in logic.
**Delivers:** PlaybackOverlay widget, audio track picker, subtitle track picker with SRT direct play and PGS/ASS burn-in
**Avoids:** Pitfall #1 (PGS silent failure), Pitfall #6 (SubtitleTracks vs SubtitleConfig), Pitfall #10 (focus traps in overlays)
**Addresses:** Features #7, #8 from table stakes

### Phase 7: Intro/Credits Skip
**Rationale:** Depends on PlaybackOverlay from Phase 6. Same overlay pattern, same marker API.
**Delivers:** Skip Intro button, Skip Credits / auto-next trigger
**Avoids:** Pitfall #5 (pre-fetch markers before playback), Pitfall #10 (overlay focus management)
**Addresses:** Differentiators #1, #2

### Phase 8: Auto-play Next Episode
**Rationale:** Depends on credits skip trigger from Phase 7. Completes the TV binge-watching workflow.
**Delivers:** 10-second countdown at end of episode, auto-advance to next episode
**Addresses:** Feature #9 from table stakes

### Phase 9: Collections and Playlists
**Rationale:** Both are content organization features that reuse PosterGrid. Playlists share sequential playback logic with auto-play next.
**Delivers:** Collections browsing, playlist browsing and playback
**Addresses:** Feature #11 from table stakes, Differentiator #5

### Phase 10: Managed Users
**Rationale:** Cross-cutting concern (changes auth token for all API calls). Build after core features are stable.
**Delivers:** User picker screen, PIN entry, user switching with token swap
**Avoids:** Pitfall #7 (token swap invalidates active tasks -- stop all tasks, clear caches, reset screen stack)
**Addresses:** Differentiator #4

### Phase 11: Music Playback (stretch)
**Rationale:** Requires architectural change (persistent Audio node in MainScene, NowPlayingBar). High complexity. Fills gap left by official app removing music.
**Delivers:** Artist/Album/Track browsing, MusicPlayer widget, NowPlayingBar, queue management
**Avoids:** Pitfall #4 (Audio node parenting), Pitfall #12 (immutable playlist after play starts)

### Phase 12: Photos (stretch)
**Rationale:** Independent from other features. Simplest media type (no playback state management).
**Delivers:** Photo grid browsing, full-screen viewer, slideshow

### Phase 13: Live TV and DVR (stretch)
**Rationale:** Most complex feature. Custom EPG grid widget. Defer to last.
**Delivers:** Channel browsing, live stream playback, DVR recordings list
**Avoids:** Pitfall #9 (live HLS handling), Pitfall #14 (EPG grid complexity -- start with simple channel list)

### Phase Ordering Rationale

- **Phases 1-4** make the app a viable daily driver. A user could switch from the official app after these phases.
- **Phases 5-8** bring feature parity with the official Plex app for video content.
- **Phases 9-10** add content organization and household support.
- **Phases 11-13** are stretch goals for additional media types, ordered by complexity (music before photos before live TV).
- Dependencies flow downward: resume/progress must exist before hub rows can show meaningful state; PlaybackOverlay must exist before intro skip; credits skip must exist before auto-play next.
- Infrastructure fixes (Phase 1) prevent compounding issues across all later phases.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 6 (Subtitles):** PGS burn-in transcode URL construction, SubtitleTracks content metadata format, and sidecar SRT URL format all need validation against actual Roku device behavior
- **Phase 11 (Music):** Roku Audio node queue management, background playback limitations, NowPlayingBar focus management across screen stack
- **Phase 13 (Live TV):** EPG data structure from Plex, tuner session management API, custom grid virtualization on Roku

Phases with standard patterns (skip research-phase):
- **Phase 1 (Infrastructure):** BrighterScript setup is well-documented with migration guides
- **Phase 2 (Resume/Progress):** Standard Plex API fields, straightforward implementation
- **Phase 3 (Hub Rows):** Well-documented Plex `/hubs` API, existing MediaRow widget
- **Phase 5 (Filter/Sort):** Standard Plex API query parameters, existing grid infrastructure
- **Phase 9 (Collections/Playlists):** Standard CRUD-style Plex API endpoints, reuses existing widgets

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | BrighterScript stable branch verified, Maestro deprecation confirmed via GitHub, Jellyfin-Roku validates production use |
| Features | HIGH | Plex API endpoints verified against Plexopedia, plexapi.dev, and official Plex support docs. User complaints verified via Plex forums. |
| Architecture | HIGH | Patterns grounded in Roku official docs, existing codebase analysis, and DAZN engineering benchmarks. Maestro assessment based on official Maestro docs. |
| Pitfalls | HIGH | Platform limitations verified via Roku developer docs. PGS issue confirmed by multiple sources. Rendezvous mechanics from Roku SDK archives. |

**Overall confidence:** HIGH

### Gaps to Address

- **Transcode URL construction for PGS burn-in:** The exact parameter format (`subtitles=burn&subtitleStreamID={id}`) needs validation against a real Plex server during Phase 6 planning. Documentation is sparse.
- **Roku Audio node background playback:** Whether audio continues when the Roku screensaver activates is unclear. Test on device during Phase 11.
- **Managed user token scope:** Whether managed user tokens can access all server endpoints or have restrictions needs validation against Plex Home API during Phase 10 planning.
- **BrighterScript 0.70.3 compatibility with existing codebase:** While the superset guarantee means it should work, the specific `diagnosticFilters` needed for existing code should be validated during Phase 1.

## Sources

### Primary (HIGH confidence)
- [BrighterScript GitHub](https://github.com/rokucommunity/brighterscript) -- v0.70.3 stable, compiler features, bsconfig.json
- [Maestro-Roku GitHub](https://github.com/georgejecook/maestro-roku) -- Confirmed deprecated, v0.72.0 final release Nov 2023
- [Roku SceneGraph Core Concepts](https://developer.roku.com/docs/developer-program/core-concepts/core-concepts.md) -- Architecture patterns
- [Roku Closed Caption docs](https://developer.roku.com/docs/developer-program/media-playback/closed-caption.md) -- Subtitle format support
- [Roku Memory Management](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md) -- Memory limits
- [Roku SceneGraph Threads](https://sdkdocs-archive.roku.com/SceneGraph-Threads_4262152.html) -- Rendezvous mechanics
- [Plex API: Global Hubs](https://plexapi.dev/api-reference/hubs/get-global-hubs) -- Hub rows endpoint
- [Plex API: Mark Watched](https://www.plexopedia.com/plex-media-server/api/library/media-mark-watched/) -- Scrobble endpoint
- [Plex Skip Content](https://support.plex.tv/articles/skip-content/) -- Intro/credits markers
- [Plex Fast User Switching](https://support.plex.tv/articles/204232453-fast-user-switching/) -- Managed users

### Secondary (MEDIUM confidence)
- [ContentNode Benchmarks (DAZN Engineering)](https://medium.com/dazn-tech/rokus-scenegraph-benchmarks-aa-vs-node-9be5158474c1) -- Performance data
- [Plex Roku app backlash](https://piunikaweb.com/2025/09/17/plex-roku-update-backlash/) -- User sentiment
- [PGS Subtitles on Roku (How-To Geek)](https://www.howtogeek.com/as-a-plex-user-im-begging-roku-to-support-pgs-subtitles/) -- PGS limitation confirmation
- [Plex Labs RSG Application](https://medium.com/plexlabs/xml-code-good-times-rsg-application-b963f0cec01b) -- Architecture reference

### Tertiary (LOW confidence)
- [RARflix community Roku client](https://github.com/ljunkie/rarflix) -- Historical reference for Roku Plex client patterns (project inactive)

---
*Research completed: 2026-03-08*
*Ready for roadmap: yes*
