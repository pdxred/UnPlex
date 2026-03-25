' ===== SearchScreen — 3-row keyboard + inline filters, horizontal results =====
'
' Layout (FHD 1920×1080):
'   y=25:   "Search" title + live query text
'   y=80:   Single keyboard row containing all controls:
'             Letters (12 cols × 3 rows) | Action keys (Space/Delete/Clear) |
'             2px separator | Filter buttons (All/Movies/TV Shows/Other)
'             All action and filter buttons span full 3-row height (152px)
'   y=240:  Divider
'   y=260:  Results — single horizontal row of posters (scrolls left/right)
'
' Focus areas: "keyboard" | "grid"
'   Keyboard includes letter grid, action keys, AND filter buttons in one
'   continuous left/right navigation strip.
'   Down from keyboard → grid (if results exist)
'   Up from grid → keyboard
'   Back: grid→keyboard, keyboard→exit

sub init()
    ' ── Layout dimensions ──
    m.KEY_W  = 48
    m.KEY_H  = 48
    m.KEY_SP = 4
    m.GRID_COLS = 12
    m.KB_ROWS = 3
    m.ACTION_GAP = 30
    m.ACTION_W = 135
    m.ACTION_H = (m.KEY_H * m.KB_ROWS) + (m.KEY_SP * (m.KB_ROWS - 1))  ' 152px, spans all 3 rows
    m.ACTION_SP = 10
    m.SEPARATOR_GAP = 15
    m.SEPARATOR_W = 2
    m.FILTER_W = 135   ' same width as action keys
    m.FILTER_SP = 10   ' same spacing as action keys

    m.queryLabel = m.top.findNode("queryLabel")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.emptyState = m.top.findNode("emptyState")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")
    m.keyboardGroup = m.top.findNode("keyboardGroup")

    m.filterIndex = 0   ' 0=All, 1=Movies, 2=TV Shows, 3=Other
    m.searchQuery = ""
    m.focusArea = "keyboard"  ' "keyboard" | "grid"
    m.retryCount = 0
    m.retryContext = invalid
    m.lastSearchResponse = invalid

    ' Keyboard state: row (0-2 for letter grid), col (0 to totalCols-1)
    m.kbRow = 0
    m.kbCol = 0

    ' Build the entire keyboard row: letters + actions + separator + filters
    buildKeyboard()

    ' Configure results grid for horizontal single-row layout
    m.resultsGrid.numRows = 1

    ' Debounce timer for search
    m.debounceTimer = CreateObject("roSGNode", "Timer")
    m.debounceTimer.duration = 0.5
    m.debounceTimer.repeat = false
    m.debounceTimer.observeField("fire", "onDebounceTimer")

    ' Search task
    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")

    ' Observers
    m.resultsGrid.observeField("itemSelected", "onGridItemSelected")
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")
    m.global.observeField("serverReconnected", "onServerReconnected")
    m.top.observeField("focusedChild", "onFocusChange")

    ' Initial focus
    m.top.setFocus(true)
    updateKeyboardFocus()
end sub

' ========== Keyboard Construction ==========

