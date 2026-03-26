' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.video = m.top.findNode("video")

    ' Customize trickplay bar colors via internal node
    trickBar = m.video.trickPlayBar
    if trickBar <> invalid
        trickBar.filledBarBlendColor = "0xF3B125FF"
        trickBar.currentTimeMarkerBlendColor = "0xF3B125FF"
        trickBar.thumbBlendColor = "0xF3B125FF"
    end if

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

    ' Skip button (intro/credits markers)
    m.skipButton = m.top.findNode("skipButton")
    m.skipButtonLabel = m.top.findNode("skipButtonLabel")
    m.skipButtonBg = m.top.findNode("skipButtonBg")
    m.skipButtonFocus = m.top.findNode("skipButtonFocus")
    m.skipFadeIn = m.top.findNode("skipFadeIn")
    m.skipFadeOut = m.top.findNode("skipFadeOut")
    m.skipFadeOut.observeField("state", "onSkipFadeOutComplete")

    ' Marker storage
    m.introMarker = invalid
    m.creditsMarker = invalid
    m.introSkipped = false
    m.skipButtonVisible = false
    m.skipButtonType = ""
    m.skipButtonFocused = false

    ' Auto-play next episode
    m.autoPlayOverlay = m.top.findNode("autoPlayOverlay")
    m.autoPlayTitle = m.top.findNode("autoPlayTitle")
    m.autoPlayEpisodeLabel = m.top.findNode("autoPlayEpisodeLabel")
    m.autoPlayCountdownLabel = m.top.findNode("autoPlayCountdownLabel")
    m.autoPlayFocusBorder = m.top.findNode("autoPlayFocusBorder")
    m.autoPlayFadeIn = m.top.findNode("autoPlayFadeIn")
    m.autoPlayFadeOut = m.top.findNode("autoPlayFadeOut")
    m.autoPlayFadeOut.observeField("state", "onAutoPlayFadeOutComplete")
    m.autoPlayProgressTrack = m.top.findNode("autoPlayProgressTrack")
    m.autoPlayProgressFill = m.top.findNode("autoPlayProgressFill")

    m.nextEpisodeInfo = invalid
    m.noNextEpisode = false
    m.fetchingNextEpisode = false
    m.countdownSeconds = 10
    m.countdownActive = false
    m.autoPlayOverlayVisible = false
    m.autoPlayFocused = false

    ' Countdown timer (1-second ticks)
    m.countdownTimer = CreateObject("roSGNode", "Timer")
    m.countdownTimer.duration = 1
    m.countdownTimer.repeat = true
    m.countdownTimer.observeField("fire", "onCountdownTick")

    ' Playlist sequential playback
    m.hasPlaylist = false
end sub

sub onControlChange(event as Object)
    control = event.getData()
    if control = "play"
        loadMedia()
    else if control = "stop"
        stopPlayback()
    end if
end sub

sub checkPlaylistContext()
    items = m.top.playlistItems
    m.hasPlaylist = (items <> invalid and items.count() > 0 and m.top.playlistIndex >= 0)
end sub

sub loadMedia()
    checkPlaylistContext()

    ' First fetch media metadata to determine playback URL
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.top.mediaKey
    task.params = { "includeMarkers": "1" }
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
        signalPlaybackComplete("error")
    end if
end sub

