# Coding Conventions

**Analysis Date:** 2026-03-08

## Naming Patterns

**Files:**
- BrightScript files: PascalCase matching component name (e.g., `HomeScreen.brs`, `PlexApiTask.brs`, `PosterGrid.brs`)
- XML files: PascalCase matching component name (e.g., `HomeScreen.xml`, `PlexApiTask.xml`)
- Source utility files: camelCase (e.g., `utils.brs`, `logger.brs`, `normalizers.brs`, `constants.brs`, `capabilities.brs`)
- Each component has a paired `.xml` + `.brs` file with identical base names

**Functions:**
- Use PascalCase for global/public functions: `GetAuthToken()`, `BuildPlexUrl()`, `SafeGet()`, `FormatTime()`, `NormalizeMovieList()`
- Use camelCase for component-scoped subs/functions: `loadLibrary()`, `processApiResponse()`, `onGridItemSelected()`, `checkAuthAndRoute()`
- Event handlers: prefix with `on` + PascalCase event name: `onApiTaskStateChange()`, `onLibrarySelected()`, `onFocusChange()`, `onKeyEvent()`
- "Show" actions: `showHomeScreen()`, `showDetailScreen()`, `showError()`, `showSettingsMenu()`
- "Load" data: `loadLibrary()`, `loadSeasons()`, `loadEpisodes()`, `loadMedia()`
- "Process" responses: `processApiResponse()`, `processMetadata()`, `processSeasons()`, `processEpisodes()`, `processSearchResults()`

**Variables:**
- Use camelCase: `m.currentSectionId`, `m.isLoading`, `m.focusOnSidebar`, `m.lastReportTime`
- Module-scoped state stored on `m.` (BrightScript module scope): `m.apiTask`, `m.screenStack`, `m.player`
- Constants object accessed via `c = GetConstants()`, then `c.PAGE_SIZE`, `c.POSTER_WIDTH`
- Boolean flags: descriptive names like `m.isLoading`, `m.focusOnSidebar`, `m.seekPending`, `m.focusOnSeasons`

**Types/Components:**
- PascalCase for SceneGraph component names: `MainScene`, `HomeScreen`, `PlexApiTask`, `PosterGrid`, `VideoPlayer`
- Component names match their directory context: screens in `screens/`, widgets in `widgets/`, tasks in `tasks/`

**XML Interface Fields:**
- camelCase: `itemSelected`, `navigateBack`, `ratingKey`, `showTitle`, `authToken`, `playbackComplete`
- Boolean flags: `alwaysNotify="true"` on fields that fire events repeatedly (e.g., `itemSelected`, `navigateBack`, `loadMore`)

## Code Style

**Formatting:**
- No automated formatter or linter detected (no `.eslintrc`, `.prettierrc`, `bsconfig.json`, or similar)
- Indentation: 4 spaces consistently throughout all files
- Single quotes for BrightScript string comments: `' This is a comment`
- No trailing commas in associative arrays (BrightScript syntax)

**Linting:**
- No linting tool configured
- No BrighterScript or `bslint` configuration detected

**Line Length:**
- No enforced limit, but lines generally stay under 120 characters
- Long URLs or string concatenations are kept on single lines

## Import Organization

**Script Includes (XML):**
Components include shared source files via `<script>` tags in their XML definitions. Follow this order:

1. Shared source utilities first: `pkg:/source/utils.brs`, `pkg:/source/constants.brs`, `pkg:/source/logger.brs`
2. Component-specific BrightScript last: the component's own `.brs` file

**Example from `SimPlex/components/MainScene.xml`:**
```xml
<script type="text/brightscript" uri="pkg:/source/utils.brs" />
<script type="text/brightscript" uri="pkg:/source/constants.brs" />
<script type="text/brightscript" uri="pkg:/source/logger.brs" />
<script type="text/brightscript" uri="MainScene.brs" />
```

**Example from `SimPlex/components/screens/HomeScreen.xml`:**
```xml
<script type="text/brightscript" uri="pkg:/source/utils.brs" />
<script type="text/brightscript" uri="pkg:/source/constants.brs" />
<script type="text/brightscript" uri="HomeScreen.brs" />
```

**Path Aliases:**
- `pkg:/` prefix for all script imports (Roku package path convention)
- Component-local `.brs` files use relative names (e.g., `HomeScreen.brs` not `pkg:/components/screens/HomeScreen.brs`)

## Component Structure Pattern

Every SceneGraph component follows this structure:

