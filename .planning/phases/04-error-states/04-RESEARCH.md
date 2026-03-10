# Phase 4: Error States - Research

**Researched:** 2026-03-09
**Domain:** Roku SceneGraph error handling, loading states, empty states, network resilience
**Confidence:** HIGH

## Summary

Phase 4 adds error handling, loading indicators, empty state messaging, and server disconnect recovery across all existing screens. The codebase already has a basic pattern: each screen has a `LoadingSpinner` that shows/hides, a `showError()` function that creates a simple `StandardMessageDialog` with an "OK" button, and task callbacks that check for `"error"` status. The work is primarily about extending these patterns consistently and adding retry/reconnect capabilities.

The existing `LoadingSpinner` component is a simple label showing "Loading..." text. Per user decisions, it should be a spinner (no text label), so the component needs upgrading to use Roku's built-in `BusySpinner` node. Every screen already imports the spinner but uses it inconsistently -- some screens show it, others silently fail. The error dialog pattern needs to shift from fire-and-forget "OK" dialogs to retry-capable dialogs with contextual messages and silent auto-retry logic.

**Primary recommendation:** Upgrade `LoadingSpinner` to use `BusySpinner`, create a reusable `showErrorDialog()` helper with retry callback support, and add a centralized server connectivity monitor in `MainScene` that handles reconnection flows.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Loading indicators: Simple centered spinner (no text label), using the existing LoadingSpinner component, positioned center of content area (right of sidebar), no minimum display time
- Empty state messaging: Friendly & helpful tone, hub rows with no content hidden entirely (already implemented), empty search: simple "No results" message, empty libraries: friendly message with guidance
- Error & retry UX: Network errors as dialog overlays (modal), contextual messages specific to what failed, silent auto-retry once before showing dialog, after dismissing without retry stay on current screen with inline "Retry" option
- Server disconnect flow: Silent background retry first, dialog with "Try Again" and "Server List" options, on successful reconnection resume user's position and re-fetch data, auth token expiry treated as standard error

### Claude's Discretion
- Loading strategy: Whether to use full-replacement or progressive loading per screen
- Empty state visuals: Whether to include icons/illustrations above empty state text

### Deferred Ideas (OUT OF SCOPE)
None
</user_constraints>

## Standard Stack

### Core
| Component | Type | Purpose | Why Standard |
|-----------|------|---------|--------------|
| BusySpinner | Built-in SceneGraph node | Animated loading indicator | Roku's official spinner widget, handles rotation animation natively |
| StandardMessageDialog | Built-in SceneGraph node | Error/retry dialogs | Already used throughout codebase for dialogs |
| Timer | Built-in SceneGraph node | Auto-retry delays, reconnect polling | Standard Roku timer, already used for hub refresh |

### Supporting
| Component | Type | Purpose | When to Use |
|-----------|------|---------|-------------|
| Label | Built-in SceneGraph node | Empty state text messages | All empty state screens |
| Rectangle | Built-in SceneGraph node | Inline retry button background | Post-dialog-dismiss retry option |
| ButtonGroup | Built-in SceneGraph node | Inline retry button | Focusable retry action on screen |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| BusySpinner in LoadingSpinner | StandardProgressDialog | ProgressDialog is modal/full-screen -- user wants non-modal centered spinner |
| Custom retry dialog | StandardMessageDialog with buttons | StandardMessageDialog already proven in codebase, no need to build custom |

**No installation needed** -- all components are built into Roku SceneGraph firmware.

## Architecture Patterns

### Current State of Error Handling
Every screen follows this pattern today:
```
Screen has:
  - m.loadingSpinner (LoadingSpinner component)
  - showError(message) function
  - Task observer checking state = "completed" or "error"
```

Screens with loading: HomeScreen, DetailScreen, EpisodeScreen, SearchScreen
Screens with showError: HomeScreen, DetailScreen, EpisodeScreen, SearchScreen

### Pattern 1: Upgraded LoadingSpinner Component
**What:** Replace the text-only LoadingSpinner with a BusySpinner-based component
**When to use:** Every screen that fetches async data

