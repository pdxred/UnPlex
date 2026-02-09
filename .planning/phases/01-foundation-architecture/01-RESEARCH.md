# Phase 1: Foundation & Architecture - Research

**Researched:** 2026-02-09
**Domain:** Roku SceneGraph / BrightScript / Plex API
**Confidence:** HIGH

## Summary

This phase establishes the foundational patterns for a Roku Plex client: Task node patterns for HTTP requests, API abstraction layer, ContentNode normalization, and error handling. The existing codebase already has a working scaffold with `PlexApiTask`, `PlexAuthTask`, and basic UI components. This phase refines these patterns to match the decisions in CONTEXT.md.

The key technical constraints are: (1) all HTTP must occur in Task nodes to avoid render thread blocking, (2) SSL certificates must be explicitly configured on every `roUrlTransfer` instance, (3) Task nodes communicate with UI via field observers using the `state` field pattern, and (4) ContentNode trees are the standard data structure for all list/grid components.

**Primary recommendation:** Enhance the existing `PlexApiTask` with proper request/response fields matching CONTEXT.md decisions, create separate normalizer functions for JSON-to-ContentNode conversion, and implement a simple logging utility for debugging.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### API Abstraction Design
- Single PlexApiTask handles all API requests (pass endpoint/method as parameters)
- Independent requests - each call creates/runs its own task instance (parallel-friendly)
- Utility functions for URL building: `GetPlexUrl()` and `GetPlexHeaders()` helpers, task assembles and executes
- Raw JSON returned from task, separate normalizer functions convert to ContentNode (clean separation)

#### Task Node Patterns
- Fresh task instance created per request (no pooling/reuse)
- Observer callback naming: `onTaskNameComplete` (e.g., `onApiTaskComplete`, `onAuthTaskComplete`)
- Task signals completion via `state` field; check `response` and `error` fields when done
- Caller is responsible for cleanup: remove observer and reference when task completes

#### Error Handling Philosophy
- Minimal, non-intrusive user messages: brief toast for user-actionable errors (auth failed, server unreachable), silent for recoverable issues
- No automatic retry - fail fast, let user trigger retry via refresh
- Hide unsupported features: if server lacks a capability, hide that UI element entirely
- Logging: errors + key events (auth, server connect, playback start) - useful for debugging without noise

#### ContentNode Structure
- Camel case field names aligned with Roku conventions (title, description, posterUrl) - map from Plex names
- Standard `itemType` field to identify media types: 'movie', 'show', 'season', 'episode'
- Minimal metadata for list/grid items: id, title, posterUrl, itemType, watched status - full metadata on detail view
- Flat with references for nested data: separate requests per level, nodes reference parent via showId/seasonId

### Claude's Discretion
- Specific file organization within source/ and components/
- Exact utility function signatures
- Internal task field names beyond state/response/error
- Logger implementation details

### Deferred Ideas (OUT OF SCOPE)
None - discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| BrightScript | 3.x | Application logic | Only language for Roku |
| SceneGraph | RSG 1.3 | UI framework | Official Roku component system |
| Task node | Built-in | Background threading | Required for HTTP, registry access |
| roUrlTransfer | Built-in | HTTP requests | Official Roku networking object |
| roRegistrySection | Built-in | Persistent storage | Only persistent storage mechanism |
| ContentNode | Built-in | Data binding | Standard for all list/grid components |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| roDeviceInfo | Device metadata | X-Plex headers, capabilities |
| ParseJson | JSON parsing | All API responses |
| roMessagePort | Async messaging | Task node async patterns |
| StandardMessageDialog | Error dialogs | User-actionable errors only |

### Already in Project
The existing codebase includes:
- `PlexApiTask` - General API requests (needs enhancement per CONTEXT.md)
- `PlexAuthTask` - PIN-based authentication
- `PlexSearchTask` - Search queries
- `PlexSessionTask` - Playback progress reporting
- `ImageCacheTask` - Poster prefetching
- Utility functions in `utils.brs` and `constants.brs`

