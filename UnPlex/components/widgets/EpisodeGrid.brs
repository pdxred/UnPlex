sub init()
    m.grid = m.top.findNode("grid")
    m.focusRect = m.top.findNode("focusRect")

    m.NUM_COLUMNS = 5
    m.ITEM_W = 340
    m.ITEM_H = 240
    m.SPACING_H = 12
    m.SPACING_V = 16
    m.focusIndex = 0
    m.totalItems = 0

    ' Size the focus highlight to match one item cell
    m.focusRect.width = m.ITEM_W
    m.focusRect.height = m.ITEM_H

    ' Do NOT observe itemFocused — we manage focusIndex entirely ourselves
    ' to avoid feedback loops with jumpToItem/animateToItem.
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
        m.focusRect.visible = false
        return
    end if

    col = m.focusIndex MOD m.NUM_COLUMNS
    row = Int(m.focusIndex / m.NUM_COLUMNS)
    totalRows = Int((m.totalItems - 1) / m.NUM_COLUMNS) + 1
    numVisibleRows = 2

    ' Compute which row within the visible viewport this is.
    ' The grid shows numVisibleRows rows. When we jumpToItem,
    ' the grid scrolls so the target item is visible.
    ' For a 2-row viewport:
    '   - If totalRows <= 2, all rows are visible. visibleRow = row.
    '   - If totalRows > 2, the grid scrolls. The focused item
    '     appears at visibleRow 0 if it's row 0, else visibleRow 1
    '     (the grid keeps the previous row above for context).
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

    m.focusRect.translation = [x, y]
    m.focusRect.visible = true
end sub

' EpisodeGrid Group holds focus. ALL keys come here.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.totalItems = 0 then return false

    currentRow = Int(m.focusIndex / m.NUM_COLUMNS)
    currentCol = m.focusIndex MOD m.NUM_COLUMNS
    lastRow = Int((m.totalItems - 1) / m.NUM_COLUMNS)

    if key = "up"
        LogEvent("EpisodeGrid UP: focusIndex=" + m.focusIndex.ToStr() + " row=" + currentRow.ToStr() + " lastRow=" + lastRow.ToStr() + " total=" + m.totalItems.ToStr())
        if currentRow = 0
            ' Top row — escape to season list
            m.top.escapeUp = true
            return true
        end if
        ' Move up one row
        m.focusIndex = m.focusIndex - m.NUM_COLUMNS
        m.grid.jumpToItem = m.focusIndex
        updateFocusRect()
        m.top.itemFocused = m.focusIndex
        return true

    else if key = "down"
        LogEvent("EpisodeGrid DOWN: focusIndex=" + m.focusIndex.ToStr() + " row=" + currentRow.ToStr() + " lastRow=" + lastRow.ToStr() + " total=" + m.totalItems.ToStr())
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
        ' Move down one row
        newIndex = m.focusIndex + m.NUM_COLUMNS
        if newIndex >= m.totalItems
            ' Partial last row — clamp to last item in same column or last item
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
