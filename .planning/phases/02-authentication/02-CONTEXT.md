# Phase 2: Authentication - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Users authenticate via plex.tv PIN code and connect to their Plex server. Includes PIN-based OAuth flow, server discovery with connection fallback, persistent token storage, and 401 handling. Navigation framework and library browsing are separate phases.

</domain>

<decisions>
## Implementation Decisions

### PIN Entry Experience
- Full screen dedicated PIN display with large code and plex.tv/link URL prominently shown
- Spinner with status text ("Waiting for authorization...") while polling for confirmation
- Auto-refresh with new PIN if current PIN expires — user never has to manually retry
- Back button cancels PIN flow (standard Roku pattern)

### Connection Fallback
- Connection priority: Local → Remote → Relay (fastest first)
- Silent retry across all connection types; only show error if ALL fail
- Auto-reconnect silently when server becomes unreachable mid-session; only interrupt user if reconnection fails after ~30s
- No offline mode — show friendly "Can't reach server" with retry option when completely offline

### Session Handling
- Auto-redirect to PIN screen when auth token expires (401 response) — clear stored token, simple recovery
- "Sign Out" option available in Settings menu — clears token, returns to PIN screen
- "Change Server" option available in Settings menu — shows server list for multi-server users
- Persist auth token and selected server URI across app restarts — app launches directly to home

### Claude's Discretion
- Server selection UI (if user has multiple servers — list style, icons, connection status indicators)
- Exact polling interval for PIN confirmation
- Connection timeout values
- Error message wording

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User accepted all recommended patterns based on Roku UI conventions and clean UX principles.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-authentication*
*Context gathered: 2026-02-09*
