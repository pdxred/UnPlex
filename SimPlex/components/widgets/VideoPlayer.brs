sub init()
    m.video = m.top.findNode("video")

    m.video.observeField("state", "onVideoStateChange")
    m.video.observeField("position", "onPositionChange")

    m.lastReportTime = 0
    m.duration = 0
    m.seekPending = false

    ' Set up session task for progress reporting
    m.sessionTask = CreateObject("roSGNode", "PlexSessionTask")

    ' Progress report timer
    m.reportTimer = CreateObject("roSGNode", "Timer")
    m.reportTimer.duration = 10  ' Report every 10 seconds
    m.reportTimer.repeat = true
    m.reportTimer.observeField("fire", "reportProgress")

    ' Track selection panel
    m.trackPanel = m.top.findNode("trackPanel")
    m.trackPanel.observeField("trackChanged", "onTrackChanged")
    m.trackPanel.observeField("visible", "onPanelVisibleChange")

    ' Stream metadata
    m.audioStreams = []
    m.subtitleStreams = []
    m.selectedAudioId = 0
    m.selectedSubtitleId = 0
    m.partId = 0

    ' Panel state
    m.pausedForPanel = false

    ' Playback mode tracking (for Plan 02 PGS transcode)
    m.isTranscoding = false
    m.isTranscodePivotInProgress = false
    m.previousPlaybackState = invalid

    ' Cache media info for potential replays
    m.cachedMediaInfo = invalid
    m.cachedPart = invalid
    m.canDirectPlay = false

    ' Transcode overlay
    m.transcodingOverlay = m.top.findNode("transcodingOverlay")
    m.transcodingSpinner = m.top.findNode("transcodingSpinner")

    ' PGS pivot target subtitle ID (set during pivot, checked on completion)
    m.pendingPgsSubtitleId = 0
end sub

sub onControlChange(event as Object)
    control = event.getData()
    if control = "play"
        loadMedia()
    else if control = "stop"
        stopPlayback()
    end if
end sub

sub loadMedia()
    ' First fetch media metadata to determine playback URL
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.top.mediaKey
    task.params = {}
    task.observeField("status", "onMediaTaskStateChange")
    task.control = "run"
    m.mediaInfoTask = task
end sub

sub onMediaTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        processMediaInfo()
    else if state = "error"
        showError("Failed to load media: " + m.mediaInfoTask.error)
        m.top.playbackComplete = true
    end if
end sub

sub processMediaInfo()
    response = m.mediaInfoTask.response
    if response = invalid or response.MediaContainer = invalid
        showError("Invalid media response")
        m.top.playbackComplete = true
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid or metadata.count() = 0
        showError("No media metadata found")
        m.top.playbackComplete = true
        return
    end if

    item = metadata[0]
    m.duration = 0
    if item.duration <> invalid
        m.duration = item.duration
    end if

    ' Get media info
    media = item.Media
    if media = invalid or media.count() = 0
        showError("No media streams found")
        m.top.playbackComplete = true
        return
    end if

    ' Use first media and part
    mediaInfo = media[0]
    parts = mediaInfo.Part
    if parts = invalid or parts.count() = 0
        showError("No media parts found")
        m.top.playbackComplete = true
        return
    end if

    part = parts[0]

    ' Cache media info for potential replays (PGS revert)
    m.cachedMediaInfo = mediaInfo
    m.cachedPart = part

    ' Store part ID for track persistence (Plan 02)
    m.partId = SafeGet(part, "id", 0)

    ' Parse stream metadata from part
    streams = SafeGet(part, "Stream", [])
    parseStreams(streams)

    ' Determine if we can direct play
    m.canDirectPlay = checkDirectPlay(mediaInfo)

    ' Build playback URL
    if m.canDirectPlay
        playUrl = BuildPlexUrl(part.key)
        streamFormat = getStreamFormat(SafeGet(part, "container", "mp4"))
    else
        ' Use transcoding
        playUrl = buildTranscodeUrl()
        streamFormat = "hls"
    end if

    ' Set up video content
    content = CreateObject("roSGNode", "ContentNode")
    content.url = playUrl
    content.streamFormat = streamFormat
    content.title = m.top.itemTitle

    ' Set up SRT sidecar subtitles if a text subtitle is selected
    setupInitialSubtitles(content)

    m.video.content = content

    ' Set seek position if resuming
    if m.top.startOffset > 0
        m.seekPending = true
    end if

    ' Start playback
    m.video.control = "play"
    m.video.setFocus(true)

    ' Start progress reporting
    m.reportTimer.control = "start"

    ' Check for forced subtitles before updating panel
    checkForcedSubtitles(content)

    ' Update track panel with stream data
    m.trackPanel.audioStreams = m.audioStreams
    m.trackPanel.subtitleStreams = m.subtitleStreams
    m.trackPanel.selectedAudioId = m.selectedAudioId
    m.trackPanel.selectedSubtitleId = m.selectedSubtitleId
