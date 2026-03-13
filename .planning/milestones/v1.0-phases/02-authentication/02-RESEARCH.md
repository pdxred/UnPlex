# Phase 2: Authentication - Research

**Researched:** 2026-02-09
**Domain:** Plex PIN-based OAuth, Roku authentication patterns, server discovery
**Confidence:** MEDIUM-HIGH

## Summary

Plex authentication uses a PIN-based OAuth flow where users enter a 4-digit code at plex.tv/link. The flow is well-documented and straightforward: POST to create PIN, poll GET to check authorization status, then fetch resources to discover available servers. Roku authentication patterns emphasize dual storage (registry + cloud), proper focus management, and graceful error handling. The existing PlexAuthTask implementation already handles basic PIN request/check but needs enhancement for expiration handling, server discovery, and connection testing.

The technical stack is already in place (PlexApiTask for HTTP, roRegistrySection for persistence, Task node pattern for async operations). Main challenges are connection fallback logic (testing local/remote/relay in priority order) and silent reconnection when server becomes unreachable mid-session.

**Primary recommendation:** Extend existing PlexAuthTask with server discovery logic, create new ServerConnectionTask for testing connections in priority order, add PIN expiration auto-refresh to prevent user-visible failures.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### PIN Entry Experience
- Full screen dedicated PIN display with large code and plex.tv/link URL prominently shown
- Spinner with status text ("Waiting for authorization...") while polling for confirmation
- Auto-refresh with new PIN if current PIN expires — user never has to manually retry
- Back button cancels PIN flow (standard Roku pattern)

#### Connection Fallback
- Connection priority: Local → Remote → Relay (fastest first)
- Silent retry across all connection types; only show error if ALL fail
- Auto-reconnect silently when server becomes unreachable mid-session; only interrupt user if reconnection fails after ~30s
- No offline mode — show friendly "Can't reach server" with retry option when completely offline

#### Session Handling
- Auto-redirect to PIN screen when auth token expires (401 response) — clear stored token, simple recovery
- "Sign Out" option available in Settings menu — clears token, returns to PIN screen
- "Change Server" option available in Settings menu — shows server list for multi-server users
- Persist auth token and selected server URI across app restarts — app launches directly to home

### Claude's Discretion
- Server selection UI (if user has multiple servers — list style, icons, connection status indicators)
- Exact polling interval for PIN confirmation
- Connection timeout values
- Error message wording

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

</user_constraints>

## Standard Stack

### Core (Already Available in Codebase)
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| PlexApiTask | Current | HTTP requests to Plex API | Existing infrastructure from Phase 1 |
| roRegistrySection | Roku built-in | Persistent storage for tokens | Roku standard for auth data |
| roUrlTransfer | Roku built-in | SSL/HTTPS communication | Required for Plex API calls |
| Task nodes | SceneGraph | Async operations | Prevents UI thread blocking |

### Supporting (Already Available)
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| GetPlexHeaders() | Current (utils.brs) | Standard Plex headers | Every Plex API call |
| SafeGet() | Current (utils.brs) | Null-safe JSON access | Parsing API responses |
| LogError/LogEvent | Current (logger.brs) | Event logging | Auth flow milestones |

### New Components Needed
| Component | Purpose | Pattern |
|-----------|---------|---------|
| PlexAuthTask | PIN request/check, server discovery | Extend existing with new actions |
| ServerConnectionTask | Connection testing (local/remote/relay) | New Task node |
| PINScreen | Full-screen PIN display | New screen component |

### No External Dependencies
BrightScript is a closed ecosystem. All authentication functionality uses built-in Roku APIs and Plex REST endpoints.

## Architecture Patterns

### Recommended Project Structure
```
PlexClassic/
├── components/
│   ├── tasks/
│   │   ├── PlexAuthTask.xml/.brs      # Extend: add server discovery action
│   │   └── ServerConnectionTask.xml/.brs  # NEW: connection testing
│   ├── screens/
│   │   └── PINScreen.xml/.brs         # NEW: PIN entry UI
│   └── widgets/
│       └── ServerList.xml/.brs        # NEW: server selection (if multiple)
└── source/
    └── utils.brs                      # Existing: token storage helpers
```

