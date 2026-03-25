sub init()
    m.authGroup = m.top.findNode("authGroup")
    m.settingsGroup = m.top.findNode("settingsGroup")
    m.pinCodeLabel = m.top.findNode("pinCodeLabel")
    m.authStatus = m.top.findNode("authStatus")
    m.serverStatus = m.top.findNode("serverStatus")
    m.settingsList = m.top.findNode("settingsList")
    m.libraryList = m.top.findNode("libraryList")
    m.libraryHint = m.top.findNode("libraryHint")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.pinId = ""
    m.pollTimer = invalid
    m.isLibraryManager = false
    m.libraryManagerMoving = false
    m.libraryManagerMovingIndex = -1
    m.serverLibraries = []
    m.pinnedLibraries = []

    ' Set up auth task
    m.authTask = CreateObject("roSGNode", "PlexAuthTask")
    m.authTask.observeField("status", "onAuthTaskStateChange")

    ' Set up poll timer
    m.pollTimer = CreateObject("roSGNode", "Timer")
    m.pollTimer.duration = 3  ' Poll every 3 seconds
    m.pollTimer.repeat = true
    m.pollTimer.observeField("fire", "onPollTimer")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")

    ' Check if already authenticated
    token = GetAuthToken()
    serverUri = GetServerUri()

    if token <> "" and serverUri <> ""
        ' Show settings menu
        showSettingsMenu()
    else if token <> ""
        ' Have token but no server - do server discovery
        discoverServers()
    else
        ' Need to authenticate
        requestPin()
    end if
end sub

sub onFocusChange(event as Object)
    ' When SettingsScreen is in focus chain but no child has focus, delegate
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        if m.settingsGroup.visible
            if m.isLibraryManager and not m.libraryManagerMoving
                m.libraryList.setFocus(true)
            else if not m.libraryManagerMoving
                m.settingsList.setFocus(true)
            end if
        end if
    end if
end sub

sub showSettingsMenu()
    m.authGroup.visible = false
    m.settingsGroup.visible = true
    m.isLibraryManager = false
    m.settingsList.visible = true
    m.libraryList.visible = false
    m.libraryHint.visible = false

    content = CreateObject("roSGNode", "ContentNode")

    ' Show current user name and menu options
    userName = GetActiveUserName()
    items = ["Signed in as: " + userName, "Hub Libraries", "Sidebar Libraries", "Switch User", "Sign Out"]
    for each item in items
        node = content.createChild("ContentNode")
        node.title = item
    end for

    m.settingsList.content = content
    m.settingsList.observeField("itemSelected", "onSettingsItemSelected")
    m.settingsList.setFocus(true)
end sub

sub onLibraryListItemSelected(event as Object)
    ' Guard against double-fire (some Roku firmware fires itemSelected twice per OK press)
    now = CreateObject("roDateTime")
    nowMs = now.AsSeconds() * 1000 + now.GetMilliseconds()
    if m.lastLibSelectMs <> invalid and (nowMs - m.lastLibSelectMs) < 300
        return
    end if
    m.lastLibSelectMs = nowMs

    index = event.getData()
    onLibraryItemSelected(index)
end sub

sub onSettingsItemSelected(event as Object)
    index = event.getData()

    if index = 0
        ' Current user label - no action
        return
    else if index = 1
        ' Hub Libraries
        showLibraryManager("hub")
    else if index = 2
        ' Sidebar Libraries
        showLibraryManager("sidebar")
    else if index = 3
        ' Switch user
        m.top.itemSelected = { action: "switchUser" }
    else if index = 4
        ' Sign out
        signOut()
    end if
end sub

' ========== Hub Library Manager ==========