The existing LoadingSpinner is just a Label showing "Loading..." text. It needs to become an animated spinner using Roku's BusySpinner node.

```xml
<!-- LoadingSpinner.xml - upgraded -->
<component name="LoadingSpinner" extends="Group">
    <interface>
        <field id="visible" type="boolean" value="false" onChange="onVisibleChange" />
    </interface>
    <script type="text/brightscript" uri="LoadingSpinner.brs" />
    <children>
        <BusySpinner
            id="spinner"
            visible="false"
            control="stop"
        />
    </children>
</component>
```

```brightscript
' LoadingSpinner.brs - upgraded
sub init()
    m.spinner = m.top.findNode("spinner")
    ' BusySpinner uses its internal Poster for the spinning graphic
    ' Use a simple white circle/arc image from images/ folder
    spinnerPoster = m.spinner.findNode("spinner").poster
    ' OR just use the default BusySpinner appearance
end sub

sub onVisibleChange(event as Object)
    visible = event.getData()
    m.spinner.visible = visible
    if visible
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
    end if
end sub
```

**Key detail:** BusySpinner requires a poster image (PNG) to rotate. The project needs a simple spinner graphic in `images/`. A white circular arc (~64x64px) works well. The `spinInterval` field controls rotation speed (default 1 second per full rotation).

### Pattern 2: Error Dialog with Retry
**What:** Reusable error dialog that supports retry callbacks
**When to use:** Every failed network request (after silent auto-retry fails)

```brightscript
' In any screen - error dialog with retry
sub showErrorDialog(title as String, message as String, retryCallback as String)
    m.pendingRetryCallback = retryCallback

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = title
    dialog.message = [message]
    dialog.buttons = ["Retry", "Dismiss"]
    dialog.observeField("buttonSelected", "onErrorDialogButton")
    dialog.observeField("wasClosed", "onErrorDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onErrorDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        ' Retry - call the stored callback
        if m.pendingRetryCallback <> "" and m.pendingRetryCallback <> invalid
            ' Use callFunc or direct sub call
            ' BrightScript allows calling subs by string via eval or direct reference
        end if
    else
        ' Dismiss - show inline retry option
        showInlineRetry()
    end if
end sub
```

**Important BrightScript limitation:** BrightScript does NOT support function references or callbacks as first-class values. You cannot pass a function as a parameter. Instead, store the retry context (endpoint, params) and use a known retry handler.

Better pattern:
```brightscript
' Store retry context
m.retryContext = {
    endpoint: endpoint
    params: params
    handler: "onApiTaskStateChange"  ' string name of callback
}

sub retryLastRequest()
    if m.retryContext = invalid then return
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.retryContext.endpoint
    task.params = m.retryContext.params
    task.observeField("status", m.retryContext.handler)
    task.control = "run"
    m.currentApiTask = task
    m.loadingSpinner.visible = true
end sub
```

### Pattern 3: Silent Auto-Retry
**What:** Automatically retry once before showing error dialog
**When to use:** Every network request failure

```brightscript
sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.retryCount = 0
        m.loadingSpinner.visible = false
        processApiResponse()
    else if state = "error"
        if m.retryCount = 0
            ' Silent auto-retry (first failure)
            m.retryCount = 1
            retryLastRequest()
        else
            ' Second failure - show error dialog
            m.retryCount = 0
            m.loadingSpinner.visible = false
            showErrorDialog("Couldn't load your library", m.currentApiTask.error)
        end if
    end if
end sub
```

### Pattern 4: Server Connectivity Monitor
**What:** Centralized server health check in MainScene
**When to use:** When any API request fails with network-level error (responseCode < 0)

The approach: When PlexApiTask gets a network error (not a 4xx/5xx HTTP error, but a connection failure), it should signal a "server unreachable" state. MainScene handles the reconnect dialog.

