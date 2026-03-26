' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.infoList = m.top.findNode("infoList")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.infoList.setFocus(true)
    end if
end sub

sub onItemDataChange(event as Object)
    itemData = event.getData()
    if itemData = invalid then return

    LogEvent("MediaInfoScreen: loading media info for " + SafeGet(itemData, "title", "unknown"))

    content = CreateObject("roSGNode", "ContentNode")
    lines = []

    ' Item title as header
    title = SafeGet(itemData, "title", "Unknown")
    lines.push("Title: " + title)
    lines.push("")

    ' Extract Media array
    mediaArray = SafeGet(itemData, "Media", invalid)
    if mediaArray = invalid or type(mediaArray) <> "roArray" or mediaArray.count() = 0
        lines.push("No media information available")
        setContentLines(content, lines)
        return
    end if

    media = mediaArray[0]
    if media = invalid
        lines.push("No media information available")
        setContentLines(content, lines)
        return
    end if

    ' Extract Part array
    partArray = SafeGet(media, "Part", invalid)
    part = invalid
    if partArray <> invalid and type(partArray) = "roArray" and partArray.count() > 0
        part = partArray[0]
    end if

    ' --- File Info Section ---
    lines.push("--- FILE INFO ---")

    if part <> invalid
        filePath = SafeGet(part, "file", "")
        if filePath <> ""
            lines.push("File: " + filePath)
        end if

        container = SafeGet(part, "container", "")
        if container <> ""
            lines.push("Container: " + container)
        end if

        fileSize = SafeGet(part, "size", invalid)
        lines.push("File Size: " + FormatFileSize(fileSize))
    else
        lines.push("No file information available")
    end if

    ' Container-level bitrate
    mediaBitrate = SafeGet(media, "bitrate", invalid)
    if mediaBitrate <> invalid
        lines.push("Overall Bitrate: " + mediaBitrate.ToStr() + " kbps")
    end if

    ' Duration from media
    mediaDuration = SafeGet(media, "duration", invalid)
    if mediaDuration <> invalid
        lines.push("Duration: " + FormatTime(mediaDuration))
    end if

    lines.push("")

    ' Collect streams from Part
    streams = []
    if part <> invalid
        streamArray = SafeGet(part, "Stream", invalid)
        if streamArray <> invalid and type(streamArray) = "roArray"
            streams = streamArray
        end if
    end if

    ' --- Video Section ---
    lines.push("--- VIDEO ---")
    hasVideo = false
    for each stream in streams
        streamType = SafeGet(stream, "streamType", 0)
        if streamType = 1
            hasVideo = true
            codec = SafeGet(stream, "codec", "unknown")
            displayTitle = SafeGet(stream, "displayTitle", "")
            if displayTitle <> ""
                lines.push("Codec: " + displayTitle)
            else
                lines.push("Codec: " + codec)
            end if

            width = SafeGet(stream, "width", 0)
            height = SafeGet(stream, "height", 0)
            if width > 0 and height > 0
                lines.push("Resolution: " + width.ToStr() + "x" + height.ToStr())
            end if

            bitrate = SafeGet(stream, "bitrate", invalid)
            if bitrate <> invalid
                lines.push("Bitrate: " + bitrate.ToStr() + " kbps")
            end if

            profile = SafeStr(SafeGet(stream, "profile", invalid))
            if profile <> ""
                lines.push("Profile: " + profile)
            end if

            frameRate = SafeStr(SafeGet(stream, "frameRate", invalid))
            if frameRate <> ""
                lines.push("Frame Rate: " + frameRate)
            end if

            colorSpace = SafeStr(SafeGet(stream, "colorSpace", invalid))
            if colorSpace <> ""
                lines.push("Color Space: " + colorSpace)
            end if
        end if
    end for
    if not hasVideo
        lines.push("No video streams found")
    end if
    lines.push("")

    ' --- Audio Section(s) ---
    lines.push("--- AUDIO ---")
    audioCount = 0
    for each stream in streams
        streamType = SafeGet(stream, "streamType", 0)
        if streamType = 2
            audioCount = audioCount + 1
            displayTitle = SafeGet(stream, "displayTitle", "")
            codec = SafeGet(stream, "codec", "unknown")
            language = SafeGet(stream, "language", "")

            label = "Track " + audioCount.ToStr()
            if displayTitle <> ""
                label = label + ": " + displayTitle
            else
                parts = [codec]
                if language <> "" then parts.push(language)
                label = label + ": " + parts.join(" - ")
            end if
            lines.push(label)

            channels = SafeGet(stream, "channels", invalid)
            if channels <> invalid
                channelStr = channels.ToStr() + " channels"
                if channels = 1 then channelStr = "Mono"
                if channels = 2 then channelStr = "Stereo"
                if channels = 6 then channelStr = "5.1"
                if channels = 8 then channelStr = "7.1"
                lines.push("  Channels: " + channelStr)
            end if

            bitrate = SafeGet(stream, "bitrate", invalid)
            if bitrate <> invalid
                lines.push("  Bitrate: " + bitrate.ToStr() + " kbps")
            end if

            sampleRate = SafeGet(stream, "samplingRate", invalid)
            if sampleRate <> invalid
                lines.push("  Sample Rate: " + sampleRate.ToStr() + " Hz")
            end if
        end if
    end for
    if audioCount = 0
        lines.push("No audio streams found")
    end if
    lines.push("")

    ' --- Subtitle Section(s) ---
    lines.push("--- SUBTITLES ---")
    subCount = 0
    for each stream in streams
        streamType = SafeGet(stream, "streamType", 0)
        if streamType = 3
            subCount = subCount + 1
            displayTitle = SafeGet(stream, "displayTitle", "")
            codec = SafeGet(stream, "codec", "unknown")
            language = SafeGet(stream, "language", "")

            label = "Track " + subCount.ToStr()
            if displayTitle <> ""
                label = label + ": " + displayTitle
            else if language <> ""
                label = label + ": " + language + " (" + codec + ")"
            else
                label = label + ": " + codec
            end if
            lines.push(label)
        end if
    end for
    if subCount = 0
        lines.push("No subtitle streams found")
    end if

    setContentLines(content, lines)
end sub

sub setContentLines(content as Object, lines as Object)
    for each line in lines
        node = content.createChild("ContentNode")
        node.title = line
    end for
    m.infoList.content = content
    m.infoList.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
