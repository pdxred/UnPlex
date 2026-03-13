sub init()
    ' Cache constants in m.global for all components to access
    m.global.addFields({ constants: GetConstants() })

    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    m.focusStack = []

    ' Initialize global auth fields
    m.global.addFields({ authRequired: false })
    m.global.observeField("authRequired", "onAuthRequired")

    ' Initialize global server disconnect/reconnect fields
    m.global.addFields({ serverUnreachable: false })
    m.global.addFields({ serverReconnected: false })

    ' Watch state updates propagated from DetailScreen to grid screens
    m.global.addFields({ watchStateUpdate: {} })

    ' Signal to refresh hub rows and sidebar (set by SettingsScreen after pin changes)
    m.global.addFields({ hubsNeedRefresh: false })
    m.global.addFields({ sidebarNeedRefresh: false })
    m.global.observeField("serverUnreachable", "onServerUnreachable")

    ' Observe showSignOut field
    m.top.observeField("showSignOut", "onShowSignOut")

    ' Check authentication status on launch
    checkAuthAndRoute()
end sub

sub checkAuthAndRoute()
    token = GetAuthToken()
    serverUri = GetServerUri()

    if token = "" or serverUri = ""
        ' No credentials - show PIN screen
        LogEvent("No stored credentials, showing PIN screen")
        showPINScreen()
    else
        ' Have credentials - verify server is reachable
        LogEvent("Found stored credentials, attempting connection")
        ' For now, trust stored credentials and show home
        ' Server reachability will be validated on first API call
        ' If 401, onAuthRequired will trigger
        showHomeScreen()
    end if
end sub

sub showPINScreen()
    ' Clear any existing screens
    clearScreenStack()

    ' Create and show PIN screen
    pinScreen = CreateObject("roSGNode", "PINScreen")
    pinScreen.observeField("state", "onPINScreenState")
    pushScreen(pinScreen)
end sub

sub onPINScreenState(event as Object)
    state = event.getData()

    if state = "authenticated"
        ' PIN auth complete, get servers from PIN screen
        pinScreen = getCurrentScreen()
        servers = pinScreen.servers
        authToken = pinScreen.authToken

        if servers <> invalid and servers.count() > 1
            ' Multiple servers - show selection
            showServerListScreen(servers, authToken)
        else if servers <> invalid and servers.count() = 1
            ' Single server - auto-connect
            autoConnectToServer(servers[0], authToken)
        else
            ' No servers found (unusual)
            LogError("No servers found after authentication")
            ' Stay on PIN screen with error? Or show error screen?
        end if

    else if state = "cancelled"
        ' User cancelled - if we have credentials, go home; otherwise stay
        if GetAuthToken() <> "" and GetServerUri() <> ""
            popScreen()
            showHomeScreen()
        end if
    end if
end sub

sub showServerListScreen(servers as Object, authToken as String)
    clearScreenStack()

    serverScreen = CreateObject("roSGNode", "ServerListScreen")
    serverScreen.servers = servers
    serverScreen.authToken = authToken
    serverScreen.observeField("state", "onServerListState")
    pushScreen(serverScreen)
end sub

sub onServerListState(event as Object)
    state = event.getData()

    if state = "connected"
        LogEvent("Server connected, showing home")
        clearScreenStack()
        showHomeScreen()
    else if state = "cancelled"
        ' Go back to PIN screen
        showPINScreen()
    end if
end sub

sub autoConnectToServer(server as Object, authToken as String)
    ' For single server, test connection then proceed
    m.connectionTask = CreateObject("roSGNode", "ServerConnectionTask")
    m.connectionTask.connections = server.connections
    m.connectionTask.authToken = authToken
    m.connectionTask.observeField("status", "onAutoConnectState")
    m.connectionTask.control = "run"

    ' Save server clientId while testing
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Write("serverClientId", server.clientId)
    sec.Flush()
end sub

sub onAutoConnectState(event as Object)
    state = event.getData()

    if state = "connected"
        SetServerUri(m.connectionTask.successfulUri)
        LogEvent("Auto-connected to server")
        clearScreenStack()
        showHomeScreen()
    else if state = "error"
        LogError("Auto-connect failed: " + m.connectionTask.error)
        ' Show error - server unreachable
        ' Could show a "Can't reach server" screen with retry
        ' For now, show PIN screen again (user can retry auth)
        showPINScreen()
    end if
