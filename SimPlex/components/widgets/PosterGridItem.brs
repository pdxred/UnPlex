sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.unwatchedIndicator = m.top.findNode("unwatchedIndicator")
end sub

sub onItemContentChange(event as Object)
    content = event.getData()
    if content = invalid
        return
    end if

    ' Set poster image
    if content.HDPosterUrl <> invalid and content.HDPosterUrl <> ""
        m.poster.uri = content.HDPosterUrl
    else
        m.poster.uri = "pkg:/images/placeholder_poster.png"
    end if

    ' Set title
    if content.title <> invalid
        m.titleLabel.text = content.title
    else
        m.titleLabel.text = ""
    end if

    ' Show unwatched indicator if applicable
    if content.viewOffset <> invalid and content.viewOffset > 0
        ' In progress - could show progress bar instead
        m.unwatchedIndicator.visible = true
        m.unwatchedIndicator.color = "0x3399FFFF"  ' Blue for in-progress
    else if content.watched <> invalid and not content.watched
        m.unwatchedIndicator.visible = true
        m.unwatchedIndicator.color = "0xE5A00DFF"  ' Gold for unwatched
    else
        m.unwatchedIndicator.visible = false
    end if
end sub