sub buildKeyboard()
    ' ── Section 1: Letter/number grid (12 cols × 3 rows) ──
    '   Row 0: A-L, Row 1: M-X, Row 2: Y-Z + 0-9
    m.gridKeys = []
    rows = [
        ["A","B","C","D","E","F","G","H","I","J","K","L"],
        ["M","N","O","P","Q","R","S","T","U","V","W","X"],
        ["Y","Z","0","1","2","3","4","5","6","7","8","9"]
    ]

    for row = 0 to m.KB_ROWS - 1
        rowArr = []
        for col = 0 to m.GRID_COLS - 1
            ch = rows[row][col]
            x = col * (m.KEY_W + m.KEY_SP)
            y = row * (m.KEY_H + m.KEY_SP)
            info = createKeyCell(x, y, m.KEY_W, m.KEY_H, ch)
            rowArr.push(info)
        end for
        m.gridKeys.push(rowArr)
    end for

    ' ── Section 2: Action keys (Space, Delete, Clear) — tall, spanning 3 rows ──
    m.actionKeys = []
    actionStartX = m.GRID_COLS * (m.KEY_W + m.KEY_SP) + m.ACTION_GAP
    actionLabels = ["Space", "Delete", "Clear"]
    actionChars  = ["SPC", "DEL", "CLR"]

    for i = 0 to 2
        x = actionStartX + i * (m.ACTION_W + m.ACTION_SP)
        info = createKeyCell(x, 0, m.ACTION_W, m.ACTION_H, actionLabels[i])
        info.char = actionChars[i]
        m.actionKeys.push(info)
    end for

    ' ── Vertical separator ──
    lastActionEndX = actionStartX + 2 * (m.ACTION_W + m.ACTION_SP) + m.ACTION_W
    sepX = lastActionEndX + m.SEPARATOR_GAP
    separator = CreateObject("roSGNode", "Rectangle")
    separator.width = m.SEPARATOR_W
    separator.height = m.ACTION_H
    separator.color = "0xFFFFFF25"
    separator.translation = [sepX, 0]
    m.keyboardGroup.appendChild(separator)

    ' ── Section 3: Filter buttons — same style as action keys ──
    m.filterKeys = []
    filterStartX = sepX + m.SEPARATOR_W + m.SEPARATOR_GAP
    filterLabels = ["All", "Movies", "TV Shows", "Other"]
    filterChars  = ["F_ALL", "F_MOV", "F_TV", "F_OTH"]

    for i = 0 to 3
        x = filterStartX + i * (m.FILTER_W + m.FILTER_SP)
        info = createKeyCell(x, 0, m.FILTER_W, m.ACTION_H, filterLabels[i])
        info.char = filterChars[i]
        m.filterKeys.push(info)
    end for

    ' Apply initial active-filter visual (All)
    updateFilterActiveVisual()

    ' ── Column map for unified navigation ──
    '   cols 0..11  = letter grid (12)
    '   cols 12..14 = action keys (3)
    '   cols 15..18 = filter buttons (4)
    m.FIRST_ACTION_COL = m.GRID_COLS          ' 12
    m.FIRST_FILTER_COL = m.GRID_COLS + 3      ' 15
    m.totalCols = m.GRID_COLS + 3 + 4         ' 19
end sub

function createKeyCell(x as Integer, y as Integer, w as Integer, h as Integer, text as String) as Object
    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = w
    bg.height = h
    bg.color = "0xFFFFFF10"
    bg.translation = [x, y]
    m.keyboardGroup.appendChild(bg)

    label = CreateObject("roSGNode", "Label")
    label.width = w
    label.height = h
    label.horizAlign = "center"
    label.vertAlign = "center"
    label.font = "font:SmallBoldSystemFont"
    label.color = "0xCCCCCCFF"
    label.text = text
    label.translation = [x, y]
    m.keyboardGroup.appendChild(label)

    return { bg: bg, label: label, char: text }
end function

' ========== Filter Active Visual ==========

sub updateFilterActiveVisual()
    ' Show which filter is currently active (semi-transparent accent when
    ' that filter button is NOT focused, full accent handled by updateKeyboardFocus)
    for i = 0 to m.filterKeys.count() - 1
        fk = m.filterKeys[i]
        if i = m.filterIndex
            fk.bg.color = "0xF3B12560"
            fk.label.color = "0xFFFFFFFF"
        else
            fk.bg.color = "0xFFFFFF10"
            fk.label.color = "0xCCCCCCFF"
        end if
    end for
end sub

' ========== Keyboard Focus Visual ==========

sub updateKeyboardFocus()
    ' Reset all keys to default
    for row = 0 to m.KB_ROWS - 1
        for col = 0 to m.GRID_COLS - 1
            m.gridKeys[row][col].bg.color = "0xFFFFFF10"
            m.gridKeys[row][col].label.color = "0xCCCCCCFF"
        end for
    end for
    for i = 0 to 2
        m.actionKeys[i].bg.color = "0xFFFFFF10"
        m.actionKeys[i].label.color = "0xCCCCCCFF"
    end for

    ' Reset filter buttons to their active/inactive base state
    updateFilterActiveVisual()

    ' Highlight the focused key (overrides filter base state if on a filter)
    info = getKeyAt(m.kbRow, m.kbCol)
    if info <> invalid
        info.bg.color = "0xF3B125FF"
        info.label.color = "0x000000FF"
    end if
