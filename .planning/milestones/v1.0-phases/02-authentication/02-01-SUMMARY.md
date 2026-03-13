---
phase: 02-authentication
plan: 01
subsystem: authentication-ui
tags: [ui, authentication, plex-api, pin-flow]
dependencies:
  requires:
    - 01-01-foundation (utils, constants, logger)
  provides:
    - PINScreen component (full-screen PIN display)
    - PlexAuthTask server discovery
  affects:
    - Authentication flow UI
    - Server selection flow
tech_stack:
  added: []
  patterns:
    - Timer-based polling (2s interval)
    - Observer pattern (state field observation)
    - ISO 8601 datetime parsing for expiration
key_files:
  created:
    - PlexClassic/components/screens/PINScreen.xml
    - PlexClassic/components/screens/PINScreen.brs
  modified:
    - PlexClassic/components/tasks/PlexAuthTask.xml
    - PlexClassic/components/tasks/PlexAuthTask.brs
decisions: []
metrics:
  duration_minutes: 4
  tasks_completed: 2
  files_created: 2
  files_modified: 2
  commits: 2
completed: 2026-02-09T20:44:57Z
---

# Phase 02 Plan 01: PIN Authentication UI Summary

**One-liner:** Full-screen PIN authentication UI with auto-refresh polling and server discovery via plex.tv OAuth flow

## What Was Built

Created the complete user-facing PIN authentication experience and enhanced the background task to support PIN expiration handling and server discovery.

### Components Created

**PINScreen (screens/PINScreen.xml + .brs)**
- Full-screen centered layout with large PIN code display (120px font in Plex gold)
- Prominent plex.tv/link URL label (48px font)
- BusySpinner with status text showing current flow state
- Error label for failure states (red text, conditionally visible)
- Bottom hint: "Press Back to cancel"
- Interface fields: state, authToken, servers (receives data from PlexAuthTask)

**PINScreen Logic**
- Creates PlexAuthTask instance and observes state changes
- Creates Timer node with 2-second repeat interval for polling
- Automatically requests PIN on init via startPinRequest()
- Polls PIN status via checkPin action every 2 seconds
- Detects PIN expiration (<30 seconds remaining) and auto-refreshes
- Handles all auth states: idle, loading, pinReady, waiting, authenticated, serversReady, error, refreshing
- Back button cancels flow (stops timer, stops task, sets state="cancelled")
- After successful auth, automatically triggers fetchResources action

### PlexAuthTask Enhancements

**New Interface Fields**
- expiresAt (string) - ISO 8601 timestamp for PIN expiration
- servers (assocarray) - Array of server objects from plex.tv resources API

**New States**
- refreshing - PIN expired, need new PIN
- serversReady - Server list fetched and parsed

**New Functionality**
- requestPin now extracts and stores expiresAt timestamp, logs PIN request
- checkPin now detects expired PINs (expired=true flag) and signals refresh state
- checkPin updates expiresAt on each poll
- fetchResources action retrieves server list from plex.tv/api/v2/resources
- parseServerList filters devices by "server" provider type, extracts name/clientId/version
- parseConnections categorizes connections into local/remote/relay arrays based on flags

## Technical Implementation

### PIN Expiration Detection
PINScreen's checkPinExpiration() parses the ISO 8601 expiresAt string into roDateTime, compares to current time, and auto-refreshes if <30 seconds remain. PlexAuthTask also detects server-side expiration via the expired boolean flag in the checkPin response.

### Observer Pattern
PINScreen observes m.authTask.state field. State changes trigger onAuthStateChange callback which updates UI elements and initiates next actions (polling, server fetch, etc).

### Connection Categorization
parseConnections examines each connection's local and relay flags (handles both string "0"/"1" and boolean 0/1 formats) to categorize connections into three arrays for future connection testing priority (local → remote → relay).

### Timer-Based Polling
2-second repeat Timer node fires onPollTimer callback, which sets action="checkPin" and control="run" on the task. Simpler than manual delay loops and integrates with SceneGraph event system.

## Verification Results

### Files Created
- [x] PlexClassic/components/screens/PINScreen.xml exists
- [x] PlexClassic/components/screens/PINScreen.brs exists

### Interface Completeness
- [x] PINScreen has state, authToken, servers fields
- [x] PlexAuthTask has expiresAt, servers fields
- [x] PlexAuthTask includes logger.brs script

### Component Structure
- [x] PINScreen.xml includes pinCodeLabel (large font)
- [x] PINScreen.xml includes statusLabel and errorLabel
- [x] PINScreen.xml includes spinner (BusySpinner)
- [x] PINScreen.brs has onAuthStateChange function
- [x] PINScreen.brs has startPinRequest function
- [x] PINScreen.brs has checkPinExpiration function
- [x] PINScreen.brs has onKeyEvent with back button handling

### PlexAuthTask Enhancements
- [x] PlexAuthTask.brs has fetchResources function
- [x] PlexAuthTask.brs has parseServerList function
- [x] PlexAuthTask.brs has parseConnections function
- [x] PlexAuthTask run() handles fetchResources action
- [x] requestPin extracts expiresAt and uses LogEvent
- [x] checkPin detects expired flag and signals refreshing state

### Success Criteria Met
- [x] PINScreen shows large 4-digit code with plex.tv/link URL
- [x] Spinner visible during polling with status text
- [x] PIN auto-refreshes when expiration detected (client-side <30s check + server-side expired flag)
- [x] Back button cancels flow (state = "cancelled")
- [x] After authentication, fetchResources returns parsed server list
- [x] Server list includes connection arrays (local/remote/relay)

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

Plan 02-02 will implement server selection UI (if multiple servers) and connection testing with fallback logic (local → remote → relay priority).

## Commits

- 3737ac8: feat(02-01): create PINScreen component with PIN display and polling
- ea77ab3: feat(02-01): enhance PlexAuthTask with expiration and server discovery

## Self-Check: PASSED

All claimed files exist and all commits are present in git history.
