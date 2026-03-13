sub init()
    m.showTitleLabel = m.top.findNode("showTitleLabel")
    m.seasonList = m.top.findNode("seasonList")
    m.episodeList = m.top.findNode("episodeList")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.emptyState = m.top.findNode("emptyState")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.seasons = []
    m.currentSeasonIndex = 0
    m.focusOnSeasons = true
    m.retryCount = 0
    m.retryContext = invalid

    ' Observe inline retry button
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")

    ' Observe server reconnected signal
    m.global.observeField("serverReconnected", "onServerReconnected")

    ' Observe watch state updates from DetailScreen
    m.global.observeField("watchStateUpdate", "onWatchStateUpdate")

    ' Observe season selection
    m.seasonList.observeField("itemFocused", "onSeasonFocused")
    m.seasonList.observeField("itemSelected", "onSeasonSelected")

    ' Observe episode selection
    m.episodeList.observeField("itemSelected", "onEpisodeSelected")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    ' When EpisodeScreen is in focus chain but no child has focus, delegate
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        if m.focusOnSeasons
            m.seasonList.setFocus(true)
        else
            m.episodeList.setFocus(true)
        end if
    end if
end sub

sub onRatingKeyChange(event as Object)
    ratingKey = event.getData()
    if ratingKey <> "" and ratingKey <> invalid
        m.showTitleLabel.text = m.top.showTitle
        loadSeasons(ratingKey)
    end if
end sub

sub loadSeasons(ratingKey as String)
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.retryGroup.visible = false

    endpoint = "/library/metadata/" + ratingKey + "/children"
    m.retryContext = { endpoint: endpoint, params: {}, handler: "onSeasonsTaskStateChange", requestType: "seasons" }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = {}
    task.observeField("status", "onSeasonsTaskStateChange")
    task.control = "run"
    m.seasonsTask = task
end sub

sub loadEpisodes(seasonKey as String)
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false
    m.retryGroup.visible = false

    endpoint = "/library/metadata/" + seasonKey + "/children"
    m.retryContext = { endpoint: endpoint, params: {}, handler: "onEpisodesTaskStateChange", requestType: "episodes" }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = {}
    task.observeField("status", "onEpisodesTaskStateChange")
    task.control = "run"
    m.episodesTask = task
end sub

sub onSeasonsTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.retryCount = 0
        m.retryGroup.visible = false
        processSeasons()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        currentTask = m.seasonsTask
        if currentTask.responseCode < 0
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
                showErrorDialog("Error", "Couldn't load episodes. Please try again.")
            end if
        end if
    end if
end sub

sub onEpisodesTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.retryCount = 0
        m.retryGroup.visible = false
        processEpisodes()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        currentTask = m.episodesTask
        if currentTask.responseCode < 0
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
                showErrorDialog("Error", "Couldn't load episodes. Please try again.")
            end if
        end if
    end if
end sub

sub processSeasons()
    response = m.seasonsTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid or metadata.count() = 0
        m.emptyState.visible = true
        return
    end if

    m.emptyState.visible = false
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
        season = m.seasons[0]
        ' Ensure ratingKey is string
        seasonKey = ""
        if season.ratingKey <> invalid
            if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
                seasonKey = season.ratingKey
            else
                seasonKey = season.ratingKey.ToStr()
            end if
        end if
        loadEpisodes(seasonKey)
    end if

    m.seasonList.setFocus(true)
end sub

