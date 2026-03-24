sub init()
    LogEvent("HomeScreen init: finding nodes")
    m.sidebar = m.top.findNode("sidebar")
    m.posterGrid = m.top.findNode("posterGrid")
    m.filterBar = m.top.findNode("filterBar")
    m.alphaNav = m.top.findNode("alphaNav")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.hubRowContainer = m.top.findNode("hubRowContainer")
    m.hubRowList = invalid
    m.emptyState = m.top.findNode("emptyState")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.gridFadeOut = m.top.findNode("gridFadeOut")
    m.gridFadeIn = m.top.findNode("gridFadeIn")
    m.clearFiltersButton = m.top.findNode("clearFiltersButton")
    m.requestSequence = 0
    m.isFilterReload = false
    m.unfilteredTotal = 0

    m.filterBottomSheetContainer = m.top.findNode("filterBottomSheetContainer")
    m.filterBottomSheet = invalid
    m.isSheetOpen = false

    m.retryCount = 0
    m.retryContext = invalid

    LogEvent("HomeScreen init: setting up observers")

    ' Observe inline retry button
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")

    ' Observe clear filters button in empty state
    m.clearFiltersButton.observeField("buttonSelected", "onClearFiltersFromEmpty")

    ' Bottom sheet observers set when created on demand

    ' Observe server reconnected signal
    m.global.observeField("serverReconnected", "onServerReconnected")

    ' Observe watch state updates from DetailScreen
    m.global.observeField("watchStateUpdate", "onWatchStateUpdate")

    ' Observe hub refresh signal from settings
    m.global.observeField("hubsNeedRefresh", "onHubsNeedRefresh")

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

    ' Collections view state
    m.isCollectionsView = false
    m.collectionRatingKey = ""

    ' Playlists view state
    m.isPlaylistsView = false

    ' Observe sidebar selection
    m.sidebar.observeField("selectedLibrary", "onLibrarySelected")
    m.sidebar.observeField("specialAction", "onSpecialAction")

    ' Observe grid events
    m.posterGrid.observeField("itemSelected", "onGridItemSelected")
    m.posterGrid.observeField("loadMore", "onLoadMore")

    ' Observe filter changes
    m.filterBar.observeField("filterChanged", "onFilterChanged")

    ' Observe alpha nav letter selection
    m.alphaNav.observeField("selectedLetter", "onAlphaNavSelected")

    ' Hub row item selection observer is set when RowList is created dynamically

    ' Delegate focus to appropriate child when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")

    LogEvent("HomeScreen init: starting timers and loading")

    ' Auto-refresh timer for hub rows (2 minutes)
    m.hubRefreshTimer = CreateObject("roSGNode", "Timer")
    m.hubRefreshTimer.duration = 120
    m.hubRefreshTimer.repeat = true
    m.hubRefreshTimer.observeField("fire", "onHubRefreshTimer")
    m.hubRefreshTimer.control = "start"

    ' In hub view mode, hide posterGrid and filterBar initially
    m.posterGrid.visible = false
    m.filterBar.visible = false

    ' Load hub rows on init
    loadHubs()

    ' Set initial focus to sidebar (focusedChild observer won't fire on first push)
    focusSidebar()
    LogEvent("HomeScreen init: complete")
end sub

sub onFocusChange(event as Object)
    ' When HomeScreen regains focus (e.g., returning from playback/detail)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        ' Refresh hub data on return
        loadHubs()

        ' Delegate focus to the appropriate area
        if m.focusArea = "sidebar"
            focusSidebar()
        else if m.focusArea = "hubs" and m.hubRowCount > 0 and m.hubRowList <> invalid
            m.hubRowList.setFocus(true)
        else
            focusGrid()
        end if
    end if
end sub

' ========== Focus Helpers ==========

sub focusSidebar()
    navList = m.sidebar.findNode("navList")
    if navList <> invalid
        navList.jumpToItem = 0
        navList.setFocus(true)
    else
        m.sidebar.setFocus(true)
    end if
end sub

sub focusGrid()
    ' Directly focus the inner MarkupGrid to ensure key events work
    gridNode = m.posterGrid.findNode("grid")
    if gridNode <> invalid
        gridNode.setFocus(true)
    else
        m.posterGrid.setFocus(true)
    end if
end sub

' ========== Hub Row Data Fetching ==========

sub loadHubs()
    if m.isLoadingHubs then return
    m.isLoadingHubs = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/hubs"
    task.params = { "count": "20" }
    task.observeField("status", "onHubsLoaded")
    task.control = "run"
    m.hubsTask = task
end sub

sub onHubsLoaded(event as Object)
    m.isLoadingHubs = false
    if event.getData() <> "completed" then return

    if m.hubsTask.response = invalid or m.hubsTask.response.MediaContainer = invalid then return

    hubs = m.hubsTask.response.MediaContainer.Hub
    if hubs = invalid then hubs = []

    ' Filter hubs by exact ID whitelist
    m.allHubs = []
    allowedIds = {
        "home.continue": true
        "home.ondeck": true
        "home.movies.recent": true
        "home.television.recent": true
    }
    for each hub in hubs
        if hub.Metadata <> invalid and hub.Metadata.count() > 0
            hubId = hub.hubIdentifier
            hubTitle = ""
            if hub.title <> invalid then hubTitle = hub.title
            LogEvent("Hub: id=" + hubId + " title=" + hubTitle)

            if hubId <> invalid and allowedIds[hubId] = true
                m.allHubs.push(hub)
                LogEvent("Hub INCLUDED: " + hubTitle)
            else
                LogEvent("Hub EXCLUDED: " + hubTitle)
            end if
        end if
    end for

    ' Fetch recently added for user-pinned libraries
    loadPinnedLibraryHubs()
