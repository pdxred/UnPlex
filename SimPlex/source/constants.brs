function GetConstants() as Object
    return {
        ' Colors (0xRRGGBBAA)
        BG_PRIMARY: "0x000000FF"
        BG_SIDEBAR: "0x121314FF"
        BG_CARD: "0x121314FF"
        TEXT_PRIMARY: "0xFFFFFFFF"
        TEXT_SECONDARY: "0xA0A0B0FF"
        ACCENT: "0xF3B125FF"
        SEPARATOR: "0x404040FF"
        FOCUS_RING: "0xF3B125FF"

        ' Layout (FHD 1920x1080)
        SIDEBAR_WIDTH: 340
        POSTER_WIDTH: 240
        POSTER_HEIGHT: 360
        GRID_COLUMNS: 6
        GRID_H_SPACING: 12
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
        PLEX_PRODUCT: "UnPlex"
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