end sub

' Parse audio and subtitle streams from Plex API response
sub parseStreams(streams as Object)
    m.audioStreams = []
    m.subtitleStreams = []

    if streams = invalid then return

    for each stream in streams
        streamType = SafeGet(stream, "streamType", 0)

        if streamType = 2  ' Audio
            displayTitle = SafeGet(stream, "displayTitle", "")
            lang = SafeGet(stream, "language", "Unknown")
            codecStr = SafeGet(stream, "codec", "")
            channels = SafeGet(stream, "channels", 2)

            ' Fallback display title for tracks with no metadata
            if displayTitle = ""
                displayTitle = lang + " (" + UCase(codecStr) + " " + channels.ToStr() + "ch)"
            end if

            audioStream = {
                id: SafeGet(stream, "id", 0)
                displayTitle: displayTitle
                language: lang
                languageTag: SafeGet(stream, "languageTag", "")
                codec: codecStr
                channels: channels
                selected: SafeGet(stream, "selected", false)
            }
            m.audioStreams.push(audioStream)

            if audioStream.selected
                m.selectedAudioId = audioStream.id
            end if

        else if streamType = 3  ' Subtitle
            codec = LCase(SafeGet(stream, "codec", ""))
            displayTitle = SafeGet(stream, "displayTitle", "")
            lang = SafeGet(stream, "language", "Unknown")

            ' Fallback display title for tracks with no metadata
            if displayTitle = ""
                displayTitle = lang + " (" + UCase(codec) + ")"
            end if

            subtitleStream = {
                id: SafeGet(stream, "id", 0)
                displayTitle: displayTitle
                language: lang
                languageTag: SafeGet(stream, "languageTag", "")
                codec: codec
                forced: SafeGet(stream, "forced", false)
                selected: SafeGet(stream, "selected", false)
                isBitmap: (codec = "pgs" or codec = "vobsub")
            }
            m.subtitleStreams.push(subtitleStream)

            if subtitleStream.selected
                m.selectedSubtitleId = subtitleStream.id
            end if
        end if
    end for

    ' Expose streams on interface for external access
    m.top.audioStreams = m.audioStreams
    m.top.subtitleStreams = m.subtitleStreams
end sub

' Set up initial sidecar subtitle if a text subtitle is pre-selected
sub setupInitialSubtitles(content as Object)
    if m.selectedSubtitleId = 0 then return

    ' Find the selected subtitle stream
    for each stream in m.subtitleStreams
        if stream.id = m.selectedSubtitleId and not stream.isBitmap
            ' Text subtitle — set up sidecar delivery
            sidecarUrl = buildSidecarUrl(stream.id)
            content.subtitleTracks = [{
                TrackName: "sidecar_" + stream.id.ToStr()
                Language: stream.languageTag
                Url: sidecarUrl
            }]
            exit for
        end if
    end for
end sub

' Build sidecar subtitle URL
function buildSidecarUrl(streamId as Integer) as String
    serverUri = GetServerUri()
    token = GetAuthToken()
    return serverUri + "/library/streams/" + streamId.ToStr() + "?X-Plex-Token=" + token
end function

