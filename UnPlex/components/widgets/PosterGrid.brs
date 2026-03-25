sub init()
    c = m.global.constants
    m.grid = m.top.findNode("grid")

    ' Configure grid dimensions — compute column count dynamically from gridWidth
    if c <> invalid
        numColumns = Int(m.top.gridWidth / (c.POSTER_WIDTH + c.GRID_H_SPACING))
        if numColumns < 1 then numColumns = 1
        m.grid.numColumns = numColumns
        m.grid.itemSize = [c.POSTER_WIDTH + 20, c.POSTER_HEIGHT + 50]
        m.grid.itemSpacing = [c.GRID_H_SPACING, c.GRID_V_SPACING]
    end if

    ' Default numRows (2 for normal grids). Overridable via numRows interface field.
    ' A value of 0 means "use default" (2).
    if m.top.numRows > 0
        m.grid.numRows = m.top.numRows
    else
        m.grid.numRows = 2
    end if

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
    ' When PosterGrid Group itself has focus (not a child), delegate to grid.
    ' Only act on hasFocus — not merely isInFocusChain — to avoid stealing
    ' focus back from a parent that intentionally reclaimed it.
    if m.top.hasFocus()
        m.grid.setFocus(true)
    end if
end sub

sub onFocusChainChange(event as Object)
    ' Fires when this component enters or leaves the focus chain.
    ' Only delegate to the inner grid when this Group *itself* has focus,
    ' not when a parent or sibling is simply in the chain.
    if m.top.hasFocus()
        m.grid.setFocus(true)
    end if
end sub

sub onGridWidthChange(event as Object)
    ' Recalculate column count when gridWidth changes dynamically
    c = m.global.constants
    if c = invalid then return
    gridWidth = event.getData()
    if gridWidth > 0
        numColumns = Int(gridWidth / (c.POSTER_WIDTH + c.GRID_H_SPACING))
        if numColumns < 1 then numColumns = 1
        m.grid.numColumns = numColumns
    end if
end sub

sub onNumRowsChange(event as Object)
    ' Allow parent components to override the number of visible rows.
    ' numRows=1 gives a horizontal scrolling strip (used by SearchScreen).
    numRows = event.getData()
    if numRows > 0
        m.grid.numRows = numRows
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

    ' Bubble focus index up to interface for parent components (e.g. ShowScreen)
    m.top.itemFocused = index

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
