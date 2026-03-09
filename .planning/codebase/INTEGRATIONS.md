# External Integrations

**Analysis Date:** 2026-03-08

## APIs & External Services

**plex.tv Authentication API (v2):**
- Purpose: PIN-based OAuth authentication and server discovery
- Task: `SimPlex/components/tasks/PlexAuthTask.brs`
- Base URL: `https://plex.tv`
- Auth: PIN code flow (no API key required to initiate; auth token returned after user links at plex.tv/link)
- Endpoints used:
  - `POST /api/v2/pins` (body: `strong=false`) - Request a PIN code for user to enter at plex.tv/link
  - `GET /api/v2/pins/{id}` - Poll for auth token after user enters PIN
  - `GET /api/v2/resources?includeHttps=1&includeRelay=1` - Discover user's Plex Media Servers (with token header)

**Plex Media Server REST API:**
- Purpose: Library browsing, metadata, search, playback, progress tracking
- Task: `SimPlex/components/tasks/PlexApiTask.brs` (general), `SimPlex/components/tasks/PlexSearchTask.brs` (search), `SimPlex/components/tasks/PlexSessionTask.brs` (progress)
- Base URL: Dynamic, stored in registry as `serverUri` (e.g., `https://192.168.1.x:32400`)
- Auth: `X-Plex-Token` query parameter on every request
- Response format: JSON (`Accept: application/json` header)
- Endpoints used:
  - `GET /library/sections` - List libraries
  - `GET /library/sections/{id}/all` - Browse library contents (paginated: `X-Plex-Container-Start`, `X-Plex-Container-Size=50`)
  - `GET /library/metadata/{ratingKey}` - Item detail metadata
  - `GET /library/metadata/{ratingKey}/children` - Seasons/episodes for a show
  - `GET /library/onDeck` - Continue watching items
  - `GET /hubs/search?query={term}&limit=20` - Search across library
  - `GET /photo/:/transcode?width={w}&height={h}&url={path}` - Resized poster images
  - `PUT /:/timeline?ratingKey={id}&state={state}&time={ms}&duration={ms}` - Playback progress reporting (via POST with `X-HTTP-Method-Override: PUT`)
  - `GET /:/scrobble?identifier=com.plexapp.plugins.library&key={ratingKey}` - Mark item as watched
  - `GET /` - Server root for capabilities/version detection

**Plex Transcoding (via PMS):**
- Purpose: Video transcoding for incompatible formats
- URL pattern: `{serverUri}/video/:/transcode/universal/start.m3u8`
- Parameters: `path`, `protocol=hls`, `directPlay=0`, `directStream=1`, `videoQuality=100`, `maxVideoBitrate=20000`, `videoResolution=1920x1080`, `subtitles=auto`
- Implementation: `SimPlex/components/widgets/VideoPlayer.brs` function `buildTranscodeUrl()`

## Required X-Plex Headers

Every API request includes these headers via `GetPlexHeaders()` in `SimPlex/source/utils.brs`:
- `X-Plex-Product`: `"SimPlex"`
- `X-Plex-Version`: `"1.0.0"`
- `X-Plex-Client-Identifier`: Persistent UUID (generated once, stored in registry)
- `X-Plex-Platform`: `"Roku"`
- `X-Plex-Platform-Version`: Roku OS version from `roDeviceInfo`
- `X-Plex-Device`: Model display name from `roDeviceInfo`
- `X-Plex-Device-Name`: Friendly device name from `roDeviceInfo`
- `Accept`: `"application/json"`

## Data Storage

**Databases:**
- None. No database system.

**Persistent Storage:**
- Roku Registry (`roRegistrySection("SimPlex")`) - Key-value store on the Roku device
  - Keys stored:
    - `authToken` - Plex authentication token (read/write via `SimPlex/source/utils.brs` `GetAuthToken()`/`SetAuthToken()`)
    - `serverUri` - Selected Plex server URI (read/write via `GetServerUri()`/`SetServerUri()`)
    - `deviceId` - Persistent device UUID for Plex client identification (generated once via `GetDeviceId()`)
    - `serverClientId` - Selected server's client identifier (written in `SimPlex/components/MainScene.brs`)
  - All writes followed by `.Flush()` call

