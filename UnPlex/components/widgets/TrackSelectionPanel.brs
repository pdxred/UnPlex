sub init()
    m.panelContainer = m.top.findNode("panelContainer")
    m.audioList = m.top.findNode("audioList")
    m.subtitleList = m.top.findNode("subtitleList")
    m.audioHeader = m.top.findNode("audioHeader")
    m.subtitleHeader = m.top.findNode("subtitleHeader")
    m.divider = m.top.findNode("divider")
    m.slideAnimation = m.top.findNode("slideAnimation")
    m.slideInterpolator = m.top.findNode("slideInterpolator")

    c = m.global.constants

    ' Apply theme colors
    m.audioHeader.color = c.TEXT_PRIMARY
    m.subtitleHeader.color = c.TEXT_PRIMARY
    m.divider.color = c.SEPARATOR
    m.audioList.focusedColor = c.ACCENT
    m.subtitleList.focusedColor = c.ACCENT

    ' Observe list item selection
    m.audioList.observeField("itemSelected", "onAudioItemSelected")
    m.subtitleList.observeField("itemSelected", "onSubtitleItemSelected")

    ' Track which list has focus for cross-list navigation
    m.focusedList = "audio"
end sub

sub onAudioStreamsChange(event as Object)
    streams = event.getData()
    renderAudioStreams(streams)
end sub

sub renderAudioStreams(streams as Object)
    if streams = invalid then return

    content = CreateObject("roSGNode", "ContentNode")

    for i = 0 to streams.count() - 1
        stream = streams[i]
        item = content.createChild("ContentNode")

        ' Build display title
        displayTitle = SafeGet(stream, "displayTitle", "")
        if displayTitle = ""
            lang = SafeGet(stream, "language", "Unknown")
            codec = UCase(SafeGet(stream, "codec", ""))
            channels = SafeGet(stream, "channels", 2)
            displayTitle = lang + " (" + codec + " " + channels.ToStr() + "ch)"
        end if

        ' Mark selected track with checkmark
        streamId = SafeGet(stream, "id", 0)
        if streamId = m.top.selectedAudioId
            displayTitle = chr(10003) + " " + displayTitle
        end if

        item.title = displayTitle
        item.addFields({ streamId: streamId })
        item.addFields({ codec: SafeGet(stream, "codec", "") })
    end for

    m.audioList.content = content
    repositionSubtitleSection()
end sub

sub onSubtitleStreamsChange(event as Object)
    streams = event.getData()
    renderSubtitleStreams(streams)
end sub

sub renderSubtitleStreams(streams as Object)
    if streams = invalid then return

    content = CreateObject("roSGNode", "ContentNode")

    ' Always add "Off" as first option
    offItem = content.createChild("ContentNode")
    if m.top.selectedSubtitleId = 0
        offItem.title = chr(10003) + " Off"
    else
        offItem.title = "Off"
    end if
    offItem.addFields({ streamId: 0 })
    offItem.addFields({ codec: "" })
    offItem.addFields({ isBitmap: false })

    for i = 0 to streams.count() - 1
        stream = streams[i]
        item = content.createChild("ContentNode")

        ' Build display title
        displayTitle = SafeGet(stream, "displayTitle", "")
        if displayTitle = ""
            lang = SafeGet(stream, "language", "Unknown")
            codec = UCase(SafeGet(stream, "codec", ""))
            displayTitle = lang + " (" + codec + ")"
        end if

        ' Mark selected track with checkmark
        streamId = SafeGet(stream, "id", 0)
        if streamId = m.top.selectedSubtitleId
            displayTitle = chr(10003) + " " + displayTitle
        end if

        item.title = displayTitle
        item.addFields({ streamId: streamId })
        item.addFields({ codec: SafeGet(stream, "codec", "") })
        item.addFields({
            isBitmap: (LCase(SafeGet(stream, "codec", "")) = "pgs" or LCase(SafeGet(stream, "codec", "")) = "vobsub")
        })
    end for

    m.subtitleList.content = content
end sub

sub onSelectedAudioIdChange(event as Object)
    ' Re-render audio list to update checkmark
    renderAudioStreams(m.top.audioStreams)
end sub

sub onSelectedSubtitleIdChange(event as Object)
    ' Re-render subtitle list to update checkmark
    renderSubtitleStreams(m.top.subtitleStreams)
end sub

sub repositionSubtitleSection()
    ' Position subtitle section below audio list based on audio item count
    audioContent = m.audioList.content
    audioCount = 0
    if audioContent <> invalid
        audioCount = audioContent.getChildCount()
    end if

    ' Each item is 56px + 4px spacing = 60px, plus header 50px offset
    audioListHeight = audioCount * 60
    subtitleY = 50 + audioListHeight + 20  ' 20px gap

    m.divider.translation = [0, subtitleY]
    m.subtitleHeader.translation = [0, subtitleY + 16]
    m.subtitleList.translation = [0, subtitleY + 66]
end sub

sub onShowPanelChange(event as Object)
    isVisible = event.getData()

    if isVisible
        m.top.visible = true
        ' Slide in from right
        m.slideInterpolator.keyValue = [[1920.0, 0.0], [1480.0, 0.0]]
        m.slideAnimation.control = "start"

        ' Focus the audio list
        m.audioList.setFocus(true)
        m.focusedList = "audio"
    else
        ' Slide out to right
        m.slideInterpolator.keyValue = [[1480.0, 0.0], [1920.0, 0.0]]
        m.slideAnimation.control = "start"
        m.top.visible = false
    end if
end sub

sub onAudioItemSelected(event as Object)
    index = event.getData()
    content = m.audioList.content
    if content = invalid then return

    item = content.getChild(index)
    if item = invalid then return

    streamId = item.streamId
    codec = item.codec

    m.top.trackChanged = {
        type: "audio"
        streamId: streamId
        codec: codec
        isBitmap: false
    }
end sub

sub onSubtitleItemSelected(event as Object)
    index = event.getData()
    content = m.subtitleList.content
    if content = invalid then return

    item = content.getChild(index)
    if item = invalid then return

    streamId = item.streamId
    codec = item.codec
    isBitmap = item.isBitmap

    m.top.trackChanged = {
        type: "subtitle"
        streamId: streamId
        codec: codec
        isBitmap: isBitmap
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" or key = "options"
        m.top.showPanel = false
        return true
    end if

    ' Cross-list navigation
    if key = "down" and m.focusedList = "audio"
        ' Check if at bottom of audio list
        audioContent = m.audioList.content
        if audioContent <> invalid
            audioCount = audioContent.getChildCount()
            if m.audioList.itemFocused >= audioCount - 1
                m.subtitleList.setFocus(true)
                m.focusedList = "subtitle"
                return true
            end if
        end if
    else if key = "up" and m.focusedList = "subtitle"
        ' Check if at top of subtitle list
        if m.subtitleList.itemFocused <= 0
            m.audioList.setFocus(true)
            m.focusedList = "audio"
            return true
        end if
    end if

    return false
end function
