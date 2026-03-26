' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.userGrid = m.top.findNode("userGrid")
    m.emptyState = m.top.findNode("emptyState")
    m.loadingSpinner = m.top.findNode("loadingSpinner")

    m.users = []  ' Array of user data from API
    m.retryCount = 0
    m.pendingSwitchItem = invalid
    m.switchUserName = ""

    ' Observe grid selection
    m.userGrid.observeField("itemSelected", "onUserSelected")

    ' Delegate focus
    m.top.observeField("focusedChild", "onFocusChange")

    ' Fetch users on init
    fetchHomeUsers()
end sub

sub onFocusChange(event as Object)
    if m.top.isInFocusChain() and m.top.focusedChild = invalid
        m.userGrid.setFocus(true)
    end if
end sub

sub fetchHomeUsers()
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true
    m.emptyState.visible = false

    ' Ensure admin token is saved before any switch
    adminToken = GetAdminToken()
    if adminToken = ""
        ' First time - current token IS the admin token
        SetAdminToken(GetAuthToken())
        adminToken = GetAuthToken()
    end if

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "https://plex.tv/api/v2/home/users"
    task.params = {}
    task.isPlexTvRequest = true
    task.authTokenOverride = adminToken
    task.observeField("status", "onUsersLoaded")
    task.control = "run"
    m.usersTask = task
end sub

sub onUsersLoaded(event as Object)
    state = event.getData()
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false

    if state = "completed"
        processUsers()
    else if state = "error"
        if m.retryCount = 0
            m.retryCount = 1
            fetchHomeUsers()
        else
            m.retryCount = 0
            ' Show empty state with error
            m.emptyState.visible = true
            emptyTitle = m.top.findNode("emptyTitle")
            emptyTitle.text = "Couldn't load users"
            emptyMessage = m.top.findNode("emptyMessage")
            emptyMessage.text = "Check your network connection and try again"
        end if
    end if
end sub

sub processUsers()
    response = m.usersTask.response
    if response = invalid
        m.emptyState.visible = true
        return
    end if

    ' Response is an array of user objects
    users = response
    if type(response) = "roAssociativeArray" and response.users <> invalid
        users = response.users
    end if

    if type(users) <> "roArray" or users.count() = 0
        m.emptyState.visible = true
        return
    end if

    m.users = users
    content = CreateObject("roSGNode", "ContentNode")

    for each user in users
        node = content.createChild("ContentNode")

        userId = ""
        if user.id <> invalid
            if type(user.id) = "roString" or type(user.id) = "String"
                userId = user.id
            else
                userId = user.id.ToStr()
            end if
        end if

        node.addFields({
            title: SafeGet(user, "title", "User")
            userId: userId
            avatarUrl: SafeGet(user, "thumb", "")
            isProtected: SafeGet(user, "protected", false)
            isAdmin: SafeGet(user, "admin", false)
        })
    end for

    m.userGrid.content = content
    m.userGrid.setFocus(true)
end sub

sub onUserSelected(event as Object)
    index = event.getData()
    content = m.userGrid.content
    if content = invalid or index < 0 or index >= content.getChildCount()
        return
    end if

    item = content.getChild(index)

    ' Check if user is PIN-protected
    isProtected = false
    if item.hasField("isProtected")
        isProtected = item.getField("isProtected")
    end if
    if isProtected = true
        showPinDialog(item)
    else
        userId = ""
        if item.hasField("userId")
            userId = item.getField("userId")
        end if
        switchToUser(userId, item.title, "")
    end if
end sub

sub showPinDialog(item as Object)
    m.pendingSwitchItem = item

    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = "Enter PIN for " + item.title
    dialog.message = ["Enter the PIN to switch to this user"]
    dialog.buttons = ["Submit", "Cancel"]
    dialog.observeField("buttonSelected", "onPinDialogButton")
    dialog.observeField("wasClosed", "onPinDialogClosed")
    m.top.getScene().dialog = dialog
    m.pinDialog = dialog
end sub

sub onPinDialogButton(event as Object)
    index = event.getData()

    if index = 0
        ' Submit - get the entered PIN
        pin = m.pinDialog.text
        m.top.getScene().dialog.close = true

        userId = ""
        if m.pendingSwitchItem.hasField("userId")
            userId = m.pendingSwitchItem.getField("userId")
        end if
        switchToUser(userId, m.pendingSwitchItem.title, pin)
    else
        ' Cancel
        m.top.getScene().dialog.close = true
    end if
end sub

sub onPinDialogClosed(event as Object)
    m.userGrid.setFocus(true)
end sub

sub switchToUser(userId as String, userName as String, pin as String)
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true

    ' Use admin token for the switch request
    adminToken = GetAdminToken()

    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "https://plex.tv/api/v2/home/users/" + userId + "/switch"
    task.method = "POST"
    task.isPlexTvRequest = true
    task.authTokenOverride = adminToken
    task.suppress401 = true  ' Don't redirect to auth on wrong PIN

    params = {}
    if pin <> ""
        params["pin"] = pin
    end if
    task.params = params

    task.observeField("status", "onSwitchComplete")
    task.control = "run"
    m.switchTask = task
    m.switchUserName = userName
end sub

sub onSwitchComplete(event as Object)
    state = event.getData()
    if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = false

    if state = "completed"
        response = m.switchTask.response
        if response <> invalid and response.authToken <> invalid
            ' Switch successful - update active token
            SetAuthToken(response.authToken)
            SetActiveUserName(m.switchUserName)

            ' Signal user switched
            m.top.userSwitched = true
        else
            showSwitchError("Switch failed - no token received")
        end if
    else if state = "error"
        ' Check if PIN was wrong (401)
        if m.switchTask.responseCode = 401
            showSwitchError("Incorrect PIN. Please try again.")
            ' Re-show PIN dialog
            if m.pendingSwitchItem <> invalid
                isProtected = false
                if m.pendingSwitchItem.hasField("isProtected")
                    isProtected = m.pendingSwitchItem.getField("isProtected")
                end if
                if isProtected = true
                    showPinDialog(m.pendingSwitchItem)
                end if
            end if
        else
            showSwitchError("Couldn't switch user. Please try again.")
        end if
    end if
end sub

sub showSwitchError(message as String)
    if m.top.getScene().dialog <> invalid then return

    dialog = CreateThemedDialog()
    dialog.title = "Switch Failed"
    dialog.message = [message]
    dialog.buttons = ["OK"]
    dialog.observeField("wasClosed", "onErrorDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onErrorDialogClosed(event as Object)
    m.userGrid.setFocus(true)
end sub

sub cleanup()
    if m.usersTask <> invalid
        m.usersTask.control = "stop"
        m.usersTask.unobserveField("status")
    end if
    if m.switchTask <> invalid
        m.switchTask.control = "stop"
        m.switchTask.unobserveField("status")
    end if
    m.userGrid.unobserveField("itemSelected")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