end sub

sub loadPinnedLibraryHubs()
    ' Load pinned libraries from settings
    m.pinnedLibs = GetPinnedLibraries()

    if m.pinnedLibs.count() = 0
        buildHubRowContent()
        return
    end if

    m.pinnedLibTasks = {}
    m.pinnedLibPending = 0

    for each lib in m.pinnedLibs
        m.pinnedLibPending = m.pinnedLibPending + 1
        endpoint = "/library/sections/" + lib.key + "/recentlyAdded"
        m.pinnedLibTasks[endpoint] = lib.title

        task = CreateObject("roSGNode", "PlexApiTask")
        task.endpoint = endpoint
        task.params = { "X-Plex-Container-Size": "20" }
        task.observeField("status", "onPinnedLibLoaded")
        task.control = "run"
        LogEvent("Fetching recently added for: " + lib.title + " (section " + lib.key + ")")
    end for
end sub

sub onPinnedLibLoaded(event as Object)
    task = event.getRoSGNode()
    if event.getData() = "completed" and task.response <> invalid and task.response.MediaContainer <> invalid
        metadata = task.response.MediaContainer.Metadata
        libTitle = m.pinnedLibTasks[task.endpoint]
        if libTitle = invalid then libTitle = "Unknown"

        if metadata <> invalid and metadata.count() > 0
            ' Skip pinned library hub if a built-in hub already covers it
            ' (home.movies.recent covers "Movies", home.television.recent covers "TV")
            isDuplicate = false
            for each existingHub in m.allHubs
                existingTitle = ""
                if existingHub.title <> invalid then existingTitle = LCase(existingHub.title)
                pinnedTitle = LCase("Recently Added " + libTitle)
                ' Check if built-in hub title matches this pinned library's content
                if existingTitle = "recently added movies" and LCase(libTitle) = "movies"
                    isDuplicate = true
                    exit for
                else if existingTitle = "recently added tv" and LCase(libTitle) = "tv"
                    isDuplicate = true
                    exit for
                end if
            end for
            if not isDuplicate
                hubObj = { title: "Recently Added " + libTitle, Metadata: metadata, hubIdentifier: "library.pinned" }
                m.allHubs.push(hubObj)
                LogEvent("Hub ADDED: Recently Added " + libTitle)
            else
                LogEvent("Hub SKIPPED (duplicate): Recently Added " + libTitle)
            end if
        end if
    end if

    m.pinnedLibPending = m.pinnedLibPending - 1
    if m.pinnedLibPending <= 0
        buildHubRowContent()
    end if
end sub

function sortHubRows(hubs as Object) as Object
    ' Built-in hubs always first in fixed order, then pinned libraries in user order
    ' Build pinned library sort keys from stored order
    pinnedLibs = GetPinnedLibraries()
    pinnedSortMap = {}
    for i = 0 to pinnedLibs.count() - 1
        pinnedSortMap[LCase(pinnedLibs[i].title)] = 10 + i
    end for

    ' Assign sort keys
    tagged = []
    for each hub in hubs
        title = LCase(hub.title)
        sortKey = 99
        if Instr(1, title, "continue") > 0
            sortKey = 0
        else if Instr(1, title, "on deck") > 0 or Instr(1, title, "ondeck") > 0
            sortKey = 1
        else if Instr(1, title, "television") > 0 or (Instr(1, title, " tv") > 0)
            sortKey = 2
        else if Instr(1, title, "movies") > 0
            sortKey = 3
        else
            ' Check if it matches a pinned library
            for each pinnedTitle in pinnedSortMap
                if Instr(1, title, pinnedTitle) > 0
                    sortKey = pinnedSortMap[pinnedTitle]
                    exit for
                end if
            end for
        end if
        tagged.push({ hub: hub, sortKey: sortKey })
    end for

    ' Insertion sort by sortKey
    for i = 1 to tagged.count() - 1
        key = tagged[i]
        j = i - 1
        while j >= 0 and tagged[j].sortKey > key.sortKey
            tagged[j + 1] = tagged[j]
            j = j - 1
        end while
        tagged[j + 1] = key
    end for

    sorted = []
    for each item in tagged
        sorted.push(item.hub)
    end for
    return sorted
end function

