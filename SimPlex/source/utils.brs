' Generate or retrieve persistent device UUID
function GetDeviceId() as String
    sec = CreateObject("roRegistrySection", "SimPlex")
    deviceId = sec.Read("deviceId")
    if deviceId = ""
        deviceId = CreateObject("roDeviceInfo").GetRandomUUID()
        sec.Write("deviceId", deviceId)
        sec.Flush()
    end if
    return deviceId
end function

' Get stored auth token
function GetAuthToken() as String
    sec = CreateObject("roRegistrySection", "SimPlex")
    return sec.Read("authToken")
end function

' Store auth token
sub SetAuthToken(token as String)
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Write("authToken", token)
    sec.Flush()
end sub

' Get stored server URI
function GetServerUri() as String
    sec = CreateObject("roRegistrySection", "SimPlex")
    return sec.Read("serverUri")
end function

' Store server URI
sub SetServerUri(uri as String)
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Write("serverUri", uri)
    sec.Flush()
end sub

' Get stored admin (owner) token
function GetAdminToken() as String
    sec = CreateObject("roRegistrySection", "SimPlex")
    return sec.Read("adminToken")
end function

' Store admin (owner) token separately from active user token
sub SetAdminToken(token as String)
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Write("adminToken", token)
    sec.Flush()
end sub

' Get active user display name
function GetActiveUserName() as String
    sec = CreateObject("roRegistrySection", "SimPlex")
    name = sec.Read("activeUserName")
    if name = "" then return "Admin"
    return name
end function

' Set active user display name
sub SetActiveUserName(name as String)
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Write("activeUserName", name)
    sec.Flush()
end sub

' Clear all stored authentication data (sign out)
sub ClearAuthData()
    sec = CreateObject("roRegistrySection", "SimPlex")
    sec.Delete("authToken")
    sec.Delete("adminToken")
    sec.Delete("serverUri")
    sec.Delete("serverClientId")
    sec.Delete("activeUserName")
    sec.Flush()
    LogEvent("Auth data cleared")
end sub

' Build standard Plex headers as associative array
function GetPlexHeaders() as Object
    di = CreateObject("roDeviceInfo")
    ' Use cached constants from m.global, fallback to GetConstants() for edge cases
    if m.global <> invalid and m.global.constants <> invalid
        c = m.global.constants
    else
        c = GetConstants()
    end if
    return {
        "X-Plex-Product": c.PLEX_PRODUCT
        "X-Plex-Version": c.PLEX_VERSION
        "X-Plex-Client-Identifier": GetDeviceId()
        "X-Plex-Platform": c.PLEX_PLATFORM
        "X-Plex-Platform-Version": di.GetOSVersion().major + "." + di.GetOSVersion().minor
        "X-Plex-Device": di.GetModelDisplayName()
        "X-Plex-Device-Name": di.GetFriendlyName()
        "Accept": "application/json"
    }
end function

' Build full PMS URL with token
function BuildPlexUrl(path as String) as String
    serverUri = GetServerUri()
    token = GetAuthToken()
    separator = "?"
    if Instr(1, path, "?") > 0 then separator = "&"
    return serverUri + path + separator + "X-Plex-Token=" + token
end function

' Build poster image URL at specified dimensions
function BuildPosterUrl(thumbPath as String, width as Integer, height as Integer) as String
    serverUri = GetServerUri()
    token = GetAuthToken()
    encodedPath = thumbPath ' Note: URL-encode if needed
    return serverUri + "/photo/:/transcode?width=" + width.ToStr() + "&height=" + height.ToStr() + "&url=" + encodedPath + "&X-Plex-Token=" + token
end function

' URL encode a string
function UrlEncode(str as String) as String
    obj = CreateObject("roUrlTransfer")
    return obj.Escape(str)
end function

' Format milliseconds to HH:MM:SS or MM:SS
function FormatTime(ms as Integer) as String
    totalSeconds = ms \ 1000
    hours = totalSeconds \ 3600
    minutes = (totalSeconds MOD 3600) \ 60
    seconds = totalSeconds MOD 60

    if hours > 0
        return hours.ToStr() + ":" + PadZero(minutes) + ":" + PadZero(seconds)
    else
        return minutes.ToStr() + ":" + PadZero(seconds)
    end if
end function

' Pad single digit with leading zero
function PadZero(num as Integer) as String
    if num < 10
        return "0" + num.ToStr()
    else
        return num.ToStr()
    end if
end function

' Safe field access - returns default if field missing or obj invalid
' Prevents crashes on malformed/partial API responses
function SafeGet(obj as Dynamic, field as String, default as Dynamic) as Dynamic
    if obj = invalid then return default
    if type(obj) <> "roAssociativeArray" then return default
    if not obj.DoesExist(field) then return default
    return obj[field]
end function

' Safe nested access for Plex MediaContainer pattern
' Usage: items = SafeGetMetadata(response) ' returns [] if path invalid
function SafeGetMetadata(response as Dynamic) as Object
    container = SafeGet(response, "MediaContainer", invalid)
    if container = invalid then return []
    metadata = SafeGet(container, "Metadata", [])
    return metadata
end function
