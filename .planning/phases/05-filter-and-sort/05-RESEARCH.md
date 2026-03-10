# Phase 5: Filter and Sort - Research

**Researched:** 2026-03-10
**Domain:** Plex API filtering/sorting + Roku SceneGraph UI (bottom sheet, animations, list components)
**Confidence:** HIGH

## Summary

Phase 5 adds sorting and filtering controls to the library grid screen. The Plex Media Server API natively supports server-side filtering and sorting via query parameters on the `/library/sections/{id}/all` endpoint, meaning the client does not need to do any client-side data manipulation -- it re-fetches from the server with updated parameters. The existing `PlexApiTask` and `loadLibrary()` flow already pass `sort` and filter params, making this a natural extension.

The UI consists of three parts: (1) a persistent filter bar below the library header showing active state, (2) a bottom sheet panel that slides up when the user presses the Options (*) button, and (3) fade transitions on the grid when results change. Roku SceneGraph provides built-in `RadioButtonList` (single-select for sort), `CheckList` (multi-select for genres), and `Animation`/`FloatFieldInterpolator`/`Vector2DFieldInterpolator` nodes for all animations needed.

**Primary recommendation:** Use server-side filtering exclusively via Plex API query parameters. Build the bottom sheet as a custom SceneGraph component using `Animation` + `Vector2DFieldInterpolator` for slide-up, and `RadioButtonList`/`CheckList` for filter options within it. The existing `FilterBar` widget gets replaced/upgraded to show the active filter summary text.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Options (*) button on the Roku remote opens the filter/sort panel
- Bottom sheet style -- slides up from the bottom of the screen, grid remains visible above
- Sheet stays open while user tweaks multiple filters; dismiss with Back button
- Filters apply immediately as each option is changed (no Apply button -- grid updates live above the sheet)
- Filters stack freely with AND logic -- e.g., Genre: Action AND Year: 2020s AND Unwatched all combine
- Genre supports multi-select -- user can pick multiple genres (OR logic within genre, AND with other filter types)
- Sort options: Title, Date Added, Year, Rating (the four from success criteria)
- Sort direction is toggleable -- ascending/descending for each sort option
- Persistent text bar below the library header shows active filters and sort (e.g., "Genre: Action, Comedy . Unwatched . Sort: Year ^")
- Bar is always visible, even in default state -- shows "All . Sort: Title A-Z" when unfiltered
- Item count displayed (e.g., "42 items" or "42 of 1,200")
- Sort and filters are mixed together in the bottom sheet (no separate sections)
- "Clear All" button in the bottom sheet resets everything
- Individual filters can be cleared one by one (not just all-or-nothing)
- Fade transition when grid re-populates after filter change (current grid fades out, new results fade in)
- Focus resets to top-left item after any filter/sort change
- Empty filter results show "No items match your filters" message with a "Clear Filters" button

### Claude's Discretion
- Dropdown/list behavior when selecting filter values within the bottom sheet
- Exact bottom sheet height and animation timing
- Filter bar typography and spacing
- Fade transition duration and easing

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core (Built-in Roku SceneGraph -- no external libraries)
| Component | Type | Purpose | Why Standard |
|-----------|------|---------|--------------|
| `RadioButtonList` | SceneGraph node | Single-select for sort option | Built-in, handles radio selection with `checkedItem` field |
| `CheckList` | SceneGraph node | Multi-select for genres | Built-in, `checkedState` array tracks multiple selections |
| `LabelList` | SceneGraph node | Year/decade selection, unwatched toggle | Built-in list with simple item selection |
| `Animation` | SceneGraph node | Container for interpolator animations | Standard Roku animation system |
| `Vector2DFieldInterpolator` | SceneGraph node | Bottom sheet slide-up/down animation | Animates `translation` field for slide effect |
| `FloatFieldInterpolator` | SceneGraph node | Grid fade in/out transition | Animates `opacity` field for fade effect |
| `ButtonGroup` | SceneGraph node | "Clear All" button in bottom sheet | Reusable built-in button component |

