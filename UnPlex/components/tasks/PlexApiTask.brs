' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.top.functionName = "run"
end sub

sub run()
    m.top.status = "loading"

    endpoint = m.top.endpoint
    params = m.top.params
    if params = invalid then params = {}

    method = m.top.method
    if method = "" then method = "GET"

    ' Log request start
    LogEvent("API request: " + method + " " + endpoint)

    ' Build URL
    if m.top.isPlexTvRequest
        ' Direct URL to plex.tv
        requestUrl = endpoint
    else if m.top.isConnectionTest
        ' Direct URL for connection testing
        requestUrl = endpoint
    else
        ' Build PMS URL
        requestUrl = BuildPlexUrl(endpoint)
    end if

    ' Add params to URL
    for each key in params
        separator = "?"
        if Instr(1, requestUrl, "?") > 0 then separator = "&"
        requestUrl = requestUrl + separator + key + "=" + params[key]
    end for

    url = CreateObject("roUrlTransfer")
    url.SetCertificatesFile("common:/certs/ca-bundle.crt")
    url.InitClientCertificates()
    url.SetUrl(requestUrl)

    ' Add all Plex headers
    headers = GetPlexHeaders()
    for each key in headers
        url.AddHeader(key, headers[key])
    end for

    ' Add auth token for plex.tv requests
    if m.top.isPlexTvRequest
        ' Use override token if provided, otherwise active token
        token = m.top.authTokenOverride
        if token = "" then token = GetAuthToken()
        if token <> ""
            url.AddHeader("X-Plex-Token", token)
        end if
    end if

    ' Use async for all requests to get response code
    port = CreateObject("roMessagePort")
    url.SetMessagePort(port)

    ' Make request based on method
    if method = "POST"
        ' Add Content-Type header for POST
        url.AddHeader("Content-Type", "application/json")

        ' Encode body as JSON
        body = m.top.body
        if body = invalid then body = {}
        bodyJson = FormatJson(body)

        if not url.AsyncPostFromString(bodyJson)
            m.top.error = "Failed to start POST request"
            m.top.status = "error"
            return
        end if
    else if method = "PUT"
        ' PUT via method override (Roku doesn't support PUT directly)
        ' Same pattern as PlexSessionTask
        url.AddHeader("X-HTTP-Method-Override", "PUT")

        if not url.AsyncPostFromString("")
            m.top.error = "Failed to start PUT request"
            m.top.status = "error"
            return
        end if
    else if method = "DELETE"
        ' DELETE via method override (Roku doesn't support DELETE directly)
        url.AddHeader("X-HTTP-Method-Override", "DELETE")

        if not url.AsyncPostFromString("")
            m.top.error = "Failed to start DELETE request"
            m.top.status = "error"
            return
        end if
    else
        ' Default to GET
        if not url.AsyncGetToString()
            m.top.error = "Failed to start GET request"
            m.top.status = "error"
            return
        end if
    end if

    ' Wait for response (30 second timeout)
    msg = wait(30000, port)
    if msg = invalid
        m.top.error = "Request timed out"
        m.top.status = "error"
        return
    end if

    ' Get response code and body from message
    responseCode = msg.GetResponseCode()
    response = msg.GetString()
    m.top.responseCode = responseCode

    ' Check for 401 Unauthorized (token expired/invalid)
    if responseCode = 401
        if m.top.suppress401
            ' Caller handles 401 (e.g., wrong PIN for managed user switch)
            LogEvent("401 suppressed by caller")
            m.top.error = "Unauthorized"
            m.top.status = "error"
            return
        end if
        LogError("401 Unauthorized - authentication required")
        ' Clear the stored token since it's invalid
        SetAuthToken("")
        ' Signal auth required via global
        m.global.addFields({ authRequired: true })
        m.global.authRequired = true
        m.top.error = "Authentication required"
        m.top.status = "authRequired"
        return
    end if

    if responseCode < 0
        errorMsg = "Request failed: " + url.GetFailureReason()
        LogError("API error: " + errorMsg)
        m.top.error = errorMsg
        m.top.status = "error"
        return
    end if

    ' Treat other HTTP errors (403, 404, 500, etc.) as errors
    if responseCode >= 400
        errorMsg = "HTTP error " + responseCode.ToStr() + " from " + endpoint
        LogError("API error: " + errorMsg)
        m.top.error = errorMsg
        m.top.status = "error"
        return
    end if

    ' Some endpoints (scrobble, unscrobble, timeline) return empty 200 responses
    if response = "" and responseCode >= 200 and responseCode < 300
        LogEvent("API complete: " + endpoint + " (empty " + responseCode.ToStr() + ")")
        m.top.response = {}
        m.top.status = "completed"
        return
    else if response = ""
        errorMsg = "Empty response (HTTP " + responseCode.ToStr() + ")"
        LogError("API error: " + errorMsg)
        m.top.error = errorMsg
        m.top.status = "error"
        return
    end if

    ' Parse JSON response
    json = ParseJson(response)
    if json = invalid
        ' Some endpoints return XML or empty responses, handle gracefully
        LogError("API error: Invalid JSON response from " + endpoint)
        m.top.error = "Invalid JSON response"
        m.top.status = "error"
        return
    end if

    LogEvent("API complete: " + endpoint)
    m.top.response = json
    m.top.status = "completed"
end sub
