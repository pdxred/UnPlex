sub init()
    m.sheetGroup = m.top.findNode("sheetGroup")
    m.sortList = m.top.findNode("sortList")
    m.unwatchedList = m.top.findNode("unwatchedList")
    m.genreList = m.top.findNode("genreList")
    m.yearList = m.top.findNode("yearList")
    m.clearAllButton = m.top.findNode("clearAllButton")
    m.slideUpAnim = m.top.findNode("slideUpAnim")
    m.slideDownAnim = m.top.findNode("slideDownAnim")

    m.isOpen = false
    m.genreKeys = []
    m.genreNames = {}
    m.yearValues = []
    m.currentFilterState = { sort: "titleSort:asc", genre: "", year: "", unwatched: "" }

    ' Sort values mapping (index -> API sort string)
    m.sortValues = [
        "titleSort:asc"
        "titleSort:desc"
        "addedAt:desc"
        "addedAt:asc"
        "year:desc"
        "year:asc"
        "rating:desc"
        "rating:asc"
    ]

    ' Populate sort list
    populateSortList()

    ' Populate unwatched list
    populateUnwatchedList()

    ' Observe controls
    m.sortList.observeField("checkedItem", "onSortChanged")
    m.unwatchedList.observeField("itemSelected", "onUnwatchedChanged")
    m.genreList.observeField("checkedState", "onGenreChanged")
    m.yearList.observeField("itemSelected", "onYearSelected")
    m.clearAllButton.observeField("buttonSelected", "onClearAll")

    ' Track which column has focus for left/right navigation
    m.focusedColumn = 0 ' 0=sort, 1=unwatched/genre, 2=year, 3=clearAll
end sub

sub populateSortList()
    sortContent = CreateObject("roSGNode", "ContentNode")

    sortLabels = [
        "Title A-Z"
        "Title Z-A"
        "Date Added (Newest)"
        "Date Added (Oldest)"
        "Year (Newest)"
        "Year (Oldest)"
        "Rating (Highest)"
        "Rating (Lowest)"
    ]

    for each label in sortLabels
        item = sortContent.createChild("ContentNode")
        item.title = label
    end for

    m.sortList.content = sortContent
    m.sortList.checkedItem = 0
end sub

sub populateUnwatchedList()
    unwatchedContent = CreateObject("roSGNode", "ContentNode")

    labels = ["All Items", "Unwatched Only"]
    for each label in labels
        item = unwatchedContent.createChild("ContentNode")
        item.title = label
    end for

    m.unwatchedList.content = unwatchedContent
end sub

sub onSectionIdChange(event as Object)
    ' Reset filter state when section changes
    m.currentFilterState = { sort: "titleSort:asc", genre: "", year: "", unwatched: "" }
    m.sortList.checkedItem = 0
    m.genreKeys = []
    m.genreNames = {}
    m.yearValues = []

    ' Fetch genre and year lists for the new section
    if m.top.sectionId <> ""
        loadGenres()
        loadYears()
    end if
end sub

sub loadGenres()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/sections/" + m.top.sectionId + "/genre"
    task.params = { "type": m.top.sectionType }
    task.observeField("status", "onGenresLoaded")
    task.control = "run"
    m.genreTask = task
end sub

sub onGenresLoaded(event as Object)
    if event.getData() <> "completed" then return
    if m.genreTask.response = invalid or m.genreTask.response.MediaContainer = invalid then return

    container = m.genreTask.response.MediaContainer
    directories = container.Directory
    if directories = invalid then directories = []

    genreContent = CreateObject("roSGNode", "ContentNode")
    m.genreKeys = []
    m.genreNames = {}

    for each dir in directories
        item = genreContent.createChild("ContentNode")
        item.title = dir.title

        keyStr = ""
        if dir.key <> invalid
            if type(dir.key) = "roString" or type(dir.key) = "String"
                keyStr = dir.key
            else
                keyStr = dir.key.ToStr()
            end if
        end if

        m.genreKeys.Push(keyStr)
        m.genreNames[keyStr] = dir.title
    end for

    m.genreList.content = genreContent

    ' Reset checked state to all unchecked
    checkedState = []
    for i = 0 to m.genreKeys.Count() - 1
        checkedState.Push(false)
    end for
    m.genreList.checkedState = checkedState

    ' Share genre display names for FilterBar
    m.top.genreDisplayNames = m.genreNames
end sub

sub loadYears()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/sections/" + m.top.sectionId + "/year"
    task.params = { "type": m.top.sectionType }
    task.observeField("status", "onYearsLoaded")
    task.control = "run"
    m.yearTask = task
end sub