## Architecture Patterns

### Project Structure (Existing)
```
PlexClassic/
├── manifest                 # App manifest, version info
├── source/
│   ├── main.brs            # Entry point, message loop
│   ├── utils.brs           # URL building, headers, persistence
│   └── constants.brs       # Colors, layout, API constants
├── components/
│   ├── MainScene.xml/.brs  # Root scene, screen stack
│   ├── screens/            # Full-screen views
│   ├── widgets/            # Reusable UI components
│   └── tasks/              # Background Task nodes
└── images/                  # Icons, splash, placeholders
```

### Recommended Additions (Claude's Discretion)
```
source/
├── normalizers.brs         # JSON-to-ContentNode converters
└── logger.brs              # Simple logging utility

components/
└── widgets/
    └── Toast.xml/.brs      # Non-modal error toast (optional)
```

### Pattern 1: Task Node Request Pattern (Per CONTEXT.md)
**What:** Each API call creates a fresh task instance
**When to use:** All Plex API requests

```brightscript
' Source: CONTEXT.md decisions + Roku best practices
sub makeApiRequest(endpoint as String, params as Object)
    ' Fresh instance per request (no reuse)
    m.apiTask = CreateObject("roSGNode", "PlexApiTask")
    m.apiTask.observeFieldScoped("state", "onApiTaskComplete")
    m.apiTask.endpoint = endpoint
    m.apiTask.params = params
    m.apiTask.control = "run"
end sub

sub onApiTaskComplete(event as Object)
    state = event.getData()
    if state = "completed"
        response = m.apiTask.response
        ' Process response...
    else if state = "error"
        error = m.apiTask.error
        ' Handle error...
    end if

    ' Cleanup: remove observer and reference
    m.apiTask.unobserveFieldScoped("state")
    m.apiTask = invalid
end sub
```

### Pattern 2: ContentNode Normalization (Per CONTEXT.md)
**What:** Separate normalizer functions convert raw JSON to ContentNode
**When to use:** After every successful API response

```brightscript
' Source: CONTEXT.md decisions
function NormalizeMovieList(jsonArray as Object) as Object
    content = CreateObject("roSGNode", "ContentNode")
    for each item in jsonArray
        node = content.createChild("ContentNode")
        node.addFields({
            id: item.ratingKey            ' Plex: ratingKey -> id
            title: item.title             ' Same
            posterUrl: item.thumb         ' Plex: thumb -> posterUrl
            itemType: "movie"             ' Standard field
            watched: (item.viewCount <> invalid and item.viewCount > 0)
        })
    end for
    return content
end function

function NormalizeShowList(jsonArray as Object) as Object
    content = CreateObject("roSGNode", "ContentNode")
    for each item in jsonArray
        node = content.createChild("ContentNode")
        node.addFields({
            id: item.ratingKey
            title: item.title
            posterUrl: item.thumb
            itemType: "show"
            watched: false  ' Shows track at episode level
        })
    end for
    return content
end function
```

### Pattern 3: Observer Cleanup (Per CONTEXT.md)
**What:** Caller removes observers and references when task completes
**When to use:** Always after task completion

```brightscript
' Use observeFieldScoped to avoid removing other components' observers
task.observeFieldScoped("state", "onMyCallback")

' In callback, after processing:
task.unobserveFieldScoped("state")
m.task = invalid  ' Release reference
```

### Anti-Patterns to Avoid
- **Reusing task instances:** Creates state pollution - always create fresh
- **Missing SSL certificates:** Causes HTTPS failures - always set on roUrlTransfer
- **Render thread HTTP:** Causes crashes - always use Task nodes
- **Observer accumulation:** Causes duplicate callbacks - always cleanup
- **Direct Plex field names in UI:** Couples UI to API - use normalizers

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Custom parser | `ParseJson()` | Built-in, handles edge cases |
| HTTP requests | Custom networking | `roUrlTransfer` | Only option, well-documented |
| List/grid data | Custom arrays | `ContentNode` trees | Required by all Roku list components |
| Focus management | Manual tracking | `setFocus(true)` | Built-in focus system handles edge cases |
| Persistent storage | File I/O | `roRegistrySection` | Only sandboxed storage available |
| URL encoding | Manual escaping | `roUrlTransfer.Escape()` | Handles all special characters |

