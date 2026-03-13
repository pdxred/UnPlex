# Testing Patterns

**Analysis Date:** 2026-03-13

## Test Framework

**Runner:**
- BrighterScript compiler (`bsc`) included in `package.json` as `brighterscript@^0.70.3`
- Roku deployment via `roku-deploy@^3.16.1`
- No automated test framework installed (no Jest, Vitest, etc.)

**Run Commands:**
```bash
npm run build              # Compile BrightScript (bsc)
npm run deploy            # Compile and deploy to Roku device
npm run lint              # Type-check without emitting (bsc --noEmit)
```

**Build Configuration:**
- `bsconfig.json` specifies compilation targets
- `rootDir: "SimPlex"` points to app source directory
- `stagingDir: "out/staging"` where compiled output goes
- Diagnostic filters suppress codes 1105 (missing return), 1045 (shadowed vars), 1140 (unused vars)
- Source maps enabled for debugging

## Test File Organization

**Status:** No automated test suite present

This is a native Roku app written in BrightScript. Roku apps do not have standard unit testing frameworks. Testing is primarily:
1. Manual UAT (User Acceptance Testing) on actual Roku devices
2. Local development build-and-deploy cycle
3. Field testing on real hardware

**Why no automated tests:**
- BrightScript is interpreted on Roku OS only (can't run on desktop/CI)
- No official Roku test framework
- Third-party frameworks exist but require custom setups
- Project uses manual UAT documented in `.planning/` phase UAT reports

**Location of UAT documentation:**
- `.planning/phases/*/UAT.md` - Phase-level test results and observed issues
- `.planning/v1.0-MILESTONE-AUDIT.md` - Milestone completion audit
- `.claude/projects/*/memory/` - Session notes on fixes applied

## Manual Testing Approach

**Build → Deploy → Test Cycle:**

1. **Build phase:**
```bash
npm run build              # Validates syntax, type hints
```

2. **Deploy phase:**
```bash
npm run deploy             # Pushes to Roku device in developer mode
```

3. **Manual test:**
- Tester navigates app on Roku
- Verifies expected behavior
- Documents issues in UAT report

**Test Environments:**
- Development Roku device (192.168.x.x in developer mode)
- Physical Roku hardware (FHD 1920x1080 resolution)
- Network conditions (LAN vs relay connectivity)

## Verification Patterns (Manual)

**Regression Testing Checklist (implicit, from code comments):**

In components and screens, known crash/issue workarounds indicate tested failure modes:

```brightscript
' From HomeScreen.brs, line 7:
m.loadingSpinner = invalid ' LoadingSpinner removed - causes firmware SIGSEGV crash

' From SearchScreen.brs, line 7:
m.loadingSpinner = invalid ' LoadingSpinner causes firmware SIGSEGV crashes on Roku

' From DetailScreen.brs, line 9:
m.loadingSpinner = invalid ' BusySpinner causes firmware SIGSEGV crashes on Roku
```

**Testing issues discovered and fixed:**
- LoadingSpinner/BusySpinner components crash on certain Roku firmware versions
- Workaround: Set `m.loadingSpinner = invalid` to disable spinner in multiple screens
- Documented in multiple files indicating cross-screen validation

**Task Node HTTP Testing:**

Task nodes tested for:
- HTTP timeout handling: 30-second timeout in `PlexApiTask.run()`
- Response code validation: Checks `responseCode < 0`, `responseCode = 401`, `responseCode >= 200/< 300`
- JSON parse failures: Graceful null return on invalid JSON
- Empty response handling: Expected for scrobble/timeline endpoints

Example pattern from `PlexApiTask.brs`:
```brightscript
' Wait for response (30 second timeout)
msg = wait(30000, port)
if msg = invalid
    m.top.error = "Request timed out"
    m.top.status = "error"
    return
end if

' Check for 401 Unauthorized
if responseCode = 401
    LogError("401 Unauthorized - authentication required")
    SetAuthToken("")
    m.global.authRequired = true  ' Signal screens to handle
    return
end if
```

## Mocking Strategy (Not Applicable)

**Why no mocking:**
- No automated test runner means no mock libraries
- Manual UAT tests against real Plex servers
- Network failures tested via actual server downtime or network disconnect

**Integration Testing (Manual):**

Real servers tested for:
- Authentication flow: PIN code → auth token validation
- Server discovery: Fetch servers from plex.tv
- Connection testing: Test both local and relay URIs
- API endpoints: Browse libraries, fetch metadata, report progress
- Server reconnect: Detect offline → online transitions

**Network Scenarios Tested (per code logic):**

1. **No credentials:** Shows PIN screen
2. **Expired token:** 401 response triggers auth reset
3. **Server unreachable:** Displays "Server Unreachable" dialog with retry options
4. **Slow network:** 30-second timeout prevents infinite hangs
5. **Empty API responses:** Scrobble/timeline endpoints return empty 200s (handled gracefully)
6. **Invalid JSON:** Null check prevents crashes

## Error Testing Patterns

**Manual error scenarios tested (evident from error handling code):**

```brightscript
' From PlexApiTask: Error code validation
if responseCode < 0
    errorMsg = "Request failed: " + url.GetFailureReason()
    LogError("API error: " + errorMsg)
    m.top.error = errorMsg
    m.top.status = "error"
    return
end if

' Empty response validation
if response = "" and responseCode >= 200 and responseCode < 300
    m.top.status = "completed"  ' Success (expected for some endpoints)
else if response = ""
    LogError("Empty response (HTTP " + responseCode.ToStr() + ")")
    m.top.status = "error"  ' Unexpected empty response
end if
```

**Test scenarios implied by code:**
- Valid responses (parsed JSON → status="completed")
- Empty success responses (HTTP 200 with no body → status="completed")
- Empty error responses (HTTP non-2xx with no body → status="error")
- Malformed JSON (parse fails → status="error")
- Network timeouts (wait() returns invalid → status="error")
- Authentication failures (401 response → status="authRequired")

## Coverage

**No automated coverage measurement**

Manual UAT documents what's been tested:
- `.planning/v1.0-MILESTONE-AUDIT.md` - Phase checklist of features verified
- `.planning/phases/*/UAT.md` - Per-phase test results

**Critical paths verified (from phase completion records):**

Per git log and UAT files:
- Phase 10: User switching (last completed phase)
  - Managed user picker UI
  - PIN entry validation
  - Token management per user
  - Auth flow and state persistence

- Phase 9: Playback foundation (completed)
  - Video playback start/resume
  - Progress reporting
  - Track selection

- Earlier phases: Library navigation, search, detail screens (all marked complete)

**Untested areas (gaps):**
- No unit test coverage for helpers (SafeGet, FormatTime, BuildPlexUrl, etc.)
- No systematic test of all HTTP error codes
- Limited edge-case testing (malformed library responses, extreme pagination, etc.)
- No performance testing (memory usage, startup time, grid rendering speed)

## Integration Points Tested (Manual)

**Plex API:**
- PIN authentication via plex.tv
- Server discovery (resources endpoint)
- Library browsing with pagination
- Metadata fetch (detail screens)
- Playback progress reporting
- Search queries

**Local Storage:**
- Registry save/load (auth tokens, pinned libraries, user settings)
- Persistent state across app restart

**SceneGraph Components:**
- Field observer callbacks (tested via screen transitions)
- Focus management (tested via remote navigation)
- Key event routing (tested via back/play/pause buttons)

## Common Testing (Manual) Patterns

**Observable/Event Testing:**

```brightscript
' Set up observer for state change
task.observeField("status", "onTaskStateChange")

' Trigger task (manual test watches Roku screen for result)
task.control = "run"

' Handler checks state
sub onTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        ' Verify response displayed correctly
        ' (manual UAT: did the grid populate? are posters visible?)
    end if
end sub
```

**Focus Testing (Manual):**

```brightscript
' Code ensures focus is set on component receives focus
sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.grid.setFocus(true)
    end if
end sub

' Manual test: press Up/Down/Left/Right, verify grid scrolls
' Manual test: press Back, verify focus returns to previous screen
```

**Error Recovery Testing (Manual):**

From MainScene:
```brightscript
' Test: Server goes offline during playback
' Expected: onServerUnreachable triggered
' Manual verify: Dialog appears with "Try Again" / "Server List"

sub onServerUnreachable(event as Object)
    if event.getData() <> true then return
    m.global.serverUnreachable = false  ' Reset flag
    testServerConnectivity()  ' Silent test
end sub

' Manual test: Click "Try Again"
' Expected: Reconnect attempt shown
' Manual test: Click "Server List"
' Expected: Navigate to server selection screen
```

## UAT Report Structure

**Phase UAT documents (at `.planning/phases/*/UAT.md`):**
- Test environment (Roku model, firmware version, network)
- Test matrix (features/scenarios tested)
- Pass/Fail status per scenario
- Issues found (bugs, crashes, UX problems)
- Recommendations (priority fixes)

**Example from memory (Phase 10 - User Switching):**
```
Tested:
✓ User picker displays all users
✓ PIN entry for managed user
✓ Token storage per user
✓ Auth flow on user switch
✓ Sidebar refreshes after switch

Issues:
✗ Focus not restored after user switch (FIXED)
✗ Home screen crashes on 401 after expired token (FIXED)
```

## Best Practices for Adding Tests (Manual)

**If adding new features:**

1. **Build and deploy to device:**
   ```bash
   npm run build && npm run deploy
   ```

2. **Manual test on Roku:**
   - Navigate to new feature
   - Verify normal case works
   - Try error case (server offline, malformed data, timeout)
   - Check UI displays correctly (no cutoff, correct colors, proper focus)

3. **Document in phase UAT:**
   - Add scenario to `.planning/phases/XX-PHASE-NAME/UAT.md`
   - Record pass/fail
   - Note any issues discovered

4. **Fix and re-test:**
   - Make code change
   - Rebuild and redeploy
   - Re-verify on device

## Diagnostics

**Logging for debugging:**

Use `LogEvent()` and `LogError()` to track execution:

```brightscript
' In task node:
LogEvent("API request: GET /library/sections")
m.top.status = "loading"
' ... make request ...
LogEvent("API complete: /library/sections")
m.top.status = "completed"

' In screen:
LogEvent("HomeScreen init: finding nodes")
LogEvent("HomeScreen init: setting up observers")
```

**View Roku logs:**
- Connect Roku to network
- SSH into device or use Roku IDE
- Tail telnet output to see print() statements (which LogEvent/LogError emit)

**Build validation without deploy:**
```bash
npm run lint              # Syntax/type check only, no device needed
```

---

*Testing analysis: 2026-03-13*
