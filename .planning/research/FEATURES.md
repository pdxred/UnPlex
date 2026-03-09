# Feature Landscape

**Domain:** Roku Plex Media Server Client (replacing official Plex Roku app)
**Researched:** 2026-03-08

## Context

SimPlex replaces the official Plex Roku app, which was recently redesigned and is widely criticized for removing sidebar navigation, slow performance, and missing features. The opportunity is clear: users actively want a fast, sidebar-driven Plex client. The existing SimPlex scaffold already covers auth, server connection, library browsing, detail/episode screens, search, and video playback.

This document categorizes features by what matters for daily use of a personal Plex server with movies and TV shows as the primary content.

---

## Table Stakes

Features users expect from any Plex client. Missing any of these makes the app feel incomplete for daily use.

| Feature | Why Expected | Complexity | Plex API Endpoints | Notes |
|---------|--------------|------------|-------------------|-------|
| **Resume playback from last position** | Users pause and return constantly; without this, the app is unusable | Low | `viewOffset` field on metadata items; pass `offset` param to playback URL | Already have progress reporting via `/:/timeline`; need to read `viewOffset` from item metadata and pass to Video node |
| **Mark watched / unwatched** | Core library management action | Low | `GET /:/scrobble?key={ratingKey}` (watched), `GET /:/unscrobble?key={ratingKey}` (unwatched) | Toggle from detail screen; update UI state immediately |
| **Watch progress indicators** | Users need to see what they've started and finished at a glance | Low | `viewOffset` and `viewCount` fields on item metadata; `leafCount`/`viewedLeafCount` on shows | Overlay progress bar on poster items; watched badge |
| **Hub rows (Continue Watching, Recently Added)** | Primary home screen discovery; users expect to land on "what's next" | Med | `GET /hubs` (global), `GET /hubs/sections/{id}` (per-library); params: `count`, `onlyTransient` | Continue Watching is the single most-used hub. Recently Added close second. |
| **On Deck** | "What episode comes next" for TV watchers | Low | `GET /library/onDeck` | Can be a hub row or standalone section |
| **Filter and sort library** | Large libraries (10K+ items) are unusable without filtering | Med | `GET /library/sections/{id}/all?sort=titleSort:asc&unwatched=1&genre=Action` ; filter options from `GET /library/sections/{id}?includeDetails=1` | Sort: title, date added, year, rating. Filter: unwatched, genre, year, decade, content rating |
| **Audio track selection** | Many users have multi-language media | Med | Audio streams listed in `/library/metadata/{id}` media parts; set via playback URL params `audioStreamID={id}` or `PUT /library/parts/{partId}?audioStreamID={id}` | Show in playback overlay or pre-play options |
| **Subtitle selection** | Essential for foreign content and accessibility | Med | Subtitle streams in media metadata; set via `subtitleStreamID={id}` param; `subtitleMode` preference | Support embedded subtitles (SRT, ASS via burn-in); surface subtitle tracks in playback overlay |
| **Auto-play next episode** | TV binge watching is the primary use case | Med | Next episode from `/library/metadata/{id}` or increment ratingKey; need countdown UI | 10-second countdown overlay at end of episode with cancel option |
| **Error states and empty states** | Without these, users hit dead ends and think the app is broken | Med | N/A (UI concern) | Loading spinners, "No items found", network error retry, server unreachable messaging |
| **Collections browsing** | Many users organize libraries with collections | Med | `GET /library/sections/{id}/collections`, collection items via `GET /library/collections/{id}/children` | Display as a browsable section in sidebar or as a filter mode |

**Confidence:** HIGH -- these features are universally present in all serious Plex clients (official app, PlexKodiConnect, Jellyfin clients). Endpoints verified against Plexopedia and plexapi.dev documentation.

---

## Differentiators

Features that set SimPlex apart from the official Plex Roku app. Not expected, but highly valued -- especially given user complaints about the official app's redesign.

