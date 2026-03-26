' Copyright 2026 UnPlex contributors. MIT License.
' Generate or retrieve persistent device UUID
function GetDeviceId() as String
    sec = CreateObject("roRegistrySection", "UnPlex")
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
    sec = CreateObject("roRegistrySection", "UnPlex")
    return sec.Read("authToken")
end function

' Store auth token
sub SetAuthToken(token as String)
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Write("authToken", token)
    sec.Flush()
end sub

' Get stored server URI
function GetServerUri() as String
    sec = CreateObject("roRegistrySection", "UnPlex")
    return sec.Read("serverUri")
end function

' Store server URI
sub SetServerUri(uri as String)
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Write("serverUri", uri)
    sec.Flush()
end sub

' Get stored admin (owner) token
function GetAdminToken() as String
    sec = CreateObject("roRegistrySection", "UnPlex")
    return sec.Read("adminToken")
end function

' Store admin (owner) token separately from active user token
sub SetAdminToken(token as String)
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Write("adminToken", token)
    sec.Flush()
end sub

' Get active user display name
function GetActiveUserName() as String
    sec = CreateObject("roRegistrySection", "UnPlex")
    name = sec.Read("activeUserName")
    if name = "" then return "Admin"
    return name
end function

' Set active user display name
sub SetActiveUserName(name as String)
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Write("activeUserName", name)
    sec.Flush()
end sub

' Clear all stored authentication data (sign out)
sub ClearAuthData()
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Delete("authToken")
    sec.Delete("adminToken")
    sec.Delete("serverUri")
    sec.Delete("serverClientId")
    sec.Delete("activeUserName")
    sec.Flush()
    LogEvent("Auth data cleared")
end sub

' Get pinned hub libraries from registry
' Returns array of { key: "sectionId", title: "Library Name" }
function GetPinnedLibraries() as Object
    sec = CreateObject("roRegistrySection", "UnPlex")
    json = sec.Read("pinnedLibraries")
    if json = ""
        return []
    end if
    parsed = ParseJson(json)
    if parsed = invalid then return []
    return parsed
end function

' Save pinned hub libraries to registry
sub SetPinnedLibraries(libs as Object)
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Write("pinnedLibraries", FormatJson(libs))
    sec.Flush()
end sub

' Get sidebar pinned libraries from registry
function GetSidebarLibraries() as Object
    sec = CreateObject("roRegistrySection", "UnPlex")
    json = sec.Read("sidebarLibraries")
    if json = ""
        return []
    end if
    parsed = ParseJson(json)
    if parsed = invalid then return []
    return parsed
end function

' Save sidebar pinned libraries to registry
sub SetSidebarLibraries(libs as Object)
    sec = CreateObject("roRegistrySection", "UnPlex")
    sec.Write("sidebarLibraries", FormatJson(libs))
    sec.Flush()
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
    encodedPath = UrlEncode(thumbPath)
    return serverUri + "/photo/:/transcode?width=" + width.ToStr() + "&height=" + height.ToStr() + "&url=" + encodedPath + "&X-Plex-Token=" + token
end function

' URL encode a string (render-thread safe — no roUrlTransfer)
' Percent-encodes all characters except unreserved set (A-Z a-z 0-9 - _ . ~)
function UrlEncode(str as String) as String
    encoded = ""
    hexChars = "0123456789ABCDEF"
    for i = 0 to Len(str) - 1
        ch = Mid(str, i + 1, 1)
        code = Asc(ch)
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code = 45 or code = 95 or code = 46 or code = 126
            ' Unreserved character: A-Z a-z 0-9 - _ . ~
            encoded = encoded + ch
        else
            ' Percent-encode: %XX
            hi = (code >> 4) and &hF
            lo = code and &hF
            encoded = encoded + "%" + Mid(hexChars, hi + 1, 1) + Mid(hexChars, lo + 1, 1)
        end if
    end for
    return encoded
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

