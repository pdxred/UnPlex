sub init()
    m.sidebar = m.top.findNode("sidebar")
    m.posterGrid = m.top.findNode("posterGrid")
    m.filterBar = m.top.findNode("filterBar")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.hubRowList = m.top.findNode("hubRowList")

    m.currentSectionId = ""
    m.currentOffset = 0
    m.totalItems = 0
    m.isLoading = false
    m.isLoadingHubs = false
    m.hubRowCount = 0
    m.hubRowMap = {}
    m.focusArea = "sidebar"
    m.viewMode = "hubGrid"
    m.savedHubFocus = invalid

    ' Observe sidebar selection
    m.sidebar.observeField("selectedLibrary", "onLibrarySelected")
    m.sidebar.observeField("specialAction", "onSpecialAction")

    ' Observe grid events
    m.posterGrid.observeField("itemSelected", "onGridItemSelected")
    m.posterGrid.observeField("loadMore", "onLoadMore")

    ' Observe filter changes
    m.filterBar.observeField("filterChanged", "onFilterChanged")

    ' Observe hub row item selection
    m.hubRowList.observeField("itemSelected", "onHubItemSelected")

    ' Delegate focus to appropriate child when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")

    ' Auto-refresh timer for hub rows (2 minutes)
    m.hubRefreshTimer = CreateObject("roSGNode", "Timer")
    m.hubRefreshTimer.duration = 120
    m.hubRefreshTimer.repeat = true
    m.hubRefreshTimer.observeField("fire", "onHubRefreshTimer")
    m.hubRefreshTimer.control = "start"

    ' Load hub rows on init
    loadHubs()
end sub

sub onFocusChange(event as Object)
    ' When HomeScreen regains focus (e.g., returning from playback/detail)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        ' Refresh hub data on return
        loadHubs()

        ' Delegate focus to the appropriate area
        if m.focusArea = "sidebar"
            m.sidebar.setFocus(true)
        else if m.focusArea = "hubs" and m.hubRowCount > 0
            m.hubRowList.setFocus(true)
        else
            m.posterGrid.setFocus(true)
        end if
    end if
end sub

' ========== Hub Row Data Fetching ==========

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

    if m.hubsTask.response = invalid or m.hubsTask.response.MediaContainer = invalid then return

    hubs = m.hubsTask.response.MediaContainer.Hub
    if hubs = invalid then return

    ' Filter for the three hub types we display
    m.continueWatching = invalid
    m.onDeck = invalid
    m.recentlyAdded = invalid

    for each hub in hubs
        id = LCase(hub.hubIdentifier)
        if Instr(1, id, "continue") > 0
            m.continueWatching = hub
        else if Instr(1, id, "ondeck") > 0
            m.onDeck = hub
        else if Instr(1, id, "recent") > 0
            if m.recentlyAdded = invalid
                m.recentlyAdded = hub
            end if
        end if
    end for

    buildHubRowContent()
end sub

sub buildHubRowContent()
    rootContent = CreateObject("roSGNode", "ContentNode")
    m.hubRowMap = {}
    rowIndex = 0
    c = m.global.constants

    ' Add rows in locked order: Continue Watching, On Deck, Recently Added
    ' Only add rows that have data (empty rows hidden per user decision)
    if m.continueWatching <> invalid
        metadata = m.continueWatching.Metadata
        if metadata <> invalid and metadata.count() > 0
            addHubRow(rootContent, "Continue Watching", metadata, c)
            m.hubRowMap[rowIndex.ToStr()] = "continueWatching"
            rowIndex = rowIndex + 1
        end if
    end if

    if m.onDeck <> invalid
        metadata = m.onDeck.Metadata
        if metadata <> invalid and metadata.count() > 0
            addHubRow(rootContent, "On Deck", metadata, c)
            m.hubRowMap[rowIndex.ToStr()] = "onDeck"
            rowIndex = rowIndex + 1
        end if
    end if

    if m.recentlyAdded <> invalid
        metadata = m.recentlyAdded.Metadata
        if metadata <> invalid and metadata.count() > 0
            addHubRow(rootContent, "Recently Added", metadata, c)
            m.hubRowMap[rowIndex.ToStr()] = "recentlyAdded"
            rowIndex = rowIndex + 1
        end if
    end if

    ' CRITICAL: set numRows BEFORE setting content
    m.hubRowList.numRows = rowIndex
    m.hubRowList.content = rootContent
    m.hubRowList.visible = (rowIndex > 0 and m.viewMode = "hubGrid")
    m.hubRowCount = rowIndex

    ' Restore scroll position if saved (from refresh, not initial load)
    if m.savedHubFocus <> invalid and rowIndex = m.savedHubFocus.count()
        m.hubRowList.jumpToRowItem = m.savedHubFocus
        m.savedHubFocus = invalid
    end if

    ' Reposition grid below hub rows
    if m.viewMode = "hubGrid"
        repositionContentBelowHubs(rowIndex)
    end if
end sub

