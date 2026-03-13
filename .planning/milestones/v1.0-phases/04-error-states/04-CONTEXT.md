# Phase 4: Error States - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Every async operation communicates its status clearly and failures are recoverable without restarting the app. Covers loading indicators, empty state messaging, network error handling with retry, and server disconnect recovery across all existing screens (home, library, detail, episodes, search, settings).

</domain>

<decisions>
## Implementation Decisions

### Loading indicators
- Simple centered spinner (no text label), using the existing LoadingSpinner component
- Positioned center of the content area (right of sidebar), not full screen center
- No minimum display time — if data comes back instantly, skip the spinner

### Claude's Discretion: Loading strategy
- Whether to use full-replacement (spinner until all data ready) or progressive loading (content appearing as it arrives) — pick per-screen based on what makes sense

### Empty state messaging
- Friendly & helpful tone — e.g., "Nothing here yet" with a brief suggestion
- Hub rows with no content (Continue Watching, On Deck, Recently Added) should be hidden entirely, not shown with a message
- Empty search results: simple "No results" message, no suggestion to broaden search
- Empty libraries: friendly message with guidance (e.g., "Add content to your Plex server")

### Claude's Discretion: Empty state visuals
- Whether to include icons/illustrations above empty state text — pick based on what works well on Roku

### Error & retry UX
- Network errors presented as dialog overlays (modal), not inline
- Contextual error messages specific to what failed (e.g., "Couldn't load your library"), no error codes
- Silent auto-retry once before showing dialog — if second attempt also fails, show the error dialog
- After dismissing error dialog without retrying: stay on current screen with inline "Retry" option

### Server disconnect flow
- Silent background retry first when server becomes unreachable — only show dialog if it stays down
- Dialog offers two options: "Try Again" (reconnect to same server) and "Server List" (pick different server)
- On successful reconnection: resume the user's position on the same screen, re-fetch its data
- Auth token expiry treated same as any other error — standard error dialog with retry, no special auth flow

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-error-states*
*Context gathered: 2026-03-09*
