' ===== SearchScreen — 3-row keyboard, custom filters, horizontal results =====
'
' Layout (FHD 1920×1080):
'   y=25:   "Search" title + live query text
'   y=80:   Keyboard (3 rows × 12 cols):
'             Row 0: A B C D E F G H I J K L
'             Row 1: M N O P Q R S T U V W X
'             Row 2: Y Z 0 1 2 3 4 5 6 7 8 9
'             Action keys: Space / Delete / Clear (right of grid, full 3-row height)
'   y=248:  Filter row: All | Movies | TV Shows | Other (custom drawn, matches keyboard)
'   y=306:  Divider
'   y=326:  Results — single horizontal row of posters (scrolls left/right)
'
' Focus areas: "keyboard" | "filters" | "grid"
'   Left/Right within keyboard navigates across all sections seamlessly
'   Down from keyboard → filters
'   Down from filters → grid (if results exist)
'   Up from grid → filters
'   Up from filters → keyboard
'   Back: grid→filters, filters→keyboard, keyboard→exit

sub init()
    ' ── Layout dimensions ──
    m.KEY_W  = 48
    m.KEY_H  = 48
    m.KEY_SP = 4
    m.GRID_COLS = 12
    m.KB_ROWS = 3
    m.ACTION_GAP = 30
    m.ACTION_W = 135
    m.ACTION_H = (m.KEY_H * m.KB_ROWS) + (m.KEY_SP * (m.KB_ROWS - 1))  ' spans all 3 rows
    m.ACTION_SP = 10

    m.queryLabel = m.top.findNode("queryLabel")
    m.filterGroup = m.top.findNode("filterGroup")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.emptyState = m.top.findNode("emptyState")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")
    m.keyboardGroup = m.top.findNode("keyboardGroup")

    m.filterIndex = 0   ' 0=All, 1=Movies, 2=TV Shows, 3=Other
    m.filterFocusIndex = 0  ' Tracks which filter button has visual focus
    m.searchQuery = ""
    m.focusArea = "keyboard"  ' "keyboard" | "filters" | "grid"
    m.retryCount = 0
    m.retryContext = invalid
    m.lastSearchResponse = invalid

    ' Keyboard state: row (0-2), col (0 to totalCols-1 across all sections)
    m.kbRow = 0
    m.kbCol = 0

    ' Build the keyboard UI
    buildKeyboard()

    ' Build the custom filter row (matching keyboard style)
    buildFilterButtons()

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
    ' 3 rows of 12 characters:
    '   Row 0: A-L
    '   Row 1: M-X
    '   Row 2: Y-Z + 0-9
    m.gridKeys = []  ' 2D array: m.gridKeys[row][col] = { label, bg, char }
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

    ' Action keys: Space, Delete, Clear — tall buttons spanning all 3 rows
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

    ' Total columns for unified navigation:
    '   cols 0..11  = grid keys (12)
    '   cols 12..14 = actions (3)
    m.totalCols = m.GRID_COLS + 3
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

' ========== Custom Filter Buttons ==========

sub buildFilterButtons()
    ' Custom-drawn filter buttons that visually match the keyboard cells.
    ' Each filter button: rounded-rect background + centered label, same
    ' font/colors as keyboard keys. Highlighted filter = accent bg + dark text.
    m.filterLabels = ["All", "Movies", "TV Shows", "Other"]
    m.filterKeys = []  ' array of { bg, label }
    m.FILTER_H = 42
    m.FILTER_SP = 8
    filterX = 0

    for i = 0 to m.filterLabels.count() - 1
        text = m.filterLabels[i]
        ' Variable width: measure roughly by character count + padding
        charW = text.Len() * 12 + 28  ' ~12px per char + 28px padding
        if charW < 60 then charW = 60

        bg = CreateObject("roSGNode", "Rectangle")
        bg.width = charW
        bg.height = m.FILTER_H
        bg.color = "0xFFFFFF10"
        bg.translation = [filterX, 0]
        m.filterGroup.appendChild(bg)

        label = CreateObject("roSGNode", "Label")
        label.width = charW
        label.height = m.FILTER_H
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.font = "font:SmallBoldSystemFont"
        label.color = "0xCCCCCCFF"
        label.text = text
        label.translation = [filterX, 0]
        m.filterGroup.appendChild(label)

        m.filterKeys.push({ bg: bg, label: label, width: charW })
        filterX = filterX + charW + m.FILTER_SP
    end for

    ' Set initial active filter visual (index 0 = "All")
    updateFilterVisuals()
end sub

