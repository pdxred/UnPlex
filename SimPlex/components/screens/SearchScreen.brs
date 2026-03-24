' ===== SearchScreen — Custom keyboard with sectioned layout =====
'
' Layout (FHD 1920×1080):
'   y=25:   "Search" title + live query text
'   y=80:   Keyboard (2 rows):
'             Letters A-M / N-Z   (13 cols × 2 rows)   x=80..748
'             Numbers 1-5 / 6-0   (5 cols × 2 rows)    x=776..1016
'             Space/Delete/Clear   (3 tall buttons)     x=1046..1510
'   y=204:  Filter row (horizontal ButtonGroup): All | TV Shows | Movies | Other
'   y=265:  Divider
'   y=280:  PosterGrid results (full width 1760px, ~800px to bottom)
'
' Focus areas: "keyboard" | "filters" | "grid"
'   Left/Right within keyboard navigates across all sections seamlessly
'   Down from keyboard → filters
'   Down from filters → grid (if results exist)
'   Up from grid → filters
'   Up from filters → keyboard
'   Back: grid→keyboard, filters→keyboard, keyboard→exit

sub init()
    ' ── Layout dimensions ──
    ' All keyboard keys are positioned relative to keyboardGroup at [80, 80].
    ' Letters section: 13 cols × 2 rows, each cell 48×48 + 4px spacing
    ' Numbers section: 5 cols × 2 rows, starts after letters + 24px gap
    ' Action section: 3 tall buttons (full 2-row height = 100px)
    m.KEY_W  = 48
    m.KEY_H  = 48
    m.KEY_SP = 4
    m.LETTER_COLS = 13
    m.NUM_COLS = 5
    m.SECTION_GAP = 24
    m.ACTION_GAP = 30
    m.ACTION_W = 135
    m.ACTION_H = 100
    m.ACTION_SP = 10
    m.queryLabel = m.top.findNode("queryLabel")
    m.filterButtons = m.top.findNode("filterButtons")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.emptyState = m.top.findNode("emptyState")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")
    m.keyboardGroup = m.top.findNode("keyboardGroup")

    m.filterIndex = 0   ' 0=All, 1=TV Shows, 2=Movies, 3=Other
    m.searchQuery = ""
    m.focusArea = "keyboard"  ' "keyboard" | "filters" | "grid"
    m.retryCount = 0
    m.retryContext = invalid
    m.lastSearchResponse = invalid

    ' Keyboard state: row (0-1), col (0 to totalCols-1 across all sections)
    m.kbRow = 0
    m.kbCol = 0

    ' Build the keyboard UI
    buildKeyboard()

    ' Debounce timer for search
    m.debounceTimer = CreateObject("roSGNode", "Timer")
    m.debounceTimer.duration = 0.5
    m.debounceTimer.repeat = false
    m.debounceTimer.observeField("fire", "onDebounceTimer")

    ' Search task
    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")

    ' Observers
    m.filterButtons.observeField("buttonSelected", "onFilterSelected")
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
    ' Letters: A-M (row 0), N-Z (row 1) — 13 columns each
    m.letterKeys = []  ' 2D array: m.letterKeys[row][col] = { label, bg, char }
    letters = [["A","B","C","D","E","F","G","H","I","J","K","L","M"], ["N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]]

    for row = 0 to 1
        rowArr = []
        for col = 0 to m.LETTER_COLS - 1
            if col < letters[row].count()
                ch = letters[row][col]
            else
                ch = ""
            end if
            x = col * (m.KEY_W + m.KEY_SP)
            y = row * (m.KEY_H + m.KEY_SP)
            info = createKeyCell(x, y, m.KEY_W, m.KEY_H, ch)
            rowArr.push(info)
        end for
        m.letterKeys.push(rowArr)
    end for

    ' Numbers: 1-5 (row 0), 6-0 (row 1) — 5 columns each
    m.numberKeys = []
    nums = [["1","2","3","4","5"], ["6","7","8","9","0"]]
    numStartX = m.LETTER_COLS * (m.KEY_W + m.KEY_SP) + m.SECTION_GAP

    for row = 0 to 1
        rowArr = []
        for col = 0 to m.NUM_COLS - 1
            ch = nums[row][col]
            x = numStartX + col * (m.KEY_W + m.KEY_SP)
            y = row * (m.KEY_H + m.KEY_SP)
            info = createKeyCell(x, y, m.KEY_W, m.KEY_H, ch)
            rowArr.push(info)
        end for
        m.numberKeys.push(rowArr)
    end for

    ' Action keys: Space, Delete, Clear — tall buttons spanning both rows
    m.actionKeys = []  ' flat array of { label, bg, char }
    actionStartX = numStartX + m.NUM_COLS * (m.KEY_W + m.KEY_SP) + m.ACTION_GAP
    actionLabels = ["Space", "Delete", "Clear"]
    actionChars  = ["SPC", "DEL", "CLR"]

    for i = 0 to 2
        x = actionStartX + i * (m.ACTION_W + m.ACTION_SP)
        info = createKeyCell(x, 0, m.ACTION_W, m.ACTION_H, actionLabels[i])
        info.char = actionChars[i]
        m.actionKeys.push(info)
    end for

    ' Total columns for unified navigation:
    '   cols 0..12  = letters (13)
    '   cols 13..17 = numbers (5)
    '   cols 18..20 = actions (3)
    m.totalCols = m.LETTER_COLS + m.NUM_COLS + 3
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

' ========== Keyboard Focus Visual ==========

sub updateKeyboardFocus()
    ' Clear all key highlights
    for row = 0 to 1
        for col = 0 to m.LETTER_COLS - 1
            m.letterKeys[row][col].bg.color = "0xFFFFFF10"
            m.letterKeys[row][col].label.color = "0xCCCCCCFF"
        end for
    end for
    for row = 0 to 1
        for col = 0 to m.NUM_COLS - 1
            m.numberKeys[row][col].bg.color = "0xFFFFFF10"
            m.numberKeys[row][col].label.color = "0xCCCCCCFF"
        end for
    end for
    for i = 0 to 2
        m.actionKeys[i].bg.color = "0xFFFFFF10"
        m.actionKeys[i].label.color = "0xCCCCCCFF"
    end for

    ' Highlight the focused key
    info = getKeyAt(m.kbRow, m.kbCol)
    if info <> invalid
        info.bg.color = "0xF3B125FF"
        info.label.color = "0x000000FF"
    end if
end sub

' Map unified (row, col) to a key info object
function getKeyAt(row as Integer, col as Integer) as Object
    if col < m.LETTER_COLS
        ' Letter section
        if row >= 0 and row <= 1 and col < m.letterKeys[row].count()
            return m.letterKeys[row][col]
        end if
    else if col < m.LETTER_COLS + m.NUM_COLS
        ' Number section
        numCol = col - m.LETTER_COLS
        if row >= 0 and row <= 1 and numCol < m.numberKeys[row].count()
            return m.numberKeys[row][numCol]
        end if
    else
        ' Action section (actions span both rows, so row is ignored for lookup)
        actionIdx = col - m.LETTER_COLS - m.NUM_COLS
        if actionIdx >= 0 and actionIdx < 3
            return m.actionKeys[actionIdx]
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
    if m.top.hasFocus() or (m.top.isInFocusChain() and m.top.focusedChild = invalid)
        if m.focusArea = "keyboard"
            ' Keep focus on the screen Group — keyboard is manually drawn
            m.top.setFocus(true)
        else
            setFocusToArea(m.focusArea)
        end if
    end if
end sub

sub setFocusToArea(area as String)
    m.focusArea = area
    if area = "keyboard"
        m.top.setFocus(true)
        updateKeyboardFocus()
    else if area = "filters"
        m.filterButtons.setFocus(true)
    else if area = "grid"
        innerGrid = m.resultsGrid.findNode("grid")
        if innerGrid <> invalid
            innerGrid.setFocus(true)
        else
            m.resultsGrid.setFocus(true)
        end if
    end if
end sub

' ========== Keyboard Input ==========

sub activateKey()
    key = getFocusedKeyChar()
    if key = "" then return

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
        ' Use the hub's type as the canonical category for all items in it.
        ' The Plex /hubs/search API groups results by type at the hub level;
        ' individual Metadata items may or may not carry their own type field.
        hubType = invalid
        if hub.type <> invalid then hubType = hub.type

        if hub.Metadata <> invalid
            for each item in hub.Metadata
                ' Determine effective type: prefer item.type, fall back to hub.type
                effectiveType = invalid
                if item.type <> invalid and item.type <> ""
                    effectiveType = item.type
                else if hubType <> invalid
                    effectiveType = hubType
                end if

                if not shouldIncludeItem(effectiveType) then continue for

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

function shouldIncludeItem(itemType as Dynamic) as Boolean
    if m.filterIndex = 0 then return true
    if itemType = invalid or itemType = "" then return (m.filterIndex = 3)

    ' Normalize to lowercase for safe comparison
    t = LCase(itemType)

    if m.filterIndex = 1
        return (t = "show" or t = "episode" or t = "season")
    end if
    if m.filterIndex = 2
        return (t = "movie")
    end if
    if m.filterIndex = 3
        return (t <> "show" and t <> "episode" and t <> "season" and t <> "movie")
    end if
    return true
end function

' ========== Filter Selection ==========

sub onFilterSelected(event as Object)
    m.filterIndex = event.getData()
    if m.lastSearchResponse <> invalid
        processSearchResults()
    end if
end sub

' ========== Grid Item Selection ==========

sub onGridItemSelected(event as Object)
    index = event.getData()
    content = m.resultsGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        m.top.itemSelected = {
            action: "detail"
            ratingKey: item.ratingKey
            itemType: item.itemType
        }
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

    ' ── Keyboard focus area ──
    if m.focusArea = "keyboard"
        if key = "OK"
            activateKey()
            return true
        else if key = "left"
            if m.kbCol > 0
                m.kbCol = m.kbCol - 1
                ' If moving into action section, clamp row to 0 (actions span both rows)
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
            if m.kbRow > 0 and m.kbCol < m.LETTER_COLS + m.NUM_COLS
                ' Only letters and numbers have 2 rows; actions are single tall buttons
                m.kbRow = 0
                updateKeyboardFocus()
                return true
            end if
            ' Already at top row — don't consume, let back handle exit
            return false
        else if key = "down"
            if m.kbRow = 0 and m.kbCol < m.LETTER_COLS + m.NUM_COLS
                ' Move to row 1 within letters/numbers
                m.kbRow = 1
                updateKeyboardFocus()
                return true
            end if
            ' At bottom of keyboard (row 1, or action key) → move to filters
            m.focusArea = "filters"
            setFocusToArea("filters")
            return true
        else if key = "back"
            m.top.navigateBack = true
            return true
        end if
        return false
    end if

    ' ── Filters focus area ──
    if m.focusArea = "filters"
        if key = "up"
            setFocusToArea("keyboard")
            return true
        else if key = "down"
            if m.resultsGrid.content <> invalid and m.resultsGrid.content.getChildCount() > 0
                setFocusToArea("grid")
                return true
            end if
            return true  ' consume even if no results to prevent focus escape
        else if key = "back"
            setFocusToArea("keyboard")
            return true
        end if
        ' Left/right within filters handled by ButtonGroup natively
        return false
    end if

    ' ── Grid focus area ──
    if m.focusArea = "grid"
        if key = "up"
            ' Check if the grid's inner focus is on the first row
            ' If so, move up to filters. Otherwise let grid handle it.
            innerGrid = m.resultsGrid.findNode("grid")
            if innerGrid <> invalid
                focusedIdx = innerGrid.itemFocused
                numCols = innerGrid.numColumns
                if focusedIdx < numCols
                    ' First row — escape to filters
                    setFocusToArea("filters")
                    return true
                end if
            end if
            ' Not first row — let grid scroll
            return false
        else if key = "back"
            setFocusToArea("keyboard")
            return true
        end if
        return false
    end if

    return false
end function
