' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.itemContainer = m.top.findNode("itemContainer")
    m.borderTop = m.top.findNode("focusBorderTop")
    m.borderBottom = m.top.findNode("focusBorderBottom")
    m.borderLeft = m.top.findNode("focusBorderLeft")
    m.borderRight = m.top.findNode("focusBorderRight")

    m.NUM_COLUMNS = 5
    m.ITEM_W = 340
    m.ITEM_H = 240
    m.SPACING_H = 12
    m.SPACING_V = 16
    m.BORDER = 4
    m.VISIBLE_ROWS = 2
    m.focusIndex = 0
    m.totalItems = 0
    m.scrollRow = 0  ' Which row is at the top of the visible area
    m.items = []

    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    if m.top.hasFocus() and m.totalItems > 0
        updateFocusBorder()
    end if
end sub

sub onContentChange(event as Object)
    content = event.getData()

    ' Remove old items
    m.itemContainer.removeChildrenIndex(m.itemContainer.getChildCount(), 0)
    m.items = []

    if content = invalid
        m.totalItems = 0
        m.focusIndex = 0
        showBorders(false)
        return
    end if

    m.totalItems = content.getChildCount()
    m.focusIndex = 0
    m.scrollRow = 0

    ' Create EpisodeGridItem nodes positioned in a grid
    for i = 0 to m.totalItems - 1
        col = i MOD m.NUM_COLUMNS
        row = Int(i / m.NUM_COLUMNS)

        item = CreateObject("roSGNode", "EpisodeGridItem")
        item.translation = [col * (m.ITEM_W + m.SPACING_H), row * (m.ITEM_H + m.SPACING_V)]
        item.itemContent = content.getChild(i)
        m.itemContainer.appendChild(item)
        m.items.push(item)
    end for

    updateScroll()
    showBorders(false)
end sub

sub onJumpToItem(event as Object)
    idx = event.getData()
    if idx >= 0 and idx < m.totalItems
        m.focusIndex = idx
        ' Ensure the target row is visible
        targetRow = Int(idx / m.NUM_COLUMNS)
        ensureRowVisible(targetRow)
        updateFocusBorder()
    end if
end sub

sub ensureRowVisible(targetRow as Integer)
    if targetRow < m.scrollRow
        m.scrollRow = targetRow
    else if targetRow >= m.scrollRow + m.VISIBLE_ROWS
        m.scrollRow = targetRow - m.VISIBLE_ROWS + 1
    end if
    updateScroll()
end sub

sub updateScroll()
    ' Shift the item container up so scrollRow is at the top
    y = -(m.scrollRow * (m.ITEM_H + m.SPACING_V))
    m.itemContainer.translation = [0, y]
end sub

sub updateFocusBorder()
    if m.totalItems = 0
        showBorders(false)
        return
    end if

    col = m.focusIndex MOD m.NUM_COLUMNS
    row = Int(m.focusIndex / m.NUM_COLUMNS)

    ' Position within the visible viewport
    visibleRow = row - m.scrollRow

    x = col * (m.ITEM_W + m.SPACING_H)
    y = visibleRow * (m.ITEM_H + m.SPACING_V)
    b = m.BORDER

    m.borderTop.translation = [x - b, y - b]
    m.borderTop.width = m.ITEM_W + b * 2
    m.borderTop.height = b

    m.borderBottom.translation = [x - b, y + m.ITEM_H]
    m.borderBottom.width = m.ITEM_W + b * 2
    m.borderBottom.height = b

    m.borderLeft.translation = [x - b, y]
    m.borderLeft.width = b
    m.borderLeft.height = m.ITEM_H

    m.borderRight.translation = [x + m.ITEM_W, y]
    m.borderRight.width = b
    m.borderRight.height = m.ITEM_H

    showBorders(true)
end sub

sub showBorders(vis as Boolean)
    m.borderTop.visible = vis
    m.borderBottom.visible = vis
    m.borderLeft.visible = vis
    m.borderRight.visible = vis
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.totalItems = 0 then return false

    currentRow = Int(m.focusIndex / m.NUM_COLUMNS)
    currentCol = m.focusIndex MOD m.NUM_COLUMNS
    lastRow = Int((m.totalItems - 1) / m.NUM_COLUMNS)

    if key = "up"
        if currentRow = 0
            showBorders(false)
            m.top.escapeUp = true
            return true
        end if
        m.focusIndex = m.focusIndex - m.NUM_COLUMNS
        ensureRowVisible(currentRow - 1)
        updateFocusBorder()
        m.top.itemFocused = m.focusIndex
        return true

    else if key = "down"
        if currentRow >= lastRow
            ' Wrap to top
            newCol = currentCol
            if newCol >= m.totalItems then newCol = m.totalItems - 1
            m.focusIndex = newCol
            m.scrollRow = 0
            updateScroll()
            updateFocusBorder()
            m.top.itemFocused = m.focusIndex
            return true
        end if
        newIndex = m.focusIndex + m.NUM_COLUMNS
        if newIndex >= m.totalItems
            newIndex = m.totalItems - 1
        end if
        m.focusIndex = newIndex
        ensureRowVisible(Int(m.focusIndex / m.NUM_COLUMNS))
        updateFocusBorder()
        m.top.itemFocused = m.focusIndex
        return true

    else if key = "left"
        if currentCol > 0
            m.focusIndex = m.focusIndex - 1
            updateFocusBorder()
            m.top.itemFocused = m.focusIndex
        end if
        return true

    else if key = "right"
        if currentCol < m.NUM_COLUMNS - 1 and m.focusIndex + 1 < m.totalItems
            m.focusIndex = m.focusIndex + 1
            updateFocusBorder()
            m.top.itemFocused = m.focusIndex
        end if
        return true

    else if key = "OK"
        m.top.itemSelected = m.focusIndex
        return true
    end if

    return false
end function