sub showLibraryManager(mode as String)
    m.isLibraryManager = true
    m.libraryManagerMode = mode
    m.libraryManagerMoving = false
    m.libraryManagerMovingIndex = -1

    ' Switch to MarkupList view
    m.settingsList.visible = false
    m.libraryList.visible = true
    m.libraryHint.visible = true
    m.libraryHint.text = "OK = toggle pin  |  Play = reorder  |  Back = return"

    ' Update title
    if mode = "sidebar"
        m.top.findNode("settingsTitle").text = "Sidebar Libraries"
    else
        m.top.findNode("settingsTitle").text = "Hub Libraries"
    end if

    ' Show loading state
    content = CreateObject("roSGNode", "ContentNode")
    node = content.createChild("ContentNode")
    node.title = "Loading libraries..."
    node.addFields({ isHeader: false, libKey: "", libTitle: "", isPinned: false, isMoving: false })
    m.libraryList.content = content
    m.libraryList.observeField("itemSelected", "onLibraryListItemSelected")
    m.libraryList.setFocus(true)

    ' Fetch server libraries
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/sections"
    task.params = {}
    task.observeField("status", "onLibManagerSectionsLoaded")
    task.control = "run"
    m.libManagerTask = task
end sub

sub onLibManagerSectionsLoaded(event as Object)
    if event.getData() <> "completed"
        content = CreateObject("roSGNode", "ContentNode")
        node = content.createChild("ContentNode")
        node.title = "Failed to load libraries"
        node.addFields({ isHeader: false, libKey: "", libTitle: "", isPinned: false, isMoving: false })
        m.libraryList.content = content
        return
    end if

    response = m.libManagerTask.response
    if response = invalid or response.MediaContainer = invalid or response.MediaContainer.Directory = invalid
        return
    end if

    ' Build list of server libraries
    m.serverLibraries = []
    for each dir in response.MediaContainer.Directory
        if m.libraryManagerMode = "sidebar"
            ' Sidebar only shows video libraries (movie/show)
            if dir.type = "movie" or dir.type = "show"
                m.serverLibraries.push({ key: dir.key, title: dir.title, libType: dir.type })
            end if
        else
            ' Hub libraries - show all
            m.serverLibraries.push({ key: dir.key, title: dir.title })
        end if
    end for

    ' Sort server libraries alphabetically
    for i = 1 to m.serverLibraries.count() - 1
        key = m.serverLibraries[i]
        j = i - 1
        while j >= 0 and LCase(m.serverLibraries[j].title) > LCase(key.title)
            m.serverLibraries[j + 1] = m.serverLibraries[j]
            j = j - 1
        end while
        m.serverLibraries[j + 1] = key
    end for

    ' Load current pinned state based on mode
    if m.libraryManagerMode = "sidebar"
        m.pinnedLibraries = GetSidebarLibraries()
    else
        m.pinnedLibraries = GetPinnedLibraries()
    end if

    refreshLibraryList()
end sub

sub refreshLibraryList()
    content = CreateObject("roSGNode", "ContentNode")

    ' Pinned section header
    if m.pinnedLibraries.count() > 0
        header = content.createChild("ContentNode")
        header.title = "PINNED TO HUB"
        header.addFields({ isHeader: true, libKey: "", libTitle: "", isPinned: false, isMoving: false })
    end if

    ' Pinned libraries in order
    for i = 0 to m.pinnedLibraries.count() - 1
        pinned = m.pinnedLibraries[i]
        isMoving = (m.libraryManagerMoving and m.libraryManagerMovingIndex = i)
        node = content.createChild("ContentNode")
        node.title = pinned.title
        node.addFields({ libKey: pinned.key, libTitle: pinned.title, isPinned: true, isMoving: isMoving, isHeader: false })
    end for

    ' Available section header
    unpinnedCount = countUnpinnedLibraries()
    if unpinnedCount > 0
        header = content.createChild("ContentNode")
        header.title = "AVAILABLE LIBRARIES"
        header.addFields({ isHeader: true, libKey: "", libTitle: "", isPinned: false, isMoving: false })
    end if

    ' Unpinned libraries
    for each lib in m.serverLibraries
        isPinned = false
        for each pinned in m.pinnedLibraries
            if pinned.key = lib.key
                isPinned = true
                exit for
            end if
        end for
        if not isPinned
            node = content.createChild("ContentNode")
            node.title = lib.title
            node.addFields({ libKey: lib.key, libTitle: lib.title, isPinned: false, isMoving: false, isHeader: false })
        end if
    end for

    m.libraryList.content = content

    ' Update hint text
    if m.libraryManagerMoving
        m.libraryHint.text = "UP/DOWN = move  |  OK = drop  |  Back = cancel"
        m.libraryHint.color = "0xF3B125FF"
    else
        m.libraryHint.text = "OK = toggle pin  |  Play = reorder  |  Back = return"
        m.libraryHint.color = "0x606070FF"
    end if