end sub

sub clearKeyboardHighlight()
    ' Remove focus highlight from all keys, preserving filter active state
    for row = 0 to m.KB_ROWS - 1
        for col = 0 to m.GRID_COLS - 1
            m.gridKeys[row][col].bg.color = "0xFFFFFF10"
            m.gridKeys[row][col].label.color = "0xCCCCCCFF"
        end for
    end for
    for i = 0 to 2
        m.actionKeys[i].bg.color = "0xFFFFFF10"
        m.actionKeys[i].label.color = "0xCCCCCCFF"
    end for
    updateFilterActiveVisual()
end sub

' Map unified (row, col) to a key info object
function getKeyAt(row as Integer, col as Integer) as Object
    if col < m.GRID_COLS
        ' Letter/number grid
        if row >= 0 and row < m.KB_ROWS and col < m.gridKeys[row].count()
            return m.gridKeys[row][col]
        end if
    else if col < m.FIRST_FILTER_COL
        ' Action keys (span all rows — row is ignored)
        actionIdx = col - m.FIRST_ACTION_COL
        if actionIdx >= 0 and actionIdx < 3
            return m.actionKeys[actionIdx]
        end if
    else
        ' Filter buttons (span all rows — row is ignored)
        filterIdx = col - m.FIRST_FILTER_COL
        if filterIdx >= 0 and filterIdx < m.filterKeys.count()
            return m.filterKeys[filterIdx]
        end if
    end if
    return invalid
end function

' Get the character/command string for the focused key
function getFocusedKeyChar() as String
    info = getKeyAt(m.kbRow, m.kbCol)
    if info <> invalid then return info.char
    return ""
end function

' ========== Focus Management ==========

sub onFocusChange(event as Object)
    ' Guard: only act when SearchScreen itself gains focus (hasFocus = true,
    ' meaning no child has focus). This avoids reacting to intermediate
    ' focus-chain transitions that cause dual-focus.
    if not m.top.hasFocus() then return

    if m.focusArea = "grid"
        ' We should be in grid mode but the Group itself got focus —
        ' re-delegate to the MarkupGrid.
        focusGrid()
    end if
    ' Otherwise keyboard mode: Group keeps focus, onKeyEvent handles input.
end sub

sub setFocusToArea(area as String)
    m.focusArea = area
    if area = "keyboard"
        ' Explicitly defocus and hide the grid's focus ring before
        ' reclaiming focus. In SceneGraph, setFocus(true) on a parent
        ' does NOT reliably unfocus a deeply nested grandchild — the
        ' MarkupGrid keeps its internal focus state and continues to
        ' render drawFocusFeedback and process key events.
        defocusGrid()
        updateKeyboardFocus()
        m.top.setFocus(true)
    else if area = "grid"
        clearKeyboardHighlight()
        focusGrid()
    end if
end sub

sub focusGrid()
    ' Enable focus feedback and give focus to the inner MarkupGrid
    innerGrid = m.resultsGrid.findNode("grid")
    if innerGrid <> invalid
        innerGrid.drawFocusFeedback = true
        innerGrid.setFocus(true)
    else
        m.resultsGrid.setFocus(true)
    end if
end sub

sub defocusGrid()
    ' Explicitly remove focus from the MarkupGrid AND disable its focus
    ' ring rendering. Without this, the grid retains visual highlight
    ' and continues processing key events even after the parent Group
    ' calls setFocus(true).
    innerGrid = m.resultsGrid.findNode("grid")
    if innerGrid <> invalid
        innerGrid.drawFocusFeedback = false
        innerGrid.setFocus(false)
    end if
end sub

' ========== Keyboard Input ==========

