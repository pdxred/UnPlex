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

    ' MarkupGrid scrolls internally — the visible row offset depends on
    ' which rows are currently rendered. For numRows=2, the grid shows
    ' at most 2 rows at a time. The focus rect needs to track the
    ' visual position within the grid viewport, not the absolute row.
    '
    ' MarkupGrid's currFocusRow field (if available) tracks this,
    ' but we can compute it: the grid scrolls so the focused row
    ' is always visible. With numRows=2, the visible start row is
    ' max(0, row - 1) when focusing the last visible row.
    ' Simpler: the focus rect Y within the viewport is row offset 0 or 1.
    totalRows = Int((m.totalItems - 1) / m.NUM_COLUMNS) + 1
    numVisibleRows = 2
    if totalRows <= numVisibleRows
        visibleRow = row
    else
        ' Grid keeps focused item visible. For 2 visible rows,
        ' the focused item is on visible row 0 or 1.
        ' Use animateToItem behavior: grid scrolls to show the focused row.
        ' The simplest model: focused row is at the bottom visible row
        ' unless we're at the top.
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
' We manually navigate the inner grid via jumpToItem.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.totalItems = 0 then return false

    currentRow = Int(m.focusIndex / m.NUM_COLUMNS)
    currentCol = m.focusIndex MOD m.NUM_COLUMNS
    lastRow = Int((m.totalItems - 1) / m.NUM_COLUMNS)

    if key = "up"
        if currentRow = 0
            ' Top row — escape to season list
            m.top.escapeUp = true
            return true
        end if
        ' Move up one row
        newIndex = m.focusIndex - m.NUM_COLUMNS
        if newIndex >= 0
            m.focusIndex = newIndex
            m.grid.animateToItem = m.focusIndex
            updateFocusRect()
            m.top.itemFocused = m.focusIndex
        end if
        return true

    else if key = "down"
        if currentRow >= lastRow
            ' Last row — wrap to top (same column)
            newIndex = currentCol
            if newIndex >= m.totalItems then newIndex = m.totalItems - 1
            m.focusIndex = newIndex
            m.grid.jumpToItem = m.focusIndex
            updateFocusRect()
            m.top.itemFocused = m.focusIndex
            return true
        end if
        ' Move down one row
        newIndex = m.focusIndex + m.NUM_COLUMNS
        if newIndex >= m.totalItems
            ' Partial last row — clamp to last item
            newIndex = m.totalItems - 1
        end if
        m.focusIndex = newIndex
        m.grid.animateToItem = m.focusIndex
        updateFocusRect()
        m.top.itemFocused = m.focusIndex
        return true

    else if key = "left"
        if currentCol > 0
            m.focusIndex = m.focusIndex - 1
            m.grid.animateToItem = m.focusIndex
            updateFocusRect()
            m.top.itemFocused = m.focusIndex
        end if
        return true

    else if key = "right"
        if currentCol < m.NUM_COLUMNS - 1 and m.focusIndex + 1 < m.totalItems
            m.focusIndex = m.focusIndex + 1
            m.grid.animateToItem = m.focusIndex
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
