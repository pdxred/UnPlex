# External Integrations

**Analysis Date:** 2026-03-13

## APIs & External Services

**Plex Media Server (PMS):**
- Local HTTP(S) server discovery and API endpoint
- SDK/Client: `roUrlTransfer` (built-in Roku)
- Auth: X-Plex-Token (stored in registry)
- Base URL: Retrieved from server discovery and stored in registry

**Plex.tv (plex.tv):**
- External authentication and server discovery service
- SDK/Client: `roUrlTransfer` (built-in Roku)
- Endpoints:
  - `POST https://plex.tv/api/v2/pins` - Request PIN for OAuth flow
  - `GET https://plex.tv/api/v2/pins/{id}` - Poll for auth token
  - `GET https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1` - Discover servers

## Authentication & Identity

**Auth Provider:**
- Plex Account (plex.tv)
- Implementation: PIN-based OAuth flow
  - User requests PIN via `PlexAuthTask` → `POST /api/v2/pins`
  - User enters code at plex.tv/link in web browser
  - App polls endpoint via `PlexAuthTask` → `GET /api/v2/pins/{id}`
  - Returns `authToken` when user completes auth
  - Token stored in registry for persistent sessions

**Token Storage:**
- Auth Token: User's Plex account token (stored in `roRegistrySection("SimPlex")`)
- Admin Token: Server owner's token (stored separately, allows managed user switching)
- Device ID: Unique client identifier generated on first run (stored persistently)

**Multi-user Support:**
- Active user name tracked in registry
- Admin token separate from active user token
- User switching with optional PIN entry (for managed users)

## Data Storage

**Databases:**
- No external database
- Local registry: `roRegistrySection("SimPlex")` - Roku's built-in key-value storage

**Persistent Data:**
- Device ID (auto-generated UUID)
- Auth tokens (user and admin)
- Server URI and connection details
- Active user name
- Pinned library configuration
- Sidebar library configuration

**File Storage:**
- Local filesystem only - app package includes manifest, source code, images
- No cloud storage or external file APIs used

**Caching:**
- Image cache: Built-in Roku image caching (HTTP cache headers from PMS)
- No external caching layer

## Content Discovery

**Library Browsing:**
- Endpoint: `{serverUri}/library/sections` - List available libraries
- Endpoint: `{serverUri}/library/sections/{id}/all` - Browse library contents
- Pagination: `X-Plex-Container-Start` and `X-Plex-Container-Size=50`
- Implementation: `PlexApiTask`

**Search:**
- Endpoint: `{serverUri}/hubs/search?query={term}&limit=20`
- Implementation: `PlexSearchTask`
- Debouncing: Handled by UI layer (not in task)

**Metadata:**
- Endpoint: `{serverUri}/library/metadata/{ratingKey}` - Item details
- Endpoint: `{serverUri}/library/onDeck` - Continue watching
- Implementation: `PlexApiTask`

## Playback & Sessions

**Direct Playback:**
- URL format: `{serverUri}{partKey}?X-Plex-Token={token}`
- Streaming: HTTP stream delivered by Plex Media Server
- Player: Built-in Roku `VideoPlayer` SceneGraph component

**Transcode Streams:**
- Endpoint: `{serverUri}/video/:/transcode/universal/start.m3u8`
- Parameters: `path={key}&protocol=hls` and other codec/bitrate settings
- Used for: Compatibility with devices or quality constraints

**Progress Tracking:**
- Endpoint: `{serverUri}/:/timeline` (PUT via X-HTTP-Method-Override)
- Parameters:
  - `ratingKey` - Media item ID
  - `state` - `playing`, `paused`, or `stopped`
  - `time` - Current position in milliseconds
  - `duration` - Total duration in milliseconds
- Frequency: Every 10 seconds during playback
- Implementation: `PlexSessionTask`

## Webhooks & Callbacks

**Incoming:**
- None - This app is consumer-only (no webhook endpoints)

**Outgoing:**
- None - Progress tracking via polling (PUT requests), not webhooks

## Server Discovery

**Auto-Discovery:**
- Service: plex.tv API provides server connection information
- Endpoint: `GET https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1`
- Returns: Array of available PMS servers with:
  - Connection URIs (local, remote, relay)
  - Server name and version
  - Client identifier for management
- Implementation: `PlexAuthTask.fetchResources()`

**Connection Selection:**
- Prioritizes local connections (same network)
- Fallback to relay connections if local unavailable
- Stores selected server URI and connection details

## Monitoring & Observability

**Error Tracking:**
- None - No external error reporting

**Logs:**
- None - No external log aggregation
- Internal: `LogEvent()` function logs to Roku debug console (development only)

**Debugging:**
- Roku debug port: SSH to port 8222 for telnet console
- Source maps available from build (sourceMap: true in bsconfig.json)

## Environment Configuration

**Required auth:**
- Plex account (email/password at plex.tv)
- Access to Plex Media Server

**Required network:**
- Internet connection to plex.tv for PIN auth and server discovery
- Network access to local Plex Media Server

**Optional:**
- Managed user accounts (if using multi-user PIN mode)
- Server with multiple libraries

## Critical Headers

**All Plex API requests include:**
- `X-Plex-Product` - "SimPlex"
- `X-Plex-Version` - "1.0.0"
- `X-Plex-Client-Identifier` - Device UUID (unique per Roku)
- `X-Plex-Platform` - "Roku"
- `X-Plex-Platform-Version` - Device OS version
- `X-Plex-Device` - Device model name
- `X-Plex-Device-Name` - Device friendly name
- `X-Plex-Token` - Auth token (except during PIN request)
- `Accept` - "application/json"

**Implementation:** `GetPlexHeaders()` in `SimPlex/source/utils.brs`

## API Rate Limiting

**Plex.tv PIN endpoint:**
- Polling: 1 second intervals (client-side throttle in UI, not enforced by API)

**PMS Library browsing:**
- Pagination: 50 items per request (X-Plex-Container-Size=50)
- Multiple fetches required for large libraries

**No documented rate limits** from Plex (typical for home use)

---

*Integration audit: 2026-03-13*
