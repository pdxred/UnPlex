' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.yearRuntimeLabel = m.top.findNode("yearRuntimeLabel")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.taglineLabel = m.top.findNode("taglineLabel")
    m.contextLabel = m.top.findNode("contextLabel")
    m.airdateLabel = m.top.findNode("airdateLabel")
    m.castLabel = m.top.findNode("castLabel")
    m.crewLabel = m.top.findNode("crewLabel")
    m.studioLabel = m.top.findNode("studioLabel")
    m.buttonGroup = m.top.findNode("buttonGroup")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    ' Progress bar nodes
    m.detailProgressTrack = m.top.findNode("detailProgressTrack")
    m.detailProgressFill = m.top.findNode("detailProgressFill")
    m.remainingLabel = m.top.findNode("remainingLabel")

    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.constants = m.global.constants
    m.itemData = invalid
    m.viewOffset = 0
    m.buttonActions = []
    m.retryCount = 0
    m.retryContext = invalid

    ' Observe button selection
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")

    ' Observe inline retry button
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")

    ' Observe server reconnected signal
    m.global.observeField("serverReconnected", "onServerReconnected")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    ' When DetailScreen is in focus chain but no child has focus, delegate to buttons
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.buttonGroup.setFocus(true)
    end if
end sub

sub onRatingKeyChange(event as Object)
    ratingKey = event.getData()
    if ratingKey <> "" and ratingKey <> invalid
        loadMetadata(ratingKey)
    end if
end sub

sub loadMetadata(ratingKey as String)
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.retryGroup.visible = false

    endpoint = "/library/metadata/" + ratingKey
    m.retryContext = { endpoint: endpoint, params: {}, handler: "onApiTaskStateChange", ratingKey: ratingKey }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = {}
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.metadataTask = task
end sub

sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.retryCount = 0
        m.retryGroup.visible = false
        processMetadata()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        if m.metadataTask.responseCode < 0
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                m.global.serverUnreachable = true
            end if
        else
            if m.retryCount = 0
                m.retryCount = 1
                retryLastRequest()
            else
                m.retryCount = 0
                showErrorDialog("Error", "Couldn't load details. Please try again.")
            end if
        end if
    end if
end sub

sub processMetadata()
    response = m.metadataTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid or metadata.count() = 0
        return
    end if

    m.itemData = metadata[0]
    item = m.itemData

    ' Set title
    m.titleLabel.text = item.title

    ' Set year and runtime
    yearRuntime = ""
    if item.year <> invalid
        yearRuntime = item.year.ToStr()
    end if
    if item.duration <> invalid
        runtime = FormatTime(item.duration)
        if yearRuntime <> ""
            yearRuntime = yearRuntime + " | " + runtime
        else
            yearRuntime = runtime
        end if
    end if
    m.yearRuntimeLabel.text = yearRuntime

    ' Set rating (API returns string, float, or array depending on item)
    m.ratingLabel.text = ""
    ratingVal = invalid
    if item.contentRating <> invalid
        ' Content rating (PG, R, etc) - always a string
        m.ratingLabel.text = item.contentRating
    else if item.audienceRating <> invalid
        ratingVal = item.audienceRating
    else if item.rating <> invalid
        ratingVal = item.rating
    end if

    if ratingVal <> invalid
        ratingType = type(ratingVal)
        if ratingType = "roString" or ratingType = "String"
            m.ratingLabel.text = "Rating: " + ratingVal
        else if ratingType = "roFloat" or ratingType = "Float" or ratingType = "roDouble" or ratingType = "Double" or ratingType = "roInt" or ratingType = "Integer"
            m.ratingLabel.text = "Rating: " + ratingVal.ToStr()
        end if
        ' Skip arrays - Rating[] is critic review data, not display rating
    end if

    ' Set genres
    if item.Genre <> invalid and item.Genre.count() > 0
        genres = []
        for each genre in item.Genre
            genres.push(genre.tag)
        end for
        m.genreLabel.text = genres.join(", ")
    else
        m.genreLabel.text = ""
    end if

    ' Set summary
    if item.summary <> invalid
        m.summaryLabel.text = item.summary
    else
        m.summaryLabel.text = ""
    end if

    ' Set poster image — portrait for movies/shows, landscape for episodes
    if item.thumb <> invalid and item.thumb <> ""
        if item.type = "movie" or item.type = "show"
            ' Portrait poster
            m.poster.width = 400
            m.poster.height = 600
            m.poster.uri = BuildPosterUrl(item.thumb, 400, 600)
            m.top.findNode("metadataGroup").translation = [520, 80]
        else
            ' Landscape thumbnail (episodes, clips)
            m.poster.width = 640
            m.poster.height = 360
            m.poster.uri = BuildPosterUrl(item.thumb, 640, 360)
            m.top.findNode("metadataGroup").translation = [760, 80]
        end if
        ' Position progress group and buttons below the poster
        posterBottom = 80 + m.poster.height
        m.top.findNode("progressGroup").translation = [80, posterBottom + 10]
        m.top.findNode("buttonGroup").translation = [80, posterBottom + 50]
    end if

    ' Store view offset
    if item.viewOffset <> invalid
        m.viewOffset = item.viewOffset
    else
        m.viewOffset = 0
    end if

    ' Update progress bar and remaining time
    updateDetailProgress()

    ' Populate type-specific metadata
    hideTypeSpecificLabels()
    if item.type = "movie"
        populateMovieMetadata(item)
    else if item.type = "episode"
        populateEpisodeMetadata(item)
    else if item.type = "show"
        populateShowMetadata(item)
    end if
    ' clip/unknown: all type-specific labels stay hidden

    ' Build buttons based on item type
    buildButtons()
    m.buttonGroup.setFocus(true)
