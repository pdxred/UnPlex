# Phase 3: Hub Rows - Research

**Researched:** 2026-03-09
**Domain:** Roku SceneGraph hub row layout + Plex hubs API
**Confidence:** HIGH

## Summary

Phase 3 adds three hub rows (Continue Watching, On Deck, Recently Added) to the home screen above the existing library grid. The Plex Media Server provides a `/hubs` API endpoint that returns all hub content in a single request, with each hub identified by a `hubIdentifier` field (e.g., `home.continue`, `home.ondeck`). Roku SceneGraph's `RowList` component is purpose-built for horizontally-scrollable rows within a vertically-scrollable list, making it the correct component for hub rows.

The main architectural challenge is combining hub rows (variable count, horizontally scrollable) with the existing `MarkupGrid` library grid into a single scrollable view. The recommended approach is to place a `RowList` for hub rows above the existing `PosterGrid`/`MarkupGrid`, with manual focus management at the boundary between them. The existing `MediaRow` widget already wraps a `RowList` with a title label and uses `PosterGridItem` as its item component -- this can be reused or extended. The `PosterGridItem` component needs a progress bar Rectangle added for Continue Watching items.

**Primary recommendation:** Use the Plex `/hubs` API (single call) to fetch all hub data, render hub rows via a `RowList` positioned above the existing grid in the HomeScreen content area, add a progress bar to `PosterGridItem`, and use a Timer node for periodic auto-refresh plus refresh-on-return-from-playback.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Reuse existing 240x360 portrait poster style -- consistent with library grid
- Rows scroll horizontally to reveal more items beyond the visible set
- Default home screen: hub rows at top, library grid below -- one scrollable view
- Sidebar allows switching between hub+grid landing view and full library grid view
- Selecting a Continue Watching item starts playback/resumes immediately
- Selecting a Recently Added or On Deck item opens the detail screen
- Pressing left on the first item in a hub row opens the sidebar (consistent with existing nav)
- Hub rows remember horizontal scroll position when navigating away and returning
- Row order: Continue Watching -> On Deck -> Recently Added
- Recently Added pulls from libraries configured to appear on the home screen (respects Plex server hub config)
- Item count per row matches Plex API defaults (typically 10-20)
- Empty hub rows are hidden entirely -- no placeholder messages
- Hub rows refresh periodically via auto-refresh while on the home screen
- Hub rows also reload when navigating back to home (e.g., after playback)

### Claude's Discretion
- Row label styling (bold headers vs subtle inline text)
- Focus behavior when navigating down from last hub row into library grid
- What to show when ALL hub rows are empty (fresh user experience)
- Error handling for failed hub row loads (silent hide vs inline error)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core
| Library/Component | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| RowList (SceneGraph) | Roku OS 8+ | Hub row container with horizontal scroll per row, vertical scroll between rows | Built-in component designed for this exact use case; handles focus, scrolling, dimming natively |
| PosterGridItem (existing) | N/A | Poster tile rendering for hub row items | Already built; reuse with progress bar addition via `itemComponentName` |
| PlexApiTask (existing) | N/A | HTTP request to `/hubs` endpoint | Already handles auth headers, JSON parsing, error states |
| MarkupGrid (existing) | N/A | Library grid below hub rows | Already working in PosterGrid widget; no changes needed |
| Timer (SceneGraph) | Roku OS 8+ | Periodic auto-refresh of hub rows | Built-in node, supports `duration`, `repeat`, and `fire` observer |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| Rectangle (SceneGraph) | Progress bar overlay on posters | Added to PosterGridItem for viewOffset/duration display |
| ContentNode tree | RowList data binding | Standard Roku pattern: root > row nodes > item nodes |
| MediaRow (existing) | Single hub row with title label | Already wraps RowList with PosterGridItem; may reuse or replace with multi-row RowList |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single RowList for all hub rows | Multiple stacked MediaRow widgets | MediaRow approach needs manual vertical scroll management; single RowList handles it natively but requires dynamic numRows |
| Single `/hubs` API call | Separate `/library/onDeck` + `/library/recentlyAdded` calls | Separate calls still work but create 3 task instances + timing complexity; single call is simpler and returns server-configured hub ordering |
| RowList for everything (hubs + library) | RowList hubs + separate MarkupGrid for library | All-RowList approach loses the existing 6-column paginated grid layout; keeping MarkupGrid preserves existing Phase 1 work |