' Coerce a Dynamic value to String. Handles String, Integer, Float, LongInteger,
' Double, Boolean, and invalid. Plex API returns some nominally-string fields
' (e.g. frameRate) as numeric types depending on server version.
function SafeStr(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "roInt" or valueType = "roInteger" or valueType = "Integer" then return value.ToStr()
    if valueType = "roFloat" or valueType = "Float" then return Str(value).Trim()
    if valueType = "roDouble" or valueType = "Double" then return Str(value).Trim()
    if valueType = "LongInteger" or valueType = "roLongInteger" then return value.ToStr()
    if valueType = "roBoolean" or valueType = "Boolean"
        if value then return "true"
        return "false"
    end if
    return ""
end function

' Safe nested access for Plex MediaContainer pattern
' Usage: items = SafeGetMetadata(response) ' returns [] if path invalid
function SafeGetMetadata(response as Dynamic) as Object
    container = SafeGet(response, "MediaContainer", invalid)
    if container = invalid then return []
    metadata = SafeGet(container, "Metadata", [])
    return metadata
end function

' Convert a ratingKey value to a guaranteed non-invalid String.
' Plex API returns ratingKey as integer in some responses, string in others.
' Usage: ratingKeyStr = GetRatingKeyStr(item.ratingKey)
function GetRatingKeyStr(ratingKey as Dynamic) as String
    if ratingKey = invalid then return ""
    if type(ratingKey) = "roString" or type(ratingKey) = "String"
        return ratingKey
    end if
    return ratingKey.ToStr()
end function

' Format file size in bytes to human-readable string (e.g. "1.54 GB", "850.00 MB")
' Plex returns Part[0].size as LongInteger for multi-GB files
function FormatFileSize(bytes as Dynamic) as String
    if bytes = invalid or bytes = 0 then return "Unknown"

    ' Convert to float for division
    bytesFloat = 0.0
    byteType = type(bytes)
    if byteType = "roFloat" or byteType = "Float" or byteType = "roDouble" or byteType = "Double"
        bytesFloat = bytes
    else if byteType = "roInt" or byteType = "Integer" or byteType = "roLongInteger" or byteType = "LongInteger"
        bytesFloat = bytes
    else if byteType = "roString" or byteType = "String"
        bytesFloat = bytes.ToFloat()
        if bytesFloat = 0 then return "Unknown"
    else
        return "Unknown"
    end if

    if bytesFloat >= 1073741824.0
        gb = bytesFloat / 1073741824.0
        ' Format to 2 decimal places
        whole = Int(gb)
        frac = Int((gb - whole) * 100 + 0.5)
        if frac >= 100
            whole = whole + 1
            frac = 0
        end if
        fracStr = frac.ToStr()
        if frac < 10 then fracStr = "0" + fracStr
        return whole.ToStr() + "." + fracStr + " GB"
    else
        mb = bytesFloat / 1048576.0
        whole = Int(mb)
        frac = Int((mb - whole) * 100 + 0.5)
        if frac >= 100
            whole = whole + 1
            frac = 0
        end if
        fracStr = frac.ToStr()
        if frac < 10 then fracStr = "0" + fracStr
        return whole.ToStr() + "." + fracStr + " MB"
    end if
end function

' Get app version from manifest (returns "major.minor.build" e.g. "1.0.2")
function GetAppVersion() as String
    appInfo = CreateObject("roAppInfo")
    return appInfo.GetVersion()
end function

' Create a themed StandardMessageDialog with UnPlex color palette.
' Usage: dialog = CreateThemedDialog()
'        dialog.title = "Title"
'        dialog.message = ["Message"]
'        dialog.buttons = ["OK", "Cancel"]
function CreateThemedDialog() as Object
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    palette = CreateObject("roSGNode", "RSGPalette")
    palette.colors = {
        DialogBackgroundColor: "0x1A1A1AFF"
        DialogFocusColor: "0xF3B125FF"
        DialogFocusItemColor: "0xFFFFFFFF"
        DialogSecondaryTextColor: "0xA0A0A0FF"
        DialogSecondaryItemColor: "0xA0A0A0FF"
        DialogTextColor: "0xE0E0E0FF"
        DialogItemColor: "0xC0C0C0FF"
    }
    dialog.palette = palette
    return dialog
end function