### Pattern 1: PIN Authentication Flow (Poll-Based)

**What:** Request PIN from plex.tv, display to user, poll until authorized or expired
**When to use:** Initial authentication, re-authentication on token expiry

**Flow:**
1. Task requests PIN: POST https://plex.tv/api/v2/pins?strong=true
2. UI displays PIN code and plex.tv/link URL
3. Task polls: GET https://plex.tv/api/v2/pins/{id} every 1-2 seconds
4. On authToken received: store token, transition to server discovery
5. On expiration (5 minutes): auto-request new PIN, update display

**Example (from existing PlexAuthTask.brs):**
```brightscript
' Source: PlexClassic/components/tasks/PlexAuthTask.brs (existing implementation)
sub requestPin()
    m.top.state = "loading"

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://plex.tv/api/v2/pins")

    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    url.AddHeader("Content-Type", "application/x-www-form-urlencoded")
    response = url.PostFromString("strong=true")

    json = ParseJson(response)
    if json <> invalid and json.id <> invalid
        m.top.pinId = json.id.ToStr()
        m.top.pinCode = json.code
        m.top.state = "pinReady"
    end if
end sub
```

**Enhancement needed:** Check json.expiresAt and auto-refresh when close to expiration.

### Pattern 2: Server Discovery (Resources Endpoint)

**What:** After authentication, fetch list of available servers with connection URIs
**When to use:** After PIN auth completes, after "Change Server" action

**Flow:**
1. GET https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1
2. Response contains array of servers with multiple connections each
3. Each connection has: uri, local (boolean), relay (boolean), protocol
4. Parse connections, group by type (local/remote/relay)
5. Test connections in priority order until one succeeds

**Expected Response Structure (from WebSearch findings):**
```json
{
  "MediaContainer": {
    "Device": [
      {
        "name": "My Plex Server",
        "clientIdentifier": "abc123...",
        "Connection": [
          {
            "uri": "http://192.168.1.10:32400",
            "local": "1",
            "relay": "0",
            "address": "192.168.1.10",
            "port": "32400",
            "protocol": "http"
          },
          {
            "uri": "https://12-34-56-78.abc123.plex.direct:32400",
            "local": "0",
            "relay": "0",
            "address": "12.34.56.78",
            "port": "32400",
            "protocol": "https"
          },
          {
            "uri": "https://relay.plex.tv:32400",
            "local": "0",
            "relay": "1",
            "protocol": "https"
          }
        ]
      }
    ]
  }
}
```

**Implementation Pattern:**
```brightscript
' Extend PlexAuthTask with new action: "fetchResources"
sub fetchResources()
    m.top.state = "loading"

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1")

    headers = GetPlexHeaders()
    headers["X-Plex-Token"] = GetAuthToken()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    response = url.GetToString()
    json = ParseJson(response)

    if json <> invalid
        m.top.servers = parseServerList(json)
        m.top.state = "serversReady"
    end if
end sub

function parseServerList(json as Object) as Object
    ' Extract servers from MediaContainer.Device array
    container = SafeGet(json, "MediaContainer", invalid)
    if container = invalid then return []

    devices = SafeGet(container, "Device", [])
    servers = []

    for each device in devices
        ' Only include servers that provide content
        if SafeGet(device, "provides", "") = "server"
            serverInfo = {
                name: SafeGet(device, "name", "Unknown Server")
                clientId: SafeGet(device, "clientIdentifier", "")
                connections: parseConnections(device.Connection)
            }
            servers.push(serverInfo)
        end if
    end for

    return servers
end function

function parseConnections(connArray as Object) as Object
    local = []
    remote = []
    relay = []

    for each conn in connArray
        connInfo = {
            uri: SafeGet(conn, "uri", "")
            address: SafeGet(conn, "address", "")
            port: SafeGet(conn, "port", "32400")
            protocol: SafeGet(conn, "protocol", "http")
        }

        isLocal = SafeGet(conn, "local", "0") = "1"
        isRelay = SafeGet(conn, "relay", "0") = "1"

        if isLocal
            local.push(connInfo)
        else if isRelay
            relay.push(connInfo)
        else
            remote.push(connInfo)
        end if
    end for

    return {local: local, remote: remote, relay: relay}
end function
```

