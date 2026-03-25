sub init()
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.unwatchedBadgeBg = m.top.findNode("unwatchedBadgeBg")
    m.unwatchedCount = m.top.findNode("unwatchedCount")
    m.watchedBadge = m.top.findNode("watchedBadge")
    m.watchedBadgeBg = m.top.findNode("watchedBadgeBg")

    ' Cache constants
    m.constants = m.global.constants
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
        m.unwatchedBadgeBg.visible = false
        m.unwatchedCount.visible = false
        m.watchedBadge.visible = false
        m.watchedBadgeBg.visible = false
        return
    end if

    ' Hub row items: no badges (episode data is unreliable for deduped items)
    if content.isHubItem <> invalid and content.isHubItem = true
        m.unwatchedBadgeBg.visible = false
        m.unwatchedCount.visible = false
        m.watchedBadge.visible = false
        m.watchedBadgeBg.visible = false
        return
    end if

    ' TV shows and seasons with real episode counts: use leafCount/viewedLeafCount
    if content.itemType <> invalid and (content.itemType = "show" or content.itemType = "season")
        hasLeafData = (content.leafCount <> invalid and content.leafCount > 0)
        if hasLeafData
            viewedLeaf = 0
            if content.viewedLeafCount <> invalid then viewedLeaf = content.viewedLeafCount
            unwatchedEpisodes = content.leafCount - viewedLeaf
            if unwatchedEpisodes <= 0
                ' Fully watched show — checkmark
                m.unwatchedBadgeBg.visible = false
                m.unwatchedCount.visible = false
                m.watchedBadge.visible = true
                m.watchedBadgeBg.visible = true
            else
                ' Partially watched show — unwatched episode count
                m.unwatchedBadgeBg.visible = true
                m.unwatchedCount.text = unwatchedEpisodes.ToStr()
                m.unwatchedCount.visible = true
                m.watchedBadge.visible = false
                m.watchedBadgeBg.visible = false
            end if
            return
        end if
        ' No leaf data — hide badges
        m.unwatchedBadgeBg.visible = false
        m.unwatchedCount.visible = false
        m.watchedBadge.visible = false
        m.watchedBadgeBg.visible = false
        return
    end if

    ' Movies, episodes, and shows without leaf data: use viewCount
    watched = false
    if content.viewCount <> invalid and content.viewCount > 0
        watched = true
    end if

    if watched
        m.unwatchedBadgeBg.visible = false
        m.unwatchedCount.visible = false
        m.watchedBadge.visible = true
        m.watchedBadgeBg.visible = true
    else
        ' Unwatched — show badge background (gold dot indicator)
        m.unwatchedBadgeBg.visible = true
        m.unwatchedCount.visible = false
        m.watchedBadge.visible = false
        m.watchedBadgeBg.visible = false
    end if
end sub
