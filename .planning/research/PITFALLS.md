# Pitfalls Research

**Domain:** Roku SceneGraph + Plex Client Development
**Researched:** 2026-02-09
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: HTTP Requests on Render Thread (Rendezvous Crash)

**What goes wrong:**
Application crashes with "roUrlTransfer: creating MAIN|TASK-only component failed on RENDER thread" error. The app experiences rendezvous timeouts causing UI freezes or complete crashes.

**Why it happens:**
Developers coming from web/mobile backgrounds instinctively put network code in component initialization or UI event handlers. BrightScript allows roUrlTransfer creation on the render thread without immediate error, but execution causes thread rendezvous that can timeout and crash.

**How to avoid:**
- ALL HTTP requests MUST be made from Task nodes, never from component init() or UI handlers
- Create dedicated Task nodes for each HTTP operation category (PlexAuthTask, PlexApiTask, PlexSearchTask, PlexSessionTask)
- Pass parameters to Task via interface fields, trigger with control="run", receive results via field observers
- Never call roUrlTransfer.AsyncGetToString() or any HTTP methods from main scene thread

**Warning signs:**
- Intermittent crashes during network operations
- Debug logs showing "RENDER thread" errors
- UI freezing during API calls
- Crash dumps mentioning "rendezvous timeout"

**Phase to address:**
Phase 1 (Authentication) - Establish Task node pattern immediately. All subsequent phases inherit this architecture.

---

### Pitfall 2: Missing HTTPS Certificate Configuration

**What goes wrong:**
SSL error code -60: "unable to get issuer certificate" or error code -77 (CURLE_SSL_CACERT_BADFILE). All HTTPS requests to Plex servers fail silently or with cryptic errors.

**Why it happens:**
Unlike web browsers, Roku doesn't have default certificate trust. Developers must explicitly configure certificates for every roUrlTransfer instance. Easy to forget or place incorrectly in code flow.

**How to avoid:**
```brightscript
' ALWAYS include these two lines for HTTPS requests
urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
urlTransfer.InitClientCertificates()
' Order matters: SetCertificatesFile BEFORE InitClientCertificates
```
- Add to utility function that all Tasks use
- Use common:/certs/ca-bundle.crt (built into Roku firmware)
- Call BEFORE setting URL or making request

**Warning signs:**
- API calls to plex.tv return empty/invalid responses
- Works in simulator but fails on device
- Logs show SSL error codes -60 or -77
- Successful HTTP requests but HTTPS fails

**Phase to address:**
Phase 1 (Authentication) - Must be correct from first plex.tv API call. Create GetPlexHeaders() utility that includes certificate setup.

---

### Pitfall 3: Missing X-Plex Headers

**What goes wrong:**
Plex API returns 401 Unauthorized or "Missing required path parameter X-Plex-Client-Identifier" errors. Authentication fails intermittently. Server discovery returns empty results.

**Why it happens:**
Plex requires specific headers on EVERY request to identify the client. Documentation is scattered and incomplete. Developers add X-Plex-Token but miss other required headers.

**How to avoid:**
Create utility function that returns ALL required headers:
```brightscript
function GetPlexHeaders(token = "" as String) as Object
    headers = {
        "X-Plex-Client-Identifier": GetDeviceUniqueId() ' UUID per device
        "X-Plex-Product": "PlexClassic"
        "X-Plex-Version": "1.0.0"
        "X-Plex-Platform": "Roku"
        "X-Plex-Platform-Version": GetOSVersion()
        "X-Plex-Device": GetDeviceModel()
        "X-Plex-Device-Name": GetDeviceName()
        "X-Plex-Provides": "player"
    }
    if token <> "" then headers["X-Plex-Token"] = token
    return headers
end function
```
- Use on EVERY Plex API call (plex.tv and PMS)
- X-Plex-Client-Identifier MUST be persistent UUID (store in registry)
- Never use reserved headers like "X-Roku-Reserved-Dev-Id" (causes SSL errors)

**Warning signs:**
- Intermittent 401 errors
- "Missing required parameter" errors
- Server discovery API returns empty list
- Works with curl/Postman but not in Roku app

**Phase to address:**
Phase 1 (Authentication) - Define GetPlexHeaders() before first API call. All phases use this function.

---

### Pitfall 4: Memory Leaks from Node Cycles