sub processEpisodes()
    response = m.episodesTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid
        metadata = []
    end if

    if metadata.count() = 0
        m.emptyState.visible = true
        m.episodeList.content = invalid
        return
    end if

    m.emptyState.visible = false
    c = m.global.constants
    content = CreateObject("roSGNode", "ContentNode")

    for each episode in metadata
        node = content.createChild("ContentNode")
        ' Ensure ratingKey is stored as string
        ratingKeyStr = ""
        if episode.ratingKey <> invalid
            if type(episode.ratingKey) = "roString" or type(episode.ratingKey) = "String"
                ratingKeyStr = episode.ratingKey
            else
                ratingKeyStr = episode.ratingKey.ToStr()
            end if
        end if

        node.addFields({
            title: episode.title
            ratingKey: ratingKeyStr
            episodeNumber: 0
            summary: ""
            duration: 0
            thumb: ""
            viewOffset: 0
            watched: false
            viewCount: 0
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
        if episode.viewCount <> invalid
            node.viewCount = episode.viewCount
            if episode.viewCount > 0
                node.watched = true
            end if
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
        season = m.seasons[index]
        ' Ensure ratingKey is string
        seasonKey = ""
        if season.ratingKey <> invalid
            if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
                seasonKey = season.ratingKey
            else
                seasonKey = season.ratingKey.ToStr()
            end if
        end if
        loadEpisodes(seasonKey)
    end if
end sub

sub onSeasonSelected(event as Object)
    ' When season is selected, move focus to episode list
    m.focusOnSeasons = false
    m.episodeList.setFocus(true)
end sub

sub onEpisodeSelected(event as Object)
    index = event.getData()
    content = m.episodeList.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        episode = content.getChild(index)
        c = m.global.constants

        ' Check if partially watched (viewOffset > 0 and >= 5% progress)
        if episode.viewOffset > 0 and episode.duration > 0
            progress = episode.viewOffset / episode.duration
            if progress >= c.PROGRESS_MIN_PERCENT
                showResumeDialog(episode)
                return
            end if
        end if

        startPlayback(episode, episode.viewOffset)
    end if
end sub

' ========== Resume Dialog ==========

sub showResumeDialog(episode as Object)
    m.pendingPlayItem = episode

    resumeTime = FormatTime(episode.viewOffset)

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = episode.title
    dialog.message = ["Resume from " + resumeTime + "?"]
    dialog.buttons = ["Resume from " + resumeTime, "Start from Beginning", "Go to Details"]
    dialog.observeField("buttonSelected", "onResumeDialogButton")
    dialog.observeField("wasClosed", "onResumeDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onResumeDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        ' Resume from last position
        startPlayback(m.pendingPlayItem, m.pendingPlayItem.viewOffset)
    else if index = 1
        ' Start from beginning
        startPlayback(m.pendingPlayItem, 0)
    else if index = 2
        ' Go to detail screen
        m.top.itemSelected = {
            action: "detail"
            ratingKey: m.pendingPlayItem.ratingKey
            itemType: "episode"
        }
    end if
end sub

sub onResumeDialogClosed(event as Object)
    m.episodeList.setFocus(true)
end sub

' ========== Options Key Context Menu ==========

sub showEpisodeOptionsMenu(episode as Object)
    m.pendingOptionsItem = episode

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = episode.title

    if episode.viewCount <> invalid and episode.viewCount > 0
        watchedLabel = "Mark as Unwatched"
    else
        watchedLabel = "Mark as Watched"
    end if

    dialog.buttons = [watchedLabel, "Cancel"]
    dialog.observeField("buttonSelected", "onEpisodeOptionsButton")
    dialog.observeField("wasClosed", "onEpisodeOptionsClosed")
    m.top.getScene().dialog = dialog
end sub

sub onEpisodeOptionsButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        ' Toggle watched state
        episode = m.pendingOptionsItem
        task = CreateObject("roSGNode", "PlexApiTask")
        if episode.viewCount <> invalid and episode.viewCount > 0
            ' Mark as unwatched - optimistic update
            episode.viewCount = 0
            episode.viewOffset = 0
            episode.watched = false
            task.endpoint = "/:/unscrobble"
        else
            ' Mark as watched - optimistic update
            episode.viewCount = 1
            episode.viewOffset = 0
            episode.watched = true
            task.endpoint = "/:/scrobble"
        end if
        task.params = {
            "identifier": "com.plexapp.plugins.library"
            "key": episode.ratingKey
        }
        task.control = "run"

        ' Force episode list re-render
        m.episodeList.content = m.episodeList.content
    end if

    m.episodeList.setFocus(true)
end sub

sub onEpisodeOptionsClosed(event as Object)
    m.episodeList.setFocus(true)
end sub

sub startPlayback(episode as Object, offset as Integer)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = episode.ratingKey
    m.player.mediaKey = "/library/metadata/" + episode.ratingKey
    m.player.startOffset = offset
    m.player.itemTitle = episode.title

    ' Set fields needed for auto-play next episode
    m.player.grandparentRatingKey = m.top.ratingKey  ' Show ratingKey
    if m.seasons.count() > m.currentSeasonIndex
        season = m.seasons[m.currentSeasonIndex]
        seasonKey = ""
        if season.ratingKey <> invalid
            if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
                seasonKey = season.ratingKey
            else
                seasonKey = season.ratingKey.ToStr()
            end if
        end if
        m.player.parentRatingKey = seasonKey  ' Season ratingKey
    end if
    if episode.episodeNumber <> invalid
        m.player.episodeIndex = episode.episodeNumber
    end if
    m.player.seasonIndex = m.currentSeasonIndex

    m.player.observeField("playbackComplete", "onPlaybackComplete")
    m.player.observeField("nextEpisodeStarted", "onNextEpisodeStarted")

    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub

sub onNextEpisodeStarted(event as Object)
    ' Refresh episode list when auto-play advances to next episode
    if m.seasons.count() > m.currentSeasonIndex
        season = m.seasons[m.currentSeasonIndex]
        seasonKey = ""
        if season.ratingKey <> invalid
            if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
                seasonKey = season.ratingKey
            else
                seasonKey = season.ratingKey.ToStr()
            end if
        end if
        loadEpisodes(seasonKey)
    end if
end sub

sub onPlaybackComplete(event as Object)
    ' Remove video player
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if

    ' TODO: Auto-play next episode with countdown
    m.episodeList.setFocus(true)

    ' Refresh episode list to update watched status
    if m.seasons.count() > m.currentSeasonIndex
        season = m.seasons[m.currentSeasonIndex]
        seasonKey = ""
        if season.ratingKey <> invalid
            if type(season.ratingKey) = "roString" or type(season.ratingKey) = "String"
                seasonKey = season.ratingKey
            else
                seasonKey = season.ratingKey.ToStr()
            end if
        end if
        loadEpisodes(seasonKey)
    end if
end sub

sub retryLastRequest()
    if m.retryContext = invalid then return
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.retryContext.endpoint
    task.params = m.retryContext.params
    if m.retryContext.requestType = "seasons"
        task.observeField("status", "onSeasonsTaskStateChange")
        m.seasonsTask = task
    else
        task.observeField("status", "onEpisodesTaskStateChange")
        m.episodesTask = task
    end if
    task.control = "run"
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
    if m.focusOnSeasons
        m.seasonList.setFocus(true)
    else
        m.episodeList.setFocus(true)
    end if
end sub

sub showInlineRetry()
    m.seasonList.visible = false
    m.episodeList.visible = false
    m.emptyState.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.seasonList.visible = true
    m.episodeList.visible = true
    retryLastRequest()
end sub

sub onServerReconnected(event as Object)
    if m.global.serverReconnected = true
        m.global.serverReconnected = false
        if m.top.ratingKey <> "" and m.top.ratingKey <> invalid
            loadSeasons(m.top.ratingKey)
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

sub onWatchStateUpdate(event as Object)
    update = event.getData()
    if update = invalid or update.ratingKey = invalid then return

    ratingKey = update.ratingKey
    viewCount = update.viewCount

    ' Update matching episode in episode list
    if m.episodeList.content <> invalid
        for i = 0 to m.episodeList.content.getChildCount() - 1
            item = m.episodeList.content.getChild(i)
            if item <> invalid and item.ratingKey = ratingKey
                item.viewCount = viewCount
                item.watched = (viewCount > 0)
                if update.viewOffset <> invalid
                    item.viewOffset = update.viewOffset
                end if
            end if
        end for
    end if
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
    else if key = "options" and not m.focusOnSeasons
        ' Show context menu for focused episode
        focusedIndex = m.episodeList.itemFocused
        content = m.episodeList.content
        if content <> invalid and focusedIndex >= 0 and focusedIndex < content.getChildCount()
            episode = content.getChild(focusedIndex)
            showEpisodeOptionsMenu(episode)
            return true
        end if
    end if

    return false
end function