end sub

sub updateDetailProgress()
    ' Hide everything by default
    m.detailProgressTrack.visible = false
    m.detailProgressFill.visible = false
    m.remainingLabel.visible = false

    if m.itemData = invalid then return
    if m.itemData.duration = invalid or m.itemData.duration <= 0 then return
    if m.viewOffset <= 0 then return

    progress = m.viewOffset / m.itemData.duration
    if progress < m.constants.PROGRESS_MIN_PERCENT then return

    ' Show progress bar
    m.detailProgressTrack.width = m.poster.width
    m.detailProgressTrack.visible = true
    m.detailProgressFill.visible = true
    m.detailProgressFill.width = Int(m.poster.width * progress)
    m.detailProgressFill.color = m.constants.ACCENT

    ' Calculate remaining time
    remainingMs = m.itemData.duration - m.viewOffset
    remainingMin = remainingMs \ 60000
    if remainingMin < 1
        m.remainingLabel.text = "Less than 1 min remaining"
    else
        m.remainingLabel.text = remainingMin.ToStr() + " min remaining"
    end if
    m.remainingLabel.visible = true
end sub

sub buildButtons()
    buttons = []
    m.buttonActions = []
    item = m.itemData

    if item.type = "show"
        ' TV show - browse seasons
        buttons.push("Browse Seasons")
        m.buttonActions.push("browseSeasons")
    else
        ' Movie or episode - play buttons
        ' Resume appears FIRST when partially watched
        if m.viewOffset > 0
            resumeTime = FormatTime(m.viewOffset)
            buttons.push("Resume from " + resumeTime)
            m.buttonActions.push("resume")
            buttons.push("Play from Beginning")
            m.buttonActions.push("play")
        else
            buttons.push("Play")
            m.buttonActions.push("play")
        end if
    end if

    ' Episode-specific navigation: Go to Show
    if item.type = "episode"
        if item.grandparentRatingKey <> invalid
            buttons.push("Go to Show")
            m.buttonActions.push("goToShow")
        end if
    end if

    ' Watched/Unwatched toggle
    if item.viewCount <> invalid and item.viewCount > 0
        buttons.push("Mark as Unwatched")
        m.buttonActions.push("markUnwatched")
    else
        buttons.push("Mark as Watched")
        m.buttonActions.push("markWatched")
    end if

    ' Get Info — available for movies and episodes
    if item.type = "movie" or item.type = "episode"
        buttons.push("Get Info")
        m.buttonActions.push("getInfo")
    end if

    ' Delete — last to reduce accidental selection
    if item.type = "movie" or item.type = "episode"
        buttons.push("Delete")
        m.buttonActions.push("delete")
    end if

    m.buttonGroup.buttons = buttons
end sub

