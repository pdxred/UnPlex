# Phase 2: Playback Foundation - Context

**Gathered:** 2026-03-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can resume where they left off and see at a glance what they have and haven't watched. Includes resume playback from last position, progress bar indicators on posters and episode lists, watched/unwatched badges, and mark watched/unwatched actions. Navigation framework, hub rows, and playback controls (audio/subs/skip) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Progress Bars
- Position: Claude's discretion (bottom edge overlay recommended)
- Color: Plex gold accent color, stored as a theme-aware constant so it changes with future accent color themes
- Background track: Yes — semi-transparent dim bar showing total length, gold fill showing progress
- Thickness: Claude's discretion (proportional to poster size at FHD)
- Visibility: Always visible regardless of focus state
- Minimum threshold: Below ~5% progress, treat as not started (no bar shown)
- Maximum threshold: Show bar until 100% — do not auto-mark as watched at 95%
- Scope: Progress bars appear on BOTH poster grid items AND episode list items
- Detail screen: Show "X min remaining" text alongside a progress bar; bar sizing at Claude's discretion
- All partially-watched items show progress bars, regardless of age

### Watched/Unwatched Badges
- Style: Corner triangle overlay (like official Plex Roku app), NOT a dot
- Color: Uses accent/theme color (gold by default, adapts to future theme changes)
- Watched items: No indicator — clean poster. Absence of triangle = watched.
- TV show posters: Triangle with unwatched episode count (e.g., "3")
- Movies and individual episodes: Triangle only, no count
- Fully-watched shows (0 unwatched): Badge hidden entirely — clean poster
- Coexistence rule: If an item has a progress bar, hide the unwatched triangle (progress bar implies unwatched)
- Episode list: Same triangle badge style on episode thumbnails
- Updates: Badge updates immediately (live) — including show poster unwatched count decrementing after watching an episode

### Resume Behavior
- From grids/episode list: Prompt dialog — "Resume from 32:15" / "Start from beginning"
- From detail screen: Separate visible "Resume" and "Play from start" buttons (no dialog)
- Progress reporting frequency: Claude's discretion (periodic updates to PMS)
- Crash recovery: Claude's discretion (periodic saves + seek saves for reliability)

### Mark Watched/Unwatched
- Trigger methods: BOTH — visible button on detail screen AND options (*) remote button context menu
- Options (*) menu: Available on poster grids too (quick mark without entering detail)
- TV show scope: Context-aware — show poster = whole show, season = whole season, episode = that episode
- UI update timing: Claude's discretion (optimistic vs wait-for-confirmation)

### Claude's Discretion
- Progress bar exact placement (bottom edge overlay recommended)
- Progress bar thickness
- Detail screen progress bar sizing
- Progress reporting interval to PMS
- Crash recovery strategy (periodic + seek saves)
- Optimistic vs confirmed UI updates for mark watched/unwatched
- Context menu visual design

</decisions>

<specifics>
## Specific Ideas

- Default theme: Gray/black UI with Plex gold highlights, white fonts, gold links — all accent elements should use a single theme color constant for future theme support
- All color-dependent UI elements (progress bars, badges, highlights) must reference a centralized accent color so the future color picker theme feature works without refactoring
- "Less clicks to get to an oft used function" — resume prompt should be fast and dismissible, not modal

</specifics>

<deferred>
## Deferred Ideas

- **Color theme picker** — 8 alternate accent colors beyond gold (future UI phase)
- **Dark/light mode toggle** — (future UI phase)
- **Settings screen** — Default to advanced settings visible (future phase)
- **Sidebar pinning and reordering** — Alphabetical sort + custom reorg, one-time sort not recurring (future navigation phase)
- **Background image priority** — Don't prioritize show/movie backgrounds over intuitive layout (future UI phase)
- **Minimize clicks philosophy** — Balance cleanliness and intuitiveness across all screens (future navigation phase)

</deferred>

---

*Phase: 02-playback-foundation*
*Context gathered: 2026-03-08*
