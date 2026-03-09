sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.yearRuntimeLabel = m.top.findNode("yearRuntimeLabel")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.buttonGroup = m.top.findNode("buttonGroup")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    ' Progress bar nodes
    m.detailProgressTrack = m.top.findNode("detailProgressTrack")
    m.detailProgressFill = m.top.findNode("detailProgressFill")
    m.remainingLabel = m.top.findNode("remainingLabel")

    m.constants = m.global.constants
    m.itemData = invalid
    m.viewOffset = 0
    m.buttonActions = []

    ' Observe button selection
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")

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
    m.loadingSpinner.visible = true
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/metadata/" + ratingKey
    task.params = {}
    task.observeField("status", "onApiTaskStateChange")
    task.control = "run"
    m.metadataTask = task
end sub

sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.visible = false
        processMetadata()
    else if state = "error"
        m.loadingSpinner.visible = false
        showError(m.metadataTask.error)
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

    ' Set poster
    if item.thumb <> invalid and item.thumb <> ""
        m.poster.uri = BuildPosterUrl(item.thumb, 400, 600)
    end if

    ' Store view offset
    if item.viewOffset <> invalid
        m.viewOffset = item.viewOffset
    else
        m.viewOffset = 0
    end if

    ' Update progress bar and remaining time
    updateDetailProgress()

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
    m.detailProgressTrack.visible = true
    m.detailProgressFill.visible = true
    m.detailProgressFill.width = Int(400 * progress)
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

    ' Watched/Unwatched toggle
    if item.viewCount <> invalid and item.viewCount > 0
        buttons.push("Mark as Unwatched")
        m.buttonActions.push("markUnwatched")
    else
        buttons.push("Mark as Watched")
        m.buttonActions.push("markWatched")
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
            ratingKey: getRatingKeyString(m.itemData.ratingKey)
            title: m.itemData.title
        }
    else if action = "markWatched"
        markAsWatched()
    else if action = "markUnwatched"
        markAsUnwatched()
    end if
end sub

sub startPlayback(offset as Integer)
    ' Create video player and start playback
    ratingKeyStr = getRatingKeyString(m.itemData.ratingKey)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = ratingKeyStr
    m.player.mediaKey = "/library/metadata/" + ratingKeyStr
    m.player.startOffset = offset
    m.player.itemTitle = m.itemData.title
    m.player.observeField("playbackComplete", "onPlaybackComplete")

    ' Add player to scene
    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub

sub onPlaybackComplete(event as Object)
    ' Remove video player and refresh metadata
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if
    m.buttonGroup.setFocus(true)
    ' Refresh to update watched status after playback
    loadMetadata(m.top.ratingKey)
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

    ' Propagate watch state change to parent screen
    m.top.watchStateChanged = {
        ratingKey: getRatingKeyString(m.itemData.ratingKey)
        viewCount: 1
        viewOffset: 0
    }

    ' Fire API call
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": getRatingKeyString(m.itemData.ratingKey)
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

    ' Propagate watch state change to parent screen
    m.top.watchStateChanged = {
        ratingKey: getRatingKeyString(m.itemData.ratingKey)
        viewCount: 0
        viewOffset: m.viewOffset
    }

    ' Fire API call
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/unscrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": getRatingKeyString(m.itemData.ratingKey)
    }
    task.control = "run"
    task.observeField("status", "onWatchedStateChange")
    m.watchedTask = task
end sub

function getRatingKeyString(ratingKey as Dynamic) as String
    if ratingKey = invalid then return ""
    if type(ratingKey) = "roString" or type(ratingKey) = "String"
        return ratingKey
    else
        return ratingKey.ToStr()
    end if
end function

sub onWatchedStateChange(event as Object)
    status = event.getData()
    if status = "error"
        ' Show brief error - optimistic update already applied
        showError("Failed to update watch state. Changes may not be saved.")
    end if
    ' On success, do nothing - optimistic update already applied
end sub

sub showError(message as String)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Error"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    m.top.getScene().dialog = dialog
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
