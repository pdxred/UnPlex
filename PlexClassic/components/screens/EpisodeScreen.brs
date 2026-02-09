sub init()
    m.showTitleLabel = m.top.findNode("showTitleLabel")
    m.seasonList = m.top.findNode("seasonList")
    m.episodeList = m.top.findNode("episodeList")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.seasons = []
    m.currentSeasonIndex = 0
    m.focusOnSeasons = true

    ' Set up API task
    m.apiTask = CreateObject("roSGNode", "PlexApiTask")
    m.apiTask.observeField("state", "onApiTaskStateChange")

    ' Observe season selection
    m.seasonList.observeField("itemFocused", "onSeasonFocused")

    ' Observe episode selection
    m.episodeList.observeField("itemSelected", "onEpisodeSelected")
end sub

sub onRatingKeyChange(event as Object)
    ratingKey = event.getData()
    if ratingKey <> "" and ratingKey <> invalid
        m.showTitleLabel.text = m.top.showTitle
        loadSeasons(ratingKey)
    end if
end sub

sub loadSeasons(ratingKey as String)
    m.loadingSpinner.visible = true
    m.apiTask.endpoint = "/library/metadata/" + ratingKey + "/children"
    m.apiTask.params = {}
    m.apiTask.requestId = "seasons"
    m.apiTask.control = "run"
end sub

sub loadEpisodes(seasonKey as String)
    m.loadingSpinner.visible = true
    m.apiTask.endpoint = "/library/metadata/" + seasonKey + "/children"
    m.apiTask.params = {}
    m.apiTask.requestId = "episodes"
    m.apiTask.control = "run"
end sub

sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        m.loadingSpinner.visible = false
        if m.apiTask.requestId = "seasons"
            processSeasons()
        else if m.apiTask.requestId = "episodes"
            processEpisodes()
        end if
    else if state = "error"
        m.loadingSpinner.visible = false
        showError(m.apiTask.error)
    end if
end sub

sub processSeasons()
    response = m.apiTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid or metadata.count() = 0
        return
    end if

    m.seasons = metadata
    seasonTitles = []
    for each season in metadata
        seasonTitles.push(season.title)
    end for

    content = CreateObject("roSGNode", "ContentNode")
    for each title in seasonTitles
        item = content.createChild("ContentNode")
        item.title = title
    end for
    m.seasonList.content = content

    ' Load first season's episodes
    if m.seasons.count() > 0
        m.currentSeasonIndex = 0
        loadEpisodes(m.seasons[0].ratingKey)
    end if

    m.seasonList.setFocus(true)
end sub

sub processEpisodes()
    response = m.apiTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid
        metadata = []
    end if

    c = GetConstants()
    content = CreateObject("roSGNode", "ContentNode")

    for each episode in metadata
        node = content.createChild("ContentNode")
        node.addFields({
            title: episode.title
            ratingKey: episode.ratingKey
            episodeNumber: 0
            summary: ""
            duration: 0
            thumb: ""
            viewOffset: 0
            watched: false
        })

        if episode.index <> invalid
            node.episodeNumber = episode.index
        end if
        if episode.summary <> invalid
            node.summary = episode.summary
        end if
        if episode.duration <> invalid
            node.duration = episode.duration
        end if
        if episode.thumb <> invalid
            node.thumb = BuildPosterUrl(episode.thumb, 320, 180)
        end if
        if episode.viewOffset <> invalid
            node.viewOffset = episode.viewOffset
        end if
        if episode.viewCount <> invalid and episode.viewCount > 0
            node.watched = true
        end if

        ' Format title with episode number
        node.title = "E" + node.episodeNumber.ToStr() + " - " + episode.title
    end for

    m.episodeList.content = content
end sub

sub onSeasonFocused(event as Object)
    index = event.getData()
    if index >= 0 and index < m.seasons.count() and index <> m.currentSeasonIndex
        m.currentSeasonIndex = index
        loadEpisodes(m.seasons[index].ratingKey)
    end if
end sub

sub onEpisodeSelected(event as Object)
    index = event.getData()
    content = m.episodeList.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        episode = content.getChild(index)
        startPlayback(episode)
    end if
end sub

sub startPlayback(episode as Object)
    player = CreateObject("roSGNode", "VideoPlayer")
    player.ratingKey = episode.ratingKey
    player.mediaKey = "/library/metadata/" + episode.ratingKey
    player.startOffset = episode.viewOffset
    player.itemTitle = episode.title
    player.observeField("playbackComplete", "onPlaybackComplete")

    m.top.getScene().appendChild(player)
    player.setFocus(true)
    player.control = "play"
end sub

sub onPlaybackComplete(event as Object)
    ' Remove video player
    player = m.top.getScene().findNode("VideoPlayer")
    if player <> invalid
        m.top.getScene().removeChild(player)
    end if

    ' TODO: Auto-play next episode with countdown
    m.episodeList.setFocus(true)

    ' Refresh episode list to update watched status
    if m.seasons.count() > m.currentSeasonIndex
        loadEpisodes(m.seasons[m.currentSeasonIndex].ratingKey)
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
    else if key = "down" and m.focusOnSeasons
        m.focusOnSeasons = false
        m.episodeList.setFocus(true)
        return true
    else if key = "up" and not m.focusOnSeasons
        m.focusOnSeasons = true
        m.seasonList.setFocus(true)
        return true
    end if

    return false
end function