```brightscript
' In MainScene - server disconnect handling
sub showServerDisconnectDialog()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Server Unreachable"
    dialog.message = ["Can't connect to your Plex server."]
    dialog.buttons = ["Try Again", "Server List"]
    dialog.observeField("buttonSelected", "onDisconnectDialogButton")
    m.top.dialog = dialog
end sub

sub onDisconnectDialogButton(event as Object)
    index = event.getData()
    m.top.dialog.close = true

    if index = 0
        ' Try Again - test server connection
        testServerConnection()
    else if index = 1
        ' Server List - go to server selection
        showPINScreen()  ' or showServerListScreen
    end if
end sub
```

### Pattern 5: Inline Retry After Dialog Dismiss
**What:** A focusable "Retry" option shown on screen after error dialog is dismissed
**When to use:** When user dismisses error dialog without retrying

```xml
<!-- Add to each screen that needs it -->
<Group id="retryGroup" visible="false" translation="[800, 400]">
    <Label
        id="retryMessage"
        text="Something went wrong"
        font="font:MediumSystemFont"
        color="0xA0A0B0FF"
        horizAlign="center"
    />
    <ButtonGroup
        id="retryButton"
        translation="[0, 60]"
        buttons='["Retry"]'
    />
</Group>
```

### Pattern 6: Empty State Messaging
**What:** Friendly messages when data sets are empty
**When to use:** Empty libraries, empty search results

```xml
<!-- Empty state group - add to screens -->
<Group id="emptyState" visible="false" translation="[800, 400]">
    <Label
        id="emptyTitle"
        text="Nothing here yet"
        font="font:LargeBoldSystemFont"
        color="0xFFFFFFFF"
        horizAlign="center"
    />
    <Label
        id="emptyMessage"
        translation="[0, 60]"
        text="Add some content to your Plex library to see it here"
        font="font:MediumSystemFont"
        color="0xA0A0B0FF"
        horizAlign="center"
        width="600"
        wrap="true"
    />
</Group>
```

### Loading Strategy Recommendations (Claude's Discretion)

| Screen | Strategy | Rationale |
|--------|----------|-----------|
| HomeScreen (hubs) | Progressive | Hub rows appear as they load; better perceived performance |
| HomeScreen (library) | Full-replacement | Spinner until grid data ready; prevents partial grid flash |
| DetailScreen | Full-replacement | Single API call, data appears all at once |
| EpisodeScreen | Progressive | Season list appears first, episodes load on season focus |
| SearchScreen | Full-replacement | Results appear after each search completes |

HomeScreen hub rows already use progressive loading (they build content as data arrives). Library browsing already shows a spinner. The main additions are ensuring spinners show consistently and empty states appear correctly.

### Empty State Visuals Recommendation (Claude's Discretion)

**Recommendation: No icons/illustrations.** Roku's rendering pipeline does not natively support SVG or icon fonts. Any illustration would need to be a PNG bitmap asset. This adds asset management overhead for minimal value on a TV interface where text is highly readable at couch distance. The friendly text message alone is sufficient and consistent with the app's clean, fast aesthetic.

### Anti-Patterns to Avoid
- **Dialog stacking:** Never show an error dialog while another dialog is open. Check `m.top.getScene().dialog` before creating a new one.
- **Retry without rate limiting:** Always track retry count and reset after success. Never create an infinite retry loop.
- **Spinner left visible:** Every code path that shows the spinner must have a corresponding hide. Use a helper function that manages spinner state.
- **Focus loss after dialog:** Always restore focus to the correct element after dialog closes. Use `wasClosed` observer.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spinning animation | Custom rotation timer | BusySpinner node | Handles hardware-specific rotation capabilities automatically |
| Modal dialogs | Custom overlay Group | StandardMessageDialog | Built-in focus trapping, backdrop, button handling |
| Connection testing | Custom HTTP ping | ServerConnectionTask (exists) | Already handles local/remote/relay ordering with timeouts |

**Key insight:** Roku's built-in dialog system handles focus management automatically. When a dialog is assigned to `scene.dialog`, it captures all remote input. When closed, focus returns to the previous element. Do not try to build custom modal overlays.

## Common Pitfalls

