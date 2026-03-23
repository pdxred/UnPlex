# M001 State & Memory Assessment

**Assessed:** 2026-03-22
**Scope:** All GSD state files, DECISIONS.md, PROJECT.md, REQUIREMENTS.md, .planning codebase docs, CLAUDE.md — cross-referenced against actual codebase
**Method:** Exhaustive grep/read of every source file against every claim in memory

---

## Executive Summary

The GSD memory files are **broadly accurate** for the work completed in S11–S12 but contain **17 discrete issues** ranging from stale claims about already-fixed bugs to incorrect constant values in CLAUDE.md. The `.planning/codebase/` docs (CONCERNS.md, ARCHITECTURE.md) are the most stale — written pre-S11 and never updated after the crash fix, auto-play fix, and watch state propagation work. PROJECT.md has 3 stale claims. CLAUDE.md has 3 incorrect constant values. There are also 3 real code issues in "finished" areas that need attention.

---

## Category A: Stale Memory — Claims About Problems That Are Already Fixed

These exist in `.planning/codebase/CONCERNS.md` and `PROJECT.md`. They describe bugs that S11 and S12 resolved but the docs were never updated.

### A1. CONCERNS.md: "Auto-Play Next Episode Not Wired" — STALE
**Claim:** EpisodeScreen and DetailScreen never set `parentRatingKey` and `grandparentRatingKey` on VideoPlayer.
**Reality:** DetailScreen.brs lines 291–298 now correctly set all three fields. S12 fixed this (commit `549da99`). FIX-01 is validated.

### A2. CONCERNS.md: "Watch State Not Propagated to Parent Screens" — STALE
**Claim:** DetailScreen `watchStateChanged` field is never observed by parent screens.
**Reality:** VideoPlayer now emits `m.global.watchStateUpdate` from `scrobble()` (line 535) and `signalPlaybackComplete()` (line 583). HomeScreen observes this at line 42 and walks both hub rows and poster grid. FIX-03 is validated.

### A3. CONCERNS.md: "Orphaned Code — normalizers.brs, capabilities.brs" — STALE
**Claim:** Files exist and are unused.
**Reality:** Both files were deleted in S11 (commit `03e9534`). SAFE-02 is validated.

### A4. CONCERNS.md: "SIGSEGV Firmware Crash" — STALE (partially)
**Claim:** Describes BusySpinner crash as an open investigation with TEST4b pending.
**Reality:** S11 confirmed root cause (BusySpinner-specific, not Animation nodes), replaced with safe LoadingSpinner, and documented the fix. SAFE-01 is validated. The description of `m.loadingSpinner = invalid` guards is also stale — screens now use a real LoadingSpinner widget with `showSpinner` field.

### A5. CONCERNS.md: "No Auto-Play Next Testing" — STALE
**Claim:** "Countdown appears at 90% of episode duration."
**Reality:** Threshold was changed to last 30 seconds (`m.duration - 30000`) in S12. Three occurrences in VideoPlayer.brs (lines 1004, 1185, 1341) all use the 30-second threshold. No 90% reference remains in code.

### A6. PROJECT.md: "Known issues: auto-play next episode has a wiring gap" — STALE
**Claim:** `grandparentRatingKey` not passed, `watchStateChanged` doesn't propagate.
**Reality:** Both fixed in S12. The "Known issues" sentence should be removed or updated.

### A7. PROJECT.md: "Orphaned files: normalizers.brs, capabilities.brs (unused functions)" — STALE
**Claim:** Files exist.
**Reality:** Deleted in S11.

### A8. PROJECT.md: "90% duration fallback for auto-play" in Key Decisions table — STALE
**Claim:** Decision rationale says "90% duration fallback."
**Reality:** Changed to 30-second fixed threshold in S12. The decision table should reflect the current threshold.

---

## Category B: Incorrect Constants in CLAUDE.md

CLAUDE.md is the primary instruction file for future agents. These errors will cause any agent writing new code to use wrong values.