sub activateKey()
    key = getFocusedKeyChar()
    if key = "" then return

    ' ── Filter button activation ──
    if key = "F_ALL"
        applyFilter(0)
        return
    else if key = "F_MOV"
        applyFilter(1)
        return
    else if key = "F_TV"
        applyFilter(2)
        return
    else if key = "F_OTH"
        applyFilter(3)
        return
    end if

    ' ── Text input keys ──
    if key = "DEL"
        if m.searchQuery.Len() > 0
            m.searchQuery = m.searchQuery.Left(m.searchQuery.Len() - 1)
        end if
    else if key = "CLR"
        m.searchQuery = ""
    else if key = "SPC"
        m.searchQuery = m.searchQuery + " "
    else
        m.searchQuery = m.searchQuery + LCase(key)
    end if
    updateQueryDisplay()
    triggerSearch()
end sub

sub applyFilter(index as Integer)
    if m.filterIndex <> index
        m.filterIndex = index
        updateKeyboardFocus()
        if m.lastSearchResponse <> invalid
            processSearchResults()
        end if
    end if
end sub

sub updateQueryDisplay()
    if m.searchQuery.Len() > 0
        m.queryLabel.text = m.searchQuery
    else
        m.queryLabel.text = ""
    end if
end sub

' ========== Search Execution ==========

sub triggerSearch()
    m.debounceTimer.control = "stop"
    if m.searchQuery.Len() >= 2
        m.debounceTimer.control = "start"
    else
        m.resultsGrid.content = invalid
        m.emptyState.visible = false
        m.lastSearchResponse = invalid
    end if
end sub

sub onDebounceTimer(event as Object)
    if m.searchQuery.Len() >= 2
        performSearch()
    end if
end sub

sub performSearch()
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false
    m.retryGroup.visible = false
    m.retryContext = { query: m.searchQuery, requestType: "search" }

    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")
    m.searchTask.query = m.searchQuery
    m.searchTask.control = "run"
end sub

sub onSearchTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.retryCount = 0
        m.retryGroup.visible = false
        m.lastSearchResponse = m.searchTask.response
        processSearchResults()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        if m.retryCount = 0
            m.retryCount = 1
            retryLastSearch()
        else
            m.retryCount = 0
            showErrorDialog("Error", "Search failed. Please try again.")
        end if
    end if
end sub

' ========== Result Processing ==========