### Pattern 3: Connection Testing (Priority Order)

**What:** Test server connections in priority order: Local → Remote → Relay
**When to use:** After server selection, on reconnection attempts

**Flow:**
1. Create ServerConnectionTask node
2. Pass connection array sorted by priority
3. Task tests each connection with timeout (3-5 seconds per attempt)
4. Test method: GET {uri}/ (root endpoint, lightweight)
5. First successful response wins, set as active server URI

**Implementation (new ServerConnectionTask):**
```brightscript
' ServerConnectionTask.brs
sub init()
    m.top.functionName = "testConnections"
end sub

sub testConnections()
    m.top.state = "testing"

    ' connections field contains array: [{uri, type}]
    connections = m.top.connections
    if connections = invalid or connections.count() = 0
        m.top.error = "No connections to test"
        m.top.state = "error"
        return
    end if

    for each conn in connections
        LogEvent("Testing connection: " + conn.type + " - " + conn.uri)

        url = CreateObject("roUrlTransfer")
        url.SetCertificatesFile("common:/certs/ca-bundle.crt")
        url.InitClientCertificates()
        url.SetUrl(conn.uri + "/")

        ' Set timeout (3 seconds)
        url.SetMessagePort(CreateObject("roMessagePort"))
        url.EnableEncodings(true)

        headers = GetPlexHeaders()
        headers["X-Plex-Token"] = GetAuthToken()
        for each key in headers
            url.AddHeader(key, headers[key])
        end for

        ' Synchronous test with timeout
        if url.AsyncGetToString()
            msg = wait(3000, url.GetPort())
            if type(msg) = "roUrlEvent" and msg.GetResponseCode() = 200
                LogEvent("Connection successful: " + conn.type)
                m.top.successfulUri = conn.uri
                m.top.connectionType = conn.type
                m.top.state = "connected"
                return
            end if
        end if

        LogEvent("Connection failed: " + conn.type)
    end for

    ' All connections failed
    m.top.error = "All connection attempts failed"
    m.top.state = "error"
end sub
```

### Pattern 4: Token Persistence (Registry)

**What:** Store auth token and server URI in Roku registry for persistence across restarts
**When to use:** After successful authentication, after server selection

**Source:** Roku Developer Documentation and existing utils.brs

**Existing Implementation (from utils.brs):**
```brightscript
' Source: PlexClassic/source/utils.brs (current implementation)
function GetAuthToken() as String
    sec = CreateObject("roRegistrySection", "PlexClassic")
    return sec.Read("authToken")
end function

sub SetAuthToken(token as String)
    sec = CreateObject("roRegistrySection", "PlexClassic")
    sec.Write("authToken", token)
    sec.Flush()  ' CRITICAL: must flush to persist
end sub

function GetServerUri() as String
    sec = CreateObject("roRegistrySection", "PlexClassic")
    return sec.Read("serverUri")
end function

sub SetServerUri(uri as String)
    sec = CreateObject("roRegistrySection", "PlexClassic")
    sec.Write("serverUri", uri)
    sec.Flush()
end sub
```

**Key Pattern:** ALWAYS call Flush() after Write() - writes are delayed and not committed to non-volatile storage until flush() is called.

### Pattern 5: Observer-Based Task Communication

**What:** UI observes Task state field, reacts to state changes
**When to use:** All async operations (PIN polling, server discovery, connection testing)

**Example:**
```brightscript
' In screen component init()
m.authTask = CreateObject("roSGNode", "PlexAuthTask")
m.authTask.observeField("state", "onAuthStateChange")
m.authTask.action = "requestPin"
m.authTask.control = "run"

' Callback
sub onAuthStateChange(event as Object)
    state = event.getData()

    if state = "pinReady"
        ' Update UI with PIN code
        m.pinLabel.text = m.authTask.pinCode
        ' Start polling
        m.timer.control = "start"  ' Timer triggers checkPin every 2 seconds

    else if state = "authenticated"
        ' Store token
        SetAuthToken(m.authTask.authToken)
        ' Proceed to server discovery
        fetchServers()

    else if state = "waiting"
        ' Still waiting for user to authorize
        ' Continue polling

    else if state = "error"
        ' Show error message
        m.errorLabel.text = m.authTask.error
    end if
end sub
```

