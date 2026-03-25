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
    m.top.status = "loading"

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

    ' Use async POST to get response body
    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)
    if not url.AsyncPostFromString("strong=false")
        m.top.error = "Failed to start PIN request"
        m.top.status = "error"
        return
    end if

    ' Wait for response
    msg = wait(10000, port)
    if msg = invalid
        m.top.error = "PIN request timed out"
        m.top.status = "error"
        return
    end if

    responseCode = msg.GetResponseCode()
    response = msg.GetString()

    if responseCode < 200 or responseCode >= 300
        m.top.error = "Failed to contact plex.tv: HTTP " + responseCode.ToStr()
        m.top.status = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid response from plex.tv"
        m.top.status = "error"
        return
    end if

    ' Extract pin info
    if json.id <> invalid and json.code <> invalid
        m.top.pinId = json.id.ToStr()
        m.top.pinCode = json.code
        m.top.expiresAt = SafeGet(json, "expiresAt", "")
        LogEvent("PIN requested: " + m.top.pinCode)
        m.top.status = "pinReady"
    else
        m.top.error = "Missing pin data in response"
        m.top.status = "error"
    end if
end sub

sub checkPin()
    pinId = m.top.pinId
    if pinId = "" or pinId = invalid
        m.top.error = "No PIN ID provided"
        m.top.status = "error"
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
        m.top.status = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid response from plex.tv"
        m.top.status = "error"
        return
    end if

    ' Update expiration time
    m.top.expiresAt = SafeGet(json, "expiresAt", "")

    ' Check if PIN expired
    if SafeGet(json, "authToken", "") = "" and SafeGet(json, "expired", false) = true
        LogEvent("PIN expired, signaling refresh")
        m.top.status = "refreshing"
        return
    end if

    ' Check for auth token
    if json.authToken <> invalid and json.authToken <> ""
        m.top.authToken = json.authToken
        SetAuthToken(json.authToken)
        m.top.status = "authenticated"
    else if json.expiresAt <> invalid
        ' Still waiting
        m.top.status = "waiting"
    else
        m.top.status = "waiting"
    end if
end sub

sub fetchResources()
    m.top.status = "loading"
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

    ' Use async request with timeout to avoid hanging forever
    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)
    if not url.AsyncGetToString()
        m.top.error = "Failed to start server fetch"
        m.top.status = "error"
        return
    end if

    msg = wait(15000, port)
    if msg = invalid
        m.top.error = "Server fetch timed out"
        m.top.status = "error"
        return
    end if

    response = msg.GetString()

    if msg.GetResponseCode() < 200 or msg.GetResponseCode() >= 300
        m.top.error = "Failed to fetch servers: HTTP " + msg.GetResponseCode().ToStr()
        m.top.status = "error"
        return
    end if

    if response = ""
        m.top.error = "Empty response from plex.tv"
        m.top.status = "error"
        return
    end if

    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid server response"
        m.top.status = "error"
        return
    end if

    m.top.servers = parseServerList(json)
    LogEvent("Found " + m.top.servers.count().ToStr() + " server(s)")
    m.top.status = "serversReady"
end sub

function parseServerList(json as Object) as Object
    servers = []

    ' v2 API returns direct array of resources
    deviceList = []
    if type(json) = "roArray"
        deviceList = json
    else
        ' Fallback for older API formats
        devices = SafeGet(json, "MediaContainer", json)
        deviceList = SafeGet(devices, "Device", [])
        if type(deviceList) <> "roArray" then deviceList = []
    end if

    for each device in deviceList
        provides = SafeGet(device, "provides", "")
        ' Only include servers (not players, etc.)
        if Instr(1, provides, "server") > 0
            serverInfo = {
                name: SafeGet(device, "name", "Unknown Server")
                clientId: SafeGet(device, "clientIdentifier", "")
                version: SafeGet(device, "productVersion", "")
                connections: parseConnections(SafeGet(device, "connections", []))
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

        ' v2 API returns boolean, older APIs may return string/int
        localVal = SafeGet(conn, "local", false)
        if type(localVal) = "Boolean"
            isLocal = localVal
        else
            isLocal = (localVal = "1" or localVal = 1 or localVal = true)
        end if

        relayVal = SafeGet(conn, "relay", false)
        if type(relayVal) = "Boolean"
            isRelay = relayVal
        else
            isRelay = (relayVal = "1" or relayVal = 1 or relayVal = true)
        end if

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
