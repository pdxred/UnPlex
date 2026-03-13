# Coding Conventions

**Analysis Date:** 2026-03-13

## Naming Patterns

**Files:**
- PascalCase for all BrightScript and XML component files: `MainScene.brs`, `HomeScreen.brs`, `PosterGrid.brs`
- XML layout files paired with `.brs` logic: `HomeScreen.xml` + `HomeScreen.brs`
- Task nodes (background threading): `PlexApiTask.brs`, `PlexAuthTask.brs`, `PlexSessionTask.brs`
- Widgets (reusable components): `Sidebar.brs`, `VideoPlayer.brs`, `PosterGrid.brs`
- Screens (full-screen views): `HomeScreen.brs`, `DetailScreen.brs`, `SearchScreen.brs`
- Utilities: `utils.brs`, `constants.brs`, `logger.brs`

**Functions and Subroutines:**
- camelCase for all function/sub declarations: `function GetAuthToken()`, `sub SetAuthToken()`
- Getters: `Get*` prefix for retrieval functions: `GetAuthToken()`, `GetServerUri()`, `GetConstants()`
- Setters: `Set*` prefix for storage functions: `SetAuthToken()`, `SetServerUri()`
- Event handlers: `on*` prefix in camelCase: `onAuthRequired()`, `onItemSelected()`, `onTaskStateChange()`
- Specialized handlers: `on<ScreenName><Event>`: `onHomeScreenState()`, `onPINScreenState()`
- Utility/builder functions: Descriptive names: `BuildPlexUrl()`, `BuildPosterUrl()`, `SafeGet()`, `SafeGetMetadata()`

**Variables:**
- camelCase for local variables: `token`, `serverUri`, `itemData`, `focusedNode`
- Prefixed temporary variables in loops: `item`, `lib`, `key`, `index`, `data`
- State variables in `m` (component member): `m.screenStack`, `m.focusStack`, `m.libraryTask`
- Global scope via `m.global`: `m.global.constants`, `m.global.authRequired`, `m.global.serverReconnected`
- Top-level node via `m.top`: `m.top.status`, `m.top.response`, `m.top.observeField()`

**Types and Objects:**
- Type hints in function signatures (BrightScript standard): `function GetAuthToken() as String`, `sub LogError(message as String)`
- Return types: `as String`, `as Object`, `as Integer`, `as Boolean`, `as Dynamic`
- Object creation: `CreateObject("roSGNode", "ScreenName")` for scene graph components
- AssociativeArrays for maps: `{ key: value, nested: { key2: value2 } }`
- Arrays for lists: `[]` for empty, `array.push(item)` for append

**Constants:**
- ALL_CAPS with underscores: `BG_PRIMARY`, `SIDEBAR_WIDTH`, `POSTER_HEIGHT`, `PLEX_PRODUCT`
- Grouped in `GetConstants()` function in `constants.brs`
- Accessed via `m.global.constants` (cached at startup in MainScene)
- Organized by category: Colors (0xRRGGBBAA), Layout (FHD dimensions), API endpoints, Pagination

## Code Style

**Formatting:**
- 4-space indentation (BrightScript standard)
- No auto-formatter configured - manual formatting required
- No linter installed (bsconfig.json has diagnostic filters enabled)
- `bsc` compiler (BrighterScript) used for build validation

**Linting:**
- `bsconfig.json` disables diagnostic codes: 1105 (missing explicit return), 1045 (shadowed vars), 1140 (unused vars)
- No pre-commit hooks enforcing style
- Manual code review for consistency

**Spacing and Blocks:**
- Blank lines between logical sections within functions
- Comments separate major functional blocks (see examples below)
- `end sub` and `end function` on separate lines
- Comments inline for non-obvious logic (e.g., "// 500ms debounce", "// Request timed out")

## Import Organization

**Script Includes (in XML):**
Scripts are included in component XML files in dependency order:
```xml
<script type="text/brightscript" uri="pkg:/source/utils.brs" />
<script type="text/brightscript" uri="pkg:/source/constants.brs" />
<script type="text/brightscript" uri="pkg:/source/logger.brs" />
<script type="text/brightscript" uri="ComponentName.brs" />
```

**Pattern:**
1. `utils.brs` - Utility functions (network, storage, helpers)
2. `constants.brs` - Constants definition
3. `logger.brs` - Logging functions
4. Component-specific logic (last, can call functions from above)

**Shared Access:**
- All functions from included scripts are globally accessible within the component
- `m.global.constants` used to avoid re-parsing constants
- No namespace pollution - all helpers are global functions

## Error Handling

**Strategy:** Defensive null-checking and graceful degradation

**Patterns:**

**Null/Invalid Checking:**
```brightscript
' Check if object is invalid before accessing
if obj = invalid then return default

' Check field existence
if not obj.DoesExist(field) then return default

' Safe nested access (prevents crashes on malformed API responses)
container = SafeGet(response, "MediaContainer", invalid)
if container = invalid then return []
```

**API Error Handling:**
- HTTP response codes checked explicitly: `if responseCode = 401` (auth required), `if responseCode < 0` (network error)
- 401 responses trigger `m.global.authRequired = true` (global signal to show PIN screen)
- Empty responses handled gracefully: scrobble/timeline endpoints return 200 with no body
- JSON parse failures logged but don't crash: `json = ParseJson(response)` followed by `if json = invalid`

