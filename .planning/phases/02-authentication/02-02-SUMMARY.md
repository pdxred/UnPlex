---
phase: 02-authentication
plan: 02
subsystem: server-connection
tags: [authentication, server-selection, connection-testing, task-node]
dependencies:
  requires:
    - 02-01 (PlexAuthTask server discovery, PINScreen)
    - 01-01-foundation (utils, constants, logger)
  provides:
    - ServerConnectionTask (priority-ordered connection testing)
    - ServerListScreen (multi-server selection UI)
  affects:
    - Authentication flow (server selection after PIN auth)
    - Connection reliability (fallback logic)
tech_stack:
  added: []
  patterns:
    - Priority-ordered connection testing (local > remote > relay)
    - Timeout-based reachability detection (3s local, 5s remote/relay)
    - Observer pattern (task state observation)
    - Registry persistence (serverClientId for reconnection)
key_files:
  created:
    - PlexClassic/components/tasks/ServerConnectionTask.xml
    - PlexClassic/components/tasks/ServerConnectionTask.brs
    - PlexClassic/components/screens/ServerListScreen.xml
    - PlexClassic/components/screens/ServerListScreen.brs
  modified: []
decisions:
  - Local connections use 3-second timeout (faster for LAN)
  - Remote/relay connections use 5-second timeout (account for latency)
  - 401 responses count as reachable (server responds, auth handled separately)
  - Single server auto-selects without showing list UI
  - Failed servers marked "(unreachable)" in list for user feedback
metrics:
  duration_minutes: 2
  tasks_completed: 2
  files_created: 4
  files_modified: 0
  commits: 2
completed: 2026-02-09T20:54:38Z
---

# Phase 02 Plan 02: Server Connection and Selection Summary

**One-liner:** Priority-ordered server connection testing (Local > Remote > Relay) with multi-server selection UI and registry persistence

## What Was Built

Created the complete server connection testing and selection experience, enabling users to connect to Plex servers with automatic fallback through connection types and smart single-server auto-selection.

### Components Created

**ServerConnectionTask (tasks/ServerConnectionTask.xml + .brs)**
- Task node for background connection testing (avoids render thread blocking)
- Tests connections in strict priority order: Local → Remote → Relay
- Configurable timeouts: 3 seconds for local, 5 seconds for remote/relay
- Interface fields: connections (input), authToken (input), successfulUri (output), connectionType (output), error (output), state (output)
- States: idle, testing, connected, error
- Returns first successful connection and stops further testing
- Treats 401 responses as reachable (server responsive, auth handled globally)

**ServerConnectionTask Logic**
- testConnections(): Main task function that orchestrates testing flow
- appendConnections(): Helper to build ordered test array from categorized connection objects
- testConnection(): Individual connection test using roUrlTransfer with timeout
- Logs every connection attempt and outcome for debugging
- Uses GetPlexHeaders() to include all required X-Plex-* headers
- Uses HTTPS certificates for secure connections

**ServerListScreen (screens/ServerListScreen.xml + .brs)**
- Full-screen server selection UI with centered layout
- Title "Select a Server" at top (48px font)
- LabelList component (600px wide, 60px item height, white text, gold focus)
- BusySpinner shown during connection testing
- Status label showing current testing state
- Error label for connection failures (red text)
- Interface fields: servers (input), authToken (input), selectedServer (output), serverUri (output), state (output)
- States: idle, testing, connected, error, cancelled

**ServerListScreen Logic**
- onServersChanged(): Populates LabelList from server array, auto-selects if only 1 server
- onServerSelected(): Handles user selection from list
- selectServer(): Persists serverClientId to registry, initiates connection test
- startConnectionTest(): Creates ServerConnectionTask instance, observes state changes
- onConnectionStateChange(): Handles connected/error states, updates UI, persists serverUri
- onKeyEvent(): Handles back button to cancel selection flow
- Failed servers marked "(unreachable)" in list, focus returns to list for retry

## Technical Implementation

### Priority-Ordered Connection Testing
ServerConnectionTask receives categorized connections from PlexAuthTask's server discovery:
- local: Connections with local=true flag (same network)
- remote: Connections with local=false, relay=false (direct internet)
- relay: Connections with relay=true flag (Plex relay servers)

The task builds a single ordered array and tests sequentially, returning on first success.

### Timeout Strategy
Local connections get 3-second timeout for fast LAN response. Remote and relay connections get 5-second timeout to account for internet latency. This prevents slow remote connections from blocking the flow unnecessarily.

### Registry Persistence
ServerListScreen persists two critical pieces of data:
- serverClientId: Stored via registry write for future reconnection (identifies specific server)
- serverUri: Stored via SetServerUri() helper for API calls

This allows the app to automatically reconnect to the last-used server on subsequent launches.

### Auto-Selection Optimization
If PlexAuthTask returns only 1 server, ServerListScreen automatically calls selectServer(0) without requiring user interaction. This streamlines the flow for single-server users (majority case).

### Graceful Failure Handling
When a connection test fails:
1. Error displayed in red error label
2. Server name in list updated to include "(unreachable)"
3. Status label shows "Connection failed"
4. Spinner hidden
5. Focus returned to server list so user can try another server
6. LogError called for debugging

This provides clear visual feedback and recovery path without blocking the user.

## Verification Results

### Files Created
- [x] PlexClassic/components/tasks/ServerConnectionTask.xml exists
- [x] PlexClassic/components/tasks/ServerConnectionTask.brs exists
- [x] PlexClassic/components/screens/ServerListScreen.xml exists
- [x] PlexClassic/components/screens/ServerListScreen.brs exists

### Interface Completeness
- [x] ServerConnectionTask.xml has connections, authToken, successfulUri, connectionType, error, state fields
- [x] ServerListScreen.xml has servers, authToken, selectedServer, serverUri, state fields

### Component Structure
- [x] ServerConnectionTask.brs has testConnections, testConnection, appendConnections functions
- [x] ServerConnectionTask uses 3s timeout for local, 5s for remote/relay
- [x] ServerConnectionTask logs all connection attempts
- [x] ServerListScreen.xml uses LabelList for server display
- [x] ServerListScreen.brs has onServersChanged, onServerSelected, selectServer functions
- [x] ServerListScreen.brs has startConnectionTest, onConnectionStateChange functions
- [x] ServerListScreen persists serverClientId to registry
- [x] ServerListScreen auto-selects if only 1 server

### Success Criteria Met
- [x] ServerConnectionTask tests local connections first (fastest)
- [x] First successful connection wins (returns immediately)
- [x] Users with 1 server auto-proceed (no selection screen shown)
- [x] Users with multiple servers see selection list
- [x] Server selection persists clientId for reconnection
- [x] Working URI saved via SetServerUri() for future API calls
- [x] Failed servers marked "(unreachable)" in list

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

Plan 02-03 integrates these components into MainScene's authentication lifecycle, adding:
- checkAuthAndRoute() to determine which screen to show on launch
- autoConnect() to reconnect to stored server
- 401 detection in PlexApiTask to handle token expiration globally

## Commits

- 9ce694f: feat(02-02): create ServerConnectionTask for priority-ordered connection testing
- b3126a4: feat(02-02): create ServerListScreen for multi-server selection

## Self-Check: PASSED

All claimed files exist and all commits are present in git history.