sub processMediaInfo()
    response = m.mediaInfoTask.response
    if response = invalid or response.MediaContainer = invalid
        showError("Invalid media response")
        signalPlaybackComplete("error")
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid or metadata.count() = 0
        showError("No media metadata found")
        signalPlaybackComplete("error")
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
        signalPlaybackComplete("error")
        return
    end if

    ' Use first media and part
    mediaInfo = media[0]
    parts = mediaInfo.Part
    if parts = invalid or parts.count() = 0
        showError("No media parts found")
        signalPlaybackComplete("error")
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

    ' Log playback context
    playMode = "direct"
    m.canDirectPlay = checkDirectPlay(mediaInfo)
    if not m.canDirectPlay then playMode = "transcode"
    LogEvent("Playback: " + m.top.itemTitle + " [" + playMode + "] duration=" + m.duration.ToStr() + "ms")

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

    ' Parse intro/credits markers from metadata response (via includeMarkers=1)
    parseMarkersFromMetadata(item)

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
    di = CreateObject("roDeviceInfo")

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
    url = url + "&X-Plex-Client-Identifier=" + GetDeviceId()
    url = url + "&X-Plex-Product=" + UrlEncode(c.PLEX_PRODUCT)
    url = url + "&X-Plex-Platform=" + c.PLEX_PLATFORM
    url = url + "&X-Plex-Platform-Version=" + di.GetOSVersion().major + "." + di.GetOSVersion().minor
    url = url + "&X-Plex-Device=" + UrlEncode(di.GetModelDisplayName())
    url = url + "&X-Plex-Token=" + token

    return url
end function

' Build transcode URL with subtitle burn-in for PGS subtitles
function buildTranscodeUrlWithSubtitles(subtitleStreamID as Integer, offsetMs as Integer) as String
    serverUri = GetServerUri()
    token = GetAuthToken()
    c = m.global.constants
    di = CreateObject("roDeviceInfo")

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
    url = url + "&X-Plex-Client-Identifier=" + GetDeviceId()
    url = url + "&X-Plex-Product=" + UrlEncode(c.PLEX_PRODUCT)
    url = url + "&X-Plex-Platform=" + c.PLEX_PLATFORM
    url = url + "&X-Plex-Platform-Version=" + di.GetOSVersion().major + "." + di.GetOSVersion().minor
    url = url + "&X-Plex-Device=" + UrlEncode(di.GetModelDisplayName())
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

        ' Check for playlist advance (immediate, no countdown)
        if m.hasPlaylist
            nextIndex = m.top.playlistIndex + 1
            items = m.top.playlistItems
            if items <> invalid and nextIndex < items.count()
                advancePlaylist(nextIndex)
                return
            end if
        end if

        ' If auto-play countdown is active, let it finish (don't exit to detail)
        if m.countdownActive and m.nextEpisodeInfo <> invalid
            return
        end if

        ' If we're currently fetching the next episode, wait for it
        if m.fetchingNextEpisode
            return
        end if

        ' If we have a next episode queued but countdown hasn't started, start it now
        if m.nextEpisodeInfo <> invalid and not m.autoPlayOverlayVisible
            showAutoPlayOverlay()
            return
        end if

        ' Normal completion (no playlist or end of playlist)
        signalPlaybackComplete("finished")
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
        signalPlaybackComplete("error")
    end if
end sub

sub onPositionChange(event as Object)
    position = event.getData()
    m.currentPosition = position * 1000  ' Convert to ms
    checkMarkers()
end sub

sub reportProgress()
    if m.currentPosition = invalid then return

    ' Create a fresh task each time — Roku Task nodes cannot be re-run
    ' by setting control="run" again (the field value doesn't change)
    m.sessionTask = CreateObject("roSGNode", "PlexSessionTask")
    m.sessionTask.ratingKey = m.top.ratingKey
    m.sessionTask.mediaKey = m.top.mediaKey
    m.sessionTask.playbackState = "playing"
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

    ' Broadcast watch state update to all visible screens
    m.global.watchStateUpdate = {
        ratingKey: m.top.ratingKey
        viewCount: 1
        viewOffset: 0
    }
end sub

sub stopPlayback()
    ' Report final position with a fresh task
    if m.currentPosition <> invalid
        stopTask = CreateObject("roSGNode", "PlexSessionTask")
        stopTask.ratingKey = m.top.ratingKey
        stopTask.mediaKey = m.top.mediaKey
        stopTask.playbackState = "stopped"
        stopTask.time = m.currentPosition
        stopTask.duration = m.duration
        stopTask.control = "run"
    end if

    m.reportTimer.control = "stop"
    m.video.control = "stop"

    ' Reset marker state
    m.introMarker = invalid
    m.creditsMarker = invalid
    if m.skipButtonVisible
        hideSkipButton()
    end if

    ' Reset auto-play state
    if m.countdownActive
        m.countdownTimer.control = "stop"
        m.countdownActive = false
    end if
    if m.autoPlayOverlayVisible
        hideAutoPlayOverlay()
    end if
    m.nextEpisodeInfo = invalid
    m.noNextEpisode = false
    m.fetchingNextEpisode = false

    ' Reset playlist state
    m.hasPlaylist = false