**Key insight:** Roku's SDK is constrained but complete. Every component has a single blessed approach. Deviating creates incompatibilities with built-in widgets.

## Common Pitfalls

### Pitfall 1: Render Thread HTTP Calls
**What goes wrong:** App crashes with "rendezvous timeout" or freezes
**Why it happens:** `roUrlTransfer` on render thread blocks UI
**How to avoid:** All HTTP in Task nodes, verify by code review
**Warning signs:** UI freezes during network requests, timeout errors in debug console

### Pitfall 2: Missing SSL Certificate Setup
**What goes wrong:** HTTPS requests fail silently or with unhelpful errors
**Why it happens:** Roku doesn't auto-configure certificates
**How to avoid:** Always include these two lines before ANY `roUrlTransfer` request:
```brightscript
url.SetCertificatesFile("common:/certs/ca-bundle.crt")
url.InitClientCertificates()
```
**Warning signs:** "Connection failed" errors, empty responses from HTTPS URLs

### Pitfall 3: ParseJson Returns Invalid
**What goes wrong:** Null pointer errors when accessing response data
**Why it happens:** Malformed JSON, XML response, or empty string
**How to avoid:** Always check `if json = invalid` before accessing fields
**Warning signs:** "roInvalid" in debug output, crashes on field access

### Pitfall 4: Observer Callback Duplication
**What goes wrong:** Same callback fires multiple times
**Why it happens:** Observer added multiple times without removal
**How to avoid:** Use `observeFieldScoped`/`unobserveFieldScoped`, cleanup in callback
**Warning signs:** Logs show duplicate processing, UI updates twice

### Pitfall 5: Task Node m.global State
**What goes wrong:** Stale data in task, unexpected values
**Why it happens:** Task's `m` is cloned at start, not live reference
**How to avoid:** Pass all needed data via task fields, don't rely on m.global in task
**Warning signs:** Task has different auth token than expected, old server URI

### Pitfall 6: Nested JSON Field Access
**What goes wrong:** "Member function not found" errors
**Why it happens:** Empty arrays or missing nested objects return wrong types
**How to avoid:** Check each level: `if response.MediaContainer <> invalid and response.MediaContainer.Metadata <> invalid`
**Warning signs:** Crashes on specific API responses, works for some but not others

## Code Examples

### Complete Task Node Implementation
```brightscript
' PlexApiTask.xml - Source: Roku Task node docs + CONTEXT.md
<?xml version="1.0" encoding="UTF-8"?>
<component name="PlexApiTask" extends="Task">
    <interface>
        <!-- Input fields -->
        <field id="endpoint" type="string" />
        <field id="params" type="assocarray" />
        <field id="method" type="string" value="GET" />

        <!-- Output fields -->
        <field id="response" type="assocarray" />
        <field id="error" type="string" />
        <field id="state" type="string" value="idle" />

        <!-- Optional: request identification -->
        <field id="requestId" type="string" />
    </interface>
    <script type="text/brightscript" uri="pkg:/source/utils.brs" />
    <script type="text/brightscript" uri="pkg:/source/constants.brs" />
    <script type="text/brightscript" uri="PlexApiTask.brs" />
</component>
```

### roUrlTransfer Setup (CRITICAL)
```brightscript
' Source: Roku roUrlTransfer docs, SSL certificate guidance
function createUrlTransfer(requestUrl as String) as Object
    url = CreateObject("roUrlTransfer")

    ' CRITICAL: SSL setup - MUST be before any request
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()

    url.SetUrl(requestUrl)

    ' Add all required Plex headers
    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    return url
end function
```