### Pitfall 1: BusySpinner Needs a Poster Image
**What goes wrong:** BusySpinner renders nothing if no poster URI is set
**Why it happens:** BusySpinner extends Poster internally -- it rotates an image, not a built-in graphic
**How to avoid:** Create a simple white spinner arc PNG (e.g., 64x64) and include it in `images/`. Set it via `m.spinner.poster.uri = "pkg:/images/spinner.png"`
**Warning signs:** Spinner area is blank despite being visible

### Pitfall 2: Dialog on Top of Dialog
**What goes wrong:** Setting `scene.dialog` while a dialog is already open replaces the first without cleanup
**Why it happens:** Network errors can fire while a user-initiated dialog (resume, options menu) is open
**How to avoid:** Check `m.top.getScene().dialog <> invalid` before showing error dialogs. Queue the error or wait until current dialog closes.
**Warning signs:** Dialogs appearing/disappearing unexpectedly, lost button observers

### Pitfall 3: Task Node Reuse After Error
**What goes wrong:** Trying to re-run a Task node that already completed/errored
**Why it happens:** Task nodes have a lifecycle -- once they reach "stop" state, re-running may not work reliably
**How to avoid:** Always create a NEW PlexApiTask for retries, never reuse the failed one
**Warning signs:** Retry button does nothing, observer never fires

### Pitfall 4: Focus Lost After Error Dialog
**What goes wrong:** After dismissing error dialog, no element on screen has focus, remote stops responding
**Why it happens:** Dialog took focus, but dismiss handler doesn't restore it
**How to avoid:** Always observe `wasClosed` on dialogs AND `buttonSelected`. In both handlers, explicitly set focus back to the appropriate screen element.
**Warning signs:** Screen appears but remote buttons don't work

### Pitfall 5: Server Disconnect During Playback
**What goes wrong:** Server goes down mid-playback, VideoPlayer handles its own errors separately
**Why it happens:** VideoPlayer has internal error handling that may conflict with app-level disconnect detection
**How to avoid:** This phase should handle non-playback screens only. VideoPlayer error handling is a separate concern (likely Phase 6+).
**Warning signs:** Duplicate error dialogs, conflicting retry attempts

### Pitfall 6: Infinite Auto-Retry Loop
**What goes wrong:** Server is truly down, auto-retry fires repeatedly
**Why it happens:** Each retry failure triggers another retry without counting attempts
**How to avoid:** Track `m.retryCount` per request. Reset to 0 on success. Only auto-retry when `retryCount = 0`.
**Warning signs:** Spinner stays visible indefinitely, excessive network traffic in debug console

## Code Examples

### Creating a BusySpinner with custom image
```xml
<!-- Source: Roku SDK docs - BusySpinner -->
<BusySpinner
    id="spinner"
    translation="[0, 0]"
    control="stop"
>
    <Poster
        uri="pkg:/images/spinner.png"
        width="64"
        height="64"
    />
</BusySpinner>
```

Note: The Poster child is the BusySpinner's internal poster. You set the image by adding a Poster child or accessing `spinner.poster.uri`.

### StandardMessageDialog with multiple buttons
```brightscript
' Source: existing codebase pattern (MainScene.brs, HomeScreen.brs)
dialog = CreateObject("roSGNode", "StandardMessageDialog")
dialog.title = "Server Unreachable"
dialog.message = ["Can't connect to your Plex server. Check your network connection and try again."]
dialog.buttons = ["Try Again", "Server List"]
dialog.observeField("buttonSelected", "onDialogButton")
dialog.observeField("wasClosed", "onDialogClosed")
m.top.getScene().dialog = dialog
```

### Detecting network vs. HTTP errors in PlexApiTask
```brightscript
' In PlexApiTask.brs - responseCode semantics
' responseCode < 0   = network error (DNS failure, connection refused, timeout)
' responseCode 401   = auth error (already handled)
' responseCode 4xx   = client error
' responseCode 5xx   = server error
' responseCode 200   = success

' The task already sets m.top.responseCode which screens can inspect
' to differentiate network failures from server errors
```

