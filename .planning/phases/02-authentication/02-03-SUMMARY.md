---
phase: 02-authentication
plan: 03
subsystem: authentication-lifecycle
tags: [authentication, routing, 401-handling, sign-out]
dependencies:
  requires:
    - 02-01-PLAN (PINScreen component and PlexAuthTask)
  provides:
    - 401 detection in PlexApiTask
    - Auth-aware routing in MainScene
    - Sign out functionality
  affects:
    - Complete authentication lifecycle
    - Initial app launch routing
    - Token expiration handling
tech_stack:
  added: []
  patterns:
    - Global field observer pattern (authRequired flag)
    - Authentication gate detection (401 responses)
    - Conditional routing based on stored credentials
    - Screen stack management (clearScreenStack helper)
key_files:
  created: []
  modified:
    - PlexClassic/components/tasks/PlexApiTask.xml
    - PlexClassic/components/tasks/PlexApiTask.brs
    - PlexClassic/components/MainScene.xml
    - PlexClassic/components/MainScene.brs
    - PlexClassic/source/utils.brs
decisions:
  - "ClearAuthData removes authToken, serverUri, and serverClientId from registry"
  - "401 detection clears token immediately via SetAuthToken(\"\") before signaling"
  - "checkAuthAndRoute trusts stored credentials on launch (validates via first API call)"
  - "Single server auto-connects via autoConnectToServer without user selection"
  - "Auth failures in autoConnect fall back to PIN screen"
metrics:
  duration_minutes: 3
  tasks_completed: 2
  files_created: 0
  files_modified: 5
  commits: 2
completed: 2026-02-09T20:50:01Z
---

# Phase 02 Plan 03: Authentication Lifecycle Integration Summary

**One-liner:** Complete auth lifecycle with 401 detection, automatic PIN screen routing on token expiration, and sign-out functionality

## What Was Built

Enhanced PlexApiTask to detect unauthorized responses and integrated comprehensive authentication routing logic into MainScene, enabling automatic recovery from token expiration and proper initial app routing.

### PlexApiTask 401 Detection

**New Interface Fields**
- responseCode (integer) - Captures HTTP status code from each request

**Enhanced Logic**
- Captures response code via url.GetResponseCode() immediately after request completes
- Detects 401 Unauthorized before checking for empty response
- Clears invalid token via SetAuthToken("") when 401 detected
- Signals authRequired via global field (m.global.authRequired = true)
- Sets state to "authRequired" for observer pattern
- Applies to both GET and POST request paths

### MainScene Authentication Routing

**New Interface Fields**
- showSignOut (boolean) - Trigger field for Settings screen to initiate sign out

**New Utility Function (utils.brs)**
- ClearAuthData() - Removes authToken, serverUri, serverClientId from registry and flushes

**Initialization Changes**
- Global authRequired field added and observed
- checkAuthAndRoute() called on init to route based on stored credentials
- showSignOut field observed for sign-out trigger

**Authentication Flow Functions**

1. **checkAuthAndRoute()** - Launch routing logic
   - Checks for stored token and serverUri
   - No credentials → showPINScreen()
   - Has credentials → showHomeScreen() (validates on first API call)

2. **showPINScreen()** - PIN authentication screen
   - Clears screen stack
   - Creates PINScreen component and observes state field
   - Pushes to screen stack

3. **onPINScreenState()** - PIN screen state handler
   - state="authenticated" → check server count
   - Multiple servers → showServerListScreen()
   - Single server → autoConnectToServer()
   - No servers → log error and stay on PIN screen
   - state="cancelled" → return to home if credentials exist

4. **showServerListScreen()** - Server selection UI
   - Clears screen stack and creates ServerListScreen
   - Passes servers array and authToken
   - Observes state field

5. **onServerListState()** - Server selection handler
   - state="connected" → clear stack and showHomeScreen()
   - state="cancelled" → showPINScreen()

6. **autoConnectToServer()** - Single server auto-connect
   - Creates ServerConnectionTask with server connections
   - Saves serverClientId to registry
   - Observes state field
   - Tests connection priority (local → remote → relay)

7. **onAutoConnectState()** - Auto-connect result handler
   - state="connected" → save serverUri and showHomeScreen()
   - state="error" → log error and showPINScreen()

8. **onAuthRequired()** - Global auth observer callback
   - Triggered when any API call returns 401
   - Resets m.global.authRequired flag
   - Shows PIN screen (user re-authenticates)

9. **signOut()** - Sign out function
   - Calls ClearAuthData() to remove all credentials
   - Shows PIN screen for re-authentication

