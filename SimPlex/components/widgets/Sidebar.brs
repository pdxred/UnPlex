sub init()
    c = m.global.constants
    m.top.width = c.SIDEBAR_WIDTH
    m.top.height = 1080
    m.top.color = c.BG_SIDEBAR

    ' Position "Plex" label right after "Sim" at same vertical position
    titleSim = m.top.findNode("titleSim")
    titlePlex = m.top.findNode("titlePlex")
    simBounds = titleSim.boundingRect()
    titlePlex.translation = [20 + simBounds.width, 25]

    m.navList = m.top.findNode("navList")
    m.navList.itemSize = [c.SIDEBAR_WIDTH, 76]
    m.navList.numRows = 12

    m.libraries = []
    m.libraryCount = 0

    ' Observe selection
    m.navList.observeField("itemSelected", "onItemSelected")

    ' Delegate focus to navList when sidebar receives focus
    m.top.observeField("focusedChild", "onFocusChange")

    ' Observe sidebar refresh signal from settings
    m.global.observeField("sidebarNeedRefresh", "onSidebarNeedRefresh")

    ' Build nav content immediately (nav items only, no separator at top)
    buildNavContent()

    ' Fetch libraries (will rebuild content with libraries when complete)
    loadLibraries()
end sub

sub loadLibraries()
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/sections"
    task.params = {}
    task.observeField("status", "onLibraryTaskStateChange")
    task.control = "run"
    m.libraryTask = task
end sub

sub onLibraryTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        processLibraries()
    end if
end sub

sub processLibraries()
    response = m.libraryTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    directories = response.MediaContainer.Directory
    if directories = invalid
        return
    end if

    ' Filter to supported library types (video only)
    supported = []
    for each lib in directories
        if lib.type = "movie" or lib.type = "show"
            supported.push(lib)
        end if
    end for

    ' Check for pinned sidebar libraries
    pinnedLibs = GetSidebarLibraries()
    if pinnedLibs.count() > 0
        ' Show only pinned libraries in stored order
        ordered = []
        for each pinned in pinnedLibs
            for each lib in supported
                if lib.key = pinned.key
                    ordered.push(lib)
                    exit for
                end if
            end for
        end for
        m.libraries = ordered
    else
        ' No pinned libraries - show all alphabetically (backward compatible)
        m.libraries = sortLibraries(supported)
    end if

    m.libraryCount = m.libraries.count()
    buildNavContent()
end sub

sub buildNavContent()
    content = CreateObject("roSGNode", "ContentNode")

    ' Library items
    for each lib in m.libraries
        node = content.createChild("ContentNode")
        node.title = lib.title
        node.addFields({ isSeparator: false })
    end for

    ' Only add separator between libraries and nav when libraries exist
    if m.libraryCount > 0
        sep = content.createChild("ContentNode")
        sep.title = ""
        sep.addFields({ isSeparator: true })
    end if

    ' Navigation items
    navItems = ["Home", "Collections", "Playlists", "Search", "Settings"]
    for each navItem in navItems
        node = content.createChild("ContentNode")
        node.title = navItem
        node.addFields({ isSeparator: false })
    end for

    ' Trailing separator after Settings (visual bookend)
    sep2 = content.createChild("ContentNode")
    sep2.title = ""
    sep2.addFields({ isSeparator: true })

    m.navList.content = content

    ' Reinitialize focus on navList after content change
    if m.top.isInFocusChain()
        m.navList.jumpToItem = 0
        m.navList.setFocus(true)
    end if
end sub

sub onItemSelected(event as Object)
    index = event.getData()
    lc = m.libraryCount

    ' Calculate nav offset: libraries + separator (if libraries exist)
    if lc > 0
        navOffset = lc + 1  ' libraries + separator
    else
        navOffset = 0  ' no libraries, no separator
    end if

    if index < lc
        ' Library selected
        lib = m.libraries[index]
        m.top.selectedLibrary = {
            sectionId: lib.key
            sectionType: lib.type
            title: lib.title
        }
    else if lc > 0 and index = lc
        ' Separator row - ignore
        return
    else if index = navOffset
        m.top.specialAction = "viewHome"
    else if index = navOffset + 1
        m.top.specialAction = "viewCollections"
    else if index = navOffset + 2
        m.top.specialAction = "playlists"
    else if index = navOffset + 3
        m.top.specialAction = "search"
    else if index = navOffset + 4
        m.top.specialAction = "settings"
    end if
end sub

sub onFocusChange(event as Object)
    ' When Sidebar is in focus chain but no child has focus, delegate to navList
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.navList.jumpToItem = 0
        m.navList.setFocus(true)
    end if
end sub

sub onSidebarNeedRefresh(event as Object)
    if m.global.sidebarNeedRefresh = true
        m.global.sidebarNeedRefresh = false
        loadLibraries()
    end if
end sub

function sortLibraries(libs as Object) as Object
    sorted = []
    for each lib in libs
        sorted.push(lib)
    end for
    ' Simple insertion sort by title (small list)
    for i = 1 to sorted.count() - 1
        key = sorted[i]
        j = i - 1
        while j >= 0 and LCase(sorted[j].title) > LCase(key.title)
            sorted[j + 1] = sorted[j]
            j = j - 1
        end while
        sorted[j + 1] = key
    end for
    return sorted
end function

sub cleanup()
    if m.libraryTask <> invalid
        m.libraryTask.control = "stop"
        m.libraryTask.unobserveField("status")
    end if
    m.navList.unobserveField("itemSelected")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