**Task Node State Patterns:**
```brightscript
' Tasks use status field to signal completion
m.top.status = "loading"    ' Request in progress
m.top.status = "completed"  ' Success - response available
m.top.status = "error"      ' Failure - error field populated
m.top.status = "authRequired" ' 401 response
```

**Safe Access Helpers:**
- `SafeGet(obj, field, default)` - Returns default if obj invalid or field missing
- `SafeGetMetadata(response)` - Extracts `response.MediaContainer.Metadata` or returns `[]`

## Logging

**Framework:** Console-based (print statements)

**Levels:**
- `LogEvent(message)` - Key milestones, state changes, successful operations
- `LogError(message)` - Problems, failures, authentication issues

**Format:**
```
[YYYY-MM-DDTHH:MM:SSTZ] [ERROR] message
[YYYY-MM-DDTHH:MM:SSTZ] [EVENT] message
```

**When to Log:**

**LogEvent used for:**
- Authentication flow: "PIN requested", "Auth data cleared", "Auto-connected to server"
- API calls: "API request: GET /library/sections", "API complete: /library/sections"
- Screen transitions: "HomeScreen init", "Showing PIN screen", "Screen connected"
- State changes: "Observing field changes", "Server reconnected"

**LogError used for:**
- HTTP errors: "401 Unauthorized - authentication required", "API error: Invalid JSON response"
- Network failures: "Request timed out", "Request failed: [reason]"
- Data issues: "No servers found after authentication", "Invalid response from plex.tv"

**No verbose/debug logging** - Only errors and key events per CLAUDE.md

## Comments

**When to Comment:**
- Non-obvious logic or workarounds: "// LoadingSpinner removed - firmware SIGSEGV crash"
- State machine transitions: "// User switch successful - reset everything"
- API quirks: "// Some endpoints return empty 200 responses"
- Focus management: "// Recursively find deepest focused element"
- Complex calculations: "// Calculate threshold within 2 rows of list end"

**What NOT to comment:**
- Self-explanatory code: `m.navList.itemSize = [width, height]` doesn't need a comment
- Direct assignments: `m.grid = m.top.findNode("grid")` is clear
- Simple loops: `for each item in array` doesn't need explanation

**Comment Style:**
- Single-line comments with `'` prefix (BrightScript style)
- Comments on same line as code or above code
- Section separators for major blocks: `' ========== Section Name ==========`

**JSDoc/TSDoc:**
- Not used (BrightScript doesn't have standard documentation generators)
- Function purpose documented in comments above function
- Example (from source):
```brightscript
' Build standard Plex headers as associative array
function GetPlexHeaders() as Object
    ' ... implementation
end function
```

## Function Design

**Size:**
- Typical range: 10-50 lines
- Longer functions acceptable if cohesive (MainScene has ~500 lines but is screen manager)
- Extracted sub-tasks into separate functions when >100 lines

**Parameters:**
- Explicit type hints: `function LoadLibraries(path as String, limit as Integer) as Object`
- Task nodes accept fields via `m.top.fieldName = value` pattern (no function params)
- Optional parameters not formally supported - use defaults or check for invalid

**Return Values:**
- Functions indicate success via return type: `function ParseJson(str as String) as Object` returns `invalid` on parse failure
- No exception throwing (Roku doesn't support)
- Task nodes use `m.top.status` and `m.top.response`/`m.top.error` pattern
- Subroutines (void) use side effects: `SetAuthToken()` modifies registry

**Example Patterns:**

Safe getter pattern:
```brightscript
function GetAuthToken() as String
    sec = CreateObject("roRegistrySection", "SimPlex")
    return sec.Read("authToken")
end function
```

Event handler with state dispatch:
```brightscript
sub onPINScreenState(event as Object)
    state = event.getData()
    if state = "authenticated"
        ' ... handle success
    else if state = "cancelled"
        ' ... handle cancel
    end if
end sub
```

## Module Design

**Exports:**
- All public functions are globally accessible (BrightScript global scope)
- Task nodes export via `m.top` field interface
- Component callbacks registered via `observeField()`

**Barrel Files:**
- Not used (BrightScript uses direct script includes in XML)
- Each component includes needed scripts explicitly

**Component Pattern:**
```brightscript
' In component XML:
<script type="text/brightscript" uri="pkg:/source/utils.brs" />
<script type="text/brightscript" uri="ComponentName.brs" />

' In ComponentName.brs:
sub init()
    ' Set up node references
    m.top.observeField("fieldName", "onFieldChange")
end sub

sub onFieldChange(event as Object)
    ' Handle field change
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' Handle remote control input
    return false ' return true if consumed
end function
```

## Observable/Field Pattern

Components communicate via field observers (SceneGraph reactive system):

```brightscript
' Parent observes child state
child.observeField("status", "onChildStatusChange")

' Child signals parent
m.top.status = "completed"  ' Triggers observer callback

' Global fields for cross-component communication
m.global.observeField("authRequired", "onAuthRequired")
m.global.authRequired = true  ' Propagates to all observers
```

This pattern used throughout for:
- Task → Screen communication (task.status = "completed" triggers screen handler)
- Global signals (authRequired, serverReconnected, watchStateUpdate)
- Screen stacking (itemSelected event pops/pushes screens)

---

*Convention analysis: 2026-03-13*