## Architecture Patterns

### Recommended HomeScreen Structure
```
HomeScreen (existing, modified)
+-- Sidebar (existing, unchanged)
+-- contentArea (Group, existing)
|   +-- hubRowList (RowList, NEW)
|   |   +-- Row 0: Continue Watching
|   |   +-- Row 1: On Deck
|   |   +-- Row 2: Recently Added
|   +-- FilterBar (existing, repositioned dynamically)
|   +-- PosterGrid (existing, repositioned dynamically)
+-- LoadingSpinner (existing)
```

### Pattern 1: Single `/hubs` API Call with Client-Side Filtering
**What:** Fetch all hubs in one request, then filter by `hubIdentifier` to extract the three rows.
**When to use:** Always -- the `/hubs` endpoint returns all configured hubs in one response.
**Example:**
```brightscript
' Source: Plex API docs (plexapi.dev/api-reference/hubs/get-global-hubs)
sub loadHubs()
    if m.isLoadingHubs then return
    m.isLoadingHubs = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/hubs"
    task.params = {}
    task.observeField("status", "onHubsLoaded")
    task.control = "run"
    m.hubsTask = task
end sub

sub onHubsLoaded(event as Object)
    m.isLoadingHubs = false
    if event.getData() <> "completed" then return

    response = m.hubsTask.response
    if response = invalid or response.MediaContainer = invalid then return

    hubs = response.MediaContainer.Hub
    if hubs = invalid then return

    ' Filter for the three hub types we display
    m.continueWatching = invalid
    m.onDeck = invalid
    m.recentlyAdded = invalid

    for each hub in hubs
        id = LCase(hub.hubIdentifier)
        if id = "home.continue" or Instr(1, id, "continue") > 0
            m.continueWatching = hub
        else if id = "home.ondeck" or Instr(1, id, "ondeck") > 0
            m.onDeck = hub
        else if Instr(1, id, "recentlyadded") > 0 or Instr(1, id, "recent") > 0
            if m.recentlyAdded = invalid  ' Take first match only
                m.recentlyAdded = hub
            end if
        end if
    end for

    buildHubRowContent()
end sub
```