end sub

sub onLibraryItemSelected(index as Integer)
    ' Move mode OK is handled in onKeyEvent, not here
    if m.libraryManagerMoving then return

    ' Get the item from content
    item = m.libraryList.content.getChild(index)
    if item = invalid then return

    ' Skip header rows
    if item.isHeader then return

    libKey = item.libKey
    libTitle = item.libTitle

    if item.isPinned
        ' Unpin it
        newPinned = []
        for each p in m.pinnedLibraries
            if p.key <> libKey then newPinned.push(p)
        end for
        m.pinnedLibraries = newPinned
    else
        ' Pin it — but only if not already pinned (guard against double-fire)
        alreadyPinned = false
        for each existing in m.pinnedLibraries
            if existing.key = libKey
                alreadyPinned = true
                exit for
            end if
        end for
        if not alreadyPinned
            m.pinnedLibraries.push({ key: libKey, title: libTitle })
        end if
    end if

    savePinnedLibraries()
    savedIndex = index
    refreshLibraryList()
    m.libraryList.jumpToItem = savedIndex
end sub

sub savePinnedLibraries()
    if m.libraryManagerMode = "sidebar"
        SetSidebarLibraries(m.pinnedLibraries)
        m.global.sidebarNeedRefresh = true
    else
        SetPinnedLibraries(m.pinnedLibraries)
        m.global.hubsNeedRefresh = true
    end if
end sub

function countUnpinnedLibraries() as Integer
    count = 0
    for each lib in m.serverLibraries
        isPinned = false
        for each pinned in m.pinnedLibraries
            if pinned.key = lib.key
                isPinned = true
                exit for
            end if
        end for
        if not isPinned then count = count + 1
    end for
    return count
end function

sub moveLibraryItem(direction as Integer)
    if not m.libraryManagerMoving then return
    idx = m.libraryManagerMovingIndex
    newIdx = idx + direction

    if newIdx < 0 or newIdx >= m.pinnedLibraries.count() then return

    ' Swap
    temp = m.pinnedLibraries[idx]
    m.pinnedLibraries[idx] = m.pinnedLibraries[newIdx]
    m.pinnedLibraries[newIdx] = temp
    m.libraryManagerMovingIndex = newIdx

    refreshLibraryList()
    m.settingsList.jumpToItem = newIdx
end sub

sub signOut()
    ClearAuthData()

    ' Show auth screen
    m.settingsGroup.visible = false
    m.authGroup.visible = true
    requestPin()
end sub

sub requestPin()
    m.authStatus.text = "Requesting PIN..."
    m.authTask.action = "requestPin"
    m.authTask.control = "run"
end sub

sub onAuthTaskStateChange(event as Object)
    state = event.getData()

    if state = "pinReady"
        m.pinId = m.authTask.pinId
        m.pinCodeLabel.text = m.authTask.pinCode
        m.authStatus.text = "Waiting for authorization..."
        ' Start polling
        m.pollTimer.control = "start"

    else if state = "authenticated"
        m.pollTimer.control = "stop"
        m.authStatus.text = "Authenticated! Discovering servers..."
        discoverServers()

    else if state = "waiting"
        ' Still waiting, continue polling
        ' Timer will fire again

    else if state = "error"
        m.pollTimer.control = "stop"
        m.authStatus.text = "Error: " + m.authTask.error
        ' Retry after delay
        m.pollTimer.duration = 5
        m.pollTimer.repeat = false
        m.pollTimer.unobserveField("fire")
        m.pollTimer.observeField("fire", "requestPin")
        m.pollTimer.control = "start"
    end if
end sub

sub onPollTimer(event as Object)
    if m.pinId <> ""
        m.authTask.action = "checkPin"
        m.authTask.pinId = m.pinId
        m.authTask.control = "run"
    end if
end sub

sub discoverServers()
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.serverStatus.visible = true
    m.serverStatus.text = "Discovering servers..."

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "https://plex.tv/api/v2/resources"
    task.params = {
        "includeHttps": "1"
        "includeRelay": "1"
    }
    task.isPlexTvRequest = true
    task.observeField("status", "onDiscoverTaskStateChange")
    task.control = "run"
    m.discoverTask = task
