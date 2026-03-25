sub init()
    m.grid = m.top.findNode("grid")
    m.grid.observeField("itemSelected", "onGridItemSelected")
    m.grid.observeField("itemFocused", "onGridItemFocused")
end sub

sub onContentChange(event as Object)
    m.grid.content = event.getData()
end sub

sub onJumpToItem(event as Object)
    m.grid.jumpToItem = event.getData()
end sub

sub onGridItemSelected(event as Object)
    m.top.itemSelected = event.getData()
end sub

sub onGridItemFocused(event as Object)
    m.top.itemFocused = event.getData()
end sub

' Key events bubble up from the inner MarkupGrid.
' With wrap=false, the grid returns false (unhandled) when trying to
' move beyond its boundaries, and the event reaches this handler.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up"
        ' Grid couldn't move up — we're on the top row. Signal escape.
        m.top.escapeUp = true
        return true
    else if key = "down"
        ' Grid couldn't move down — we're on the last row. Wrap to top.
        m.grid.jumpToItem = 0
        return true
    end if

    return false
end function
