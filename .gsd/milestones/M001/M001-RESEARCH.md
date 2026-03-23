# Project Research Summary

**Project:** SimPlex v1.1 — Polish & Navigation
**Domain:** Roku BrightScript / SceneGraph sideloaded Plex client
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

SimPlex v1.1 is a polish and bug-fix milestone for an existing, working Roku channel. Unlike greenfield projects, almost every deliverable is a targeted fix to a specific known gap — auto-play wiring, watch state propagation, TV show navigation friction, search layout defects, and orphaned code — rather than new feature construction. The platform stack (BrighterScript 0.70.x, SceneGraph RSG 1.3, Task nodes, roRegistrySection) is fully validated and unchanged. No new code dependencies are required; the only new file additions are a bundled TrueType font (InterBold.ttf) and replacement image assets for icons and splash screen.

The recommended approach is a series of precise, well-scoped surgical fixes applied in dependency order, not a broad refactor. Research reveals that the most tempting expansion — splitting EpisodeScreen into a three-screen Season/Episode hierarchy — carries the highest risk of breaking existing working behaviour (VideoPlayer context fields, focus recovery after playback) and should be avoided unless the current two-panel layout proves genuinely insufficient. All required fix information exists in the live codebase; there is no speculative architecture work needed.

The primary risk for v1.1 is a live firmware crash: `BusySpinner` causes SIGSEGV signal 11 (crash, no BrightScript trace) on the test device, with root cause not yet fully confirmed (TEST4b pending). This must be resolved or definitively scoped before any new screen work proceeds. Secondary risks are procedural: orphaned file deletion requires a sideload-and-verify cycle after each deletion, server switching removal touches four separate codepaths that must all be patched before the screen is deleted, and the HAR file on disk contains auth tokens that must never reach GitHub.

## Key Findings

### Recommended Stack

The v1.0 stack requires no changes for v1.1. BrighterScript 0.70.x compiles all existing and planned code. The only new file type is a static-weight TrueType font (InterBold.ttf, SIL OFL licensed, ~300KB) placed in a new `SimPlex/fonts/` directory and referenced via the SceneGraph `Font` node. `bsconfig.json` must include `fonts/**/*` in its files array. Icon and splash assets are PNG/JPG replacements bundled in `images/` — no new code path.

Two platform limitations are confirmed and affect branding choices: SceneGraph `Label` nodes have no stroke or shadow property (workaround: stack two offset labels), and `Rectangle` nodes have no gradient fill (workaround: pre-rendered PNG via `Poster` node). Both workarounds are established community patterns with negligible render cost. Static-weight TTF (InterBold.ttf) is the correct font loading approach — variable font support in the Roku OS Font node is unverified and should not be assumed.

**Core technologies:**
- BrighterScript 0.70.x: compile toolchain — unchanged, confirmed stable, no update needed
- SceneGraph RSG 1.3: all UI, task, and animation nodes — unchanged
- SceneGraph `Timer` node: auto-play countdown — built into OS, already used in SearchScreen for debounce; proven pattern
- SceneGraph `Font` node with `uri` field: custom TTF font loading — confirmed working community pattern
- roRegistrySection("SimPlex"): all persistent state — unchanged
- InterBold.ttf (new asset): bolder title typography — Inter is screen-legibility-optimised, SIL OFL licensed, ~300KB

**What NOT to add:** BrighterScript 1.0.0-alpha (unstable alpha, explicitly deferred), Maestro MVVM (deprecated Nov 2023), SGDEX (adds enormous complexity for a sideloaded channel), roFontRegistry BrightScript API (legacy non-SceneGraph path), WebP/AVIF for icons (Roku manifest expects PNG/JPG), variable font TTF (support unverified), BusySpinner or Animation nodes (SIGSEGV crash risk until root cause confirmed).

### Expected Features

**Must have (table stakes — closes v1.1):**
- Auto-play next episode working end-to-end — countdown fires, advances, cancels; currently unreachable because `grandparentRatingKey` is not passed from DetailScreen. EpisodeScreen is already fixed; DetailScreen is not.
- Watch state propagates to HomeScreen hub rows after playback/watched toggle — currently only the poster grid ContentNode is walked; hub RowList ContentNode tree is not walked
- TV show navigation: grid tap → EpisodeScreen directly, removing the unnecessary DetailScreen intermediate hop for shows
- Search results legible with type context — episode results in portrait grid show `parentThumb` (portrait) not `thumb` (landscape, distorted)
- Icon and splash replaced with correctly-sized, properly-branded assets across all four Roku variants simultaneously
- Orphaned files (`normalizers.brs`, `capabilities.brs`) deleted and codebase compiles cleanly
- README and CONTRIBUTING.md written; repository publishable to GitHub

**Should have (valuable, can slip to v1.2 if scope is tight):**
- Continue Watching hub items launch playback directly (check `viewOffset > 0`) rather than routing via DetailScreen
- Collections accessible from sidebar without requiring a library context first
- Season poster grid as an upgrade to the current LabelList season tabs

**Defer (v2+):**
- Music library browsing and playback
- Photo grid and slideshow
- Live TV / EPG
- Grid/list toggle per library type
- Bulk "mark all watched" for a season

**Explicit anti-features (do not build in v1.1):**
- Animated screen transitions — SceneGraph Animation nodes are the suspected BusySpinner crash trigger; defer until root cause confirmed
- Custom episode sorting / filtering — Plex server handles ordering; UI complexity has near-zero benefit
- Server switching UI overhaul — single-server scope per PROJECT.md; remove dead code rather than build it out
- Loading spinners (BusySpinner) — confirmed SIGSEGV crash trigger

### Architecture Approach

The v1.1 architecture is modification-only — no new screens or components are required. All changes are contained to existing files. The most complex target is EpisodeScreen (watch state emission, auto-play season boundary fix, options key "Info" action to reach DetailScreen from within EpisodeScreen). The simplest is a one-line bug fix in PosterGridItem (hardcoded progress bar width). The existing layered architecture — screen stack managed by MainScene, widgets reused across screens, all HTTP via Task nodes, persistence via roRegistrySection — remains intact and correct.

**Major components and their v1.1 status:**
1. `HomeScreen.brs` — Modified: 5-line routing change so TV show taps emit `{action:"episodes"}` instead of `{action:"detail"}`
2. `EpisodeScreen.brs` — Modified (primary overhaul target): watch state emission after playback, auto-play season boundary handling, options key "Info" route to DetailScreen
3. `SearchScreen.brs` — Modified: keyboard collapse on grid focus, episode thumbnail fix (`parentThumb` for episode results), column count computed from `gridWidth` field
4. `PosterGridItem.brs` — Bug fix: `Int(240 * progress)` → `Int(m.constants.POSTER_WIDTH * progress)` (1 line)
5. `SettingsScreen.brs` — Simplified: remove "Switch Server" discovery flow (~80 lines, 4 call sites must be patched first)
6. `utils.brs` — Cleaned: promote `GetRatingKeyStr()` as shared helper replacing 8+ duplicate inline blocks; remove dead spinner guards
7. `source/normalizers.brs`, `source/capabilities.brs` — Delete (zero call sites confirmed; sideload-test after each deletion)
8. `MainScene.brs` — Minor: verify `popScreen` type checks cover all screen subtypes

**Not touched in v1.1:** VideoPlayer, PlexApiTask, DetailScreen (structural), Sidebar, FilterBar, AlphaNav, TrackSelectionPanel, PlexSessionTask, PlexAuthTask, ServerConnectionTask.

### Critical Pitfalls

1. **BusySpinner SIGSEGV is unresolved — must be addressed in Phase 1.** Any screen that introduces `BusySpinner` or `Animation` nodes before root cause is confirmed will crash within 3-5 seconds of init with signal 11 (no BrightScript trace, silent channel exit). Use static `Label` text toggling for all loading feedback in v1.1.

2. **EpisodeScreen navigation refactor can sever VideoPlayer context.** If the overhaul splits EpisodeScreen into Season + Episode screens, the five VideoPlayer context fields (`grandparentRatingKey`, `parentRatingKey`, `episodeIndex`, `seasonIndex`, `mediaKey`) must all survive the boundary. Auto-play silently breaks if any are missing. Prefer enhancing the existing two-panel EpisodeScreen over splitting into three screens.

3. **Watch state does not reach hub row ContentNodes.** `HomeScreen.onWatchStateUpdate` walks the poster grid ContentNode tree but not the RowList tree. "Continue Watching" hub items persist after marking watched. The hub tree walker must be added; its structure (rows as children, items as grandchildren) differs from the flat poster grid.

4. **Server switching removal touches four codepaths simultaneously.** Deleting `ServerListScreen` before patching all four call sites causes a crash during auth with a multi-server plex.tv account. Remove in sequence: patch all call sites first, delete screen last, test with a multi-server account.

5. **Orphaned file deletion crashes the compile if any XML `<script>` tag still references the file.** Search all `.xml` and `.brs` files for references before each deletion. Sideload and check port 8085 debug console after each deletion. Treat each deletion as a separate deploy-test cycle.

6. **Auto-play gap exists in both EpisodeScreen AND DetailScreen.** EpisodeScreen already passes all five VideoPlayer context fields (line 416-432 — already fixed). DetailScreen does not. Episode played from DetailScreen will not auto-play until DetailScreen is also updated.

7. **HAR file on disk contains live auth tokens.** `plex.owlfarm.ad.har` is in the untracked files list. Add `*.har` to `.gitignore` before the first GitHub push; if not done first, the HAR file can be accidentally committed with a bulk `git add`.

## Implications for Roadmap

Based on combined research, the following phase structure is recommended. It follows the dependency order derived from architecture analysis and places the SIGSEGV investigation first as a mandatory gate for all screen work.

### Phase 1: Crash Safety and Foundation Cleanup
**Rationale:** The BusySpinner SIGSEGV (signal 11, no trace) is an open investigation with TEST4b still pending. Until the root cause is confirmed (BusySpinner-specific vs. Animation nodes broadly), no new screen work can be trusted to be stable. Cleanup now reduces confusion and sets a clean baseline for all subsequent phases.
**Delivers:** Confirmed crash-safe baseline; orphaned files deleted; `GetRatingKeyStr()` extracted to utils; dead spinner guards removed; `*.har` in `.gitignore`; PosterGridItem progress bar 1-line fix applied
**Addresses:** Codebase cleanup (P1), BusySpinner root cause confirmation, PosterGridItem bug (XS fix with no dependencies — do it here)
**Avoids:** SIGSEGV from adding new SceneGraph components (Pitfall 8); compile crashes from orphaned file deletion (Pitfall 6)

### Phase 2: Bug Fixes — Watch State and Auto-Play
**Rationale:** Watch state propagation and auto-play are both P1 bugs with known exact fixes. They share a dependency (both require EpisodeScreen to emit `watchStateUpdate` correctly after playback) and should be done together to avoid double-patching EpisodeScreen. The hub row ContentNode walker must be added alongside the poster grid walker.
**Delivers:** Auto-play working end-to-end from both EpisodeScreen and DetailScreen; "Continue Watching" hub row updates correctly after watched/unwatched toggle; watch state propagates to both poster grid and hub RowList ContentNode trees
**Addresses:** Auto-play wiring (P1), watch state propagation (P1)
**Avoids:** Auto-play gap in DetailScreen (Pitfall 9); watch state missing from hub rows (Pitfall 3)