### Plex API Endpoints
| Endpoint | Method | Purpose | Parameters |
|----------|--------|---------|------------|
| `/library/sections/{id}/all` | GET | Fetch filtered/sorted library items | `sort`, `genre`, `year`, `unwatched`, pagination params |
| `/library/sections/{id}/genre` | GET | List available genres for a library | `type` (1=movie, 2=show) |
| `/library/sections/{id}/year` | GET | List available years for a library | `type` (1=movie, 2=show) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Server-side filtering | Client-side array filtering | Server-side is correct: handles paginated libraries of thousands, no memory issues |
| RadioButtonList for sort | LabelList with manual icons | RadioButtonList has built-in radio button UI, less custom code |
| CheckList for genre | Custom toggle buttons | CheckList has built-in multi-select with checkedState array |

## Architecture Patterns

### New Components
```
SimPlex/components/widgets/
  FilterBottomSheet.xml/.brs   # Bottom sheet panel with filter/sort controls
  FilterBar.xml/.brs           # UPGRADE existing -- active filter summary text bar
```

### Pattern 1: Server-Side Filtering via Query Parameters
**What:** All filtering and sorting happens on the Plex server. The client sends query parameters and re-fetches.
**When to use:** Every filter/sort change triggers a new API call with updated params.
**Example:**
```brightscript
' Source: Plex API documentation (plexopedia.com, python-plexapi docs)
' Sort: field:direction format
' sort=titleSort:asc | sort=addedAt:desc | sort=year:asc | sort=rating:desc

' Unwatched filter:
' unwatched=1

' Genre filter (tag-based, supports multiple via comma):
' genre=Action | genre=Action,Comedy

' Year filter (supports operators):
' year=2020 | year>=2020 | year=2020,2021,2022

' Combined example:
endpoint = "/library/sections/" + sectionId + "/all"
params = {
    "sort": "year:desc"
    "genre": "Action,Comedy"
    "unwatched": "1"
    "X-Plex-Container-Start": "0"
    "X-Plex-Container-Size": "50"
}
```

### Pattern 2: Bottom Sheet Slide Animation
**What:** A Group node positioned off-screen (below 1080) slides up via Vector2DFieldInterpolator.
**When to use:** Options button pressed while in library grid view.
**Example:**
```xml
<!-- Source: Roku Animation docs (developer.roku.com) -->
<Animation id="slideUpAnim" duration="0.3" easeFunction="inOutCubic">
    <Vector2DFieldInterpolator
        id="slideUpInterp"
        key="[0.0, 1.0]"
        keyValue="[[0, 1080], [0, 580]]"
        fieldToInterp="sheetGroup.translation"
    />
</Animation>
<Animation id="slideDownAnim" duration="0.25" easeFunction="inOutCubic">
    <Vector2DFieldInterpolator
        id="slideDownInterp"
        key="[0.0, 1.0]"
        keyValue="[[0, 580], [0, 1080]]"
        fieldToInterp="sheetGroup.translation"
    />
</Animation>
```
```brightscript
' Open bottom sheet
sub openSheet()
    m.sheetGroup.visible = true
    m.slideUpAnim.control = "start"
end sub

' Close bottom sheet
sub closeSheet()
    m.slideDownAnim.observeField("state", "onSlideDownComplete")
    m.slideDownAnim.control = "start"
end sub

sub onSlideDownComplete(event as Object)
    if event.getData() = "stopped"
        m.sheetGroup.visible = false
        m.slideDownAnim.unobserveField("state")
    end if
end sub
```

