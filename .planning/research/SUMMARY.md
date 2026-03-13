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
