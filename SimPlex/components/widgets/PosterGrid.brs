sub init()
    c = m.global.constants
    m.grid = m.top.findNode("grid")

    ' Configure grid dimensions — compute column count dynamically from gridWidth
    numColumns = Int(m.top.gridWidth / (c.POSTER_WIDTH + c.GRID_H_SPACING))
    if numColumns < 1 then numColumns = 1
    m.grid.numColumns = numColumns
    m.grid.itemSize = [c.POSTER_WIDTH + 20, c.POSTER_HEIGHT + 50]
    m.grid.itemSpacing = [c.GRID_H_SPACING, c.GRID_V_SPACING]

    ' Set numRows so MarkupGrid renders multiple visible rows and scrolls
    m.grid.numRows = 2

    ' Observe gridWidth changes for dynamic recalculation (e.g. search layout toggle)
    m.top.observeField("gridWidth", "onGridWidthChange")

    ' Observe grid selection
    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")

    ' Delegate focus to inner grid when this component receives focus
    m.top.observeField("focusedChild", "onFocusChange")

    ' Also catch the case where setFocus(true) is called on this Group
    ' directly — focusedChild stays invalid so the observer won't fire,
    ' but the Group gains focus. Observing isInFocusChain handles this.
    m.top.observeField("isInFocusChain", "onFocusChainChange")

    m.lastFocusedIndex = 0
    m.totalItems = 0
end sub

sub onFocusChange(event as Object)
    ' When PosterGrid is in focus chain but no child has focus, delegate to grid
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.grid.setFocus(true)
    end if
end sub

sub onFocusChainChange(event as Object)
    ' Fires when this component enters the focus chain (e.g. setFocus(true)
    ' called on this Group). If the Group itself has focus (not a child),
    ' delegate to the inner MarkupGrid immediately.
    if m.top.hasFocus()
        m.grid.setFocus(true)
    end if
end sub

sub onGridWidthChange(event as Object)
    ' Recalculate column count when gridWidth changes dynamically
    c = m.global.constants
    gridWidth = event.getData()
    if gridWidth > 0
        numColumns = Int(gridWidth / (c.POSTER_WIDTH + c.GRID_H_SPACING))
        if numColumns < 1 then numColumns = 1
        m.grid.numColumns = numColumns
    end if
end sub

sub onContentChange(event as Object)
    content = event.getData()
    m.grid.content = content
    if content <> invalid
        m.totalItems = content.getChildCount()
    else
        m.totalItems = 0
    end if
end sub

sub onItemSelected(event as Object)
    index = event.getData()
    m.top.itemSelected = index
end sub

sub onItemFocused(event as Object)
    index = event.getData()
    m.lastFocusedIndex = index

    ' Check if we need to load more (within 2 rows of the end)
    itemsPerRow = m.grid.numColumns
    threshold = m.totalItems - (itemsPerRow * 2)

    if index >= threshold and m.totalItems > 0
        m.top.loadMore = true
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' Let the grid handle its own navigation
    return false
end function
