# Project Research Summary

**Project:** PlexClassic
**Domain:** Roku Plex Media Server Client
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

PlexClassic is a custom Roku channel that replaces the official Plex app with a fast, grid-based UI inspired by the original "Plex Classic" client. Expert developers build Roku media clients using BrightScript/SceneGraph with strict separation between render thread (UI) and Task nodes (all HTTP/background operations). The platform is unforgiving of mistakes—HTTP on render thread causes crashes, missing SSL certificates break all requests, and memory leaks from observer patterns accumulate over time.

The recommended approach is a component-based architecture with Task nodes for all API communication, ContentNode trees for data (not associative arrays), and built-in UI components (PosterGrid, RowList, Video). Use BrighterScript for development to gain modern language features while maintaining full Roku compatibility. The architecture centers on a screen stack manager (MainScene) that pushes/pops full-screen views, with field observers connecting UI to background Tasks. Start with authentication and establish patterns immediately—the foundation phase determines code quality for the entire project.

Key risks are render thread blocking (causes crashes), memory leaks from improper observer cleanup, and image loading without scaling (exhausts memory on low-end devices). Mitigation requires strict adherence to Task node patterns, unobserveField() discipline, and requesting pre-scaled images from Plex's transcode API. The technology stack is mature and well-documented, but the platform punishes architectural mistakes severely. Following established patterns from research prevents costly refactoring later.

## Key Findings

### Recommended Stack

PlexClassic requires Roku-specific technologies with no alternatives. The stack is BrightScript/SceneGraph running on Roku OS 15.0+, targeting FHD 1920x1080 resolution. BrighterScript (a transpiled superset of BrightScript) is strongly recommended for development, providing classes, namespaces, and modern syntax while compiling to standard BrightScript. The RokuCommunity toolchain (VSCode extension, bslint, roku-deploy, ropm) is industry standard for professional development.

**Core technologies:**
- **BrighterScript 0.70.3+**: Development language that compiles to BrightScript — adds modern features (classes, ternary operators, template strings) without sacrificing compatibility. Catches errors at compile-time.
- **Roku SceneGraph 1.3**: Component-based UI framework — mandatory for certification by October 2026. XML layouts paired with BrightScript logic files.
- **Task nodes**: Background threading for all HTTP — critical architectural requirement. Using roUrlTransfer on render thread causes rendezvous crashes and app rejection.
- **ContentNode trees**: Data model for lists/grids — passed by reference (30-50x faster than associative arrays for large datasets). Required by built-in PosterGrid and RowList components.
- **roRegistrySection**: Persistent storage (16KB limit) — stores auth tokens and preferences across app launches. Must call Flush() after writes or data is lost.
- **Built-in Video node**: Playback component — supports Direct Play and HLS transcoding. Custom video implementations fail certification.

**Critical patterns:**
- All Plex API requests require 8+ X-Plex headers (Platform, Product, Version, Device-Name, Client-Identifier, Token, etc.)
- HTTPS requests must call SetCertificatesFile("common:/certs/ca-bundle.crt") + InitClientCertificates() or SSL fails with error -60
- Library fetches must paginate using X-Plex-Container-Start/Size=50 headers or large libraries crash
- Images must set loadWidth/loadHeight BEFORE uri or full-resolution images exhaust memory

### Expected Features

Users expect a Plex client to provide full library browsing (Movies/TV Shows in grid view), continue watching, playback with subtitle/audio track selection, and server authentication. The official Plex Roku app is widely criticized for slow navigation, horizontal tab layout, and UI bloat, creating opportunity for a lean, fast alternative focused on personal media libraries.

**Must have (table stakes):**
- Library browsing (Movies/TV Shows) — core function of media client
- Poster grid view (6 columns FHD) — standard visual browsing pattern
- Continue Watching / On Deck — users expect to resume where they left off
- Basic playback controls (play/pause/seek/stop) — fundamental
- Direct Play with transcode fallback — avoid unnecessary re-encoding
- Watch state syncing — mark watched/unwatched, track progress
- Subtitle and audio track selection — expected for multi-language support
- Server discovery and PIN authentication — required to connect to Plex
- Episode lists (Show → Season → Episode) — hierarchical TV navigation
- Item metadata display — title, summary, ratings, cast, runtime, genre
- Back button navigation — return to previous screen with focus preserved

