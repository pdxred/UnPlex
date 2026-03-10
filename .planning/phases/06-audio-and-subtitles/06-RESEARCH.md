# Phase 6: Audio and Subtitles - Research

**Researched:** 2026-03-10
**Domain:** Roku SceneGraph playback stream selection, Plex Media Server subtitle/audio API
**Confidence:** HIGH

## Summary

Phase 6 adds audio and subtitle track selection during playback. The Roku Video node exposes stream selection natively via `availableAudioTracks`, `availableSubtitleTracks`, and their corresponding `set` methods. Text subtitles (SRT/ASS) can be delivered as sidecar URLs on the ContentNode without transcoding. PGS/bitmap subtitles cannot be rendered client-side on Roku — they must be burned in via PMS transcode, which requires stopping direct play and starting an HLS transcode session with `subtitleStreamID` and `burn` parameters.

The main complexity is the PGS transition: preserving playback position when switching from direct play to transcode, showing a loading state during the transcode pivot, and reverting gracefully on failure. The existing `VideoPlayer.brs` already has `buildTranscodeUrl()` and position tracking infrastructure that can be extended.

**Primary recommendation:** Build a `TrackSelectionPanel` SceneGraph component (LabelList-based) that reads stream metadata from the Plex API response, handles selection, and signals the VideoPlayer to switch audio tracks natively or restart playback with transcode parameters for PGS subtitles.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Side panel that slides in from the right edge; playback video remains visible behind it
- Playback pauses while the panel is open
- Two trigger methods: Options (*) button opens panel directly, AND an icon in the playback HUD
- Combined panel with Audio section on top, Subtitles section below (single panel, not tabs)
- Audio tracks show: language + codec/channels (e.g. "English (AAC 5.1)")
- Subtitle tracks show: language + type (e.g. "English (SRT)" or "English (PGS)")
- Active/selected track gets a checkmark icon AND accent color highlight (Plex gold)
- Subtitles always include an "Off" option in the list
- Track changes apply immediately on select — no confirm button
- Track choices persist across episodes via Plex server API (PUT to set preferred tracks)
- Forced subtitles auto-enable when audio language doesn't match user's language
- When selecting a PGS subtitle, show a brief spinner with "Switching subtitles..." while transcode session starts
- Type label "(PGS)" vs "(SRT)" in the track list is sufficient distinction — no warning icons
- On transcode failure: show error toast "Subtitle unavailable" and revert to previous track
- Playback position must be preserved when switching from direct play to transcode — record offset, start transcode at same position

### Claude's Discretion
- Panel animation speed and easing
- Exact panel width and typography
- HUD icon design and placement
- How to handle tracks with no language metadata
- Spinner/loading indicator style

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAY-06 | User can select audio track during playback | Roku `availableAudioTracks` + `setAudioTrack()` API; Plex stream metadata from `/library/metadata/{id}` |
| PLAY-07 | User can select subtitle track during playback | Roku `availableSubtitleTracks` + `setSubtitleTrack()`; Plex subtitle stream listing |
| PLAY-08 | SRT/text subtitles render via sidecar delivery | ContentNode `subtitleTracks` field with sidecar URL; no transcode needed |
| PLAY-09 | PGS/bitmap subtitles trigger transcode with burn-in | PMS transcode endpoint with `subtitleStreamID` + `subtitles=burn` params |
</phase_requirements>

## Standard Stack

### Core
| Component | Purpose | Why Standard |
|-----------|---------|--------------|
| Roku Video node | Playback with native audio/subtitle track APIs | Built-in; `availableAudioTracks`, `availableSubtitleTracks`, `setAudioTrack()`, `setSubtitleTrack()` |
| LabelList | Track list rendering | Built-in SceneGraph list; simple, focus-managed, ideal for text-based track lists |
| LayoutGroup / Group | Panel layout | Position Audio section above Subtitles section within the slide-in panel |
| Animation + FloatFieldInterpolator | Panel slide animation | Standard SceneGraph animation nodes for translateX sliding |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| Rectangle | Panel background, dividers, accent highlights | Visual structure of the panel |
| Label | Section headers ("Audio", "Subtitles"), track labels | All text in the panel |
| Poster | Checkmark icon for selected track | Active track indicator |
| Timer | Debounce for transcode switch | Prevent rapid PGS selections causing multiple transcode starts |
| BusySpinner (existing) | "Switching subtitles..." feedback | During PGS transcode pivot |

## Architecture Patterns

### Stream Metadata from Plex API

The Plex `/library/metadata/{ratingKey}` response includes full stream information under `Media[].Part[].Stream[]`. Each stream has:

```json
{
  "id": 12345,
  "streamType": 2,       // 1=video, 2=audio, 3=subtitle
  "codec": "srt",        // or "pgs", "aac", "ac3", "eac3", etc.
  "language": "English",
  "languageTag": "en",
  "displayTitle": "English (SRT)",
  "channels": 6,         // audio only
  "selected": true,      // currently active track
  "forced": false
}
```

**Pattern:** Fetch metadata once when playback starts (already done in `processMediaInfo()`), cache stream arrays, populate the track panel from cached data.

### Audio Track Selection (Native)

Roku's Video node provides:
- `availableAudioTracks` (read-only array) — populated after playback starts
- `currentAudioTrack` — currently playing audio track index
- Audio track switch via setting a new `audioTrack` on the ContentNode before or during playback

For Plex, audio track selection during direct play works by:
1. Reading stream IDs from the metadata
2. Setting `audioStreamID` parameter on the direct play URL
3. For already-playing content, Roku's native `audioTrack` field on the Video node can switch tracks without restart if the container supports it (MKV, MP4)

**Important:** Roku's native audio track switching works for direct play containers. For HLS transcode, audio selection must be done via the transcode URL parameter `audioStreamID`.

### Subtitle Track Selection

**Text subtitles (SRT, ASS, VTT):**
- Delivered as sidecar files via Plex endpoint: `{server}/library/streams/{streamID}?X-Plex-Token={token}`
- Set on ContentNode's `SubtitleTracks` field as an array of associative arrays with `url`, `language`, `description`
- Roku renders these natively without transcoding
- Can be switched on-the-fly using `setSubtitleTrack()` or `enableSubtitle()`/`disableSubtitle()`

**Bitmap subtitles (PGS, VOBSUB):**
- Cannot be rendered client-side on Roku — no API for bitmap subtitle overlay
- Must be burned into the video stream via PMS transcode
- Transcode URL requires: `subtitleStreamID={id}&subtitles=burn`
- This forces a playback restart: stop current video, start HLS transcode with burn-in

### PGS Transcode Pivot Pattern

```
Current State: Direct play at position P
User selects PGS track with streamID S

1. Record current position: P = m.currentPosition
2. Pause/stop current video
3. Show "Switching subtitles..." spinner
4. Build transcode URL with:
   - path={mediaKey}
   - subtitleStreamID={S}
   - subtitles=burn
   - offset={P / 1000}  (PMS expects seconds)
5. Set new ContentNode with HLS URL
6. Start playback
7. On "playing" state → hide spinner
8. On error → show "Subtitle unavailable" toast, revert to previous state
```

**Reverting on failure:**
- Store previous ContentNode URL and position before switching
- On transcode error, rebuild previous URL (direct play or previous transcode)
- Seek to stored position

### Track Persistence via Plex API

To persist track choices across episodes:
```
PUT /library/parts/{partID}?audioStreamID={id}&subtitleStreamID={id}&X-Plex-Token={token}
```

This tells PMS to prefer these tracks for future playback of items in the same show/library. The `partID` comes from `Media[0].Part[0].id` in the metadata response.

### Forced Subtitle Auto-Enable

Plex API marks forced tracks with `"forced": true` in the stream metadata. When audio language differs from the user's language (from Plex account settings or device locale), forced subtitles in the user's language should auto-enable.

Detection logic:
1. Get selected audio track's `languageTag`
2. Get device locale via `CreateObject("roDeviceInfo").GetCurrentLocale()` (returns e.g., "en_US")
3. If audio language !== device language prefix, find forced subtitle track matching device language
4. Auto-select that track

### Panel Component Structure

```
TrackSelectionPanel (Group)
├── PanelBackground (Rectangle, semi-transparent dark)
├── ContentGroup (LayoutGroup, vertical)
│   ├── AudioSection (Group)
│   │   ├── AudioHeader (Label, "Audio")
│   │   └── AudioList (LabelList or MarkupList)
│   ├── Divider (Rectangle)
│   └── SubtitleSection (Group)
│       ├── SubHeader (Label, "Subtitles")
│       └── SubtitleList (LabelList or MarkupList)
└── SlideAnimation (Animation + FloatFieldInterpolator)
```

**Focus flow:** Up/Down navigates within each list. When reaching the bottom of AudioList, focus moves to SubtitleList header. When reaching the top of SubtitleList, focus moves back to AudioList. Back button or Options button closes panel.

