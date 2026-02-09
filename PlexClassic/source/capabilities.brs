' capabilities.brs - Parse and query Plex server capabilities
' Per CONTEXT.md: hide unsupported features based on server capabilities

' Parse server capabilities from root (/) endpoint response
' Returns associative array with version and feature flags
function ParseServerCapabilities(response as Object) as Object
    caps = {
        version: ""
        versionMajor: 0
        versionMinor: 0
        versionPatch: 0
        supportsHls: true  ' Assumed for transcoding
        supportsIntroMarkers: false
        supportsCreditsMarkers: false
        supportsChapters: true  ' Standard feature
        myPlexSigninState: ""
        platform: ""
    }

    container = SafeGet(response, "MediaContainer", invalid)
    if container = invalid then return caps

    ' Parse version string (e.g., "1.32.5.7349-xyz")
    caps.version = SafeGet(container, "version", "")
    if caps.version <> ""
        versionParts = caps.version.Split(".")
        if versionParts.count() >= 1
            caps.versionMajor = val(versionParts[0])
        end if
        if versionParts.count() >= 2
            caps.versionMinor = val(versionParts[1])
        end if
        if versionParts.count() >= 3
            ' Third part may have build info, extract just the number
            patchStr = versionParts[2]
            dashPos = Instr(1, patchStr, "-")
            if dashPos > 0
                patchStr = Left(patchStr, dashPos - 1)
            end if
            caps.versionPatch = val(patchStr)
        end if
    end if

    caps.myPlexSigninState = SafeGet(container, "myPlexSigninState", "")
    caps.platform = SafeGet(container, "platform", "")

    ' Intro/Credits markers require PMS 1.30+
    ' (This is approximate - exact version varies)
    if caps.versionMajor > 1 or (caps.versionMajor = 1 and caps.versionMinor >= 30)
        caps.supportsIntroMarkers = true
        caps.supportsCreditsMarkers = true
    end if

    return caps
end function

' Check if a specific capability is supported
' capability: "introMarkers", "creditsMarkers", "chapters", "hls"
function HasCapability(caps as Object, capability as String) as Boolean
    if caps = invalid then return false

    if capability = "introMarkers"
        return SafeGet(caps, "supportsIntroMarkers", false)
    else if capability = "creditsMarkers"
        return SafeGet(caps, "supportsCreditsMarkers", false)
    else if capability = "chapters"
        return SafeGet(caps, "supportsChapters", true)
    else if capability = "hls"
        return SafeGet(caps, "supportsHls", true)
    end if

    return false
end function

' Get minimum version required for a feature (for UI display/logging)
function GetMinVersionForFeature(feature as String) as String
    if feature = "introMarkers" or feature = "creditsMarkers"
        return "1.30.0"
    end if
    return "1.0.0"  ' Basic features
end function

' Compare server version to minimum required
' Returns true if server meets or exceeds minVersion
function MeetsMinVersion(caps as Object, minMajor as Integer, minMinor as Integer, minPatch as Integer) as Boolean
    if caps = invalid then return false

    if caps.versionMajor > minMajor then return true
    if caps.versionMajor < minMajor then return false

    ' Major equal, check minor
    if caps.versionMinor > minMinor then return true
    if caps.versionMinor < minMinor then return false

    ' Minor equal, check patch
    return caps.versionPatch >= minPatch
end function
