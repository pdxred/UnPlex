sub init()
    m.top.functionName = "run"
end sub

sub run()
    m.top.status = "loading"

    urls = m.top.imageUrls
    if urls = invalid or urls.count() = 0
        m.top.status = "completed"
        return
    end if

    completed = 0
    for each imageUrl in urls
        ' Prefetch image by making a HEAD request
        ' This triggers the server to generate the thumbnail
        url = CreateObject("roUrlTransfer")
        url.SetCertificatesFile("common:/certs/ca-bundle.crt")
        url.InitClientCertificates()
        url.SetUrl(imageUrl)

        ' Add Plex headers
        headers = GetPlexHeaders()
        for each key in headers
            url.AddHeader(key, headers[key])
        end for

        ' Just do a GET - the response will be cached by Roku's image system
        ' We don't need to store the result
        response = url.GetToString()

        completed = completed + 1
        m.top.completed = completed
    end for

    m.top.status = "completed"
end sub
