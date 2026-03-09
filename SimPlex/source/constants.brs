function GetConstants() as Object
    return {
        ' Colors (0xRRGGBBAA)
        BG_PRIMARY: "0x1A1A2EFF"
        BG_SIDEBAR: "0x0F0F1AFF"
        BG_CARD: "0x232342FF"
        TEXT_PRIMARY: "0xFFFFFFFF"
        TEXT_SECONDARY: "0xA0A0B0FF"
        ACCENT: "0xE5A00DFF"
        SEPARATOR: "0x2A2A4AFF"
        FOCUS_RING: "0xE5A00DFF"

        ' Layout (FHD 1920x1080)
        SIDEBAR_WIDTH: 280
        POSTER_WIDTH: 240
        POSTER_HEIGHT: 360
        GRID_COLUMNS: 6
        GRID_H_SPACING: 20
        GRID_V_SPACING: 40
        FILTER_BAR_HEIGHT: 60

        ' Watch State UI
        PROGRESS_BAR_HEIGHT_POSTER: 6
        PROGRESS_BAR_HEIGHT_EPISODE: 4
        PROGRESS_BAR_HEIGHT_DETAIL: 8
        PROGRESS_MIN_PERCENT: 0.05
        BADGE_SIZE: 40
        BADGE_SIZE_EPISODE: 28

        ' Plex API
        PLEX_TV_URL: "https://plex.tv"
        PLEX_PRODUCT: "SimPlex"
        PLEX_VERSION: "1.0.0"
        PLEX_PLATFORM: "Roku"

        ' Pagination
        PAGE_SIZE: 50

        ' Playback
        PROGRESS_REPORT_INTERVAL: 10  ' seconds
        SKIP_FORWARD_SEC: 10
        SKIP_BACK_SEC: 10
    }
end function
