sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.itemCountLabel = m.top.findNode("itemCountLabel")
    m.playlistItemList = m.top.findNode("playlistItemList")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.emptyState = m.top.findNode("emptyState")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")

    m.playlistItems = []   ' Array of playlist item data for VideoPlayer
    m.retryCount = 0
    m.retryContext = invalid

    ' Observe item selection
    m.playlistItemList.observeField("itemSelected", "onItemSelected")

    ' Observe retry button
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")

    ' Observe server reconnect
    m.global.observeField("serverReconnected", "onServerReconnected")

    ' Delegate focus
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.playlistItemList.setFocus(true)
    end if
end sub

sub onRatingKeyChange(event as Object)
    ratingKey = event.getData()
    if ratingKey <> "" and ratingKey <> invalid
        m.titleLabel.text = m.top.playlistTitle
        loadPlaylistItems(ratingKey)
    end if
end sub

sub loadPlaylistItems(ratingKey as String)
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false
    m.retryGroup.visible = false

    endpoint = "/playlists/" + ratingKey + "/items"
    m.retryContext = { endpoint: endpoint, params: {}, handler: "onPlaylistItemsLoaded" }

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = endpoint
    task.params = {}
    task.observeField("status", "onPlaylistItemsLoaded")
    task.control = "run"
    m.apiTask = task
end sub

sub onPlaylistItemsLoaded(event as Object)
    state = event.getData()
    if state = "completed"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        m.retryCount = 0
        m.retryGroup.visible = false
        processPlaylistItems()
    else if state = "error"
        if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false
        if m.apiTask.responseCode < 0
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
                showErrorDialog("Error", "Couldn't load playlist. Please try again.")
            end if
        end if
    end if
end sub

sub processPlaylistItems()
    response = m.apiTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    metadata = response.MediaContainer.Metadata
    if metadata = invalid or metadata.count() = 0
        m.emptyState.visible = true
        m.itemCountLabel.text = "0 items"
        return
    end if

    m.emptyState.visible = false
    m.playlistItems = []
    c = m.global.constants
    content = CreateObject("roSGNode", "ContentNode")

    itemIndex = 1
    for each item in metadata
        ratingKeyStr = ""
        if item.ratingKey <> invalid
            if type(item.ratingKey) = "roString" or type(item.ratingKey) = "String"
                ratingKeyStr = item.ratingKey
            else
                ratingKeyStr = item.ratingKey.ToStr()
            end if
        end if

        ' Skip items with no ratingKey (deleted from library)
        if ratingKeyStr = "" then continue for

        node = content.createChild("ContentNode")
        node.addFields({
            title: item.title
            ratingKey: ratingKeyStr
            itemType: item.type
            itemIndex: itemIndex
            duration: 0
            viewOffset: 0
            viewCount: 0
            grandparentTitle: ""
            parentTitle: ""
        })

        if item.duration <> invalid then node.duration = item.duration
        if item.viewOffset <> invalid then node.viewOffset = item.viewOffset
        if item.viewCount <> invalid then node.viewCount = item.viewCount
        if item.grandparentTitle <> invalid then node.grandparentTitle = item.grandparentTitle
        if item.parentTitle <> invalid then node.parentTitle = item.parentTitle

        ' Build playlist items array for VideoPlayer
        m.playlistItems.push({
            ratingKey: ratingKeyStr
            mediaKey: "/library/metadata/" + ratingKeyStr
            title: item.title
            itemType: item.type
        })

        itemIndex = itemIndex + 1
    end for

    m.itemCountLabel.text = m.playlistItems.count().ToStr() + " items"
    m.playlistItemList.content = content
    m.playlistItemList.setFocus(true)
end sub

sub onItemSelected(event as Object)
    index = event.getData()
    content = m.playlistItemList.content
    if content = invalid or index < 0 or index >= content.getChildCount()
        return
    end if

    item = content.getChild(index)
    c = m.global.constants

    ' Check for resume
    if item.viewOffset > 0 and item.duration > 0
        progress = item.viewOffset / item.duration
        if progress >= c.PROGRESS_MIN_PERCENT
            showResumeDialog(item, index)
            return
        end if
    end if

    startPlaylistPlayback(item, 0, index)
end sub

sub showResumeDialog(item as Object, playlistIndex as Integer)
    m.pendingPlayItem = item
    m.pendingPlaylistIndex = playlistIndex

    resumeTime = FormatTime(item.viewOffset)

    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = item.title
    dialog.message = ["Resume from " + resumeTime + "?"]
    dialog.buttons = ["Resume from " + resumeTime, "Start from Beginning"]
    dialog.observeField("buttonSelected", "onResumeDialogButton")
    dialog.observeField("wasClosed", "onResumeDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onResumeDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true

    if index = 0
        startPlaylistPlayback(m.pendingPlayItem, m.pendingPlayItem.viewOffset, m.pendingPlaylistIndex)
    else if index = 1
        startPlaylistPlayback(m.pendingPlayItem, 0, m.pendingPlaylistIndex)
    end if
end sub

sub onResumeDialogClosed(event as Object)
    m.playlistItemList.setFocus(true)
end sub

sub startPlaylistPlayback(item as Object, offset as Integer, playlistIndex as Integer)
    m.player = CreateObject("roSGNode", "VideoPlayer")
    m.player.ratingKey = item.ratingKey
    m.player.mediaKey = "/library/metadata/" + item.ratingKey
    m.player.startOffset = offset
    m.player.itemTitle = item.title
    m.player.playlistItems = m.playlistItems
    m.player.playlistIndex = playlistIndex
    m.player.observeField("playbackComplete", "onPlaybackComplete")
    m.player.observeField("playlistAdvanced", "onPlaylistAdvanced")

    m.top.getScene().appendChild(m.player)
    m.player.setFocus(true)
    m.player.control = "play"
end sub

sub onPlaybackComplete(event as Object)
    if m.player <> invalid
        m.top.getScene().removeChild(m.player)
        m.player = invalid
    end if
    m.playlistItemList.setFocus(true)

    ' Refresh playlist items to update watched states
    if m.top.ratingKey <> "" and m.top.ratingKey <> invalid
        loadPlaylistItems(m.top.ratingKey)
    end if
end sub

sub onPlaylistAdvanced(event as Object)
    ' VideoPlayer advanced to next playlist item — no action needed
end sub

sub retryLastRequest()
    if m.retryContext = invalid then return
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = m.retryContext.endpoint
    task.params = m.retryContext.params
    task.observeField("status", "onPlaylistItemsLoaded")
    task.control = "run"
    m.apiTask = task
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
    m.playlistItemList.setFocus(true)
end sub

sub showInlineRetry()
    m.playlistItemList.visible = false
    m.emptyState.visible = false
    m.retryGroup.visible = true
    m.retryButton.setFocus(true)
end sub

sub onRetryButtonSelected(event as Object)
    m.retryGroup.visible = false
    m.playlistItemList.visible = true
    retryLastRequest()
end sub

sub onServerReconnected(event as Object)
    if m.global.serverReconnected = true
        m.global.serverReconnected = false
        if m.top.ratingKey <> "" and m.top.ratingKey <> invalid
            loadPlaylistItems(m.top.ratingKey)
        end if
    end if
end sub

sub cleanup()
    if m.apiTask <> invalid
        m.apiTask.control = "stop"
        m.apiTask.unobserveField("status")
    end if
    m.playlistItemList.unobserveField("itemSelected")
    m.retryButton.unobserveField("buttonSelected")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
