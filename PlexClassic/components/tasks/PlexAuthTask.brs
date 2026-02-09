sub init()
    m.top.functionName = "run"
end sub

sub run()
    action = m.top.action
    if action = "requestPin"
        requestPin()
    else if action = "checkPin"
        checkPin()
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

    ' Check for auth token
    if json.authToken <> invalid and json.authToken <> ""
        m.top.authToken = json.authToken
        SetAuthToken(json.authToken)
        m.top.state = "authenticated"
    else if json.expiresAt <> invalid
        ' Check if expired - for now just mark as waiting
        m.top.state = "waiting"
    else
        m.top.state = "waiting"
    end if
end sub
