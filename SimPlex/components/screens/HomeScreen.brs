sub init()
    m.sidebar = m.top.findNode("sidebar")
    m.posterGrid = m.top.findNode("posterGrid")
    m.filterBar = m.top.findNode("filterBar")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.hubRowList = m.top.findNode("hubRowList")
    m.emptyState = m.top.findNode("emptyState")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.gridFadeOut = m.top.findNode("gridFadeOut")
    m.gridFadeIn = m.top.findNode("gridFadeIn")
    m.clearFiltersButton = m.top.findNode("clearFiltersButton")
    m.requestSequence = 0
    m.isFilterReload = false
    m.unfilteredTotal = 0

    m.filterBottomSheet = m.top.findNode("filterBottomSheet")
    m.isSheetOpen = false

    m.retryCount = 0
    m.retryContext = invalid

    ' Observe inline retry button
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")

    ' Observe clear filters button in empty state
    m.clearFiltersButton.observeField("buttonSelected", "onClearFiltersFromEmpty")

    ' Observe bottom sheet events
    m.filterBottomSheet.observeField("filterState", "onBottomSheetFilterChanged")
    m.filterBottomSheet.observeField("sheetDismissed", "onSheetDismissed")

    ' Observe server reconnected signal
    m.global.observeField("serverReconnected", "onServerReconnected")

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
            viewCount: 0
            leafCount: 0
            viewedLeafCount: 0
        })

        if item.viewOffset <> invalid then itemNode.viewOffset = item.viewOffset
        if item.viewCount <> invalid then itemNode.viewCount = item.viewCount
        if item.leafCount <> invalid then itemNode.leafCount = item.leafCount
        if item.viewedLeafCount <> invalid then itemNode.viewedLeafCount = item.viewedLeafCount
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
    if rowContent = invalid then return
    itemContent = rowContent.getChild(itemIndex)
    if itemContent = invalid then return

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
    m.emptyState.visible = false
    m.clearFiltersButton.visible = false
    m.retryGroup.visible = false

    ' Cancel previous API task before starting new one
    if m.currentApiTask <> invalid
        m.currentApiTask.control = "stop"
        m.currentApiTask.unobserveField("status")
    end if

    c = m.global.constants
    endpoint = "/library/sections/" + m.currentSectionId + "/all"
    params = {
        "X-Plex-Container-Start": m.currentOffset.ToStr()
        "X-Plex-Container-Size": c.PAGE_SIZE.ToStr()
    }

    ' Apply active filters (includes sort from filterState)
    if m.filterBar.activeFilters <> invalid
        for each key in m.filterBar.activeFilters
            params[key] = m.filterBar.activeFilters[key]
        end for
    end if

    ' Fallback: ensure sort is always present
    if params["sort"] = invalid
        params["sort"] = "titleSort:asc"
    end if

    ' Store retry context
    m.retryContext = { endpoint: endpoint, params: params, handler: "onApiTaskStateChange", requestType: "library" }

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
        m.retryCount = 0
        m.retryGroup.visible = false
        processApiResponse()
    else if state = "error"
        m.loadingSpinner.visible = false
        m.isLoading = false
        ' Check if network-level error (responseCode < 0) for server disconnect
        if m.currentApiTask.responseCode < 0
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                m.global.serverUnreachable = true
            end if
        else
            ' HTTP error (4xx/5xx) - use per-screen error dialog
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                showErrorDialog("Error", "Couldn't load your library. Please try again.")
            end if
        end if
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
            duration: 0
            viewCount: 0
            leafCount: 0
            viewedLeafCount: 0
        })

        if item.viewOffset <> invalid
            node.viewOffset = item.viewOffset
        end if
        if item.duration <> invalid
            node.duration = item.duration
        else if item.Media <> invalid and item.Media.count() > 0
            if item.Media[0].duration <> invalid
                node.duration = item.Media[0].duration
            end if
        end if
        if item.viewCount <> invalid then node.viewCount = item.viewCount
        if item.leafCount <> invalid then node.leafCount = item.leafCount
        if item.viewedLeafCount <> invalid then node.viewedLeafCount = item.viewedLeafCount

        ' Build poster URL
        if item.thumb <> invalid and item.thumb <> ""
            node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
        end if
    end for

    m.posterGrid.content = content
    m.currentOffset = m.currentOffset + metadata.count()

    ' Update filter bar item counts
    filteredTotal = container.totalSize
    m.filterBar.totalFiltered = filteredTotal

    ' Track unfiltered total: if no filters beyond sort are active, this IS the unfiltered total
    hasActiveFilters = false
    if m.filterBar.activeFilters <> invalid
        for each key in m.filterBar.activeFilters
            if key <> "sort"
                hasActiveFilters = true
                exit for
            end if
        end for
    end if

    if not hasActiveFilters
        m.unfilteredTotal = filteredTotal
    end if
    m.filterBar.totalItems = m.unfilteredTotal

    ' Fade in grid if it was faded out
    if m.posterGrid.opacity < 1.0
        m.gridFadeIn.control = "start"
    end if

    ' Reset focus to top-left after filter change
    if m.isFilterReload and m.currentOffset > 0
        gridNode = m.posterGrid.findNode("grid")
        if gridNode <> invalid
            gridNode.jumpToItem = 0
        end if
        m.isFilterReload = false
    end if

    ' Show empty state if library has zero items on initial load
    if m.currentOffset = 0 or (m.currentOffset = metadata.count() and metadata.count() = 0)
        m.emptyState.visible = true
        m.posterGrid.visible = false

        ' Show filter-specific empty message if filters are active
        emptyTitle = m.top.findNode("emptyTitle")
        emptyMessage = m.top.findNode("emptyMessage")
        if hasActiveFilters
            emptyTitle.text = "No items match your filters"
            emptyMessage.text = "Try changing or clearing your filters"
            m.clearFiltersButton.visible = true
            m.clearFiltersButton.setFocus(true)
        else
            emptyTitle.text = "Nothing here yet"
            emptyMessage.text = "Add some content to your Plex library to see it here"
            m.clearFiltersButton.visible = false
        end if
    else
        m.emptyState.visible = false
        m.posterGrid.visible = true
    end if
