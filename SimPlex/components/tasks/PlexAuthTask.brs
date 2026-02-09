sub init()
    m.top.functionName = "run"
end sub

sub run()
    action = m.top.action
    if action = "requestPin"
        requestPin()
    else if action = "checkPin"
        checkPin()
    else if action = "fetchResources"
        fetchResources()
    end if
end sub

sub requestPin()
    m.top.state = "loading"

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://plex.tv/api/v2/pins")

    ' Add all Plex headers
    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    ' POST body
    url.AddHeader("Content-Type", "application/x-www-form-urlencoded")

    ' Make the request
    response = url.PostFromString("strong=true")

    if response = ""
        m.top.error = "Failed to contact plex.tv: " + url.GetFailureReason()
        m.top.state = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid response from plex.tv"
        m.top.state = "error"
        return
    end if

    ' Extract pin info
    if json.id <> invalid and json.code <> invalid
        m.top.pinId = json.id.ToStr()
        m.top.pinCode = json.code
        m.top.expiresAt = SafeGet(json, "expiresAt", "")
        LogEvent("PIN requested: " + m.top.pinCode)
        m.top.state = "pinReady"
    else
        m.top.error = "Missing pin data in response"
        m.top.state = "error"
    end if
end sub

sub checkPin()
    pinId = m.top.pinId
    if pinId = "" or pinId = invalid
        m.top.error = "No PIN ID provided"
        m.top.state = "error"
        return
    end if

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://plex.tv/api/v2/pins/" + pinId)

    ' Add all Plex headers
    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    ' Make GET request
    response = url.GetToString()

    if response = ""
        m.top.error = "Failed to check pin: " + url.GetFailureReason()
        m.top.state = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid response from plex.tv"
        m.top.state = "error"
        return
    end if

    ' Update expiration time
    m.top.expiresAt = SafeGet(json, "expiresAt", "")

    ' Check if PIN expired
    if SafeGet(json, "authToken", "") = "" and SafeGet(json, "expired", false) = true
        LogEvent("PIN expired, signaling refresh")
        m.top.state = "refreshing"
        return
    end if

    ' Check for auth token
    if json.authToken <> invalid and json.authToken <> ""
        m.top.authToken = json.authToken
        SetAuthToken(json.authToken)
        m.top.state = "authenticated"
    else if json.expiresAt <> invalid
        ' Still waiting
        m.top.state = "waiting"
    else
        m.top.state = "waiting"
    end if
end sub

sub fetchResources()
    m.top.state = "loading"
    LogEvent("Fetching server resources")

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl("https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1")

    headers = GetPlexHeaders()
    headers["X-Plex-Token"] = m.top.authToken
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    response = url.GetToString()

    if response = ""
        m.top.error = "Failed to fetch servers: " + url.GetFailureReason()
        m.top.state = "error"
        return
    end if

    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid server response"
        m.top.state = "error"
        return
    end if

    m.top.servers = parseServerList(json)
    LogEvent("Found " + m.top.servers.count().ToStr() + " server(s)")
    m.top.state = "serversReady"
end sub

function parseServerList(json as Object) as Object
    servers = []
    devices = SafeGet(json, "MediaContainer", invalid)
    if devices = invalid then devices = json  ' Handle v2 API format

    deviceList = SafeGet(devices, "Device", [])
    if type(deviceList) <> "roArray" then deviceList = []

    for each device in deviceList
        provides = SafeGet(device, "provides", "")
        ' Only include servers (not players, etc.)
        if Instr(1, provides, "server") > 0
            serverInfo = {
                name: SafeGet(device, "name", "Unknown Server")
                clientId: SafeGet(device, "clientIdentifier", "")
                version: SafeGet(device, "productVersion", "")
                connections: parseConnections(SafeGet(device, "Connection", []))
            }
            servers.push(serverInfo)
        end if
    end for

    return servers
end function

function parseConnections(connArray as Object) as Object
    result = { local: [], remote: [], relay: [] }

    if type(connArray) <> "roArray" then return result

    for each conn in connArray
        connInfo = {
            uri: SafeGet(conn, "uri", "")
            address: SafeGet(conn, "address", "")
            port: SafeGet(conn, "port", "32400")
            protocol: SafeGet(conn, "protocol", "http")
        }

        isLocal = SafeGet(conn, "local", "0") = "1" or SafeGet(conn, "local", 0) = 1
        isRelay = SafeGet(conn, "relay", "0") = "1" or SafeGet(conn, "relay", 0) = 1

        if isLocal
            result.local.push(connInfo)
        else if isRelay
            result.relay.push(connInfo)
        else
            result.remote.push(connInfo)
        end if
    end for

    return result
end function