### Anti-Patterns to Avoid

- **Using roUrlTransfer on render thread:** Always use Task nodes for HTTP requests to avoid rendezvous crashes (existing code already follows this)
- **Polling too aggressively:** Plex PINs expire in 5 minutes; polling every 1 second is reasonable, but faster is unnecessary network load
- **Not handling PIN expiration:** PINs expire in 5 minutes - auto-refresh instead of showing error to user
- **Testing all connections sequentially without timeout:** Use short timeouts (3-5 seconds) to fail fast, prioritize local first
- **Forgetting Flush() after registry Write():** Registry writes are not persisted until Flush() is called
- **Storing token in plain field:** Use registry, not m.global fields (security and persistence)
- **Not clearing token on 401:** If server returns 401, token is expired - clear it and redirect to PIN screen

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Custom parser | ParseJson() built-in | BrightScript provides reliable JSON parser |
| HTTP requests | Manual socket handling | roUrlTransfer in Task | Roku enforces SSL/HTTPS, manages certificates |
| Timer for polling | Custom loop with sleep | roTimespan or Timer node | Prevents blocking, integrates with message loop |
| Server reachability detection | Custom ping/socket test | GET request to / endpoint | Plex servers always respond to root with capabilities |
| Token encryption | Custom crypto | Registry isolation per channel | Roku isolates registry per channel ID |

**Key insight:** Roku provides all necessary primitives for authentication flows. The challenge is orchestrating them correctly (state management, error handling, priority logic) rather than implementing low-level functionality.

## Common Pitfalls

### Pitfall 1: PIN Expiration Not Handled
**What goes wrong:** User gets PIN, takes more than 5 minutes to authorize, PIN expires, polling returns error, user sees cryptic error message
**Why it happens:** Developer focuses on happy path (user authorizes quickly), doesn't check expiresAt field
**How to avoid:**
- Parse json.expiresAt from PIN response (ISO 8601 timestamp)
- Monitor time remaining during polling
- When < 30 seconds remaining OR polling returns expired error, auto-request new PIN
- Update UI with new code seamlessly
**Warning signs:** Error state during polling, user reports "code doesn't work"

### Pitfall 2: Connection Testing Blocks UI
**What goes wrong:** Testing 5-10 connections sequentially without timeout causes 30+ second freeze, user thinks app crashed
**Why it happens:** Developer doesn't set timeout on roUrlTransfer, failed connections wait for system timeout (30+ seconds)
**How to avoid:**
- Use AsyncGetToString() with message port and wait(timeout)
- Set aggressive timeout (3 seconds for local, 5 for remote)
- Test local first (usually succeeds immediately)
- Show spinner/status text during testing
**Warning signs:** App freezes after authentication, user force-quits

### Pitfall 3: Not Handling 401 Responses Globally
**What goes wrong:** Token expires mid-session, user navigates to library, API returns 401, app shows generic error, user stuck
**Why it happens:** 401 handling only in auth flow, not in PlexApiTask
**How to avoid:**
- In PlexApiTask, check response code (url.GetResponseCode())
- If 401: clear stored token, set global flag, interrupt current operation
- MainScene observes global flag, redirects to PIN screen
- User re-authenticates without losing place (after auth, return to previous screen)
**Warning signs:** User reports app "stops working" after several hours/days, requires restart

### Pitfall 4: Multiple Servers Handled Incorrectly
**What goes wrong:** User has 2+ servers, app auto-selects first from list (may be offline), no way to switch, user can't access their content
**Why it happens:** Developer assumes single server scenario, doesn't build server selection UI
**How to avoid:**
- After fetchResources, check servers.count()
- If > 1: show ServerList screen, let user pick
- Store selected server's clientId in registry (serverClientId)
- Add "Change Server" option in Settings
- On app launch: fetch resources, match stored clientId, test that server first
**Warning signs:** User reports "can't see my server", has multiple servers in account