function checkDirectPlay(mediaInfo as Object) as Boolean
    ' Check video codec
    videoCodec = ""
    if mediaInfo.videoCodec <> invalid
        videoCodec = LCase(mediaInfo.videoCodec)
    end if

    ' Roku supports H.264, HEVC, VP9
    supportedVideoCodecs = ["h264", "hevc", "h265", "vp9"]
    videoOk = false
    for each codec in supportedVideoCodecs
        if videoCodec = codec
            videoOk = true
            exit for
        end if
    end for

    if not videoOk then return false

    ' Check audio codec
    audioCodec = ""
    if mediaInfo.audioCodec <> invalid
        audioCodec = LCase(mediaInfo.audioCodec)
    end if

    ' Roku supports AAC, AC3, EAC3, MP3
    supportedAudioCodecs = ["aac", "ac3", "eac3", "mp3"]
    audioOk = false
    for each codec in supportedAudioCodecs
        if audioCodec = codec
            audioOk = true
            exit for
        end if
    end for

    return videoOk and audioOk
end function

function getStreamFormat(container as String) as String
    c = LCase(container)
    if c = "mp4" or c = "m4v"
        return "mp4"
    else if c = "mkv"
        return "mkv"
    else if c = "hls"
        return "hls"
    else
        return "mp4"  ' Default
    end if
end function

function buildTranscodeUrl() as String
    serverUri = GetServerUri()
    token = GetAuthToken()
    c = m.global.constants

    url = serverUri + "/video/:/transcode/universal/start.m3u8"
    url = url + "?path=" + UrlEncode(m.top.mediaKey)
    url = url + "&mediaIndex=0"
    url = url + "&partIndex=0"
    url = url + "&protocol=hls"
    url = url + "&directPlay=0"
    url = url + "&directStream=1"
    url = url + "&videoQuality=100"
    url = url + "&maxVideoBitrate=20000"
    url = url + "&videoResolution=1920x1080"
    url = url + "&subtitles=auto"
    url = url + "&X-Plex-Token=" + token

    return url
end function

' Build transcode URL with subtitle burn-in for PGS subtitles
function buildTranscodeUrlWithSubtitles(subtitleStreamID as Integer, offsetMs as Integer) as String
    serverUri = GetServerUri()
    token = GetAuthToken()

    url = serverUri + "/video/:/transcode/universal/start.m3u8"
    url = url + "?path=" + UrlEncode(m.top.mediaKey)
    url = url + "&mediaIndex=0"
    url = url + "&partIndex=0"
    url = url + "&protocol=hls"
    url = url + "&directPlay=0"
    url = url + "&directStream=1"
    url = url + "&videoQuality=100"
    url = url + "&maxVideoBitrate=20000"
    url = url + "&videoResolution=1920x1080"
    url = url + "&subtitleStreamID=" + subtitleStreamID.ToStr()
    url = url + "&subtitles=burn"
    url = url + "&offset=" + Int(offsetMs / 1000).ToStr()
    url = url + "&X-Plex-Token=" + token

    return url
end function

sub onVideoStateChange(event as Object)
    state = event.getData()

    if state = "playing"
        ' Handle transcode pivot completion
        if m.isTranscodePivotInProgress
            m.transcodingOverlay.visible = false
            m.transcodingSpinner.visible = false
            m.isTranscodePivotInProgress = false

            ' Persist the track selection
            persistTrackSelection(m.selectedAudioId, m.selectedSubtitleId)
            return
        end if

        if m.seekPending and m.top.startOffset > 0
            m.video.seek = m.top.startOffset / 1000  ' Convert ms to seconds
            m.seekPending = false
        end if
    else if state = "finished"
        ' Mark as watched
        scrobble()
        m.reportTimer.control = "stop"
        m.top.playbackComplete = true
    else if state = "error"
        ' Handle transcode pivot failure
        if m.isTranscodePivotInProgress
            m.transcodingOverlay.visible = false
            m.transcodingSpinner.visible = false
            m.isTranscodePivotInProgress = false
            revertFromTranscodePivot()
            return
        end if

        m.reportTimer.control = "stop"
        errorInfo = m.video.errorMsg
        showError("Playback error: " + errorInfo)
        m.top.playbackComplete = true
    end if
end sub

