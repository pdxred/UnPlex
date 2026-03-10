# Phase 5: Filter and Sort - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can find specific content in large libraries without scrolling through thousands of items. This phase adds sorting and filtering controls to library grid screens. Collections, playlists, and search are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Controls placement
- Options (*) button on the Roku remote opens the filter/sort panel
- Bottom sheet style — slides up from the bottom of the screen, grid remains visible above
- Sheet stays open while user tweaks multiple filters; dismiss with Back button
- Filters apply immediately as each option is changed (no Apply button — grid updates live above the sheet)

### Filter interaction
- Filters stack freely with AND logic — e.g., Genre: Action AND Year: 2020s AND Unwatched all combine
- Genre supports multi-select — user can pick multiple genres (OR logic within genre, AND with other filter types)
- Sort options: Title, Date Added, Year, Rating (the four from success criteria)
- Sort direction is toggleable — ascending/descending for each sort option

### Active filter display
- Persistent text bar below the library header shows active filters and sort (e.g., "Genre: Action, Comedy · Unwatched · Sort: Year ↑")
- Bar is always visible, even in default state — shows "All · Sort: Title A-Z" when unfiltered
- Item count displayed (e.g., "42 items" or "42 of 1,200")
- Sort and filters are mixed together in the bottom sheet (no separate sections)

### Clearing filters
- "Clear All" button in the bottom sheet resets everything
- Individual filters can be cleared one by one (not just all-or-nothing)

### Result transitions
- Fade transition when grid re-populates after filter change (current grid fades out, new results fade in)
- Focus resets to top-left item after any filter/sort change
- Empty filter results show "No items match your filters" message with a "Clear Filters" button

### Claude's Discretion
- Dropdown/list behavior when selecting filter values within the bottom sheet
- Exact bottom sheet height and animation timing
- Filter bar typography and spacing
- Fade transition duration and easing

</decisions>

<specifics>
## Specific Ideas

- Filter bar mockup style: "Genre: Action · Unwatched · Sort: Year ↑" — compact, dot-separated, with arrow for sort direction
- Bottom sheet should feel lightweight — not a full-screen takeover, grid stays visible and updates live

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-filter-and-sort*
*Context gathered: 2026-03-10*
