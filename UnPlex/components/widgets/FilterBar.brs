' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.countLabel = m.top.findNode("countLabel")

    ' Initialize default filter state
    m.filterState = { sort: "titleSort:asc", genre: "", year: "", unwatched: "" }
    m.top.activeFilters = {}
    m.top.filterState = m.filterState

    updateSummary()
end sub

sub onSectionIdChange(event as Object)
    ' Reset filters when section changes
    m.filterState = { sort: "titleSort:asc", genre: "", year: "", unwatched: "" }
    m.top.filterState = m.filterState
    m.top.activeFilters = {}
    updateSummary()
    m.top.filterChanged = m.top.activeFilters
end sub

sub onFilterStateChanged(event as Object)
    m.filterState = m.top.filterState
    params = buildFilterParams()
    m.top.activeFilters = params
    updateSummary()
    m.top.filterChanged = m.top.activeFilters
end sub

function buildFilterParams() as Object
    params = {}

    ' Always include sort
    params["sort"] = m.filterState.sort

    ' Optional filters
    if m.filterState.genre <> ""
        params["genre"] = m.filterState.genre
    end if

    if m.filterState.year <> ""
        params["year"] = m.filterState.year
    end if

    if m.filterState.unwatched <> ""
        params["unwatched"] = m.filterState.unwatched
    end if

    return params
end function

function buildFilterSummary() as String
    parts = []

    ' Genre filter
    if m.filterState.genre <> "" and m.top.genreNames <> invalid
        genreKeys = m.filterState.genre.Split(",")
        genreDisplayParts = []
        for each gKey in genreKeys
            gKey = gKey.Trim()
            if m.top.genreNames[gKey] <> invalid
                genreDisplayParts.Push(m.top.genreNames[gKey])
            else
                genreDisplayParts.Push(gKey)
            end if
        end for
        if genreDisplayParts.Count() > 0
            parts.Push("Genre: " + genreDisplayParts.Join(", "))
        end if
    else if m.filterState.genre <> ""
        parts.Push("Genre: " + m.filterState.genre)
    end if

    ' Unwatched filter
    if m.filterState.unwatched = "1"
        parts.Push("Unwatched")
    end if

    ' Year filter
    if m.filterState.year <> ""
        parts.Push("Year: " + m.filterState.year)
    end if

    ' If no filters active, show "All"
    if parts.Count() = 0
        text = "All"
    else
        text = parts.Join(" . ")
    end if

    ' Append sort display
    text = text + " . Sort: " + getSortDisplayName(m.filterState.sort)

    return text
end function

function getSortDisplayName(sortValue as String) as String
    if sortValue = "titleSort:asc"
        return "Title A-Z"
    else if sortValue = "titleSort:desc"
        return "Title Z-A"
    else if sortValue = "addedAt:desc"
        return "Date Added (Newest)"
    else if sortValue = "addedAt:asc"
        return "Date Added (Oldest)"
    else if sortValue = "year:desc"
        return "Year (Newest)"
    else if sortValue = "year:asc"
        return "Year (Oldest)"
    else if sortValue = "rating:desc"
        return "Rating (Highest)"
    else if sortValue = "rating:asc"
        return "Rating (Lowest)"
    end if

    return "Title A-Z"
end function

sub updateSummary()
    m.summaryLabel.text = buildFilterSummary()
    onTotalItemsChanged(invalid)
end sub

sub onTotalItemsChanged(event as Object)
    totalFiltered = m.top.totalFiltered
    totalItems = m.top.totalItems

    if totalFiltered = 0 and totalItems = 0
        m.countLabel.text = ""
    else if totalFiltered < totalItems and totalItems > 0
        m.countLabel.text = totalFiltered.ToStr() + " of " + totalItems.ToStr()
    else
        m.countLabel.text = totalItems.ToStr() + " items"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