### Pattern 2: RowList ContentNode Tree Structure
**What:** Build the correct ContentNode hierarchy for RowList. Root node contains row nodes (one per hub), each row node contains item nodes (one per poster).
**When to use:** Every time hub data is loaded or refreshed.
**Example:**
```brightscript
' Source: Roku RowList docs (sdkdocs-archive.roku.com/RowList_1611919.html)
sub buildHubRowContent()
    rootContent = CreateObject("roSGNode", "ContentNode")
    m.hubRowMap = {}  ' Maps row index to hub type string
    rowIndex = 0
    c = m.global.constants

    ' Add rows in locked order: Continue Watching, On Deck, Recently Added
    ' Only add rows that have data (empty rows hidden per user decision)
    if m.continueWatching <> invalid
        metadata = m.continueWatching.Metadata
        if metadata <> invalid and metadata.count() > 0
            addHubRow(rootContent, "Continue Watching", metadata, c)
            m.hubRowMap[rowIndex.ToStr()] = "continueWatching"
            rowIndex++
        end if
    end if

    if m.onDeck <> invalid
        metadata = m.onDeck.Metadata
        if metadata <> invalid and metadata.count() > 0
            addHubRow(rootContent, "On Deck", metadata, c)
            m.hubRowMap[rowIndex.ToStr()] = "onDeck"
            rowIndex++
        end if
    end if

    if m.recentlyAdded <> invalid
        metadata = m.recentlyAdded.Metadata
        if metadata <> invalid and metadata.count() > 0
            addHubRow(rootContent, "Recently Added", metadata, c)
            m.hubRowMap[rowIndex.ToStr()] = "recentlyAdded"
            rowIndex++
        end if
    end if

    ' Update RowList dimensions before setting content (CRITICAL ordering)
    m.hubRowList.numRows = rowIndex
    m.hubRowList.content = rootContent
    m.hubRowList.visible = (rowIndex > 0)
    m.hubRowCount = rowIndex

    ' Reposition grid below hub rows
    repositionContentBelowHubs(rowIndex)
end sub

sub addHubRow(rootContent as Object, title as String, metadata as Object, c as Object)
    rowNode = rootContent.createChild("ContentNode")
    rowNode.title = title  ' RowList uses TITLE field for row labels

    for each item in metadata
        itemNode = rowNode.createChild("ContentNode")

        ratingKeyStr = ""
        if item.ratingKey <> invalid
            if type(item.ratingKey) = "roString" or type(item.ratingKey) = "String"
                ratingKeyStr = item.ratingKey
            else
                ratingKeyStr = item.ratingKey.ToStr()
            end if
        end if

        itemNode.addFields({
            title: item.title
            ratingKey: ratingKeyStr
            itemType: item.type
            viewOffset: 0
            duration: 0
        })

        if item.viewOffset <> invalid then itemNode.viewOffset = item.viewOffset
        if item.duration <> invalid then itemNode.duration = item.duration

        if item.thumb <> invalid and item.thumb <> ""
            itemNode.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
        end if
    end for
end sub
```

### Pattern 3: Progress Bar in PosterGridItem
**What:** Add a thin Rectangle at the bottom of the poster that shows watch progress as a fraction of poster width.
**When to use:** For Continue Watching items that have both `viewOffset` and `duration` fields.
**Example:**
```xml
<!-- Add to PosterGridItem.xml children, after the poster -->
<Rectangle
    id="progressBg"
    translation="[0, 350]"
    width="240"
    height="6"
    color="0x00000080"
    visible="false"
/>
<Rectangle
    id="progressBar"
    translation="[0, 350]"
    width="0"
    height="6"
    color="0xE5A00DFF"
    visible="false"
/>
```

```brightscript
' Add to PosterGridItem.brs onItemContentChange:
sub updateProgressBar(content as Object)
    viewOffset = 0
    duration = 0
    if content.viewOffset <> invalid then viewOffset = content.viewOffset
    if content.duration <> invalid then duration = content.duration

    if viewOffset > 0 and duration > 0
        progress = viewOffset / duration
        if progress > 1.0 then progress = 1.0
        m.progressBg.visible = true
        m.progressBar.visible = true
        m.progressBar.width = Int(240 * progress)  ' 240 = POSTER_WIDTH
    else
        m.progressBg.visible = false
        m.progressBar.visible = false
    end if
end sub
```

### Pattern 4: Auto-Refresh with Timer + Refresh on Return
**What:** Use a SceneGraph Timer node for periodic refresh, plus reload when home screen regains focus after playback.
**When to use:** Per user decisions -- hub rows refresh periodically and on return from playback.
**Example:**
```brightscript
' In HomeScreen init():
m.hubRefreshTimer = CreateObject("roSGNode", "Timer")
m.hubRefreshTimer.duration = 120  ' 2 minutes
m.hubRefreshTimer.repeat = true
m.hubRefreshTimer.observeField("fire", "onHubRefreshTimer")
m.hubRefreshTimer.control = "start"

sub onHubRefreshTimer(event as Object)
    if not m.isLoadingHubs
        loadHubs()
    end if
end sub

' Refresh on return from playback (detect via focusedChild change)
sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        ' Screen just regained focus -- reload hubs
        loadHubs()
        ' ... existing focus delegation logic
    end if
end sub
```