### Pattern 3: Grid Fade Transition on Filter Change
**What:** When filters change, fade out grid opacity, swap content, fade in.
**When to use:** Every time filters or sort changes trigger a re-fetch.
**Example:**
```xml
<!-- Source: Roku Animation docs (developer.roku.com) -->
<Animation id="gridFadeOut" duration="0.15" easeFunction="linear">
    <FloatFieldInterpolator
        key="[0.0, 1.0]"
        keyValue="[1.0, 0.0]"
        fieldToInterp="posterGrid.opacity"
    />
</Animation>
<Animation id="gridFadeIn" duration="0.2" easeFunction="linear">
    <FloatFieldInterpolator
        key="[0.0, 1.0]"
        keyValue="[0.0, 1.0]"
        fieldToInterp="posterGrid.opacity"
    />
</Animation>
```
```brightscript
sub onFilterChanged()
    ' Fade out, then re-fetch
    m.gridFadeOut.observeField("state", "onFadeOutDone")
    m.gridFadeOut.control = "start"
end sub

sub onFadeOutDone(event as Object)
    if event.getData() = "stopped"
        m.gridFadeOut.unobserveField("state")
        m.currentOffset = 0
        loadLibrary()  ' Will fade in when data arrives
    end if
end sub

sub processApiResponse()
    ' ... build content nodes ...
    m.posterGrid.content = content
    m.gridFadeIn.control = "start"
end sub
```

### Pattern 4: Fetching Available Filter Values
**What:** Fetch genre and year lists from the server when a library section is selected.
**When to use:** Once per library section selection; cache the results.
**Example:**
```brightscript
' Source: Plex API docs (python-plexapi, plexopedia)
' Fetch genres for a movie library (type=1 for movies, type=2 for shows)
sub loadFilterOptions()
    ' Fetch genres
    genreTask = CreateObject("roSGNode", "PlexApiTask")
    genreTask.endpoint = "/library/sections/" + m.currentSectionId + "/genre"
    genreTask.params = { "type": m.currentSectionType }
    genreTask.observeField("status", "onGenresLoaded")
    genreTask.control = "run"
    m.genreTask = genreTask

    ' Fetch years
    yearTask = CreateObject("roSGNode", "PlexApiTask")
    yearTask.endpoint = "/library/sections/" + m.currentSectionId + "/year"
    yearTask.params = { "type": m.currentSectionType }
    yearTask.observeField("status", "onYearsLoaded")
    yearTask.control = "run"
    m.yearTask = yearTask
end sub
```

### Pattern 5: Filter State Management
**What:** Maintain filter state as an associative array that maps directly to API query params.
**When to use:** Central state object passed between FilterBottomSheet, FilterBar, and loadLibrary().
**Example:**
```brightscript
' Filter state object -- maps 1:1 to API query params
m.filterState = {
    sort: "titleSort:asc"      ' Default sort
    genre: ""                   ' Comma-separated genre keys (OR logic)
    year: ""                    ' Year value or range
    unwatched: ""               ' "1" or "" (empty = all)
}

' Build params from filter state
function buildFilterParams() as Object
    params = {
        "sort": m.filterState.sort
        "X-Plex-Container-Start": "0"
        "X-Plex-Container-Size": m.global.constants.PAGE_SIZE.ToStr()
    }
    if m.filterState.genre <> ""
        params["genre"] = m.filterState.genre
    end if
    if m.filterState.year <> ""
        params["year"] = m.filterState.year
    end if
    if m.filterState.unwatched <> ""
        params["unwatched"] = m.filterState.unwatched
    end if
    return params
end function
```

### Anti-Patterns to Avoid
- **Client-side filtering:** Never fetch all items then filter in BrightScript. Libraries can have thousands of items. Always use server-side filtering via API params.
- **Blocking the render thread:** Genre/year list fetches must use Task nodes, never roUrlTransfer on render thread.
- **Rebuilding filter lists on every open:** Cache genre/year lists per section. Only re-fetch when section changes.
- **Deep-copying content nodes:** When clearing grid for new filter results, create a fresh ContentNode tree rather than trying to remove children from existing content.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Radio button selection | Custom toggle buttons with manual state | `RadioButtonList` | Built-in radio selection, focus management, `checkedItem` field |
| Multi-select checkboxes | Custom checkbox items with manual state | `CheckList` | Built-in `checkedState` array, checkbox icons, focus management |
| Slide animation | Manual timer-based position updates | `Animation` + `Vector2DFieldInterpolator` | Hardware-accelerated, proper easing, state callbacks |
| Fade animation | Manual opacity stepping | `Animation` + `FloatFieldInterpolator` | Smooth 60fps, no render thread blocking |
| Server-side filtering | Client-side array filtering | Plex API query params | Handles pagination, thousands of items, zero memory overhead |

