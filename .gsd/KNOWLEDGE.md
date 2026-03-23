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

## Gotchas

- **Accent color inconsistency:** constants.brs defines ACCENT as `0xF3B125FF` but 5 files still hardcode old `0xE5A00D` values inline (EpisodeScreen.xml, SettingsScreen.brs, LibrarySettingItem.xml ×3). When changing accent color, grep for both values.
- **HomeScreen direct playback path is not wired for auto-play.** `startPlaybackFromGrid()` uses old `playbackComplete` observer and doesn't set grandparentRatingKey/parentRatingKey. Episodes played from hub rows won't auto-advance or show PostPlayScreen.
- **ServerListScreen still exists** even though server switching is slated for removal in S15. Don't delete it until all 4 codepaths in SettingsScreen.brs are patched.
- **HAR file in project root** (`plex.owlfarm.ad.har`, 17 MB) contains live auth tokens. Added to .gitignore 2026-03-22 but the file itself still exists on disk — never commit it.
