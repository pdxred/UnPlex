# Phase 3: Navigation Framework - Research

**Researched:** 2026-02-09
**Domain:** Roku SceneGraph navigation, screen stack management, focus preservation
**Confidence:** HIGH

## Summary

The navigation framework implementation centers on a screen stack pattern using BrightScript arrays and SceneGraph component lifecycle management. The existing MainScene.brs already implements the core pattern correctly: array-based stack (push/pop/peek), focus preservation via focusedChild tracking, and visible field management for hiding background screens. The implementation follows established Roku community patterns for back button navigation and screen transitions.

The primary challenge is ensuring proper cleanup to prevent memory leaks. BrightScript's reference counting means observers must be explicitly removed (unobserveField) and child nodes removed (removeChild) before setting references to invalid. The existing code has the foundation but needs enhancement for observer cleanup and consistent screen lifecycle management.

**Primary recommendation:** Audit existing MainScene stack implementation for observer cleanup, add cleanup helper for common unobserve patterns, ensure all screens follow consistent lifecycle (observe on push, unobserve on pop), and verify focus restoration works across all screen types including grids with scroll positions.

## Summary

Navigation in Roku SceneGraph applications uses an array-based screen stack pattern where the MainScene component manages an array of screen nodes. When navigating forward, new screens are pushed onto the stack; the back button pops screens off. Focus preservation requires storing the focusedChild reference before hiding a screen, then restoring it when returning. Proper cleanup (unobserveField + removeChild + setting references to invalid) is critical to prevent memory leaks in BrightScript's reference-counting environment.

The existing codebase already implements this pattern correctly in MainScene.brs lines 198-261. The main enhancement needed is systematic observer cleanup and verification that focus restoration works for complex widgets (grids with scroll positions).

## Standard Stack

### Core (Built-in Roku SceneGraph)
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Scene | SceneGraph 1.3 | Root container | Only valid root for Roku SceneGraph apps |
| Group | Built-in | Screen container | Standard container for child components |
| Array | BrightScript | Screen stack storage | Native data structure with push/pop/peek |
| focusedChild | Built-in field | Focus tracking | Official mechanism for querying focus chain |
| visible | Built-in field | Screen show/hide | Standard field for toggling node rendering |
| onKeyEvent() | Built-in function | Key capture | Required for back button handling |

### Supporting Patterns
| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| observeField("state") | Screen lifecycle signals | All screen-to-MainScene communication |
| setFocus(true) | Focus assignment | After push, after pop (restoration) |
| removeChild() | Node cleanup | Before popping from stack |
| unobserveField() | Observer cleanup | Before removing child nodes |
| m.screenStack = [] | Stack initialization | MainScene init() |

### Already Implemented
The existing MainScene.brs (lines 1-327) includes:
- Screen stack array (`m.screenStack`, `m.focusStack`)
- Push/pop operations with focus tracking
- Back button handler via onKeyEvent
- Observer pattern for screen signals (itemSelected, navigateBack)
- Exit dialog for last screen on stack

**Gaps to address:**
- Systematic observer cleanup (unobserveField before removeChild)
- Screen cleanup helper function for consistency
- Verification of focus restoration for PosterGrid scroll positions

## Architecture Patterns

### Pattern 1: Screen Stack Management (Already Implemented)

**What:** Array-based stack with push/pop operations, visible field management
**When to use:** All screen navigation in MainScene
**Source:** Existing MainScene.brs lines 198-261

```brightscript
' Source: Existing MainScene.brs with cleanup enhancements
sub pushScreen(screen as Object)
    ' Store current focus position before pushing
    if m.screenStack.count() > 0
        currentScreen = m.screenStack.peek()
        focusedNode = currentScreen.focusedChild
        if focusedNode <> invalid
            m.focusStack.push(focusedNode)
        else
            m.focusStack.push(invalid)
        end if
        currentScreen.visible = false  ' Hide previous screen (performance)
    end if

    ' Add new screen
    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    screen.setFocus(true)

    ' Observe standard screen events
    screen.observeField("itemSelected", "onItemSelected")
    screen.observeField("navigateBack", "onNavigateBack")
end sub

sub popScreen()
    if m.screenStack.count() <= 1
        showExitDialog()
        return
    end if

    ' Cleanup current screen
    currentScreen = m.screenStack.pop()

    ' CRITICAL: Unobserve before removing
    currentScreen.unobserveField("itemSelected")
    currentScreen.unobserveField("navigateBack")

    m.screenContainer.removeChild(currentScreen)
    ' Note: No need to set currentScreen = invalid here (local scope)

    ' Restore previous screen
    previousScreen = m.screenStack.peek()
    previousScreen.visible = true

    ' Restore focus
    if m.focusStack.count() > 0
        savedFocus = m.focusStack.pop()
        if savedFocus <> invalid
            savedFocus.setFocus(true)
        else
            previousScreen.setFocus(true)
        end if
    else
        previousScreen.setFocus(true)
    end if
end sub
```