### Pattern 5: Transient Hub Refresh
**What:** Use `onlyTransient=1` parameter to efficiently refresh only hubs that change after playback (Continue Watching, On Deck).
**When to use:** On return from playback -- avoids re-fetching static hubs like Recently Added.
**Example:**
```brightscript
sub refreshTransientHubs()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/hubs"
    task.params = { "onlyTransient": "1" }
    task.observeField("status", "onHubsRefreshed")
    task.control = "run"
    m.hubsRefreshTask = task
end sub
```

### Pattern 6: Focus Management Between Hub Rows and Library Grid
**What:** Intercept up/down key events to manually transfer focus between the RowList and the MarkupGrid/PosterGrid.
**When to use:** At the boundary between hub rows and library grid -- RowList and MarkupGrid are separate components.
**Example:**
```brightscript
' In HomeScreen onKeyEvent:
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down"
        ' If focused on hub rows and on last row, move to grid
        if m.focusArea = "hubs"
            focusedRow = m.hubRowList.rowItemFocused
            if focusedRow <> invalid and focusedRow[0] >= m.hubRowCount - 1
                m.focusArea = "grid"
                m.posterGrid.setFocus(true)
                return true
            end if
        end if
    else if key = "up"
        ' If focused on grid first row, move to hub rows
        if m.focusArea = "grid"
            ' Check if grid is at top (first row focused)
            if m.posterGrid.isAtTop()  ' Custom helper or check itemFocused < numColumns
                if m.hubRowCount > 0
                    m.focusArea = "hubs"
                    m.hubRowList.setFocus(true)
                    return true
                end if
            end if
        end if
    else if key = "left"
        ' From first item in hub row, open sidebar
        if m.focusArea = "hubs"
            focusedItem = m.hubRowList.rowItemFocused
            if focusedItem <> invalid and focusedItem[1] = 0
                m.focusArea = "sidebar"
                m.sidebar.setFocus(true)
                return true
            end if
        end if
    end if

    ' ... existing left/right/back handling
    return false
end function
```

### Anti-Patterns to Avoid
- **Using roUrlTransfer on render thread for hub calls:** All HTTP requests must go through Task nodes. Roku platform rule; causes rendezvous crashes.
- **Creating one PlexApiTask per hub row:** The `/hubs` endpoint returns all hubs in one call. Three separate tasks waste resources and create timing/ordering complexity.
- **Setting RowList content before sizing fields:** RowList calculates layout when content is set. Setting content before itemSize/rowItemSize/numRows causes invisible or overlapping items.
- **Building custom vertical scroll for hub rows:** RowList handles vertical scrolling between rows natively with focus dimming. Custom scroll management is fragile and unnecessary.
- **Polling hubs too frequently:** Timer-based refresh every 2 minutes is sufficient. More frequent polling wastes network/CPU on constrained Roku hardware.
- **Hard-coding hub identifier strings:** Plex hub identifiers may vary by PMS version. Use case-insensitive partial matching.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Horizontally scrollable row of posters | Custom scroll with translation animation | RowList component | RowList handles focus, scroll position memory, dimming, accessibility natively |
| Vertical scrolling between hub rows | Manual key handling to shift Group translations | RowList with numRows | RowList manages vertical navigation and focus transitions between rows |
| Progress bar percentage calculation | Complex math with edge case handling | Simple `viewOffset / duration` clamped to 0-1 | Plex provides both values in hub metadata; straightforward division |
| Hub data caching | Custom cache with timestamps and invalidation | Fresh `/hubs` call + `onlyTransient=1` for refresh | Plex server handles caching; transient parameter avoids redundant data transfer |
| Row visibility toggling | Custom show/hide logic per row | Dynamic ContentNode tree with only populated rows | Build tree with only non-empty rows; RowList renders what it gets |
| Periodic refresh timer | Custom timestamp tracking with roDateTime | SceneGraph Timer node with repeat=true | Built-in, handles repeat, observable fire field |

