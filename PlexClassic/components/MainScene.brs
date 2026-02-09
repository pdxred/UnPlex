sub init()
    m.screenContainer = m.top.findNode("screenContainer")
    m.screenStack = []
    m.focusStack = []

    ' Set up global node for shared state
    m.global.addFields({
        authToken: GetAuthToken()
        serverUri: GetServerUri()
    })

    ' Check auth state and show appropriate screen
    if m.global.authToken <> "" and m.global.serverUri <> ""
        showHomeScreen()
    else
        showSettingsScreen()
    end if
end sub

sub showHomeScreen()
    screen = CreateObject("roSGNode", "HomeScreen")
    pushScreen(screen)
    m.top.currentScreen = "home"
end sub

sub showSettingsScreen()
    screen = CreateObject("roSGNode", "SettingsScreen")
    screen.observeField("authComplete", "onAuthComplete")
    pushScreen(screen)
    m.top.currentScreen = "settings"
end sub

sub showDetailScreen(ratingKey as String, itemType as String)
    screen = CreateObject("roSGNode", "DetailScreen")
    screen.ratingKey = ratingKey
    screen.itemType = itemType
    pushScreen(screen)
    m.top.currentScreen = "detail"
end sub

sub showEpisodeScreen(ratingKey as String, showTitle as String)
    screen = CreateObject("roSGNode", "EpisodeScreen")
    screen.ratingKey = ratingKey
    screen.showTitle = showTitle
    pushScreen(screen)
    m.top.currentScreen = "episodes"
end sub

sub showSearchScreen()
    screen = CreateObject("roSGNode", "SearchScreen")
    pushScreen(screen)
    m.top.currentScreen = "search"
end sub

sub pushScreen(screen as Object)
    ' Store current focus position before pushing
    if m.screenStack.count() > 0
        currentScreen = m.screenStack.peek()
        focusedNode = currentScreen.focusedChild
        if focusedNode <> invalid
            m.focusStack.push(focusedNode)
        else
            m.focusStack.push(invalid)
        end if
        currentScreen.visible = false
    end if

    m.screenContainer.appendChild(screen)
    m.screenStack.push(screen)
    screen.setFocus(true)

    ' Observe screen events
    screen.observeField("itemSelected", "onItemSelected")
    screen.observeField("navigateBack", "onNavigateBack")
end sub

sub popScreen()
    if m.screenStack.count() <= 1
        ' Show exit confirmation on last screen
        showExitDialog()
        return
    end if

    ' Remove current screen
    currentScreen = m.screenStack.pop()
    m.screenContainer.removeChild(currentScreen)

    ' Restore previous screen
    previousScreen = m.screenStack.peek()
    previousScreen.visible = true

    ' Restore focus
    if m.focusStack.count() > 0
        savedFocus = m.focusStack.pop()
        if savedFocus <> invalid
            savedFocus.setFocus(true)
        else
            previousScreen.setFocus(true)
        end if
    else
        previousScreen.setFocus(true)
    end if

    ' Update current screen name
    if previousScreen.subtype() = "HomeScreen"
        m.top.currentScreen = "home"
    else if previousScreen.subtype() = "DetailScreen"
        m.top.currentScreen = "detail"
    else if previousScreen.subtype() = "EpisodeScreen"
        m.top.currentScreen = "episodes"
    else if previousScreen.subtype() = "SearchScreen"
        m.top.currentScreen = "search"
    else if previousScreen.subtype() = "SettingsScreen"
        m.top.currentScreen = "settings"
    end if
end sub

sub showExitDialog()
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = "Exit PlexClassic?"
    dialog.message = ["Are you sure you want to exit?"]
    dialog.buttons = ["Exit", "Cancel"]
    dialog.observeField("buttonSelected", "onExitDialogButton")
    m.top.dialog = dialog
end sub

sub onExitDialogButton(event as Object)
    buttonIndex = event.getData()
    m.top.dialog.close = true
    if buttonIndex = 0
        ' User selected Exit
        m.top.close = true
    end if
end sub

sub onAuthComplete(event as Object)
    ' Auth completed successfully, refresh global state and show home
    m.global.authToken = GetAuthToken()
    m.global.serverUri = GetServerUri()

    ' Remove settings screen and show home
    while m.screenStack.count() > 0
        screen = m.screenStack.pop()
        m.screenContainer.removeChild(screen)
    end while
    m.focusStack.clear()

    showHomeScreen()
end sub

sub onItemSelected(event as Object)
    data = event.getData()
    if data <> invalid
        if data.action = "detail"
            showDetailScreen(data.ratingKey, data.itemType)
        else if data.action = "episodes"
            showEpisodeScreen(data.ratingKey, data.title)
        else if data.action = "search"
            showSearchScreen()
        else if data.action = "settings"
            showSettingsScreen()
        end if
    end if
end sub

sub onNavigateBack(event as Object)
    popScreen()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        popScreen()
        return true
    end if

    return false
end function