### Anti-Patterns to Avoid
- **Don't create custom scrolling for track lists** — use LabelList/MarkupList which handle focus and scrolling natively
- **Don't restart playback for text subtitle changes** — use sidecar delivery and native Roku subtitle APIs
- **Don't build a custom subtitle renderer** — Roku handles SRT/VTT natively via ContentNode subtitleTracks
- **Don't ignore the Video node's native audio track support** — avoid unnecessary transcode restarts for audio-only changes

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subtitle rendering | Custom text overlay | Roku native subtitle support via ContentNode | Handles timing, styling, encoding edge cases |
| List scrolling | Custom scroll math | LabelList/MarkupList | Focus management, long-press scroll, screen reader support |
| Slide animation | Manual timer-based position updates | Animation + FloatFieldInterpolator | Hardware-accelerated, cancelable, proper easing |
| Track label formatting | Complex string parsing | Plex API `displayTitle` field | Already formatted as "English (AAC 5.1)" by PMS |

## Common Pitfalls

### Pitfall 1: Setting subtitleTracks after playback starts
**What goes wrong:** Setting `SubtitleTracks` on ContentNode after `video.control = "play"` may not take effect
**Why it happens:** Some Roku firmware versions cache subtitle track info at play start
**How to avoid:** Set subtitle sidecar URLs on ContentNode BEFORE starting playback. For mid-playback changes, use `setSubtitleTrack()` on the Video node or rebuild ContentNode and restart.
**Warning signs:** Subtitles don't appear despite correct URL

### Pitfall 2: PGS selection without position preservation
**What goes wrong:** User loses their place in the video when switching to PGS subtitles
**Why it happens:** Transcode restart defaults to beginning if offset not specified
**How to avoid:** Always capture `m.currentPosition` before stopping video, pass as `offset` parameter to transcode URL
**Warning signs:** Video jumps to start after subtitle change

### Pitfall 3: Rapid track switching causing race conditions
**What goes wrong:** Multiple transcode sessions started if user quickly switches between PGS tracks
**Why it happens:** Each PGS selection triggers a full playback restart; previous restart may not have completed
**How to avoid:** Disable track selection UI during transcode pivot (show spinner, disable list interaction). Use a state flag `m.isTranscodePivotInProgress`.
**Warning signs:** Multiple buffering events, wrong subtitle appearing

### Pitfall 4: Stale availableAudioTracks/availableSubtitleTracks
**What goes wrong:** Roku's Video node track arrays are empty or incomplete
**Why it happens:** These fields populate asynchronously after playback begins; reading too early returns empty
**How to avoid:** Don't rely solely on Roku's native track enumeration. Use Plex API metadata (which is fetched before playback) as the source of truth for the track panel. Roku's native fields are only needed for `setAudioTrack()`/`setSubtitleTrack()` calls.
**Warning signs:** Panel shows no tracks despite media having them

### Pitfall 5: Missing language metadata
**What goes wrong:** Track displays as blank or "Unknown"
**Why it happens:** Some media files have streams with no language tag
**How to avoid:** Fallback label: "Track {N}" with codec info. Use `displayTitle` from Plex API which already handles this gracefully. If `displayTitle` is empty, construct from `language` (or "Unknown") + codec + channels.
**Warning signs:** Empty labels in track list

### Pitfall 6: Subtitle sidecar URL format
**What goes wrong:** SRT subtitles fail to load as sidecar
**Why it happens:** Wrong URL format or missing token for sidecar delivery
**How to avoid:** Sidecar URL format: `{server}/library/streams/{streamID}?X-Plex-Token={token}`. Ensure HTTPS certs are handled (Roku ContentNode handles this for subtitle URLs automatically).
**Warning signs:** No subtitles despite selecting SRT track

## Code Examples

### Reading Stream Metadata from Plex Response

```brightscript
' After fetching /library/metadata/{ratingKey}
' item = response.MediaContainer.Metadata[0]
' media = item.Media[0]
' part = media.Part[0]
' streams = part.Stream  ' Array of all streams

sub parseStreams(streams as Object)
    m.audioStreams = []
    m.subtitleStreams = []

    for each stream in streams
        streamType = SafeGet(stream, "streamType", 0)
        if streamType = 2  ' Audio
            m.audioStreams.push({
                id: SafeGet(stream, "id", 0)
                displayTitle: SafeGet(stream, "displayTitle", "Unknown Audio")
                language: SafeGet(stream, "language", "Unknown")
                codec: SafeGet(stream, "codec", "")
                channels: SafeGet(stream, "channels", 2)
                selected: SafeGet(stream, "selected", false)
            })
        else if streamType = 3  ' Subtitle
            m.subtitleStreams.push({
                id: SafeGet(stream, "id", 0)
                displayTitle: SafeGet(stream, "displayTitle", "Unknown Subtitle")
                language: SafeGet(stream, "language", "Unknown")
                codec: SafeGet(stream, "codec", "")
                forced: SafeGet(stream, "forced", false)
                selected: SafeGet(stream, "selected", false)
                isBitmap: (LCase(SafeGet(stream, "codec", "")) = "pgs" or LCase(SafeGet(stream, "codec", "")) = "vobsub")
            })
        end if
    end for
end sub
```