end sub

sub onDiscoverTaskStateChange(event as Object)
    state = event.getData()

    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        processServerList()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.serverStatus.text = "Error discovering servers: " + m.discoverTask.error
    end if
end sub

sub processServerList()
    response = m.discoverTask.response
    if response = invalid or type(response) <> "roArray"
        m.serverStatus.text = "No servers found"
        return
    end if

    ' Find servers that provide video
    m.servers = []
    for each resource in response
        if resource.provides <> invalid and Instr(1, resource.provides, "server") > 0
            m.servers.push(resource)
        end if
    end for

    if m.servers.count() = 0
        m.serverStatus.text = "No Plex Media Servers found"
        return
    end if

    ' Try to connect to first server
    m.currentServerIndex = 0
    m.currentConnectionIndex = 0
    tryServerConnection()
end sub

sub tryServerConnection()
    if m.currentServerIndex >= m.servers.count()
        m.serverStatus.text = "Could not connect to any server"
        return
    end if

    server = m.servers[m.currentServerIndex]
    connections = server.connections
    if connections = invalid or m.currentConnectionIndex >= connections.count()
        ' Try next server
        m.currentServerIndex = m.currentServerIndex + 1
        m.currentConnectionIndex = 0
        tryServerConnection()
        return
    end if

    conn = connections[m.currentConnectionIndex]
    m.serverStatus.text = "Trying " + server.name + " (" + conn.uri + ")..."

    ' Test connection
    m.testUri = conn.uri
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = conn.uri + "/identity"
    task.params = {}
    task.isPlexTvRequest = false
    task.isConnectionTest = true
    task.observeField("status", "onConnectionTestComplete")
    task.control = "run"
    m.connectionTestTask = task
end sub

sub onConnectionTestComplete(event as Object)
    state = event.getData()
    if state = "completed"
        ' Connection successful
        SetServerUri(m.testUri)
        m.serverStatus.text = "Connected to " + m.servers[m.currentServerIndex].name
        ' Signal auth complete
        m.top.authComplete = true
    else
        ' Try next connection
        m.currentConnectionIndex = m.currentConnectionIndex + 1
        tryServerConnection()
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.isLibraryManager = true
        ' Header offset: pinned items start at index 1 (after "PINNED TO HUB" header)
        headerOffset = 0
        if m.pinnedLibraries.count() > 0 then headerOffset = 1

        if m.libraryManagerMoving
            ' Move mode: all keys handled here (MarkupList doesn't have focus)
            if key = "up" or key = "down"
                direction = -1
                if key = "down" then direction = 1
                moveLibraryItem(direction)
                return true
            else if key = "OK"
                ' Drop the item
                m.libraryManagerMoving = false
                idx = m.libraryManagerMovingIndex
                m.libraryManagerMovingIndex = -1
                savePinnedLibraries()
                refreshLibraryList()
                m.libraryList.setFocus(true)
                m.libraryList.jumpToItem = idx + headerOffset
                return true
            else if key = "back"
                ' Cancel move mode
                m.libraryManagerMoving = false
                m.libraryManagerMovingIndex = -1
                savePinnedLibraries()
                refreshLibraryList()
                m.libraryList.setFocus(true)
                return true
            end if
            return true
        end if

        if key = "back"
            ' Return to main settings
            m.isLibraryManager = false
            m.libraryList.unobserveField("itemSelected")
            m.top.findNode("settingsTitle").text = "Settings"
            showSettingsMenu()
            return true
        end if

        if key = "play"
            ' Enter move mode on a pinned item
            index = m.libraryList.itemFocused
            ' Convert list index to pinned array index (subtract header)
            pinnedIndex = index - headerOffset
            if pinnedIndex >= 0 and pinnedIndex < m.pinnedLibraries.count()
                m.libraryManagerMoving = true
                m.libraryManagerMovingIndex = pinnedIndex
                ' Take focus off MarkupList so up/down keys come to onKeyEvent
                m.settingsGroup.setFocus(true)
                refreshLibraryList()
                return true
            end if
        end if

        return false
    end if

    if key = "back"
        if m.settingsGroup.visible
            m.top.navigateBack = true
        end if
        return true
    end if

    return false
end function