end sub

sub signalPlaybackComplete(reason as String)
    ' Send final timeline update to Plex server so Continue Watching updates immediately
    if m.currentPosition <> invalid and m.currentPosition > 0
        finalState = "stopped"
        if reason = "finished" then finalState = "stopped"
        finalTask = CreateObject("roSGNode", "PlexSessionTask")
        finalTask.ratingKey = m.top.ratingKey
        finalTask.mediaKey = m.top.mediaKey
        finalTask.playbackState = finalState
        finalTask.time = m.currentPosition
        finalTask.duration = m.duration
        finalTask.control = "run"
    end if

    ' Emit final watch state for stopped/cancelled (finished is handled by scrobble())
    if reason = "stopped" or reason = "cancelled"
        m.global.watchStateUpdate = {
            ratingKey: m.top.ratingKey
            viewCount: 0
            viewOffset: m.currentPosition
        }
    end if

    ' Build structured result and emit via playbackResult field
    hasNext = (m.nextEpisodeInfo <> invalid)
    result = {
        reason: reason
        ratingKey: m.top.ratingKey
        itemTitle: m.top.itemTitle
        hasNextEpisode: hasNext
        nextEpisodeInfo: m.nextEpisodeInfo
        grandparentRatingKey: m.top.grandparentRatingKey
        viewOffset: m.currentPosition
        duration: m.duration
        isPlaylist: m.hasPlaylist
    }
    m.top.playbackResult = result
end sub

sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Playback Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    dialog.observeField("buttonSelected", "onErrorDialogButton")
    m.top.getScene().dialog = dialog
end sub

sub onErrorDialogButton(event as Object)
    m.top.getScene().dialog.close = true
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
    m.trackPanel.showPanel = false
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

' ========== Intro/Credits Skip Markers ==========

' Parse intro and credits markers from metadata response (included via includeMarkers=1)
sub parseMarkersFromMetadata(item as Object)
    m.introMarker = invalid
    m.creditsMarker = invalid
    m.introSkipped = false

    markers = SafeGet(item, "Marker", [])
    if markers = invalid or markers.count() = 0
        LogEvent("Markers: none found in metadata")
        return
    end if

    LogEvent("Markers: found " + markers.count().ToStr() + " marker(s)")
    for each marker in markers
        markerType = SafeGet(marker, "type", "")
        startMs = SafeGet(marker, "startTimeOffset", 0)
        endMs = SafeGet(marker, "endTimeOffset", 0)

        if markerType = "intro" and startMs > 0 and endMs > startMs
            m.introMarker = { startMs: startMs, endMs: endMs }
            LogEvent("Marker: intro " + startMs.ToStr() + "ms - " + endMs.ToStr() + "ms")
        else if markerType = "credits" and startMs > 0 and endMs > startMs
            m.creditsMarker = { startMs: startMs, endMs: endMs }
            LogEvent("Marker: credits " + startMs.ToStr() + "ms - " + endMs.ToStr() + "ms")
        end if
    end for
end sub