sub processSearchResults()
    response = m.lastSearchResponse
    if response = invalid or response.MediaContainer = invalid
        m.emptyState.visible = true
        return
    end if

    hubs = response.MediaContainer.Hub
    if hubs = invalid or hubs.count() = 0
        m.emptyState.visible = true
        return
    end if

    c = m.global.constants
    content = CreateObject("roSGNode", "ContentNode")
    hasResults = false

    for each hub in hubs
        hubType = invalid
        if hub.type <> invalid then hubType = hub.type

        if hub.Metadata <> invalid
            for each item in hub.Metadata
                effectiveType = invalid
                if item.type <> invalid and item.type <> ""
                    effectiveType = item.type
                else if hubType <> invalid
                    effectiveType = hubType
                end if

                effectiveSubtype = ""
                if item.subtype <> invalid and item.subtype <> ""
                    effectiveSubtype = item.subtype
                end if

                if not shouldIncludeItem(effectiveType, effectiveSubtype) then continue for

                ratingKeyStr = GetRatingKeyStr(item.ratingKey)
                node = content.createChild("ContentNode")
                node.addFields({
                    title: item.title
                    ratingKey: ratingKeyStr
                    itemType: effectiveType
                    thumb: ""
                })

                posterThumb = invalid
                if item.grandparentThumb <> invalid and item.grandparentThumb <> ""
                    posterThumb = item.grandparentThumb
                else if item.parentThumb <> invalid and item.parentThumb <> ""
                    posterThumb = item.parentThumb
                else if item.thumb <> invalid and item.thumb <> ""
                    posterThumb = item.thumb
                end if
                if posterThumb <> invalid
                    node.HDPosterUrl = BuildPosterUrl(posterThumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
                end if

                hasResults = true
            end for
        end if
    end for

    if hasResults
        m.resultsGrid.content = content
        m.emptyState.visible = false
    else
        m.resultsGrid.content = invalid
        m.emptyState.visible = true
    end if
end sub

function shouldIncludeItem(itemType as Dynamic, itemSubtype as String) as Boolean
    ' Filter logic:
    '   0 = All — show everything
    '   1 = Movies — type=movie AND subtype is NOT "clip"
    '   2 = TV Shows — type is show, episode, or season
    '   3 = Other — clips, home videos, anything not movie or TV
    if m.filterIndex = 0 then return true
    if itemType = invalid or itemType = "" then return (m.filterIndex = 3)

    t = LCase(itemType)
    st = LCase(itemSubtype)

    if m.filterIndex = 1
        return (t = "movie" and st <> "clip")
    end if
    if m.filterIndex = 2
        return (t = "show" or t = "episode" or t = "season")
    end if
    if m.filterIndex = 3
        isClip = (st = "clip" or t = "clip")
        isMovie = (t = "movie" and st <> "clip")
        isTv = (t = "show" or t = "episode" or t = "season")
        return (not isMovie and not isTv) or isClip
    end if
    return true
end function

' ========== Grid Item Selection ==========

sub onGridItemSelected(event as Object)
    index = event.getData()
    content = m.resultsGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        if item.itemType = "show"
            m.top.itemSelected = {
                action: "episodes"
                ratingKey: item.ratingKey
                title: item.title
            }
        else
            m.top.itemSelected = {
                action: "detail"
                ratingKey: item.ratingKey
                itemType: item.itemType
            }
        end if
    end if
end sub

' ========== Error Handling & Retry ==========

sub retryLastSearch()
    if m.retryContext = invalid then return
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")
    m.searchTask.query = m.retryContext.query
    m.searchTask.control = "run"
end sub

sub showErrorDialog(title as String, message as String)
    if m.top.getScene().dialog <> invalid then return
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
        retryLastSearch()
    else if index = 1
        showInlineRetry()
    end if
end sub

sub onErrorDialogClosed(event as Object)
    setFocusToArea(m.focusArea)
end sub

sub showInlineRetry()
    m.resultsGrid.visible = false
    m.emptyState.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.resultsGrid.visible = true
    retryLastSearch()
end sub

sub onServerReconnected(event as Object)
    if m.global.serverReconnected = true
        m.global.serverReconnected = false
        if m.searchQuery.Len() >= 2
            performSearch()
        end if
    end if
end sub

' ========== Key Event Handling ==========

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' ── Keyboard focus area (letters + actions + filters) ──
    if m.focusArea = "keyboard"
        if key = "OK"
            activateKey()
            return true
        else if key = "left"
            if m.kbCol > 0
                m.kbCol = m.kbCol - 1
                updateKeyboardFocus()
            end if
            return true
        else if key = "right"
            if m.kbCol < m.totalCols - 1
                m.kbCol = m.kbCol + 1
                updateKeyboardFocus()
            end if
            return true
        else if key = "up"
            if m.kbRow > 0 and m.kbCol < m.GRID_COLS
                ' Only letter/number grid has multiple rows
                m.kbRow = m.kbRow - 1
                updateKeyboardFocus()
                return true
            end if
            ' Top row — don't consume
            return false
        else if key = "down"
            if m.kbCol < m.GRID_COLS and m.kbRow < m.KB_ROWS - 1
                ' Move to next row within letter/number grid
                m.kbRow = m.kbRow + 1
                updateKeyboardFocus()
                return true
            end if
            ' Bottom of grid, or on tall key → move to results if available
            if m.resultsGrid.content <> invalid and m.resultsGrid.content.getChildCount() > 0
                setFocusToArea("grid")
                return true
            end if
            return true  ' consume to prevent focus escape
        else if key = "back"
            m.top.navigateBack = true
            return true
        end if
        return false
    end if

    ' ── Grid focus area ──
    if m.focusArea = "grid"
        if key = "up"
            ' Single-row horizontal grid — up always escapes to keyboard
            setFocusToArea("keyboard")
            return true
        else if key = "back"
            setFocusToArea("keyboard")
            return true
        else if key = "left" or key = "right" or key = "OK" or key = "down"
            ' Let MarkupGrid handle these natively.
            ' Return false so the event reaches the grid.
            return false
        end if
        ' Consume any other key to prevent it leaking to keyboard logic
        return true
    end if

    return false
end function
