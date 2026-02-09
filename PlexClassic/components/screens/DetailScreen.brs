sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.yearRuntimeLabel = m.top.findNode("yearRuntimeLabel")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.buttonGroup = m.top.findNode("buttonGroup")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.itemData = invalid
    m.viewOffset = 0
    m.buttonActions = []

    ' Set up API task
    m.apiTask = CreateObject("roSGNode", "PlexApiTask")
    m.apiTask.observeField("state", "onApiTaskStateChange")

    ' Observe button selection
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")
end sub

sub onRatingKeyChange(event as Object)
    ratingKey = event.getData()
    if ratingKey <> "" and ratingKey <> invalid
        loadMetadata(ratingKey)
    end if
end sub

sub loadMetadata(ratingKey as String)
    m.loadingSpinner.visible = true
    m.apiTask.endpoint = "/library/metadata/" + ratingKey
    m.apiTask.params = {}
    m.apiTask.control = "run"
end sub

sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.visible = false
        processMetadata()
    else if state = "error"
        m.loadingSpinner.visible = false
        showError(m.apiTask.error)
    end if
end sub

sub processMetadata()
    response = m.apiTask.response
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

    ' Set rating
    if item.rating <> invalid
        m.ratingLabel.text = "Rating: " + item.rating.ToStr()
    else if item.audienceRating <> invalid
        m.ratingLabel.text = "Rating: " + item.audienceRating.ToStr()
    else
        m.ratingLabel.text = ""
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
    c = GetConstants()
    if item.thumb <> invalid and item.thumb <> ""
        m.poster.uri = BuildPosterUrl(item.thumb, 400, 600)
    end if

    ' Store view offset
    if item.viewOffset <> invalid
        m.viewOffset = item.viewOffset
    else
        m.viewOffset = 0
    end if

    ' Build buttons based on item type
    buildButtons()
    m.buttonGroup.setFocus(true)
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
        buttons.push("Play")
        m.buttonActions.push("play")

        if m.viewOffset > 0
            resumeTime = FormatTime(m.viewOffset)
            buttons.push("Resume from " + resumeTime)
            m.buttonActions.push("resume")
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
            ratingKey: m.itemData.ratingKey
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
    player = CreateObject("roSGNode", "VideoPlayer")
    player.ratingKey = m.itemData.ratingKey
    player.mediaKey = "/library/metadata/" + m.itemData.ratingKey
    player.startOffset = offset
    player.itemTitle = m.itemData.title
    player.observeField("playbackComplete", "onPlaybackComplete")

    ' Add player to scene
    m.top.getScene().appendChild(player)
    player.setFocus(true)
    player.control = "play"
end sub

sub onPlaybackComplete(event as Object)
    ' Remove video player and refresh metadata
    players = m.top.getScene().findNode("VideoPlayer")
    if players <> invalid
        m.top.getScene().removeChild(players)
    end if
    m.buttonGroup.setFocus(true)
    ' Refresh to update watched status
    loadMetadata(m.top.ratingKey)
end sub

sub markAsWatched()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": m.itemData.ratingKey
    }
    task.control = "run"
    task.observeField("state", "onWatchedStateChange")
end sub

sub markAsUnwatched()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/unscrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": m.itemData.ratingKey
    }
    task.control = "run"
    task.observeField("state", "onWatchedStateChange")
end sub

sub onWatchedStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        ' Refresh metadata to update button
        loadMetadata(m.top.ratingKey)
    end if
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
