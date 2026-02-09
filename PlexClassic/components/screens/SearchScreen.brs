sub init()
    m.keyboard = m.top.findNode("keyboard")
    m.searchQueryLabel = m.top.findNode("searchQueryLabel")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.noResultsLabel = m.top.findNode("noResultsLabel")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.searchQuery = ""
    m.debounceTimer = invalid
    m.focusOnKeyboard = true

    ' Set up search task
    m.searchTask = CreateObject("roSGNode", "PlexSearchTask")
    m.searchTask.observeField("state", "onSearchTaskStateChange")

    ' Set up debounce timer
    m.debounceTimer = CreateObject("roSGNode", "Timer")
    m.debounceTimer.duration = 0.5  ' 500ms debounce
    m.debounceTimer.repeat = false
    m.debounceTimer.observeField("fire", "onDebounceTimer")

    ' Observe keyboard
    m.keyboard.observeField("text", "onTextChange")

    ' Observe grid selection
    m.resultsGrid.observeField("itemSelected", "onGridItemSelected")

    m.keyboard.setFocus(true)
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
        m.noResultsLabel.visible = false
    end if
end sub

sub onDebounceTimer(event as Object)
    if m.searchQuery.Len() >= 2
        performSearch()
    end if
end sub

sub performSearch()
    m.loadingSpinner.visible = true
    m.noResultsLabel.visible = false
    m.searchTask.query = m.searchQuery
    m.searchTask.control = "run"
end sub

sub onSearchTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.visible = false
        processSearchResults()
    else if state = "error"
        m.loadingSpinner.visible = false
        showError(m.searchTask.error)
    end if
end sub

sub processSearchResults()
    response = m.searchTask.response
    if response = invalid or response.MediaContainer = invalid
        m.noResultsLabel.visible = true
        return
    end if

    ' Search results come in hubs
    hubs = response.MediaContainer.Hub
    if hubs = invalid or hubs.count() = 0
        m.noResultsLabel.visible = true
        return
    end if

    c = GetConstants()
    content = CreateObject("roSGNode", "ContentNode")
    hasResults = false

    for each hub in hubs
        if hub.Metadata <> invalid
            for each item in hub.Metadata
                node = content.createChild("ContentNode")
                node.addFields({
                    title: item.title
                    ratingKey: item.ratingKey
                    itemType: item.type
                    thumb: ""
                })

                if item.thumb <> invalid and item.thumb <> ""
                    node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
                else
                    node.HDPosterUrl = "pkg:/images/placeholder_poster.png"
                end if

                hasResults = true
            end for
        end if
    end for

    if hasResults
        m.resultsGrid.content = content
        m.noResultsLabel.visible = false
    else
        m.resultsGrid.content = invalid
        m.noResultsLabel.visible = true
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

sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog
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
