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
            audioStream = {
                id: SafeGet(stream, "id", 0)
                displayTitle: SafeGet(stream, "displayTitle", "")
                language: SafeGet(stream, "language", "Unknown")
                languageTag: SafeGet(stream, "languageTag", "")
                codec: SafeGet(stream, "codec", "")
                channels: SafeGet(stream, "channels", 2)
                selected: SafeGet(stream, "selected", false)
            }
            m.audioStreams.push(audioStream)

            if audioStream.selected
                m.selectedAudioId = audioStream.id
            end if

        else if streamType = 3  ' Subtitle
            codec = LCase(SafeGet(stream, "codec", ""))
            subtitleStream = {
                id: SafeGet(stream, "id", 0)
                displayTitle: SafeGet(stream, "displayTitle", "")
                language: SafeGet(stream, "language", "Unknown")
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

sub onVideoStateChange(event as Object)
    state = event.getData()

    if state = "playing"
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
            exit for
        end if
    end for
end sub

sub handleTextSubtitleChange(streamId as Integer)
    if streamId = 0
        ' Turn off subtitles
        m.video.subtitleTrack = ""
        m.video.enableSubtitle = false
        m.selectedSubtitleId = 0
        m.trackPanel.selectedSubtitleId = 0
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
            exit for
        end if
    end for
end sub

sub handlePgsSubtitleRequest(streamId as Integer)
    ' Signal PGS request for Plan 02 to handle via transcode pivot
    ' Store the request so Plan 02 can observe pgsRequested field
    m.top.pgsRequested = {
        streamId: streamId
        position: m.currentPosition
    }

    ' Update panel selection optimistically (Plan 02 will revert on failure)
    m.selectedSubtitleId = streamId
    m.trackPanel.selectedSubtitleId = streamId
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