sub onYearsLoaded(event as Object)
    if event.getData() <> "completed" then return
    if m.yearTask.response = invalid or m.yearTask.response.MediaContainer = invalid then return

    container = m.yearTask.response.MediaContainer
    directories = container.Directory
    if directories = invalid then directories = []

    yearContent = CreateObject("roSGNode", "ContentNode")
    m.yearValues = []

    ' Add "All Years" as first item
    allItem = yearContent.createChild("ContentNode")
    allItem.title = "All Years"
    m.yearValues.Push("")

    ' Collect all years as integers for grouping into decades
    yearInts = []
    yearMap = {}
    for each dir in directories
        keyStr = ""
        if dir.key <> invalid
            if type(dir.key) = "roString" or type(dir.key) = "String"
                keyStr = dir.key
            else
                keyStr = dir.key.ToStr()
            end if
        end if

        yearInt = Val(keyStr)
        if yearInt > 0
            yearInts.Push(yearInt)
            yearMap[keyStr] = dir.title
        end if
    end for

    ' Sort years descending (simple bubble sort -- small list)
    for i = 0 to yearInts.Count() - 2
        for j = 0 to yearInts.Count() - 2 - i
            if yearInts[j] < yearInts[j + 1]
                temp = yearInts[j]
                yearInts[j] = yearInts[j + 1]
                yearInts[j + 1] = temp
            end if
        end for
    end for

    ' Group into decades
    addedDecades = {}
    for each yr in yearInts
        decade = Int(yr / 10) * 10
        decadeStr = decade.ToStr() + "s"

        if addedDecades[decadeStr] = invalid
            ' Add decade entry
            decadeItem = yearContent.createChild("ContentNode")
            decadeItem.title = decadeStr

            ' Build comma-separated range for the decade
            decadeYears = []
            for each y2 in yearInts
                d2 = Int(y2 / 10) * 10
                if d2 = decade
                    decadeYears.Push(y2.ToStr())
                end if
            end for

            m.yearValues.Push(decadeYears.Join(","))
            addedDecades[decadeStr] = true
        end if
    end for

    m.yearList.content = yearContent
end sub

sub onSortChanged(event as Object)
    index = m.sortList.checkedItem
    if index >= 0 and index < m.sortValues.Count()
        m.currentFilterState.sort = m.sortValues[index]
        emitFilterState()
    end if
end sub

sub onUnwatchedChanged(event as Object)
    index = event.getData()
    if index = 0
        m.currentFilterState.unwatched = ""
    else
        m.currentFilterState.unwatched = "1"
    end if
    emitFilterState()
end sub

sub onGenreChanged(event as Object)
    checkedState = m.genreList.checkedState
    selectedGenres = []

    if checkedState <> invalid
        for i = 0 to checkedState.Count() - 1
            if checkedState[i] = true and i < m.genreKeys.Count()
                selectedGenres.Push(m.genreKeys[i])
            end if
        end for
    end if

    m.currentFilterState.genre = selectedGenres.Join(",")
    emitFilterState()
end sub

sub onYearSelected(event as Object)
    index = event.getData()
    if index >= 0 and index < m.yearValues.Count()
        m.currentFilterState.year = m.yearValues[index]
    else
        m.currentFilterState.year = ""
    end if
    emitFilterState()
end sub

sub onClearAll(event as Object)
    ' Reset all filter state to defaults
    m.currentFilterState = { sort: "titleSort:asc", genre: "", year: "", unwatched: "" }

    ' Reset sort list selection
    m.sortList.checkedItem = 0

    ' Reset genre checklist to all unchecked
    if m.genreKeys.Count() > 0
        checkedState = []
        for i = 0 to m.genreKeys.Count() - 1
            checkedState.Push(false)
        end for
        m.genreList.checkedState = checkedState
    end if

    emitFilterState()
end sub

sub emitFilterState()
    m.top.filterState = m.currentFilterState
end sub

sub onShowSheetChange(event as Object)
    if event.getData() = true
        m.top.visible = true
        openSheet()
    else
        if m.isOpen
            closeSheet()
        end if
    end if
end sub

sub openSheet()
    m.sheetGroup.visible = true
    m.slideUpAnim.control = "start"
    m.isOpen = true
    m.focusedColumn = 0
    m.sortList.setFocus(true)
end sub

sub closeSheet()
    m.slideDownAnim.observeField("state", "onSlideDownComplete")
    m.slideDownAnim.control = "start"
end sub

sub onSlideDownComplete(event as Object)
    if event.getData() = "stopped"
        m.sheetGroup.visible = false
        m.slideDownAnim.unobserveField("state")
        m.isOpen = false
        m.top.sheetDismissed = true
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or not m.isOpen then return false

    if key = "back"
        closeSheet()
        return true
    end if

    ' Left/right navigation between columns
    if key = "right"
        if m.focusedColumn = 0
            ' Sort -> Unwatched/Genre
            m.focusedColumn = 1
            m.unwatchedList.setFocus(true)
            return true
        else if m.focusedColumn = 1
            ' Unwatched/Genre -> Year
            m.focusedColumn = 2
            m.yearList.setFocus(true)
            return true
        else if m.focusedColumn = 2
            ' Year -> Clear All
            m.focusedColumn = 3
            m.clearAllButton.setFocus(true)
            return true
        end if
    else if key = "left"
        if m.focusedColumn = 3
            ' Clear All -> Year
            m.focusedColumn = 2
            m.yearList.setFocus(true)
            return true
        else if m.focusedColumn = 2
            ' Year -> Unwatched/Genre
            m.focusedColumn = 1
            m.unwatchedList.setFocus(true)
            return true
        else if m.focusedColumn = 1
            ' Unwatched/Genre -> Sort
            m.focusedColumn = 0
            m.sortList.setFocus(true)
            return true
        end if
    else if key = "down"
        ' Handle transition from unwatched to genre within same column
        if m.focusedColumn = 1
            if m.unwatchedList.isInFocusChain()
                m.genreList.setFocus(true)
                return true
            end if
        end if
        ' Let lists handle their own up/down scrolling
        return false
    else if key = "up"
        ' Handle transition from genre to unwatched within same column
        if m.focusedColumn = 1
            if m.genreList.isInFocusChain()
                m.unwatchedList.setFocus(true)
                return true
            end if
        end if
        ' Let lists handle their own up/down scrolling
        return false
    end if

    return false
end function