10. **onShowSignOut()** - Sign out trigger observer
    - Responds to showSignOut field change
    - Resets field to false
    - Calls signOut()

**Helper Functions Added**
- clearScreenStack() - Removes all screens from stack
- getCurrentScreen() - Returns top screen from stack (used to get PINScreen data)

**Integration Points**
- Screen stack management preserves existing pushScreen/popScreen logic
- PINScreen subtype added to currentScreen detection in popScreen()
- logger.brs script included in MainScene.xml for LogEvent/LogError

## Technical Implementation

### 401 Detection Flow
1. PlexApiTask makes HTTP request (GET or POST)
2. Captures responseCode via url.GetResponseCode()
3. Checks if responseCode = 401 before any other validation
4. If 401: clears token, sets global authRequired flag, returns with "authRequired" state
5. MainScene's onAuthRequired observer fires
6. User redirected to PIN screen automatically

### Launch Routing Logic
- App init → checkAuthAndRoute()
- Check registry for authToken and serverUri
- Empty → PIN screen (fresh install or signed out)
- Present → Home screen (trust stored creds, validate on first API call)
- First API call returns 401 → onAuthRequired fires → PIN screen

### Sign Out Flow
- Settings screen sets m.top.showSignOut = true
- MainScene's onShowSignOut observer fires
- Calls signOut() → ClearAuthData() → showPINScreen()
- User must re-authenticate to access content

### Single vs. Multiple Server Handling
- PINScreen's fetchResources returns server array
- onPINScreenState checks servers.count()
- 1 server → autoConnectToServer (no user interaction needed)
- 2+ servers → showServerListScreen (user picks server)
- 0 servers → error logged, stay on PIN screen

## Verification Results

### Task 1: PlexApiTask 401 Detection
- [x] PlexApiTask.xml has responseCode interface field
- [x] PlexApiTask.brs captures response code after request
- [x] 401 check happens before empty response check
- [x] SetAuthToken("") called to clear invalid token
- [x] m.global.authRequired set to true
- [x] state set to "authRequired"
- [x] Check applies to both GET and POST paths

### Task 2: MainScene Auth Routing
- [x] utils.brs has ClearAuthData function
- [x] MainScene.xml has showSignOut interface field
- [x] MainScene.xml includes logger.brs script
- [x] MainScene.brs has checkAuthAndRoute function
- [x] MainScene.brs has showPINScreen function
- [x] MainScene.brs has onPINScreenState callback
- [x] MainScene.brs has showServerListScreen function
- [x] MainScene.brs has onServerListState callback
- [x] MainScene.brs has autoConnectToServer function
- [x] MainScene.brs has onAutoConnectState callback
- [x] MainScene.brs has onAuthRequired observer callback
- [x] MainScene.brs has signOut function
- [x] MainScene.brs has onShowSignOut observer
- [x] m.global.authRequired field initialized and observed
- [x] clearScreenStack and getCurrentScreen helpers present

### Success Criteria Met
- [x] Fresh install shows PIN screen (no stored credentials)
- [x] After auth + server selection, app shows home
- [x] Subsequent launches go directly to home (credentials persisted)
- [x] 401 from any API call redirects to PIN screen automatically
- [x] Sign Out from Settings clears data and shows PIN screen
- [x] Token cleared immediately when 401 detected

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

Phase 2 authentication is now complete. The app has full authentication lifecycle support:
- PIN-based OAuth flow
- Server discovery and connection testing
- 401 detection and automatic re-authentication
- Sign out functionality

Next phase will implement library browsing and navigation UI.

## Commits

- 7c093e3: feat(02-03): add 401 detection to PlexApiTask
- 7e3a3db: feat(02-03): add auth-aware routing to MainScene

## Self-Check: PASSED

All modified files exist and all commits are present in git history.

Verification commands:
```
[ -f "PlexClassic/components/tasks/PlexApiTask.xml" ] && echo "FOUND"
[ -f "PlexClassic/components/tasks/PlexApiTask.brs" ] && echo "FOUND"
[ -f "PlexClassic/components/MainScene.xml" ] && echo "FOUND"
[ -f "PlexClassic/components/MainScene.brs" ] && echo "FOUND"
[ -f "PlexClassic/source/utils.brs" ] && echo "FOUND"
git log --oneline --all | grep -q "7c093e3" && echo "FOUND: 7c093e3"
git log --oneline --all | grep -q "7e3a3db" && echo "FOUND: 7e3a3db"
```