### Pitfall 5: Silent Reconnection Too Aggressive
**What goes wrong:** Server goes offline, app retries every second, floods network, drains battery, still shows content from cache causing confusion
**Why it happens:** Developer interprets "silent reconnection" as "retry immediately and forever"
**How to avoid:**
- On API error: check if network-related (timeout, connection refused)
- First retry: immediate (might be transient blip)
- Subsequent retries: exponential backoff (2s, 4s, 8s, max 30s)
- After ~30 seconds total: show "Can't reach server" UI with manual retry button
- Don't cache old content - show spinner or error, not stale data
**Warning signs:** Network traffic spikes during server downtime, battery drain

### Pitfall 6: Registry Section Name Collision
**What goes wrong:** Two channels with same source code share registry section, token leak between channels, security risk
**Why it happens:** Using common section name like "Authentication" instead of app-specific name
**How to avoid:**
- Use unique section name tied to channel: "PlexClassic" (already done in existing code)
- Never use generic names like "auth", "user", "settings"
- Verify section name matches manifest title
**Warning signs:** Token mysteriously appears/disappears, works in one channel but not cloned version

## Code Examples

Verified patterns from official sources and existing codebase.

### PIN Polling with Auto-Refresh
```brightscript
' Enhanced checkPin with expiration handling
sub checkPin()
    pinId = m.top.pinId
    if pinId = "" then return

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://plex.tv/api/v2/pins/" + pinId)

    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    response = url.GetToString()
    json = ParseJson(response)

    if json = invalid then return

    ' Check for auth token (success case)
    if json.authToken <> invalid and json.authToken <> ""
        m.top.authToken = json.authToken
        SetAuthToken(json.authToken)
        m.top.state = "authenticated"
        return
    end if

    ' Check for expiration
    if json.expiresAt <> invalid
        expiresAt = CreateObject("roDateTime")
        expiresAt.FromISO8601String(json.expiresAt)
        now = CreateObject("roDateTime")

        secondsRemaining = expiresAt.AsSeconds() - now.AsSeconds()

        if secondsRemaining < 30
            ' PIN about to expire or expired - request new one
            LogEvent("PIN expiring, requesting new PIN")
            m.top.state = "refreshing"
            requestPin()  ' Automatically get new PIN
            return
        end if
    end if

    ' Still waiting
    m.top.state = "waiting"
end sub
```

### Connection Priority Builder
```brightscript
' Build ordered array of connections to test
function buildConnectionTestOrder(server as Object) as Object
    testOrder = []

    ' Priority 1: Local connections (fastest)
    for each conn in server.connections.local
        testOrder.push({uri: conn.uri, type: "local"})
    end for

    ' Priority 2: Remote connections
    for each conn in server.connections.remote
        testOrder.push({uri: conn.uri, type: "remote"})
    end for

    ' Priority 3: Relay connections (slowest, bandwidth limited)
    for each conn in server.connections.relay
        testOrder.push({uri: conn.uri, type: "relay"})
    end for

    return testOrder
end function
```