| Feature | Value Proposition | Complexity | Plex API Endpoints | Notes |
|---------|-------------------|------------|-------------------|-------|
| **Sidebar navigation** | The #1 complaint about the new Plex Roku app is removing the sidebar. SimPlex's entire identity is this. | Already built | N/A | This is the core competitive advantage. Never remove it. |
| **Fast grid browsing** | Official app is slow; SimPlex should feel instant | Already built (optimize) | Pagination via `X-Plex-Container-Start`/`X-Plex-Container-Size` | Focus on perceived performance: prefetch next page, image cache warming |
| **Intro skip button** | Beloved feature; official app has it but SimPlex showing it proves feature parity | Med | `GET /library/metadata/{id}?includeMarkers=1` -- look for `type="intro"` markers with `startTimeOffset`/`endTimeOffset` | Show "Skip Intro" button overlay during intro marker timespan |
| **Credits skip / auto-next** | Trigger next episode at credits rather than waiting for end | Med | `type="credits"` markers from same endpoint as intros | At credits marker start, show "Next Episode" / "Watch Credits" overlay |
| **Playlists** | Many users curate playlists; official Roku app support is inconsistent | Med | `GET /playlists` (all), `GET /playlists/{id}/items` (contents), `POST /playQueues?type=video&uri=...` | Browse and play; creating/editing playlists is lower priority |
| **Grid/list view toggle** | Some users prefer list view for TV shows, grid for movies | Low | N/A (UI concern) | Simple toggle on HomeScreen; persist preference per library type |
| **Managed user switching** | Households with multiple profiles | Med | `GET https://plex.tv/api/v2/home/users` (list users), `POST https://plex.tv/api/v2/home/users/{id}/switch?pin={pin}` | User picker at startup or from settings; PIN dialog if user has PIN |
| **Pre-roll / cinema trailers** | Enhances the "cinema experience" feel some users love | Low | Pre-rolls configured server-side; client creates PlayQueue with `extras` param to include them | Detect via server settings; PlayQueue handles the sequencing |
| **Keyboard / search speed** | Official app search is reported as broken/slow | Already built (polish) | `/hubs/search?query={term}&limit=10` | Already have debounced search; ensure results render fast |
| **Music playback** | Official Roku app removed music; no Plexamp on TV platforms. This is a gap. | High | `GET /library/sections/{id}/all` (artists), `/library/metadata/{id}/children` (albums then tracks); music library type=8 | Artist > Album > Track browsing; now-playing bar; background playback is the hard part on Roku |
| **Photo browsing** | Niche but valued by photo-heavy users | Med | Photo library type=13; `GET /library/sections/{id}/all` (albums), `/library/metadata/{id}/children` (photos) | Grid view, full-screen viewer, slideshow with timer |

**Confidence:** HIGH for sidebar/speed (verified via user complaints on Plex forums). MEDIUM for music (Roku background audio has platform limitations). HIGH for API endpoints (verified against Python PlexAPI docs and Plexopedia).

---

## Anti-Features

Features to explicitly NOT build. Each wastes development time or degrades the user experience.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Plex Discover / streaming service integration** | SimPlex is for personal media only; Discover adds complexity for content the user doesn't own | Show only local library content; no streaming service links |
| **Ad-supported content (Plex Free Movies & TV)** | Irrelevant to a personal server client; adds clutter | Omit entirely; don't hit the `/hubs/promoted` endpoint |
| **Social features (friends activity, Watch Together)** | Complexity with no value for a personal/household app | Omit entirely |
| **Cloud relay playback** | PROJECT.md explicitly scopes to direct server connection; relay adds latency and complexity | Connect local > remote only; skip relay connections |
| **Multi-server browsing** | Scoped to single personal server | Support server switching in settings, but only one active server |
| **Parental controls / content restrictions** | Deferred to v2 per PROJECT.md; Plex server handles this at the user level anyway | Rely on managed user permissions set on the server |
| **Channel store certification** | Sideload only; certification adds UI/UX constraints that conflict with the classic feel | Distribute as .zip for sideloading |
| **Fancy animations / transitions** | The official app's "gorgeous animations" are exactly what makes it feel slow on Roku | Instant screen transitions; focus goes where expected; no slide-in panels |
| **Horizontal tab navigation** | The official app's switch to top tabs is the #1 user complaint | Keep the sidebar; this is the product identity |
| **Offline downloads** | Roku has no filesystem for media storage; this is a mobile-only feature | Omit entirely |
| **DVR management / recording scheduling** | High complexity, niche use case, requires tuner hardware | If Live TV is added, browse recordings only; no schedule management |

---

## Feature Dependencies

```
Resume Playback --> Watch Progress Indicators (both read viewOffset)
Hub Rows --> On Deck (On Deck is a hub type)
Filter/Sort --> Library Browsing (already built; filters layer on top)
Intro Skip --> Credits Skip (same marker API, same overlay pattern)
Credits Skip --> Auto-play Next Episode (credits trigger the "next" prompt)
Auto-play Next --> Playlists (playlist playback uses same sequential logic)
Audio Track Selection --> Subtitle Selection (same UI pattern, same media metadata)
Managed Users --> PIN Entry (users may have PINs)
Pre-rolls --> PlayQueue API (pre-rolls use PlayQueue extras)
Music Playback --> Playlists (music playlists reuse playlist infrastructure)
Collections --> Filter/Sort (collections can be a filter type within a library)
```