**Key insight:** Roku provides all the UI building blocks (RadioButtonList, CheckList, Animation nodes). The Plex API provides all filtering/sorting server-side. The work is wiring them together and managing state, not building primitives.

## Common Pitfalls

### Pitfall 1: Genre Key vs Display Name Mismatch
**What goes wrong:** Using genre display names (e.g., "Science Fiction") as API filter values instead of the key/tag returned by the genre endpoint.
**Why it happens:** The `/library/sections/{id}/genre` endpoint returns objects with both `title` (display) and `key` (API param) fields. They may differ.
**How to avoid:** Always use the `key` field from the genre list response as the filter value. Display the `title` to the user.
**Warning signs:** Filters return zero results for genres that clearly have content.

### Pitfall 2: Pagination Reset on Filter Change
**What goes wrong:** Appending filtered results to an existing unfiltered grid, or continuing pagination from the wrong offset.
**Why it happens:** `m.currentOffset` isn't reset to 0 when filters change.
**How to avoid:** Always set `m.currentOffset = 0` and create a fresh ContentNode tree when any filter or sort changes. The existing `onFilterChanged` handler already does this correctly.
**Warning signs:** Mixed content from different filter states in the grid.

### Pitfall 3: Bottom Sheet Focus Trapping
**What goes wrong:** D-pad navigation escapes the bottom sheet into the grid behind it, or focus gets stuck.
**Why it happens:** SceneGraph's default focus chain doesn't know about overlay semantics.
**How to avoid:** The bottom sheet's `onKeyEvent` must consume all directional keys that would escape the sheet. Only Back button should dismiss. Explicitly manage focus within the sheet's internal components.
**Warning signs:** Focus jumps to grid items behind the sheet, or Back button doesn't close the sheet.

### Pitfall 4: Race Conditions on Rapid Filter Changes
**What goes wrong:** User rapidly toggles filters, multiple API tasks run concurrently, responses arrive out of order, grid shows stale results.
**Why it happens:** Each filter change spawns a new PlexApiTask, but previous tasks aren't cancelled.
**How to avoid:** Cancel the previous API task before starting a new one: `m.currentApiTask.control = "stop"`. Track a request ID or sequence number to discard stale responses.
**Warning signs:** Grid briefly flashes wrong content, or shows results from a previous filter state.

### Pitfall 5: Library Type Mismatch for Filters
**What goes wrong:** Genre/year endpoint returns wrong or empty data because the `type` parameter doesn't match the library type.
**Why it happens:** Movie libraries use `type=1`, TV show libraries use `type=2`. Using the wrong type returns no filter choices.
**How to avoid:** Store `sectionType` when selecting a library (the existing code already tracks `m.currentSectionType`). Pass it to genre/year fetch endpoints.
**Warning signs:** Genre list is empty for a library that clearly has genres.

### Pitfall 6: Sort Field Name Confusion
**What goes wrong:** Sorting by title uses the wrong field name and results appear unsorted.
**Why it happens:** The sort field for title is `titleSort` (not `title`). Using `title` may not sort correctly because it includes articles like "The".
**How to avoid:** Use the correct Plex sort field names: `titleSort`, `addedAt`, `year`, `rating`.
**Warning signs:** "The Godfather" appears under T instead of G when sorting by title.

## Code Examples