### 401 Detection in PlexApiTask
```brightscript
' Add to PlexApiTask.brs after response received
' Check for 401 Unauthorized (token expired)
responseCode = url.GetResponseCode()
if responseCode = 401
    LogError("401 Unauthorized - token expired")
    ' Clear stored token
    SetAuthToken("")
    ' Signal auth needed
    m.global.authRequired = true
    m.top.error = "Authentication required"
    m.top.state = "authRequired"  ' New state for 401
    return
end if
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Basic PIN auth (X-Plex-Token only) | JWT-based auth with JWK | 2024-2025 | Plex is introducing JWT auth with public-key cryptography for better security and shorter token lifespans |
| XML responses (default) | JSON responses (Accept header) | Ongoing | JSON is now standard for Plex API v2, must include Accept: application/json header |
| Single auth token forever | Short-lived JWT tokens | Rolling out 2025-2026 | Will require token refresh logic in future (not yet mandatory) |
| plex.tv resources endpoint | clients.plex.tv resources endpoint | v2 API | New endpoint for JWT compatibility |

**Deprecated/outdated:**
- MyPlex (old name for plex.tv service) - still works but outdated terminology
- /api/v1/pins - replaced by /api/v2/pins with better security
- Plain HTTP connections - Plex now prioritizes HTTPS, HTTP fallback only for local

**Current recommendation:** Implement current PIN auth (v2 API, X-Plex-Token) as described in CONTEXT.md decisions. JWT auth is newer and more complex but not yet required. When Plex mandates JWT, the pattern is well-documented and can be added as enhancement.

## Open Questions

1. **JWT Authentication Timeline**
   - What we know: Plex is introducing JWT auth with JWK (JSON Web Key) for better security
   - What's unclear: When will JWT auth become mandatory? Is PIN auth deprecated?
   - Recommendation: Implement current PIN auth (v2/pins endpoint with strong=true). Monitor Plex API announcements. JWT auth can be added later without major refactor since auth is isolated in PlexAuthTask.

2. **Connection Test Timeout Values**
   - What we know: Should prioritize local (fastest), then remote, then relay
   - What's unclear: Optimal timeout per connection type? Too short = false negatives, too long = poor UX
   - Recommendation: Start with 3s for local, 5s for remote/relay. Make configurable constant for tuning based on user feedback. Roku devices on WiFi typically see <500ms local response, <2s remote.

3. **Reconnection Backoff Strategy**
   - What we know: Silent reconnection for ~30s, then show error
   - What's unclear: Exact backoff intervals? How many retries before giving up?
   - Recommendation: Exponential backoff: immediate, 2s, 4s, 8s, 15s (total ~29s). Max 5 attempts. After that, show "Can't reach server" with manual retry. Prevents network flood while giving transient issues time to resolve.

4. **Server Selection UI Complexity**
   - What we know: Need UI for multiple servers, but user may have 1-10+ servers
   - What's unclear: How much server info to show? Icons? Connection status? Version?
   - Recommendation: Minimal MVP: LabelList with server name only. User picks, app tests connections. If testing fails, show next to name in red. Future enhancement: show connection type (local/remote), version, library count.

## Sources

### Primary (HIGH confidence)
- Existing codebase: PlexClassic/components/tasks/PlexAuthTask.brs, PlexApiTask.brs, source/utils.brs - Current implementation patterns
- Phase 1 plans: .planning/phases/01-foundation-architecture/01-01-PLAN.md, 01-02-PLAN.md - Established infrastructure (PlexApiTask, SafeGet, logging)
- [Plex API Documentation](https://plexapi.dev/api-reference/plex/get-a-pin) - PIN authentication endpoints
- [Python PlexAPI Documentation (Jan 2026)](https://python-plexapi.readthedocs.io/en/latest/modules/myplex.html) - PIN flow patterns, polling interval, expiration handling

### Secondary (MEDIUM confidence)
- [Plex API Resources Endpoint](https://plexapi.dev/api-reference/authentication/get-source-connection-information) - Server discovery, connection types
- [Roku Developer - roRegistrySection](https://developer.roku.com/docs/references/brightscript/components/roregistrysection.md) - Token persistence pattern
- [Roku Developer - Sign-in Best Practices](https://developer.roku.com/docs/developer-program/roku-pay/signin-best-practices.md) - Dual storage (registry + cloud), token validation
- [Roku Developer - Task Node](https://developer.roku.com/docs/references/scenegraph/control-nodes/task.md) - Observer pattern for async operations
- Multiple WebSearch results on Plex PIN expiration (5 minutes), polling interval (1 second standard)

### Tertiary (LOW confidence - needs validation)
- JWT authentication implementation details - documentation exists but timeline for mandatory adoption unclear
- Exact server version requirements for specific features - capabilities.brs from Phase 1 provides framework but version numbers approximate
- Connection timeout recommendations - no official Plex guidance found, recommendations based on general networking best practices

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Existing infrastructure already in place, Plex API well-documented
- Architecture: MEDIUM-HIGH - Patterns clear from existing code and official docs, some implementation details need testing
- Pitfalls: MEDIUM - Based on known Roku/Plex patterns and existing code review, but some scenarios untested

**Research date:** 2026-02-09
**Valid until:** ~30 days (Plex API stable, Roku platform stable, but JWT auth rollout may change requirements)

**Key uncertainties:**
- JWT auth migration timeline (monitor Plex developer announcements)
- Optimal timeout values (test on real Roku devices)
- Edge cases in multi-server scenarios (test with real user accounts)