sub addHubRow(rootContent as Object, title as String, metadata as Object, c as Object)
    rowNode = rootContent.createChild("ContentNode")
    rowNode.title = title

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
        if item.duration <> invalid
            itemNode.duration = item.duration
        else if item.Media <> invalid and item.Media.count() > 0
            if item.Media[0].duration <> invalid
                itemNode.duration = item.Media[0].duration
            end if
        end if

        if item.thumb <> invalid and item.thumb <> ""
            itemNode.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
        end if
    end for
end sub

sub repositionContentBelowHubs(hubRowCount as Integer)
    if hubRowCount = 0
        m.filterBar.translation = [20, 20]
        m.posterGrid.translation = [20, 100]
    else
        ' Each hub row: ~430px item height + ~10px spacing + ~30px label area
        hubHeight = hubRowCount * 470
        m.filterBar.translation = [20, hubHeight + 20]
        m.posterGrid.translation = [20, hubHeight + 100]
    end if
end sub

' ========== Hub Row Item Selection ==========

sub onHubItemSelected(event as Object)
    selectedInfo = event.getData()
    rowIndex = selectedInfo[0]
    itemIndex = selectedInfo[1]

    ' Determine which hub type this row represents
    hubType = m.hubRowMap[rowIndex.ToStr()]

    ' Get the content node for this item
    rowContent = m.hubRowList.content.getChild(rowIndex)
    itemContent = rowContent.getChild(itemIndex)

    if hubType = "continueWatching"
        ' Per locked decision: resume playback immediately
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

' ========== Auto-Refresh ==========

sub onHubRefreshTimer(event as Object)
    if not m.isLoadingHubs
        ' Save scroll position before refreshing
        if m.hubRowList.rowItemFocused <> invalid
            m.savedHubFocus = m.hubRowList.rowItemFocused
        end if
        loadHubs()
    end if
end sub

' ========== View Mode ==========

sub onViewModeChanged()
    if m.viewMode = "libraryOnly"
        m.hubRowList.visible = false
        m.filterBar.translation = [20, 20]
        m.posterGrid.translation = [20, 100]
    else if m.viewMode = "hubGrid"
        if m.hubRowCount > 0
            m.hubRowList.visible = true
        end if
        repositionContentBelowHubs(m.hubRowCount)
    end if
end sub

' ========== Library & Sidebar ==========

sub onLibrarySelected(event as Object)
    data = event.getData()
    if data <> invalid and data.sectionId <> m.currentSectionId
        m.currentSectionId = data.sectionId
        m.currentSectionType = data.sectionType
        m.currentOffset = 0
        m.filterBar.sectionId = m.currentSectionId

        ' Switch to library-only view when a specific library is selected
        m.viewMode = "libraryOnly"
        onViewModeChanged()

        loadLibrary()
    end if
end sub

sub onSpecialAction(event as Object)
    action = event.getData()
    if action = "viewHome"
        m.viewMode = "hubGrid"
        onViewModeChanged()
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
    ' Stop hub refresh timer
    m.hubRefreshTimer.control = "stop"
    m.hubRefreshTimer.unobserveField("fire")

    ' Stop hubs task
    if m.hubsTask <> invalid
        m.hubsTask.control = "stop"
        m.hubsTask.unobserveField("status")
    end if

    ' Stop running API task
    if m.currentApiTask <> invalid
        m.currentApiTask.control = "stop"
        m.currentApiTask.unobserveField("status")
    end if

    ' Unobserve hub row list
    m.hubRowList.unobserveField("itemSelected")

    ' Unobserve child widgets
    m.sidebar.unobserveField("selectedLibrary")
    m.sidebar.unobserveField("specialAction")
    m.posterGrid.unobserveField("itemSelected")
    m.posterGrid.unobserveField("loadMore")
    m.filterBar.unobserveField("filterChanged")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down"
        if m.focusArea = "hubs"
            ' Check if on last hub row
            focusedRow = m.hubRowList.rowItemFocused
            if focusedRow <> invalid and focusedRow[0] >= m.hubRowCount - 1
                m.focusArea = "grid"
                m.posterGrid.setFocus(true)
                return true
            end if
        end if
    else if key = "up"
        if m.focusArea = "grid"
            ' Check if grid is at top row
            gridNode = m.posterGrid.findNode("grid")
            if gridNode <> invalid
                c = m.global.constants
                if gridNode.itemFocused < c.GRID_COLUMNS and m.hubRowCount > 0 and m.viewMode = "hubGrid"
                    m.focusArea = "hubs"
                    m.hubRowList.setFocus(true)
                    return true
                end if
            end if
        end if
    else if key = "left"
        if m.focusArea = "hubs"
            ' Check if on first item in the row
            focusedItem = m.hubRowList.rowItemFocused
            if focusedItem <> invalid and focusedItem[1] = 0
                m.focusArea = "sidebar"
                m.sidebar.setFocus(true)
                return true
            end if
        else if m.focusArea = "grid"
            m.focusArea = "sidebar"
            m.sidebar.setFocus(true)
            return true
        end if
    else if key = "right"
        if m.focusArea = "sidebar"
            if m.hubRowCount > 0 and m.viewMode = "hubGrid"
                m.focusArea = "hubs"
                m.hubRowList.setFocus(true)
                return true
            else
                m.focusArea = "grid"
                m.posterGrid.setFocus(true)
                return true
            end if
        end if
    else if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
