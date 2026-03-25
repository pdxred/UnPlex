sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    scene = screen.CreateScene("MainScene")
    screen.Show()

    ' Pass launch args to scene if deep-linking
    if args <> invalid
        scene.launchArgs = args
    end if

    ' Observe close field to exit app
    scene.observeField("close", m.port)

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if msgType = "roSGNodeEvent"
            if msg.getField() = "close" and msg.getData() = true
                screen.close()
                return
            end if
        end if
    end while
end sub
