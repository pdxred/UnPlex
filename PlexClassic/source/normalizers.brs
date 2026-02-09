' normalizers.brs - Convert Plex JSON to ContentNode trees
' Per CONTEXT.md: raw JSON from task, normalizers convert to ContentNode

' Normalize movie list from Plex API response
' Input: Array of movie objects from MediaContainer.Metadata
' Output: ContentNode with child nodes for each movie
function NormalizeMovieList(jsonArray as Object) as Object
    content = CreateObject("roSGNode", "ContentNode")
    if jsonArray = invalid then return content

    for each item in jsonArray
        node = content.createChild("ContentNode")
        node.addFields({
            id: SafeGet(item, "ratingKey", "")
            title: SafeGet(item, "title", "Unknown")
            posterUrl: SafeGet(item, "thumb", "")
            itemType: "movie"
            watched: (SafeGet(item, "viewCount", 0) > 0)
            year: SafeGet(item, "year", 0)
            duration: SafeGet(item, "duration", 0)
            summary: SafeGet(item, "summary", "")
        })
    end for
    return content
end function

' Normalize TV show list
function NormalizeShowList(jsonArray as Object) as Object
    content = CreateObject("roSGNode", "ContentNode")
    if jsonArray = invalid then return content

    for each item in jsonArray
        node = content.createChild("ContentNode")
        node.addFields({
            id: SafeGet(item, "ratingKey", "")
            title: SafeGet(item, "title", "Unknown")
            posterUrl: SafeGet(item, "thumb", "")
            itemType: "show"
            watched: false  ' Shows track watched at episode level
            year: SafeGet(item, "year", 0)
            leafCount: SafeGet(item, "leafCount", 0)  ' Episode count
            viewedLeafCount: SafeGet(item, "viewedLeafCount", 0)
        })
    end for
    return content
end function

' Normalize season list for a show
function NormalizeSeasonList(jsonArray as Object, showId as String) as Object
    content = CreateObject("roSGNode", "ContentNode")
    if jsonArray = invalid then return content

    for each item in jsonArray
        node = content.createChild("ContentNode")
        node.addFields({
            id: SafeGet(item, "ratingKey", "")
            title: SafeGet(item, "title", "Unknown Season")
            posterUrl: SafeGet(item, "thumb", "")
            itemType: "season"
            showId: showId  ' Reference to parent show
            seasonNumber: SafeGet(item, "index", 0)
            leafCount: SafeGet(item, "leafCount", 0)
            viewedLeafCount: SafeGet(item, "viewedLeafCount", 0)
        })
    end for
    return content
end function

' Normalize episode list for a season
function NormalizeEpisodeList(jsonArray as Object, showId as String, seasonId as String) as Object
    content = CreateObject("roSGNode", "ContentNode")
    if jsonArray = invalid then return content

    for each item in jsonArray
        node = content.createChild("ContentNode")
        node.addFields({
            id: SafeGet(item, "ratingKey", "")
            title: SafeGet(item, "title", "Unknown Episode")
            posterUrl: SafeGet(item, "thumb", "")
            itemType: "episode"
            showId: showId
            seasonId: seasonId
            episodeNumber: SafeGet(item, "index", 0)
            seasonNumber: SafeGet(item, "parentIndex", 0)
            duration: SafeGet(item, "duration", 0)
            summary: SafeGet(item, "summary", "")
            watched: (SafeGet(item, "viewCount", 0) > 0)
            viewOffset: SafeGet(item, "viewOffset", 0)  ' Resume position
        })
    end for
    return content
end function

' Normalize On Deck / Continue Watching items (mixed types)
function NormalizeOnDeck(jsonArray as Object) as Object
    content = CreateObject("roSGNode", "ContentNode")
    if jsonArray = invalid then return content

    for each item in jsonArray
        node = content.createChild("ContentNode")
        plexType = SafeGet(item, "type", "")

        if plexType = "movie"
            itemType = "movie"
        else if plexType = "episode"
            itemType = "episode"
        else
            itemType = "unknown"
        end if

        node.addFields({
            id: SafeGet(item, "ratingKey", "")
            title: SafeGet(item, "title", "Unknown")
            posterUrl: SafeGet(item, "thumb", "")
            itemType: itemType
            viewOffset: SafeGet(item, "viewOffset", 0)
            duration: SafeGet(item, "duration", 0)
            watched: false  ' On Deck items are by definition not fully watched
        })

        ' Add episode-specific fields if episode
        if itemType = "episode"
            node.addFields({
                showTitle: SafeGet(item, "grandparentTitle", "")
                seasonNumber: SafeGet(item, "parentIndex", 0)
                episodeNumber: SafeGet(item, "index", 0)
            })
        end if
    end for
    return content
end function
