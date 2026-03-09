sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.unwatchedIndicator = m.top.findNode("unwatchedIndicator")
    m.progressBg = m.top.findNode("progressBg")
    m.progressBar = m.top.findNode("progressBar")
end sub

sub onItemContentChange(event as Object)
    content = event.getData()
    if content = invalid
        return
    end if

    ' Set poster image
    if content.HDPosterUrl <> invalid and content.HDPosterUrl <> ""
        m.poster.uri = content.HDPosterUrl
    end if

    ' Set title
    if content.title <> invalid
        m.titleLabel.text = content.title
    else
        m.titleLabel.text = ""
    end if

    ' Update progress bar (must be called before unwatched indicator logic)
    updateProgressBar(content)

    ' Show unwatched indicator if applicable (hidden when progress bar is visible)
    if m.progressBar.visible
        m.unwatchedIndicator.visible = false
    else if content.viewOffset <> invalid and content.viewOffset > 0
        m.unwatchedIndicator.visible = true
        m.unwatchedIndicator.color = "0x3399FFFF"  ' Blue for in-progress
    else if content.watched <> invalid and not content.watched
        m.unwatchedIndicator.visible = true
        m.unwatchedIndicator.color = "0xE5A00DFF"  ' Gold for unwatched
    else
        m.unwatchedIndicator.visible = false
    end if
end sub

sub updateProgressBar(content as Object)
    viewOffset = 0
    duration = 0
    if content.viewOffset <> invalid then viewOffset = content.viewOffset
    if content.duration <> invalid then duration = content.duration

    if viewOffset > 0 and duration > 0
        progress = viewOffset / duration
        if progress > 1.0 then progress = 1.0
        m.progressBg.visible = true
        m.progressBar.visible = true
        m.progressBar.width = Int(240 * progress)
    else
        m.progressBg.visible = false
        m.progressBar.visible = false
    end if
end sub