**XML file:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<component name="ComponentName" extends="Group|Task|Scene">
    <interface>
        <!-- Input/output fields -->
    </interface>
    <script type="text/brightscript" uri="pkg:/source/utils.brs" />
    <script type="text/brightscript" uri="ComponentName.brs" />
    <children>
        <!-- Layout nodes -->
    </children>
</component>
```

**BrightScript file:**
```brightscript
sub init()
    ' 1. Find child nodes
    m.childNode = m.top.findNode("childId")

    ' 2. Initialize state variables
    m.someState = ""

    ' 3. Create Task nodes for API calls
    m.apiTask = CreateObject("roSGNode", "PlexApiTask")
    m.apiTask.observeField("status", "onApiTaskStateChange")

    ' 4. Observe child widget events
    m.childNode.observeField("eventField", "onEventHandler")

    ' 5. Observe own focus changes
    m.top.observeField("focusedChild", "onFocusChange")

    ' 6. Initial data load (if needed)
    loadInitialData()
end sub
```

## Error Handling

**API Response Validation:**
Always guard against `invalid` at every level of response parsing. Use this cascading null-check pattern:

```brightscript
' From SimPlex/components/screens/HomeScreen.brs
response = m.apiTask.response
if response = invalid or response.MediaContainer = invalid
    return
end if
metadata = response.MediaContainer.Metadata
if metadata = invalid then metadata = []
```

**Safe Field Access:**
Use `SafeGet()` from `SimPlex/source/utils.brs` for accessing fields that may be missing:

```brightscript
' SafeGet(obj, field, default) - returns default if field missing or obj invalid
title = SafeGet(item, "title", "Unknown")
viewOffset = SafeGet(item, "viewOffset", 0)
```

Use `SafeGetMetadata()` for the standard Plex `MediaContainer.Metadata` path:
```brightscript
items = SafeGetMetadata(response)  ' returns [] if path invalid
```

**Type-Safe ratingKey Handling:**
Plex API returns `ratingKey` as either string or integer depending on context. Always normalize to string:

```brightscript
' This pattern appears in HomeScreen.brs, EpisodeScreen.brs, SearchScreen.brs, DetailScreen.brs
ratingKeyStr = ""
if item.ratingKey <> invalid
    if type(item.ratingKey) = "roString" or type(item.ratingKey) = "String"
        ratingKeyStr = item.ratingKey
    else
        ratingKeyStr = item.ratingKey.ToStr()
    end if
end if
```

A helper `getRatingKeyString()` exists in `SimPlex/components/screens/DetailScreen.brs` but is not shared globally. Other files duplicate this logic inline.

**Task Error Pattern:**
All Task nodes follow this status-based error pattern:

```brightscript
sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.visible = false
        m.isLoading = false
        processResponse()
    else if state = "error"
        m.loadingSpinner.visible = false
        m.isLoading = false
        showError(m.apiTask.error)
    end if
end sub
```

**Error Display:**
Errors are shown via `StandardMessageDialog`:

```brightscript
sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog
end sub
```

## Logging

**Framework:** Custom logger in `SimPlex/source/logger.brs` wrapping BrightScript `print`

**Two Log Levels Only:**
- `LogError(message)` - For error conditions (failed requests, invalid responses)
- `LogEvent(message)` - For key milestones (auth complete, screen transitions, API calls)

**Output Format:** `[ISO-8601-timestamp] [LEVEL] message`

**When to Log:**
- Log every API request start: `LogEvent("API request: " + method + " " + endpoint)`
- Log API completion: `LogEvent("API complete: " + endpoint)`
- Log errors with context: `LogError("API error: " + errorMsg)`
- Log auth/navigation events: `LogEvent("No stored credentials, showing PIN screen")`
- Do NOT use verbose/debug logging

## Focus Management

**Pattern:** Every screen/widget that can receive focus implements `onFocusChange`:

```brightscript
sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        ' Delegate focus to the appropriate child
        m.someChild.setFocus(true)
    end if
end sub
```

This is observed via: `m.top.observeField("focusedChild", "onFocusChange")`

**Focus Tracking State:**
Screens with multiple focusable areas track which area has focus with a boolean:
- `m.focusOnSidebar` in `SimPlex/components/screens/HomeScreen.brs`
- `m.focusOnKeyboard` in `SimPlex/components/screens/SearchScreen.brs`
- `m.focusOnSeasons` in `SimPlex/components/screens/EpisodeScreen.brs`

## Key Event Handling

**Pattern:** Every screen implements `onKeyEvent` with this structure:

```brightscript
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    else if key = "left" and someCondition
        ' Handle navigation
        return true
    end if

    return false