**Should have (competitive):**
- Fast sidebar navigation — main differentiator vs official app's slow horizontal tabs
- Instant library switching — preload/cache metadata for responsive UX
- Collections support — users organize media into collections (Marvel movies, etc.)
- Search functionality — find specific content with debouncing
- Persistent focus position — remember grid location when returning from detail screen
- Clean, distraction-free UI — no ads, no free Plex content hub, movies/TV only
- Multiple sort/filter options — organize by title, date, year, rating, genre

**Defer (v2+):**
- Automatic intro/credits skip — high complexity, requires marker detection and auto-seek logic
- Chapter markers — depends on server providing chapter metadata reliably
- Playlist support — nice-to-have, not critical for launch
- 10-second skip buttons — UX improvement, not essential
- Grid customization (adjustable columns) — user preference feature

**Explicitly exclude (anti-features):**
- Plex's free streaming content — adds bloat, focus on personal media only
- News/Live TV/DVR — scope creep, not user's need
- Music/Photos libraries — separate use case, video content only
- Multi-user profiles — single account per requirements
- Social features (Watch Together) — complex, not requested
- Settings overload — opinionated defaults, minimal configuration

### Architecture Approach

Roku SceneGraph applications use a component-based architecture with strict thread separation. The UI runs on the render thread (must remain responsive, <16ms per frame at 60fps), while all HTTP requests and heavy processing run in background Task nodes. MainScene manages a screen stack (array of component nodes), pushing new screens on navigation and popping on back button. Screens communicate with Tasks via field observers—UI sets Task input fields and observes output fields, Tasks update fields when work completes. Data flows from Plex API → Task node (parses JSON/XML into ContentNode trees) → UI component (binds to grid/list). Global state (auth token, server URL) lives in m.global node, accessible from all components. Registry provides persistent storage with 16KB limit per channel.

**Major components:**
1. **MainScene** — Root scene, screen stack management, global state initialization, back button handling
2. **Task nodes (PlexAuthTask, PlexApiTask, PlexSearchTask, PlexSessionTask, ImageCacheTask)** — All HTTP operations, run in background threads, communicate via field observers
3. **Screen components (HomeScreen, DetailScreen, EpisodesScreen, SearchScreen, SettingsScreen)** — Full-screen views with focused state, key event handling, screen-specific layouts
4. **Widget components (Sidebar, PosterGrid, VideoPlayer, FilterBar)** — Reusable UI elements with interface fields for data binding
5. **Utility layer (source/utils.brs, source/constants.brs)** — Shared helpers (GetPlexHeaders, BuildPlexUrl, registry operations, color constants)
6. **Data model (ContentNode trees)** — Hierarchical content structures passed by reference, populated by Tasks and bound to grid/list components

**Critical architectural patterns:**
- Screen stack navigation (push/pop) with focus restoration
- Task-based HTTP with field observers (never roUrlTransfer on render thread)
- ContentNode trees for all list/grid data (not associative arrays)
- API abstraction layer in Task nodes (clean interfaces, single source of truth)
- Global state via m.global for auth token and server config
- One-way references (parent → child only, never circular to avoid memory leaks)

### Critical Pitfalls

The research identified 10 critical pitfalls that cause crashes, certification rejection, or severe performance degradation. These are well-documented mistakes that experts avoid from day one.

1. **HTTP requests on render thread** — Using roUrlTransfer outside Task nodes causes rendezvous crashes and app rejection. ALWAYS use Task nodes for all network operations.

2. **Missing HTTPS certificate configuration** — Forgetting SetCertificatesFile() + InitClientCertificates() causes SSL error -60 on all HTTPS requests. Must be called before every HTTPS request.