### Building Transcode URL with Subtitle Burn-In

```brightscript
function buildTranscodeUrlWithSubtitles(subtitleStreamID as Integer, offsetMs as Integer) as String
    serverUri = GetServerUri()
    token = GetAuthToken()

    url = serverUri + "/video/:/transcode/universal/start.m3u8"
    url = url + "?path=" + UrlEncode(m.top.mediaKey)
    url = url + "&mediaIndex=0"
    url = url + "&partIndex=0"
    url = url + "&protocol=hls"
    url = url + "&directPlay=0"
    url = url + "&directStream=1"
    url = url + "&videoQuality=100"
    url = url + "&maxVideoBitrate=20000"
    url = url + "&videoResolution=1920x1080"
    url = url + "&subtitleStreamID=" + subtitleStreamID.ToStr()
    url = url + "&subtitles=burn"
    url = url + "&offset=" + (offsetMs / 1000).ToStr()
    url = url + "&X-Plex-Token=" + token

    return url
end function
```

### Setting SRT Sidecar Subtitles on ContentNode

```brightscript
sub setSidecarSubtitle(streamID as Integer)
    serverUri = GetServerUri()
    token = GetAuthToken()

    sidecarUrl = serverUri + "/library/streams/" + streamID.ToStr()
    sidecarUrl = sidecarUrl + "?X-Plex-Token=" + token

    subtitleConfig = {
        trackName: "subtitle_sidecar"
        language: "en"
        url: sidecarUrl
    }

    content = m.video.content
    content.subtitleTracks = [subtitleConfig]
    m.video.enableSubtitle("subtitle_sidecar")
end sub
```

### Persisting Track Selection via Plex API

```brightscript
sub persistTrackSelection(partID as Integer, audioStreamID as Integer, subtitleStreamID as Integer)
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/library/parts/" + partID.ToStr()
    task.method = "PUT"
    task.params = {}

    if audioStreamID > 0
        task.params["audioStreamID"] = audioStreamID.ToStr()
    end if
    if subtitleStreamID > 0
        task.params["subtitleStreamID"] = subtitleStreamID.ToStr()
    else
        task.params["subtitleStreamID"] = "0"  ' 0 = off
    end if

    task.control = "run"
    ' Fire and forget - no need to wait for response
end sub
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| subtitles=auto in transcode URL | Explicit subtitleStreamID + subtitles=burn | PMS 1.25+ | Precise control over which subtitle track is burned in |
| No sidecar subtitle support on Roku | ContentNode subtitleTracks with external URLs | Roku OS 10+ | SRT/VTT can be loaded without transcoding |
| Manual HTTP subtitle fetch + overlay | Native Video node subtitle rendering | Roku OS 9+ | Eliminates custom subtitle parser/renderer |

## Open Questions

1. **PUT method for /library/parts endpoint**
   - What we know: Plex uses PUT to set preferred streams. PlexApiTask currently supports GET and POST.
   - What's unclear: Need to add PUT support to PlexApiTask (use X-HTTP-Method-Override like PlexSessionTask does)
   - Recommendation: Add PUT support via method override header in PlexApiTask, following the same pattern as PlexSessionTask

2. **Subtitle sidecar URL format validation**
   - What we know: `/library/streams/{id}` is the documented endpoint
   - What's unclear: Whether all PMS versions support this endpoint for all text subtitle formats
   - Recommendation: Test with real server; fall back to transcode if sidecar delivery fails

3. **Forced subtitle detection timing**
   - What we know: Forced flag is in stream metadata; device locale available via roDeviceInfo
   - What's unclear: Whether Plex account language settings should override device locale
   - Recommendation: Use device locale as primary; Plex account language as fallback if available from /library/metadata response

## Sources

### Primary (HIGH confidence)
- Roku Developer Documentation — Video node, ContentNode subtitle fields, audio track APIs
- Plex Media Server API — Stream metadata structure, transcode parameters, `/library/parts` endpoint
- Existing codebase — `VideoPlayer.brs`, `PlexApiTask.brs`, `PlexSessionTask.brs`, `utils.brs` patterns

### Secondary (MEDIUM confidence)
- Plex forum discussions on subtitle burn-in parameters and sidecar delivery
- Roku developer forums on `availableAudioTracks` timing behavior

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Roku built-in components, well-documented APIs
- Architecture: HIGH — extends existing VideoPlayer and PlexApiTask patterns
- Pitfalls: HIGH — based on known Roku Video node behavior and Plex transcode mechanics

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (stable platform, no expected breaking changes)