' Check current position against marker ranges and show/hide skip button
sub checkMarkers()
    if m.currentPosition = invalid then return
    if m.isTranscodePivotInProgress then return

    currentPos = m.currentPosition
    inIntro = false
    inCredits = false

    ' Check intro marker range
    if m.introMarker <> invalid
        if currentPos >= m.introMarker.startMs and currentPos < m.introMarker.endMs
            inIntro = true
        end if
    end if

    ' Check credits marker range
    if m.creditsMarker <> invalid
        if currentPos >= m.creditsMarker.startMs and currentPos < m.creditsMarker.endMs
            inCredits = true
        end if
    end if

    ' Fallback: last 30 seconds for auto-play next episode (TV only, not movies)
    if not inCredits and m.creditsMarker = invalid and m.duration > 0
        if m.top.grandparentRatingKey <> "" and m.top.grandparentRatingKey <> invalid
            if m.duration > 0 and currentPos >= m.duration - 30000
                inCredits = true
            end if
        end if
    end if

    ' Show or hide overlays based on position
    if inIntro and not m.introSkipped
        ' Auto-skip intro
        LogEvent("Auto-skipping intro to " + m.introMarker.endMs.ToStr() + "ms")
        m.introSkipped = true
        m.video.seek = m.introMarker.endMs / 1000
        return
    else if inCredits and m.hasPlaylist
        ' Playlist mode: skip credits overlays — playlist advances on finish
        return
    else if inCredits
        ' For TV episodes: show auto-play countdown instead of skip credits
        if m.top.grandparentRatingKey <> "" and m.top.grandparentRatingKey <> invalid
            LogEvent("Credits region (TV): nextEp=" + (m.nextEpisodeInfo <> invalid).ToStr() + " fetching=" + m.fetchingNextEpisode.ToStr() + " noNext=" + m.noNextEpisode.ToStr() + " overlayVis=" + m.autoPlayOverlayVisible.ToStr())
            if m.nextEpisodeInfo <> invalid and not m.autoPlayOverlayVisible
                showAutoPlayOverlay()
            else if not m.fetchingNextEpisode and m.nextEpisodeInfo = invalid and not m.noNextEpisode
                fetchNextEpisode()
            else if m.noNextEpisode and (not m.skipButtonVisible or m.skipButtonType <> "credits")
                showSkipButton("credits")
            end if
        else if not m.skipButtonVisible or m.skipButtonType <> "credits"
            LogEvent("Credits region (non-TV): showing skip credits")
            showSkipButton("credits")
        end if
    else if not inIntro and not inCredits
        if m.skipButtonVisible
            hideSkipButton()
        end if
        if m.autoPlayOverlayVisible
            cancelAutoPlay()
        end if
    end if
end sub

' Show skip button with fade-in animation
sub showSkipButton(markerType as String)
    LogEvent("showSkipButton: " + markerType)
    ' Set button label text
    if markerType = "intro"
        m.skipButtonLabel.text = "Skip Intro"
    else
        m.skipButtonLabel.text = "Skip Credits"
    end if

    m.skipButtonType = markerType
    m.skipButton.visible = true
    m.skipFadeIn.control = "start"
    m.skipButtonVisible = true

    ' Focus management: only take focus if track panel is not open
    if not m.trackPanel.showPanel
        m.skipButton.setFocus(true)
        m.skipButtonFocused = true
        m.skipButtonFocus.color = m.global.constants.FOCUS_RING
        m.skipButtonFocus.visible = true
    else
        m.skipButtonFocused = false
        m.skipButtonFocus.visible = false
    end if
end sub

' Hide skip button with fade-out animation
sub hideSkipButton()
    if not m.skipButtonVisible then return

    m.skipFadeOut.control = "start"
    m.skipButtonVisible = false
    m.skipButtonFocus.visible = false

    ' Return focus to video if we had focus
    if m.skipButtonFocused
        m.skipButtonFocused = false
        m.video.setFocus(true)
    end if
end sub

' Called when fade-out animation completes
sub onSkipFadeOutComplete(event as Object)
    state = event.getData()
    if state = "stopped"
        m.skipButton.visible = false
        m.skipButton.opacity = 0.0
    end if
end sub

' Handle skip button OK press — seek to marker end position
sub handleSkipPress()
    endMs = 0
    if m.skipButtonType = "intro" and m.introMarker <> invalid
        endMs = m.introMarker.endMs
    else if m.skipButtonType = "credits" and m.creditsMarker <> invalid
        endMs = m.creditsMarker.endMs
    else if m.skipButtonType = "credits" and m.duration > 0
        ' Fallback: no credits marker, seek to end
        endMs = m.duration
    end if

    if endMs > 0
        m.video.seek = endMs / 1000
    end if

    hideSkipButton()