sub buildHubRowContent()
    rootContent = CreateObject("roSGNode", "ContentNode")
    m.hubRowMap = {}
    rowIndex = 0
    c = m.global.constants

    ' Sort hubs into desired display order
    orderedHubs = sortHubRows(m.allHubs)

    ' Add rows for all hubs that have content
    for each hub in orderedHubs
        hubTitle = hub.title
        if hubTitle = invalid or hubTitle = "" then hubTitle = "Hub"
        hubId = hub.hubIdentifier
        if hubId = invalid then hubId = "unknown"
        addHubRow(rootContent, hubTitle, hub.Metadata, c, hubId)
        m.hubRowMap[rowIndex.ToStr()] = hubId
        rowIndex = rowIndex + 1
    end for

    ' Create RowList dynamically only when we have data (avoids firmware crash with empty RowList)
    if rowIndex > 0
        if m.hubRowList = invalid
            m.hubRowList = CreateObject("roSGNode", "RowList")
            m.hubRowList.translation = [20, 20]
            m.hubRowList.itemSize = [1540, 510]
            m.hubRowList.rowItemSize = [[240, 390]]
            m.hubRowList.rowItemSpacing = [[20, 0]]
            m.hubRowList.itemSpacing = [0, 40]
            m.hubRowList.showRowLabel = [true]
            m.hubRowList.rowLabelOffset = [[0, 10]]
            m.hubRowList.rowLabelColor = "0xF3B125FF"
            m.hubRowList.rowLabelFont = "font:MediumBoldSystemFont"
            m.hubRowList.drawFocusFeedback = true
            m.hubRowList.focusBitmapBlendColor = "0xF3B125FF"
            m.hubRowList.vertFocusAnimationStyle = "fixedFocusWrap"
            m.hubRowList.rowFocusAnimationStyle = "floatingFocus"
            m.hubRowList.itemComponentName = "PosterGridItem"
            m.hubRowList.observeField("rowItemSelected", "onHubItemSelected")
            m.hubRowContainer.appendChild(m.hubRowList)
        end if
        m.hubRowList.numRows = 2
        m.hubRowList.content = rootContent
        m.hubRowList.visible = (m.viewMode = "hubGrid")
    else if m.hubRowList <> invalid
        m.hubRowList.visible = false
    end if
    m.hubRowCount = rowIndex

    ' Restore scroll position if saved (from refresh, not initial load)
    if m.hubRowList <> invalid and m.savedHubFocus <> invalid and rowIndex = m.savedHubFocus.count()
        m.hubRowList.jumpToRowItem = m.savedHubFocus
        m.savedHubFocus = invalid
    end if
end sub

