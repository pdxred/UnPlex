' ===== Custom search screen with built-in keyboard grid =====
' Three focus areas: keyGrid (custom letter grid), filterButtons, resultsGrid.
' No native Keyboard/MiniKeyboard node — everything is our own components.

sub init()
    m.keyGrid = m.top.findNode("keyGrid")
    m.queryLabel = m.top.findNode("queryLabel")
    m.filterButtons = m.top.findNode("filterButtons")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.emptyState = m.top.findNode("emptyState")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.filterIndex = 0   ' 0=All, 1=TV Shows, 2=Movies, 3=Other
    m.searchQuery = ""
    m.focusArea = "keyboard"  ' "keyboard" | "filters" | "grid"
    m.retryCount = 0
    m.retryContext = invalid
    m.lastSearchResponse = invalid

    ' Build keyboard content: a-z, 0-9, SPACE, DEL, CLEAR
    buildKeyboardContent()

    ' Debounce timer for search
    m.debounceTimer = CreateObject("roSGNode", "Timer")
    m.debounceTimer.duration = 0.5
    m.debounceTimer.repeat = false
    m.debounceTimer.observeField("fire", "onDebounceTimer")

    ' Search task
    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")

    ' Observers
    m.keyGrid.observeField("itemSelected", "onKeySelected")
    m.filterButtons.observeField("buttonSelected", "onFilterSelected")
    m.resultsGrid.observeField("itemSelected", "onGridItemSelected")
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")
    m.global.observeField("serverReconnected", "onServerReconnected")
    m.top.observeField("focusedChild", "onFocusChange")

    ' Initial focus
    m.keyGrid.setFocus(true)
end sub

sub buildKeyboardContent()
    content = CreateObject("roSGNode", "ContentNode")
    ' Row 1: A-J
    keys = "ABCDEFGHIJ"
    for i = 0 to keys.Len() - 1
        node = content.createChild("ContentNode")
        node.title = keys.Mid(i, 1)
    end for
    ' Row 2: K-T
    keys = "KLMNOPQRST"
    for i = 0 to keys.Len() - 1
        node = content.createChild("ContentNode")
        node.title = keys.Mid(i, 1)
    end for
    ' Row 3: U-Z, 0-3
    keys = "UVWXYZ0123"
    for i = 0 to keys.Len() - 1
        node = content.createChild("ContentNode")
        node.title = keys.Mid(i, 1)
    end for
    ' Row 4: 4-9, SPACE, DEL, CLR, (padding)
    for i = 4 to 9
        node = content.createChild("ContentNode")
        node.title = i.ToStr()
    end for
    node = content.createChild("ContentNode")
    node.title = "SPC"
    node = content.createChild("ContentNode")
    node.title = "DEL"
    node = content.createChild("ContentNode")
    node.title = "CLR"
    node = content.createChild("ContentNode")
    node.title = ""
    m.keyGrid.content = content
end sub

sub onFocusChange(event as Object)
    if m.top.hasFocus() or (m.top.isInFocusChain() and m.top.focusedChild = invalid)
        setFocusToArea(m.focusArea)
    end if
end sub

sub setFocusToArea(area as String)
    if area = "keyboard"
        m.keyGrid.setFocus(true)
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

sub onKeySelected(event as Object)
    index = event.getData()
    content = m.keyGrid.content
    if content = invalid then return
    item = content.getChild(index)
    if item = invalid then return
    key = item.title
    if key = "DEL"
        if m.searchQuery.Len() > 0
            m.searchQuery = m.searchQuery.Left(m.searchQuery.Len() - 1)
        end if
    else if key = "CLR"
        m.searchQuery = ""
    else if key = "SPC"
        m.searchQuery = m.searchQuery + " "
    else if key = ""
        ' Empty padding cell — do nothing
        return
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
        if hub.Metadata <> invalid
            for each item in hub.Metadata
                if not shouldIncludeItem(item.type) then continue for

                ratingKeyStr = GetRatingKeyStr(item.ratingKey)
                node = content.createChild("ContentNode")
                node.addFields({
                    title: item.title
                    ratingKey: ratingKeyStr
                    itemType: item.type
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
    if itemType = invalid then return (m.filterIndex = 3)
    if m.filterIndex = 1
        return (itemType = "show" or itemType = "episode" or itemType = "season")
    end if
    if m.filterIndex = 2
        return (itemType = "movie")
    end if
    if m.filterIndex = 3
        return (itemType <> "show" and itemType <> "episode" and itemType <> "season" and itemType <> "movie")
    end if
    return true
end function

sub onFilterSelected(event as Object)
    m.filterIndex = event.getData()
    if m.lastSearchResponse <> invalid
        processSearchResults()
    end if
end sub

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

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        if m.focusArea = "grid"
            m.focusArea = "filters"
            setFocusToArea("filters")
            return true
        else if m.focusArea = "filters"
            m.focusArea = "keyboard"
            setFocusToArea("keyboard")
            return true
        end if
        m.top.navigateBack = true
        return true
    else if key = "down"
        if m.focusArea = "keyboard"
            m.focusArea = "filters"
            setFocusToArea("filters")
            return true
        else if m.focusArea = "filters"
            if m.resultsGrid.content <> invalid and m.resultsGrid.content.getChildCount() > 0
                m.focusArea = "grid"
                setFocusToArea("grid")
                return true
            end if
        end if
        ' grid handles its own down for scrolling
    else if key = "up"
        if m.focusArea = "grid"
            m.focusArea = "filters"
            setFocusToArea("filters")
            return true
        else if m.focusArea = "filters"
            m.focusArea = "keyboard"
            setFocusToArea("keyboard")
            return true
        end if
    end if

    return false
end function