end sub

' ========== Auto-play Next Episode ==========

' Fetch next episode in current season via Plex API
sub fetchNextEpisode()
    if m.top.parentRatingKey = "" or m.top.parentRatingKey = invalid then return
    m.fetchingNextEpisode = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/metadata/" + m.top.parentRatingKey + "/children"
    task.observeField("status", "onNextEpisodeLoaded")
    task.control = "run"
    m.nextEpisodeTask = task
end sub

' Parse next episode from season children response
sub onNextEpisodeLoaded(event as Object)
    state = event.getData()
    m.fetchingNextEpisode = false
    if state <> "completed" then return

    response = m.nextEpisodeTask.response
    if response = invalid or response.MediaContainer = invalid then return

    episodes = SafeGet(response.MediaContainer, "Metadata", [])
    if episodes = invalid or episodes.count() = 0
        m.noNextEpisode = true
        return
    end if

    ' Find next episode by index
    currentIndex = m.top.episodeIndex
    nextEp = invalid
    for each ep in episodes
        epIndex = SafeGet(ep, "index", 0)
        if epIndex = currentIndex + 1
            nextEp = ep
            exit for
        end if
    end for

    if nextEp <> invalid
        ratingKeyRaw = SafeGet(nextEp, "ratingKey", "")
        ratingKeyType = type(ratingKeyRaw)
        if ratingKeyType = "roString" or ratingKeyType = "String"
            ratingKey = ratingKeyRaw
        else
            ratingKey = ratingKeyRaw.ToStr()
        end if
        epTitle = SafeGet(nextEp, "title", "Episode " + (currentIndex + 1).ToStr())
        parentIndex = SafeGet(nextEp, "parentIndex", m.top.seasonIndex)
        epIndex = SafeGet(nextEp, "index", currentIndex + 1)
        seasonEp = "S" + parentIndex.ToStr() + " E" + epIndex.ToStr()

        m.nextEpisodeInfo = {
            ratingKey: ratingKey
            mediaKey: "/library/metadata/" + ratingKey
            title: epTitle
            seasonEp: seasonEp
            episodeIndex: epIndex
            parentRatingKey: m.top.parentRatingKey
            seasonIndex: parentIndex
        }

        ' If video already finished while we were fetching, start auto-play now
        if m.video.state = "finished"
            showAutoPlayOverlay()
        else if m.currentPosition <> invalid
            ' If we're currently in credits range, show overlay now
            inCredits = false
            if m.creditsMarker <> invalid
                if m.currentPosition >= m.creditsMarker.startMs and m.currentPosition < m.creditsMarker.endMs
                    inCredits = true
                end if
            else if m.duration > 0 and m.currentPosition >= m.duration - 30000
                inCredits = true
            end if

            if inCredits and not m.autoPlayOverlayVisible
                showAutoPlayOverlay()
            end if
        end if
    else
        ' No next episode in current season - try next season
        if m.top.grandparentRatingKey <> "" and m.top.grandparentRatingKey <> invalid
            fetchNextSeason()
        else
            m.noNextEpisode = true
        end if
    end if
end sub

' Fetch the show's seasons to find the next one after the current season
sub fetchNextSeason()
    m.fetchingNextEpisode = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/metadata/" + m.top.grandparentRatingKey + "/children"
    task.observeField("status", "onSeasonsForNextLoaded")
    task.control = "run"
    m.nextSeasonTask = task
end sub

