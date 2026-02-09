sub init()
    m.filterButtons = m.top.findNode("filterButtons")

    m.top.activeFilters = {}
    m.currentFilter = "all"

    m.filterButtons.observeField("buttonSelected", "onFilterSelected")
end sub

sub onSectionIdChange(event as Object)
    ' Reset filters when section changes
    m.top.activeFilters = {}
    m.currentFilter = "all"
    m.filterButtons.buttonSelected = 0
end sub

sub onFilterSelected(event as Object)
    index = event.getData()

    if index = 0
        ' All
        m.currentFilter = "all"
        m.top.activeFilters = {}
    else if index = 1
        ' Unwatched
        m.currentFilter = "unwatched"
        m.top.activeFilters = { "unwatched": "1" }
    end if

    m.top.filterChanged = m.top.activeFilters
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