end sub

sub onAuthRequired(event as Object)
    required = event.getData()

    if required = true
        LogEvent("Auth required signal received, showing PIN screen")
        ' Reset the flag
        m.global.authRequired = false
        ' Show PIN screen
        showPINScreen()
    end if
end sub

sub onShowSignOut(event as Object)
    if event.getData() = true
        m.top.showSignOut = false  ' Reset
        signOut()
    end if
end sub

sub signOut()
    LogEvent("User signed out")
    ClearAuthData()
    showPINScreen()
end sub

sub showHomeScreen()
    screen = CreateObject("roSGNode", "HomeScreen")
    pushScreen(screen)
    m.top.currentScreen = "home"
end sub

sub showSettingsScreen()
    screen = CreateObject("roSGNode", "SettingsScreen")
    screen.observeField("authComplete", "onAuthComplete")
    pushScreen(screen)
    m.top.currentScreen = "settings"
end sub

sub showDetailScreen(ratingKey as String, itemType as String)
    screen = CreateObject("roSGNode", "DetailScreen")
    screen.ratingKey = ratingKey
    screen.itemType = itemType
    pushScreen(screen)
    m.top.currentScreen = "detail"
end sub

sub showEpisodeScreen(ratingKey as String, showTitle as String)
    screen = CreateObject("roSGNode", "EpisodeScreen")
    screen.ratingKey = ratingKey
    screen.showTitle = showTitle
    pushScreen(screen)
    m.top.currentScreen = "episodes"
end sub

sub showSearchScreen()
    screen = CreateObject("roSGNode", "SearchScreen")
    pushScreen(screen)
    m.top.currentScreen = "search"
end sub

sub showUserPickerScreen()
    screen = CreateObject("roSGNode", "UserPickerScreen")
    screen.observeField("userSwitched", "onUserSwitched")
    pushScreen(screen)
    m.top.currentScreen = "userPicker"
end sub

sub onUserSwitched(event as Object)
    if event.getData() = true
        ' User switch successful - reset everything
        clearScreenStack()
        showHomeScreen()
    end if
end sub

sub showPlaylistScreen(ratingKey as String, title as String)
    screen = CreateObject("roSGNode", "PlaylistScreen")
    screen.ratingKey = ratingKey
    screen.playlistTitle = title
    pushScreen(screen)
    m.top.currentScreen = "playlist"
end sub

sub showPostPlayScreen(data as Object)
    screen = CreateObject("roSGNode", "PostPlayScreen")
    if data.itemTitle <> invalid
        screen.itemTitle = data.itemTitle
    end if
    if data.ratingKey <> invalid
        screen.ratingKey = data.ratingKey
    end if
    if data.grandparentRatingKey <> invalid
        screen.grandparentRatingKey = data.grandparentRatingKey
    end if
    screen.hasNextEpisode = (data.hasNextEpisode = true)
    if data.nextEpisodeInfo <> invalid
        screen.nextEpisodeInfo = data.nextEpisodeInfo
    end if
    if data.viewOffset <> invalid
        screen.viewOffset = data.viewOffset
    end if
    if data.duration <> invalid
        screen.duration = data.duration
    end if
    if data.isPlaylist <> invalid
        screen.isPlaylist = data.isPlaylist
    end if
    screen.observeField("action", "onPostPlayAction")
    screen.observeField("navigateBack", "onNavigateBack")
    pushScreen(screen)
    m.top.currentScreen = "postPlay"
end sub

sub onPostPlayAction(event as Object)
    action = event.getData()
    if action = invalid or action = "" then return

    if action = "playNext"
        ' Get next episode info before popping screen
        postPlayScreen = getCurrentScreen()
        nextInfo = invalid
        if postPlayScreen <> invalid and postPlayScreen.nextEpisodeInfo <> invalid
            nextInfo = postPlayScreen.nextEpisodeInfo
        end if
        popScreen()
        ' Navigate to the next episode's detail screen
        if nextInfo <> invalid
            showDetailScreen(nextInfo.ratingKey, "episode")
        end if
    else if action = "replay"
        ' Pop PostPlayScreen — calling screen is restored with Play button visible
        popScreen()
    else if action = "backToLibrary"
        ' Pop all screens back to HomeScreen
        while m.screenStack.count() > 1
            currentScreen = m.screenStack.pop()
            cleanupScreen(currentScreen)
            m.screenContainer.removeChild(currentScreen)
        end while
        m.focusStack.clear()
        ' Restore the home screen
        homeScreen = m.screenStack.peek()
        if homeScreen <> invalid
            homeScreen.visible = true
            homeScreen.setFocus(true)
        end if
        m.top.currentScreen = "home"
    else if action = "playFromTimestamp"
        ' Pop PostPlayScreen — calling screen is restored
        popScreen()
    end if