**Key principles:**
- Array.peek() returns last item without removing (safe for count check)
- visible=false hides background screens (saves rendering cycles)
- focusedChild stores immediate child in focus chain (may be invalid)
- Always unobserve before removeChild (prevents lapsed listener problem)

### Pattern 2: Back Button Handling (Already Implemented)

**What:** Component-level onKeyEvent intercepts back button, returns true to consume
**When to use:** MainScene and any screen that needs custom back behavior
**Source:** Existing MainScene.brs lines 317-326, Roku official docs

```brightscript
' Source: MainScene.brs (existing implementation)
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        popScreen()
        return true  ' Consume event (stop propagation)
    end if

    return false  ' Allow event to bubble up
end function
```

**Return value semantics:**
- `return true` = event consumed, stop bubbling up focus chain
- `return false` = event not handled, continue to parent/firmware
- Only process on `press = true` (ignore key release)

**Sources:**
- [Roku onKeyEvent Documentation](https://developer.roku.com/docs/references/scenegraph/component-functions/onkeyevent.md)
- [Roku Community: Back Button Navigation](https://community.roku.com/discussions/developer/please-help-me-with-back-button-navigation/359679)

### Pattern 3: Focus Preservation via focusedChild (Existing with Caveats)

**What:** Save focusedChild reference on push, restore via setFocus() on pop
**When to use:** All navigation that should preserve scroll/selection position
**Source:** Existing MainScene.brs lines 199-207, 236-245

```brightscript
' On push: save current focus
if m.screenStack.count() > 0
    currentScreen = m.screenStack.peek()
    focusedNode = currentScreen.focusedChild
    m.focusStack.push(focusedNode)  ' May be invalid if no focus
end if

' On pop: restore saved focus
if m.focusStack.count() > 0
    savedFocus = m.focusStack.pop()
    if savedFocus <> invalid
        savedFocus.setFocus(true)
    else
        previousScreen.setFocus(true)  ' Fallback to screen root
    end if
end if
```

**Known limitation:** focusedChild returns the immediate child in the focus chain, not the deeply nested node. For complex components like PosterGrid, focusedChild may reference the grid itself rather than the specific item. Roku's built-in grid components (PosterGrid, RowList) handle internal focus restoration automatically when setFocus(true) is called, but custom scroll positions may not restore perfectly.

**Workaround for advanced cases:** Screens can expose custom fields for deep focus state (e.g., gridScrollIndex, selectedItemIndex) which MainScene can save/restore explicitly.

**Sources:**
- [Roku ifSGNodeFocus Interface](https://developer.roku.com/docs/references/brightscript/interfaces/ifsgnodefocus.md)
- [Roku Community: Is there a way to get the currently focused node?](https://community.roku.com/t5/Roku-Developer-Program/Is-there-a-way-to-get-the-currently-focused-node/td-p/452512)

### Pattern 4: Observer Cleanup (Enhancement Needed)

**What:** Call unobserveField before removeChild to prevent lapsed listener problem
**When to use:** Always before removing a node from SceneGraph
**Source:** Roku community best practices, BrightScript memory management

```brightscript
' WRONG: Missing cleanup
sub popScreen()
    screen = m.screenStack.pop()
    m.screenContainer.removeChild(screen)  ' Observers still attached!
end sub

' CORRECT: Cleanup observers first
sub popScreen()
    screen = m.screenStack.pop()

    ' Remove ALL observers for this screen
    screen.unobserveField("itemSelected")
    screen.unobserveField("navigateBack")
    screen.unobserveField("state")  ' If observing
    ' ... any other observed fields

    m.screenContainer.removeChild(screen)
    ' Reference goes out of scope (local var), garbage collected
end sub
```

**Critical insight:** Each observeField call adds a callback to the field's callback queue. If not removed, the observer function remains in memory even after removeChild. This creates a "lapsed listener" memory leak where the observer closure holds references to the removed node.

**Sources:**
- [Medium: Memory Leak in Observer Pattern](https://medium.com/@devcorner/what-is-a-memory-leak-how-memory-leaks-are-associated-with-the-observer-pattern-dbd12898f2b9)
- [Roku Community: ObserveField](https://community.roku.com/discussions/developer/observefield/474377)
- [Lapsed Listener Problem (Wikipedia)](https://en.wikipedia.org/wiki/Lapsed_listener_problem)

### Pattern 5: Screen Lifecycle Interface

**What:** Standardized fields for screen-to-MainScene communication
**When to use:** All screen components
**Source:** Existing implementation (HomeScreen, DetailScreen, etc.)

```brightscript
' Standard screen interface (in screen XML)
<interface>
    <field id="itemSelected" type="assocarray" alwaysNotify="true" />
    <field id="navigateBack" type="boolean" alwaysNotify="true" />
    <field id="state" type="string" alwaysNotify="true" />  ' Optional
</interface>
```

**Field semantics:**
- `itemSelected` - Screen signals navigation action (e.g., show detail, open search)
- `navigateBack` - Screen requests pop (alternative to onKeyEvent consumption)
- `state` - Optional lifecycle state (loading, ready, error)
- `alwaysNotify="true"` - Fire observer even if value unchanged (critical for repeated actions)

**MainScene observes these on pushScreen() and unobserves on popScreen().**

**Example screen implementation:**
```brightscript
' In HomeScreen.brs
sub onGridItemSelected(event as Object)
    index = event.getData()
    item = m.posterGrid.content.getChild(index)

    ' Signal to MainScene via itemSelected field
    m.top.itemSelected = {
        action: "detail"
        ratingKey: item.ratingKey
        itemType: item.itemType
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        ' Signal back navigation (MainScene will pop)
        m.top.navigateBack = true
        return true
    end if

    return false
end function
```

### Pattern 6: Sidebar Focus Management (Existing Implementation)

**What:** Sidebar component handles its own focus via onKeyEvent, doesn't auto-focus when visible
**When to use:** Persistent navigation widgets (Sidebar on HomeScreen)
**Source:** Existing HomeScreen.brs lines 204-221, Sidebar.brs lines 150-184

```brightscript
' HomeScreen manages focus between sidebar and content
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" and not m.focusOnSidebar
        m.focusOnSidebar = true
        m.sidebar.setFocus(true)
        return true
    else if key = "right" and m.focusOnSidebar
        m.focusOnSidebar = false
        m.posterGrid.setFocus(true)
        return true
    else if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
```

**Sidebar internal focus management:**
```brightscript
' Sidebar.brs handles up/down between its three LabelLists
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down"
        if m.activeList = "library"
            if m.libraryList.itemFocused >= m.libraries.count() - 1
                m.activeList = "hub"
                m.hubList.setFocus(true)
                return true
            end if
        ' ... transitions to bottom list
    else if key = "up"
        ' ... reverse transitions
    end if

    return false
end function
```

**Key principle:** Parent screen (HomeScreen) handles horizontal focus (left/right), child widget (Sidebar) handles vertical focus (up/down within lists). Both return true when consuming events to prevent bubbling.

### Anti-Patterns to Avoid

- **Missing unobserveField before removeChild:** Creates lapsed listener memory leaks
- **Saving focusedChild without invalid check:** Crashes if screen has no focus
- **Not hiding previous screen (visible=false):** Wastes rendering cycles on off-screen content
- **Returning false from onKeyEvent when handling back:** Allows event to bubble, may trigger unwanted firmware behavior
- **Using m.global for screen references:** Increases reference count, harder to garbage collect
- **Reusing screen instances:** State pollution from previous use, always create fresh
- **Not handling exit dialog on last screen:** User expects back button to show "Exit?" confirmation

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Focus tracking | Custom focus state system | focusedChild built-in field | Roku maintains focus chain automatically |
| Screen transitions | Custom animation system | visible field toggle | SceneGraph optimized for show/hide |
| Back button handling | Custom event system | onKeyEvent() function | Official API, handles bubbling correctly |
| Stack data structure | Custom linked list | BrightScript Array with push/pop/peek | Native implementation is fast and tested |
| Screen lifecycle signals | Custom event bus | observeField on standard fields | SceneGraph observer pattern is built-in |
| Exit confirmation | Custom dialog component | StandardMessageDialog | Roku's official dialog matches OS style |

**Key insight:** Roku's SceneGraph provides all primitives needed for navigation. The challenge is orchestrating them correctly (lifecycle management, cleanup discipline) rather than building custom abstractions. Existing MainScene implementation follows these patterns well.

## Common Pitfalls

### Pitfall 1: Observer Accumulation (Lapsed Listener)
**What goes wrong:** Memory leaks, callbacks fire multiple times, stale screen logic executes after screen removed
**Why it happens:** observeField adds callback to queue without checking for duplicates, removeChild doesn't auto-unobserve
**How to avoid:**
- ALWAYS unobserveField before removeChild
- Create helper function for consistent cleanup pattern
- Use observeFieldScoped where appropriate (safer scoping)
**Warning signs:** Memory usage grows over navigation cycles, callback logs show duplicate execution, crashes referencing deallocated screens
**Source:** [Roku Community: ObserveField](https://community.roku.com/discussions/developer/observefield/474377)

### Pitfall 2: focusedChild Returns Invalid
**What goes wrong:** Attempt to call setFocus(true) on invalid reference causes crash
**Why it happens:** Screen may have no focused child (e.g., screen just created, all children disabled)
**How to avoid:**
- Always check `if savedFocus <> invalid` before calling setFocus
- Provide fallback: `screen.setFocus(true)` (focus screen root)
**Warning signs:** Crashes on popScreen with "Method 'setFocus' not found in roInvalid"
**Source:** Existing MainScene.brs lines 238-244 (correct implementation)

### Pitfall 3: Deep Focus Not Preserved
**What goes wrong:** PosterGrid scroll position resets to top after back navigation, user loses place
**Why it happens:** focusedChild only captures immediate child (the grid itself), not the selected item index or scroll offset
**How to avoid:**
- Rely on Roku's built-in grid focus restoration (works for most cases)
- For custom behavior: expose screen fields like `lastScrollIndex` that MainScene can save/restore explicitly
- Alternatives: some developers save full scroll state in screen's m.top before hiding
**Warning signs:** User reports "lost my place" when navigating back to library grid
**Source:** [Roku Community: RowList Node loses focus](https://community.roku.com/discussions/developer/rowlist-node-loses-focus/423105)

### Pitfall 4: Screen Stack Underflow
**What goes wrong:** popScreen called on empty stack, array.pop() returns invalid, crash attempting to restore screen
**Why it happens:** Multiple back button handlers (screen + MainScene) both pop, or logic error in navigation flow
**How to avoid:**
- Check `if m.screenStack.count() <= 1` before popping (show exit dialog instead)
- Screens should signal navigateBack rather than calling popScreen directly
- Only MainScene manipulates stack
**Warning signs:** Crashes on back button with "roInvalid" errors accessing m.screenStack.peek()
**Source:** Existing MainScene.brs lines 221-225 (correct guard)

### Pitfall 5: Exit Dialog Doesn't Show
**What goes wrong:** App exits immediately on back button from home screen, no confirmation
**Why it happens:** onKeyEvent returns true for back button, consuming event, but no exit dialog logic
**How to avoid:**
- In popScreen(), check `if m.screenStack.count() <= 1` then call showExitDialog()
- StandardMessageDialog with buttons=["Exit", "Cancel"]
- On "Exit" button: set m.top.close = true (signals channel exit to firmware)
**Warning signs:** User accidentally exits app frequently, no "Are you sure?" prompt
**Source:** Existing MainScene.brs lines 270-286 (correct implementation)

### Pitfall 6: Task Nodes Not Cleaned Up
**What goes wrong:** Background tasks continue running after screen removed, memory leak, duplicate API calls
**Why it happens:** Screen creates task in init(), observes it, but doesn't stop/unobserve when removed
**How to avoid:**
- In screen cleanup: set `task.control = "stop"`, unobserveField, set task = invalid
- Alternatively: use Task timeout or check task.state in observer and cleanup on completion
- MainScene could provide cleanup hook: `screen.callFunc("cleanup")` before removeChild
**Warning signs:** Network traffic continues after navigating away, debug logs show task state changes for removed screens
**Source:** [Roku SDK: SceneGraph Threads](https://sdkdocs-archive.roku.com/SceneGraph-Threads_4262152.html)

## Code Examples

Verified patterns from existing codebase and Roku documentation.

### Complete Screen Stack Implementation (Enhanced)
```brightscript
' MainScene.brs - Enhanced with systematic cleanup
sub init()
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    m.focusStack = []

    ' Standard observer fields
    m.observedFields = ["itemSelected", "navigateBack", "state"]
end sub

sub pushScreen(screen as Object)
    ' Save current screen's focus
    if m.screenStack.count() > 0
        currentScreen = m.screenStack.peek()
        focusedNode = currentScreen.focusedChild
        m.focusStack.push(focusedNode)  ' May be invalid
        currentScreen.visible = false
    end if

    ' Add and focus new screen
    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    screen.setFocus(true)

    ' Observe standard events
    for each field in m.observedFields
        screen.observeField(field, "on" + field.left(1).toUpper() + field.mid(1))
    end for
end sub

sub popScreen()
    ' Guard against underflow
    if m.screenStack.count() <= 1
        showExitDialog()
        return
    end if

    ' Remove and cleanup current screen
    currentScreen = m.screenStack.pop()
    cleanupScreen(currentScreen)
    m.screenContainer.removeChild(currentScreen)

    ' Restore previous screen
    previousScreen = m.screenStack.peek()
    previousScreen.visible = true

    ' Restore focus
    restoreFocus(previousScreen)
end sub

sub cleanupScreen(screen as Object)
    ' Unobserve all standard fields
    for each field in m.observedFields
        screen.unobserveField(field)
    end for

    ' Optional: Call screen cleanup function if exists
    if screen.hasField("cleanup")
        screen.callFunc("cleanup")
    end if
end sub

sub restoreFocus(screen as Object)
    if m.focusStack.count() > 0
        savedFocus = m.focusStack.pop()
        if savedFocus <> invalid and savedFocus.isValid()
            savedFocus.setFocus(true)
            return
        end if
    end if

    ' Fallback: focus screen root
    screen.setFocus(true)
end sub

sub clearScreenStack()
    ' Remove all screens with proper cleanup
    while m.screenStack.count() > 0
        screen = m.screenStack.pop()
        cleanupScreen(screen)
        m.screenContainer.removeChild(screen)
    end while
    m.focusStack.clear()
end sub
```

### Screen Cleanup Function (Optional Pattern)
```brightscript
' In screen component (e.g., HomeScreen.brs)
' Optional cleanup function called by MainScene before removal
sub cleanup()
    ' Stop any running tasks
    if m.apiTask <> invalid
        m.apiTask.control = "stop"
        m.apiTask.unobserveField("state")
        m.apiTask = invalid
    end if

    ' Clear large content nodes
    if m.posterGrid <> invalid
        m.posterGrid.content = invalid
    end if

    ' Unobserve child widgets
    m.sidebar.unobserveField("selectedLibrary")
    m.sidebar.unobserveField("specialAction")
end sub
```

### Focus-Aware Screen Base Pattern
```brightscript
' Pattern for screens that need to preserve deep focus state
' In DetailScreen.brs (example)
sub init()
    m.top.addFields({
        savedFocusIndex: -1  ' Expose for MainScene to save/restore
    })

    m.buttonGroup = m.top.findNode("buttonGroup")
    m.buttonGroup.observeField("buttonFocused", "onButtonFocused")
end sub

sub onButtonFocused(event as Object)
    ' Track which button has focus
    m.top.savedFocusIndex = event.getData()
end sub

' When screen becomes visible again (MainScene can call this)
sub restoreDeepFocus()
    if m.top.savedFocusIndex >= 0 and m.top.savedFocusIndex < m.buttonGroup.getChildCount()
        button = m.buttonGroup.getChild(m.top.savedFocusIndex)
        button.setFocus(true)
    end if
end sub
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| observeField | observeFieldScoped | Roku OS 8.0+ (2018) | Safer cleanup (scoped to observer lifetime) |
| Manual focus tracking | focusedChild built-in field | SceneGraph 1.0 (2015) | Roku maintains focus chain automatically |
| Custom screen stack logic | Array push/pop/peek | BrightScript core (2015) | Native stack operations are idiomatic |
| Global event bus | Field observers per screen | SceneGraph pattern | Cleaner isolation, easier cleanup |
| Single scene navigation | Multi-scene apps (rare) | SceneGraph 1.3 (2020+) | Most apps still use single Scene with stack |

**Current best practices (2026):**
- Single Scene with screen stack (not multi-Scene architecture)
- observeFieldScoped for safer observer management (existing code uses observeField - works but scoped is safer)
- Focus restoration relies on Roku's internal state where possible
- Exit dialog on last screen is standard UX expectation
- SGDEX (SceneGraph Developer Extensions) provides ViewStack component for advanced apps, but not required for simple stack navigation

**Sources:**
- [Medium: Navigating Screen Stacks in Roku](https://medium.com/@amitdogra70512/navigating-screen-stacks-in-roku-a-guide-to-creating-and-managing-multiple-screens-using-arrays-1f9cbb736079)
- [TVID Services: Back Stack Management](https://roku.home.blog/2019/01/02/back-stack-management-in-roku-using-scenegraph-component/)
- [GitHub: Roku SceneGraph Developer Extensions - ViewStack](https://github.com/rokudev/SceneGraphDeveloperExtensions)

## Open Questions

1. **SGDEX ViewStack vs Manual Implementation**
   - What we know: SGDEX provides ViewStack component with built-in stack management, close field, focus handling
   - What's unclear: Does it add significant complexity/overhead for simple app? Is it maintained/recommended?
   - Recommendation: Existing manual implementation is working and clear. SGDEX adds dependency and learning curve. Only consider if adding complex navigation features (modals, overlays, slide animations).

2. **Focus Restoration for PosterGrid Scroll Position**
   - What we know: focusedChild captures grid itself, not scroll offset; Roku grids have internal focus memory
   - What's unclear: Does setFocus(true) on saved focusedChild reliably restore scroll position in all cases?
   - Recommendation: Test with real navigation flows. Most users report it works "well enough". If issues arise, add explicit itemFocused field save/restore.

3. **Task Cleanup Hook Pattern**
   - What we know: Screens create tasks but MainScene removes screens, need coordination
   - What's unclear: Should MainScene call cleanup function on screens? Or should screens cleanup on navigateBack signal?
   - Recommendation: Implement optional cleanup() function pattern. MainScene calls if function exists (screen.hasField("cleanup")). Allows screens to manage their own task lifecycle.

4. **observeField vs observeFieldScoped**
   - What we know: Existing code uses observeField; observeFieldScoped is safer (auto-cleanup on scope exit)
   - What's unclear: Does switching provide meaningful benefit? Is it compatible with all SceneGraph components?
   - Recommendation: Existing observeField + manual cleanup works. Could refactor to observeFieldScoped for safety, but not urgent. Document pattern for consistency.

## Sources

### Primary (HIGH confidence)
- Existing codebase: PlexClassic/components/MainScene.brs - Working implementation of screen stack pattern
- [Roku onKeyEvent Documentation](https://developer.roku.com/docs/references/scenegraph/component-functions/onkeyevent.md) - Key event handling, return value semantics
- [Roku ifSGNodeFocus Interface](https://developer.roku.com/docs/references/brightscript/interfaces/ifsgnodefocus.md) - Focus management methods
- [Roku Array (roArray) Documentation](https://developer.roku.com/docs/references/brightscript/components/roarray.md) - push/pop/peek methods

### Secondary (MEDIUM confidence)
- [Medium: Navigating Screen Stacks in Roku](https://medium.com/@amitdogra70512/navigating-screen-stacks-in-roku-a-guide-to-creating-and-managing-multiple-screens-using-arrays-1f9cbb736079) - Community implementation patterns
- [TVID Services: Back Stack Management](https://roku.home.blog/2019/01/02/back-stack-management-in-roku-using-scenegraph-component/) - Observer cleanup patterns
- [Roku Community: ObserveField](https://community.roku.com/discussions/developer/observefield/474377) - Observer accumulation issues
- [Roku Community: Scene Graph Destroying Nodes](https://forums.roku.com/viewtopic.php?t=96628) - Cleanup best practices
- [Medium: Memory Leak in Observer Pattern](https://medium.com/@devcorner/what-is-a-memory-leak-how-memory-leaks-are-associated-with-observer-pattern-dbd12898f2b9) - Lapsed listener problem

### Tertiary (LOW confidence - needs validation)
- [GitHub: Roku SceneGraph Developer Extensions](https://github.com/rokudev/SceneGraphDeveloperExtensions) - SGDEX ViewStack (blocked, but documented in other sources)
- Deep focus restoration for complex grids - community reports vary, needs testing

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH - Built-in Roku primitives, existing code validates patterns
- Architecture: HIGH - Existing MainScene implementation follows best practices, enhancements are refinements
- Pitfalls: HIGH - Well-documented across Roku community, verified in existing code

**Research date:** 2026-02-09
**Valid until:** 90 days (Roku SceneGraph patterns are stable, navigation is mature API)
