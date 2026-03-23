sub init()
    m.focusBg = m.top.findNode("focusBg")
    m.focusAccent = m.top.findNode("focusAccent")
    m.titleLabel = m.top.findNode("titleLabel")
    m.separatorLine = m.top.findNode("separatorLine")
    m.isSeparator = false
end sub

sub onContentChange(event as Object)
    content = event.getData()
    if content = invalid then return

    m.isSeparator = false
    m.titleLabel.visible = false
    m.separatorLine.visible = false

    isSep = false
    if content.isSeparator <> invalid then isSep = content.isSeparator

    if isSep
        m.isSeparator = true
        m.separatorLine.visible = true
        return
    end if

    m.titleLabel.text = content.title
    m.titleLabel.visible = true
    m.titleLabel.color = "0xFFFFFFFF"
end sub

sub onFocusChange(event as Object)
    focusPercent = event.getData()
    hasFocus = (focusPercent > 0.5)

    if m.isSeparator
        ' Separators never show focus
        m.focusBg.visible = false
        m.focusAccent.visible = false
        return
    end if

    m.focusBg.visible = hasFocus
    m.focusAccent.visible = hasFocus

    if hasFocus
        m.titleLabel.color = "0xE5A00DFF"
        m.titleLabel.font = "font:SmallBoldSystemFont"
    else
        m.titleLabel.color = "0xFFFFFFFF"
        m.titleLabel.font = "font:SmallSystemFont"
    end if
end sub
