sub init()
    m.thumbnail = m.top.findNode("thumbnail")
    m.titleLabel = m.top.findNode("titleLabel")
    m.durationLabel = m.top.findNode("durationLabel")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.watchedBadge = m.top.findNode("watchedBadge")
    m.watchedBadgeBg = m.top.findNode("watchedBadgeBg")
    m.unwatchedBadge = m.top.findNode("unwatchedBadge")

    ' Cache constants
    m.constants = m.global.constants
end sub

sub onItemContentChange(event as Object)
    content = event.getData()
    if content = invalid then return

    ' Set thumbnail
    if content.thumb <> invalid and content.thumb <> ""
        m.thumbnail.uri = content.thumb
    else
        m.thumbnail.uri = ""
    end if

    ' Set formatted title: "E1 · Title"
    if content.title <> invalid
        m.titleLabel.text = content.title
    else
        m.titleLabel.text = ""
    end if

    ' Set duration
    if content.duration <> invalid and content.duration > 0
        m.durationLabel.text = FormatTime(content.duration)
    else
        m.durationLabel.text = ""
    end if

    ' Update watch state indicators (progress bar must be called first)
    updateProgressBar(content)
    updateBadge(content)
end sub

sub updateProgressBar(content as Object)
    viewOffset = 0
    duration = 0
    if content.viewOffset <> invalid then viewOffset = content.viewOffset
    if content.duration <> invalid then duration = content.duration

    if viewOffset > 0 and duration > 0
        progress = viewOffset / duration
        if progress < m.constants.PROGRESS_MIN_PERCENT
            m.progressTrack.visible = false
            m.progressFill.visible = false
            return
        end if
        if progress > 1.0 then progress = 1.0
        m.progressTrack.visible = true
        m.progressFill.visible = true
        m.progressFill.width = Int(320 * progress)
        m.progressFill.color = m.constants.ACCENT
    else
        m.progressTrack.visible = false
        m.progressFill.visible = false
    end if
end sub

sub updateBadge(content as Object)
    ' Coexistence rule: progress bar showing = hide all badges
    if m.progressTrack.visible = true
        m.unwatchedBadge.visible = false
        m.watchedBadge.visible = false
        m.watchedBadgeBg.visible = false
        return
    end if

    ' Check watched state via viewCount or watched flag
    watched = false
    if content.viewCount <> invalid and content.viewCount > 0
        watched = true
    end if
    if content.watched <> invalid and content.watched = true
        watched = true
    end if

    if watched
        ' Watched: show checkmark
        m.unwatchedBadge.visible = false
        m.watchedBadge.visible = true
        m.watchedBadgeBg.visible = true
    else
        ' Unwatched: show dot badge
        m.unwatchedBadge.visible = true
        m.watchedBadge.visible = false
        m.watchedBadgeBg.visible = false
    end if
end sub