**Key insight:** RowList is the single most important "don't hand-roll" item. It handles horizontal scroll per row, vertical navigation between rows, focus dimming of non-active rows, row labels, and scroll position memory. Building any of this manually would be fragile, slow, and significantly more code.

## Common Pitfalls

### Pitfall 1: RowList Content Set Before Dimensions
**What goes wrong:** Items render with wrong sizes, overlap, or don't appear at all.
**Why it happens:** RowList calculates layout on content assignment. If itemSize/rowItemSize/numRows aren't set yet, it uses defaults (often 0x0).
**How to avoid:** Always set itemSize, rowItemSize, rowItemSpacing, and numRows BEFORE setting content. When dynamically changing numRows (e.g., hub row count changes), update numRows first, then content.
**Warning signs:** Empty rows, items overlapping, items not visible despite valid content.

### Pitfall 2: Hub Identifier Case Sensitivity and Variation
**What goes wrong:** Hub filtering fails; rows appear empty even though API returned data.
**Why it happens:** Plex hub identifiers may vary in casing across PMS versions (e.g., `home.continue` vs `home.Continue`). Some servers may split recently added by type (`home.movies.recent`, `home.tv.recent`).
**How to avoid:** Use `LCase()` when comparing hubIdentifier values. Use `Instr()` for partial matching as fallback. Log all received hubIdentifier values during development for debugging.
**Warning signs:** Hub data loads successfully (API returns 200 with data) but rows don't populate.

### Pitfall 3: RowList numRows Mismatch with Actual Row Count
**What goes wrong:** Extra blank rows appear below populated rows, or populated rows get clipped.
**Why it happens:** numRows controls how many rows are visible. If set to 3 but only 2 hubs have data, a blank third row appears. If set to 2 but 3 hubs have data, the third row is hidden.
**How to avoid:** Dynamically set numRows to match the actual number of ContentNode children in the root content node. Count populated hubs first, then set numRows, then set content.
**Warning signs:** Blank space below populated rows, focus going to invisible area, missing hub row.

### Pitfall 4: Focus Transition Between RowList and MarkupGrid
**What goes wrong:** Focus gets stuck at the boundary, or jumps unexpectedly when navigating down from last hub row to library grid (or up from grid to hub rows).
**Why it happens:** RowList and MarkupGrid are separate SceneGraph components with independent focus chains. Neither knows the other exists.
**How to avoid:** Handle `onKeyEvent` in HomeScreen to detect "down" key when on last hub row and manually `setFocus` to grid. Similarly detect "up" on first grid row and transfer to hub rows. Track current focus area with a state variable (e.g., `m.focusArea`).
**Warning signs:** Users can reach the grid but can't get back to hub rows, or vice versa.

### Pitfall 5: API Task Collision on Refresh
**What goes wrong:** Old hub data overwrites new data, or callbacks fire in wrong order after timer-triggered reload.
**Why it happens:** Timer fires while previous hub load is still in progress; both tasks call the same callback. Old task completes after new task, overwriting newer data.
**How to avoid:** Track `m.isLoadingHubs` flag; skip refresh if already loading. In callback, verify the task reference matches the current `m.hubsTask` before processing response.
**Warning signs:** Hub rows flicker or show stale data intermittently, especially after returning from playback near a timer tick.

### Pitfall 6: Missing Duration Field for Progress Bars
**What goes wrong:** Progress bars show 0% or 100% incorrectly, or don't appear when they should.
**Why it happens:** Plex hub metadata includes `viewOffset` (ms) but `duration` may come from different fields depending on content type. Some hub responses may omit full media details.
**How to avoid:** Check for `duration` directly on the item first. If not present, check `Media[0].Part[0].duration`. If neither exists, hide the progress bar entirely rather than showing a broken bar. Always verify both values are non-zero before calculating.
**Warning signs:** Progress bars all show as empty or full, or appear on items that shouldn't have them.