**File Storage:**
- Local filesystem only (`pkg:/images/` for bundled static assets)
- No cloud file storage

**Caching:**
- Roku's built-in image cache (poster images fetched via `ImageCacheTask` are cached by the platform)
- Implementation: `SimPlex/components/tasks/ImageCacheTask.brs` - prefetches images by GETting them, relying on Roku's internal cache
- No explicit cache management or TTL

## Authentication & Identity

**Auth Provider:**
- plex.tv PIN-based OAuth flow (custom implementation)
  - Implementation: `SimPlex/components/tasks/PlexAuthTask.brs` and `SimPlex/components/screens/PINScreen.brs`
  - Flow:
    1. App requests PIN from `POST https://plex.tv/api/v2/pins` (strong=false for 4-char code)
    2. User enters code at `https://plex.tv/link` on another device
    3. App polls `GET https://plex.tv/api/v2/pins/{id}` until `authToken` is present or PIN expires
    4. Auth token stored in Roku registry
    5. Server discovery via `GET https://plex.tv/api/v2/resources`
  - Token expiry: handled by 401 response detection in `PlexApiTask.brs` (lines 98-108), triggers global `authRequired` flag
  - Sign-out: `ClearAuthData()` in `SimPlex/source/utils.brs` deletes token, server URI, and server client ID

**Server Connection:**
- `SimPlex/components/tasks/ServerConnectionTask.brs` tests connections in priority order: local (3s timeout) > remote (5s timeout) > relay (5s timeout)
- Connection selection stored as `serverUri` in registry
- 401 responses from any API call trigger automatic re-authentication via `m.global.authRequired` observer in `SimPlex/components/MainScene.brs`

## Monitoring & Observability

**Error Tracking:**
- None. No external error tracking service.

**Logs:**
- Console `print` statements via `SimPlex/source/logger.brs`
- Two levels: `LogEvent()` (key milestones) and `LogError()` (problems)
- Format: `[ISO-timestamp] [LEVEL] message`
- Viewable via Roku developer console (telnet to port 8085 on device)

## CI/CD & Deployment

**Hosting:**
- Side-loaded directly to Roku device via HTTP upload
- Not published to Roku Channel Store

**CI Pipeline:**
- None detected. No GitHub Actions, no CI configuration files.

**Build Process:**
- Manual: `cd SimPlex && zip -r ../SimPlex.zip manifest source components images`
- Upload zip to `http://{roku-ip}:8060` via browser or curl

## Environment Configuration

**Required env vars:**
- None. Roku apps do not use environment variables.

**Secrets location:**
- Auth token stored in Roku device registry (encrypted at rest by Roku OS)
- No secrets in source code

**Configuration that must be set at runtime:**
- Auth token (obtained via PIN flow)
- Server URI (discovered via plex.tv resources API, validated via connection testing)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- Playback progress reports to PMS via `PUT /:/timeline` (periodic, every 10 seconds during playback)
- Scrobble notifications via `GET /:/scrobble` when playback completes
- Implementation: `SimPlex/components/widgets/VideoPlayer.brs` `reportProgress()` and `scrobble()` subs

## Direct Play Support

The VideoPlayer (`SimPlex/components/widgets/VideoPlayer.brs`) determines direct play vs transcode:

**Direct Play codecs (function `checkDirectPlay()`):**
- Video: h264, hevc, h265, vp9
- Audio: aac, ac3, eac3, mp3
- Containers: mp4, m4v, mkv

**Fallback:** HLS transcoding via PMS transcode endpoint

## Server Capabilities Detection

`SimPlex/source/capabilities.brs` parses the PMS root endpoint (`/`) response to detect:
- Server version (major.minor.patch parsing)
- Intro marker support (PMS 1.30+)
- Credits marker support (PMS 1.30+)
- HLS transcoding support (assumed true)
- Chapter support (assumed true)

---

*Integration audit: 2026-03-08*
