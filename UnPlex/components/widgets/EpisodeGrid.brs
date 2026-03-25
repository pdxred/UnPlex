sub init()
    m.grid = m.top.findNode("grid")
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
    m.focusIndex = 0
    m.totalItems = 0
end sub

sub onContentChange(event as Object)
    content = event.getData()
    m.grid.content = content
    if content <> invalid
        m.totalItems = content.getChildCount()
    else
        m.totalItems = 0
    end if
    m.focusIndex = 0
    m.grid.jumpToItem = 0
    LogEvent("EpisodeGrid: content loaded, totalItems=" + m.totalItems.ToStr())
    updateFocusRect()
end sub

sub onJumpToItem(event as Object)
    idx = event.getData()
    if idx >= 0 and idx < m.totalItems
        m.focusIndex = idx
        m.grid.jumpToItem = idx
        updateFocusRect()
    end if
end sub

sub updateFocusRect()
    if m.totalItems = 0
        showBorders(false)
        return
    end if

    col = m.focusIndex MOD m.NUM_COLUMNS
    row = Int(m.focusIndex / m.NUM_COLUMNS)
    totalRows = Int((m.totalItems - 1) / m.NUM_COLUMNS) + 1
    numVisibleRows = 2

    if totalRows <= numVisibleRows
        visibleRow = row
    else
        if row = 0
            visibleRow = 0
        else
            visibleRow = 1
        end if
    end if

    x = col * (m.ITEM_W + m.SPACING_H)
    y = visibleRow * (m.ITEM_H + m.SPACING_V)
    b = m.BORDER

    ' Top border
    m.borderTop.translation = [x - b, y - b]
    m.borderTop.width = m.ITEM_W + b * 2
    m.borderTop.height = b

    ' Bottom border
    m.borderBottom.translation = [x - b, y + m.ITEM_H]
    m.borderBottom.width = m.ITEM_W + b * 2
    m.borderBottom.height = b

    ' Left border
    m.borderLeft.translation = [x - b, y]
    m.borderLeft.width = b
    m.borderLeft.height = m.ITEM_H

    ' Right border
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
            m.top.escapeUp = true
            return true
        end if
        m.focusIndex = m.focusIndex - m.NUM_COLUMNS
        m.grid.jumpToItem = m.focusIndex
        updateFocusRect()
        m.top.itemFocused = m.focusIndex
        return true

    else if key = "down"
        if currentRow >= lastRow
            ' Last row — wrap to top (same column)
            newCol = currentCol
            if newCol >= m.totalItems then newCol = m.totalItems - 1
            m.focusIndex = newCol
            m.grid.jumpToItem = m.focusIndex
            updateFocusRect()
            m.top.itemFocused = m.focusIndex
            return true
        end if
        newIndex = m.focusIndex + m.NUM_COLUMNS
        if newIndex >= m.totalItems
            newIndex = m.totalItems - 1
        end if
        m.focusIndex = newIndex
        m.grid.jumpToItem = m.focusIndex
        updateFocusRect()
        m.top.itemFocused = m.focusIndex
        return true

    else if key = "left"
        if currentCol > 0
            m.focusIndex = m.focusIndex - 1
            m.grid.jumpToItem = m.focusIndex
            updateFocusRect()
            m.top.itemFocused = m.focusIndex
        end if
        return true

    else if key = "right"
        if currentCol < m.NUM_COLUMNS - 1 and m.focusIndex + 1 < m.totalItems
            m.focusIndex = m.focusIndex + 1
            m.grid.jumpToItem = m.focusIndex
            updateFocusRect()
            m.top.itemFocused = m.focusIndex
        end if
        return true

    else if key = "OK"
        m.top.itemSelected = m.focusIndex
        return true
    end if

    return false
end function