3. **Missing X-Plex headers** — Plex API requires 8+ headers on every request (Client-Identifier, Product, Version, Platform, Device-Name, Token, etc.). Missing headers cause 401 errors or empty responses.

4. **Memory leaks from node cycles** — Storing parent references in children or not calling unobserveField() creates reference cycles that prevent garbage collection. Memory grows until crash.

5. **Observer pattern anti-patterns** — Each observeField() adds a callback without removing old ones. Accumulated observers cause callbacks to fire multiple times and leak memory. Must unobserveField() before re-observing.

6. **Plex token invalidation** — Tokens expire when users change passwords or remove devices. Apps must validate tokens on launch and handle 401 responses by redirecting to authentication.

7. **Library pagination failure** — Large libraries (>1000 items) crash without pagination. Must use X-Plex-Container-Start/Size=50 headers on library requests.

8. **Poster image loading without scaling** — Loading full-resolution images (2000x3000px) when displaying 240x360 exhausts memory. Must set loadWidth/loadHeight BEFORE uri and use Plex transcode API.

9. **ContentNode creation in loops on render thread** — Creating ContentNodes in tight loops blocks UI (30-50x slower than associative arrays). Must build ContentNode trees in Task nodes.

10. **Registry write without Flush()** — Registry writes are buffered. Without Flush(), data never persists to storage. Auth tokens and settings lost on app restart.

## Implications for Roadmap

Based on research, PlexClassic requires strict phase ordering due to architectural dependencies. Task node patterns established in Phase 1 cascade through all subsequent phases. Getting the foundation right prevents costly refactoring. The project naturally groups into 4-5 phases based on build dependencies and feature complexity.

### Phase 1: Foundation & Authentication
**Rationale:** Task node patterns, API utilities, and registry management must be established first. Authentication is the entry point—users can't proceed without connecting to a Plex server. This phase establishes code quality patterns (Task-based HTTP, observer cleanup, certificate configuration) that all future phases inherit.

**Delivers:**
- Working PIN-based OAuth with plex.tv
- Server discovery and selection
- Token persistence with validation
- Core utilities (GetPlexHeaders, registry helpers, constants)
- PlexAuthTask and PlexApiTask foundation