end sub

sub onGridItemSelected(event as Object)
    index = event.getData()
    content = m.posterGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        c = m.global.constants

        ' Check if partially watched (viewOffset > 0 and >= 5% progress)
        if item.viewOffset > 0 and item.duration > 0
            progress = item.viewOffset / item.duration
            if progress >= c.PROGRESS_MIN_PERCENT
                showResumeDialog(item)
                return
            end if
        end if

        m.top.itemSelected = {
            action: "detail"
            ratingKey: item.ratingKey
            itemType: item.itemType
        }
    end if
end sub

' ========== Resume Dialog ==========

sub showResumeDialog(item as Object)
    m.pendingPlayItem = item
    m.pendingFocusTarget = "grid"

    resumeTime = FormatTime(item.viewOffset)

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = item.title
    dialog.message = ["Resume from " + resumeTime + "?"]
    dialog.buttons = ["Resume from " + resumeTime, "Start from Beginning", "Go to Details"]
    dialog.observeField("buttonSelected", "onResumeDialogButton")
    dialog.observeField("wasClosed", "onResumeDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onResumeDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        ' Resume from last position
        startPlaybackFromGrid(m.pendingPlayItem, m.pendingPlayItem.viewOffset)
    else if index = 1
        ' Start from beginning
        startPlaybackFromGrid(m.pendingPlayItem, 0)
    else if index = 2
        ' Go to detail screen
        m.top.itemSelected = {
            action: "detail"
            ratingKey: m.pendingPlayItem.ratingKey
            itemType: m.pendingPlayItem.itemType
        }
    end if
end sub

sub onResumeDialogClosed(event as Object)
    restoreFocusAfterDialog()
end sub

sub startPlaybackFromGrid(item as Object, offset as Integer)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = item.ratingKey
    m.player.mediaKey = "/library/metadata/" + item.ratingKey
    m.player.startOffset = offset
    m.player.itemTitle = item.title
    m.player.observeField("playbackComplete", "onGridPlaybackComplete")

    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub

sub onGridPlaybackComplete(event as Object)
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if

    ' Restore focus to grid
    m.posterGrid.setFocus(true)

    ' Refresh hub data and library to update watch states
    loadHubs()
    if m.currentSectionId <> "" and m.viewMode = "libraryOnly"
        m.currentOffset = 0
        loadLibrary()
    end if
end sub

' ========== Options Key Context Menu ==========

sub showOptionsMenu(item as Object)
    m.pendingOptionsItem = item

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = item.title

    ' Determine watched label based on item type and state
    watchedLabel = ""
    if item.viewCount <> invalid and item.viewCount > 0
        if item.itemType = "show"
            watchedLabel = "Mark Show as Unwatched"
        else
            watchedLabel = "Mark as Unwatched"
        end if
    else
        if item.itemType = "show"
            watchedLabel = "Mark Show as Watched"
        else
            watchedLabel = "Mark as Watched"
        end if
    end if

    dialog.buttons = [watchedLabel, "Cancel"]
    dialog.observeField("buttonSelected", "onOptionsMenuButton")
    dialog.observeField("wasClosed", "onOptionsMenuClosed")
    m.top.getScene().dialog = dialog
end sub

sub onOptionsMenuButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        ' Toggle watched state
        item = m.pendingOptionsItem
        if item.viewCount <> invalid and item.viewCount > 0
            ' Mark as unwatched - optimistic update
            item.viewCount = 0
            item.viewOffset = 0
            fireScrobbleApi(item.ratingKey, false)
        else
            ' Mark as watched - optimistic update
            item.viewCount = 1
            item.viewOffset = 0
            fireScrobbleApi(item.ratingKey, true)
        end if

        ' Force grid re-render by re-assigning content
        m.posterGrid.content = m.posterGrid.content
    end if

    restoreFocusAfterDialog()
end sub

sub onOptionsMenuClosed(event as Object)
    restoreFocusAfterDialog()
end sub

sub fireScrobbleApi(ratingKey as String, watched as Boolean)
    task = CreateObject("roSGNode", "PlexApiTask")
    if watched
        task.endpoint = "/:/scrobble"
    else
        task.endpoint = "/:/unscrobble"
    end if
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": ratingKey
    }
    task.control = "run"
