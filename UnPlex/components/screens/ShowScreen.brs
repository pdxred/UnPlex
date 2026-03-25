sub init()
    m.showTitleLabel = m.top.findNode("showTitleLabel")
    m.seasonRow = m.top.findNode("seasonRow")
    m.episodeGrid = m.top.findNode("episodeGrid")
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

    ' Observe watch state updates
    m.global.observeField("watchStateUpdate", "onWatchStateUpdate")

    ' Observe season selection and focus (PosterGrid bubbles these up)
    m.seasonRow.observeField("itemSelected", "onSeasonSelected")
    m.seasonRow.observeField("itemFocused", "onSeasonFocused")

    ' Observe episode selection
    m.episodeGrid.observeField("itemSelected", "onEpisodeSelected")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    ' When ShowScreen is in focus chain but no child has focus, delegate
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        if m.focusOnSeasons
            m.seasonRow.setFocus(true)
        else
            m.episodeGrid.setFocus(true)
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

' ========== Data Loading ==========

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

' ========== Task Callbacks ==========

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
                showErrorDialog("Error", "Couldn't load seasons. Please try again.")
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

' ========== Data Processing ==========

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

    content = CreateObject("roSGNode", "ContentNode")
    targetIndex = 0
    foundUnwatched = false

    for i = 0 to metadata.count() - 1
        season = metadata[i]
        node = content.createChild("ContentNode")

        ' Set title
        if season.title <> invalid
            node.title = season.title
        else
            node.title = "Season " + (i + 1).ToStr()
        end if

        ' Set poster URL with fallback to show poster
        thumbPath = ""
        if season.thumb <> invalid and season.thumb <> ""
            thumbPath = season.thumb
        else if season.parentThumb <> invalid and season.parentThumb <> ""
            thumbPath = season.parentThumb
        end if
        if thumbPath <> ""
            node.HDPosterUrl = BuildPosterUrl(thumbPath, 240, 360)
        end if

        ' Set leaf counts for PosterGridItem badge support
        node.addFields({
            ratingKey: GetRatingKeyStr(season.ratingKey)
            leafCount: 0
            viewedLeafCount: 0
            itemType: "season"
        })
        if season.leafCount <> invalid
            node.leafCount = season.leafCount
        end if
        if season.viewedLeafCount <> invalid
            node.viewedLeafCount = season.viewedLeafCount
        end if

        ' Auto-focus logic: prefer focusSeasonRatingKey if set, else first unwatched
        if not foundUnwatched
            ' Check if this season matches the requested focus target
            if m.top.focusSeasonRatingKey <> "" and GetRatingKeyStr(season.ratingKey) = m.top.focusSeasonRatingKey
                targetIndex = i
                foundUnwatched = true  ' Stop searching
            else
                leafCount = 0
                viewedLeafCount = 0
                if season.leafCount <> invalid then leafCount = season.leafCount
                if season.viewedLeafCount <> invalid then viewedLeafCount = season.viewedLeafCount

                if leafCount > 0 and viewedLeafCount < leafCount
                    targetIndex = i
                    foundUnwatched = true
                end if
            end if
        end if
    end for

    ' If all seasons fully watched, focus last season
    if not foundUnwatched and metadata.count() > 0
        targetIndex = metadata.count() - 1
    end if

    m.seasonRow.content = content
    m.currentSeasonIndex = targetIndex

    ' Jump to the target season
    ' PosterGrid contains an inner MarkupGrid; we need to set jumpToItem on it
    innerGrid = m.seasonRow.findNode("grid")
    if innerGrid <> invalid
        innerGrid.jumpToItem = targetIndex
    end if

    ' Load episodes for the auto-focused season
    season = m.seasons[targetIndex]
    loadEpisodes(GetRatingKeyStr(season.ratingKey))

    m.seasonRow.drawFocusFeedback = true
    m.episodeGrid.drawFocusFeedback = false
    m.seasonRow.setFocus(true)
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
        m.episodeGrid.content = invalid
        return
    end if

    m.emptyState.visible = false
    content = CreateObject("roSGNode", "ContentNode")

    for each episode in metadata
        node = content.createChild("ContentNode")
        ratingKeyStr = GetRatingKeyStr(episode.ratingKey)

        node.addFields({
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

        ' Format title with episode number: "E1 · Title"
        epTitle = ""
        if episode.title <> invalid then epTitle = episode.title
        node.title = "E" + node.episodeNumber.ToStr() + " · " + epTitle
    end for

    m.episodeGrid.content = content
end sub

' ========== Season Navigation ==========

sub onSeasonFocused(event as Object)
    index = event.getData()
    if index >= 0 and index < m.seasons.count() and index <> m.currentSeasonIndex
        m.currentSeasonIndex = index
        season = m.seasons[index]
        loadEpisodes(GetRatingKeyStr(season.ratingKey))
    end if
end sub

sub onSeasonSelected(event as Object)
    ' When season is selected (OK pressed), move focus to episode grid
    if m.episodeGrid.content <> invalid and m.episodeGrid.content.getChildCount() > 0
        m.focusOnSeasons = false
        m.seasonRow.drawFocusFeedback = false
        m.episodeGrid.drawFocusFeedback = true
        m.episodeGrid.setFocus(true)
    end if
end sub

' ========== Episode Selection ==========

sub onEpisodeSelected(event as Object)
    index = event.getData()
    content = m.episodeGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        episode = content.getChild(index)

        ' Always navigate to episode detail screen
        m.top.itemSelected = {
            action: "detail"
            ratingKey: episode.ratingKey
            itemType: "episode"
        }
    end if
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

    dialog.buttons = [watchedLabel, "Show Info", "Cancel"]
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

        ' Force episode grid re-render
        m.episodeGrid.content = m.episodeGrid.content
    else if index = 1
        ' Navigate to show detail screen
        m.top.itemSelected = {
            action: "detail"
            ratingKey: m.top.ratingKey
            itemType: "show"
        }
    end if

    m.episodeGrid.setFocus(true)
end sub

sub onEpisodeOptionsClosed(event as Object)
    m.episodeGrid.setFocus(true)
end sub

' ========== Playback ==========

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
        m.player.parentRatingKey = GetRatingKeyStr(season.ratingKey)  ' Season ratingKey
    end if
    if episode.episodeNumber <> invalid
        m.player.episodeIndex = episode.episodeNumber
    end if
    m.player.seasonIndex = m.currentSeasonIndex

    m.player.observeField("playbackResult", "onPlaybackResult")
    m.player.observeField("nextEpisodeStarted", "onNextEpisodeStarted")

    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub

sub onNextEpisodeStarted(event as Object)
    ' Refresh episode list when auto-play advances to next episode
    if m.seasons.count() > m.currentSeasonIndex
        season = m.seasons[m.currentSeasonIndex]
        loadEpisodes(GetRatingKeyStr(season.ratingKey))
    end if
end sub

sub onPlaybackResult(event as Object)
    result = event.getData()
    if result = invalid then return

    ' Remove video player from scene
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if

    ' Always push PostPlayScreen after playback ends
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

' ========== Error / Retry ==========

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
        m.seasonRow.setFocus(true)
    else
        m.episodeGrid.setFocus(true)
    end if
end sub

sub showInlineRetry()
    m.seasonRow.visible = false
    m.episodeGrid.visible = false
    m.emptyState.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.seasonRow.visible = true
    m.episodeGrid.visible = true
    retryLastRequest()
end sub

' ========== Server Reconnect ==========

sub onServerReconnected(event as Object)
    if m.global.serverReconnected = true
        m.global.serverReconnected = false
        if m.top.ratingKey <> "" and m.top.ratingKey <> invalid
            loadSeasons(m.top.ratingKey)
        end if
    end if
end sub

' ========== Watch State Updates ==========

sub onWatchStateUpdate(event as Object)
    update = event.getData()
    if update = invalid or update.ratingKey = invalid then return

    ratingKey = update.ratingKey
    viewCount = update.viewCount

    ' Update matching episode in episode grid
    if m.episodeGrid.content <> invalid
        for i = 0 to m.episodeGrid.content.getChildCount() - 1
            item = m.episodeGrid.content.getChild(i)
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

' ========== Focus / Key Event Management ==========

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    else if key = "down" and m.focusOnSeasons
        ' Only move to episode grid if it has content
        if m.episodeGrid.content <> invalid and m.episodeGrid.content.getChildCount() > 0
            m.focusOnSeasons = false
            m.seasonRow.drawFocusFeedback = false
            m.episodeGrid.drawFocusFeedback = true
            m.episodeGrid.setFocus(true)
        end if
        return true
    else if key = "up" and not m.focusOnSeasons
        ' Move to season row when on top row of episode grid (items 0..numColumns-1)
        focusedIndex = m.episodeGrid.itemFocused
        if focusedIndex < 5
            m.focusOnSeasons = true
            m.episodeGrid.drawFocusFeedback = false
            m.seasonRow.drawFocusFeedback = true
            m.seasonRow.setFocus(true)
            return true
        end if
        ' Not on top row — let MarkupGrid handle internal navigation
        return false
    else if key = "options" and not m.focusOnSeasons
        ' Show context menu for focused episode
        focusedIndex = m.episodeGrid.itemFocused
        content = m.episodeGrid.content
        if content <> invalid and focusedIndex >= 0 and focusedIndex < content.getChildCount()
            episode = content.getChild(focusedIndex)
            showEpisodeOptionsMenu(episode)
            return true
        end if
    end if

    return false
end function
