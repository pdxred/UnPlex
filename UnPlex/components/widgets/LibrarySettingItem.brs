' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.focusBg = m.top.findNode("focusBg")
    m.movingBg = m.top.findNode("movingBg")
    m.headerLine = m.top.findNode("headerLine")
    m.pinDot = m.top.findNode("pinDot")
    m.unpinBorder = m.top.findNode("unpinBorder")
    m.unpinInner = m.top.findNode("unpinInner")
    m.moveArrows = m.top.findNode("moveArrows")
    m.titleLabel = m.top.findNode("titleLabel")
    m.headerLabel = m.top.findNode("headerLabel")
end sub

sub onContentChange(event as Object)
    content = event.getData()
    if content = invalid then return

    ' Reset all indicators
    m.pinDot.visible = false
    m.unpinBorder.visible = false
    m.unpinInner.visible = false
    m.moveArrows.visible = false
    m.titleLabel.visible = false
    m.headerLabel.visible = false
    m.headerLine.visible = false
    m.movingBg.visible = false

    isHeader = false
    if content.isHeader <> invalid then isHeader = content.isHeader

    if isHeader
        ' Section header row
        m.headerLabel.text = content.title
        m.headerLabel.visible = true
        m.headerLine.visible = true
        return
    end if

    ' Regular library item
    m.titleLabel.text = content.title
    m.titleLabel.visible = true

    isPinned = false
    if content.isPinned <> invalid then isPinned = content.isPinned

    isMoving = false
    if content.isMoving <> invalid then isMoving = content.isMoving

    if isMoving
        ' Moving state: gold background + arrows
        m.movingBg.visible = true
        m.moveArrows.visible = true
        m.titleLabel.translation = [50, 16]
        m.titleLabel.color = "0xFFFFFFFF"
    else if isPinned
        ' Pinned: gold dot
        m.pinDot.visible = true
        m.titleLabel.translation = [50, 16]
        m.titleLabel.color = "0xFFFFFFFF"
    else
        ' Unpinned: hollow dot, dimmer text
        m.unpinBorder.visible = true
        m.unpinInner.visible = true
        m.titleLabel.translation = [50, 16]
        m.titleLabel.color = "0x808090FF"
    end if
end sub

sub onFocusChange(event as Object)
    focusPercent = event.getData()
    m.focusBg.visible = (focusPercent > 0.5)

    ' Update focus highlight opacity
    if focusPercent > 0.5
        m.focusBg.color = "0xFFFFFF18"
    end if
end sub