### Safe JSON Field Access
```brightscript
' Source: Roku community best practices
function safeGet(obj as Object, field as String, default as Dynamic) as Dynamic
    if obj = invalid then return default
    if type(obj) <> "roAssociativeArray" then return default
    if not obj.DoesExist(field) then return default
    return obj[field]
end function

' Usage:
metadata = safeGet(response, "MediaContainer", invalid)
items = safeGet(metadata, "Metadata", [])
```

### Simple Logger Implementation (Claude's Discretion)
```brightscript
' logger.brs - Source: Claude's discretion area
function Log(level as String, message as String)
    ' Only log errors and key events per CONTEXT.md
    if level = "ERROR" or level = "EVENT"
        timestamp = CreateObject("roDateTime").AsSeconds().ToStr()
        print "[" + timestamp + "] [" + level + "] " + message
    end if
end function

sub LogError(message as String)
    Log("ERROR", message)
end sub

sub LogEvent(message as String)
    Log("EVENT", message)
end sub
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single task reuse | Fresh task per request | Best practice | Prevents state pollution |
| observeField | observeFieldScoped | Roku OS 8.0+ | Safer cleanup, no side effects |
| XML API responses | JSON with Accept header | Plex API v2 | Simpler parsing |
| Global utility functions | Script includes in XML | SceneGraph design | No m.global function refs |

**Current Roku OS features (as of 2026):**
- Roku OS 15.0 includes move semantics for associative arrays (improved performance)
- observeFieldScoped/unobserveFieldScoped for safer observer management
- Better error messages in debug console

## Open Questions

1. **Plex Server Version Detection Timing**
   - What we know: `/` endpoint returns server capabilities including version
   - What's unclear: When to fetch (on connect? periodically?)
   - Recommendation: Fetch once on server connection, store in m.global

2. **JWT vs Legacy Token**
   - What we know: Plex is transitioning to JWT authentication
   - What's unclear: Timeline for legacy token deprecation
   - Recommendation: Continue using legacy tokens (PIN flow), monitor Plex announcements

3. **Error Toast Component**
   - What we know: CONTEXT.md specifies "brief toast for user-actionable errors"
   - What's unclear: Exact visual design, duration
   - Recommendation: Simple overlay rectangle with text, auto-dismiss after 3 seconds

## Sources

### Primary (HIGH confidence)
- [Roku Task Node Documentation](https://developer.roku.com/docs/references/scenegraph/control-nodes/task.md) - Threading model, state field pattern
- [Roku roUrlTransfer Documentation](https://developer.roku.com/docs/references/brightscript/components/rourltransfer.md) - HTTP methods, SSL setup
- [LearnRoku Crash Course - Lesson 3](https://github.com/learnroku/crash-course/blob/master/docs/Lesson3.md) - Task node patterns, HTTP examples
- [Plex Forum Authentication Guide](https://forums.plex.tv/t/authenticating-with-plex/609370) - PIN flow, X-Plex headers
- [Plexopedia API Capabilities](https://www.plexopedia.com/plex-media-server/api/server/capabilities/) - Server capabilities endpoint

### Secondary (MEDIUM confidence)
- [Plex Web API Overview](https://github.com/Arcanemagus/plex-api/wiki/Plex-Web-API-Overview) - Headers, pagination, filtering
- [Roku Community Forums](https://community.roku.com/) - Observer patterns, memory management
- Existing codebase analysis - Current implementation patterns

### Tertiary (LOW confidence)
- Training data knowledge on BrightScript edge cases - Needs validation during implementation

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Roku platform is well-documented, existing codebase validates
- Architecture Patterns: HIGH - CONTEXT.md decisions are clear, Roku patterns are established
- Pitfalls: HIGH - Well-documented across Roku community, verified in official docs

**Research date:** 2026-02-09
**Valid until:** 60 days (Roku platform stable, Plex API stable)
