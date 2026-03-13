# Feature Research

**Domain:** Roku Plex Media Server Client — v1.1 Polish & Navigation Milestone
**Researched:** 2026-03-13
**Confidence:** HIGH (code read directly; UX patterns from TV media client ecosystem; Roku specs from official and community sources)

---

## Context

This document replaces the v1.0 FEATURES.md. The v1.0 research catalogued what to build across the full app. This document focuses exclusively on what the v1.1 milestone needs to accomplish: TV show navigation overhaul, bug fixes, branding refresh, codebase cleanup, and GitHub documentation.

Everything listed under "Already Built" in PROJECT.md is treated as existing infrastructure, not a deliverable. Features below are only the delta for v1.1.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these makes v1.1 feel like it didn't address the right things.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Show → Season list → Episode grid navigation** | Every TV media client (Netflix, Plex, Emby, Infuse) uses this three-level hierarchy. A flat episode list is disorienting for shows with 5+ seasons. | MEDIUM | Already have the two-panel layout (season LabelList + episode MarkupList). The overhaul is about adding a proper season-as-poster grid before the episode list, with the show still acting as the entry point. Season selection should jump to that season's episode list. |
| **Episode thumbnail, number, and duration in list** | Users scan episode lists by thumbnail and episode number. Without these, the list is unusable for long-running shows. | LOW | EpisodeItem.xml already has thumbnail, title, summary, duration, and progress bar. The format string "E3 - Title" is already applied. The gap is showing watched badges reliably and ensuring the thumbnail loads. |
| **Watched state accurate after playback** | After marking an episode watched or finishing it, the episode list must update immediately without requiring a manual reload. | MEDIUM | Two known gaps: (1) auto-play wiring: `grandparentRatingKey` never set so countdown never fires; (2) `watchStateChanged` from DetailScreen never observed by HomeScreen grid. Both are documented bugs, not new features. |
| **Auto-play next episode working end-to-end** | Users binge TV shows. Auto-play is expected to work if it appears in the UI at all. The countdown overlay exists in VideoPlayer but is unreachable because callers never set `grandparentRatingKey`. | MEDIUM | Fix: both `EpisodeScreen.startPlayback()` and `DetailScreen.startPlayback()` must set `parentRatingKey`, `grandparentRatingKey`, `episodeIndex`, and `seasonIndex` on the VideoPlayer node before calling `control = "play"`. Already documented in CONCERNS.md. |
| **Search results grouped or typed** | Searching a library with movies, shows, and episodes mixed into one undifferentiated poster grid is confusing. Users expect to see at minimum a "Movies" section and a "TV Shows" section. | MEDIUM | Current SearchScreen flattens all hub results into one PosterGrid with no section headers. The Plex search API returns hub-structured results (`MediaContainer.Hub[]`) with `type` on each hub. Group results by hub type or show a type badge (movie/show/episode) on each poster. |
| **App icons at correct Roku dimensions** | Roku expects specific dimensions for `mm_icon_focus_fhd` (540x405px), `mm_icon_focus_hd` (290x218px), `mm_icon_side_fhd` (540x405px), and `mm_icon_side_hd` (290x218px). Wrong sizes appear blurry or cropped. | LOW | Current manifest references HD icons that may not exist at correct dimensions. Splash at 1920x1080 JPG is correct. Focus icons are the "large" channel art; side icons are the smaller thumbnail seen in the channel store list. Both need gradient background and legible "SimPlex" text. |
| **Splash screen branding** | Splash must convey product identity in the 1.5 seconds it's visible. Current `splash_fhd.jpg` exists but branding quality is unknown. | LOW | Target: dark gradient background (matching BG_PRIMARY `0x1A1A2EFF`), large bold "SimPlex" wordmark with gray stroke, subtle Plex-gold accent. No animation — static JPG. |
| **Codebase free of orphaned files** | Orphaned code creates confusion for contributors and breaks the promise of a published open-source channel. `normalizers.brs` and `capabilities.brs` contain 9 functions that are never called. | LOW | Delete both files. They are unimported and untested. If capabilities detection is needed later, rebuild from scratch using the Plex API response at connect time. |

### Differentiators (Competitive Advantage)

