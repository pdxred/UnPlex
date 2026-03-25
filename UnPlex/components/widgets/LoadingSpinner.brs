' Copyright 2026 UnPlex contributors. MIT License.
sub init()
    m.spinner = m.top.findNode("spinner")
    m.overlay = m.top.findNode("overlay")
    m.delayTimer = m.top.findNode("delayTimer")
    m.delayTimer.observeField("fire", "onDelayTimerFire")
end sub

sub onShowSpinnerChange(event as Object)
    show = event.getData()
    if show
        ' Start the 300ms delay timer — only show overlay+label if still loading after 300ms
        m.delayTimer.control = "start"
    else
        ' Hide immediately when done loading
        m.delayTimer.control = "stop"
        m.spinner.visible = false
        m.overlay.visible = false
        m.top.visible = false
    end if
end sub

sub onDelayTimerFire(event as Object)
    ' Timer fired — still loading after 300ms, show the spinner
    if m.top.showSpinner
        m.top.visible = true
        m.overlay.visible = true
        m.spinner.visible = true
    end if
end sub
