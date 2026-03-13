# Phase 3: Hub Rows - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Home screen surfaces personalized "what to watch next" content via hub rows (Continue Watching, Recently Added, On Deck) without requiring library browsing. Users see progress bars on partially-watched items and can quickly resume or discover content. Hub rows sit above the existing library grid on the home screen.

</domain>

<decisions>
## Implementation Decisions

### Row layout & presentation
- Reuse existing 240x360 portrait poster style — consistent with library grid
- Rows scroll horizontally to reveal more items beyond the visible set
- Default home screen: hub rows at top, library grid below — one scrollable view
- Sidebar allows switching between hub+grid landing view and full library grid view

### Navigation & selection
- Selecting a Continue Watching item starts playback/resumes immediately
- Selecting a Recently Added or On Deck item opens the detail screen
- Pressing left on the first item in a hub row opens the sidebar (consistent with existing nav)
- Hub rows remember horizontal scroll position when navigating away and returning

### Row content & ordering
- Row order: Continue Watching → On Deck → Recently Added
- Recently Added pulls from libraries configured to appear on the home screen (respects Plex server hub config)
- Item count per row matches Plex API defaults (typically 10-20)

### Empty & sparse states
- Empty hub rows are hidden entirely — no placeholder messages
- Hub rows refresh periodically via auto-refresh while on the home screen
- Hub rows also reload when navigating back to home (e.g., after playback)

### Claude's Discretion
- Row label styling (bold headers vs subtle inline text)
- Focus behavior when navigating down from last hub row into library grid
- What to show when ALL hub rows are empty (fresh user experience)
- Error handling for failed hub row loads (silent hide vs inline error)

</decisions>

<specifics>
## Specific Ideas

- Hub+grid as the landing view mirrors the old Plex Classic feel — hub rows for quick access, grid for browsing
- The sidebar view toggle gives power users a way to go straight to library browsing without hub rows in the way

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-navigation-framework*
*Context gathered: 2026-03-09*