' Called when seasons list is fetched for season-boundary transition
sub onSeasonsForNextLoaded(event as Object)
    state = event.getData()
    m.fetchingNextEpisode = false
    if state <> "completed" then return

    response = m.nextSeasonTask.response
    if response = invalid or response.MediaContainer = invalid
        m.noNextEpisode = true
        return
    end if

    seasons = SafeGet(response.MediaContainer, "Metadata", [])
    if seasons = invalid or seasons.count() = 0
        m.noNextEpisode = true
        return
    end if

    ' Find current season by parentRatingKey, then get next season
    currentParentKey = m.top.parentRatingKey
    currentSeasonIndex = -1
    for i = 0 to seasons.count() - 1
        season = seasons[i]
        seasonKeyRaw = SafeGet(season, "ratingKey", "")
        seasonKeyType = type(seasonKeyRaw)
        if seasonKeyType = "roString" or seasonKeyType = "String"
            seasonKey = seasonKeyRaw
        else
            seasonKey = seasonKeyRaw.ToStr()
        end if
        if seasonKey = currentParentKey
            currentSeasonIndex = i
            exit for
        end if
    end for

    if currentSeasonIndex = -1 or currentSeasonIndex >= seasons.count() - 1
        ' No next season found
        m.noNextEpisode = true
        return
    end if

    nextSeason = seasons[currentSeasonIndex + 1]
    nextSeasonKeyRaw = SafeGet(nextSeason, "ratingKey", "")
    nextSeasonKeyType = type(nextSeasonKeyRaw)
    if nextSeasonKeyType = "roString" or nextSeasonKeyType = "String"
        nextSeasonKey = nextSeasonKeyRaw
    else
        nextSeasonKey = nextSeasonKeyRaw.ToStr()
    end if

    m.nextSeasonNumber = SafeGet(nextSeason, "index", 0)
    m.nextSeasonKey = nextSeasonKey
    m.fetchingNextEpisode = true

    ' Fetch episodes from the next season
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/metadata/" + nextSeasonKey + "/children"
    task.observeField("status", "onNextSeasonEpisodesLoaded")
    task.control = "run"
    m.nextSeasonEpisodesTask = task
end sub

' Called when next season episodes are fetched
sub onNextSeasonEpisodesLoaded(event as Object)
    state = event.getData()
    m.fetchingNextEpisode = false
    if state <> "completed" then return

    response = m.nextSeasonEpisodesTask.response
    if response = invalid or response.MediaContainer = invalid
        m.noNextEpisode = true
        return
    end if

    episodes = SafeGet(response.MediaContainer, "Metadata", [])
    if episodes = invalid or episodes.count() = 0
        m.noNextEpisode = true
        return
    end if

    ' Take first episode (lowest index)
    firstEp = invalid
    lowestIndex = 99999
    for each ep in episodes
        epIndex = SafeGet(ep, "index", 99999)
        if epIndex < lowestIndex
            lowestIndex = epIndex
            firstEp = ep
        end if
    end for

    if firstEp = invalid
        firstEp = episodes[0]
    end if

    ratingKeyRaw = SafeGet(firstEp, "ratingKey", "")
    ratingKeyType = type(ratingKeyRaw)
    if ratingKeyType = "roString" or ratingKeyType = "String"
        ratingKey = ratingKeyRaw
    else
        ratingKey = ratingKeyRaw.ToStr()
    end if

    epTitle = SafeGet(firstEp, "title", "Episode 1")
    epIndex = SafeGet(firstEp, "index", 1)
    seasonNumber = m.nextSeasonNumber
    seasonEp = "S" + seasonNumber.ToStr() + " E" + epIndex.ToStr()

    m.nextEpisodeInfo = {
        ratingKey: ratingKey
        mediaKey: "/library/metadata/" + ratingKey
        title: epTitle
        seasonEp: seasonEp
        isNewSeason: true
        seasonNumber: seasonNumber
        episodeIndex: epIndex
        parentRatingKey: m.nextSeasonKey
        seasonIndex: seasonNumber
    }

    ' If video already finished while we were fetching, start auto-play now
    if m.video.state = "finished"
        showAutoPlayOverlay()
    else if m.currentPosition <> invalid
        inCredits = false
        if m.creditsMarker <> invalid
            if m.currentPosition >= m.creditsMarker.startMs and m.currentPosition < m.creditsMarker.endMs
                inCredits = true
            end if
        else if m.duration > 0 and m.currentPosition >= m.duration - 30000
            inCredits = true
        end if

        if inCredits and not m.autoPlayOverlayVisible
            showAutoPlayOverlay()
        end if
    end if
