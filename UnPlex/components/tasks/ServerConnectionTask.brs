sub init()
    m.top.functionName = "testConnections"
end sub

sub testConnections()
    m.top.status = "testing"
    connections = m.top.connections
    authToken = m.top.authToken

    if connections = invalid
        m.top.error = "No connections provided"
        m.top.status = "error"
        return
    end if

    ' Build ordered test list: local first, then remote, then relay
    testOrder = []
    appendConnections(testOrder, connections.local, "local")
    appendConnections(testOrder, connections.remote, "remote")
    appendConnections(testOrder, connections.relay, "relay")

    if testOrder.count() = 0
        m.top.error = "No connections to test"
        m.top.status = "error"
        return
    end if

    LogEvent("Testing " + testOrder.count().ToStr() + " connections")

    for each conn in testOrder
        if testConnection(conn, authToken)
            LogEvent("Connection successful: " + conn.type + " - " + conn.uri)
            m.top.successfulUri = conn.uri
            m.top.connectionType = conn.type
            m.top.status = "connected"
            return
        end if
        LogEvent("Connection failed: " + conn.type + " - " + conn.uri)

        ' Fallback: if the URI uses plex.direct, try direct IP instead
        ' plex.direct DNS or certs may not work on all networks
        if conn.address <> "" and Instr(1, conn.uri, "plex.direct") > 0
            directUri = conn.protocol + "://" + conn.address + ":" + conn.port
            directConn = { uri: directUri, address: conn.address, port: conn.port, protocol: conn.protocol, type: conn.type }
            if testConnection(directConn, authToken)
                LogEvent("Connection successful (direct IP): " + conn.type + " - " + directUri)
                m.top.successfulUri = directUri
                m.top.connectionType = conn.type
                m.top.status = "connected"
                return
            end if
            LogEvent("Connection failed (direct IP): " + conn.type + " - " + directUri)
        end if
    end for

    ' All failed
    m.top.error = "All connection attempts failed"
    m.top.status = "error"
    LogError("All " + testOrder.count().ToStr() + " connection attempts failed")
end sub

sub appendConnections(testOrder as Object, connArray as Object, connType as String)
    if connArray = invalid or type(connArray) <> "roArray" then return
    for each conn in connArray
        testOrder.push({
            uri: SafeGet(conn, "uri", "")
            address: SafeGet(conn, "address", "")
            port: SafeGet(conn, "port", "32400")
            protocol: SafeGet(conn, "protocol", "https")
            type: connType
        })
    end for
end sub

function testConnection(conn as Object, authToken as String) as Boolean
    if conn.uri = "" then return false

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl(conn.uri + "/")

    ' Set timeout based on connection type
    ' Local: 3 seconds, Remote/Relay: 5 seconds
    timeout = 5000
    if conn.type = "local" then timeout = 3000

    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)
    url.EnableEncodings(true)

    headers = GetPlexHeaders()
    headers["X-Plex-Token"] = authToken
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    ' Async request with timeout
    if not url.AsyncGetToString()
        return false
    end if

    msg = wait(timeout, port)
    if type(msg) = "roUrlEvent"
        responseCode = msg.GetResponseCode()
        if responseCode = 200
            return true
        else if responseCode = 401
            ' Token invalid but server reachable - still counts as reachable
            ' 401 will be handled by global auth observer
            return true
        end if
    end if

    return false
end function