end sub

sub restoreFocusAfterDialog()
    if m.focusArea = "hubs"
        m.hubRowList.setFocus(true)
    else
        m.posterGrid.setFocus(true)
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
    m.requestSequence = m.requestSequence + 1
    m.isFilterReload = true

    ' Fade out grid before reloading if it has content
    if m.posterGrid.opacity = 1.0 and m.posterGrid.content <> invalid and m.posterGrid.content.getChildCount() > 0
        m.gridFadeOut.observeField("state", "onGridFadeOutDone")
        m.gridFadeOut.control = "start"
    else
        loadLibrary()
    end if
end sub

sub onGridFadeOutDone(event as Object)
    if event.getData() = "stopped"
        m.gridFadeOut.unobserveField("state")
        loadLibrary()
    end if
end sub

sub onClearFiltersFromEmpty(event as Object)
    ' Reset filter state to defaults, triggering the filterChanged cascade
    m.filterBar.filterState = { sort: "titleSort:asc", genre: "", year: "", unwatched: "" }
end sub

' ========== Bottom Sheet Integration ==========

sub onBottomSheetFilterChanged(event as Object)
    newState = event.getData()
    m.filterBar.filterState = newState
    ' Pass genre display names so FilterBar can resolve genre keys to names
    if m.filterBottomSheet.genreDisplayNames <> invalid
        m.filterBar.genreNames = m.filterBottomSheet.genreDisplayNames
    end if
end sub

sub onSheetDismissed(event as Object)
    m.isSheetOpen = false
    m.filterBottomSheet.visible = false

    ' Restore focus to previous area
    if m.focusArea = "grid"
        m.posterGrid.setFocus(true)
    else if m.focusArea = "sidebar"
        m.sidebar.setFocus(true)
    else
        m.posterGrid.setFocus(true)
    end if
end sub

sub retryLastRequest()
    if m.retryContext = invalid then return
    m.isLoading = true
    m.loadingSpinner.visible = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.retryContext.endpoint
    task.params = m.retryContext.params
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.currentApiTask = task
end sub

sub showErrorDialog(title as String, message as String)
    ' Guard against dialog stacking
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
        ' Retry
        retryLastRequest()
    else if index = 1
        ' Dismiss - show inline retry
        showInlineRetry()
    end if
end sub

sub onErrorDialogClosed(event as Object)
    restoreFocusAfterDialog()
end sub

sub showInlineRetry()
    m.posterGrid.visible = false
    m.hubRowList.visible = false
    m.emptyState.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.posterGrid.visible = true
    if m.hubRowCount > 0 and m.viewMode = "hubGrid"
        m.hubRowList.visible = true
    end if
    retryLastRequest()
end sub

sub onServerReconnected(event as Object)
    if m.global.serverReconnected = true
        m.global.serverReconnected = false
        ' Re-fetch data based on current view
        if m.viewMode = "hubGrid"
            loadHubs()
        end if
        if m.currentSectionId <> ""
            m.currentOffset = 0
            loadLibrary()
        end if
    end if
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
    m.clearFiltersButton.unobserveField("buttonSelected")
    m.filterBottomSheet.unobserveField("filterState")
    m.filterBottomSheet.unobserveField("sheetDismissed")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' When bottom sheet is open, let it handle all keys
    if m.isSheetOpen then return false

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
    else if key = "options"
        if m.viewMode = "libraryOnly" and not m.isSheetOpen
            ' In library view, options key opens filter bottom sheet
            m.filterBottomSheet.sectionId = m.currentSectionId
            m.filterBottomSheet.sectionType = m.currentSectionType
            m.filterBottomSheet.visible = true
            m.isSheetOpen = true
            return true
        else
            ' In hub view, show context menu for focused item
            if m.focusArea = "grid"
                gridNode = m.posterGrid.findNode("grid")
                if gridNode <> invalid
                    focusedIndex = gridNode.itemFocused
                    content = m.posterGrid.content
                    if content <> invalid and focusedIndex >= 0 and focusedIndex < content.getChildCount()
                        item = content.getChild(focusedIndex)
                        showOptionsMenu(item)
                        return true
                    end if
                end if
            else if m.focusArea = "hubs"
                ' Get focused hub row item
                focusedInfo = m.hubRowList.rowItemFocused
                if focusedInfo <> invalid
                    rowContent = m.hubRowList.content.getChild(focusedInfo[0])
                    if rowContent <> invalid
                        itemContent = rowContent.getChild(focusedInfo[1])
                        if itemContent <> invalid
                            showOptionsMenu(itemContent)
                            return true
                        end if
                    end if
                end if
            end if
        end if
    else if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