end sub

sub cleanupScreen(screen as Object)
    ' Unobserve all standard screen fields
    screen.unobserveField("itemSelected")
    screen.unobserveField("navigateBack")
    screen.unobserveField("state")
    screen.unobserveField("userSwitched")

    ' Optional: Call screen's own cleanup if it exists
    if screen.hasField("cleanup")
        screen.callFunc("cleanup")
    end if
end sub

sub clearScreenStack()
    ' Remove all screens
    while m.screenStack.count() > 0
        screen = m.screenStack.pop()
        cleanupScreen(screen)
        m.screenContainer.removeChild(screen)
    end while
    m.focusStack.clear()
end sub

sub pushScreen(screen as Object)
    ' Store current focus position before pushing (get deepest focused element)
    if m.screenStack.count() > 0
        currentScreen = m.screenStack.peek()
        focusedNode = getDeepFocusedChild(currentScreen)
        m.focusStack.push(focusedNode)
        currentScreen.visible = false
    end if

    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    screen.setFocus(true)

    ' Observe screen events
    screen.observeField("itemSelected", "onItemSelected")
    screen.observeField("navigateBack", "onNavigateBack")
end sub

function getDeepFocusedChild(node as Object) as Object
    ' Recursively find the deepest focused element
    if node = invalid then return invalid

    child = node.focusedChild
    if child <> invalid and child.isSameNode(node) = false
        return getDeepFocusedChild(child)
    else if node.hasFocus()
        return node
    else
        return invalid
    end if
end function

sub popScreen()
    if m.screenStack.count() <= 1
        ' Show exit confirmation on last screen
        showExitDialog()
        return
    end if

    ' Remove current screen
    currentScreen = m.screenStack.pop()
    cleanupScreen(currentScreen)
    m.screenContainer.removeChild(currentScreen)

    ' Restore previous screen
    previousScreen = m.screenStack.peek()
    previousScreen.visible = true

    ' Restore focus
    if m.focusStack.count() > 0
        savedFocus = m.focusStack.pop()
        if savedFocus <> invalid
            savedFocus.setFocus(true)
        else
            previousScreen.setFocus(true)
        end if
    else
        previousScreen.setFocus(true)
    end if

    ' Update current screen name
    if previousScreen.subtype() = "HomeScreen"
        m.top.currentScreen = "home"
    else if previousScreen.subtype() = "DetailScreen"
        m.top.currentScreen = "detail"
    else if previousScreen.subtype() = "EpisodeScreen"
        m.top.currentScreen = "episodes"
    else if previousScreen.subtype() = "SearchScreen"
        m.top.currentScreen = "search"
    else if previousScreen.subtype() = "SettingsScreen"
        m.top.currentScreen = "settings"
    else if previousScreen.subtype() = "PlaylistScreen"
        m.top.currentScreen = "playlist"
    else if previousScreen.subtype() = "UserPickerScreen"
        m.top.currentScreen = "userPicker"
    else if previousScreen.subtype() = "PINScreen"
        m.top.currentScreen = "pin"
    else if previousScreen.subtype() = "PostPlayScreen"
        m.top.currentScreen = "postPlay"
    end if
end sub

function getCurrentScreen() as Object
    if m.screenStack.count() > 0
        return m.screenStack.peek()
    end if
    return invalid
end function

sub showExitDialog()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Exit SimPlex?"
    dialog.message = ["Are you sure you want to exit?"]
    dialog.buttons = ["Exit", "Cancel"]
    dialog.observeField("buttonSelected", "onExitDialogButton")
    m.top.dialog = dialog
end sub

sub onExitDialogButton(event as Object)
    buttonIndex = event.getData()
    m.top.dialog.close = true
    if buttonIndex = 0
        ' User selected Exit
        m.top.close = true
    end if
end sub

