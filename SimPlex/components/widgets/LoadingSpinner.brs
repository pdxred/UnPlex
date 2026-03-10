sub init()
    m.spinner = m.top.findNode("spinner")
end sub

sub onVisibleChange(event as Object)
    visible = event.getData()
    if visible
        m.spinner.visible = true
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
        m.spinner.visible = false
    end if
end sub
