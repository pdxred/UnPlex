sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.unwatchedBadge = m.top.findNode("unwatchedBadge")
    m.unwatchedCount = m.top.findNode("unwatchedCount")

    ' Cache constants and set badge tint color
    m.constants = m.global.constants
    if m.constants <> invalid
        m.unwatchedBadge.blendColor = m.constants.ACCENT
    else
        m.unwatchedBadge.blendColor = "0xF3B125FF"
    end if
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
        m.progressFill.width = Int(m.constants.POSTER_WIDTH * progress)
        m.progressFill.color = m.constants.ACCENT
    else
        m.progressTrack.visible = false
        m.progressFill.visible = false
    end if
end sub

sub updateBadge(content as Object)
    ' Coexistence rule: progress bar showing = hide badge
    if m.progressTrack.visible = true
        m.unwatchedBadge.visible = false
        m.unwatchedCount.visible = false
        return
    end if

    ' Determine watched state
    watched = false
    if content.viewCount <> invalid and content.viewCount > 0
        watched = true
    end if

    ' Fully watched: clean poster
    if watched
        m.unwatchedBadge.visible = false
        m.unwatchedCount.visible = false
        return
    end if

    ' Unwatched: show badge
    m.unwatchedBadge.visible = true

    ' TV shows: show unwatched episode count
    if content.itemType <> invalid and content.itemType = "show" and content.leafCount <> invalid and content.viewedLeafCount <> invalid
        unwatchedEpisodes = content.leafCount - content.viewedLeafCount
        if unwatchedEpisodes <= 0
            ' Fully watched show
            m.unwatchedBadge.visible = false
            m.unwatchedCount.visible = false
            return
        end if
        m.unwatchedCount.text = unwatchedEpisodes.ToStr()
        m.unwatchedCount.visible = true
    else
        ' Movies and individual episodes: triangle only, no count
        m.unwatchedCount.visible = false
    end if
end sub
