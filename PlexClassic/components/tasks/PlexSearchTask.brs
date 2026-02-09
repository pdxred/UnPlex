sub init()
    m.top.functionName = "run"
end sub

sub run()
    m.top.state = "loading"

    query = m.top.query
    if query = "" or query = invalid
        m.top.error = "No search query provided"
        m.top.state = "error"
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

    ' Make GET request
    response = url.GetToString()

    if response = ""
        m.top.error = "Search failed: " + url.GetFailureReason()
        m.top.state = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        m.top.error = "Invalid search response"
        m.top.state = "error"
        return
    end if

    m.top.response = json
    m.top.state = "completed"
end sub
