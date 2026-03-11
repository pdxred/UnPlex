sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.searchQueryLabel = m.top.findNode("searchQueryLabel")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.emptyState = m.top.findNode("emptyState")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.searchQuery = ""
    m.debounceTimer = invalid
    m.focusOnKeyboard = true
    m.retryCount = 0
    m.retryContext = invalid

    ' Observe inline retry button
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")

    ' Observe server reconnected signal
    m.global.observeField("serverReconnected", "onServerReconnected")

    ' Set up search task
    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")

    ' Set up debounce timer
    m.debounceTimer = CreateObject("roSGNode", "Timer")
    m.debounceTimer.duration = 0.5  ' 500ms debounce
    m.debounceTimer.repeat = false
    m.debounceTimer.observeField("fire", "onDebounceTimer")

    ' Observe keyboard
    m.keyboard.observeField("text", "onTextChange")

    ' Observe grid selection
    m.resultsGrid.observeField("itemSelected", "onGridItemSelected")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    ' When SearchScreen is in focus chain but no child has focus, delegate
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        if m.focusOnKeyboard
            m.keyboard.setFocus(true)
        else
            m.resultsGrid.setFocus(true)
        end if
    end if
end sub

sub onTextChange(event as Object)
    m.searchQuery = event.getData()
    m.searchQueryLabel.text = "Search: " + m.searchQuery

    ' Reset and start debounce timer
    m.debounceTimer.control = "stop"
    if m.searchQuery.Len() >= 2
        m.debounceTimer.control = "start"
    else
        ' Clear results if query too short
        m.resultsGrid.content = invalid
        m.emptyState.visible = false
    end if
end sub

sub onDebounceTimer(event as Object)
    if m.searchQuery.Len() >= 2
        performSearch()
    end if
end sub

sub performSearch()
    m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false
    m.retryGroup.visible = false

    ' Store retry context
    m.retryContext = { query: m.searchQuery, requestType: "search" }

    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("status", "onSearchTaskStateChange")
    m.searchTask.query = m.searchQuery
    m.searchTask.control = "run"
end sub

sub onSearchTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.showSpinner = false
        m.retryCount = 0
        m.retryGroup.visible = false
        processSearchResults()
    else if state = "error"
        m.loadingSpinner.showSpinner = false
        ' Search uses PlexSearchTask which may not have responseCode, treat all as HTTP errors
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
    response = m.searchTask.response
    if response = invalid or response.MediaContainer = invalid
        m.emptyState.visible = true
        return
    end if

    ' Search results come in hubs
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
                ' Ensure ratingKey is stored as string
                ratingKeyStr = ""
                if item.ratingKey <> invalid
                    if type(item.ratingKey) = "roString" or type(item.ratingKey) = "String"
                        ratingKeyStr = item.ratingKey
                    else
                        ratingKeyStr = item.ratingKey.ToStr()
                    end if
                end if

                node = content.createChild("ContentNode")
                node.addFields({
                    title: item.title
                    ratingKey: ratingKeyStr
                    itemType: item.type
                    thumb: ""
                })

                if item.thumb <> invalid and item.thumb <> ""
                    node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
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
    m.loadingSpinner.showSpinner = true

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
    if m.focusOnKeyboard
        m.keyboard.setFocus(true)
    else
        m.resultsGrid.setFocus(true)
    end if
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
        m.top.navigateBack = true
        return true
    else if key = "right" and m.focusOnKeyboard
        m.focusOnKeyboard = false
        m.resultsGrid.setFocus(true)
        return true
    else if key = "left" and not m.focusOnKeyboard
        m.focusOnKeyboard = true
        m.keyboard.setFocus(true)
        return true
    end if

    return false
end function
