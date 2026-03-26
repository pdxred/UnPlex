' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.top.functionName = "run"
end sub

sub run()
    m.top.status = "loading"

    query = m.top.query
    if query = "" or query = invalid
        m.top.error = "No search query provided"
        m.top.status = "error"
        return
    end if

    ' Build search URL
    endpoint = "/hubs/search"
    requestUrl = BuildPlexUrl(endpoint)
    requestUrl = requestUrl + "&query=" + UrlEncode(query)
    requestUrl = requestUrl + "&limit=20"

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl(requestUrl)

    ' Add all Plex headers
    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    ' Make async GET request with timeout
    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)
    if not url.AsyncGetToString()
        m.top.error = "Failed to start search request"
        m.top.status = "error"
        return
    end if

    msg = wait(10000, port)
    if msg = invalid
        m.top.error = "Search request timed out"
        m.top.status = "error"
        return
    end if

    response = msg.GetString()

    if response = ""
        m.top.error = "Search failed: empty response"
        m.top.status = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid search response"
        m.top.status = "error"
        return
    end if

    m.top.response = json
    m.top.status = "completed"
end sub
