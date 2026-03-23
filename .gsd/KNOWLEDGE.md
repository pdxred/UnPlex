# Knowledge

## Rules

- **Never use BusySpinner** — native Roku SceneGraph component causes firmware SIGSEGV ~3s after init on FHD-targeted channels. Use Label + Rectangle + Timer pattern instead (LoadingSpinner widget).
- **All HTTP requests in Task nodes only** — roUrlTransfer on render thread causes rendezvous crashes.
- **Always call `.Flush()` after roRegistrySection writes** — data is lost without it.
- **GetRatingKeyStr() for all ratingKey handling** — Plex API returns ratingKey as integer or string inconsistently. Single helper in utils.brs, never inline the type check.
- **HTTPS certificates required on every roUrlTransfer** — `SetCertificatesFile("common:/certs/ca-bundle.crt")` + `InitClientCertificates()`.
- **Include all X-Plex-* headers on every API call** — use `GetPlexHeaders()`.
- **XML attributes can't use BrightScript constants** — hardcoded values in XML are overridden at runtime by init() code. This is normal; don't try to "fix" XML defaults to match constants.

## Patterns

- **LoadingSpinner pattern:** `showSpinner` field with 300ms Timer delay. Guard: `if m.loadingSpinner <> invalid then m.loadingSpinner.showSpinner = true/false`.
- **playbackResult vs playbackComplete:** DetailScreen and EpisodeScreen observe `playbackResult` (structured AA). HomeScreen and PlaylistScreen still use old `playbackComplete` boolean. Both fields exist on VideoPlayer.xml for backward compatibility.
- **signalPlaybackComplete(reason):** Single exit point in VideoPlayer.brs. Emits structured AA with reason/ratingKey/hasNextEpisode/nextEpisodeInfo/viewOffset/duration/isPlaylist.
- **watchStateUpdate emission:** Emitted from scrobble() and signalPlaybackComplete(), NOT from reportProgress() (avoids excessive re-renders). Observers in HomeScreen walk both hubRowList and posterGrid ContentNode trees.
- **Screen navigation:** All screens use `itemSelected` field with action AA. PostPlayScreen uses `action='postPlay'`. MainScene dispatches based on action string.
- **Auto-play threshold:** Last 30 seconds (`m.duration - 30000`), NOT 90% of duration. Three places in VideoPlayer.brs must stay in sync.
- **PosterGrid dynamic resize:** Set `gridWidth` on PosterGrid and columns recalculate automatically via observer (`Int(gridWidth / (POSTER_WIDTH + GRID_H_SPACING))`). Default library width 1620px → 6 cols. Any parent can resize at runtime.
- **Sidebar.libraries interface field:** Read-only assocarray `{ items: [{key, title, type}, ...] }` populated after library API response. Use for cross-component library metadata access without reaching into Sidebar internals.
- **Search layout two-state toggle:** `m.keyboard.visible` tracks state. When adding new elements to SearchScreen, provide positioning for both keyboard-visible (grid at x=700, gridWidth=1140) and keyboard-hidden (grid at x=80, gridWidth=1760) states.
- **Options menu button index shifting:** When inserting type-specific buttons (e.g. "Show Info" for shows), Cancel shifts to a higher index. Cancel needs no explicit handler — dialog close fires before index checks and `restoreFocusAfterDialog()` / `setFocus(true)` runs unconditionally at function end. Pattern used in both HomeScreen and EpisodeScreen options menus.
- **itemType-based routing:** Grid/hub selection handlers check `itemType` before the catch-all `action: "detail"` block. Shows emit `action: "episodes"`; everything else falls through to detail. Safe degradation — missing or unrecognized itemType gets default detail routing, never crashes.

## Gotchas

- **Accent color inconsistency:** constants.brs defines ACCENT as `0xF3B125FF` but 5 files still hardcode old `0xE5A00D` values inline (EpisodeScreen.xml, SettingsScreen.brs, LibrarySettingItem.xml ×3). When changing accent color, grep for both values.
- **HomeScreen direct playback path is not wired for auto-play.** `startPlaybackFromGrid()` uses old `playbackComplete` observer and doesn't set grandparentRatingKey/parentRatingKey. Episodes played from hub rows won't auto-advance or show PostPlayScreen.
- **ServerListScreen deleted in S15.** All server switching UI and codepaths removed. `discoverServers()` in SettingsScreen is preserved — it serves auth recovery and PIN completion, NOT server switching. Don't remove it.
- **SettingsScreen menu indices after S15:** 0=user label, 1=Hub Libraries, 2=Sidebar Libraries, 3=Switch User, 4=Sign Out. Any new menu item should insert before Sign Out and bump its index.
- **HAR file in project root** (`plex.owlfarm.ad.har`, 17 MB) contains live auth tokens. Added to .gitignore 2026-03-22 but the file itself still exists on disk — never commit it.
- **Google Fonts GitHub raw URLs return HTML, not font files** — Git LFS stores font binaries as pointers, so `github.com/google/fonts/raw/...` returns an HTML page. Use the gstatic CDN URL (e.g. `fonts.gstatic.com/s/inter/v18/...`) to download the actual TTF binary.
- **SceneGraph Font child nodes conflict with font= attribute** — When using `<Font role="font" uri="..." />` inside a Label, the `font="font:LargeBoldSystemFont"` attribute MUST be removed entirely. Both present = undefined behavior (firmware may ignore the child node).
