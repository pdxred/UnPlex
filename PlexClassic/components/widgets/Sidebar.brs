sub init()
    c = GetConstants()
    m.top.width = c.SIDEBAR_WIDTH
    m.top.height = 1080
    m.top.color = c.BG_SIDEBAR

    m.libraryList = m.top.findNode("libraryList")
    m.hubList = m.top.findNode("hubList")
    m.bottomList = m.top.findNode("bottomList")
    m.separator1 = m.top.findNode("separator1")
    m.separator2 = m.top.findNode("separator2")

    m.libraries = []
    m.activeList = "library"

    ' Set up API task to fetch libraries
    m.apiTask = CreateObject("roSGNode", "PlexApiTask")
    m.apiTask.observeField("state", "onApiTaskStateChange")

    ' Observe list selections
    m.libraryList.observeField("itemSelected", "onLibrarySelected")
    m.hubList.observeField("itemSelected", "onHubSelected")
    m.bottomList.observeField("itemSelected", "onBottomSelected")

    ' Set up hub and bottom lists (static items)
    setupStaticLists()

    ' Fetch libraries
    loadLibraries()
end sub

sub setupStaticLists()
    ' Hub items: On Deck, Recently Added
    hubContent = CreateObject("roSGNode", "ContentNode")
    hubItems = ["On Deck", "Recently Added"]
    for each item in hubItems
        node = hubContent.createChild("ContentNode")
        node.title = "  " + item  ' Indent for visual
    end for
    m.hubList.content = hubContent

    ' Bottom items: Search, Settings
    bottomContent = CreateObject("roSGNode", "ContentNode")
    bottomItems = ["Search", "Settings"]
    for each item in bottomItems
        node = bottomContent.createChild("ContentNode")
        node.title = "  " + item
    end for
    m.bottomList.content = bottomContent
end sub

sub loadLibraries()
    m.apiTask.endpoint = "/library/sections"
    m.apiTask.params = {}
    m.apiTask.control = "run"
end sub

sub onApiTaskStateChange(event as Object)
    state = event.getData()
    if state = "completed"
        processLibraries()
    end if
end sub

sub processLibraries()
    response = m.apiTask.response
    if response = invalid or response.MediaContainer = invalid
        return
    end if

    directories = response.MediaContainer.Directory
    if directories = invalid
        return
    end if

    m.libraries = directories
    content = CreateObject("roSGNode", "ContentNode")

    for each lib in directories
        node = content.createChild("ContentNode")
        ' Add icon prefix based on type
        prefix = "  "
        if lib.type = "movie"
            prefix = "  " ' Could use unicode film icon if supported
        else if lib.type = "show"
            prefix = "  "
        else if lib.type = "artist"
            prefix = "  "
        end if
        node.title = prefix + lib.title
    end for

    m.libraryList.content = content

    ' Position the other elements based on library count
    layoutLists()

    ' Focus library list
    m.libraryList.setFocus(true)
end sub

sub layoutLists()
    libCount = m.libraries.count()
    libHeight = libCount * 50

    ' Position separator1 after library list
    m.separator1.translation = [20, 100 + libHeight + 10]

    ' Position hub list after separator1
    m.hubList.translation = [0, 100 + libHeight + 22]
    hubHeight = 2 * 50  ' 2 hub items

    ' Position separator2 after hub list
    m.separator2.translation = [20, 100 + libHeight + 22 + hubHeight + 10]

    ' Position bottom list after separator2
    m.bottomList.translation = [0, 100 + libHeight + 22 + hubHeight + 22]
end sub

sub onLibrarySelected(event as Object)
    index = event.getData()
    if index >= 0 and index < m.libraries.count()
        lib = m.libraries[index]
        m.top.selectedLibrary = {
            sectionId: lib.key
            sectionType: lib.type
            title: lib.title
        }
    end if
end sub

sub onHubSelected(event as Object)
    index = event.getData()
    if index = 0
        m.top.specialAction = "onDeck"
    else if index = 1
        m.top.specialAction = "recentlyAdded"
    end if
end sub

sub onBottomSelected(event as Object)
    index = event.getData()
    if index = 0
        m.top.specialAction = "search"
    else if index = 1
        m.top.specialAction = "settings"
    end if
end sub

sub cleanup()
    if m.apiTask <> invalid
        m.apiTask.control = "stop"
        m.apiTask.unobserveField("state")
    end if

    m.libraryList.unobserveField("itemSelected")
    m.hubList.unobserveField("itemSelected")
    m.bottomList.unobserveField("itemSelected")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down"
        if m.activeList = "library"
            if m.libraryList.itemFocused >= m.libraries.count() - 1
                m.activeList = "hub"
                m.hubList.setFocus(true)
                return true
            end if
        else if m.activeList = "hub"
            if m.hubList.itemFocused >= 1
                m.activeList = "bottom"
                m.bottomList.setFocus(true)
                return true
            end if
        end if
    else if key = "up"
        if m.activeList = "bottom"
            if m.bottomList.itemFocused <= 0
                m.activeList = "hub"
                m.hubList.setFocus(true)
                return true
            end if
        else if m.activeList = "hub"
            if m.hubList.itemFocused <= 0
                m.activeList = "library"
                m.libraryList.setFocus(true)
                return true
            end if
        end if
    end if

    return false
end function
