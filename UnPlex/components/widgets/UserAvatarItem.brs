' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.avatarBg = m.top.findNode("avatarBg")
    m.avatarImage = m.top.findNode("avatarImage")
    m.initialsLabel = m.top.findNode("initialsLabel")
    m.lockBadgeBg = m.top.findNode("lockBadgeBg")
    m.lockBadge = m.top.findNode("lockBadge")
    m.nameLabel = m.top.findNode("nameLabel")
end sub

sub onContentChange(event as Object)
    content = event.getData()
    if content = invalid then return

    ' Set name
    m.nameLabel.text = content.title

    ' Set avatar
    avatarUrl = ""
    if content.hasField("avatarUrl")
        avatarUrl = content.getField("avatarUrl")
    end if
    if avatarUrl <> invalid and avatarUrl <> ""
        m.avatarImage.uri = avatarUrl
        m.avatarImage.visible = true
        m.initialsLabel.visible = false
    else
        ' Show initials fallback
        m.avatarImage.visible = false
        m.initialsLabel.visible = true
        name = content.title
        if name <> invalid and Len(name) > 0
            m.initialsLabel.text = UCase(Left(name, 1))
        else
            m.initialsLabel.text = "?"
        end if
    end if

    ' Show lock badge for PIN-protected users
    isProtected = false
    if content.hasField("isProtected")
        isProtected = content.getField("isProtected")
    end if
    if isProtected = true
        m.lockBadgeBg.visible = true
        m.lockBadge.visible = true
    else
        m.lockBadgeBg.visible = false
        m.lockBadge.visible = false
    end if
end sub