Features that make v1.1 better than leaving v1.0 as-is.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Season poster grid before episode list** | Most clients show seasons as a horizontal scroll or a simple text list. A poster grid with season artwork (using season thumb) gives shows a richer, more premium feel. | MEDIUM | Requires a new SeasonScreen or promoting the season selection to its own screen. The current single-screen two-panel layout (LabelList + MarkupList) can stay as a fallback for shows with many seasons. Season thumbnails come from `season.thumb` in `/library/metadata/{showRatingKey}/children`. |
| **Continue Watching routes directly to playback** | The current HomeScreen routes Continue Watching items to DetailScreen, adding a friction click. Any show or movie with `viewOffset > 0` should launch playback directly with a resume prompt. | MEDIUM | Already documented as a UX gap in CONCERNS.md. Requires distinguishing "resume" hub items from "new" hub items by checking `viewOffset > 0` in `HomeScreen.startPlaybackFromHub()`. |
| **Collections accessible without library selection** | Collections are a dead-end in the current sidebar — clicking Collections requires a library to be selected first but provides no feedback. Adding a top-level collections view that calls `/library/collections` fixes a visible broken feature. | MEDIUM | Documented in CONCERNS.md as UX gap. The fix is adding an "All Collections" path in the sidebar that doesn't require a library context. |
| **Bolder icon/splash branding** | PROJECT.md explicitly names this as a v1.1 target: "bolder font with gray stroke, gradient backgrounds on icon/splash." A professionally branded icon distinguishes the channel in the Roku home screen among other sideloaded apps. | LOW | Icon design work, not code work. Deliverable is replacement PNG files at correct Roku dimensions (540x405 FHD focus, 290x218 HD focus, matching side icon variants) and updated splash JPG. |
| **GitHub-publishable documentation** | Publishing to GitHub creates a community around the project and lets others contribute. Without a README, setup guide, and architecture doc, nobody can run the project from source. | LOW | Required files: `README.md` (what it is, screenshots, install via sideload), `CONTRIBUTING.md` (dev environment, BrighterScript setup, F5 deploy), and in-code architecture doc or link to `.planning/codebase/ARCHITECTURE.md`. |
| **Search results with type context** | Showing a "TV Show" or "Movie" label below each poster in search results lets users orient immediately, especially when a search term returns both (e.g., "The Office" returns the show AND episodes). | LOW | Can be a small text label under the poster title in PosterGridItem, drawn from the `type` field on each result node. Low complexity given the data is already available. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Animated season transitions** | Feels polished on mobile/web | Roku's animation system is brittle; SOURCE of the BusySpinner SIGSEGV crash. Adding SceneGraph animations risks new firmware crashes. | Static screen transitions. Focus goes where expected instantly. No slide-ins or crossfades. |
| **Custom episode sorting / filtering** | Power users want to reorder or filter episode lists | Episode ordering is always by episode number — Plex API returns them sorted; adding custom sort adds UI complexity with near-zero benefit | Rely on Plex server ordering; let users configure sort on the server side |
| **Server switching UI overhaul** | Multiple servers means all content accessible | PROJECT.md: single personal server only. Multi-server is explicitly out of scope. | Fix or cleanly remove the server-switching dead code rather than building it out |
| **Loading animations / spinners** | Users want visual feedback during loads | BusySpinner causes SIGSEGV firmware crash (confirmed in bisection). Static loading text is safe. | Show "Loading..." label text or a simple static graphic during API calls. No BusySpinner. |
| **Season-level mark all watched** | Bulk watched marking is convenient | Requires a `/library/metadata/{seasonKey}/children` fetch + N scrobble calls; adds UI complexity for a rare action | Mark individual episodes from the options menu. Bulk actions are a v2 feature if ever. |

---

## Feature Dependencies

```
Auto-play next episode fix
    └──requires──> grandparentRatingKey set in EpisodeScreen.startPlayback()
    └──requires──> grandparentRatingKey set in DetailScreen.startPlayback()
    └──enables──>  Watch state propagation refresh after auto-play

Watch state propagation fix
    └──requires──> HomeScreen observes watchStateChanged from child screens
    └──enhances──> Episode list accuracy after marking watched on DetailScreen

Search results with type grouping
    └──requires──> SearchScreen processes Hub[] array (already available)
    └──enhances──> User orientation in mixed-type results

Season poster grid
    └──requires──> Season thumb URLs from /library/metadata/{id}/children
    └──may split into──> SeasonScreen (new) + EpisodeScreen (existing)

Continue Watching direct playback
    └──requires──> HomeScreen hub item routing logic update
    └──requires──> Resume dialog (already exists in EpisodeScreen — reuse pattern)

Collections top-level
    └──requires──> /library/collections endpoint (new API call)
    └──requires──> Sidebar adds Collections entry without library context

Icon/splash refresh
    └──independent──> All other features (purely asset replacement)

GitHub documentation
    └──independent──> All other features (written last, after code is final)

Codebase cleanup (orphaned files)
    └──independent──> But should be first — reduces confusion during other work
```