### Phase 3: TV Show Direct Navigation
**Rationale:** Direct navigation (show tap → EpisodeScreen) is a 5-line change in HomeScreen routing, but it must come after watch state is fixed. The new navigation path means HomeScreen must correctly update when EpisodeScreen pops — that update relies on watch state propagation being in place. The options key "Info" action in EpisodeScreen gives users a path back to DetailScreen for show-level metadata.
**Delivers:** Grid tap on TV show goes directly to EpisodeScreen; DetailScreen accessible via options key ("Info") from within EpisodeScreen; navigation stack depth reduced from 3 to 2 levels for TV shows
**Addresses:** TV show navigation overhaul (P1)
**Avoids:** Splitting EpisodeScreen into three screens (Pitfall 1); focus loss after VideoPlayer closure (Pitfall 2); breaking VideoPlayer context fields

### Phase 4: Search Layout Fix and Collections
**Rationale:** These are independent fixes that do not depend on navigation or watch state changes. Grouping them keeps the patch set focused and avoids a state where search partially works and collections are still a dead-end.
**Delivers:** Episode search results use `parentThumb` (no distorted thumbnails); keyboard collapses on grid focus expanding to full-width 6-column grid; column count computed dynamically from `gridWidth`; collections routable from both HomeScreen grid and SearchScreen
**Addresses:** Search layout (P1), collections handler dispatch mismatch (Pitfall 4), search thumbnail aspect ratio (Pitfall 5)
**Avoids:** Aspect ratio distortion in search grid; collections "Play" button sending collection ratingKey to VideoPlayer

### Phase 5: Server Switching Removal and Settings Simplification
**Rationale:** Server switching removal is isolated but requires careful sequencing across four codepaths. Doing it after navigation and search are stable means the test surface is smaller and regression risk is lower. This is the last code-only phase before asset and documentation work.
**Delivers:** "Switch Server" removed from Settings; ~80 lines of duplicate discovery logic deleted; SettingsScreen simplified to auth, library manager, and user context; stale `m.global.serverUri` bug eliminated
**Addresses:** Server switching fix-or-remove (P2 per PROJECT.md)
**Avoids:** Partial removal crashing multi-server auth flow (Pitfall 7)

### Phase 6: App Branding
**Rationale:** Purely asset work — no code dependencies. Can be run in parallel with Phase 5 if resources allow, or sequentially after. Placed here to ensure asset design reflects the final v1.1 feature set before GitHub publication.
**Delivers:** InterBold.ttf bundled in `SimPlex/fonts/`; all four icon variants updated simultaneously (540x405 FHD focus, 246x140 FHD side, 336x210 HD focus, 164x94 HD side); splash at exactly 1920x1080; optional gradient background PNG; `bsconfig.json` updated with `fonts/**/*`; stacked-label shadow pattern applied where bold typography is used
**Addresses:** App branding refresh (P1 per PROJECT.md)
**Avoids:** Icon dimension mismatch across Roku devices (Pitfall 10); WebP/AVIF format incompatibility; variable font instability

### Phase 7: GitHub Documentation
**Rationale:** Written last, after code and assets are final. Documentation describes what was actually built. This phase also includes the GitHub publish security audit (LogEvent credential leakage, HAR gitignore already done in Phase 1).
**Delivers:** `README.md` (overview, screenshots, sideload how-to, feature list, license); `CONTRIBUTING.md` (dev environment, F5 deploy, code conventions, known limitations); optional `docs/ARCHITECTURE.md`; GitHub repository publishable
**Addresses:** GitHub documentation (P1 for publishability)
**Avoids:** Auth tokens in LogEvent calls (audit as part of this phase); HAR file in repo (gated by Phase 1 `.gitignore`)

### Phase Ordering Rationale

- SIGSEGV confirmation gates all screen work — if Animation nodes broadly are implicated, several v1.1 changes that involve any visual feedback need to use only safe patterns. This cannot be discovered mid-refactor.
- Watch state must precede direct navigation — the new HomeScreen → EpisodeScreen path immediately exercises the propagation path; broken propagation would manifest as a navigation bug and be harder to isolate.
- Bug fixes (watch state, auto-play) precede less critical fixes (search, collections) to deliver the highest user value earliest.
- Server switching removal is deferred past the core fixes to keep the test surface smaller during the most complex phases.
- Branding and documentation are independent of code and are placed last to avoid rework if code changes affect what is documented or shown in screenshots.

### Research Flags

Phases with well-documented patterns where `research-phase` can be skipped:
- **Phase 1 (Cleanup):** Pure deletion and refactoring. All information needed is in this research package.
- **Phase 3 (Direct Navigation):** 5-line HomeScreen change. The routing pattern already exists in the codebase; MainScene already has the `action:"episodes"` branch.
- **Phase 5 (Server Switching Removal):** Deletion and call-site patching. ARCHITECTURE.md identifies all four codepaths with exact sub names.
- **Phase 6 (Branding):** Asset work with confirmed dimensions from STACK.md. No platform uncertainty beyond the icon dimension discrepancy noted in Gaps below.
- **Phase 7 (Documentation):** Plain Markdown. No research needed.

Phases that may benefit from targeted research before planning:
- **Phase 2 (Watch State and Auto-Play):** Hub row ContentNode tree walking is the non-obvious part. The existing poster grid walker provides a template, but RowList ContentNode structure (rows as children, items as grandchildren) differs from a flat grid. A quick code read of HomeScreen.brs at the RowList population site (`processHubs()`) before planning the walker is recommended.
- **Phase 4 (Search Layout and Collections):** The keyboard collapse animation (repositioning grid to full width) should be prototyped early — if it causes render jank on low-RAM Roku Express devices, the simpler fallback is a fixed 4-column layout with no collapse. Collections endpoint response structure should be verified against the live Plex server before building the handler.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Based on live codebase inspection and confirmed Roku platform behaviour. Only caveat: icon dimension spec page returned 403; community-verified values used (MEDIUM for that specific finding). |
| Features | HIGH | All bugs confirmed by code reading (line numbers cited). Known gaps documented in PROJECT.md, CONCERNS.md, and v1.0 milestone audit. Feature priorities grounded in actual codebase state. |
| Architecture | HIGH | All component analysis from live code, not speculation. Fix approaches are code-level specific with sub names, line numbers, and exact field names. |
| Pitfalls | HIGH | All pitfalls grounded in observed code state or confirmed platform constraints. BusySpinner SIGSEGV is the only unresolved area — root cause pending TEST4b. |

**Overall confidence:** HIGH

### Gaps to Address

- **BusySpinner root cause:** TEST4b (fade animations, no spinner) was pending at v1.0 close. Phase 1 must include a structured test run to confirm whether the crash is BusySpinner-specific or Animation-node-general. If Animation nodes broadly are implicated, any future loading feedback using opacity animation is also ruled out.
- **Icon dimension discrepancy:** STACK.md and FEATURES.md report slightly different HD icon dimensions for side icons (STACK: 246x140 FHD side; FEATURES.md cites Zype source: 290x218 for both FHD focus and FHD side). The official Roku spec page returned 403. Verify by checking the Roku developer portal directly or testing a sideload with both dimension sets before committing to final asset production.
- **RowList ContentNode tree shape for hub row watch state walker:** `processHubs()` in HomeScreen.brs builds the RowList ContentNode but the exact child/grandchild structure needs to be confirmed before writing the watch state walker. A code read of HomeScreen.brs at the hub population site resolves this; it is a 15-minute task, not a research gap.
- **Collections API endpoint structure:** `/library/collections` is referenced in FEATURES.md and ARCHITECTURE.md but the exact API response shape should be verified against the live Plex server before building the handler. If it mirrors the standard `MediaContainer.Metadata[]` structure, no additional work is needed; if not, the handler must be adapted.

## Sources

### Primary (HIGH confidence)
- Live codebase: `EpisodeScreen.brs/.xml`, `DetailScreen.brs`, `HomeScreen.brs`, `MainScene.brs`, `SearchScreen.brs/.xml`, `VideoPlayer.brs/.xml`, `PosterGrid.brs/.xml`, `PosterGridItem.brs`, `utils.brs`, `constants.brs`, `SettingsScreen.brs`, `source/normalizers.brs`, `source/capabilities.brs` — all architecture and pitfall findings
- `.planning/PROJECT.md` — documented known gaps, explicit feature scope (single server, no multi-server)
- `.planning/codebase/CONCERNS.md` — documented UX gaps and open bugs
- `.planning/milestones/v1.0-MILESTONE-AUDIT.md` — confirmed v1.0 completion state
- `CLAUDE.md` — platform constraints and architecture rules
- `.planning/UAT-DEBUG-CONTEXT.md` — BusySpinner SIGSEGV investigation state, bisection results
- Roku Developer docs — Timer node, Font node (official, HIGH confidence)
- Inter font project (rsms.me/inter) — SIL OFL license confirmed

### Secondary (MEDIUM confidence)
- Roku Community Forum — `mm_icon_focus_fhd` dimensions (multiple threads consistent; official spec page returned 403)
- Roku Community Forum — gradient Rectangle limitation (multiple threads confirm no native gradient; workaround established)
- Roku Community Forum — custom TTF font usage (consistent with Font node documentation pattern)
- Roku Community Forum — Label stroke limitation (no stroke property; stacked-label workaround established)
- Zype Roku App Images guide — icon dimension reference (cross-check source; differs from other community sources on side icon FHD dimensions)
- Jellyfin Roku GitHub — README and CONTRIBUTING.md structure reference

### Tertiary
- TV UX best practices (spyro-soft.com) — season navigation patterns across Netflix, Plex, Infuse, Jellyfin (used to validate feature prioritisation only, not implementation decisions)
- Plex forum feedback on TV navigation — user complaint patterns confirming TV show navigation friction (corroborating, not primary)

---
*Research completed: 2026-03-13*
*Ready for roadmap: yes*

# Architecture Research

