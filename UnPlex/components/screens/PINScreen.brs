sub init()
    ' Store UI element references
    m.pinCodeLabel = m.top.findNode("pinCodeLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.errorLabel = m.top.findNode("errorLabel")
    m.loadingIndicator = m.top.findNode("loadingIndicator")

    ' Create auth task
    m.authTask = CreateObject("roSGNode", "PlexAuthTask")
    m.authTask.observeField("status", "onAuthStateChange")

    ' Create poll timer (2 second interval)
    m.pollTimer = CreateObject("roSGNode", "Timer")
    m.pollTimer.duration = 2
    m.pollTimer.repeat = true
    m.pollTimer.observeField("fire", "onPollTimer")

    ' Store current PIN info
    m.currentPinId = ""
    m.pinExpiresAt = ""

    m.isAuthenticated = false

    ' Start the PIN request flow
    startPinRequest()
end sub

sub startPinRequest()
    LogEvent("Requesting new PIN code")
    m.authTask.action = "requestPin"
    m.authTask.control = "run"

    ' Show loading state
    m.loadingIndicator.visible = true
    m.statusLabel.text = "Requesting PIN..."
    m.errorLabel.visible = false
end sub

sub onAuthStateChange(event as Object)
    state = event.getData()
    LogEvent("Auth state changed to: " + state)

    if state = "pinReady"
        ' Display the PIN code
        m.pinCodeLabel.text = m.authTask.pinCode
        m.currentPinId = m.authTask.pinId
        m.pinExpiresAt = m.authTask.expiresAt

        ' Update UI
        m.statusLabel.text = "Waiting for authorization..."
        m.loadingIndicator.visible = true
        m.errorLabel.visible = false

        ' Start polling
        m.pollTimer.control = "start"
        LogEvent("PIN ready: " + m.authTask.pinCode + " (ID: " + m.currentPinId + ")")

    else if state = "waiting"
        ' Check if PIN is expiring and needs refresh
        checkPinExpiration()

    else if state = "authenticated"
        ' Stop polling
        m.pollTimer.control = "stop"
        m.isAuthenticated = true
        LogEvent("PIN authentication successful")

        ' Update UI
        m.statusLabel.text = "Success! Loading servers..."
        m.loadingIndicator.visible = true

        ' Create a fresh task for resource fetch (reusing stopped tasks is unreliable)
        m.authTask.control = "stop"
        m.authTask.unobserveField("status")
        m.authTask = CreateObject("roSGNode", "PlexAuthTask")
        m.authTask.authToken = GetAuthToken()
        m.authTask.observeField("status", "onAuthStateChange")
        m.authTask.action = "fetchResources"
        m.authTask.control = "run"

    else if state = "serversReady"
        ' Hide loading indicator
        m.loadingIndicator.visible = false

        ' Pass data up to parent
        m.top.servers = m.authTask.servers
        m.top.authToken = m.authTask.authToken
        m.top.state = "authenticated"
        LogEvent("Servers ready: " + m.authTask.servers.count().ToStr() + " server(s)")

    else if state = "error"
        ' Stop polling and show error
        m.pollTimer.control = "stop"
        m.loadingIndicator.visible = false

        m.errorLabel.text = m.authTask.error
        m.errorLabel.visible = true
        m.statusLabel.text = ""
        LogError("PIN auth failed: " + m.authTask.error)

    else if state = "refreshing"
        ' PIN expired, request a new one
        LogEvent("PIN expired, requesting new PIN")
        m.pollTimer.control = "stop"
        startPinRequest()
    end if
end sub

sub checkPinExpiration()
    ' Check if PIN is about to expire (< 30 seconds)
    if m.pinExpiresAt = "" then return

    ' Parse expiration time
    expiresDateTime = CreateObject("roDateTime")
    expiresDateTime.FromISO8601String(m.pinExpiresAt)

    ' Get current time
    currentDateTime = CreateObject("roDateTime")

    ' Calculate time remaining in seconds
    expiresSeconds = expiresDateTime.AsSeconds()
    currentSeconds = currentDateTime.AsSeconds()
    timeRemaining = expiresSeconds - currentSeconds

    ' If less than 30 seconds, auto-refresh
    if timeRemaining < 30
        LogEvent("PIN expiring in " + timeRemaining.ToStr() + " seconds, auto-refreshing")
        m.pollTimer.control = "stop"
        startPinRequest()
    end if
end sub

sub onPollTimer(event as Object)
    ' Don't poll if already authenticated (prevents race with fetchResources)
    if m.isAuthenticated then return

    ' Poll the PIN status
    if m.currentPinId <> ""
        m.authTask.action = "checkPin"
        m.authTask.pinId = m.currentPinId
        m.authTask.control = "run"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        ' Cancel authentication flow
        LogEvent("User cancelled PIN authentication")
        m.pollTimer.control = "stop"
        m.authTask.control = "stop"
        m.top.state = "cancelled"
        return true
    end if
    return false
end function