### Dependency Ordering (build bottom-up):

1. **Resume + Watch Progress** (foundation for all playback features)
2. **Hub Rows + On Deck** (home screen becomes useful for daily workflow)
3. **Filter/Sort** (large library usability)
4. **Audio/Subtitle Selection** (playback completeness)
5. **Intro/Credits Skip** (playback polish)
6. **Auto-play Next Episode** (TV workflow)
7. **Collections + Playlists** (content organization)
8. **Managed Users** (household support)
9. **Music + Photos** (additional media types)
10. **Pre-rolls** (nice-to-have polish)

---

## MVP Recommendation

The existing scaffold handles auth, browsing, playback. The next priority tier should focus on making the app usable as a **daily driver** -- replacing the official app entirely.

### Priority 1: Daily Driver (must complete before anyone would switch from official app)

1. **Resume playback from last position** -- without this, users restart every movie/episode
2. **Watch progress indicators** -- users can't tell what they've seen
3. **Mark watched/unwatched** -- basic library hygiene
4. **Hub rows (Continue Watching + Recently Added)** -- home screen must surface "what's next"
5. **On Deck** -- TV watchers need next-episode awareness
6. **Error states** -- without these, any API hiccup feels like a crash

### Priority 2: Feature Parity (makes the app competitive with official app)

7. **Filter and sort** -- essential for large libraries
8. **Audio track selection** -- multi-language households
9. **Subtitle selection** -- accessibility and foreign content
10. **Auto-play next episode** -- binge watching
11. **Intro/credits skip** -- expected polish

### Priority 3: Differentiation (makes the app better than official app)

12. **Collections** -- organization users set up on their server
13. **Playlists** -- curated playback
14. **Managed users** -- household with kids/partners
15. **Music playback** -- fills the gap left by official app removing music

### Defer: Explicitly push to later

- **Photos/Slideshow** -- niche; most users access photos on mobile
- **Live TV / DVR** -- requires tuner hardware; tiny user base
- **Pre-rolls** -- fun but zero impact on daily usability
- **Grid/list toggle** -- nice polish but not blocking adoption

---

## Sources

- [Plex Roku app backlash and missing features](https://piunikaweb.com/2025/09/17/plex-roku-update-backlash/) -- MEDIUM confidence (news reporting)
- [Plex sidebar removal complaint thread](https://forums.plex.tv/t/roku-plex-ui-regression-sidebar-removed-top-tabs-now-request-classic-sidebar-toggle/935370) -- HIGH confidence (direct user feedback)
- [Plex API: Mark Watched endpoint](https://www.plexopedia.com/plex-media-server/api/library/media-mark-watched/) -- HIGH confidence (API reference)
- [Plex API: Get Global Hubs](https://plexapi.dev/api-reference/hubs/get-global-hubs) -- HIGH confidence (API reference)
- [Plex API: Get On Deck](https://plexapi.dev/api-reference/library/get-on-deck) -- HIGH confidence (API reference)
- [Plex API: Collections](https://python-plexapi.readthedocs.io/en/latest/modules/collection.html) -- HIGH confidence (Python PlexAPI docs)
- [Plex API: Music tracks](https://www.plexopedia.com/plex-media-server/api/library/music-albums-tracks/) -- HIGH confidence (API reference)
- [Plex Skip Intro/Credits markers](https://support.plex.tv/articles/skip-content/) -- HIGH confidence (official Plex support)
- [Plex Managed Users and Fast User Switching](https://support.plex.tv/articles/204232453-fast-user-switching/) -- HIGH confidence (official Plex support)
- [Plex Extras / Pre-rolls](https://support.plex.tv/articles/202920803-extras/) -- HIGH confidence (official Plex support)
- [Plex Playlists API](https://plexapi.dev/api-reference/playlists/get-all-playlists) -- HIGH confidence (API reference)
- [RARflix community Roku client](https://github.com/ljunkie/rarflix) -- MEDIUM confidence (historical reference)
- [Plex official Roku app "ruined" thread](https://forums.plex.tv/t/plex-just-ruined-their-roku-app/931058) -- HIGH confidence (direct user feedback)
