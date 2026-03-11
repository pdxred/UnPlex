sub init()
    LogEvent("HomeScreen TEST4a init: NO spinner, NO animations")
    m.sidebar = m.top.findNode("sidebar")
    m.posterGrid = m.top.findNode("posterGrid")
    m.filterBar = m.top.findNode("filterBar")
    m.hubRowContainer = m.top.findNode("hubRowContainer")
    m.emptyState = m.top.findNode("emptyState")
    m.retryGroup = m.top.findNode("retryGroup")
    m.retryButton = m.top.findNode("retryButton")
    m.clearFiltersButton = m.top.findNode("clearFiltersButton")
    m.filterBottomSheetContainer = m.top.findNode("filterBottomSheetContainer")
    m.hubRowList = invalid
    m.filterBottomSheet = invalid
    m.isSheetOpen = false
    m.focusArea = "sidebar"

    m.sidebar.observeField("selectedLibrary", "onLibrarySelected")
    m.sidebar.observeField("specialAction", "onSpecialAction")
    m.posterGrid.observeField("itemSelected", "onGridItemSelected")
    m.posterGrid.observeField("loadMore", "onLoadMore")
    m.filterBar.observeField("filterChanged", "onFilterChanged")
    m.retryButton.observeField("buttonSelected", "onRetryButtonSelected")
    m.clearFiltersButton.observeField("buttonSelected", "onClearFiltersFromEmpty")
    m.global.observeField("serverReconnected", "onServerReconnected")
    m.top.observeField("focusedChild", "onFocusChange")

    LogEvent("HomeScreen TEST4a init: complete")
end sub

sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.sidebar.setFocus(true)
    end if
end sub

sub onLibrarySelected(event as Object)
    LogEvent("Library selected")
end sub

sub onSpecialAction(event as Object)
    LogEvent("Special action: " + event.getData())
end sub

sub onGridItemSelected(event as Object)
    LogEvent("Grid item selected")
end sub

sub onLoadMore(event as Object)
    LogEvent("Load more")
end sub

sub onFilterChanged(event as Object)
    LogEvent("Filter changed")
end sub

sub onRetryButtonSelected(event as Object)
    LogEvent("Retry")
end sub

sub onClearFiltersFromEmpty(event as Object)
    LogEvent("Clear filters")
end sub

sub onServerReconnected(event as Object)
    LogEvent("Server reconnected")
end sub

sub cleanup()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        m.top.navigateBack = true
        return true
    end if
    return false
end function
