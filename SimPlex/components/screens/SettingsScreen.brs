sub init()
    m.authGroup = m.top.findNode("authGroup")
    m.settingsGroup = m.top.findNode("settingsGroup")
    m.pinCodeLabel = m.top.findNode("pinCodeLabel")
    m.authStatus = m.top.findNode("authStatus")
    m.serverStatus = m.top.findNode("serverStatus")
    m.settingsList = m.top.findNode("settingsList")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.pinId = ""
    m.pollTimer = invalid

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
            m.settingsList.setFocus(true)
        end if
    end if
end sub

sub showSettingsMenu()
    m.authGroup.visible = false
    m.settingsGroup.visible = true

    content = CreateObject("roSGNode", "ContentNode")

    items = ["Switch Server", "Sign Out"]
    for each item in items
        node = content.createChild("ContentNode")
        node.title = item
    end for

    m.settingsList.content = content
    m.settingsList.observeField("itemSelected", "onSettingsItemSelected")
    m.settingsList.setFocus(true)
end sub

sub onSettingsItemSelected(event as Object)
    index = event.getData()
    if index = 0
        ' Switch server
        discoverServers()
    else if index = 1
        ' Sign out
        signOut()
    end if
end sub

sub signOut()
    ' Clear stored credentials
    sec = CreateObject("roRegistrySection", "PlexClassic")
    sec.Delete("authToken")
    sec.Delete("serverUri")
    sec.Flush()

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
    m.loadingSpinner.visible = true
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
        m.loadingSpinner.visible = false
        processServerList()
    else if state = "error"
        m.loadingSpinner.visible = false
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

    if key = "back"
        if m.settingsGroup.visible
            m.top.navigateBack = true
        end if
        return true
    end if

    return false
end function
