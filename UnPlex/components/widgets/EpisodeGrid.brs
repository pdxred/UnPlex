sub init()
    m.grid = m.top.findNode("grid")

    m.numColumns = 5
    m.focusIndex = 0
    m.totalItems = 0

    ' We hold focus on the Group (not the inner grid).
    ' The grid renders focus feedback via drawFocusFeedback even when
    ' it doesn't have focus, as long as we keep updating jumpToItem.
    ' But we DO need to give the grid focus for it to render the
    ' focus rectangle. So we use the grid for focus + rendering,
    ' but reclaim focus to the Group immediately after each key press
    ' using a focusedChild observer.
    m.grid.observeField("itemSelected", "onGridItemSelected")
    m.grid.observeField("itemFocused", "onGridItemFocused")
    m.top.observeField("focusedChild", "onFocusedChildChange")
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
end sub

sub onJumpToItem(event as Object)
    idx = event.getData()
    m.grid.jumpToItem = idx
    m.focusIndex = idx
end sub

sub onGridItemSelected(event as Object)
    m.top.itemSelected = event.getData()
end sub

sub onGridItemFocused(event as Object)
    m.top.itemFocused = event.getData()
    m.focusIndex = event.getData()
end sub

sub onFocusedChildChange(event as Object)
    ' When we get focus (e.g. from ShowScreen), delegate to the inner grid
    ' so it renders the focus rectangle. But we keep our onKeyEvent active
    ' because it fires for the Group even when a child has focus.
    if m.top.isInFocusChain() and not m.grid.hasFocus()
        m.grid.setFocus(true)
    end if
end sub

' This fires when a key bubbles up from the inner MarkupGrid unhandled.
' With wrap=false, boundary keys (up on top row, down on last row) bubble.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    LogEvent("EpisodeGrid onKeyEvent: " + key + " focusIndex=" + m.focusIndex.ToStr())

    if key = "up"
        ' Only reaches here if the grid didn't handle it (top row, wrap=false)
        LogEvent("EpisodeGrid: escapeUp triggered")
        m.top.escapeUp = true
        return true
    else if key = "down"
        ' Only reaches here if the grid didn't handle it (last row, wrap=false)
        ' Manually wrap to the same column on the top row
        col = m.focusIndex MOD m.numColumns
        if col >= m.totalItems then col = m.totalItems - 1
        LogEvent("EpisodeGrid: downward wrap to item " + col.ToStr())
        m.grid.jumpToItem = col
        m.focusIndex = col
        return true
    end if

    return false
end function