### Pitfall 7: Sidebar View Toggle Complexity
**What goes wrong:** Switching between "hub+grid" and "full library grid" views creates state management bugs.
**Why it happens:** User decision requires sidebar to toggle views. Need to track current view mode, show/hide hub rows, and adjust grid positioning accordingly.
**How to avoid:** Use a simple `m.viewMode` string ("hubGrid" vs "libraryOnly"). When toggling, set RowList visible=true/false and reposition the grid. Don't destroy/recreate content -- just toggle visibility.
**Warning signs:** Hub rows appear in library-only mode, grid position wrong after toggle, focus lost on toggle.

## Code Examples

### RowList XML Configuration for Hub Rows
```xml
<!-- In HomeScreen.xml, inside contentArea Group -->
<RowList
    id="hubRowList"
    translation="[0, 0]"
    itemSize="[1620, 430]"
    numRows="3"
    rowItemSize="[[260, 390]]"
    rowItemSpacing="[[20, 0]]"
    itemSpacing="[0, 10]"
    showRowLabel="[true, true, true]"
    rowLabelOffset="[[0, 0]]"
    drawFocusFeedback="true"
    focusBitmapBlendColor="0xE5A00DFF"
    vertFocusAnimationStyle="floatingFocus"
    rowFocusAnimationStyle="floatingFocus"
    itemComponentName="PosterGridItem"
    visible="false"
/>
```

### Hub Row Item Selection Handler
```brightscript
sub onHubItemSelected(event as Object)
    selectedInfo = event.getData()  ' [rowIndex, itemIndex]
    rowIndex = selectedInfo[0]
    itemIndex = selectedInfo[1]

    ' Determine which hub type this row represents
    hubType = m.hubRowMap[rowIndex.ToStr()]

    ' Get the content node for this item
    rowContent = m.hubRowList.content.getChild(rowIndex)
    itemContent = rowContent.getChild(itemIndex)

    if hubType = "continueWatching"
        ' Per user decision: resume playback immediately
        m.top.itemSelected = {
            action: "play"
            ratingKey: itemContent.ratingKey
            itemType: itemContent.itemType
            viewOffset: itemContent.viewOffset
        }
    else
        ' On Deck and Recently Added: open detail screen
        m.top.itemSelected = {
            action: "detail"
            ratingKey: itemContent.ratingKey
            itemType: itemContent.itemType
        }
    end if
end sub
```

### Dynamic Repositioning After Hub Load
```brightscript
sub repositionContentBelowHubs(hubRowCount as Integer)
    if hubRowCount = 0
        ' No hub rows -- position as before
        m.filterBar.translation = [20, 20]
        m.posterGrid.translation = [20, 100]
    else
        ' Each hub row: ~430px item height + ~10px spacing + ~30px label
        hubHeight = hubRowCount * 470
        m.filterBar.translation = [20, hubHeight + 20]
        m.posterGrid.translation = [20, hubHeight + 100]
    end if
end sub
```