sub onPositionChange(event as Object)
    position = event.getData()
    m.currentPosition = position * 1000  ' Convert to ms
end sub

sub reportProgress()
    if m.currentPosition = invalid then return

    m.sessionTask.ratingKey = m.top.ratingKey
    m.sessionTask.mediaKey = m.top.mediaKey
    m.sessionTask.state = "playing"
    m.sessionTask.time = m.currentPosition
    m.sessionTask.duration = m.duration
    m.sessionTask.control = "run"
end sub

sub scrobble()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": m.top.ratingKey
    }
    task.control = "run"
end sub

sub stopPlayback()
    ' Report final position
    if m.currentPosition <> invalid
        m.sessionTask.ratingKey = m.top.ratingKey
        m.sessionTask.mediaKey = m.top.mediaKey
        m.sessionTask.state = "stopped"
        m.sessionTask.time = m.currentPosition
        m.sessionTask.duration = m.duration
        m.sessionTask.control = "run"
    end if

    m.reportTimer.control = "stop"
    m.video.control = "stop"
end sub

sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Playback Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog
end sub

' ========== Track Selection Panel Integration ==========

sub onTrackChanged(event as Object)
    change = event.getData()
    if change = invalid then return

    changeType = SafeGet(change, "type", "")
    streamId = SafeGet(change, "streamId", 0)
    codec = SafeGet(change, "codec", "")
    isBitmap = SafeGet(change, "isBitmap", false)

    if changeType = "audio"
        handleAudioTrackChange(streamId)
    else if changeType = "subtitle"
        if isBitmap
            ' PGS/bitmap subtitle — signal for Plan 02 transcode pivot
            handlePgsSubtitleRequest(streamId)
        else
            ' Text subtitle or Off
            handleTextSubtitleChange(streamId)
        end if
    end if
end sub

sub handleAudioTrackChange(streamId as Integer)
    ' Find the audio track index for Roku Video node
    for i = 0 to m.audioStreams.count() - 1
        if m.audioStreams[i].id = streamId
            ' Roku Video audioTrack is 0-based index of audio streams
            m.video.audioTrack = i.ToStr()
            m.selectedAudioId = streamId
            m.trackPanel.selectedAudioId = streamId

            ' Persist track preference
            persistTrackSelection(streamId, m.selectedSubtitleId)
            exit for
        end if
    end for
end sub

sub handleTextSubtitleChange(streamId as Integer)
    ' If currently transcoding (PGS burn-in), switch back to direct play
    if m.isTranscoding
        switchFromTranscodeToDirectPlay(streamId)
        return
    end if

    if streamId = 0
        ' Turn off subtitles
        m.video.subtitleTrack = ""
        m.video.enableSubtitle = false
        m.selectedSubtitleId = 0
        m.trackPanel.selectedSubtitleId = 0

        ' Persist track preference
        persistTrackSelection(m.selectedAudioId, 0)
        return
    end if

    ' Find the subtitle stream
    for each stream in m.subtitleStreams
        if stream.id = streamId
            ' Build sidecar URL and apply to content
            sidecarUrl = buildSidecarUrl(streamId)
            trackName = "sidecar_" + streamId.ToStr()

            content = m.video.content
            if content <> invalid
                content.subtitleTracks = [{
                    TrackName: trackName
                    Language: stream.languageTag
                    Url: sidecarUrl
                }]
                m.video.subtitleTrack = trackName
                m.video.enableSubtitle = true
            end if

            m.selectedSubtitleId = streamId
            m.trackPanel.selectedSubtitleId = streamId

            ' Persist track preference
            persistTrackSelection(m.selectedAudioId, streamId)
            exit for
        end if
    end for
end sub