### Dependency Notes

- **Auto-play fix requires** both callers (EpisodeScreen AND DetailScreen) to be updated — fixing only one leaves the other path still broken.
- **Watch state propagation** is separate from auto-play fix but both affect episode list freshness. Do them in the same phase to avoid double-patching.
- **Season poster grid** may require a new SeasonScreen component. If so, EpisodeScreen continues to exist as the episode-level screen; SeasonScreen becomes the intermediate step between DetailScreen and EpisodeScreen.
- **Cleanup should be first** — removing orphaned files before making changes avoids confusion about whether normalizers.brs is a dependency.

---

## MVP Definition

### The v1.1 milestone ships when:

- [ ] **Auto-play end-to-end works** — countdown fires, advances to next episode, cancels correctly — this is the highest-value fix because it closes the only "unsatisfied" requirements from v1.0
- [ ] **Watch state propagates** from DetailScreen back to grid/hub rows after marking watched/unwatched
- [ ] **TV show navigation** feels complete — Show detail → Seasons → Episode list without dead ends
- [ ] **Search results** are legible with type context (at minimum a label, ideally grouped by hub)
- [ ] **Icons and splash** replaced with properly-sized, visually distinct assets
- [ ] **Orphaned files deleted** and codebase compiles cleanly
- [ ] **README published** — someone new can sideload the channel in under 10 minutes following the instructions

### Add After Validation (v1.x)

- [ ] Continue Watching direct playback — valuable but lower urgency than the bug fixes
- [ ] Collections top-level access — currently a dead-end but not a crash
- [ ] Season poster grid — current two-panel layout works; grid is an upgrade

### Future Consideration (v2+)

- [ ] Music library browsing and playback
- [ ] Photo grid and slideshow
- [ ] Live TV / EPG
- [ ] Grid/list view toggle per library type

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Auto-play next episode (wire fix) | HIGH | LOW (known exact fix) | P1 |
| Watch state propagation | HIGH | LOW (known exact fix) | P1 |
| Orphaned file cleanup | MEDIUM | LOW | P1 |
| TV show navigation overhaul | HIGH | MEDIUM | P1 |
| Search results with type context | MEDIUM | LOW | P1 |
| Icon/splash branding refresh | MEDIUM | LOW (asset work) | P1 |
| GitHub README + docs | HIGH (for publishability) | LOW | P1 |
| Continue Watching direct playback | HIGH | MEDIUM | P2 |
| Collections top-level access | MEDIUM | MEDIUM | P2 |
| Season poster grid | MEDIUM | MEDIUM | P2 |
| Server switching cleanup | LOW | LOW (remove it) | P2 |
| LoadingSpinner replacement | MEDIUM | MEDIUM (crash risk if done wrong) | P2 |

**Priority key:**
- P1: Must have for v1.1 milestone completion
- P2: Should have if time allows, can slip to v1.2
- P3: Future milestone

---

## Competitor Feature Analysis

How other TV media clients handle the specific areas this milestone addresses:

| Feature | Official Plex Roku App | Infuse (Apple TV) | Jellyfin Roku | SimPlex v1.0 | SimPlex v1.1 Target |
|---------|----------------------|-------------------|---------------|--------------|---------------------|
| Season navigation | Seasons as horizontal tab row across top of screen | Season picker dropdown overlaid on episode list | Season list + episode grid (two panels) | Two-panel: LabelList (seasons) + MarkupList (episodes) | Same two-panel but ensure layout handles 10+ seasons; consider season poster grid |
| Episode display | Episode grid with thumbnails + title + runtime | Compact list with thumbnail, S01E01 format, duration | Episode list with thumbnail, title, description | MarkupList rows: thumbnail, "E3 - Title", summary, duration, progress bar | Same layout; fix watched badge rendering |
| Search results | Hub-grouped results with section headers ("Movies", "TV Shows") | Flat grid, type badge on each tile | Flat grid | Flat PosterGrid, no type labels | Add type label below each poster OR split into sections by hub |
| Auto-play | Countdown overlay with cancel, advances to next episode | System-level next episode via ATV queue | Countdown + skip | Countdown exists in VideoPlayer but unreachable | Wire `grandparentRatingKey` so countdown fires |
| Channel icon | Official Plex branding | N/A (not on Roku) | Jellyfin logo on dark background | Current placeholder icon | Bold "SimPlex" wordmark with gradient background, gold accent |
| Documentation | Official Plex support docs | N/A | DEVGUIDE.md + contributing.md | None | README.md + CONTRIBUTING.md |