### B1. SIDEBAR_WIDTH: 280 → actual: 340
**CLAUDE.md says:** `SIDEBAR_WIDTH: 280`
**constants.brs says:** `SIDEBAR_WIDTH: 340`
**Evidence:** HomeScreen.xml `contentArea` translation is `[340, 0]`. SidebarNavItem uses `width="340"`. The 280 appears only as the inner text label width within SidebarNavItem.

### B2. BG_PRIMARY: "0x1A1A2EFF" → actual: "0x000000FF"
**CLAUDE.md says:** `BG_PRIMARY: "0x1A1A2EFF"` (dark navy blue)
**constants.brs says:** `BG_PRIMARY: "0x000000FF"` (pure black)
**Evidence:** Only one file still references `0x1A1A2E` — `LibrarySettingItem.xml` — as a local item color, not the global BG_PRIMARY.

### B3. ACCENT: "0xE5A00DFF" → actual: "0xF3B125FF"
**CLAUDE.md says:** `ACCENT: "0xE5A00DFF"` (deeper gold)
**constants.brs says:** `ACCENT: "0xF3B125FF"` (lighter gold)
**Evidence:** 5 files still use the old `0xE5A00D` value inline (EpisodeScreen.xml, SettingsScreen.brs, LibrarySettingItem.xml). The constant is `0xF3B125FF`. This is a real inconsistency — some files use the old color, some use the constant.

---

## Category C: Real Code Issues in "Finished" Areas

These are bugs or gaps in code that S11/S12 claimed to have completed, or code areas that the validated requirements imply are done.

### C1. HomeScreen.startPlaybackFromGrid() — missing auto-play wiring
**Location:** HomeScreen.brs lines 1085–1096
**Issue:** When HomeScreen launches playback directly (resume from hub row), it creates a VideoPlayer and observes `playbackComplete` (old boolean), NOT `playbackResult` (new structured field). It also doesn't set `grandparentRatingKey`, `parentRatingKey`, or `episodeIndex`. This means:
- Auto-play will not trigger for episodes resumed from HomeScreen hub rows
- PostPlayScreen will not appear after playback from HomeScreen
- The old `playbackComplete` boolean path is used instead of the new `playbackResult` pattern
**Severity:** Medium — this is the same class of bug that FIX-01 was supposed to fix, but the HomeScreen playback path wasn't included in S12's scope.
**DECISIONS.md note:** "playbackComplete boolean kept in VideoPlayer.xml — HomeScreen and PlaylistScreen still reference it" — this is correctly documented but the inconsistency exists.

### C2. PlaylistScreen — uses old playbackComplete, no PostPlayScreen
**Location:** PlaylistScreen.brs line 206
**Issue:** Same pattern as C1. PlaylistScreen observes `playbackComplete`, not `playbackResult`. No PostPlayScreen integration. This is documented in DECISIONS.md as intentional scope exclusion but creates an inconsistent user experience.
**Severity:** Low — documented as deferred, but worth noting.

### C3. Sidebar.xml hardcodes itemSize `[280, 76]` instead of using constant
**Location:** Sidebar.xml line 32
**Issue:** XML attributes can't use BrightScript constants, but Sidebar.brs line 14 sets `m.navList.itemSize = [c.SIDEBAR_WIDTH, 76]` at runtime. The XML value `280` and the runtime value `340` disagree. The runtime value wins (BrightScript overrides XML defaults), so the visual is correct, but the XML is misleading.
**Severity:** Low — cosmetic inconsistency in source.

### C4. Inline accent color inconsistency
**Location:** EpisodeScreen.xml:41, SettingsScreen.brs:240, LibrarySettingItem.xml (3 occurrences)
**Issue:** 5 locations use `0xE5A00D` (old accent) while the constant `ACCENT` is `0xF3B125FF`. These components don't read from the constant — they use hardcoded hex values.
**Severity:** Low — subtle color difference (both are gold), but creates visual inconsistency if the accent is ever changed.

---

## Category D: .gitignore Gap — Security Concern