### Plex API Sort Parameter Values
```brightscript
' Source: Plex API documentation (python-plexapi, plexopedia)
' Format: "field:direction" where direction is "asc" or "desc"

' Title A-Z (default)
sort = "titleSort:asc"

' Title Z-A
sort = "titleSort:desc"

' Date Added (newest first)
sort = "addedAt:desc"

' Date Added (oldest first)
sort = "addedAt:asc"

' Year (newest first)
sort = "year:desc"

' Year (oldest first)
sort = "year:asc"

' Rating (highest first)
sort = "rating:desc"

' Rating (lowest first)
sort = "rating:asc"
```

### Plex API Filter Parameter Values
```brightscript
' Source: Plex API documentation (plexopedia, python-plexapi, Arcanemagus wiki)

' Unwatched only
params["unwatched"] = "1"

' Single genre
params["genre"] = "28"  ' Genre key from /genre endpoint

' Multiple genres (OR logic)
params["genre"] = "28,35"  ' Action OR Comedy

' Single year
params["year"] = "2024"

' Year range (decade) -- multiple values
params["year"] = "2020,2021,2022,2023,2024,2025"

' Combined filters (AND logic between different filter types)
' genre=28,35 AND unwatched=1 AND year=2024
params["genre"] = "28,35"
params["unwatched"] = "1"
params["year"] = "2024"
```

### RadioButtonList for Sort Options
```brightscript
' Source: Roku SceneGraph docs (developer.roku.com)
' In XML:
' <RadioButtonList id="sortList" itemSize="[400, 48]" />

' In BrightScript:
sub populateSortList()
    content = CreateObject("roSGNode", "ContentNode")
    sortOptions = ["Title A-Z", "Title Z-A", "Date Added (Newest)", "Date Added (Oldest)", "Year (Newest)", "Year (Oldest)", "Rating (Highest)", "Rating (Lowest)"]
    for each opt in sortOptions
        item = content.createChild("ContentNode")
        item.title = opt
    end for
    m.sortList.content = content
    m.sortList.checkedItem = 0  ' Default: Title A-Z
end sub

sub onSortSelected(event as Object)
    index = m.sortList.checkedItem
    sortValues = ["titleSort:asc", "titleSort:desc", "addedAt:desc", "addedAt:asc", "year:desc", "year:asc", "rating:desc", "rating:asc"]
    m.filterState.sort = sortValues[index]
    applyFilters()
end sub
```

### CheckList for Genre Multi-Select
```brightscript
' Source: Roku SceneGraph docs (developer.roku.com)
' In XML:
' <CheckList id="genreList" itemSize="[400, 48]" />

' In BrightScript:
sub populateGenreList(genres as Object)
    ' genres = array from /library/sections/{id}/genre API response
    content = CreateObject("roSGNode", "ContentNode")
    m.genreKeys = []
    for each genre in genres
        item = content.createChild("ContentNode")
        item.title = genre.title  ' Display name: "Action", "Comedy", etc.
        m.genreKeys.push(genre.key)  ' API key for filtering
    end for
    m.genreList.content = content
end sub

sub onGenreChanged(event as Object)
    ' checkedState is an array of booleans
    states = m.genreList.checkedState
    selectedKeys = []
    for i = 0 to states.count() - 1
        if states[i] = true
            selectedKeys.push(m.genreKeys[i])
        end if
    end for
    m.filterState.genre = selectedKeys.join(",")
    applyFilters()
end sub
```

