sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.loadingSpinner = m.top.findNode("loadingSpinner")
    m.emptyState = m.top.findNode("emptyState")

    ' Set title when available
    m.top.observeField("playlistTitle", "onTitleChanged")
    m.top.observeField("ratingKey", "onRatingKeyChanged")
end sub

sub onTitleChanged(event as Object)
    m.titleLabel.text = m.top.playlistTitle
end sub

sub onRatingKeyChanged(event as Object)
    if m.top.ratingKey <> ""
        loadPlaylistItems()
    end if
end sub

sub loadPlaylistItems()
    ' Stub: Full implementation in Plan 09-02
    m.loadingSpinner.visible = false
    m.emptyState.visible = true
end sub

sub cleanup()
    m.top.unobserveField("playlistTitle")
    m.top.unobserveField("ratingKey")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.navigateBack = true
        return true
    end if

    return false
end function