sub addHubRow(rootContent as Object, title as String, metadata as Object, c as Object, hubId as String)
    rowNode = rootContent.createChild("ContentNode")
    rowNode.title = title

    ' Only deduplicate episodes for "recently added" type hubs, NOT for continue/ondeck
    shouldDedup = (Instr(1, LCase(hubId), "recent") > 0 or hubId = "library.pinned")
    seenShows = {}

    for each item in metadata
        ' Deduplicate: if this is an episode in a recently-added hub and we already have this show, skip
        if shouldDedup and item.type = "episode" and item.grandparentRatingKey <> invalid
            showKey = GetRatingKeyStr(item.grandparentRatingKey)
            if seenShows[showKey] = true
                continue for
            end if
            seenShows[showKey] = true
        end if

        itemNode = rowNode.createChild("ContentNode")

        ' For episodes in recently-added hubs, present as the parent show
        isEpisodeDedup = (shouldDedup and item.type = "episode" and item.grandparentRatingKey <> invalid)
        if isEpisodeDedup
            ratingKeyStr = GetRatingKeyStr(item.grandparentRatingKey)
            itemTitle = item.grandparentTitle
            if itemTitle = invalid or itemTitle = "" then itemTitle = item.title
            itemType = "show"
        else
            ratingKeyStr = GetRatingKeyStr(item.ratingKey)
            itemTitle = item.title
            itemType = item.type
        end if

        itemNode.addFields({
            title: itemTitle
            ratingKey: ratingKeyStr
            itemType: itemType
            viewOffset: 0
            duration: 0
            viewCount: 0
            leafCount: 0
            viewedLeafCount: 0
            isHubItem: true
        })

        if not isEpisodeDedup
            if item.viewOffset <> invalid then itemNode.viewOffset = item.viewOffset
            if item.viewCount <> invalid then itemNode.viewCount = item.viewCount
        end if
        if item.leafCount <> invalid then itemNode.leafCount = item.leafCount
        if item.viewedLeafCount <> invalid then itemNode.viewedLeafCount = item.viewedLeafCount
        if item.duration <> invalid
            itemNode.duration = item.duration
        else if item.Media <> invalid and item.Media.count() > 0
            if item.Media[0].duration <> invalid
                itemNode.duration = item.Media[0].duration
            end if
        end if

        ' Prefer show/season poster over episode screenshot for hub items
        posterThumb = invalid
        if item.grandparentThumb <> invalid and item.grandparentThumb <> ""
            posterThumb = item.grandparentThumb
        else if item.parentThumb <> invalid and item.parentThumb <> ""
            posterThumb = item.parentThumb
        else if item.thumb <> invalid and item.thumb <> ""
            posterThumb = item.thumb
        end if
        if posterThumb <> invalid
            itemNode.HDPosterUrl = BuildPosterUrl(posterThumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
        end if
    end for
end sub

' No longer needed - hubGrid mode shows only RowList, libraryOnly mode shows only posterGrid

' ========== Hub Row Item Selection ==========

sub onHubItemSelected(event as Object)
    selectedInfo = event.getData()
    rowIndex = selectedInfo[0]
    itemIndex = selectedInfo[1]

    ' Determine which hub type this row represents
    hubId = m.hubRowMap[rowIndex.ToStr()]

    ' Get the content node for this item
    if m.hubRowList = invalid then return
    rowContent = m.hubRowList.content.getChild(rowIndex)
    if rowContent = invalid then return
    itemContent = rowContent.getChild(itemIndex)
    if itemContent = invalid then return

    ' Continue watching hub: resume playback immediately
    if hubId <> invalid and Instr(1, LCase(hubId), "continue") > 0
        m.top.itemSelected = {
            action: "play"
            ratingKey: itemContent.ratingKey
            itemType: itemContent.itemType
            viewOffset: itemContent.viewOffset
        }
    else if itemContent.itemType = "show"
        ' TV shows: go directly to EpisodeScreen
        m.top.itemSelected = {
            action: "episodes"
            ratingKey: itemContent.ratingKey
            title: itemContent.title
        }
    else
        ' All other hubs: open detail screen
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
        if m.hubRowList <> invalid and m.hubRowList.rowItemFocused <> invalid
            m.savedHubFocus = m.hubRowList.rowItemFocused
        end if
        loadHubs()
    end if
end sub

' ========== View Mode ==========

sub onViewModeChanged()
    if m.viewMode = "libraryOnly"
        ' Library view: hide hubs, show grid and filter bar with alpha nav
        if m.hubRowList <> invalid then m.hubRowList.visible = false
        m.filterBar.translation = [20, 20]
        m.posterGrid.translation = [20, 100]
        m.posterGrid.visible = true
        m.filterBar.visible = true
        m.alphaNav.visible = true
        ' 6 columns with tighter spacing to fit alongside alpha nav
        ' Available: 1560 - 60(alphanav) - 20(pad) = 1480px
        ' 6 * 240 + 5 * 8 = 1480
        gridNode = m.posterGrid.findNode("grid")
        if gridNode <> invalid
            gridNode.numColumns = 6
            gridNode.itemSize = [240, 390]
            gridNode.itemSpacing = [8, 20]
        end if
    else if m.viewMode = "hubGrid"
        ' Hub view: show hubs, hide grid, filter bar, and alpha nav
        if m.hubRowCount > 0 and m.hubRowList <> invalid
            m.hubRowList.visible = true
        end if
        m.posterGrid.visible = false
        m.filterBar.visible = false
        m.alphaNav.visible = false
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

        ' Move focus to content grid
        m.focusArea = "grid"
        focusGrid()

        loadLibrary()
    end if
end sub

sub onSpecialAction(event as Object)
    action = event.getData()
    if action = "viewHome"
        m.isCollectionsView = false
        m.collectionRatingKey = ""
        m.isPlaylistsView = false
        m.viewMode = "hubGrid"
        m.filterBar.visible = true
        onViewModeChanged()
    else if action = "viewCollections"
        ' Auto-select first library if none active (FIX-04)
        if m.currentSectionId = ""
            sidebarLibs = m.sidebar.libraries
            if sidebarLibs <> invalid and sidebarLibs.items <> invalid and sidebarLibs.items.count() > 0
                firstLib = sidebarLibs.items[0]
                m.currentSectionId = firstLib.key
                m.currentSectionType = firstLib.type
                print "Collections auto-selected library: " + firstLib.title + " (section " + firstLib.key + ")"
            end if
        end if
        if m.currentSectionId <> ""
            m.isCollectionsView = true
            m.collectionRatingKey = ""
            m.isPlaylistsView = false
            m.currentOffset = 0
            m.viewMode = "libraryOnly"
            onViewModeChanged()
            m.filterBar.visible = false
            m.alphaNav.visible = false
            loadCollections()
        end if
    else if action = "playlists"
        m.isPlaylistsView = true
        m.isCollectionsView = false
        m.collectionRatingKey = ""
        m.currentOffset = 0
        m.viewMode = "libraryOnly"
        onViewModeChanged()
        m.filterBar.visible = false
        m.alphaNav.visible = false
        loadPlaylists()
    else if action = "search"
        m.top.itemSelected = { action: "search" }
    else if action = "settings"
        m.top.itemSelected = { action: "settings" }
    else if action = "viewLibraries"
        showLibraryPickerDialog()
    end if
end sub

sub showLibraryPickerDialog()
    sidebarLibs = m.sidebar.libraries
    if sidebarLibs = invalid or sidebarLibs.items = invalid or sidebarLibs.items.count() = 0
        return
    end if

    ' Fetch ALL libraries from the API (not just sidebar-pinned ones)
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/sections"
    task.params = {}
    task.observeField("status", "onLibraryPickerLoaded")
    task.control = "run"
    m.libraryPickerTask = task
end sub

sub onLibraryPickerLoaded(event as Object)
    if event.getData() <> "completed" then return
    response = m.libraryPickerTask.response
    if response = invalid or response.MediaContainer = invalid then return

    directories = response.MediaContainer.Directory
    if directories = invalid or directories.count() = 0 then return

    ' Filter to supported types and build button list
    m.libraryPickerItems = []
    buttonLabels = []
    for each lib in directories
        if lib.type = "movie" or lib.type = "show"
            m.libraryPickerItems.push({ key: lib.key, type: lib.type, title: lib.title })
            buttonLabels.push(lib.title)
        end if
    end for

    if buttonLabels.count() = 0 then return

    ' Sort alphabetically
    for i = 1 to m.libraryPickerItems.count() - 1
        key = m.libraryPickerItems[i]
        keyLabel = buttonLabels[i]
        j = i - 1
        while j >= 0 and LCase(m.libraryPickerItems[j].title) > LCase(key.title)
            m.libraryPickerItems[j + 1] = m.libraryPickerItems[j]
            buttonLabels[j + 1] = buttonLabels[j]
            j = j - 1
        end while
        m.libraryPickerItems[j + 1] = key
        buttonLabels[j + 1] = keyLabel
    end for

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Select Library"
    dialog.message = ["Choose a library to browse:"]
    dialog.buttons = buttonLabels
    dialog.observeField("buttonSelected", "onLibraryPickerButton")
    dialog.observeField("wasClosed", "onLibraryPickerClosed")
    m.top.getScene().dialog = dialog
end sub

sub onLibraryPickerButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index >= 0 and index < m.libraryPickerItems.count()
        lib = m.libraryPickerItems[index]
        m.currentSectionId = lib.key
        m.currentSectionType = lib.type
        m.isCollectionsView = false
        m.collectionRatingKey = ""
        m.isPlaylistsView = false
        m.currentOffset = 0
        m.viewMode = "libraryOnly"
        onViewModeChanged()
        m.filterBar.visible = true
        m.alphaNav.visible = true
        loadLibrary()
    end if
end sub

sub onLibraryPickerClosed(event as Object)
    focusSidebar()
end sub

sub loadLibrary()
    if m.isLoading then return
    m.isLoading = true
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
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
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.isLoading = false
        m.retryCount = 0
        m.retryGroup.visible = false
        processApiResponse()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
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

    isNewContent = (m.currentOffset = 0)
    if isNewContent
        ' New data set - create fresh content
        content = CreateObject("roSGNode", "ContentNode")
    else
        ' Appending to existing content
        content = m.posterGrid.content
        if content = invalid
            content = CreateObject("roSGNode", "ContentNode")
            isNewContent = true
        end if
    end if

    for each item in metadata
        node = content.createChild("ContentNode")

        ' Ensure ratingKey is stored as string
        ratingKeyStr = GetRatingKeyStr(item.ratingKey)

        titleSortStr = ""
        if item.titleSort <> invalid
            titleSortStr = item.titleSort
        else
            titleSortStr = item.title
        end if

        node.addFields({
            title: item.title
            titleSort: titleSortStr
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

    ' Only set content on first page to avoid resetting scroll position
    if isNewContent
        m.posterGrid.content = content
    end if
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

    ' Auto-fetch ALL remaining items in one request after first page
    if m.currentOffset < m.totalItems and m.currentOffset = metadata.count() and not m.isCollectionsView and not m.isPlaylistsView and m.collectionRatingKey = ""
        m.autoLoadTimer = CreateObject("roSGNode", "Timer")
        m.autoLoadTimer.duration = 0.2
        m.autoLoadTimer.repeat = false
        m.autoLoadTimer.observeField("fire", "onAutoLoadNext")
        m.autoLoadTimer.control = "start"
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

' ========== Collections ==========

sub loadCollections()
    if m.isLoading then return
    m.isLoading = true
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false
    m.retryGroup.visible = false

    ' Cancel previous API task
    if m.currentApiTask <> invalid
        m.currentApiTask.control = "stop"
        m.currentApiTask.unobserveField("status")
    end if

    endpoint = "/library/sections/" + m.currentSectionId + "/collections"
    params = {
        "X-Plex-Container-Start": m.currentOffset.ToStr()
        "X-Plex-Container-Size": m.global.constants.PAGE_SIZE.ToStr()
    }

    m.retryContext = { endpoint: endpoint, params: params, handler: "onCollectionsLoaded", requestType: "collections" }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = params
    task.observeField("status", "onCollectionsLoaded")
    task.control = "run"
    m.currentApiTask = task
end sub

sub onCollectionsLoaded(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.isLoading = false
        m.retryCount = 0
        m.retryGroup.visible = false

        response = m.currentApiTask.response
        if response = invalid or response.MediaContainer = invalid then return

        c = m.global.constants
        metadata = response.MediaContainer.Metadata
        if metadata = invalid then metadata = []

        content = CreateObject("roSGNode", "ContentNode")

        for each item in metadata
            node = content.createChild("ContentNode")

            ratingKeyStr = GetRatingKeyStr(item.ratingKey)

            node.addFields({
                title: item.title
                ratingKey: ratingKeyStr
                itemType: "collection"
                viewOffset: 0
                duration: 0
                viewCount: 0
                leafCount: 0
                viewedLeafCount: 0
                isHubItem: true
            })

            if item.childCount <> invalid then node.leafCount = item.childCount

            if item.thumb <> invalid and item.thumb <> ""
                node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
            end if
        end for

        m.posterGrid.content = content
        m.posterGrid.visible = true

        ' Show empty state if no collections
        if metadata.count() = 0
            m.emptyState.visible = true
            m.posterGrid.visible = false
            emptyTitle = m.top.findNode("emptyTitle")
            emptyMessage = m.top.findNode("emptyMessage")
            emptyTitle.text = "No collections found"
            emptyMessage.text = "Create collections in Plex to organize your library"
            m.clearFiltersButton.visible = false
        else
            m.emptyState.visible = false
        end if
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.isLoading = false
        if m.currentApiTask.responseCode < 0
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                m.global.serverUnreachable = true
            end if
        else
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                showErrorDialog("Error", "Couldn't load collections. Please try again.")
            end if
        end if
    end if
end sub

sub loadCollectionContents(collectionKey as String)
    m.collectionRatingKey = collectionKey
    m.currentOffset = 0
    m.isLoading = true
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false

    ' Cancel previous API task
    if m.currentApiTask <> invalid
        m.currentApiTask.control = "stop"
        m.currentApiTask.unobserveField("status")
    end if

    endpoint = "/library/collections/" + collectionKey + "/children"
    params = {
        "X-Plex-Container-Start": "0"
        "X-Plex-Container-Size": m.global.constants.PAGE_SIZE.ToStr()
    }

    m.retryContext = { endpoint: endpoint, params: params, handler: "onApiTaskStateChange", requestType: "library" }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = params
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.currentApiTask = task
end sub

' ========== Playlists ==========

sub loadPlaylists()
    if m.isLoading then return
    m.isLoading = true
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false
    m.retryGroup.visible = false

    ' Cancel previous API task
    if m.currentApiTask <> invalid
        m.currentApiTask.control = "stop"
        m.currentApiTask.unobserveField("status")
    end if

    m.retryContext = { endpoint: "/playlists", params: {}, handler: "onPlaylistsLoaded", requestType: "playlists" }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/playlists"
    task.params = {}
    task.observeField("status", "onPlaylistsLoaded")
    task.control = "run"
    m.currentApiTask = task
end sub

sub onPlaylistsLoaded(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.isLoading = false
        m.retryCount = 0
        m.retryGroup.visible = false

        response = m.currentApiTask.response
        if response = invalid or response.MediaContainer = invalid then return

        c = m.global.constants
        metadata = response.MediaContainer.Metadata
        if metadata = invalid then metadata = []

        content = CreateObject("roSGNode", "ContentNode")

        for each item in metadata
            ' Only show video playlists
            if item.playlistType = "video"
                node = content.createChild("ContentNode")

                ratingKeyStr = GetRatingKeyStr(item.ratingKey)

                node.addFields({
                    title: item.title
                    ratingKey: ratingKeyStr
                    itemType: "playlist"
                    viewOffset: 0
                    duration: 0
                    viewCount: 0
                    leafCount: 0
                    viewedLeafCount: 0
                    isHubItem: true
                })

                if item.leafCount <> invalid then node.leafCount = item.leafCount

                if item.thumb <> invalid and item.thumb <> ""
                    node.HDPosterUrl = BuildPosterUrl(item.thumb, c.POSTER_WIDTH, c.POSTER_HEIGHT)
                end if
            end if
        end for

        m.posterGrid.content = content
        m.posterGrid.visible = true

        ' Show empty state if no video playlists
        if content.getChildCount() = 0
            m.emptyState.visible = true
            m.posterGrid.visible = false
            emptyTitle = m.top.findNode("emptyTitle")
            emptyMessage = m.top.findNode("emptyMessage")
            emptyTitle.text = "No playlists found"
            emptyMessage.text = "Create playlists in Plex to organize your media"
            m.clearFiltersButton.visible = false
        else
            m.emptyState.visible = false
        end if
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.isLoading = false
        if m.currentApiTask.responseCode < 0
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                m.global.serverUnreachable = true
            end if
        else
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                showErrorDialog("Error", "Couldn't load playlists. Please try again.")
            end if
        end if
    end if
end sub

sub onGridItemSelected(event as Object)
    index = event.getData()
    content = m.posterGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        c = m.global.constants

        ' Handle collection item selection
        if item.itemType = "collection"
            loadCollectionContents(item.ratingKey)
            m.isCollectionsView = false
            return
        end if

        ' Handle playlist item selection
        if item.itemType = "playlist"
            m.top.itemSelected = {
                action: "playlist"
                ratingKey: item.ratingKey
                title: item.title
            }
            return
        end if

        ' Check if partially watched (viewOffset > 0 and >= 5% progress)
        if item.viewOffset > 0 and item.duration > 0
            progress = item.viewOffset / item.duration
            if progress >= c.PROGRESS_MIN_PERCENT
                showResumeDialog(item)
                return
            end if
        end if

        ' TV shows: go directly to EpisodeScreen
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
    focusGrid()

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

    if item.itemType = "show"
        dialog.buttons = [watchedLabel, "Show Info", "Cancel"]
    else
        dialog.buttons = [watchedLabel, "Cancel"]
    end if
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
    else if index = 1 and m.pendingOptionsItem.itemType = "show"
        ' "Show Info" — navigate to DetailScreen for this show
        m.top.itemSelected = {
            action: "detail"
            ratingKey: m.pendingOptionsItem.ratingKey
            itemType: "show"
        }
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
    if m.focusArea = "hubs" and m.hubRowList <> invalid
        m.hubRowList.setFocus(true)
    else
        focusGrid()
    end if
end sub

sub onAlphaNavSelected(event as Object)
    letter = event.getData()
    if letter = invalid or letter = "" then return
    LogEvent("AlphaNav jump to: " + letter)

    ' Get content from the inner MarkupGrid directly
    gridNode = m.posterGrid.findNode("grid")
    if gridNode = invalid then return
    content = gridNode.content
    if content = invalid
        LogEvent("AlphaNav: no grid content")
        return
    end if

    count = content.getChildCount()

    for i = 0 to count - 1
        item = content.getChild(i)
        if item <> invalid
            ' Use titleSort for comparison (matches server sort order)
            sortTitle = ""
            if item.titleSort <> invalid and item.titleSort <> ""
                sortTitle = item.titleSort
            else if item.title <> invalid
                sortTitle = item.title
            end if
            if sortTitle = "" then sortTitle = "Z"

            firstChar = UCase(Left(sortTitle, 1))
            if letter = "#"
                if firstChar >= "0" and firstChar <= "9"
                    LogEvent("AlphaNav: jump to " + i.ToStr() + " (" + item.title + ")")
                    gridNode.jumpToItem = i
                    return
                end if
            else if firstChar >= letter
                LogEvent("AlphaNav: jump to " + i.ToStr() + " (" + item.title + ")")
                gridNode.jumpToItem = i
                return
            end if
        end if
    end for
    LogEvent("AlphaNav: no match for " + letter)
end sub

sub onLoadMore(event as Object)
    if m.isLoading then return
    if m.currentOffset >= m.totalItems then return
    if m.currentSectionId = "onDeck" or m.currentSectionId = "recentlyAdded" then return

    ' No pagination for collections list or playlists list
    if m.isCollectionsView then return
    if m.isPlaylistsView then return

    ' Collection contents use normal library pagination
    if m.collectionRatingKey <> ""
        loadCollectionContents(m.collectionRatingKey)
        return
    end if

    loadLibrary()
end sub

sub onAutoLoadNext(event as Object)
    ' Auto-load ALL remaining library content in one request
    if m.currentOffset < m.totalItems and not m.isLoading
        loadLibraryBulk()
    end if
end sub

sub loadLibraryBulk()
    if m.isLoading then return
    m.isLoading = true

    c = m.global.constants
    remaining = m.totalItems - m.currentOffset
    endpoint = "/library/sections/" + m.currentSectionId + "/all"
    params = {
        "X-Plex-Container-Start": m.currentOffset.ToStr()
        "X-Plex-Container-Size": remaining.ToStr()
    }

    ' Apply active filters
    if m.filterBar.activeFilters <> invalid
        for each key in m.filterBar.activeFilters
            params[key] = m.filterBar.activeFilters[key]
        end for
    end if
    if params["sort"] = invalid
        params["sort"] = "titleSort:asc"
    end if

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = params
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.currentApiTask = task
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
    if m.filterBottomSheet <> invalid and m.filterBottomSheet.genreDisplayNames <> invalid
        m.filterBar.genreNames = m.filterBottomSheet.genreDisplayNames
    end if
end sub

sub onSheetDismissed(event as Object)
    m.isSheetOpen = false
    if m.filterBottomSheet <> invalid then m.filterBottomSheet.showSheet = false

    ' Restore focus to previous area
    if m.focusArea = "grid"
        focusGrid()
    else if m.focusArea = "sidebar"
        focusSidebar()
    else
        focusGrid()
    end if
end sub

sub retryLastRequest()
    if m.retryContext = invalid then return
    m.isLoading = true
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true

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
    if m.hubRowList <> invalid then m.hubRowList.visible = false
    m.emptyState.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.posterGrid.visible = true
    if m.hubRowCount > 0 and m.viewMode = "hubGrid" and m.hubRowList <> invalid
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
        if m.isPlaylistsView
            m.currentOffset = 0
            loadPlaylists()
        else if m.isCollectionsView
            m.currentOffset = 0
            loadCollections()
        else if m.collectionRatingKey <> ""
            m.currentOffset = 0
            loadCollectionContents(m.collectionRatingKey)
        else if m.currentSectionId <> ""
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
    if m.hubRowList <> invalid then m.hubRowList.unobserveField("itemSelected")

    ' Unobserve child widgets
    m.sidebar.unobserveField("selectedLibrary")
    m.sidebar.unobserveField("specialAction")
    m.posterGrid.unobserveField("itemSelected")
    m.posterGrid.unobserveField("loadMore")
    m.filterBar.unobserveField("filterChanged")
    m.alphaNav.unobserveField("selectedLetter")
    m.clearFiltersButton.unobserveField("buttonSelected")
    if m.filterBottomSheet <> invalid
        m.filterBottomSheet.unobserveField("filterState")
        m.filterBottomSheet.unobserveField("sheetDismissed")
    end if
end sub

sub onHubsNeedRefresh(event as Object)
    if m.global.hubsNeedRefresh = true
        m.global.hubsNeedRefresh = false
        if m.viewMode = "hubGrid"
            loadHubs()
        end if
    end if
end sub

sub onWatchStateUpdate(event as Object)
    update = event.getData()
    if update = invalid or update.ratingKey = invalid then return

    ratingKey = update.ratingKey
    viewCount = update.viewCount

    ' Update matching items in hub RowList
    if m.hubRowList <> invalid and m.hubRowList.content <> invalid
        for rowIdx = 0 to m.hubRowList.content.getChildCount() - 1
            row = m.hubRowList.content.getChild(rowIdx)
            if row <> invalid
                for itemIdx = 0 to row.getChildCount() - 1
                    item = row.getChild(itemIdx)
                    if item <> invalid and item.ratingKey = ratingKey
                        item.viewCount = viewCount
                        if update.viewOffset <> invalid
                            item.viewOffset = update.viewOffset
                        end if
                    end if
                end for
            end if
        end for
    end if

    ' Update matching items in poster grid
    gridNode = m.posterGrid.findNode("grid")
    if gridNode <> invalid and gridNode.content <> invalid
        for i = 0 to gridNode.content.getChildCount() - 1
            item = gridNode.content.getChild(i)
            if item <> invalid and item.ratingKey = ratingKey
                item.viewCount = viewCount
                if update.viewOffset <> invalid
                    item.viewOffset = update.viewOffset
                end if
            end if
        end for
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' When bottom sheet is open, let it handle all keys
    if m.isSheetOpen then return false

    if key = "down"
        if m.focusArea = "hubs" and m.hubRowList <> invalid and m.posterGrid.visible
            ' Only transition to grid if grid is visible (libraryOnly mode)
            focusedRow = m.hubRowList.rowItemFocused
            if focusedRow <> invalid and focusedRow[0] >= m.hubRowCount - 1
                m.focusArea = "grid"
                focusGrid()
                return true
            end if
        end if
    else if key = "up"
        if m.focusArea = "grid"
            ' Check if grid is at top row
            gridNode = m.posterGrid.findNode("grid")
            if gridNode <> invalid
                c = m.global.constants
                if gridNode.itemFocused < c.GRID_COLUMNS and m.hubRowCount > 0 and m.viewMode = "hubGrid" and m.hubRowList <> invalid
                    m.focusArea = "hubs"
                    m.hubRowList.setFocus(true)
                    return true
                end if
            end if
        end if
    else if key = "left"
        if m.focusArea = "alphaNav"
            m.focusArea = "grid"
            focusGrid()
            return true
        else if m.focusArea = "hubs" and m.hubRowList <> invalid
            m.focusArea = "sidebar"
            focusSidebar()
            return true
        else if m.focusArea = "grid"
            m.focusArea = "sidebar"
            focusSidebar()
            return true
        end if
    else if key = "right"
        if m.focusArea = "sidebar"
            if m.hubRowCount > 0 and m.viewMode = "hubGrid" and m.hubRowList <> invalid
                m.focusArea = "hubs"
                m.hubRowList.setFocus(true)
                return true
            else
                m.focusArea = "grid"
                focusGrid()
                return true
            end if
        else if m.focusArea = "grid" and m.viewMode = "libraryOnly" and m.alphaNav.visible
            m.focusArea = "alphaNav"
            m.alphaNav.setFocus(true)
            return true
        end if
    else if key = "options"
        if m.viewMode = "libraryOnly" and not m.isSheetOpen and not m.isCollectionsView and not m.isPlaylistsView and m.collectionRatingKey = ""
            ' In library view, options key opens filter bottom sheet
            ' Create on demand to avoid firmware crash from complex initial tree
            if m.filterBottomSheet = invalid
                m.filterBottomSheet = CreateObject("roSGNode", "FilterBottomSheet")
                m.filterBottomSheet.observeField("filterState", "onBottomSheetFilterChanged")
                m.filterBottomSheet.observeField("sheetDismissed", "onSheetDismissed")
                m.filterBottomSheetContainer.appendChild(m.filterBottomSheet)
            end if
            m.filterBottomSheet.sectionId = m.currentSectionId
            m.filterBottomSheet.sectionType = m.currentSectionType
            m.filterBottomSheet.showSheet = true
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
            else if m.focusArea = "hubs" and m.hubRowList <> invalid
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
        if m.collectionRatingKey <> ""
            ' Return to collections list from collection contents
            m.collectionRatingKey = ""
            m.isCollectionsView = true
            m.currentOffset = 0
            loadCollections()
            return true
        else if m.isCollectionsView
            ' Return to library from collections list
            m.isCollectionsView = false
            m.currentOffset = 0
            m.filterBar.visible = true
            loadLibrary()
            return true
        else if m.isPlaylistsView
            ' Return to home view from playlists
            m.isPlaylistsView = false
            m.viewMode = "hubGrid"
            onViewModeChanged()
            m.focusArea = "sidebar"
            focusSidebar()
            return true
        else if m.focusArea <> "sidebar"
            ' Return to sidebar from any content area (hubs, grid, etc.)
            if m.viewMode = "libraryOnly"
                ' Return to hub/home view
                m.viewMode = "hubGrid"
                m.currentSectionId = ""
                onViewModeChanged()
            end if
            m.focusArea = "sidebar"
            focusSidebar()
            return true
        end if
        m.top.navigateBack = true
        return true
    end if

    return false
end function