end function
```

**Rules:**
- Always check `if not press then return false` first (ignore key releases)
- Return `true` to consume the event, `false` to let it propagate
- "back" key always sets `m.top.navigateBack = true` on screens

## Screen Communication Pattern

**Screen-to-Parent (upward):**
Screens communicate to `MainScene` via interface fields:
- `itemSelected` (assocarray with `action`, `ratingKey`, `itemType`) - triggers navigation
- `navigateBack` (boolean) - triggers `popScreen()`
- `state` (string) - lifecycle events like "authenticated", "connected", "cancelled"

**Parent-to-Screen (downward):**
Data passed to screens via interface fields set before or after creation:
```brightscript
screen = CreateObject("roSGNode", "EpisodeScreen")
screen.ratingKey = ratingKey
screen.showTitle = showTitle
pushScreen(screen)
```

**Task-to-Screen:**
Tasks communicate via `status` field with values: `"idle"`, `"loading"`, `"completed"`, `"error"`, `"authRequired"`

## Cleanup Pattern

**Screens with a `cleanup` function** (declared in XML as `<function name="cleanup" />`):
- Stop running tasks: `m.apiTask.control = "stop"`
- Unobserve all fields: `m.apiTask.unobserveField("status")`
- Called by `MainScene.cleanupScreen()` when popping from screen stack

**Example from `SimPlex/components/screens/HomeScreen.brs`:**
```brightscript
sub cleanup()
    if m.apiTask <> invalid
        m.apiTask.control = "stop"
        m.apiTask.unobserveField("status")
    end if
    m.sidebar.unobserveField("selectedLibrary")
    m.sidebar.unobserveField("specialAction")
    m.posterGrid.unobserveField("itemSelected")
    m.posterGrid.unobserveField("loadMore")
    m.filterBar.unobserveField("filterChanged")
end sub
```

## Constants Access

**Pattern:** Never hardcode layout values, colors, or API constants. Always use `GetConstants()`:

```brightscript
c = GetConstants()
m.grid.numColumns = c.GRID_COLUMNS
m.grid.itemSize = [c.POSTER_WIDTH + 20, c.POSTER_HEIGHT + 50]
```

Constants are defined in `SimPlex/source/constants.brs` and returned as an associative array.

## HTTP Request Pattern

**All HTTP requests MUST run in Task nodes** (never on render thread).

**Standard setup in every Task:**
```brightscript
url = CreateObject("roUrlTransfer")
url.SetCertificatesFile("common:/certs/ca-bundle.crt")
url.InitClientCertificates()
url.SetUrl(requestUrl)

headers = GetPlexHeaders()
for each key in headers
    url.AddHeader(key, headers[key])
end for
```

## Registry (Persistent Storage) Pattern

**Always use "SimPlex" section name** and **always call `.Flush()` after writes:**

```brightscript
sec = CreateObject("roRegistrySection", "SimPlex")
sec.Write("key", value)
sec.Flush()
```

Note: `SimPlex/components/screens/SettingsScreen.brs` line 85 incorrectly uses `"PlexClassic"` instead of `"SimPlex"` - this is a bug from the rename.

## Comments

**When to Comment:**
- Single-line comments with `'` prefix
- Comment purpose of each `init()` section (node finding, state init, observers)
- Comment non-obvious logic (e.g., ratingKey type coercion, codec compatibility checks)
- Comment TODO items for future work

**Style:**
```brightscript
' Build standard Plex headers as associative array
' Safe field access - returns default if field missing or obj invalid
' Roku supports H.264, HEVC, VP9
```

**No JSDoc/TSDoc** - BrightScript has no standard doc comment format. Use plain `'` comments.

## Data Normalization

**Pattern:** Raw JSON from API tasks is converted to ContentNode trees via normalizer functions in `SimPlex/source/normalizers.brs`.

Each normalizer:
1. Creates a root `ContentNode`
2. Iterates the JSON array
3. Uses `SafeGet()` for every field access
4. Adds custom fields via `node.addFields({})`
5. Returns the content tree

Normalizers: `NormalizeMovieList()`, `NormalizeShowList()`, `NormalizeSeasonList()`, `NormalizeEpisodeList()`, `NormalizeOnDeck()`

Note: These normalizers are defined but not consistently used. `HomeScreen.brs` and `EpisodeScreen.brs` build ContentNode trees inline rather than calling normalizers.

---

*Convention analysis: 2026-03-08*
