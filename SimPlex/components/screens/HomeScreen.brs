sub init()
    m.sidebar = m.top.findNode("sidebar")
    m.posterGrid = m.top.findNode("posterGrid")
    m.filterBar = m.top.findNode("filterBar")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.currentSectionId = ""
    m.currentOffset = 0
    m.totalItems = 0
    m.isLoading = false
    m.focusOnSidebar = true

    ' Observe sidebar selection
    m.sidebar.observeField("selectedLibrary", "onLibrarySelected")
    m.sidebar.observeField("specialAction", "onSpecialAction")

    ' Observe grid events
    m.posterGrid.observeField("itemSelected", "onGridItemSelected")
    m.posterGrid.observeField("loadMore", "onLoadMore")

    ' Observe filter changes
    m.filterBar.observeField("filterChanged", "onFilterChanged")

    ' Delegate focus to appropriate child when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    ' When HomeScreen is in focus chain but no child has focus, delegate
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        if m.focusOnSidebar
            m.sidebar.setFocus(true)
        else
            m.posterGrid.setFocus(true)
        end if
    end if
end sub

sub onLibrarySelected(event as Object)
    data = event.getData()
    if data <> invalid and data.sectionId <> m.currentSectionId
        m.currentSectionId = data.sectionId
        m.currentSectionType = data.sectionType
        m.currentOffset = 0
        m.filterBar.sectionId = m.currentSectionId
        loadLibrary()
    end if
end sub

sub onSpecialAction(event as Object)
    action = event.getData()
    if action = "onDeck"
        loadOnDeck()
    else if action = "recentlyAdded"
        loadRecentlyAdded()
    else if action = "search"
        m.top.itemSelected = { action: "search" }
    else if action = "settings"
        m.top.itemSelected = { action: "settings" }
    end if
end sub

sub loadLibrary()
    if m.isLoading then return
    m.isLoading = true
    m.loadingSpinner.visible = true

    c = m.global.constants
    endpoint = "/library/sections/" + m.currentSectionId + "/all"
    params = {
        "sort": "titleSort:asc"
        "X-Plex-Container-Start": m.currentOffset.ToStr()
        "X-Plex-Container-Size": c.PAGE_SIZE.ToStr()
    }

    ' Apply any active filters
    if m.filterBar.activeFilters <> invalid
        for each key in m.filterBar.activeFilters
            params[key] = m.filterBar.activeFilters[key]
        end for
    end if

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = params
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.currentApiTask = task
end sub

sub loadOnDeck()
    if m.isLoading then return
    m.isLoading = true
    m.loadingSpinner.visible = true
    m.currentSectionId = "onDeck"
    m.currentOffset = 0

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/onDeck"
    task.params = {}
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.currentApiTask = task
end sub

sub loadRecentlyAdded()
    if m.isLoading then return
    m.isLoading = true
    m.loadingSpinner.visible = true
    m.currentSectionId = "recentlyAdded"
    m.currentOffset = 0

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/recentlyAdded"
    task.params = {}
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.currentApiTask = task
end sub

sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.visible = false
        m.isLoading = false
        processApiResponse()
    else if state = "error"
        m.loadingSpinner.visible = false
        m.isLoading = false
        showError(m.currentApiTask.error)
    end if
end sub

sub processApiResponse()
    response = m.currentApiTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    container = response.MediaContainer
    m.totalItems = container.totalSize

    ' Build content nodes for the grid
    c = m.global.constants
    metadata = container.Metadata
    if metadata = invalid then metadata = []

    if m.currentOffset = 0
        ' New data set - create fresh content
        content = CreateObject("roSGNode", "ContentNode")
    else
        ' Appending - use existing content
        content = m.posterGrid.content
        if content = invalid
            content = CreateObject("roSGNode", "ContentNode")
        end if
    end if

    for each item in metadata
        node = content.createChild("ContentNode")

        ' Ensure ratingKey is stored as string
        ratingKeyStr = ""
        if item.ratingKey <> invalid
            if type(item.ratingKey) = "roString" or type(item.ratingKey) = "String"
                ratingKeyStr = item.ratingKey
            else
                ratingKeyStr = item.ratingKey.ToStr()
            end if
        end if

        node.addFields({
            title: item.title
            ratingKey: ratingKeyStr
            itemType: item.type
            thumb: item.thumb
            viewOffset: 0
        })

        if item.viewOffset <> invalid
            node.viewOffset = item.viewOffset
        end if

        ' Build poster URL
        if item.thumb <> invalid and item.thumb <> ""
            node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
        end if
    end for

    m.posterGrid.content = content
    m.currentOffset = m.currentOffset + metadata.count()
end sub

sub onGridItemSelected(event as Object)
    index = event.getData()
    content = m.posterGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        m.top.itemSelected = {
            action: "detail"
            ratingKey: item.ratingKey
            itemType: item.itemType
        }
    end if
end sub

sub onLoadMore(event as Object)
    if m.isLoading then return
    if m.currentOffset >= m.totalItems then return
    if m.currentSectionId = "onDeck" or m.currentSectionId = "recentlyAdded" then return

    loadLibrary()
end sub

sub onFilterChanged(event as Object)
    ' Reset and reload with new filters
    m.currentOffset = 0
    loadLibrary()
end sub

sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog
end sub

sub cleanup()
    ' Stop running task
    if m.currentApiTask <> invalid
        m.currentApiTask.control = "stop"
        m.currentApiTask.unobserveField("status")
    end if

    ' Unobserve child widgets
    m.sidebar.unobserveField("selectedLibrary")
    m.sidebar.unobserveField("specialAction")
    m.posterGrid.unobserveField("itemSelected")
    m.posterGrid.unobserveField("loadMore")
    m.filterBar.unobserveField("filterChanged")
end sub

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