sub updateFilterVisuals()
    ' Update filter button visuals: active filter gets accent underline bar,
    ' focused filter (when focusArea=filters) gets accent bg.
    for i = 0 to m.filterKeys.count() - 1
        fk = m.filterKeys[i]
        if m.focusArea = "filters" and i = m.filterIndex
            ' Focused + active
            fk.bg.color = "0xF3B125FF"
            fk.label.color = "0x000000FF"
        else if i = m.filterIndex
            ' Active but not focused
            fk.bg.color = "0xF3B125AA"
            fk.label.color = "0x000000FF"
        else if m.focusArea = "filters" and i = m.filterFocusIndex
            ' Focused but not active
            fk.bg.color = "0xFFFFFF30"
            fk.label.color = "0xFFFFFFFF"
        else
            ' Default
            fk.bg.color = "0xFFFFFF10"
            fk.label.color = "0xCCCCCCFF"
        end if
    end for
end sub

' ========== Keyboard Focus Visual ==========

sub updateKeyboardFocus()
    ' Clear all key highlights
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

    ' Highlight the focused key
    info = getKeyAt(m.kbRow, m.kbCol)
    if info <> invalid
        info.bg.color = "0xF3B125FF"
        info.label.color = "0x000000FF"
    end if
end sub

' Map unified (row, col) to a key info object
function getKeyAt(row as Integer, col as Integer) as Object
    if col < m.GRID_COLS
        ' Grid key section
        if row >= 0 and row < m.KB_ROWS and col < m.gridKeys[row].count()
            return m.gridKeys[row][col]
        end if
    else
        ' Action section (actions span all rows, so row is ignored for lookup)
        actionIdx = col - m.GRID_COLS
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
        else if m.focusArea = "filters"
            ' Filters are also manually drawn — keep focus on screen
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
        updateFilterVisuals()
    else if area = "filters"
        m.top.setFocus(true)
        clearKeyboardHighlight()
        updateFilterVisuals()
    else if area = "grid"
        clearKeyboardHighlight()
        updateFilterVisuals()
        innerGrid = m.resultsGrid.findNode("grid")
        if innerGrid <> invalid
            innerGrid.setFocus(true)
        else
            m.resultsGrid.setFocus(true)
        end if
    end if
end sub

sub clearKeyboardHighlight()
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

                ' Capture subtype for "Other Videos" detection.
                ' Plex "Other Videos" libraries store items as type="movie"
                ' with subtype="clip". We pass this through so the filter
                ' can distinguish real movies from home videos / clips.
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
    '              (excludes "Other Videos" which are type=movie, subtype=clip)
    '   2 = TV Shows — type is show, episode, or season
    '   3 = Other — everything else: clips (Other Videos/home videos), music,
    '              photos, and items with subtype="clip" (even if type=movie)
    if m.filterIndex = 0 then return true
    if itemType = invalid or itemType = "" then return (m.filterIndex = 3)

    t = LCase(itemType)
    st = LCase(itemSubtype)

    if m.filterIndex = 1
        ' Movies — real movies only (not clips from "Other Videos" libraries)
        return (t = "movie" and st <> "clip")
    end if
    if m.filterIndex = 2
        ' TV Shows
        return (t = "show" or t = "episode" or t = "season")
    end if
    if m.filterIndex = 3
        ' Other — clips, Other Videos (type=movie + subtype=clip), and anything
        ' that isn't a normal movie or TV content
        isClip = (st = "clip" or t = "clip")
        isMovie = (t = "movie" and st <> "clip")
        isTv = (t = "show" or t = "episode" or t = "season")
        return (not isMovie and not isTv) or isClip
    end if
    return true
end function

' ========== Filter Selection ==========

sub activateFilter()
    if m.filterIndex <> m.filterFocusIndex
        m.filterIndex = m.filterFocusIndex
        updateFilterVisuals()
        if m.lastSearchResponse <> invalid
            processSearchResults()
        end if
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
                ' Only grid keys have multiple rows; actions are single tall buttons
                m.kbRow = m.kbRow - 1
                updateKeyboardFocus()
                return true
            end if
            ' Already at top row — don't consume, let back handle exit
            return false
        else if key = "down"
            if m.kbCol < m.GRID_COLS and m.kbRow < m.KB_ROWS - 1
                ' Move to next row within grid keys
                m.kbRow = m.kbRow + 1
                updateKeyboardFocus()
                return true
            end if
            ' At bottom of keyboard (row 2, or action key) → move to filters
            m.filterFocusIndex = m.filterIndex
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
        if key = "OK"
            activateFilter()
            return true
        else if key = "left"
            if m.filterFocusIndex > 0
                m.filterFocusIndex = m.filterFocusIndex - 1
                updateFilterVisuals()
            end if
            return true
        else if key = "right"
            if m.filterFocusIndex < m.filterKeys.count() - 1
                m.filterFocusIndex = m.filterFocusIndex + 1
                updateFilterVisuals()
            end if
            return true
        else if key = "up"
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
        return false
    end if

    ' ── Grid focus area ──
    if m.focusArea = "grid"
        if key = "up"
            ' Single-row horizontal grid — up always escapes to filters
            m.filterFocusIndex = m.filterIndex
            setFocusToArea("filters")
            return true
        else if key = "back"
            setFocusToArea("keyboard")
            return true
        end if
        ' Left/right within the horizontal grid handled by MarkupGrid natively
        return false
    end if

    return false
end function
