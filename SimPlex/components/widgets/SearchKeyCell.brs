sub onContentChange(event as Object)
    content = event.getData()
    if content = invalid then return
    label = m.top.findNode("keyLabel")
    if content.title <> invalid
        label.text = content.title
    end if
end sub

sub onFocusChange(event as Object)
    pct = event.getData()
    bg = m.top.findNode("keyBg")
    label = m.top.findNode("keyLabel")
    if pct > 0.5
        bg.color = "0xF3B125FF"
        label.color = "0x000000FF"
    else
        bg.color = "0xFFFFFF10"
        label.color = "0xCCCCCCFF"
    end if
end sub
