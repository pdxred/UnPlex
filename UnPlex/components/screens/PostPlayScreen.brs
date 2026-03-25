' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.subtitleLabel = m.top.findNode("subtitleLabel")
    m.buttonGroup = m.top.findNode("buttonGroup")

    m.buttonActions = []

    ' Observe button selection
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")

    ' Delegate focus when screen receives focus
    m.top.observeField("focusedChild", "onFocusChange")

    ' Observe field changes to build UI
    m.top.observeField("itemTitle", "onItemTitleChange")
    m.top.observeField("hasNextEpisode", "onDataChange")
    m.top.observeField("viewOffset", "onDataChange")
end sub

sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.buttonGroup.setFocus(true)
    end if
end sub

sub onItemTitleChange(event as Object)
    title = event.getData()
    if title <> invalid and title <> ""
        m.subtitleLabel.text = title
    end if
    buildButtons()
end sub

sub onDataChange(event as Object)
    buildButtons()
end sub

sub buildButtons()
    buttons = []
    m.buttonActions = []

    ' Play Next Episode (only if hasNextEpisode=true)
    if m.top.hasNextEpisode = true
        buttons.push("Play Next Episode")
        m.buttonActions.push("playNext")
    end if

    ' Replay
    buttons.push("Replay")
    m.buttonActions.push("replay")

    ' Back to Library
    buttons.push("Back to Library")
    m.buttonActions.push("backToLibrary")

    ' Play from Timestamp (only if viewOffset > 0)
    if m.top.viewOffset > 0
        buttons.push("Play from Timestamp")
        m.buttonActions.push("playFromTimestamp")
    end if

    m.buttonGroup.buttons = buttons
    m.buttonGroup.setFocus(true)
end sub

sub onButtonSelected(event as Object)
    index = event.getData()
    if index < 0 or index >= m.buttonActions.count()
        return
    end if

    action = m.buttonActions[index]
    m.top.action = action
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
