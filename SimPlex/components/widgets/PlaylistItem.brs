sub init()
    m.indexLabel = m.top.findNode("indexLabel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.subtitleLabel = m.top.findNode("subtitleLabel")
    m.durationLabel = m.top.findNode("durationLabel")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
end sub

sub onContentChange(event as Object)
    content = event.getData()
    if content = invalid then return

    ' Index number
    itemIndex = content.getField("itemIndex")
    if itemIndex <> invalid
        m.indexLabel.text = itemIndex.ToStr()
    end if

    ' Title
    m.titleLabel.text = content.title

    ' Subtitle: show type indicator and parent info for episodes
    subtitle = ""
    itemType = content.getField("itemType")
    grandparentTitle = content.getField("grandparentTitle")
    if grandparentTitle <> invalid and grandparentTitle <> ""
        subtitle = grandparentTitle
        parentTitle = content.getField("parentTitle")
        if parentTitle <> invalid and parentTitle <> ""
            subtitle = subtitle + " - " + parentTitle
        end if
    else if itemType <> invalid
        if itemType = "movie"
            subtitle = "Movie"
        else if itemType = "episode"
            subtitle = "Episode"
        end if
    end if
    m.subtitleLabel.text = subtitle

    ' Duration
    duration = content.getField("duration")
    if duration <> invalid and duration > 0
        m.durationLabel.text = FormatTime(duration)
    else
        m.durationLabel.text = ""
    end if

    ' Progress bar
    viewOffset = content.getField("viewOffset")
    if viewOffset <> invalid and viewOffset > 0 and duration <> invalid and duration > 0
        progress = viewOffset / duration
        c = GetConstants()
        if progress >= c.PROGRESS_MIN_PERCENT
            m.progressTrack.visible = true
            m.progressFill.visible = true
            m.progressFill.width = Int(1200 * progress)
        else
            m.progressTrack.visible = false
            m.progressFill.visible = false
        end if
    else
        m.progressTrack.visible = false
        m.progressFill.visible = false
    end if
end sub