end sub

' Show auto-play countdown overlay
sub showAutoPlayOverlay()
    if m.autoPlayOverlayVisible or m.nextEpisodeInfo = invalid then return
    LogEvent("showAutoPlayOverlay: " + m.nextEpisodeInfo.title)

    ' Hide skip button if visible (countdown replaces it)
    if m.skipButtonVisible
        hideSkipButton()
    end if

    ' Set title based on whether it's a new season
    if m.nextEpisodeInfo.isNewSeason = true
        m.autoPlayTitle.text = "Starting Season " + m.nextEpisodeInfo.seasonNumber.ToStr()
    else
        m.autoPlayTitle.text = "Up Next"
    end if

    ' Set episode info
    m.autoPlayEpisodeLabel.text = m.nextEpisodeInfo.seasonEp + " - " + m.nextEpisodeInfo.title
    m.countdownSeconds = 10
    m.autoPlayCountdownLabel.text = "Starting in 10..."

    ' Reset progress bar to full width
    if m.autoPlayProgressFill <> invalid
        m.autoPlayProgressFill.width = 400
    end if

    ' Show overlay with fade-in
    m.autoPlayOverlay.visible = true
    m.autoPlayFadeIn.control = "start"
    m.autoPlayOverlayVisible = true

    ' Start countdown timer
    m.countdownTimer.control = "start"
    m.countdownActive = true

    ' Focus management
    if not m.trackPanel.showPanel
        m.autoPlayOverlay.setFocus(true)
        m.autoPlayFocused = true
        m.autoPlayFocusBorder.color = m.global.constants.FOCUS_RING
        m.autoPlayFocusBorder.visible = true
    else
        m.autoPlayFocused = false
        m.autoPlayFocusBorder.visible = false
    end if
end sub

' Hide auto-play countdown overlay
sub hideAutoPlayOverlay()
    if not m.autoPlayOverlayVisible then return

    m.countdownTimer.control = "stop"
    m.countdownActive = false
    m.autoPlayFadeOut.control = "start"
    m.autoPlayOverlayVisible = false
    m.autoPlayFocusBorder.visible = false

    if m.autoPlayFocused
        m.autoPlayFocused = false
        m.video.setFocus(true)
    end if
end sub

' Called when auto-play fade-out animation completes
sub onAutoPlayFadeOutComplete(event as Object)
    state = event.getData()
    if state = "stopped"
        m.autoPlayOverlay.visible = false
        m.autoPlayOverlay.opacity = 0.0
    end if
end sub

' Countdown tick — update display and trigger auto-play at 0
sub onCountdownTick(event as Object)
    m.countdownSeconds = m.countdownSeconds - 1

    if m.countdownSeconds <= 0
        startNextEpisode()
    else
        m.autoPlayCountdownLabel.text = "Starting in " + m.countdownSeconds.ToStr() + "..."
        ' Update shrinking progress bar (counts down from 10)
        if m.autoPlayProgressFill <> invalid
            m.autoPlayProgressFill.width = Int(400 * (m.countdownSeconds / 10.0))
        end if
    end if
end sub

' Cancel auto-play countdown — dismiss overlay, resume normal playback
sub cancelAutoPlay()
    hideAutoPlayOverlay()
end sub