**Domain:** Roku SceneGraph / BrightScript Plex client — v1.1 Polish & Navigation
**Researched:** 2026-03-13
**Confidence:** HIGH (analysis of live codebase, no speculation)

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MainScene (root)                              │
│  screenStack: []   focusStack: []   m.global.constants              │
├─────────────────────────────────────────────────────────────────────┤
│                       Screen Layer (push/pop)                        │
│  ┌───────────┐  ┌────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │HomeScreen │  │DetailScreen│  │EpisodeScreen│  │ SearchScreen │  │
│  │(sidebar + │  │(movie/ep   │  │(season list │  │(keyboard +   │  │
│  │ grid/hubs)│  │ detail)    │  │ + ep list)  │  │ PosterGrid)  │  │
│  └───────────┘  └────────────┘  └─────────────┘  └──────────────┘  │
│  ┌───────────┐  ┌────────────┐  ┌─────────────┐                     │
│  │Settings   │  │UserPicker  │  │Playlist     │                     │
│  │Screen     │  │Screen      │  │Screen       │                     │
│  └───────────┘  └────────────┘  └─────────────┘                     │
├─────────────────────────────────────────────────────────────────────┤
│                       Widget Layer (reusable)                        │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │PosterGrid│  │EpisodeItem │  │VideoPlayer│  │TrackSelectionPanel│ │
│  │(MarkupGrid│  │(MarkupList │  │(Video +  │  │(audio/subtitle)   │ │
│  │+GridItem)│  │ item comp) │  │ overlays)│  │                   │ │
│  └──────────┘  └────────────┘  └──────────┘  └────────────────────┘ │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐                         │
│  │Sidebar   │  │FilterBar   │  │AlphaNav  │                         │
│  └──────────┘  └────────────┘  └──────────┘                         │
├─────────────────────────────────────────────────────────────────────┤
│                        Task Layer (background HTTP)                  │
│  ┌──────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │PlexApiTask│  │PlexSearch  │  │PlexAuthTask  │  │PlexSession   │  │
│  │(general) │  │Task        │  │(PIN OAuth)   │  │Task (progress│  │
│  └──────────┘  └────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────┐                                                         │
│  │ServerConn│                                                         │
│  │ectionTask│                                                         │
│  └──────────┘                                                         │
├─────────────────────────────────────────────────────────────────────┤
│                       Persistence Layer                              │
│  roRegistrySection("SimPlex") — authToken, adminToken, serverUri,   │
│  serverClientId, activeUserName, deviceId, pinnedLibraries,         │
│  sidebarLibraries                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | v1.1 Status |
|-----------|----------------|-------------|
| `MainScene` | Screen stack (push/pop/clear), auth routing, server disconnect/reconnect, dialog owner | Stable — minor extension for new popScreen type checks |
| `HomeScreen` | Sidebar + hub rows + library grid (three-zone focus) | **Modified** — TV show tap routing change |
| `DetailScreen` | Movie/episode detail + playback buttons + watched state toggle | Stable |
| `EpisodeScreen` | Season list (LabelList) + episode list (MarkupList/EpisodeItem) + inline playback | **Modified** — overhaul target |
| `SearchScreen` | Keyboard (left) + PosterGrid results (right) — left/right focus split | **Modified** — layout fix |
| `PosterGrid` | MarkupGrid wrapper — pagination trigger, focus delegation | **Bug fix** — progress bar width |
| `PosterGridItem` | Poster + title + progress bar + unwatched badge | **Bug fix** — hardcoded 240 width |
| `EpisodeItem` | 16:9 thumbnail + title + summary + duration + progress + badge | Stable |
| `VideoPlayer` | Video node + skip intro/credits + auto-play overlay + track panel + session reporting | Stable |
| `SettingsScreen` | Auth, server discovery, library manager, user context | **Modified** — server switching simplified |
| `PlexApiTask` | All PMS and plex.tv HTTP | Stable |

---

## TV Show Navigation: Current State and Overhaul Target

### Current Flow (v1.0)

```
HomeScreen grid → itemSelected {action:"detail", itemType:"show"}
    → MainScene.showDetailScreen()
        → DetailScreen loads /library/metadata/{id}
        → buildButtons() sees type="show" → adds "Browse Seasons" button
        → user presses Browse Seasons → itemSelected {action:"episodes", ratingKey, title}
            → MainScene.showEpisodeScreen()
                → EpisodeScreen: LabelList seasons (top) + MarkupList episodes (below)
```

**Stack depth for TV show:** HomeScreen → DetailScreen → EpisodeScreen (3 levels)

**Problem:** DetailScreen is an unnecessary intermediate screen for TV shows. The "Browse Seasons" button is non-obvious for a TV remote — users expect: grid tap → season/episode screen → play. The extra hop adds friction and the detail screen layout (poster left, metadata right, buttons below) is designed for movies, not for shows with season structure.

### Overhaul Target (v1.1): Direct Navigation

From the grid, TV show taps go directly to EpisodeScreen. DetailScreen remains accessible via an "Info" action from within EpisodeScreen.

```
HomeScreen grid → itemSelected {action:"episodes", ratingKey, title}  [for shows]
    → MainScene.showEpisodeScreen(ratingKey, title)
        → EpisodeScreen: season selector + episode list
        → user can press * (options) → "Show Info" → pushes DetailScreen
```

**Stack depth for TV show:** HomeScreen → EpisodeScreen (2 levels, same as movies)

### Integration Requirements

**`HomeScreen.brs`:**
In `onGridItemSelected` and hub row selection handlers, the current logic fires `{action:"detail"}` for all item types. Change the type check so shows fire `{action:"episodes"}` instead:

```brightscript
' Current (v1.0):
m.top.itemSelected = {action: "detail", ratingKey: ratingKey, itemType: itemType}

' Target (v1.1) — add type branch:
if itemType = "show"
    m.top.itemSelected = {action: "episodes", ratingKey: ratingKey, title: title}
else
    m.top.itemSelected = {action: "detail", ratingKey: ratingKey, itemType: itemType}
end if
```

**`MainScene.brs`:**
`onItemSelected` already has the `action:"episodes"` branch routing to `showEpisodeScreen`. No change needed.

**`EpisodeScreen.brs`:**
Add options key handler that fires `{action:"detail", ratingKey: m.top.ratingKey, itemType:"show"}` for users who want the show metadata screen. This makes DetailScreen an optional destination, not a required step.

**Watch state propagation fix:**
EpisodeScreen should emit `m.global.watchStateUpdate` after playback completes (same structure DetailScreen uses). HomeScreen already observes this field. The payload should include the show's `ratingKey` (the `m.top.ratingKey` in EpisodeScreen) so HomeScreen can update the show poster's unwatched episode badge.

### Season/Episode Layout

Currently EpisodeScreen uses:
- `LabelList` — horizontal season tabs at top (numRows=1, items [200, 50])
- `MarkupList` — vertical full-width episode rows using `EpisodeItem`

The two-zone layout (tabs above, list below) is the right pattern and should be kept. The v1.1 work is layout polish: ensure the season list scrolls correctly if there are many seasons, add keyboard shortcut hints, and verify `EpisodeItem.brs` is correctly wired. The XML references `EpisodeItem.brs` via a `<script>` tag but the file must exist and have an `onItemContentChange` handler — verify this is in place.

---

## Search Layout Restructure

### Current Layout Problem

```
SearchScreen (1920x1080):
  Keyboard: translation="[80, 120]"   (~620px wide)
  PosterGrid: translation="[700, 200]", gridWidth="1140"
    → 6-column grid in 1140px = only 4 full columns fit (240px * 4 = 960, 5th clips)
  Focus: left key → keyboard, right key → grid
```

The `PosterGrid` is instantiated with `gridWidth="1140"` but PosterGrid.brs sets `numColumns = c.GRID_COLUMNS` (6). This means only ~4 full posters fit in the 1140px right zone. The `gridWidth` field exists in the PosterGrid interface but currently has no effect on column count — it is just stored, never read.

Additionally, search results flatten all Hub types (movies, shows, episodes, artists) into a single grid using the 240x360 portrait poster. Episodes appear with portrait frames for landscape thumbnails, which looks wrong.

### Recommended Fix (v1.1)

**Step 1 — Fix column count in search:** Make `PosterGrid.brs` read `gridWidth` and compute columns:

```brightscript
' In PosterGrid.brs onGridWidthChange() or in init():
availableWidth = m.top.gridWidth
columnWidth = c.POSTER_WIDTH + c.GRID_H_SPACING
m.grid.numColumns = Int(availableWidth / columnWidth)  ' = 4 for 1140px
```

This makes the 4-column layout intentional rather than accidental clipping.

**Step 2 — Keyboard collapse on grid focus:** When user moves right into the grid, hide the keyboard and expand the grid to full width:

```brightscript
' In SearchScreen.brs onKeyEvent:
else if key = "right" and m.focusOnKeyboard
    m.focusOnKeyboard = false
    m.keyboard.visible = false
    ' Reposition grid to full width
    m.resultsGrid.translation = [80, 160]
    m.top.findNode("searchQueryLabel").translation = [80, 80]
    m.resultsGrid.setFocus(true)
    return true
else if key = "left" and not m.focusOnKeyboard
    m.focusOnKeyboard = true
    m.keyboard.visible = true
    m.resultsGrid.translation = [700, 200]
    m.top.findNode("searchQueryLabel").translation = [700, 120]
    m.keyboard.setFocus(true)
    return true
```

Full-width grid (1760px) at 6 columns shows the same density as the library grid, which makes result browsing feel consistent.

**Step 3 — Search result type grouping (optional):** Rather than mixing all types into one flat grid, consider labeling sections ("Movies", "Shows") using a RowList or section headers. This is medium complexity and can be deferred if scope is tight.

---

## Thumbnail Aspect Ratio Changes

### Problem

`PosterGrid` and `PosterGridItem` hardcode 240x360 (2:3 portrait). This is correct for movies and TV shows. It fails for episodes (16:9) which appear pinched in portrait frames.

### Current Thumbnail Requests by Context

| Context | Requested Size | Ratio | Source |
|---------|---------------|-------|--------|
| Library grid (movies/shows) | 240x360 | 2:3 portrait | `PosterGridItem.brs` via `HDPosterUrl` |
| Episode list thumbnails | 320x180 | 16:9 landscape | `EpisodeScreen.brs` line 247 |
| Detail screen poster | 640x360 | 16:9 landscape | `DetailScreen.brs` line 172 |
| Search results (mixed) | 240x360 | 2:3 portrait (wrong for episodes) | `SearchScreen.brs` line 149 |

### Bug: Hardcoded Width in PosterGridItem

`PosterGridItem.brs` line 57 hardcodes:
```brightscript
m.progressFill.width = Int(240 * progress)
```

This should use the actual poster width from constants:
```brightscript
m.progressFill.width = Int(m.constants.POSTER_WIDTH * progress)
```

One-line fix, no dependencies.

### Aspect Ratio for v1.1 Scope

The `EpisodeItem` widget already uses 213x120 (16:9) thumbnails — this is the right place for episode thumbnails. The issue is that collections browsed through the library grid occasionally show up in search results with wrong ratios, and episodes should never appear in a portrait PosterGrid.

**For v1.1:** Fix the progress bar width bug. Ensure search results only show movies and shows (filter episodes and other types from `processSearchResults`), so the portrait grid issue is avoided rather than solved. A landscape `PosterGrid` variant is a future enhancement.

---

## Server Switching Architecture

### Current State

"Switch Server" appears in `SettingsScreen.brs` (index 4 in the settings list → `discoverServers()`). This function:
1. Fires `PlexApiTask` to `plex.tv/api/v2/resources`
2. Iterates servers and connections via `tryServerConnection()` / `onConnectionTestComplete()`
3. On success: calls `SetServerUri()` (writes registry) but does NOT update `m.global.serverUri`
4. Fires `m.top.authComplete = true` — which MainScene interprets as full re-auth complete → clears screen stack and shows home

**Bugs:**
- `m.global.serverUri` (if cached) is not updated after `SetServerUri()` in `onConnectionTestComplete`. Screens that use `GetServerUri()` (reads registry directly) are fine. Tasks that cache the URI during their init are not.
- The discovery logic in SettingsScreen (`discoverServers()`, `tryServerConnection()`, `onConnectionTestComplete()`) duplicates the logic in `MainScene.navigateToServerList()` / `MainScene.autoConnectToServer()`.
- Sequential connection testing (one at a time, fallback to next) is slow for a single-server use case.

### Fix Decision: Remove "Switch Server", Keep "Re-authenticate"

Since multi-server is explicitly out of scope (PROJECT.md), "Switch Server" is unnecessary complexity. The right user action for changing servers is to sign out and sign back in, which already works.

**Replace** SettingsScreen item index 4 ("Switch Server") with either:
- Nothing (remove from the menu), or
- "Re-authenticate" which calls `signOut()` and `requestPin()` — identical to signing out

This removes ~80 lines of duplicate discovery/connection logic from SettingsScreen and eliminates the stale `m.global.serverUri` bug.

**If keep for future:** The fix is to add a global update helper in utils.brs:
```brightscript
sub UpdateServerUri(uri as String)
    SetServerUri(uri)
    if m.global <> invalid
        m.global.serverUri = uri
    end if
end sub
```
And call this instead of `SetServerUri()` everywhere a new server URI is established.

---

## Watch State Propagation Gap

### Problem

When returning from EpisodeScreen (after watching episodes), HomeScreen's grid still shows old progress/watched state for the show poster. The `onWatchStateUpdate` observer in HomeScreen works for individual item updates (DetailScreen → HomeScreen path), but EpisodeScreen → HomeScreen is missing.

### Current Propagation Paths

| Source | Signal | Observer |
|--------|--------|----------|
| DetailScreen marks watched | `m.global.watchStateUpdate = {ratingKey, viewCount, viewOffset}` | HomeScreen.onWatchStateUpdate, EpisodeScreen.onWatchStateUpdate |
| EpisodeScreen playback ends | `loadEpisodes()` called — episode list refreshed | Nothing propagates to HomeScreen |
| EpisodeScreen options menu watched toggle | `m.episodeList.content = m.episodeList.content` (force re-render) | Nothing propagates to HomeScreen |

### Fix

After `onPlaybackComplete` in EpisodeScreen refreshes the episode list, it should also emit a watch state signal for the show itself. Since EpisodeScreen holds `m.top.ratingKey` (the show's ratingKey), it can emit:

```brightscript
' In EpisodeScreen.onPlaybackComplete(), after loadEpisodes():
watchUpdate = {
    ratingKey: m.top.ratingKey  ' show ratingKey
    viewCount: -1               ' -1 = "needs refresh", not a known value
    viewOffset: 0
}
m.global.watchStateUpdate = watchUpdate
```

HomeScreen's `onWatchStateUpdate` already scans its ContentNode grid by ratingKey and updates the matching item. The `-1` viewCount convention signals "re-fetch this item's data" vs an optimistic update. Alternatively, HomeScreen can simply reload the current library page when it returns to focus via a `onFocusChange` observer — simpler but causes a flash.

---

## Auto-Play Wiring Gap

### Problem (Known from PROJECT.md)

`grandparentRatingKey` is correctly passed to VideoPlayer from EpisodeScreen (line 416):
```brightscript
m.player.grandparentRatingKey = m.top.ratingKey  ' Show ratingKey
m.player.parentRatingKey = seasonKey             ' Season ratingKey
m.player.episodeIndex = episode.episodeNumber
m.player.seasonIndex = m.currentSeasonIndex
```

The gap is that when VideoPlayer auto-plays the next episode and fires `nextEpisodeStarted`, EpisodeScreen's `onNextEpisodeStarted` handler calls `loadEpisodes(currentSeason)` but does not check if the new episode is in the *next* season. If auto-play crosses a season boundary, the episode list shows the wrong season.

### Fix

VideoPlayer's `nextEpisodeStarted` field should carry metadata about the next episode:
```brightscript
' VideoPlayer should set:
m.top.nextEpisodeStarted = {
    ratingKey: nextEpisode.ratingKey
    seasonIndex: nextEpisode.seasonIndex  ' 0-based
    episodeIndex: nextEpisode.index
}
```

EpisodeScreen's `onNextEpisodeStarted` should update `m.currentSeasonIndex` and reload episodes if the season changed:
```brightscript
sub onNextEpisodeStarted(event as Object)
    data = event.getData()
    if data <> invalid and data.seasonIndex <> invalid
        if data.seasonIndex <> m.currentSeasonIndex
            m.currentSeasonIndex = data.seasonIndex
            m.seasonList.jumpToItem = data.seasonIndex
        end if
    end if
    ' Always refresh current season's episode list
    loadEpisodes(m.seasons[m.currentSeasonIndex].ratingKey)
end sub
```

---

## Codebase Cleanup: Orphaned and Brittle Patterns

### Orphaned Files

| File | Issue | Action |
|------|-------|--------|
| `source/normalizers.brs` | Functions defined (NormalizeMovieList, NormalizeShowList, etc.) but never called — all screens do inline JSON→ContentNode conversion | **Delete** |
| `source/capabilities.brs` | `ParseServerCapabilities()` defined but never called | **Delete** |

Both files were written during planning phase as forward-looking scaffolding. They contradict the actual pattern that evolved (inline normalization per screen). Leaving them in creates confusion about which pattern to follow. Delete them; if future phases need normalizers, reintroduce with a clear adoption plan.

### Brittle Patterns to Fix

**1. ratingKey type coercion — duplicated in 8+ locations**

Every screen repeats:
```brightscript
if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
    seasonKey = season.ratingKey
else
    seasonKey = season.ratingKey.ToStr()
end if
```

`DetailScreen.brs` already has this as a local function `getRatingKeyString()`. Promote it to `utils.brs` as `GetRatingKeyStr(key as Dynamic) as String` and replace all instances.

**2. Dead spinner code in every screen**

Every screen has:
```brightscript
' LoadingSpinner removed - BusySpinner causes firmware SIGSEGV crashes on Roku
m.loadingSpinner = invalid
```
...followed by guards like `if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true`.

These guards are dead code. Remove all spinner-related lines from all screens. If loading indication is needed in a future phase, use a safe approach (a Rectangle + opacity animation).

**3. Task creation pattern — new task per request**

Several screens create a new `PlexApiTask` node for every request:
```brightscript
task = CreateObject("roSGNode", "PlexApiTask")
task.endpoint = endpoint
task.observeField("status", "handler")
task.control = "run"
m.someTask = task
```

HomeScreen already uses the better pattern (single task created in `init()`, reused). The "create per request" pattern is not catastrophically wrong (SceneGraph GC handles it), but it creates memory churn on large libraries. For v1.1 cleanup, EpisodeScreen and SearchScreen are the highest-traffic screens and should be updated to use a single reused task.

**4. `showError()` vs `showErrorDialog()` inconsistency**

Several screens have both `showError(message)` (no buttons, just OK) and `showErrorDialog(title, message)` (Retry/Dismiss buttons). They're slightly different dialogs used in slightly different contexts. Consolidate into one pattern: always show Retry/Dismiss, remove the standalone `showError`.

---

## Data Flow

### TV Show Navigation Flow (after v1.1 overhaul)

```
User selects TV show in grid (HomeScreen)
    ↓
HomeScreen.onGridItemSelected:
    itemType = "show" → m.top.itemSelected = {action:"episodes", ratingKey, title}
    ↓
MainScene.onItemSelected → showEpisodeScreen(ratingKey, title)
    ↓
EpisodeScreen.onRatingKeyChange → loadSeasons(ratingKey)
    ↓ [PlexApiTask: /library/metadata/{id}/children]
EpisodeScreen.processSeasons() → LabelList populated → loadEpisodes(season[0].ratingKey)
    ↓ [PlexApiTask: /library/metadata/{seasonKey}/children]
EpisodeScreen.processEpisodes() → MarkupList populated via EpisodeItem
    ↓
User selects episode → showResumeDialog (if offset > 5%) or startPlayback()
    ↓
startPlayback() → VideoPlayer appended to scene root, setFocus, control="play"
    ↓
VideoPlayer.onPlaybackComplete → EpisodeScreen.onPlaybackComplete
    ↓
EpisodeScreen: loadEpisodes(currentSeason) + emit m.global.watchStateUpdate  [NEW]
    ↓
HomeScreen.onWatchStateUpdate → scan grid ContentNode, update show's badge/progress
```

### Search Flow (after v1.1 layout fix)

```
SearchScreen pushed → keyboard visible (left), PosterGrid (right, 4 cols)
    ↓
User types → onTextChange → debounceTimer → performSearch()
    ↓ [PlexSearchTask: /hubs/search?query=...]
processSearchResults():
    - flatten hub.Metadata (filter to movies + shows only, skip episodes/artists)
    - build ContentNode, set HDPosterUrl with 240x360 portrait dimensions
    ↓
PosterGrid.content set → 4-column grid in right zone
    ↓
User presses right key:
    m.focusOnKeyboard = false
    keyboard.visible = false
    resultsGrid repositioned to full width (1760px, 6 cols)
    resultsGrid.setFocus(true)
    ↓
User selects item → m.top.itemSelected = {action:"detail"|"episodes", ratingKey, itemType}
    ↓
MainScene routes to DetailScreen or EpisodeScreen based on itemType
```

### Watch State Global Signal Flow

```
DetailScreen / EpisodeScreen (after watched toggle or playback)
    ↓
m.global.watchStateUpdate = {ratingKey, viewCount, viewOffset}
    ↓
All active observers fire simultaneously:
  - HomeScreen.onWatchStateUpdate: scan grid ContentNode children by ratingKey, update
  - EpisodeScreen.onWatchStateUpdate: scan episodeList ContentNode children by ratingKey, update
```

---

## Component Boundaries: New vs Modified for v1.1

### New Components

None required. All v1.1 features integrate into existing components.

### Modified Components

| Component | Change Type | Description | Complexity |
|-----------|------------|-------------|------------|
| `HomeScreen.brs` | Routing logic | TV show taps → `{action:"episodes"}` instead of `{action:"detail"}` | XS — 5-line change |
| `EpisodeScreen.brs` | Feature + bug fix | Watch state emission, auto-play season boundary fix, options key "Info" action | M |
| `EpisodeScreen.xml` | Layout polish | Season list spacing, episode list visual improvements | S |
| `SearchScreen.brs` | Layout + filter | Keyboard collapse on grid focus, filter episodes from results | S-M |
| `SearchScreen.xml` | Layout | Coordinate adjustments if keyboard collapse is implemented | XS |
| `PosterGridItem.brs` | Bug fix | `Int(240 * progress)` → `Int(m.constants.POSTER_WIDTH * progress)` | XS — 1-line |
| `PosterGrid.brs` | Enhancement | Read `gridWidth` field to compute column count | XS |
| `SettingsScreen.brs` | Simplification | Remove "Switch Server" discovery flow (~80 lines) | S |
| `utils.brs` | Cleanup | Promote `getRatingKeyString` → `GetRatingKeyStr`, add `UpdateServerUri` if server switching kept | S |
| `MainScene.brs` | Minor | `popScreen` type string check — verify covers all screen subtypes | XS |
| `source/normalizers.brs` | Delete | Orphaned file | — |
| `source/capabilities.brs` | Delete | Orphaned file | — |

### Not Touched in v1.1

- `VideoPlayer.xml/.brs` — Auto-play fix is a data-passing change in EpisodeScreen. VideoPlayer's `nextEpisodeStarted` field already fires; the fix is to enrich its payload.
- `PlexApiTask.brs` — No changes needed.
- `DetailScreen.xml/.brs` — Still used for movies and episode detail. No structural changes.
- `Sidebar`, `FilterBar`, `AlphaNav`, `TrackSelectionPanel` — v1.1 does not touch these.
- `PlexSessionTask`, `PlexAuthTask`, `ServerConnectionTask` — No changes.

---

## Suggested Build Order

Build in dependency order to avoid blocked work:

**1. utils.brs cleanup** (no dependencies)
- Promote `GetRatingKeyStr()` helper
- Remove dead spinner-related code from utils.brs if any

**2. Delete orphaned files** (no dependencies)
- Remove `normalizers.brs`, `capabilities.brs`

**3. PosterGridItem progress bar bug fix** (no dependencies)
- One-line change — do early to avoid merge conflicts

**4. SettingsScreen server switching removal** (no dependencies)
- Isolated change — remove "Switch Server" and discovery logic from SettingsScreen

**5. Watch state propagation fix in EpisodeScreen** (depends on: utils.brs cleanup)
- Add `m.global.watchStateUpdate` emission after playback and watched state toggle
- HomeScreen already has the observer in place — this just wires the source

**6. TV show direct navigation — HomeScreen tap routing** (depends on: watch state fix)
- Change show tap from `{action:"detail"}` to `{action:"episodes"}`
- Watch state must be in place so HomeScreen updates properly when EpisodeScreen pops

**7. EpisodeScreen overhaul** (depends on: direct navigation in place)
- Layout improvements, "Info" options key action, auto-play season fix
- Do after direct navigation so EpisodeScreen is being actively exercised as the entry point

**8. Search layout fix** (independent — can be done at any point after utils.brs)
- Keyboard collapse, column count fix, episode type filtering

**9. Branding / assets** (independent — no code dependencies)
- Icon/splash gradient, font changes, manifest version bump

**10. Documentation** (do last — after code is stable)
- User guide and developer/architecture docs for GitHub publish

---

## Anti-Patterns to Avoid in v1.1

### Anti-Pattern 1: Replacing MarkupList with Custom Scrolling

**What people do:** Build a custom scrollable container because MarkupList "feels limiting."
**Why it's wrong:** Custom scrolling on Roku's render thread is jittery and brittle. BusySpinner proved that deviating from built-in components causes firmware crashes (SIGSEGV).
**Do this instead:** Use `MarkupList` for episodes, `MarkupGrid` for grids. Customize via `itemComponentName`.

### Anti-Pattern 2: Moving HTTP Calls to the Render Thread

**What people do:** Call `roUrlTransfer` synchronously in a BRS callback to "simplify" code.
**Why it's wrong:** Causes rendezvous crashes. This is a hard platform constraint.
**Do this instead:** Always use a Task node. PlexApiTask handles all cases.

### Anti-Pattern 3: Proliferating m.global Signals

**What people do:** Add new global signals for every cross-screen communication need (e.g., `m.global.episodeWatched`, `m.global.seasonChanged`).
**Why it's wrong:** Global signals fire on all screens simultaneously, including hidden/stale screens still in the stack. Too many global observers create performance issues and debugging nightmares.
**Do this instead:** Use the existing `watchStateUpdate` signal for watch state. For other coordination, pass data via screen interface fields before navigation.

### Anti-Pattern 4: Rebuilding ContentNode Tree on Every Watch State Change

**What people do:** On `onWatchStateUpdate`, call the API to re-fetch the library page and rebuild the entire grid ContentNode.
**Why it's wrong:** Network round-trip + full grid flash. Destroys the "instant feedback" feel.
**Do this instead:** Scan children by `ratingKey`, mutate only the matching child's fields in-place. MarkupGrid re-renders only the changed item. This is the existing pattern — keep it.

---

## Integration Points

### External Service: Plex Media Server

| Endpoint | Used By | Notes |
|----------|---------|-------|
| `/library/metadata/{id}` | DetailScreen | Movie/episode/show metadata |
| `/library/metadata/{id}/children` | EpisodeScreen | Seasons (children of show), episodes (children of season) |
| `/hubs/search?query=` | SearchScreen | Returns Hub array — flatten Metadata for grid |
| `/:/scrobble`, `/:/unscrobble` | DetailScreen, EpisodeScreen | Watched state toggle; fire-and-forget |
| `plex.tv/api/v2/resources` | MainScene, SettingsScreen | Server discovery — remove from SettingsScreen in v1.1 |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Screen → MainScene (navigate forward) | `m.top.itemSelected = {action, ratingKey, ...}` | Standard pattern, stable |
| Screen → MainScene (navigate back) | `m.top.navigateBack = true` | Standard pattern, stable |
| Screen → Screen (watch state) | `m.global.watchStateUpdate = {ratingKey, viewCount, viewOffset}` | Fires on all screens; keep payload minimal |
| Task → Screen | `task.observeField("status", "handler")` | Standard async pattern |
| SettingsScreen → MainScene (user switch) | `m.top.itemSelected = {action:"switchUser"}` | Routed via MainScene.onItemSelected |
| SettingsScreen → MainScene (auth complete) | `m.top.authComplete = true` | Triggers clearScreenStack + showHomeScreen |
| SettingsScreen → MainScene (server switch BUG) | `m.top.authComplete = true` after server test | Triggers full auth flow — this is the server-switch bug (correct behavior after fix is removal) |

---

## Sources

- Live codebase analysis: `SimPlex/components/screens/`, `SimPlex/components/widgets/`, `SimPlex/source/` — HIGH confidence
- `.planning/PROJECT.md` — v1.1 target features and known issues — HIGH confidence
- `CLAUDE.md` — architecture constraints and platform rules — HIGH confidence

---

*Architecture research for: SimPlex v1.1 Polish & Navigation*
*Researched: 2026-03-13*

# Stack Research

**Domain:** Roku BrightScript / SceneGraph channel — v1.1 Polish & Navigation milestone
**Researched:** 2026-03-13
**Confidence:** HIGH for platform findings; MEDIUM for icon dimensions (official spec page returned 403, community-verified values used)

---

## What This Document Covers

This replaces the v1.0 STACK.md. The v1.0 stack (BrighterScript 0.70.x, SceneGraph RSG 1.3, Task nodes, roRegistrySection) is fully validated and unchanged. This document covers **only delta requirements** for v1.1 features: TV show navigation overhaul, bug fixes, branding refresh, codebase cleanup, and GitHub documentation.

---

## Key Finding: Most v1.1 Work Requires No New Stack

After examining the existing codebase (`EpisodeScreen.brs`, `EpisodeScreen.xml`, `EpisodeItem.xml`, `constants.brs`, `utils.brs`, `SearchScreen.brs`, `manifest`), the v1.1 milestone is overwhelmingly a **bug fix and polish** milestone. The platform capabilities needed already exist in Roku OS and the existing codebase. The only genuine new stack items are:

1. A bundled custom TTF font for bolder title typography
2. Pre-rendered PNG image assets for gradient backgrounds and redesigned icons/splash

Everything else — auto-play Timer, watch state propagation, season progress display, search layout fixes — uses existing SceneGraph nodes and BrightScript patterns.

---

## Delta Stack for v1.1

### New Assets (Not Code Dependencies)

| Asset | Type | Dimensions / Format | Purpose | Source |
|-------|------|---------------------|---------|--------|
| InterBold.ttf OR OutfitBold.ttf | TrueType font | N/A | Heavier title/heading weight than system bold | rsms.me/inter / fonts.google.com |
| icon_focus_fhd.png (redesigned) | PNG | 540 x 405 px | Channel tile, focused state (FHD) | Designed externally, bundled in `images/` |
| icon_side_fhd.png (redesigned) | PNG | 246 x 140 px | Channel tile, side state (FHD) | Designed externally, bundled in `images/` |
| icon_focus_hd.png (redesigned) | PNG | 336 x 210 px | Channel tile, focused state (HD) | Designed externally, bundled in `images/` |
| icon_side_hd.png (redesigned) | PNG | 164 x 94 px | Channel tile, side state (HD) | Designed externally, bundled in `images/` |
| splash_fhd.jpg (redesigned) | JPG or PNG | 1920 x 1080 px | Launch splash screen | Designed externally, bundled in `images/` |
| gradient panels (optional) | PNG | Varies (1580x1080 or similar) | Background gradient overlay for screens | Designed externally, bundled in `images/` |

**No new npm packages.** **No new BrighterScript plugins.** **No new Task nodes.**

---

## Feature-by-Feature Stack Analysis

### 1. TV Show Navigation Overhaul

**Existing implementation is mostly correct.** `EpisodeScreen.xml` already uses:
- `LabelList` for horizontal season tabs (fires `itemFocused` to load episodes dynamically)
- `MarkupList` with custom `EpisodeItem` component for episode rows
- Up/down key routing between season list and episode list
- `grandparentRatingKey` / `parentRatingKey` passing into `VideoPlayer` for auto-play

**What needs fixing (BrightScript logic only, no new stack):**

| Issue | What It Is | Fix Approach |
|-------|-----------|--------------|
| Season progress display | `leafCount` and `viewedLeafCount` are returned by `/library/metadata/{id}/children` but not parsed | Read these fields in `processSeasons()` and format "S01 (6/10)" in the LabelList content |
| Auto-play countdown wiring | `onPlaybackComplete` in EpisodeScreen has a `TODO` comment; countdown never fires | Use SceneGraph `Timer` node (already in Roku OS) with a 10-second countdown overlay Group/Label |
| Watch state propagation | `m.global.watchStateUpdate` is fired from DetailScreen but HomeScreen does not observe it | Add `m.global.observeField("watchStateUpdate", ...)` in HomeScreen and refresh hub rows |

**SceneGraph `Timer` node** (for auto-play countdown):
- Built into Roku OS — zero import, zero dependency
- `timer.duration = 10`, `timer.repeat = false`, `timer.observeField("fire", "onAutoPlayTimer")`
- Already used in `SearchScreen.brs` for debounce — proven pattern in this codebase

### 2. Bug Fixes

All bugs are BrightScript/XML logic errors. No new stack for any of them:

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Collections navigation | Likely ratingKey type coercion or missing `type = "collection"` check | BrightScript fix in collection item handler |
| Search result layout | `EpisodeItem`-style component assumes 2:3 portrait ratio for all results; episode results are 16:9 | Branch on `type` field in search result item renderer; apply correct `width`/`height` to `BuildPosterUrl()` |
| Thumbnail aspect ratios | Same root cause as search layout | Correct dimensions per content type: movie=240x360, episode=320x180, show=240x360 |
| Auto-play wiring gap | `onPlaybackComplete` missing countdown implementation (confirmed by `TODO` comment in code) | Timer node + overlay Group (see above) |
| Watch state propagation | HomeScreen not observing `m.global.watchStateUpdate` | Single `observeField` call + refresh logic |
| Server switching | Feature is unclear/broken; PROJECT.md lists as "fix or remove" | Remove UI paths for server switching; consolidate to single-server flow (deletion task) |

### 3. App Branding

#### Custom Font (Bolder Title Weight)

Roku SceneGraph supports custom fonts via the `Font` node:

```xml
<Label id="titleLabel" translation="[80, 40]" color="0xFFFFFFFF">
    <Font uri="pkg:/fonts/InterBold.ttf" size="52" />
</Label>
```

Or in BrightScript when setting font dynamically:
```brightscript
font = CreateObject("roSGNode", "Font")
font.uri = "pkg:/fonts/InterBold.ttf"
font.size = 52
m.titleLabel.font = font
```

**Recommended font:** Inter Bold (`InterBold.ttf`)
- Open-source, SIL OFL licensed — no legal constraints
- Designed for screen legibility at small pixel densities; excellent for 10-foot TV UI
- ~300KB file size; no enforced sideload package size limit for developer channels
- Download from https://rsms.me/inter/ (variable font or static Bold weight)

**File placement:** `SimPlex/fonts/InterBold.ttf` — new `fonts/` directory at same level as `source/`, `components/`, `images/`

**bsconfig.json files array must include:** `"fonts/**/*"` (or the fonts dir will not be zipped into the package)

#### Text Stroke / Outline Effect

Roku SceneGraph `Label` nodes have **no stroke, outline, or shadow property**. This is a confirmed platform limitation — there is no workaround via Label fields.

**Standard community workaround:** Stack two Label nodes at the same position, offset the lower one by 1-2px in a dark translucent color:

```xml
<!-- Shadow/depth layer (render first, underneath) -->
<Label id="titleShadow" translation="[82, 42]" color="0x00000099" />
<!-- Primary text layer -->
<Label id="titleLabel" translation="[80, 40]" color="0xFFFFFFFF" />
```

Both labels receive the same `text` value in BrightScript. Render cost is negligible for a few title labels.

#### Gradient Backgrounds

Roku SceneGraph `Rectangle` nodes have **no gradient fill property**. This is a confirmed platform limitation — no workaround exists within SceneGraph node properties.

**Only approach:** Pre-render gradient as a PNG image and display it via a `Poster` node:

```xml
<Poster id="gradientBg" uri="pkg:/images/gradient_bg.png" width="1920" height="1080" />
```

Generate gradient PNGs using any image tool (Figma, Photoshop, ImageMagick, etc.) outside the channel. Bundle the PNG in `SimPlex/images/`. PNG supports alpha channel for partial-transparency gradient overlays.

#### Icon and Splash Screen Assets

Icons and splash are static image files referenced in `manifest`. They are replaced by designing new assets externally and overwriting the existing files. **No BrightScript or SceneGraph changes needed.**

Required dimensions (community-verified; official spec page returned HTTP 403):

| Manifest Key | Current File | Required Size | Format |
|-------------|-------------|---------------|--------|
| `mm_icon_focus_fhd` | icon_focus_fhd.png | 540 x 405 px | PNG |
| `mm_icon_side_fhd` | icon_side_fhd.png | 246 x 140 px | PNG |
| `mm_icon_focus_hd` | icon_focus_hd.png | 336 x 210 px | PNG |
| `mm_icon_side_hd` | icon_side_hd.png | 164 x 94 px | PNG |
| `splash_screen_fhd` | splash_fhd.jpg | 1920 x 1080 px | JPG or PNG |

`splash_min_time = 1500` in manifest is appropriate — no change needed.

### 4. Codebase Cleanup

Pure deletion and refactoring — no new stack:

| Task | What |
|------|------|
| Delete `normalizers.brs` | Confirmed orphaned in PROJECT.md ("Known issues") |
| Delete `capabilities.brs` | Confirmed orphaned in PROJECT.md |
| Extract `SafeStr(ratingKey)` helper to `utils.brs` | The ratingKey string coercion block appears 15+ times verbatim across EpisodeScreen, DetailScreen, etc. — consolidate |
| Remove server switching UI | Delete or simplify ServerListScreen paths |

### 5. GitHub Documentation

Plain Markdown in the repository. No documentation generator needed.

**Recommended structure:**
```
README.md                  — Project overview, screenshots, sideload how-to, feature list
docs/
  USER_GUIDE.md            — Remote control map, navigation flows, settings
  ARCHITECTURE.md          — Component map, task node pattern, screen stack, data flow
  CONTRIBUTING.md          — BrightScript style guide, how to add a screen/widget
```

No Docusaurus, MkDocs, or similar — overengineered for a personal sideloaded channel with no public API.

---

## Recommended Stack Summary (v1.1 Delta)

### New Code Dependencies: None

The BrighterScript 0.70.x + SceneGraph RSG 1.3 toolchain handles everything. No new npm packages, no new plugins, no new ropm packages.

### New File System Additions

```
SimPlex/
  fonts/                    ← NEW directory
    InterBold.ttf           ← NEW font asset
  images/
    icon_focus_fhd.png      ← REPLACE (redesigned)
    icon_side_fhd.png       ← REPLACE (redesigned)
    icon_focus_hd.png       ← REPLACE (redesigned)
    icon_side_hd.png        ← REPLACE (redesigned)
    splash_fhd.jpg          ← REPLACE (redesigned)
    gradient_bg.png         ← NEW (optional, if gradient backgrounds are used)
```

### bsconfig.json Update Required

Add `fonts/**/*` to the `files` array so the font is included in the sideload package:

```json
{
  "files": [
    "manifest",
    "source/**/*",
    "components/**/*",
    "images/**/*",
    "fonts/**/*"
  ]
}
```

---

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not |
|---------|-------------|-------------|---------|
| Bolder font | Bundle InterBold.ttf | Use `font:LargeBoldSystemFont` | System bold is visually thin at 40-52px title sizes; no weight control; cannot match brand intent |
| Text stroke | Stacked Label shadow offset | Image-based text overlay | Image overlays cannot work for dynamic text strings |
| Gradient background | Pre-rendered PNG as Poster | Rectangle gradient | Rectangle gradient not supported in Roku OS (confirmed) |
| Auto-play countdown | SceneGraph `Timer` node | New Task node | Timer fires on render thread — no async work needed; simpler |
| Season progress | Parse `leafCount`/`viewedLeafCount` from existing API response | Additional API call | Fields already present in `/children` response; zero cost |
| Documentation | Plain Markdown | Docusaurus/MkDocs | No public API surface; sideload-only personal project; Markdown is faster to write and maintain |
| Font weight | Inter Bold | Outfit Bold | Both are excellent choices; Inter has stronger screen legibility research behind it and is used by major tech products |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| BrighterScript 1.0.0-alpha | Explicitly deferred in PROJECT.md; unstable alpha with breaking changes | Stay on 0.70.x |
| Maestro MVVM | Deprecated November 2023; confirmed in v1.0 research | Plain BrightScript + SceneGraph |
| SGDEX (SceneGraph Developer Extensions) | Heavy Roku-official framework for channel-store apps; adds enormous complexity for a custom sideloaded channel | Native SceneGraph nodes |
| roFontRegistry BrightScript API | Legacy API for non-SceneGraph font registration; SceneGraph Font node is the correct approach | SceneGraph `Font` node with `uri` field |
| WebP or AVIF for icons/splash | Roku firmware manifest image rendering expects PNG/JPG for icon and splash assets | PNG for icons, JPG/PNG for splash |
| Variable font (single TTF with all weights) | Variable font support in Roku OS Font node is unverified; static weight TTF is confirmed working | Static weight TTF (e.g., InterBold.ttf, not Inter.ttf with `wght` axis) |

---

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| BrighterScript | 0.70.x | Unchanged from v1.0; confirmed stable |
| Roku OS | 11.5+ | Target per PROJECT.md; Timer, Font node, MarkupList, MarkupGrid all available since OS 9.x |
| SceneGraph | RSG 1.3 | Set in manifest; confirmed in existing channel |
| Inter font | v4.x (static Bold) | Download static Bold variant, not the variable font package |
| PNG images | Standard PNG-24/32 | Roku OS renders standard PNG; APNG animation not supported |

---

## Sources

- Roku Community — mm_icon_focus_fhd dimensions: https://community.roku.com/t5/Roku-Developer-Program/mm-icon-focus-fhd-resolution/td-p/492827 (MEDIUM confidence; official spec page returned 403; community values are consistent across multiple threads)
- Roku Developer docs — Timer node: https://developer.roku.com/docs/references/scenegraph/control-nodes/timer.md
- Roku Developer docs — Font node: https://developer.roku.com/docs/references/scenegraph/typographic-nodes/font.md
- Roku Community — Gradient Rectangle limitation: https://community.roku.com/t5/Roku-Developer-Program/Gradient-rectangle/td-p/404364 (MEDIUM confidence; multiple threads confirm no native gradient; Roku docs page returned 403)
- Roku Community — Custom TTF font usage: https://community.roku.com/t5/Roku-Developer-Program/Using-custom-fonts-ttf-files-in-XML/td-p/505688 (HIGH confidence; consistent with Font node documentation pattern)
- Roku Community — Label stroke limitation: https://community.roku.com/t5/Roku-Developer-Program/How-to-modify-System-Fonts-in-SceneGraph/td-p/466671 (MEDIUM confidence; community confirms no stroke property; stacked-label workaround is established pattern)
- Existing codebase — EpisodeScreen.brs, EpisodeScreen.xml, EpisodeItem.xml, constants.brs, utils.brs, SearchScreen.brs, manifest (HIGH confidence; direct code inspection)
- PROJECT.md — Known issues (orphaned files, auto-play gap, watch state gap) (HIGH confidence; on-disk project record)
- Inter font project — https://rsms.me/inter/ (HIGH confidence; verified open-source, SIL OFL license)

---

*Stack research for: SimPlex v1.1 Polish & Navigation (Roku BrightScript/SceneGraph channel)*
*Researched: 2026-03-13*

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

# Pitfalls Research

**Domain:** Roku/BrightScript Plex client — v1.1 Polish & Navigation milestone
**Researched:** 2026-03-13
**Confidence:** HIGH (all findings grounded in existing codebase, known firmware behavior, and Roku platform constraints)

---

## Critical Pitfalls

### Pitfall 1: EpisodeScreen Navigation Refactor Severs VideoPlayer Context Fields

**What goes wrong:**
`EpisodeScreen` already implements a combined season/episode screen. If the refactor splits it into separate Season and Episode screens pushed onto the stack, the VideoPlayer launch in `startPlayback()` stops receiving the five context fields it needs: `grandparentRatingKey`, `parentRatingKey`, `episodeIndex`, `seasonIndex`, and `mediaKey`. Auto-play next episode silently stops working — `onNextEpisodeStarted` fires but the wrong season reloads, or auto-play does nothing.

**Why it happens:**
The EpisodeScreen holds `m.seasons`, `m.currentSeasonIndex`, and `m.top.ratingKey` (the show's ratingKey) all in one component. A new SeasonScreen sitting between HomeScreen and EpisodeScreen would own the season array but not the episode list, creating a boundary that severs the season-to-VideoPlayer context chain. The existing `startPlayback()` at EpisodeScreen.brs line 408 depends on `m.seasons` and `m.currentSeasonIndex` being in scope.

**How to avoid:**
Audit whether three separate screens are necessary before committing to the structure. If EpisodeScreen can be enhanced in-place (larger season list, season artwork column), prefer that over splitting. If splitting is required, the screen that launches the VideoPlayer must own or receive all five context fields. After refactoring, run a focused test: play episode from season 2, let auto-play fire, verify it advances within season 2 and not season 1.

**Warning signs:**
- Auto-play next episode fires but jumps back to season 1 episode 1
- `VideoPlayer.grandparentRatingKey` is `""` or `"0"` after the refactor
- `nextEpisodeStarted` event fires but `loadEpisodes` reloads the wrong season

**Phase to address:** TV Show Navigation Overhaul

---

### Pitfall 2: Focus Recovery After VideoPlayer Closure Breaks Under Navigation Refactor

**What goes wrong:**
`VideoPlayer` is appended directly to the scene root (`m.top.getScene().appendChild(m.player)`) — it bypasses the `pushScreen`/`popScreen` focus stack entirely. After playback, `onPlaybackComplete` calls `m.episodeList.setFocus(true)`. If a SeasonScreen is added as a proper stack entry and EpisodeScreen is popped before VideoPlayer completes, then `m.episodeList` is already removed from the scene when the callback fires. `setFocus(true)` on a detached node is a silent no-op — the user has no focus.

**Why it happens:**
The VideoPlayer lifecycle is outside the screen stack. Any navigation refactor that changes which screen owns the episode list invalidates the hardcoded focus restore target in `onPlaybackComplete`.

**How to avoid:**
Keep the VideoPlayer lifecycle independent of the screen stack (append to scene root, remove on complete). After playback, focus must be restored to whatever the current top-of-stack screen considers its "default focus target" via `getCurrentScreen().setFocus(true)`, not to a specific node that may no longer be in scope. Alternatively, have each screen implement a `restoreFocus()` callFunc that MainScene invokes after VideoPlayer removes itself.

**Warning signs:**
- Back button after playback does nothing (no focused component)
- Remote buttons unresponsive after returning from video
- Debug console shows focus set to a node that returns `invalid` from `findNode`

**Phase to address:** TV Show Navigation Overhaul

---

### Pitfall 3: Watch State Propagation Does Not Reach Hub Rows

**What goes wrong:**
`m.global.watchStateUpdate` propagates from DetailScreen. `HomeScreen.onWatchStateUpdate` exists but only patches the poster grid ContentNodes. Hub row ContentNodes (the RowList populated by `loadHubs`) are a separate ContentNode tree and are not walked by the current handler. After marking an episode watched in DetailScreen and returning to HomeScreen, "Continue Watching" still shows the episode and the progress bar is still visible on its hub row poster.

**Why it happens:**
Hub rows are loaded into a dynamically-created RowList whose content is built in `processHubs()`. The poster grid and the hub RowList are two separate ContentNode trees. `onWatchStateUpdate` was written to patch the poster grid. Extending it to walk the hub RowList requires iterating `m.hubRowList.content` children and their children, which is a different tree shape.

**How to avoid:**
Fix watch state propagation before adding more navigation depth. The hub row walker needs to: (1) iterate each hub row ContentNode, (2) for each row, iterate its child ContentNodes, (3) match on `ratingKey`, (4) update `viewCount`, `viewOffset`, and `watched` fields. Add a test: mark watched in Detail; return to Home; "Continue Watching" hub must not show that item (either removed or shows watched badge).

**Warning signs:**
- "Continue Watching" shows a just-finished episode
- Progress bar persists on hub row poster after watching from Detail
- On Deck shows an episode that was marked watched

**Phase to address:** Bug Fixes — Watch State Propagation

---

### Pitfall 4: Collections Handler Dispatch Mismatch Sends Users to Wrong Screen

**What goes wrong:**
When a collection is selected from the poster grid, `HomeScreen.onGridItemSelected` fires. If `itemType` is `"collection"`, MainScene routes it to `showDetailScreen`. DetailScreen's `buildButtons()` only explicitly handles `item.type = "show"` — everything else falls to the movie/episode branch which shows "Play" (not "Browse Collection"). Collections are not playable; pressing "Play" on a collection causes an error or sends `mediaKey` for a collection ratingKey to VideoPlayer, which fails.

**Why it happens:**
The Plex API returns `type: "collection"` for collection items, but `buildButtons()` in DetailScreen has no branch for it. The `browseSeasons` action path only fires for `type = "show"`. There is no `browseCollection` action defined in either DetailScreen or MainScene.

**How to avoid:**
Add an explicit `type = "collection"` branch in `buildButtons()` showing a "Browse Collection" button with `action: "browseCollection"`. Add a handler in MainScene `onItemSelected` for `action: "browseCollection"` that calls `showHomeScreen()` in collection mode by passing `collectionRatingKey`. HomeScreen already has `m.isCollectionsView` and `m.collectionRatingKey` — wire them from the navigation action. Verify the full loop: Home → collection item → Detail → "Browse Collection" → collection contents → item Detail.

**Warning signs:**
- Selecting a collection shows "Play" as the only action button
- "Play" on a collection causes a VideoPlayer error
- `isCollectionsView` never evaluates to `true` via navigation

**Phase to address:** Bug Fixes — Collections Handler

---

### Pitfall 5: Search Grid Shows Stretched Episode Thumbnails Alongside Portrait Posters

**What goes wrong:**
Search results mix movies (2:3 portrait), TV shows (2:3 portrait), and episodes (16:9 landscape) in a single MarkupGrid with `itemSize: [240, 360]`. Episode `thumb` values are built with `BuildPosterUrl(item.thumb, 320, 180)` in `processSearchResults()` but assigned to `HDPosterUrl` on a 240x360 cell. The Roku image scaler stretches the 16:9 thumbnail to fill the 2:3 cell, producing distorted episode thumbnails.

**Why it happens:**
`processSearchResults()` in SearchScreen.brs line 149 builds all posters with `c.POSTER_WIDTH, c.POSTER_HEIGHT` (240x360) regardless of item type. Episode thumbnails are inherently landscape. The grid itemSize assumes portrait.

**How to avoid:**
For search result items where `item.type = "episode"`, use `item.parentThumb` (the parent show's poster, portrait art) instead of `item.thumb`. If `parentThumb` is absent, fall back to `thumb` at portrait dimensions and accept letterboxing. The Plex API search response always includes `parentThumb` for episode results — use `hub.Metadata[i].parentThumb`. This eliminates the ratio mismatch without changing grid layout.

**Warning signs:**
- Episode results in search appear taller than wide but distorted
- Movie and show results look correct but episode results look squashed
- Different item rows in the search grid have visually inconsistent poster sizes

**Phase to address:** Bug Fixes — Search Layout

---

### Pitfall 6: Deleting Orphaned BRS Files Crashes the Channel If Any XML Still References Them

**What goes wrong:**
Deleting `normalizers.brs` or `capabilities.brs` (documented orphans in PROJECT.md) causes a black screen on next launch if any `.xml` component still has `<script type="text/brightscript" uri="pkg:/source/normalizers.brs" />`. BrightScript compile errors on Roku do not produce a BrightScript stack trace — the channel simply fails to start with "compile error: file not found" in the debug console.

**Why it happens:**
SceneGraph XML components reference `.brs` source files via `<script>` tags. These are checked at compile time. Removing a file without removing all its XML references is a hard compile failure. The error is easy to miss if the developer does not check the debug console after the sideload.

**How to avoid:**
Before deleting any `.brs` file: (1) search all `.xml` files for the filename, (2) search all `.brs` files for any function names defined in the target file. Delete only after confirming zero references. After deletion, do a full sideload and check the debug console on port 8085 for compile errors before proceeding. Treat each file deletion as a separate deploy-test cycle.

**Warning signs:**
- Channel shows black screen immediately on launch after cleanup
- Debug console (port 8085) shows "compile error" or "file not found"
- No BrightScript error — pure compilation failure

**Phase to address:** Codebase Cleanup

---

### Pitfall 7: Removing Server Switching Requires Touching Four Codepaths Simultaneously

**What goes wrong:**
Server switching logic is distributed across four places: (1) `MainScene.navigateToServerList()` called from the disconnect dialog, (2) `onDisconnectDialogButton` index 1 routing, (3) `onPINScreenState` in MainScene when `servers.count() > 1` (after initial auth), (4) `PINScreen.brs` own post-auth routing. If server switching is removed by deleting `ServerListScreen` without patching all four paths, any path that previously routed to `ServerListScreen` either crashes (calls a missing `showServerListScreen` sub) or silently fails to navigate.

**Why it happens:**
There is no single "server switching module." The logic is woven into auth flow, disconnect recovery, and PINScreen state management. It looks removable by deleting the screen, but the call sites remain.

**How to avoid:**
Removal sequence: (1) patch `onPINScreenState` to auto-connect to `servers[0]` regardless of count (log a warning if count > 1 but proceed), (2) replace the "Server List" button in the disconnect dialog with "Sign Out" or remove it, (3) delete `showServerListScreen` and `navigateToServerList` subs, (4) delete `ServerListScreen.xml/.brs`. Only delete the screen after all call sites are patched. Do a full auth flow test with a plex.tv account that has two registered servers.

**Warning signs:**
- Auth flow crashes immediately after authenticating with a multi-server plex.tv account
- "Server List" button in disconnect dialog routes to blank screen
- `showServerListScreen` call appears in a file after the sub is deleted

**Phase to address:** Server Switching — Fix or Remove

---

### Pitfall 8: BusySpinner SIGSEGV Root Cause Is Still Unconfirmed

**What goes wrong:**
The UAT debug context documents an active firmware crash: `BusySpinner` (or its associated fade animations) causes SIGSEGV signal 11 on the test Roku. All production screens already have `m.loadingSpinner = invalid` with comments. However, `LoadingSpinner.xml/.brs` still exists. TEST4b (fade animations, no spinner) was pending at the time of the v1.0 close. If either BusySpinner or animated Group nodes are re-added to any v1.1 screen without resolving the root cause, that screen will SIGSEGV within 3-5 seconds of init.

**Why it happens:**
Roku firmware has known stability issues with `BusySpinner` on certain firmware versions and with animated SceneGraph Group nodes that use `Animation` nodes containing `Vector2DFieldInterpolator`. The exact trigger is not yet pinned.

**How to avoid:**
Do not add `BusySpinner` or `Animation` nodes to any screen in v1.1 until the root cause is confirmed. For loading feedback, use a static `Label` with text toggled visible/invisible — zero crash risk. If animation is desired, use a `Timer` node that cycles a label through "Loading.", "Loading..", "Loading..." text states. The crash is blocking and must be resolved in the first v1.1 phase before any other screen work.

**Warning signs:**
- SIGSEGV signal 11 in debug console (not a BrightScript error — native firmware crash)
- Crash occurs 3-5 seconds after screen init, not immediately
- Crash does not produce a BrightScript stack trace; channel silently exits

**Phase to address:** Must be resolved in Phase 1 before all other screen work

---

### Pitfall 9: Auto-Play Wiring Gap Remains in DetailScreen Even Though EpisodeScreen Was Fixed

**What goes wrong:**
PROJECT.md documents the auto-play gap as a known issue. Checking the code: `EpisodeScreen.startPlayback()` now sets all five VideoPlayer context fields (line 416–432, fix already present). However, `DetailScreen.startPlayback()` sets only `ratingKey`, `mediaKey`, `startOffset`, and `itemTitle`. When an episode is played from DetailScreen (e.g., via "Go to Details" from EpisodeScreen's resume dialog, or via direct DetailScreen navigation for an episode ratingKey), VideoPlayer receives no `grandparentRatingKey` and auto-play cannot find the next episode.

**Why it happens:**
DetailScreen handles both movies and episodes with the same `startPlayback()` sub. Movies don't need parent/grandparent context. The episode-specific context was never added to DetailScreen, only to EpisodeScreen.

**How to avoid:**
In `DetailScreen.startPlayback()`, check `m.itemData.type`. If `"episode"`, populate `grandparentRatingKey` from `m.itemData.grandparentRatingKey`, `parentRatingKey` from `m.itemData.parentRatingKey`, `episodeIndex` from `m.itemData.index`, and `seasonIndex` by fetching the season's index from `m.itemData.parentIndex`. The metadata response already includes these fields — they just need to be passed forward. Verify by playing an episode from DetailScreen and checking that auto-play advances correctly.

**Warning signs:**
- Auto-play works when playing from EpisodeScreen but not from DetailScreen
- `onNextEpisodeStarted` never fires after playing from DetailScreen
- VideoPlayer `grandparentRatingKey` field is `""` when launched from Detail

**Phase to address:** Bug Fixes — Auto-Play Wiring

---

### Pitfall 10: Icon/Splash Branding Requires All Four Variants Updated Simultaneously

**What goes wrong:**
The manifest references four icon files: `icon_focus_fhd.png` (540x405), `icon_side_fhd.png` (248x140), `icon_focus_hd.png` (336x240), `icon_side_hd.png` (210x120). The splash is `splash_fhd.jpg` (must be exactly 1920x1080). If only the FHD variants are updated and the HD variants are left unchanged, the Roku home screen shows mismatched branding — old icon on HD-resolution Roku devices, new icon on FHD. Even for a sideloaded channel, the home screen pulls the appropriate resolution variant automatically.

**Why it happens:**
FHD is the target development resolution so FHD icons are naturally updated first. HD variants are easy to forget because no dev testing is done on HD displays. The Roku firmware silently falls back to HD icons when FHD is not found — or vice versa — making the mismatch non-obvious until tested on a different device.

**How to avoid:**
Export all four icon sizes from the same source file in a single pass every time branding changes. Use a single Figma/Sketch/Inkscape source file with named export presets for all four sizes. Splash must be exactly 1920x1080 JPEG — verify pixel dimensions before sideloading. After any branding change, test on the actual Roku device and view the home screen channel tile.

**Warning signs:**
- Channel icon looks different on the test TV vs. another Roku in the house
- Icon appears blurry or wrong aspect ratio on the Roku home screen tile
- Splash shows black bars, crops, or stretching artifacts on first load

**Phase to address:** App Branding

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `ratingKey` type-coercion repeated in every screen (6+ identical blocks) | Defensive; works regardless of API return type | Any change to the pattern requires 6+ edits; `getRatingKeyString()` already exists in `DetailScreen.brs` but is not shared | Extract to `utils.brs` — one refactor, done |
| Duplicate `showErrorDialog`/`showInlineRetry` in every screen | Each screen self-contained | Same ~40-line block in 6+ screens; fixing a dialog bug requires 6 changes | Acceptable for v1.1; extract to shared utility in v1.2 |
| `BuildPosterUrl` reads registry on every call | No setup needed | 2 registry reads per image URL; on a 300-item grid that's 600 registry reads per load | Cache `serverUri` and `authToken` at screen init; pass as parameters |
| Task nodes created but never explicitly released | Simple; Roku handles GC | Task node count grows during paginated browsing; potential memory pressure on low-RAM devices (Roku Express: 256MB) | Acceptable for short-lived tasks; add explicit cleanup for pagination tasks |
| `m.global.watchStateUpdate` as a single shared event | Simple propagation | Does not reach hub row ContentNode trees; any observer fires on every update regardless of relevance | Fix hub row coverage before adding more navigation depth |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Plex API — Collections | Routing `type: "collection"` to DetailScreen and expecting play buttons | Add explicit `type = "collection"` branch in `buildButtons()`; show "Browse Collection" routed to collection contents endpoint |
| Plex API — Search results | Using `item.thumb` for episodes produces 16:9 thumbnails in a 2:3 grid | Use `item.parentThumb` for `type: "episode"` search results to get the parent show's portrait poster |
| Plex API — Episode metadata | Assuming `grandparentRatingKey` is always present | Check for `invalid` before use; some library configurations omit it. Fall back to re-fetching the show via `/library/metadata/{parentRatingKey}` |
| Roku manifest — Icon filenames | Renaming icon files without updating manifest paths | Manifest hardcodes exact filenames; always update manifest and image file together |
| roRegistrySection — Sign-out gaps | `ClearAuthData()` deletes a fixed list of keys; new keys added in v1.1 are not in that list | Maintain a canonical key list or use `deleteSection()` as the nuclear option |
| GitHub publish — HAR files | `plex.owlfarm.ad.har` is in the untracked files list; HAR files contain full HTTP sessions including auth tokens | Add `*.har` to `.gitignore` before first push; never commit HAR files |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Season navigation fires `loadEpisodes` on every focus event | Network spam when arrowing through seasons; brief grid flicker | Guard exists (`index <> m.currentSeasonIndex`) — do not remove this guard during refactor | With 10+ seasons and rapid navigation, 10+ in-flight requests stack up |
| `m.episodeList.content = m.episodeList.content` to force re-render | Visible flash on episode list update for watched state toggle | Update individual ContentNode child directly; MarkupList observes child field changes | Visible flash on 20+ episode lists; cascades if called multiple times |
| `BuildPosterUrl` reads registry per call | Slow grid initial load; noticeable on Roku Express | Cache `serverUri` and `authToken` in `m` at screen init | Noticeable on grids > 100 items on devices with slow flash storage |
| Observer accumulation on global fields | Callbacks fire for all screens in stack, not just the top screen | Unobserve global fields when screen is hidden; re-observe when focused | Hard to detect; symptom is multiple screens updating on a single watchStateUpdate |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Auth token visible in poster image URLs in debug logs | If anyone reads the Roku debug console output (port 8085), auth tokens in poster URLs expose credentials | Never log full `BuildPosterUrl` results; log only the path without query string |
| `LogEvent` calls left in production code | Auth headers and server URIs may appear in debug logs accessible to anyone on the local network | Audit all `LogEvent` calls before GitHub publish; remove or conditionalize verbose logging |
| `plex.owlfarm.ad.har` committed to GitHub | HAR files contain full HTTP request/response logs including X-Plex-Token values for every request captured during the session | Add `*.har` to `.gitignore` immediately; if already tracked, use `git rm --cached` |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Season list shows only one horizontal row (LabelList `numRows="1"`) | For shows with 10+ seasons, user must scroll horizontally with no count indicator | Add season count label; consider showing all seasons in a scrollable list with the count visible |
| Auto-play countdown fires while user is actively browsing episode list | User is startled by sudden playback beginning while navigating | Auto-play countdown must cancel immediately on any key press or focus move to episode list |
| "Mark as Watched" optimistic update allows double-tap race condition | Two toggles in flight produce final state opposite of intent | Disable button (or set flag) during in-flight API call; re-enable in `onWatchedStateChange` |
| Episode thumbnails in search (16:9) distort the grid layout | Visual inconsistency makes search results look broken for TV shows | Use `parentThumb` for episode search results — portrait poster gives consistent grid |

---

## "Looks Done But Isn't" Checklist

- [ ] **TV show navigation:** Episode playback from BOTH `EpisodeScreen` AND `DetailScreen` passes all five VideoPlayer context fields — `grandparentRatingKey`, `parentRatingKey`, `episodeIndex`, `seasonIndex` are non-empty for every episode play path
- [ ] **Auto-play next episode:** Works correctly after playing from EpisodeScreen; also works after playing from DetailScreen via "Go to Details" path
- [ ] **Collections fix:** Selecting a collection from BOTH HomeScreen poster grid AND SearchScreen routes to collection contents — verify both entry points
- [ ] **Watch state propagation:** Mark watched in DetailScreen; return to HomeScreen; "Continue Watching" hub row must not show that item (hub row ContentNodes must be walked, not just the poster grid)
- [ ] **Server switching removal:** Full auth flow tested with a plex.tv account that has multiple servers registered — flow completes without crash or hang
- [ ] **BusySpinner crash:** Root cause confirmed (BusySpinner vs. Animation nodes); any new screens in v1.1 use safe loading feedback pattern (Label toggle, not BusySpinner)
- [ ] **Branding update:** All four icon variants updated and verified on actual Roku hardware home screen; splash exactly 1920x1080
- [ ] **File deletion cleanup:** Full sideload test after EACH file deletion; debug console checked for compile errors before proceeding to next deletion
- [ ] **GitHub publish:** `*.har` in `.gitignore`; no auth tokens in any committed file; `LogEvent` calls audited for credential leakage

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Broken `<script>` reference after file deletion | LOW | Re-add deleted file or remove XML reference; sideload to confirm; re-delete correctly |
| Focus permanently lost after navigation refactor | MEDIUM | Add `LogEvent` to all `onFocusChange` observers; trace focus chain; revert last focus-related change; re-apply incrementally |
| Auto-play broken by navigation refactor | MEDIUM | Log all VideoPlayer fields at `control = "play"` time; compare pre/post refactor to identify which context field is now missing |
| SIGSEGV from adding new component | HIGH | Revert to last known-good state; use bisection pattern from UAT debug context (TEST1→TEST2→etc.); test one new SceneGraph node type at a time |
| Collections dispatch loop | LOW | Add `LogEvent` to `onItemSelected` in MainScene; log `data.action` and `data.itemType` for every selection; trace the full dispatch chain |
| HAR file accidentally committed | HIGH | Before repo is public: `git filter-repo` to remove from history; rotate exposed auth token via plex.tv account settings immediately |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| VideoPlayer context severed by navigation refactor | TV Show Navigation Overhaul | Auto-play fires correctly from all episode play entry points |
| Focus lost after playback closure | TV Show Navigation Overhaul | Back from player restores focus to last-focused episode; remote buttons respond |
| Watch state not propagating to hub rows | Bug Fixes — Watch State | Mark watched in Detail; "Continue Watching" hub row removes item on return to Home |
| Collections handler dispatch mismatch | Bug Fixes — Collections | Collections accessible from both HomeScreen grid and SearchScreen |
| Search grid mixed aspect ratios | Bug Fixes — Search Layout | Episode results in search show portrait posters, not stretched thumbnails |
| Orphaned file deletion crashes compile | Codebase Cleanup | Sideload test after each deletion; zero compile errors in debug console |
| Server switching partial removal | Server Switching Phase | Full auth flow with multi-server account completes without crash |
| Icon/splash variant mismatch | App Branding | All four icon variants visually correct on actual Roku home screen |
| BusySpinner SIGSEGV unresolved | Phase 1 — must precede all other work | 10-minute session with no SIGSEGV in any screen |
| Auto-play gap in DetailScreen | Bug Fixes — Auto-Play | Episode played from DetailScreen auto-plays next episode correctly |
| HAR file in repo | Documentation / GitHub Phase | `*.har` in `.gitignore`; `git status` shows no HAR files tracked |

---

## Sources

- Direct codebase analysis: `EpisodeScreen.brs`, `DetailScreen.brs`, `MainScene.brs`, `SearchScreen.brs`, `VideoPlayer.brs`, `utils.brs`, `constants.brs`, `HomeScreen.brs`, `PosterGrid.brs`, all `.xml` layouts
- `.planning/PROJECT.md` — documented known gaps (auto-play wiring, watch state propagation, orphaned files, collections bug)
- `.planning/UAT-DEBUG-CONTEXT.md` — BusySpinner SIGSEGV active investigation, bisection results (TEST4b pending), crash characteristics
- Roku SceneGraph documentation — focus chain behavior, `BusySpinner` instability notes, `Animation` node constraints
- Plex API field reference — `parentThumb` vs. `thumb` for search results, collection endpoint structure, episode metadata fields

---
*Pitfalls research for: SimPlex v1.1 Polish & Navigation — Roku/BrightScript Plex client*
*Researched: 2026-03-13*