**What goes wrong:**
Channel memory usage grows over time. Eventually crashes with out-of-memory errors on lower-end Roku devices. Nodes that should be garbage collected persist indefinitely.

**Why it happens:**
BrightScript uses reference counting for memory management. Circular references (node A references node B, B references A) prevent garbage collection. Common when nodes observe each other or parent/child relationships create cycles.

**How to avoid:**
- NEVER store references to parent/ancestor nodes in child node fields
- Call unobserveField() in component cleanup before removing from tree
- Use weak references pattern: store node ID instead of node reference, look up when needed
- Clear ContentNode children arrays before removing screens: `screenNode.removeChildren(screenNode.getChildren(-1, 0))`
- Test with Roku Resource Monitor to track node count over time

**Warning signs:**
- Node count increases but never decreases (check via SceneGraph debugging)
- Memory usage grows during navigation then returning to previous screens
- Crashes on older/low-memory Roku devices after extended use
- Multiple observer callbacks firing for same field change

**Phase to address:**
Phase 2 (Navigation/Screens) - Implement proper cleanup pattern when popping screen stack. Add to MainScene.brs screen removal logic.

---

### Pitfall 5: Observer Pattern Anti-Patterns

**What goes wrong:**
Callback functions fire multiple times for single field change. Task observers trigger after Task node is removed. Memory leaks from accumulated observer callbacks.

**Why it happens:**
observeField() ADDS a callback, doesn't replace existing ones. Developers call observeField() in init() then again when reusing a Task. No automatic cleanup when nodes are removed.

**How to avoid:**
```brightscript
' ALWAYS unobserve before re-observing
task.unobserveField("state")
task.observeField("state", "onTaskStateChange")

' Unobserve in cleanup BEFORE removing node
sub cleanup()
    if m.currentTask <> invalid
        m.currentTask.unobserveField("state")
        m.currentTask.unobserveField("response")
        m.currentTask = invalid
    end if
end sub
```
- Each observeField() call adds another callback to the queue
- unobserveField() before setting node to invalid
- Don't reuse Task nodes if they have callbacks
- Check if callback function checks node validity: `if m.task = invalid then return`

**Warning signs:**
- Callback function executes 2, 3, 4+ times for single change
- Crashes with "field not found" in observer callback
- Observer fires after navigating away from screen
- Memory leaks that correlate with Task usage

**Phase to address:**
Phase 1 (Authentication) - Establish pattern in first Task node implementation. Document in utils.brs.

---

### Pitfall 6: Plex Token Invalidation

**What goes wrong:**
User successfully authenticates, but requests fail with 401 Unauthorized hours/days later. App requires re-authentication every launch. Token saved in registry becomes invalid.

**Why it happens:**
Plex invalidates tokens when user changes password, removes device from account, or after extended inactivity. App doesn't detect token invalidation and continues using stale token. No refresh token mechanism in Plex PIN flow.

**How to avoid:**
- Store token AND validated timestamp in registry
- Implement 401 detection in all API calls: if response code = 401, clear token and redirect to auth
- Validate stored token on app launch: GET /user with X-Plex-Token
- Provide "Sign Out" option that clears registry token
- Don't assume PIN authentication is permanent - expect re-auth

**Warning signs:**
- Works after fresh authentication but fails later
- 401 errors after app has been closed and reopened
- Users report needing to re-authenticate frequently
- API calls fail after user changes Plex password

**Phase to address:**
Phase 1 (Authentication) - Build token validation into auth flow. Add 401 handler to API utility functions.

---

### Pitfall 7: Library Pagination Failure

**What goes wrong:**
Large libraries (>1000 items) load partially or hang. UI shows first 50-100 items but never loads more. Memory crashes when loading massive libraries without pagination.

**Why it happens:**
Plex API returns 50 items by default. Developers don't implement X-Plex-Container-Start/Size headers. Attempting to load entire 10,000-item library in one request crashes or times out.

**How to avoid:**
```brightscript
' Always paginate library requests
headers["X-Plex-Container-Start"] = m.currentOffset.ToStr()
headers["X-Plex-Container-Size"] = "50"

' Check response for totalSize, load more if needed
totalSize = xml.GetNamedElements("MediaContainer")[0].size
if m.currentOffset + 50 < totalSize then
    m.currentOffset = m.currentOffset + 50
    m.loadMoreTask.control = "run"
end if
```
- Use X-Plex-Container-Start and X-Plex-Container-Size on /library/sections/{id}/all requests
- Implement "load more" pattern when user scrolls near end of grid
- Check MediaContainer@size vs MediaContainer@totalSize in response
- Start with size=50, increase to 100 if performance allows