sub handlePgsSubtitleRequest(streamId as Integer)
    ' Guard against rapid PGS switching
    if m.isTranscodePivotInProgress then return

    m.isTranscodePivotInProgress = true
    m.pendingPgsSubtitleId = streamId

    ' Store current state for revert on failure
    currentContent = m.video.content
    m.previousPlaybackState = {
        url: ""
        streamFormat: ""
        position: m.currentPosition
        audioId: m.selectedAudioId
        subtitleId: m.selectedSubtitleId
        wasTranscoding: m.isTranscoding
    }
    if currentContent <> invalid
        m.previousPlaybackState.url = currentContent.url
        m.previousPlaybackState.streamFormat = currentContent.streamFormat
    end if

    ' Record position before stopping
    offsetMs = 0
    if m.currentPosition <> invalid
        offsetMs = m.currentPosition
    end if

    ' Stop current playback
    m.video.control = "stop"

    ' Show "Switching subtitles..." overlay
    m.transcodingOverlay.visible = true
    m.transcodingSpinner.visible = true

    ' Build transcode URL with subtitle burn-in
    playUrl = buildTranscodeUrlWithSubtitles(streamId, offsetMs)

    ' Create new content node with HLS transcode
    content = CreateObject("roSGNode", "ContentNode")
    content.url = playUrl
    content.streamFormat = "hls"
    content.title = m.top.itemTitle

    ' Start playback with transcode
    m.video.content = content
    m.video.control = "play"
    m.isTranscoding = true

    ' Update selection state
    m.selectedSubtitleId = streamId
    m.trackPanel.selectedSubtitleId = streamId

    ' Close the panel
    m.pausedForPanel = false  ' Don't resume — we're restarting
    m.trackPanel.visible = false
end sub

' Revert to previous playback state after PGS transcode failure
sub revertFromTranscodePivot()
    ' Show error toast
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Subtitle Unavailable"
    dialog.message = ["Could not load this subtitle track. Reverting to previous settings."]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog

    if m.previousPlaybackState <> invalid
        ' Restore previous subtitle selection
        m.selectedSubtitleId = m.previousPlaybackState.subtitleId
        m.trackPanel.selectedSubtitleId = m.previousPlaybackState.subtitleId
        m.isTranscoding = m.previousPlaybackState.wasTranscoding

        ' Rebuild previous content
        content = CreateObject("roSGNode", "ContentNode")
        content.url = m.previousPlaybackState.url
        content.streamFormat = m.previousPlaybackState.streamFormat
        content.title = m.top.itemTitle

        m.video.content = content
        m.video.control = "play"

        ' Seek to previous position
        if m.previousPlaybackState.position <> invalid and m.previousPlaybackState.position > 0
            m.seekPending = true
            m.top.startOffset = m.previousPlaybackState.position
        end if
    end if

    m.previousPlaybackState = invalid
end sub

' Switch back from PGS transcode to direct play (when selecting SRT or Off while transcoding)
sub switchFromTranscodeToDirectPlay(subtitleStreamId as Integer)
    if not m.isTranscoding then return
    if m.isTranscodePivotInProgress then return

    m.isTranscodePivotInProgress = true

    ' Record current position
    offsetMs = 0
    if m.currentPosition <> invalid
        offsetMs = m.currentPosition
    end if

    ' Stop transcode playback
    m.video.control = "stop"

    ' Show overlay during switch
    m.transcodingOverlay.visible = true
    m.transcodingSpinner.visible = true

    ' Rebuild direct play URL from cached media info
    if m.cachedPart <> invalid and m.canDirectPlay
        playUrl = BuildPlexUrl(m.cachedPart.key)
        streamFormat = getStreamFormat(SafeGet(m.cachedPart, "container", "mp4"))
    else
        playUrl = buildTranscodeUrl()
        streamFormat = "hls"
    end if

    content = CreateObject("roSGNode", "ContentNode")
    content.url = playUrl
    content.streamFormat = streamFormat
    content.title = m.top.itemTitle

    ' Set up sidecar subtitle if selecting SRT
    if subtitleStreamId > 0
        for each stream in m.subtitleStreams
            if stream.id = subtitleStreamId and not stream.isBitmap
                sidecarUrl = buildSidecarUrl(subtitleStreamId)
                content.subtitleTracks = [{
                    TrackName: "sidecar_" + subtitleStreamId.ToStr()
                    Language: stream.languageTag
                    Url: sidecarUrl
                }]
                exit for
            end if
        end for
    end if

    m.video.content = content
    m.video.control = "play"
    m.isTranscoding = false

    ' Seek to current position
    if offsetMs > 0
        m.seekPending = true
        m.top.startOffset = offsetMs
    end if

    ' Update selection
    m.selectedSubtitleId = subtitleStreamId
    m.trackPanel.selectedSubtitleId = subtitleStreamId