### Sidebar View Toggle
```brightscript
sub onViewModeChanged(mode as String)
    if mode = "libraryOnly"
        m.hubRowList.visible = false
        m.filterBar.translation = [20, 20]
        m.posterGrid.translation = [20, 100]
    else  ' "hubGrid"
        m.hubRowList.visible = true
        repositionContentBelowHubs(m.hubRowCount)
    end if
end sub
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate `/library/onDeck` + `/library/recentlyAdded` calls | `/hubs` endpoint returns all hub types in one call | Plex ~2020 | Single API call for all hub content; server controls hub selection/ordering |
| Full hub reload on every refresh | `onlyTransient=1` parameter for efficient refresh | Plex ~2021 | Only refetches hubs that change after playback (Continue Watching, On Deck) |
| Multiple stacked custom scroll components | Single RowList with dynamic numRows | Roku OS 8+ | RowList natively handles multi-row horizontal scroll with vertical navigation |

**Deprecated/outdated:**
- `/library/onDeck` and `/library/recentlyAdded` endpoints still work as standalone calls, but the `/hubs` endpoint is the modern approach that returns all hub types with server-configured ordering and visibility. The existing HomeScreen already calls these via sidebar "special actions" -- Phase 3 should migrate to `/hubs` instead.

## Open Questions

1. **Exact hubIdentifier strings on target Plex server**
   - What we know: Common identifiers include `home.continue`, `home.ondeck`, and variations with `recentlyadded`. The API docs show `home.onDeck` as an example context of `hub.home.onDeck`.
   - What's unclear: Exact identifier strings may vary by PMS version. Some servers may return `home.movies.recent` and `home.tv.recent` as separate hubs rather than a combined recently added.
   - Recommendation: Log all hubIdentifier values from the first `/hubs` call during development. Use case-insensitive partial matching (e.g., `Instr` for "continue", "ondeck", "recent") as fallback. Accept the first match for recently added.

2. **Duration field availability in `/hubs` metadata**
   - What we know: `viewOffset` (ms) is reliably present for in-progress items. The `duration` field should be on the item for movies and episodes.
   - What's unclear: Whether all hub response items include `duration` or if it requires a separate metadata fetch for some content types.
   - Recommendation: Check for `duration` on item first, fall back to `Media[0].duration` if available. If neither exists, hide progress bar. Test with real server data during development.

3. **RowList + MarkupGrid combined vertical scrolling feel**
   - What we know: These are separate components; the transition between them requires manual focus management via onKeyEvent.
   - What's unclear: Whether the visual transition feels smooth or if there's a jarring jump when focus moves between the two.
   - Recommendation: Test on device early. If the transition feels rough, consider adding a brief focus animation or adjusting translation to create visual continuity. The `vertFocusAnimationStyle="floatingFocus"` on RowList may help within the hub rows themselves.

4. **Scroll position preservation on hub refresh**
   - What we know: User decision requires hub rows to remember horizontal scroll position.
   - What's unclear: Whether RowList preserves scroll position when content is replaced (e.g., on refresh timer tick).
   - Recommendation: Before refreshing, save `rowItemFocused` value. After setting new content, restore via `jumpToRowItem`. If content structure changed (different row count), reset to beginning.

## Sources

### Primary (HIGH confidence)
- Roku RowList documentation (sdkdocs-archive.roku.com/RowList_1611919.html) - Full field reference, content structure, focus behavior
- Plex API Get Global Hubs (plexapi.dev/api-reference/hubs/get-global-hubs) - Endpoint params, response structure, hub fields, example JSON
- Existing codebase: HomeScreen.brs, PosterGridItem.brs, PlexApiTask.brs, MediaRow.brs, Sidebar.brs - Current architecture and patterns

### Secondary (MEDIUM confidence)
- Plex Python PlexAPI docs (python-plexapi.readthedocs.io/en/latest/modules/library.html) - Hub identifier names and metadata field references
- Roku SDK Development Guide (github.com/rokudev/SDK-Development-Guide) - RowList usage patterns and best practices
- Roku Community RowList discussions (community.roku.com) - Focus behavior and content structure patterns

### Tertiary (LOW confidence)
- Exact hub identifier strings per PMS version - Based on community references and third-party documentation; needs validation against actual server response during development
- Duration field availability in hub metadata - Needs validation with real Plex server responses

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - RowList is the documented Roku component for this exact use case; `/hubs` is the official Plex API endpoint
- Architecture: HIGH - Patterns follow existing codebase conventions (Task nodes, ContentNode trees, observer pattern); extending proven patterns
- Pitfalls: HIGH - Based on documented Roku component behavior, existing codebase patterns, and Plex API known behaviors
- Hub identifiers: MEDIUM - Exact strings may vary; partial matching recommended as safety net
- Progress bar duration data: MEDIUM - Likely available but needs server-side validation

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable platform APIs, unlikely to change)