sub onButtonSelected(event as Object)
    index = event.getData()
    if index < 0 or index >= m.buttonActions.count()
        return
    end if

    action = m.buttonActions[index]

    if action = "play"
        startPlayback(0)
    else if action = "resume"
        startPlayback(m.viewOffset)
    else if action = "browseSeasons"
        m.top.itemSelected = {
            action: "episodes"
            ratingKey: GetRatingKeyStr(m.itemData.ratingKey)
            title: m.itemData.title
        }
    else if action = "goToShow"
        ' Navigate to ShowScreen for the parent show
        m.top.itemSelected = {
            action: "episodes"
            ratingKey: GetRatingKeyStr(m.itemData.grandparentRatingKey)
            title: m.itemData.grandparentTitle
        }
    else if action = "markWatched"
        markAsWatched()
    else if action = "markUnwatched"
        markAsUnwatched()
    else if action = "getInfo"
        m.top.itemSelected = {
            action: "mediaInfo"
            itemData: m.itemData
        }
    else if action = "delete"
        showDeleteConfirmation()
    end if
end sub

sub startPlayback(offset as Integer)
    ' Create video player and start playback
    ratingKeyStr = GetRatingKeyStr(m.itemData.ratingKey)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = ratingKeyStr
    m.player.mediaKey = "/library/metadata/" + ratingKeyStr
    m.player.startOffset = offset
    m.player.itemTitle = m.itemData.title

    ' Wire episode context for auto-play next episode
    if m.itemData.type = "episode"
        if m.itemData.grandparentRatingKey <> invalid
            m.player.grandparentRatingKey = GetRatingKeyStr(m.itemData.grandparentRatingKey)
        end if
        if m.itemData.parentRatingKey <> invalid
            m.player.parentRatingKey = GetRatingKeyStr(m.itemData.parentRatingKey)
        end if
        if m.itemData.index <> invalid
            m.player.episodeIndex = m.itemData.index
        end if
    end if

    m.player.observeField("playbackResult", "onPlaybackResult")
    m.player.observeField("nextEpisodeStarted", "onNextEpisodeStarted")

    ' Add player to scene
    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub

sub onPlaybackResult(event as Object)
    result = event.getData()
    if result = invalid then return

    ' Remove video player from scene
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if

    ' Back-press during playback: return to this screen directly
    if result.reason = "stopped"
        ' Refresh metadata (watch progress may have changed)
        loadMetadata(result.ratingKey)
        ' Restore focus to button group
        m.buttonGroup.setFocus(true)
        return
    end if

    ' All other reasons (finished, cancelled, error): push PostPlayScreen
    m.top.itemSelected = {
        action: "postPlay"
        ratingKey: result.ratingKey
        itemTitle: result.itemTitle
        hasNextEpisode: result.hasNextEpisode
        nextEpisodeInfo: result.nextEpisodeInfo
        grandparentRatingKey: result.grandparentRatingKey
        viewOffset: result.viewOffset
        duration: result.duration
        isPlaylist: result.isPlaylist
    }
end sub

sub onNextEpisodeStarted(event as Object)
    ' No-op: metadata refresh is unnecessary while the fullscreen player is active.
    ' DetailScreen is hidden behind the player and will be refreshed when playback
    ' ends via onPlaybackResult. Removing the duplicate API call that previously
    ' fired here alongside VideoPlayer's own loadMedia() fetch.
end sub

sub markAsWatched()
    ' Optimistic update: change UI immediately
    m.itemData.viewCount = 1
    m.viewOffset = 0
    m.itemData.viewOffset = 0

    ' Hide progress bar and remaining time
    updateDetailProgress()

    ' Rebuild buttons (will now show "Play" instead of "Resume")
    buildButtons()
    m.buttonGroup.setFocus(true)

    ' Propagate watch state change to parent screen via global
    watchUpdate = {
        ratingKey: GetRatingKeyStr(m.itemData.ratingKey)
        viewCount: 1
        viewOffset: 0
    }
    m.top.watchStateChanged = watchUpdate
    m.global.watchStateUpdate = watchUpdate

    ' Fire API call
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": GetRatingKeyStr(m.itemData.ratingKey)
    }
    task.control = "run"
    task.observeField("status", "onWatchedStateChange")
    m.watchedTask = task
end sub