sub onAuthComplete(event as Object)
    ' Auth completed successfully, refresh global state and show home
    m.global.authToken = GetAuthToken()
    m.global.serverUri = GetServerUri()

    ' Remove settings screen and show home
    clearScreenStack()
    showHomeScreen()
end sub

sub onItemSelected(event as Object)
    data = event.getData()
    if data <> invalid
        if data.action = "play"
            ' Resume playback - route to detail screen until VideoPlayer is wired
            showDetailScreen(data.ratingKey, data.itemType)
        else if data.action = "detail"
            showDetailScreen(data.ratingKey, data.itemType)
        else if data.action = "episodes"
            showEpisodeScreen(data.ratingKey, data.title)
        else if data.action = "search"
            showSearchScreen()
        else if data.action = "playlist"
            showPlaylistScreen(data.ratingKey, data.title)
        else if data.action = "switchUser"
            showUserPickerScreen()
        else if data.action = "settings"
            showSettingsScreen()
        else if data.action = "postPlay"
            showPostPlayScreen(data)
        end if
    end if
end sub

sub onNavigateBack(event as Object)
    popScreen()
end sub

' ========== Server Disconnect / Reconnect ==========

sub onServerUnreachable(event as Object)
    if event.getData() <> true then return

    ' Reset flag to prevent duplicate triggers
    m.global.serverUnreachable = false

    ' Don't show disconnect dialog during playback
    currentScreen = getCurrentScreen()
    if currentScreen <> invalid and currentScreen.subtype() = "VideoPlayer" then return

    ' Don't show if a dialog is already open
    if m.top.dialog <> invalid then return

    ' Silent background connectivity test first
    testServerConnectivity()
end sub

sub testServerConnectivity()
    serverUri = GetServerUri()
    if serverUri = "" then return

    m.reconnectTask = CreateObject("roSGNode", "ServerConnectionTask")

    ' Build a simple connections object with just the current server URI
    connections = { local: [], remote: [{ uri: serverUri }], relay: [] }
    m.reconnectTask.connections = connections
    m.reconnectTask.authToken = GetAuthToken()
    m.reconnectTask.observeField("status", "onReconnectTestResult")
    m.reconnectTask.control = "run"
end sub

sub onReconnectTestResult(event as Object)
    state = event.getData()

    if state = "connected"
        ' Server is back - signal screens to re-fetch
        m.global.serverReconnected = true
    else if state = "error"
        ' Server still down - show disconnect dialog
        showServerDisconnectDialog()
    end if
end sub

sub showServerDisconnectDialog()
    if m.top.dialog <> invalid then return

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Server Unreachable"
    dialog.message = ["Can't connect to your Plex server. Check your network connection and try again."]
    dialog.buttons = ["Try Again", "Server List"]
    dialog.observeField("buttonSelected", "onDisconnectDialogButton")
    dialog.observeField("wasClosed", "onDisconnectDialogClosed")
    m.top.dialog = dialog
end sub

sub onDisconnectDialogButton(event as Object)
    index = event.getData()
    m.top.dialog.close = true

    if index = 0
        ' Try Again - re-test connectivity
        testServerConnectivity()
    else if index = 1
        ' Server List - navigate to server selection
        navigateToServerList()
    end if
end sub

sub onDisconnectDialogClosed(event as Object)
    ' Restore focus to current screen
    currentScreen = getCurrentScreen()
    if currentScreen <> invalid
        currentScreen.setFocus(true)
    end if
end sub

sub navigateToServerList()
    ' Pop all screens and show server list
    ' Need auth token and servers from plex.tv
    clearScreenStack()

    ' Fetch servers from plex.tv
    m.serverFetchTask = CreateObject("roSGNode", "PlexApiTask")
    m.serverFetchTask.isPlexTvRequest = true
    m.serverFetchTask.endpoint = "https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1"
    m.serverFetchTask.observeField("status", "onServerFetchForList")
    m.serverFetchTask.control = "run"
end sub

sub onServerFetchForList(event as Object)
    state = event.getData()
    if state = "completed"
        servers = m.serverFetchTask.response
        if servers <> invalid
            showServerListScreen(servers, GetAuthToken())
        else
            ' Fallback to PIN screen if can't fetch servers
            showPINScreen()
        end if
    else
        ' Can't reach plex.tv either - show PIN screen
        showPINScreen()
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        popScreen()
        return true
    end if

    return false
end function
