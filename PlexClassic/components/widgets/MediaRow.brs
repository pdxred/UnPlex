sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.rowList = m.top.findNode("rowList")

    m.rowList.observeField("itemSelected", "onItemSelected")
end sub

sub onRowTitleChange(event as Object)
    m.titleLabel.text = event.getData()
end sub

sub onContentChange(event as Object)
    content = event.getData()
    ' Wrap content in a row for RowList
    rowContent = CreateObject("roSGNode", "ContentNode")
    row = rowContent.createChild("ContentNode")
    if content <> invalid
        for i = 0 to content.getChildCount() - 1
            row.appendChild(content.getChild(i).clone(true))
        end for
    end if
    m.rowList.content = rowContent
end sub

sub onItemSelected(event as Object)
    m.top.itemSelected = event.getData()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
