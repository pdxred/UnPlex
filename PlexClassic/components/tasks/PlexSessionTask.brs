sub init()
    m.top.functionName = "run"
end sub

sub run()
    m.top.taskState = "loading"

    ' Build timeline URL
    serverUri = GetServerUri()
    token = GetAuthToken()
    deviceId = GetDeviceId()

    requestUrl = serverUri + "/:/timeline"
    requestUrl = requestUrl + "?ratingKey=" + m.top.ratingKey
    requestUrl = requestUrl + "&key=" + UrlEncode(m.top.mediaKey)
    requestUrl = requestUrl + "&state=" + m.top.state
    requestUrl = requestUrl + "&time=" + m.top.time.ToStr()
    requestUrl = requestUrl + "&duration=" + m.top.duration.ToStr()
    requestUrl = requestUrl + "&X-Plex-Client-Identifier=" + deviceId
    requestUrl = requestUrl + "&X-Plex-Token=" + token

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl(requestUrl)

    ' Add all Plex headers
    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    ' Make PUT request (using POST with method override as Roku doesn't support PUT directly)
    url.AddHeader("X-HTTP-Method-Override", "PUT")
    response = url.PostFromString("")

    if response = "" and url.GetResponseCode() <> 200
        m.top.error = "Timeline update failed: " + url.GetFailureReason()
        m.top.taskState = "error"
        return
    end if

    m.top.taskState = "completed"
end sub
