# Phase 1: Foundation & Architecture - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish project structure, Task node patterns, and API abstraction layer that all subsequent phases depend on. This phase delivers the scaffolding and patterns — no user-facing features.

</domain>

<decisions>
## Implementation Decisions

### API Abstraction Design
- Single PlexApiTask handles all API requests (pass endpoint/method as parameters)
- Independent requests — each call creates/runs its own task instance (parallel-friendly)
- Utility functions for URL building: `GetPlexUrl()` and `GetPlexHeaders()` helpers, task assembles and executes
- Raw JSON returned from task, separate normalizer functions convert to ContentNode (clean separation)

### Task Node Patterns
- Fresh task instance created per request (no pooling/reuse)
- Observer callback naming: `onTaskNameComplete` (e.g., `onApiTaskComplete`, `onAuthTaskComplete`)
- Task signals completion via `state` field; check `response` and `error` fields when done
- Caller is responsible for cleanup: remove observer and reference when task completes

### Error Handling Philosophy
- Minimal, non-intrusive user messages: brief toast for user-actionable errors (auth failed, server unreachable), silent for recoverable issues
- No automatic retry — fail fast, let user trigger retry via refresh
- Hide unsupported features: if server lacks a capability, hide that UI element entirely
- Logging: errors + key events (auth, server connect, playback start) — useful for debugging without noise

### ContentNode Structure
- Camel case field names aligned with Roku conventions (title, description, posterUrl) — map from Plex names
- Standard `itemType` field to identify media types: 'movie', 'show', 'season', 'episode'
- Minimal metadata for list/grid items: id, title, posterUrl, itemType, watched status — full metadata on detail view
- Flat with references for nested data: separate requests per level, nodes reference parent via showId/seasonId

### Claude's Discretion
- Specific file organization within source/ and components/
- Exact utility function signatures
- Internal task field names beyond state/response/error
- Logger implementation details

</decisions>

<specifics>
## Specific Ideas

- Environment: 1-2 Rokus connecting to single local Plex server
- Rare simultaneous access — no need for request queuing or rate limiting
- Patterns should prioritize simplicity over handling complex edge cases

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-architecture*
*Context gathered: 2026-02-09*