**Warning signs:**
- Grid shows exactly 50 items regardless of library size
- Memory usage spikes with large libraries
- Timeouts on library browse requests
- Users report missing items in large collections

**Phase to address:**
Phase 3 (Library Browsing) - Implement pagination from start. Never load unpaginated library lists.

---

### Pitfall 8: Poster Image Loading Without Scaling

**What goes wrong:**
App loads slowly and consumes excessive memory. Crashes on devices with limited RAM. Grid scrolling is janky. Each poster loads full-resolution image (2000x3000px) when only displaying 240x360.

**Why it happens:**
Plex returns full-resolution poster URLs by default. Poster component loads entire image into memory before scaling. Developers forget to set loadWidth/loadHeight or set them after uri.

**How to avoid:**
```brightscript
' CRITICAL: Set load dimensions BEFORE setting uri
posterNode = createObject("roSGNode", "Poster")
posterNode.loadWidth = 240
posterNode.loadHeight = 360
posterNode.loadDisplayMode = "scaleToFit"
' NOW set uri - image loads scaled
posterNode.uri = posterUrl
```
- Use Plex transcode API for posters: `/photo/:/transcode?url={posterKey}&width=240&height=360`
- Property order matters: load* properties MUST be set before uri
- Match loadWidth/loadHeight to display size (don't load 1920x1080 to show 240x360)
- Compress images, prefer non-SSL URLs where possible

**Warning signs:**
- Slow grid population (>5 seconds for 50 items)
- Memory usage grows rapidly when browsing library
- Out of memory crashes during scrolling
- Graphics memory warnings in debug logs

**Phase to address:**
Phase 3 (Library Browsing) - Implement in PosterGrid component from start. Use ImageCacheTask with proper scaling.

---

### Pitfall 9: ContentNode Creation in Loops

**What goes wrong:**
Grid takes 5-10 seconds to populate with 100 items. UI freezes during library loading. User thinks app has crashed.

**Why it happens:**
ContentNode creation is 30-50x slower than AssociativeArray creation. Creating ContentNodes in tight loops blocks render thread. Benchmarks show 649ms for 2000 ContentNodes vs 3ms for 2000 AAs.

**How to avoid:**
```brightscript
' Do heavy ContentNode creation in Task, not UI thread
' Task node:
sub processLibraryData()
    content = createObject("roSGNode", "ContentNode")
    for each item in m.top.rawData
        child = content.createChild("ContentNode")
        child.addFields({
            title: item.title
            hdPosterUrl: item.thumb
            ratingKey: item.ratingKey
        })
    end for
    m.top.processedContent = content
end sub

' Main scene observes processedContent field, assigns to grid
m.posterGrid.content = task.processedContent
```
- Build ContentNode trees in background Task, pass completed tree to UI
- Use addFields() to set multiple fields at once (faster than individual assignments)
- Consider caching ContentNode trees for recently viewed screens
- Batch updates: build complete tree before assigning to grid.content

**Warning signs:**
- Multi-second delay when loading grids
- Frame rate drops during library browsing
- CPU usage spikes when populating lists
- Render thread shows high activity in profiler

**Phase to address:**
Phase 3 (Library Browsing) - Use Task-based ContentNode creation pattern. Never build large ContentNode trees on render thread.

---

### Pitfall 10: Registry Write Without Flush

**What goes wrong:**
User settings disappear after app restart. Authentication token lost on device reboot. Selected server forgotten. Users complain about having to reconfigure app repeatedly.

**Why it happens:**
Registry writes are buffered. Without Flush(), data stays in memory but never persists to storage. Power loss or crash before flush = data loss. Developers assume Write() is sufficient.

**How to avoid:**
```brightscript
' ALWAYS flush after registry writes
registry = createObject("roRegistrySection", "PlexClassic")
registry.Write("authToken", token)
registry.Write("serverUrl", serverUrl)
registry.Flush()  ' Critical - don't skip this
```
- Call Flush() after every registry write operation
- Flush is expensive (slow), so batch writes then flush once
- Registry survives app exit and device reboot ONLY after flush
- Test by killing app process before flush to verify data persists

**Warning signs:**
- Settings lost after app crash
- Inconsistent data persistence (sometimes works, sometimes doesn't)
- User authentication lost on device reboot
- Works in development but fails on published app

**Phase to address:**
Phase 1 (Authentication) - Establish registry pattern from first token storage. Create utility function that includes flush.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip pagination, load all library items | Simpler code, no scroll tracking | Memory crashes on large libraries, slow load times | NEVER - even small libraries can grow |
| Reuse single Task node for all API calls | Fewer nodes to manage | Race conditions, observer conflicts, difficult debugging | NEVER - create Task per operation type |
| Store nodes in AA instead of proper cleanup | Easier to access later | Memory leaks from circular references | NEVER - use proper unobserve/remove |
| Skip certificate configuration in dev | Faster local testing | Fails on device, blocks production deployment | Only for pure offline/mock testing |
| Hardcode X-Plex-Client-Identifier | Works immediately | Breaks multi-device, violates Plex guidelines | NEVER - must be unique per device |
| Load full-size images without scaling | Works on high-end devices | Crashes on low-end Rokus, slow performance | NEVER - always scale at load time |
| Skip token validation on startup | Faster app launch | Silent failures, poor UX when token expires | Only if auth flow is extremely robust |
| Build ContentNode trees on render thread | Simpler Task management | UI freezes, poor UX, app feels broken | Only for <10 items |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Plex PIN Auth | Poll immediately after PIN creation | Wait for user to see PIN code, then start polling every 1s, max 5 minutes |
| Server Discovery | Use first server from /resources | Present server list, prioritize local connections, respect user choice |
| Playback Progress | Report every position change | Debounce, report every 10s during playback, on pause, and on stop |
| Direct Play Detection | Assume all content can Direct Play | Check codec, resolution, audio format against Roku capabilities before deciding |
| Transcode URLs | Use same URL for entire playback | Transcode URLs expire; handle 404 and request new transcode decision |
| Server Connections | Always use HTTPS | Try HTTPS first, fall back to HTTP for local connections if HTTPS fails |
| Auth Token in URL | Include token in query params for all requests | Use X-Plex-Token header; only use URL query for direct video playback |
| Library Sections | Assume section keys are sequential | Use actual section key from API response; keys are arbitrary strings |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unpaginated library loads | Slow grid population, memory warnings | Always paginate: X-Plex-Container-Size=50 | Libraries >500 items |
| Synchronous image loading | UI freezes while images load | Use loadWidth/loadHeight, transcode URLs | Grids with >20 posters |
| Full ContentNode tree on render thread | Multi-second UI freezes | Build ContentNode in Task, assign completed tree | >50 nodes |
| Observer accumulation | Multiple callbacks per change | unobserveField() before removing nodes | After 10+ screen navigations |
| Registry flush in loops | Slow settings updates | Batch writes, flush once at end | Any loop >5 iterations |
| Missing Task node cleanup | Memory growth over time | Set task = invalid after reading results | After 50+ Task executions |
| Global AA for large datasets | Deep copy overhead | Use ContentNode (passed by reference) | Data structures >100 items |
| Poster URLs without transcoding | High bandwidth usage | Use /photo/:/transcode with width/height | Grids with >10 full-res images |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging auth tokens | Token leakage via debug logs, telemetry | Never log X-Plex-Token; redact in error reporting |
| Hardcoded client identifier | All devices appear as same client, possible ban | Generate UUID on first launch, store in registry |
| Token in URL for API calls | Token visible in network logs, proxy logs | Use X-Plex-Token header except for video playback |
| No token validation on startup | App continues with invalid token, poor UX | Validate token with /user endpoint on app launch |
| Storing passwords | Plex uses OAuth PIN flow, no password storage needed | NEVER store passwords; use PIN auth only |
| Missing HTTPS for plex.tv | Man-in-the-middle attacks, token theft | Always use HTTPS for plex.tv, configure certificates |
| Exposing server token in logs | Local server access compromise | Treat server URLs with tokens as sensitive |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No loading indicators | User thinks app is frozen | Show spinner during API calls, progress bars for large loads |
| Silent authentication failures | App appears broken, no error shown | Display clear error messages, offer "Retry" and "Sign Out" |
| Losing grid position on back | User must scroll to find their place | Store scroll index in screen node, restore on back navigation |
| No empty state messaging | Blank screen when library is empty | Show "No items found" with icon and helpful text |
| Immediate failure on token error | Jarring re-authentication flow | Attempt silent token refresh first, show message if that fails |
| Missing connection status | User doesn't know if server is unreachable | Show connection status in settings, warn before attempting actions |
| No server selection UI | User stuck with wrong/offline server | Allow server switching without full re-authentication |
| Playback starts without buffer | Instant playback attempt, then buffering pause | Pre-buffer 2-3 seconds before starting playback |
| No intro/credits skip feedback | User presses button, nothing happens | Show confirmation toast "Intro skipped" when successful |

## "Looks Done But Isn't" Checklist

- [ ] **HTTP Requests:** Task nodes used for ALL requests - verify no roUrlTransfer on render thread
- [ ] **HTTPS Certificates:** SetCertificatesFile + InitClientCertificates on every HTTPS request - check all Task nodes
- [ ] **X-Plex Headers:** ALL 8 required headers on every Plex API call - audit API utility functions
- [ ] **Pagination:** X-Plex-Container-Start/Size on library requests - check /all and /search endpoints
- [ ] **Image Scaling:** loadWidth/loadHeight set BEFORE uri - verify property order in all Poster uses
- [ ] **Observer Cleanup:** unobserveField() before node removal - audit all component cleanup methods
- [ ] **Registry Flush:** Flush() after all Write() operations - search codebase for Write() calls
- [ ] **Token Validation:** Check token validity on startup and handle 401 responses - test with expired token
- [ ] **Memory Cleanup:** removeChildren() and node=invalid in screen removal - verify screen stack management
- [ ] **ContentNode Performance:** Large trees built in Task, not render thread - profile grid population
- [ ] **Focus Restoration:** Store and restore focus index on back navigation - test multi-level navigation
- [ ] **Error Handling:** API failures show user-friendly errors - test with network disabled

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| HTTP on render thread | HIGH | Refactor all network code into Task nodes; significant architecture change |
| Missing certificates | LOW | Add 2 lines to Task node utility; test on device |
| Missing X-Plex headers | MEDIUM | Create GetPlexHeaders() utility; update all API calls to use it |
| Memory leaks (node cycles) | HIGH | Audit entire codebase for observers and node references; add cleanup |
| No pagination | MEDIUM | Add pagination to API calls; implement load-more UI pattern |
| Image loading without scaling | LOW | Fix property order, add transcode parameters; simple code change |
| Observer anti-patterns | MEDIUM | Add unobserveField() calls; requires testing all flows |
| Token invalidation handling | MEDIUM | Add validation on launch, 401 detection; update auth flow |
| ContentNode on render thread | MEDIUM | Move to Task-based creation; refactor grid population logic |
| Registry without flush | LOW | Add Flush() calls; one-line fix per write location |
| Lost focus on navigation | MEDIUM | Add focus index tracking to screen nodes; test navigation flows |
| No SceneGraph 1.3 declaration | LOW | Add rsg_version=1.3 to manifest before Oct 2026 |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| HTTP on render thread | Phase 1: Authentication | All HTTP in Task nodes; debug logs show no render thread roUrlTransfer |
| Missing HTTPS certificates | Phase 1: Authentication | plex.tv API calls succeed on physical device |
| Missing X-Plex headers | Phase 1: Authentication | Token received, servers discovered; no 401 errors |
| Observer anti-patterns | Phase 1: Authentication | Observer fires once per field change; no multi-trigger |
| Token invalidation | Phase 1: Authentication | App handles expired token, redirects to auth |
| Registry without flush | Phase 1: Authentication | Token persists after app kill and device reboot |
| Memory leaks (node cycles) | Phase 2: Navigation | Node count stable over 20+ screen navigations |
| Focus restoration | Phase 2: Navigation | Focus position correct when pressing back button |
| Library pagination | Phase 3: Library Browsing | Libraries >1000 items load correctly |
| Image loading without scaling | Phase 3: Library Browsing | Memory usage <50MB with 100 posters visible |
| ContentNode on render thread | Phase 3: Library Browsing | Grid populates in <1s with 100 items |
| Direct Play detection | Phase 4: Playback | Content plays without unnecessary transcoding |
| Playback progress tracking | Phase 4: Playback | Resume position accurate after app restart |
| SceneGraph 1.3 manifest | Pre-launch: Certification | manifest contains rsg_version=1.3 |

## Sources

**Roku SceneGraph & BrightScript:**
- [Roku SceneGraph Threads Documentation](https://sdkdocs-archive.roku.com/SceneGraph-Threads_4262152.html) - MEDIUM confidence
- [Understanding Threads in Roku Development](https://medium.com/@amitdogra70512/understanding-threads-in-roku-development-d890fa2fa9b5) - MEDIUM confidence
- [Rendezevous in Roku](https://medium.com/@amitdogra70512/rendezevous-in-roku-bd55d81fc994) - MEDIUM confidence
- [Task in Roku](https://www.oodlestechnologies.com/blogs/task-in-roku/) - MEDIUM confidence
- [Roku Memory Management](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md) - HIGH confidence (attempted)
- [Roku SceneGraph Debugging](https://sdkdocs-archive.roku.com/Debugging-SceneGraph-Applications_3736509.html) - MEDIUM confidence
- [SSL Certificate Problem Community Thread](https://community.roku.com/t5/Roku-Developer-Program/SSL-certificate-problem-unable-to-get-issuer-certificate/td-p/496742) - MEDIUM confidence
- [Roku Poster Component Property Order](https://briandunnington.github.io/poster_property_order) - HIGH confidence
- [Optimizing Roku UI Tips and Tricks](https://medium.com/@amitdogra70512/optimizing-roku-ui-tips-and-tricks-dd9d8b1a36e4) - MEDIUM confidence
- [Image Optimization in Roku](https://www.tothenew.com/blog/image-optimisation-in-roku/) - MEDIUM confidence
- [Mastering Focus Handling in Roku](https://www.tothenew.com/blog/mastering-focus-handling-in-roku-a-comprehensive-guide-to-focus-handling-through-mapping/) - MEDIUM confidence
- [Managing Screen Back Stack in Roku](https://roku.home.blog/2019/01/02/back-stack-management-in-roku-using-scenegraph-component/) - MEDIUM confidence
- [Roku Registry Discussion](https://community.roku.com/t5/Roku-Developer-Program/Anyone-seen-a-save-registry-value-fail/td-p/263592) - MEDIUM confidence
- [ContentNode Performance Discussion](https://community.roku.com/t5/Roku-Developer-Program/Performance-of-creating-ContentNode-v-roArray-roAA/td-p/470963) - HIGH confidence
- [Roku SceneGraph 1.3 Certification](https://blog.roku.com/developer) - MEDIUM confidence

**Plex API & Authentication:**
- [Plex API Authentication Forum](https://forums.plex.tv/t/authenticating-with-plex/609370) - HIGH confidence
- [Finding Plex Authentication Token](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/) - HIGH confidence
- [Plex Media Server Documentation](https://developer.plex.tv/pms/) - HIGH confidence
- [Plex X-Plex Headers Documentation](https://github.com/phillipj/node-plex-api-headers) - MEDIUM confidence
- [Plex Client Identifier Gist](https://gist.github.com/philipjewell/2b721ccde6f251f67454dd04829cef4b) - MEDIUM confidence
- [Plex Server Discovery Resources](https://support.plex.tv/articles/206721658-using-plex-tv-resources-information-to-troubleshoot-app-connections/) - HIGH confidence
- [Plex API Pagination Documentation](https://plexapi.dev/api-reference/library/get-all-media-of-library) - HIGH confidence
- [Plex Direct Play Documentation](https://support.plex.tv/articles/200250387-streaming-media-direct-play-and-direct-stream/) - HIGH confidence
- [Plex PIN Authentication Implementation](https://github.com/harrisonhoward/plex_pin_auth) - MEDIUM confidence
- [Plex Token Invalidation Issues](https://github.com/goauthentik/authentik/issues/17089) - MEDIUM confidence

**Community Experience (Training Data):**
- Personal knowledge of BrightScript render thread limitations - LOW confidence (not verified with 2026 docs)
- ContentNode performance benchmarks from community testing - MEDIUM confidence
- Registry flush behavior based on community reports - MEDIUM confidence

---
*Pitfalls research for: PlexClassic Roku Channel*
*Researched: 2026-02-09*