### D1. HAR file not gitignored
**Location:** `.gitignore` — no `*.har` entry
**Issue:** `plex.owlfarm.ad.har` (17 MB) sits in the project root, untracked but not gitignored. This file contains live Plex auth tokens and server connection details. A careless `git add .` would expose credentials. DOCS-03 requirement ("exclude HAR files, credentials, build artifacts") is marked `active` — this hasn't been done yet.
**Severity:** High — security risk if accidentally committed before the GitHub publish in S17.

---

## Category E: LOC Count Drift

### E1. PROJECT.md LOC count is stale
**Claim:** "11,158 LOC across BrightScript and SceneGraph XML"
**Actual:** 11,385 LOC (measured now). S11 and S12 added PostPlayScreen (2 files), modified 19 files, deleted 2 files, net +227 LOC.
**Severity:** Cosmetic.

---

## Category F: Upstream Research Findings

### F1. RSG 1.3 migration deadline
<cite index="3-7">Starting October 1, 2026, all apps must declare support for RSG 1.3 in the manifest to pass certification testing.</cite> The manifest already has `rsg_version=1.3`, so SimPlex is compliant. However, the new RSG 1.3 data transfer APIs (move vs copy for AA fields, reference access on render thread) are not used anywhere in the codebase. This doesn't block sideloading but is worth noting for future performance optimization. Not a current issue since the app is sideloaded (no certification needed).

### F2. BusySpinner is a known Roku platform bug
<cite index="1-1">The issue is not specifically with the BusySpinner, but rather with rotations in general when using the automatic scaling from FHD to HD.</cite> The community confirms this is a firmware issue with rotation-based animations on FHD→HD scaling. SimPlex targets `ui_resolutions=fhd` on a 4K TV (no downscaling), so the root cause documented in S11 (BusySpinner specifically) is consistent. The safe LoadingSpinner replacement (Label + Rectangle, no rotation) is the correct approach.

### F3. BrighterScript 0.70.3 is current stable
<cite index="22-1">Latest version: 0.70.3, last published: 4 months ago.</cite> The project's `package.json` pins `^0.70.3`, which is the latest stable release. The v1 rewrite is still in alpha testing. The `Out of Scope` decision to defer BrighterScript v1.0.0-alpha migration remains correct.

---

## Summary Table

| # | Category | Issue | Severity | Fix Location |
|---|----------|-------|----------|-------------|
| A1 | Stale memory | Auto-play not wired (fixed in S12) | Memory-only | CONCERNS.md |
| A2 | Stale memory | Watch state not propagated (fixed in S12) | Memory-only | CONCERNS.md |
| A3 | Stale memory | Orphaned files exist (deleted in S11) | Memory-only | CONCERNS.md |
| A4 | Stale memory | SIGSEGV open investigation (resolved in S11) | Memory-only | CONCERNS.md |
| A5 | Stale memory | 90% threshold (changed to 30s in S12) | Memory-only | CONCERNS.md |
| A6 | Stale memory | Known issues in PROJECT.md | Memory-only | PROJECT.md |
| A7 | Stale memory | Orphaned files in PROJECT.md | Memory-only | PROJECT.md |
| A8 | Stale memory | 90% decision in PROJECT.md | Memory-only | PROJECT.md |
| B1 | Wrong constant | SIDEBAR_WIDTH 280→340 | Agent hazard | CLAUDE.md |
| B2 | Wrong constant | BG_PRIMARY wrong color | Agent hazard | CLAUDE.md |
| B3 | Wrong constant | ACCENT wrong color | Agent hazard | CLAUDE.md |
| C1 | Code bug | HomeScreen playback missing auto-play/PostPlay | Medium | HomeScreen.brs |
| C2 | Code gap | PlaylistScreen uses old playbackComplete | Low (documented) | PlaylistScreen.brs |
| C3 | Code cosmetic | Sidebar.xml hardcoded itemSize | Low | Sidebar.xml |
| C4 | Code inconsistency | 5 inline uses of old accent color | Low | 3 files |
| D1 | Security | HAR file not gitignored | High | .gitignore |
| E1 | Cosmetic | LOC count 11,158→11,385 | Cosmetic | PROJECT.md |
