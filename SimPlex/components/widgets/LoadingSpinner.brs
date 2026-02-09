sub init()
    m.spinner = m.top.findNode("spinner")
    m.loadingLabel = m.top.findNode("loadingLabel")
end sub

sub onVisibleChange(event as Object)
    visible = event.getData()
    m.spinner.visible = visible
    m.loadingLabel.visible = visible
    if visible
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
    end if
end sub
