sub init()
    m.serverList = m.top.findNode("serverList")
    m.spinner = m.top.findNode("spinner")
    m.statusLabel = m.top.findNode("statusLabel")
    m.errorLabel = m.top.findNode("errorLabel")

    m.top.observeField("servers", "onServersChanged")
    m.serverList.observeField("itemSelected", "onServerSelected")

    m.connectionTask = invalid
    m.serverData = []
    m.selectedServerIndex = invalid
end sub

sub onServersChanged(event as Object)
    servers = m.top.servers
    if servers = invalid or servers.count() = 0
        m.errorLabel.visible = true
        m.errorLabel.text = "No servers found"
        LogError("No servers available for selection")
        return
    end if

    ' Build ContentNode for LabelList
    content = CreateObject("roSGNode", "ContentNode")
    m.serverData = []
    for each server in servers
        item = content.CreateChild("ContentNode")
        item.title = server.name
        m.serverData.push(server)
    end for
    m.serverList.content = content

    ' Set focus to server list
    m.serverList.setFocus(true)

    ' Auto-select if only 1 server
    if servers.count() = 1
        LogEvent("Auto-selecting single server: " + servers[0].name)
        selectServer(0)
    end if
end sub

sub onServerSelected(event as Object)
    index = event.getData()
    selectServer(index)
end sub

sub selectServer(index as Integer)
    if index < 0 or index >= m.serverData.count() then return

    server = m.serverData[index]
    m.selectedServerIndex = index
    m.top.selectedServer = server

    ' Store server clientId for future reconnection
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Write("serverClientId", server.clientId)
    sec.Flush()

    LogEvent("Selected server: " + server.name)

    ' Start connection testing
    startConnectionTest(server)
end sub

sub startConnectionTest(server as Object)
    m.spinner.visible = true
    m.statusLabel.visible = true
    m.statusLabel.text = "Testing connection to " + server.name + "..."
    m.errorLabel.visible = false

    ' Stop any existing test
    if m.connectionTask <> invalid
        m.connectionTask.control = "stop"
    end if

    m.connectionTask = CreateObject("roSGNode", "ServerConnectionTask")
    m.connectionTask.connections = server.connections
    m.connectionTask.authToken = m.top.authToken
    m.connectionTask.observeField("status", "onConnectionStateChange")
    m.connectionTask.control = "run"
end sub

sub onConnectionStateChange(event as Object)
    state = event.getData()

    if state = "connected"
        m.spinner.visible = false
        m.statusLabel.text = "Connected via " + m.connectionTask.connectionType

        serverUri = m.connectionTask.successfulUri
        m.top.serverUri = serverUri

        ' Persist server URI
        SetServerUri(serverUri)
        LogEvent("Server URI saved: " + serverUri)

        m.top.state = "connected"

    else if state = "error"
        m.spinner.visible = false
        m.errorLabel.visible = true
        m.errorLabel.text = m.connectionTask.error
        m.statusLabel.text = "Connection failed"

        ' Mark server in list as unreachable (update item text)
        if m.selectedServerIndex <> invalid
            item = m.serverList.content.getChild(m.selectedServerIndex)
            item.title = m.serverData[m.selectedServerIndex].name + " (unreachable)"
        end if

        LogError("Server connection failed: " + m.connectionTask.error)
        ' Return focus to list so user can try another server
        m.serverList.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    if key = "back"
        ' Allow back to cancel if not mid-connection-test
        if m.connectionTask <> invalid
            m.connectionTask.control = "stop"
        end if
        m.top.state = "cancelled"
        return true
    end if

    return false
end function