sub markAsUnwatched()
    ' Optimistic update: change UI immediately
    m.itemData.viewCount = 0

    ' Rebuild buttons (will now show "Mark as Watched" instead of "Mark as Unwatched")
    buildButtons()
    m.buttonGroup.setFocus(true)

    ' Propagate watch state change to parent screen via global
    watchUpdate = {
        ratingKey: GetRatingKeyStr(m.itemData.ratingKey)
        viewCount: 0
        viewOffset: m.viewOffset
    }
    m.top.watchStateChanged = watchUpdate
    m.global.watchStateUpdate = watchUpdate

    ' Fire API call
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/unscrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": GetRatingKeyStr(m.itemData.ratingKey)
    }
    task.control = "run"
    task.observeField("status", "onWatchedStateChange")
    m.watchedTask = task
end sub

sub onWatchedStateChange(event as Object)
    status = event.getData()
    if status = "error"
        ' Show brief error - optimistic update already applied
        showError("Failed to update watch state. Changes may not be saved.")
    end if
    ' On success, do nothing - optimistic update already applied
end sub

sub showDeleteConfirmation()
    if m.top.getScene().dialog <> invalid then return

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Delete Media"
    dialog.message = ["This will permanently delete this media from your Plex library. This action cannot be undone."]
    dialog.buttons = ["Delete", "Cancel"]
    dialog.observeField("buttonSelected", "onDeleteDialogButton")
    dialog.observeField("wasClosed", "onDeleteDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onDeleteDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        ' User confirmed delete — fire DELETE request
        executeDelete()
    end if
    ' index = 1 (Cancel) — dialog already closed, nothing else to do
end sub

sub executeDelete()
    ratingKeyStr = GetRatingKeyStr(m.itemData.ratingKey)
    LogEvent("Deleting media: /library/metadata/" + ratingKeyStr)

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/metadata/" + ratingKeyStr
    task.method = "DELETE"
    task.observeField("status", "onDeleteTaskComplete")
    task.control = "run"
    m.deleteTask = task
end sub

sub onDeleteDialogClosed(event as Object)
    m.buttonGroup.setFocus(true)
end sub

sub onDeleteTaskComplete(event as Object)
    status = event.getData()
    if status = "completed"
        LogEvent("Delete successful, navigating back")
        m.top.navigateBack = true
    else if status = "error"
        if m.deleteTask.responseCode = 403
            LogError("Delete failed: 403 - media deletion not enabled")
            showError("Media deletion is not enabled on this server. Enable it in Plex Media Server settings.")
        else
            LogError("Delete failed: " + m.deleteTask.error)
            showDeleteRetryDialog()
        end if
    end if
end sub

sub showDeleteRetryDialog()
    if m.top.getScene().dialog <> invalid then return

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Delete Failed"
    dialog.message = ["Could not delete this media. Please try again."]
    dialog.buttons = ["Retry", "Dismiss"]
    dialog.observeField("buttonSelected", "onDeleteRetryButton")
    dialog.observeField("wasClosed", "onDeleteRetryDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onDeleteRetryButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        executeDelete()
    end if
end sub

sub onDeleteRetryDialogClosed(event as Object)
    m.buttonGroup.setFocus(true)
end sub

sub retryLastRequest()
    if m.retryContext = invalid then return
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.retryContext.endpoint
    task.params = m.retryContext.params
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.metadataTask = task
end sub

sub showErrorDialog(title as String, message as String)
    if m.top.getScene().dialog <> invalid then return

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = title
    dialog.message = [message]
    dialog.buttons = ["Retry", "Dismiss"]
    dialog.observeField("buttonSelected", "onErrorDialogButton")
    dialog.observeField("wasClosed", "onErrorDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onErrorDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        retryLastRequest()
    else if index = 1
        showInlineRetry()
    end if
end sub

sub onErrorDialogClosed(event as Object)
    m.buttonGroup.setFocus(true)
end sub

sub showInlineRetry()
    m.poster.visible = false
    m.top.findNode("metadataGroup").visible = false
    m.top.findNode("progressGroup").visible = false
    m.buttonGroup.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.poster.visible = true
    m.top.findNode("metadataGroup").visible = true
    m.top.findNode("progressGroup").visible = true
    m.buttonGroup.visible = true
    retryLastRequest()
end sub

sub onServerReconnected(event as Object)
    if m.global.serverReconnected = true
        m.global.serverReconnected = false
        if m.top.ratingKey <> "" and m.top.ratingKey <> invalid
            loadMetadata(m.top.ratingKey)
        end if
    end if
end sub

sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog
end sub

sub hideTypeSpecificLabels()
    m.taglineLabel.visible = false
    m.contextLabel.visible = false
    m.airdateLabel.visible = false
    m.castLabel.visible = false
    m.crewLabel.visible = false
    m.studioLabel.visible = false
end sub

sub populateMovieMetadata(item as Object)
    ' Tagline
    if item.tagline <> invalid and item.tagline <> ""
        m.taglineLabel.text = item.tagline
        m.taglineLabel.visible = true
    end if

    ' Cast — up to 5 Role[] names
    if item.Role <> invalid and item.Role.count() > 0
        castNames = []
        maxCast = item.Role.count()
        if maxCast > 5 then maxCast = 5
        for i = 0 to maxCast - 1
            role = item.Role[i]
            if role <> invalid and role.tag <> invalid and role.tag <> ""
                castNames.push(role.tag)
            end if
        end for
        if castNames.count() > 0
            m.castLabel.text = "Cast: " + castNames.join(", ")
            m.castLabel.visible = true
        end if
    end if

    ' Director and Writer — build crew line
    directorName = ""
    writerName = ""

    if item.Director <> invalid and item.Director.count() > 0
        firstDirector = item.Director[0]
        if firstDirector <> invalid and firstDirector.tag <> invalid
            directorName = firstDirector.tag
        end if
    end if

    if item.Writer <> invalid and item.Writer.count() > 0
        firstWriter = item.Writer[0]
        if firstWriter <> invalid and firstWriter.tag <> invalid
            writerName = firstWriter.tag
        end if
    end if

    crewText = ""
    if directorName <> ""
        crewText = "Directed by " + directorName
    end if
    if writerName <> ""
        if crewText <> ""
            crewText = crewText + " · Written by " + writerName
        else
            crewText = "Written by " + writerName
        end if
    end if

    if crewText <> ""
        m.crewLabel.text = crewText
        m.crewLabel.visible = true
    end if

    ' Studio
    if item.studio <> invalid and item.studio <> ""
        m.studioLabel.text = item.studio
        m.studioLabel.visible = true
    end if
end sub

sub populateEpisodeMetadata(item as Object)
    ' Context line: "S{parentIndex} · E{index} — {grandparentTitle}"
    contextParts = []
    if item.parentIndex <> invalid
        contextParts.push("S" + item.parentIndex.ToStr())
    end if
    if item.index <> invalid
        contextParts.push("E" + item.index.ToStr())
    end if

    contextText = contextParts.join(" · ")

    if item.grandparentTitle <> invalid and item.grandparentTitle <> ""
        if contextText <> ""
            contextText = contextText + " — " + item.grandparentTitle
        else
            contextText = item.grandparentTitle
        end if
    end if

    if contextText <> ""
        m.contextLabel.text = contextText
        m.contextLabel.visible = true
    end if

    ' Air date
    if item.originallyAvailableAt <> invalid and item.originallyAvailableAt <> ""
        formatted = FormatDate(item.originallyAvailableAt)
        m.airdateLabel.text = "Aired: " + formatted
        m.airdateLabel.visible = true
    end if
end sub

sub populateShowMetadata(item as Object)
    ' Context line: "{childCount} Seasons · {leafCount} Episodes"
    showParts = []
    if item.childCount <> invalid
        showParts.push(item.childCount.ToStr() + " Seasons")
    end if
    if item.leafCount <> invalid
        showParts.push(item.leafCount.ToStr() + " Episodes")
    end if

    if showParts.count() > 0
        m.contextLabel.text = showParts.join(" · ")
        m.contextLabel.visible = true
    end if

    ' Studio
    if item.studio <> invalid and item.studio <> ""
        m.studioLabel.text = item.studio
        m.studioLabel.visible = true
    end if
end sub

function FormatDate(dateStr as String) as String
    if dateStr = invalid or dateStr = ""
        return dateStr
    end if

    parts = dateStr.split("-")
    if parts.count() <> 3
        return dateStr
    end if

    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    yearStr = parts[0]
    monthStr = parts[1]
    dayStr = parts[2]

    monthNum = monthStr.ToInt()
    if monthNum < 1 or monthNum > 12
        return dateStr
    end if

    monthName = months[monthNum - 1]

    ' Strip leading zero from day
    dayNum = dayStr.ToInt()
    if dayNum < 1 or dayNum > 31
        return dateStr
    end if

    return monthName + " " + dayNum.ToStr() + ", " + yearStr
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
