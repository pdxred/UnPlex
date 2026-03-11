sub init()
    m.spinner = m.top.findNode("spinner")
end sub

sub onShowSpinnerChange(event as Object)
    show = event.getData()
    if show
        m.top.visible = true
        m.spinner.visible = true
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
        m.spinner.visible = false
        m.top.visible = false
    end if
end sub