' Start the next episode — scrobble current, reset, and load next
sub startNextEpisode()
    if m.nextEpisodeInfo = invalid then return

    ' Stop countdown
    m.countdownTimer.control = "stop"
    m.countdownActive = false

    ' Scrobble current episode as watched
    scrobble()

    ' Stop current playback (without triggering playbackComplete)
    m.reportTimer.control = "stop"
    m.video.control = "stop"

    ' Update playback fields for next episode
    m.top.ratingKey = m.nextEpisodeInfo.ratingKey
    m.top.mediaKey = m.nextEpisodeInfo.mediaKey
    m.top.itemTitle = m.nextEpisodeInfo.title
    m.top.startOffset = 0

    ' Update episode/season tracking so the next credits cycle finds the right successor
    if m.nextEpisodeInfo.episodeIndex <> invalid
        m.top.episodeIndex = m.nextEpisodeInfo.episodeIndex
    end if
    if m.nextEpisodeInfo.seasonIndex <> invalid
        m.top.seasonIndex = m.nextEpisodeInfo.seasonIndex
    end if
    if m.nextEpisodeInfo.parentRatingKey <> invalid
        m.top.parentRatingKey = m.nextEpisodeInfo.parentRatingKey
    end if

    ' Signal next episode started
    m.top.nextEpisodeStarted = true

    ' Reset auto-play and marker state
    m.nextEpisodeInfo = invalid
    m.noNextEpisode = false
    m.fetchingNextEpisode = false
    m.introMarker = invalid
    m.creditsMarker = invalid
    m.introSkipped = false
    m.autoPlayOverlayVisible = false
    m.autoPlayFocused = false
    m.autoPlayOverlay.visible = false
    m.autoPlayOverlay.opacity = 0.0
    m.skipButtonVisible = false
    m.skipButton.visible = false
    m.skipButton.opacity = 0.0

    ' Load and start the next episode
    loadMedia()
end sub

' ========== Playlist Sequential Playback ==========

sub advancePlaylist(nextIndex as Integer)
    items = m.top.playlistItems
    nextItem = items[nextIndex]

    ' Stop current playback (without triggering playbackComplete)
    m.video.control = "stop"

    ' Update playback fields for next item
    m.top.ratingKey = nextItem.ratingKey
    m.top.mediaKey = nextItem.mediaKey
    m.top.itemTitle = nextItem.title
    m.top.startOffset = 0
    m.top.playlistIndex = nextIndex

    ' Signal playlist advanced
    m.top.playlistAdvanced = true

    ' Reset marker and auto-play state
    m.introMarker = invalid
    m.creditsMarker = invalid
    m.introSkipped = false
    if m.skipButtonVisible then hideSkipButton()
    if m.autoPlayOverlayVisible then hideAutoPlayOverlay()
    m.nextEpisodeInfo = invalid
    m.noNextEpisode = false
    m.fetchingNextEpisode = false

    ' Load and start the next item
    loadMedia()
end sub

' ========== Key Event Handling ==========

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    c = m.global.constants

    ' Handle auto-play overlay keys (highest priority)
    if m.autoPlayFocused
        LogEvent("Key during auto-play: " + key)
        if key = "OK"
            ' OK during countdown: cancel and show PostPlayScreen
            cancelAutoPlay()
            stopPlayback()
            signalPlaybackComplete("cancelled")
            return true
        else if key = "back"
            ' Back during countdown: cancel and exit to PostPlayScreen
            cancelAutoPlay()
            stopPlayback()
            signalPlaybackComplete("stopped")
            return true
        else if key = "left" or key = "right"
            cancelAutoPlay()
            return true
        end if
    end if

    ' Handle skip button keys (before track panel check)
    if m.skipButtonFocused
        LogEvent("Key during skip button: " + key)
        if key = "OK"
            handleSkipPress()
            return true
        else if key = "back" or key = "left" or key = "right"
            hideSkipButton()
            return true
        end if
    end if

    ' If track panel is visible, let it handle keys
    if m.trackPanel.showPanel
        return false
    end if

    if key = "options"
        ' Toggle track selection panel
        m.trackPanel.showPanel = not m.trackPanel.showPanel
        return true
    else if key = "back"
        stopPlayback()
        signalPlaybackComplete("stopped")
        return true
    end if

    ' All other keys (play, pause, OK, FF, RW, left, right, up, down)
    ' are handled by the Video node's built-in transport/trickplay UI
    return false
end function