### Filter Summary Text Builder
```brightscript
' Build the filter bar display text
function buildFilterSummary() as String
    parts = []

    ' Genre display
    if m.filterState.genre <> ""
        genreNames = getSelectedGenreNames()
        parts.push("Genre: " + genreNames.join(", "))
    end if

    ' Unwatched
    if m.filterState.unwatched = "1"
        parts.push("Unwatched")
    end if

    ' Year
    if m.filterState.year <> ""
        parts.push("Year: " + m.filterState.year)
    end if

    ' Build summary
    if parts.count() = 0
        filterText = "All"
    else
        filterText = parts.join(" . ")
    end if

    ' Sort display
    sortDisplay = getSortDisplayName(m.filterState.sort)
    filterText = filterText + " . Sort: " + sortDisplay

    return filterText
end function
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Client-side filtering | Server-side API filtering | Always (Plex API design) | Handles large libraries efficiently |
| Custom animation timers | Animation node with interpolators | Roku SceneGraph v1+ | Hardware-accelerated, proper easing |
| ButtonGroup for filters | CheckList/RadioButtonList | Roku SceneGraph v1+ | Built-in selection state management |

**Existing code state:**
- `FilterBar` widget exists but is minimal (just "All" and "Unwatched" ButtonGroup). Needs full redesign.
- `HomeScreen.brs` already has `onFilterChanged` handler, `m.filterBar.activeFilters`, and applies filters in `loadLibrary()`. This infrastructure is reusable.
- `loadLibrary()` already passes `sort` param (`"titleSort:asc"` hardcoded) and merges `activeFilters` into params. This is the exact integration point.

## Open Questions

1. **Genre key format from Plex API**
   - What we know: The `/library/sections/{id}/genre` endpoint returns genre objects with `title` and `key` fields
   - What's unclear: Exact format of `key` -- is it a numeric ID (e.g., "28") or a string slug (e.g., "action")? This affects the `genre=` filter param value.
   - Recommendation: The executor should inspect the actual API response from a real server during implementation. Use `key` field regardless of format. LOW confidence on exact format.

2. **Year endpoint response format**
   - What we know: `/library/sections/{id}/year` returns available years
   - What's unclear: Whether the response includes decade groupings or just individual years. User wants "filter by year or decade."
   - Recommendation: Fetch individual years, group into decades client-side (2020s = 2020-2029). The API likely returns individual years only.

3. **Plex `type` parameter values**
   - What we know: `type=1` for movies, `type=2` for shows is the standard
   - What's unclear: Whether the genre/year endpoints require the `type` param or work without it
   - Recommendation: Always pass `type` param based on `m.currentSectionType` to be safe

## Sources

### Primary (HIGH confidence)
- Plex API filtering documentation (plexopedia.com/plex-media-server/api/filter/) -- filter syntax, operators, field names
- Plex API Python PlexAPI docs (python-plexapi.readthedocs.io) -- sort format `field:direction`, genre/year endpoints
- Roku SceneGraph Animation docs (developer.roku.com) -- Animation, Vector2DFieldInterpolator, FloatFieldInterpolator
- Roku SceneGraph XSD schema (devtools.web.roku.com/schema/RokuSceneGraph.xsd) -- Animation node attributes

### Secondary (MEDIUM confidence)
- Plex Web API Overview wiki (github.com/Arcanemagus/plex-api/wiki) -- filter endpoint patterns, genre/year list endpoints
- Plexopedia unwatched movies (plexopedia.com/plex-media-server/api/library/movies-unwatched/) -- unwatched endpoint, available filter params
- Roku Community forums -- CheckList checkedState usage patterns

### Tertiary (LOW confidence)
- Genre key format -- only inferred from python-plexapi source code, not verified against live API
- Year endpoint decade grouping -- assumed individual years based on API pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all components are built-in Roku SceneGraph or native Plex API
- Architecture: HIGH -- extends existing patterns already in the codebase (FilterBar, loadLibrary, PlexApiTask)
- Plex API sort/filter params: HIGH -- multiple sources confirm `sort=field:dir`, `genre=key`, `unwatched=1`, `year=val`
- Plex API genre/year list endpoints: MEDIUM -- confirmed by multiple sources but exact response format not verified
- Roku animation patterns: HIGH -- official Roku documentation confirms Animation + interpolator approach
- Bottom sheet UI pattern: MEDIUM -- no built-in bottom sheet component; must be custom-built from Group + Animation
- Pitfalls: HIGH -- derived from direct codebase analysis and known Roku development patterns

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (stable APIs and platform)