**Addresses features:**
- Server discovery and authentication (table stakes)
- Token storage with validation (prevents pitfall #6)

**Avoids pitfalls:**
- #1: HTTP on render thread — establishes Task node pattern from start
- #2: Missing HTTPS certificates — creates utility that includes certificate config
- #3: Missing X-Plex headers — GetPlexHeaders() utility ensures all required headers
- #5: Observer anti-patterns — documents proper observeField/unobserveField pattern
- #10: Registry without Flush() — creates registry utility that always flushes

**Phase-specific risks:** Plex PIN auth flow is unique (POST PIN, poll until user enters code at plex.tv/link, retrieve token). Needs careful implementation of polling with timeout.

---

### Phase 2: Navigation & Screen Management
**Rationale:** MainScene screen stack is required by all subsequent screens. Sidebar widget is the UI differentiator (vs official app's horizontal tabs). Establishing navigation patterns now prevents refactoring when adding more screens later. Screen lifecycle management (focus restoration, memory cleanup) must be robust before building multiple screens.

**Delivers:**
- MainScene with screen stack (push/pop)
- Back button navigation with focus restoration
- Sidebar component for library switching
- HomeScreen placeholder (uses Sidebar)
- Screen cleanup pattern (prevents memory leaks)

**Addresses features:**
- Back button navigation (table stakes)
- Fast sidebar navigation (differentiator)
- Persistent focus position (competitive advantage)

**Avoids pitfalls:**
- #4: Memory leaks from node cycles — implements proper screen removal with unobserve/removeChild/invalid
- #5: Observer anti-patterns — establishes cleanup pattern in screen lifecycle

**Uses stack:**
- SceneGraph component architecture (MainScene, screens, widgets)
- Field observer pattern for screen communication

**Phase-specific risks:** Screen stack management is custom (Roku has no built-in back stack). Requires testing navigation flows (push multiple screens, pop, verify focus restoration).

---

### Phase 3: Library Browsing & Content Display
**Rationale:** This is the core user experience—browsing movies/TV shows in grid view. Depends on authentication (Phase 1) and navigation (Phase 2). Poster grid is used by multiple screens (HomeScreen, DetailScreen, EpisodesScreen), so building the reusable PosterGrid widget first reduces duplication. Pagination and image scaling must be correct from start—retrofitting is painful.

**Delivers:**
- PosterGrid widget (reusable, paginated)
- HomeScreen with library browsing
- DetailScreen showing item metadata
- EpisodesScreen (Show → Season → Episode hierarchy)
- Continue Watching / On Deck section
- Recently Added section
- Watch state syncing (mark watched/unwatched)
- ImageCacheTask for poster prefetching

**Addresses features:**
- Library browsing (table stakes)
- Poster grid view (table stakes)
- Continue Watching / On Deck (table stakes)
- Item metadata display (table stakes)
- Episode lists (table stakes)
- Watch state syncing (table stakes)
- Recently Added (table stakes)

**Avoids pitfalls:**
- #7: Library pagination failure — implements X-Plex-Container-Start/Size from start
- #8: Poster image loading without scaling — uses loadWidth/loadHeight and Plex transcode API
- #9: ContentNode creation in loops — builds ContentNode trees in PlexApiTask, not render thread

**Uses stack:**
- Built-in PosterGrid/MarkupGrid components
- ContentNode trees for data (passed by reference)
- PlexApiTask for all library requests
- ImageCacheTask for poster prefetching

**Implements architecture:**
- Task → ContentNode → UI binding pattern
- API abstraction layer (PlexApiTask with clean interface fields)
- Widget reusability (PosterGrid used by multiple screens)

**Phase-specific risks:** Pagination UX requires "load more" detection when user scrolls near grid end. Image caching needs eviction strategy for memory management. TV show hierarchy (Show → Season → Episode) requires careful ContentNode tree structure.

---

### Phase 4: Playback & Progress Tracking
**Rationale:** Playback is the ultimate goal (everything leads to watching content). Depends on all previous phases—can't play without auth, navigation, and content selection. Video playback uses built-in Roku Video node (no custom implementation), but requires proper content node setup, Direct Play detection, and progress reporting. Resume functionality depends on watch state from Phase 3.

**Delivers:**
- VideoPlayer component wrapping built-in Video node
- Direct Play with transcode fallback
- Playback controls (play/pause/seek/stop)
- Subtitle track selection UI
- Audio track selection UI
- Resume playback for in-progress content
- PlexSessionTask for progress reporting (PUT /:/timeline)
- Basic seek controls (rewind/forward)

**Addresses features:**
- Basic playback controls (table stakes)
- Direct Play (table stakes)
- Subtitle/audio track selection (table stakes)
- Resume playback (table stakes)

**Uses stack:**
- Built-in Video node (only certification-compliant option)
- PlexSessionTask for progress reporting
- ContentNode for video content metadata

**Implements architecture:**
- VideoPlayer screen in screen stack
- Task-based progress reporting (every 10s, on pause, on stop)

**Phase-specific risks:** Direct Play vs transcode decision requires checking codec/resolution/audio format against Roku capabilities. Transcode URLs can expire mid-playback (need 404 handling). Progress reporting must be debounced (not every position change, every 10s). Subtitle/audio track selection UI on TV remote is challenging.

---

### Phase 5: Search & Advanced Features
**Rationale:** Search is high-value but complex (requires PlexSearchTask with debouncing, keyboard input handling, results display). Deferring until core browsing works prevents scope creep. Collections, sort/filter, and list view enhance usability but aren't blockers for v1.0 launch. These features depend on stable API patterns from earlier phases.

**Delivers:**
- PlexSearchTask with debouncing
- SearchScreen with keyboard input
- Search results grid
- Collections support (browse Plex collections)
- Sort options (title, date, year, rating)
- Filter options (genre, year, unwatched)
- List view option (alternative to grid)
- SettingsScreen (server switching, sign out, preferences)

**Addresses features:**
- Search functionality (should have)
- Collections support (should have)
- Sort/filter options (should have)
- List view option (should have)
- Settings screen (basic configuration)

**Uses stack:**
- PlexSearchTask with debouncing logic
- Roku on-screen keyboard for text entry
- Same PosterGrid/ContentNode patterns as Phase 3

**Phase-specific risks:** Search debouncing requires careful timing (wait for typing to stop, typically 300ms). Keyboard input on TV remote is painful UX (consider voice input via Roku remote API). Sort/filter UI needs intuitive remote navigation. Collections API endpoint may differ from library endpoints.

---

### Phase Ordering Rationale

**Dependency-driven:**
- Phase 1 (Authentication) is required by all other phases—no API calls without auth token
- Phase 2 (Navigation) establishes MainScene screen stack used by all screens
- Phase 3 (Library Browsing) depends on auth + navigation, provides content for playback
- Phase 4 (Playback) is the goal but depends on content selection from Phase 3
- Phase 5 (Search/Advanced) enhances Phase 3 patterns, can be deferred to v1.1+

**Risk mitigation:**
- Establishing Task node patterns in Phase 1 prevents render thread crashes throughout project
- Building screen cleanup in Phase 2 prevents memory leaks from accumulating as more screens are added
- Implementing pagination in Phase 3 avoids costly refactoring when testing with large libraries
- Using built-in Video node in Phase 4 ensures certification compliance

**Architecture alignment:**
- Phases follow natural component dependencies (foundation → structure → data → presentation → polish)
- Each phase delivers working functionality (not partial implementations)
- Later phases reuse patterns from earlier phases (Task nodes, ContentNode trees, screen stack)

**User value prioritization:**
- Phases 1-4 deliver minimum viable product (auth → browse → watch)
- Phase 5 is post-launch enhancement based on user feedback
- Deferring advanced features prevents scope creep while core functionality is unstable

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 4 (Playback):** Direct Play codec detection logic needs device capability matrix research. Plex transcode URL structure and parameters need API documentation review. Subtitle format support (SRT, VTT, etc.) needs testing across Roku models.
- **Phase 5 (Search):** Plex search API endpoint query parameters and response format needs documentation. Debouncing implementation patterns for Roku remote keyboard input need research.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Authentication):** Plex PIN auth flow is well-documented in research. Task node patterns are established Roku standards.
- **Phase 2 (Navigation):** Screen stack management pattern is thoroughly documented in ARCHITECTURE.md. No unusual requirements.
- **Phase 3 (Library Browsing):** PosterGrid + ContentNode patterns are standard Roku development. Pagination is documented Plex API feature.

**General guidance:**
- Any phase involving new Plex API endpoints should validate request/response format with actual PMS
- Performance testing (image loading, grid scrolling) should use low-end Roku devices (Roku Express)
- Memory profiling should use Roku Resource Monitor throughout all phases

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official Roku docs + RokuCommunity tools verified. BrighterScript is established standard with 189 GitHub stars. RSG 1.3 requirement confirmed for Oct 2026. |
| Features | HIGH | Official Plex support docs + extensive user feedback from forums. MVP feature set derived from "table stakes" analysis. Anti-features clear from user complaints about official app. |
| Architecture | HIGH | Official Roku SceneGraph docs + certification-compliant samples. Task node pattern is non-negotiable. ContentNode performance verified in community benchmarks. |
| Pitfalls | HIGH | All 10 critical pitfalls verified with official docs and/or community consensus. Render thread crashes, SSL errors, and memory leaks are well-documented failure modes. |

**Overall confidence:** HIGH

Research is comprehensive with strong verification from official sources. The technology stack has no alternatives (Roku = BrightScript/SceneGraph). Architectural patterns are established best practices with certification requirements. Feature expectations come from official Plex docs and user feedback. Pitfalls are well-known mistakes documented across official resources and community experience.

### Gaps to Address

**Token refresh mechanism:** Plex PIN auth provides no refresh token. When tokens expire (password change, device removal), app must redirect to full re-authentication. Research didn't find silent refresh strategy. During implementation: validate token on every app launch (GET /user), redirect to auth on 401, provide clear "Sign Out" option.

**Device capability matrix:** Research identified that Direct Play requires codec/resolution checking against Roku capabilities, but didn't provide complete matrix. During Phase 4: test common codecs (H.264, HEVC) and containers (MP4, MKV) on target devices, implement fallback to transcode when Direct Play fails, log failures for pattern analysis.

**Search API response structure:** PITFALLS.md mentioned search debouncing but research didn't detail Plex search endpoint response format. During Phase 5: validate /hubs/search endpoint with test queries, confirm response matches library endpoint format (can reuse ContentNode builder), test with special characters and empty queries.

**Collections API endpoint:** FEATURES.md listed Collections as "should have" but research didn't verify endpoint. During Phase 3 or 5: check if collections use same /library/sections structure or require separate endpoint, verify if ContentNode trees work identically or need custom fields.

**Roku OS 15.0 adoption rate:** STACK.md recommends OS 15.0+ for performance features (move APIs, Perfetto tracing), but research didn't confirm install base. During Phase 1: check Roku developer dashboard for OS version distribution, consider minimum OS version for certification (likely OS 11.0), use OS 15.0 features conditionally with fallbacks.

**Image caching eviction strategy:** ARCHITECTURE.md mentions ImageCacheTask but research didn't define memory limits or eviction policy. During Phase 3: profile memory usage with 100+ cached images, implement LRU eviction when hitting 20-30MB cache size, test on low-end Roku Express (1GB RAM).

## Sources

### Primary (HIGH confidence)
- [Roku OS 15.0 Beta Announcement](https://blog.roku.com/developer/roku-os-15-0-beta) — Roku OS features, RSG 1.3 requirement
- [Roku Developer Portal](https://developer.roku.com) — Official SceneGraph, Task node, memory management docs
- [BrighterScript GitHub](https://github.com/rokucommunity/brighterscript) — Language features, version compatibility
- [vscode-brightscript-language](https://github.com/rokucommunity/vscode-brightscript-language) — RokuCommunity toolchain
- [Plex Support: Navigating Big Screen Apps](https://support.plex.tv/articles/navigating-the-big-screen-apps/) — Feature expectations
- [Plex Support: Mark as Watched](https://support.plex.tv/articles/201018487-mark-as-watched-or-unwatched/) — Watch state API
- [Plex Support: Streaming Overview](https://support.plex.tv/articles/200430303-streaming-overview/) — Direct Play vs transcode
- [Plex API Authentication Forum](https://forums.plex.tv/t/authenticating-with-plex/609370) — PIN auth flow
- [Roku SceneGraph Master Sample](https://github.com/rokudev/scenegraph-master-sample) — Certification-compliant architecture

### Secondary (MEDIUM confidence)
- Medium articles by Krishna Kumar Chaturvedi and Amit Dogra — BrightScript fundamentals, Task threading, screen stacks
- [New Plex UI backlash forums](https://forums.plex.tv/t/new-ui-is-an-awful-experience/931048) — User pain points, feature requests
- [Roku Poster Component Property Order](https://briandunnington.github.io/poster_property_order) — Image loading pitfalls
- [ContentNode Performance Discussion](https://community.roku.com/t5/Roku-Developer-Program/Performance-of-creating-ContentNode-v-roArray-roAA/td-p/470963) — AA vs ContentNode benchmarks
- Community threads on SSL errors, registry flush, observer cleanup — Well-documented pitfalls

### Tertiary (LOW confidence)
- None — all findings verified with official sources or community consensus

---
*Research completed: 2026-02-09*
*Ready for roadmap: yes*
