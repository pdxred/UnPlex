sub init()
    m.letters = ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    m.letterLabels = []
    m.focusIndex = 0

    ' 27 letters, 1080px height -> ~38px per letter, centered
    letterCount = m.letters.count()
    letterHeight = 38
    totalHeight = letterCount * letterHeight
    startY = Int((1080 - totalHeight) / 2)

    for i = 0 to letterCount - 1
        label = CreateObject("roSGNode", "Label")
        label.text = m.letters[i]
        label.width = 60
        label.height = letterHeight
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.font = "font:SmallBoldSystemFont"
        label.color = "0xA0A0B0FF"
        label.translation = [0, startY + (i * letterHeight)]
        m.top.appendChild(label)
        m.letterLabels.push(label)
    end for

    ' Focus indicator - highlight rectangle behind focused letter
    m.focusRect = CreateObject("roSGNode", "Rectangle")
    m.focusRect.width = 60
    m.focusRect.height = letterHeight
    m.focusRect.color = "0xF3B12566"
    m.focusRect.visible = false
    m.focusRect.translation = [0, startY]
    m.top.insertChild(m.focusRect, 1) ' Behind letters, in front of bg

    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange(event as Object)
    if m.top.isInFocusChain()
        m.focusRect.visible = true
        updateFocusVisual()
    else
        m.focusRect.visible = false
    end if
end sub

sub updateFocusVisual()
    if m.focusIndex >= 0 and m.focusIndex < m.letterLabels.count()
        ' Move focus rect to current letter position
        label = m.letterLabels[m.focusIndex]
        m.focusRect.translation = [0, label.translation[1]]

        ' Update colors: focused letter is bright, others are dim
        for i = 0 to m.letterLabels.count() - 1
            if i = m.focusIndex
                m.letterLabels[i].color = "0xFFFFFFFF"
            else
                m.letterLabels[i].color = "0xA0A0B0FF"
            end if
        end for
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up"
        if m.focusIndex > 0
            m.focusIndex = m.focusIndex - 1
            updateFocusVisual()
            return true
        end if
    else if key = "down"
        if m.focusIndex < m.letters.count() - 1
            m.focusIndex = m.focusIndex + 1
            updateFocusVisual()
            return true
        end if
    else if key = "OK"
        ' Fire the selected letter
        m.top.selectedLetter = m.letters[m.focusIndex]
        LogEvent("AlphaNav selected: " + m.letters[m.focusIndex])
        return true
    end if

    return false
end function
