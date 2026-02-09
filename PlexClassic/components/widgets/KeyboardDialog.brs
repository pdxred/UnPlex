sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.keyboard = m.top.findNode("keyboard")
    m.buttonGroup = m.top.findNode("buttonGroup")

    m.keyboard.observeField("text", "onTextChange")
    m.buttonGroup.observeField("buttonSelected", "onButtonSelected")

    m.keyboard.setFocus(true)
end sub

sub onTitleChange(event as Object)
    m.titleLabel.text = event.getData()
end sub

sub onTextChange(event as Object)
    m.top.text = event.getData()
end sub

sub onButtonSelected(event as Object)
    index = event.getData()
    if index = 0
        ' OK
        m.top.textSubmitted = m.keyboard.text
    else
        ' Cancel
        m.top.cancelled = true
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.cancelled = true
        return true
    end if

    return false
end function
