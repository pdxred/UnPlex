' Log levels: ERROR (problems), EVENT (key milestones)
' Per CONTEXT.md: only log errors and key events, no verbose/debug

function Log(level as String, message as String)
    timestamp = CreateObject("roDateTime")
    timeStr = timestamp.ToISOString()
    print "[" + timeStr + "] [" + level + "] " + message
end function

sub LogError(message as String)
    Log("ERROR", message)
end sub

sub LogEvent(message as String)
    Log("EVENT", message)
end sub