### Screen-specific content area centering for spinner
```brightscript
' Spinner should be centered in content area (right of sidebar)
' Sidebar width: 280, Screen width: 1920
' Content area center X: 280 + (1920 - 280) / 2 = 280 + 820 = 1100
' Content area center Y: 1080 / 2 = 540
' But spinner is relative to parent group, so:
' If spinner is child of contentArea (translated 280,0):
'   spinner.translation = [(1640/2) - 32, (1080/2) - 32]  = [788, 508]
' If spinner is child of screen root:
'   spinner.translation = [1100 - 32, 540 - 32]  = [1068, 508]
' (assuming 64x64 spinner image, offset by half to center)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Dialog node | StandardMessageDialog | Roku OS 10+ | More flexible buttons, built-in styling |
| Custom rotation timer | BusySpinner node | Always available | Hardware-aware rotation, simpler code |
| try/catch unavailable | try/catch in BrightScript | Roku OS 9.4 | Can catch network exceptions in tasks |

**Deprecated/outdated:**
- `Dialog` node: Still works but `StandardMessageDialog` is the modern replacement with better button support

## Screens Requiring Changes

| Screen | Loading | Empty State | Error+Retry | Server Disconnect |
|--------|---------|-------------|-------------|-------------------|
| HomeScreen (hubs) | Already loads, needs spinner while empty | Hub rows already hidden when empty (done) | Add retry for hub load failure | Via MainScene |
| HomeScreen (library) | Has spinner (needs upgrade) | Add empty library message | Add retry for library load failure | Via MainScene |
| DetailScreen | Has spinner (needs upgrade) | N/A (always has one item) | Add retry for metadata load failure | Via MainScene |
| EpisodeScreen | Has spinner (needs upgrade) | Add empty season/episode message | Add retry for season/episode load failure | Via MainScene |
| SearchScreen | Has spinner (needs upgrade) | Has "No results" (needs tone upgrade) | Add retry for search failure | Via MainScene |
| ServerListScreen | Already has connection testing | N/A | Already handles connection errors | N/A |
| PINScreen | Already has auth flow | N/A | Already handles auth errors | N/A |

## Open Questions

1. **BusySpinner poster image source**
   - What we know: BusySpinner requires a PNG image to rotate
   - What's unclear: Whether to use a custom asset or if there's a system default
   - Recommendation: Create a simple 64x64 white arc/ring PNG for `images/spinner.png`. Could also try the BusySpinner without explicit poster to test if firmware provides a default.

2. **Server disconnect detection scope**
   - What we know: PlexApiTask already sets responseCode; negative codes indicate network errors
   - What's unclear: Should every screen independently detect server disconnect, or should there be a global signal?
   - Recommendation: Use a global field (`m.global.serverUnreachable`) set by any task that gets responseCode < 0. MainScene observes this field and shows the disconnect dialog. Screens check this flag before retrying.

## Sources

### Primary (HIGH confidence)
- Roku SDK Archive - BusySpinner documentation (fields: control, clockwise, spinInterval, poster)
- Roku SDK Archive - Dialogs Markup (Dialog, PinDialog, KeyboardDialog, ProgressDialog)
- Roku GitHub - standard-dialog-framework (StandardMessageDialog, StandardProgressDialog)
- Existing codebase: PlexApiTask.brs, MainScene.brs, HomeScreen.brs, DetailScreen.brs, EpisodeScreen.brs, SearchScreen.brs

### Secondary (MEDIUM confidence)
- Roku Community forums - BusySpinner usage patterns and poster requirements
- Roku developer docs - Error handling with try/catch in BrightScript (Roku OS 9.4+)

### Tertiary (LOW confidence)
- BusySpinner default poster behavior (may or may not render without explicit image -- needs testing)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components are built-in Roku SceneGraph nodes already used in codebase
- Architecture: HIGH - patterns directly extend existing codebase patterns with minimal new concepts
- Pitfalls: HIGH - derived from direct codebase analysis and Roku SDK documentation
- BusySpinner specifics: MEDIUM - poster requirement confirmed by docs but exact default behavior untested

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable -- Roku SDK changes are infrequent)
