' Copyright 2026 UnPlex contributors. MIT License.
' Log levels: ERROR (problems), EVENT (key milestones)
' Per CONTEXT.md: only log errors and key events, no verbose/debug

function Log(level as String, message as String)
    timestamp = CreateObject("roDateTime")
    timeStr = timestamp.ToISOString()
    line = "[" + timeStr + "] [" + level + "] " + message
    print line

    ' Append to in-memory ring buffer (m.global.logBuffer, max 500 entries)
    if m.global <> invalid and m.global.hasField("logBuffer")
        buffer = m.global.logBuffer
        if buffer = invalid then buffer = []
        buffer.push(line)
        ' Trim to 500 entries max (ring buffer)
        while buffer.count() > 500
            buffer.shift()
        end while
        m.global.logBuffer = buffer
    end if
end function

' Write the in-memory log buffer to tmp:/unplex_debug.log for download
' Returns true on success, false on failure
function ExportLogs() as Boolean
    if m.global = invalid or not m.global.hasField("logBuffer")
        return false
    end if

    buffer = m.global.logBuffer
    if buffer = invalid or buffer.count() = 0
        return false
    end if

    ' Join all log lines with newline
    output = ""
    for each line in buffer
        output = output + line + chr(10)
    end for

    ' Write to tmp:/ for download via Roku dev web server
    success = WriteAsciiFile("tmp:/unplex_debug.log", output)
    return success
end function

sub LogError(message as String)
    Log("ERROR", message)
end sub

sub LogEvent(message as String)
    Log("EVENT", message)
end sub