---

## Roku Icon Specifications (Research Findings)

Confidence: MEDIUM (from Roku community forum threads, Zype support, Roku developer help pages; official spec page returned 403)

| Asset | Manifest Key | Dimensions | Format |
|-------|-------------|------------|--------|
| Focus icon FHD | `mm_icon_focus_fhd` | 540x405px | PNG |
| Focus icon HD | `mm_icon_focus_hd` | 290x218px | PNG |
| Side icon FHD | `mm_icon_side_fhd` | 540x405px | PNG |
| Side icon HD | `mm_icon_side_hd` | 290x218px | PNG |
| Splash FHD | `splash_screen_fhd` | 1920x1080px | JPG |

Current manifest already references all five assets. The focus icon is the large poster shown when channel is highlighted; the side icon is the small thumbnail in the channel list. Both should carry the same branding but side icons need to be legible at smaller size.

Note: The current images directory contains `icon_focus_hd.png` and `icon_side_hd.png` as new untracked files — these may already be the replacement assets.

---

## GitHub Documentation Requirements

Based on review of the Jellyfin Roku repo (the most directly comparable published Roku media client) and general open source norms:

### README.md (required)

- Project name, tagline, screenshot or demo GIF
- What it is and what it is NOT (Plex required, sideload only, single server)
- Prerequisites (Roku device in developer mode, Plex Media Server, BrighterScript for dev)
- Installation: two paths — (1) download release .zip and sideload, (2) clone + build from source
- Features list (bullet points matching v1.1 state)
- License

### CONTRIBUTING.md (required for dev onboarding)

- Dev environment: VSCode + BrighterScript extension + Roku VSCode extension
- F5 deploy workflow
- Project structure explanation (mirrors CLAUDE.md)
- Code conventions (commit format, BrightScript patterns, no roUrlTransfer on render thread)
- Known limitations and out-of-scope features

### Optional but valuable

- `docs/ARCHITECTURE.md` (or link to `.planning/codebase/ARCHITECTURE.md`)
- GitHub releases with tagged .zip attachments for no-build installs

---

## Sources

- Codebase analysis: `SimPlex/components/screens/EpisodeScreen.brs`, `DetailScreen.brs`, `SearchScreen.brs`, `SearchScreen.xml`, `EpisodeScreen.xml`, `EpisodeItem.xml`
- Known bugs: `.planning/codebase/CONCERNS.md`, `.planning/milestones/v1.0-MILESTONE-AUDIT.md`
- Project scope: `.planning/PROJECT.md`
- Roku icon dimensions: [Roku Community Forum thread](https://community.roku.com/t5/Roku-Developer-Program/mm-icon-focus-fhd-resolution/td-p/492827), [Zype Roku App Images guide](https://support.zype.com/hc/en-us/articles/216101428-Roku-App-Images)
- TV UX patterns: [8 UX/UI best practices for Smart TV apps](https://spyro-soft.com/blog/media-and-entertainment/8-ux-ui-best-practices-for-designing-user-friendly-tv-apps)
- Competitor reference: [Jellyfin Roku GitHub](https://github.com/jellyfin/jellyfin-roku) — README structure, DEVGUIDE pattern, BrighterScript usage
- Plex search hub structure: Plex API returns `MediaContainer.Hub[]` from `/hubs/search` — confirmed by reading `SearchScreen.brs` processSearchResults() which iterates `hubs` array
- Plex forum feedback on TV navigation: [Roku Plex season/episode bug thread](https://forums.plex.tv/t/roku-app-when-going-into-a-season-it-shows-all-episodes-but-also-season-as-one-of-the-episodes/936141)

---

*Feature research for: SimPlex v1.1 Polish & Navigation*
*Researched: 2026-03-13*