end sub

' Panel visibility change — manage pause/resume
sub onPanelVisibleChange(event as Object)
    isVisible = event.getData()

    if isVisible
        ' Panel opened — pause if playing
        if m.video.state = "playing"
            m.video.control = "pause"
            m.pausedForPanel = true
        end if
    else
        ' Panel closed — resume if we paused for it
        if m.pausedForPanel
            m.video.control = "resume"
            m.pausedForPanel = false
        end if
        ' Restore focus to video
        m.video.setFocus(true)
    end if
end sub

' ========== Track Persistence ==========

' Persist track selection to Plex server via PUT /library/parts/{id}
' Fire-and-forget — no UI impact on success/failure
sub persistTrackSelection(audioStreamId as Integer, subtitleStreamId as Integer)
    if m.partId = 0 then return

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/parts/" + m.partId.ToStr()
    task.method = "PUT"

    params = {}
    if audioStreamId > 0
        params["audioStreamID"] = audioStreamId.ToStr()
    end if
    if subtitleStreamId > 0
        params["subtitleStreamID"] = subtitleStreamId.ToStr()
    else
        params["subtitleStreamID"] = "0"
    end if

    task.params = params
    task.control = "run"
    ' Fire and forget — per established scrobble pattern
end sub

' ========== Forced Subtitle Auto-Enable ==========

' Check if forced subtitles should auto-enable based on audio language vs device locale
sub checkForcedSubtitles(content as Object)
    ' Find selected audio track's language
    audioLangTag = ""
    for each stream in m.audioStreams
        if stream.selected
            audioLangTag = stream.languageTag
            exit for
        end if
    end for

    ' Get device locale (e.g., "en_US")
    di = CreateObject("roDeviceInfo")
    locale = di.GetCurrentLocale()
    deviceLang = Left(locale, 2)  ' Extract 2-letter language code

    ' If audio language matches device language, no forced sub needed
    if audioLangTag <> "" and Left(audioLangTag, 2) = deviceLang
        return
    end if

    ' Search for a forced subtitle track matching device language
    for each stream in m.subtitleStreams
        if stream.forced and Left(stream.languageTag, 2) = deviceLang
            ' Found a matching forced subtitle — auto-enable
            if not stream.isBitmap
                ' Text subtitle — apply sidecar
                sidecarUrl = buildSidecarUrl(stream.id)
                content.subtitleTracks = [{
                    TrackName: "sidecar_" + stream.id.ToStr()
                    Language: stream.languageTag
                    Url: sidecarUrl
                }]
                m.selectedSubtitleId = stream.id
            end if
            ' PGS forced subtitles would need transcode — skip auto-enable for initial load
            ' (User can manually select PGS track from panel)
            exit for
        end if
    end for
end sub

' ========== Key Event Handling ==========

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    c = m.global.constants

    ' If track panel is visible, let it handle keys
    if m.trackPanel.visible
        return false
    end if

    if key = "options"
        ' Toggle track selection panel
        m.trackPanel.visible = not m.trackPanel.visible
        return true
    else if key = "back"
        stopPlayback()
        m.top.playbackComplete = true
        return true
    else if key = "fastforward" or key = "right"
        ' Skip forward
        if m.currentPosition <> invalid
            newPos = (m.currentPosition + (c.SKIP_FORWARD_SEC * 1000)) / 1000
            m.video.seek = newPos
        end if
        return true
    else if key = "rewind" or key = "left"
        ' Skip back
        if m.currentPosition <> invalid
            newPos = (m.currentPosition - (c.SKIP_BACK_SEC * 1000)) / 1000
            if newPos < 0 then newPos = 0
            m.video.seek = newPos
        end if
        return true
    else if key = "play" or key = "pause"
        if m.video.state = "playing"
            m.video.control = "pause"
        else if m.video.state = "paused"
            m.video.control = "resume"
        end if
        return true
    end if

    return false
end function
