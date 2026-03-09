# Codebase Concerns

**Analysis Date:** 2026-03-08

## Tech Debt

**Incomplete rename from PlexClassic to SimPlex:**
- Issue: The project was renamed from "PlexClassic" to "SimPlex" but several references to the old name remain scattered through the codebase.
- Files:
  - `SimPlex/components/MainScene.brs` (line 296): Exit dialog says `"Exit PlexClassic?"`
  - `SimPlex/components/widgets/Sidebar.xml` (line 17): Header text reads `"PlexClassic"`
  - `SimPlex/components/screens/SettingsScreen.brs` (line 85): Uses `roRegistrySection("PlexClassic")` instead of `"SimPlex"`
  - `SimPlex/images/README.txt` (line 1): Says `"PlexClassic Image Assets"`
- Impact: The SettingsScreen bug is critical -- it reads/writes to the wrong registry section (`"PlexClassic"`) while all other code uses `"SimPlex"`. This means the SettingsScreen `signOut()` function deletes credentials from the wrong registry section, so signing out from Settings does NOT actually clear the real auth data. The user appears signed out but the app will still use the old credentials on next launch.
- Fix approach: Global find-and-replace of `PlexClassic` with `SimPlex`. The registry section mismatch in `SettingsScreen.brs` is the highest priority fix.

**Duplicated ratingKey type-coercion logic:**
- Issue: The pattern for ensuring `ratingKey` is a string (checking type, calling `.ToStr()`) is copy-pasted verbatim in at least 5 locations.
- Files:
  - `SimPlex/components/screens/HomeScreen.brs` (lines 158-165)
  - `SimPlex/components/screens/EpisodeScreen.brs` (lines 136-143, 105-112, 188-195, 241-248)
  - `SimPlex/components/screens/SearchScreen.brs` (lines 104-111)
  - `SimPlex/components/screens/DetailScreen.brs` (lines 255-262, has its own `getRatingKeyString()` function)
- Impact: Code duplication increases maintenance burden. `DetailScreen.brs` already extracted a `getRatingKeyString()` helper, but it is not shared with other screens.
- Fix approach: Move `getRatingKeyString()` to `SimPlex/source/utils.brs` as a shared utility and replace all inline occurrences.

**Unused normalizers module:**
- Issue: `SimPlex/source/normalizers.brs` defines `NormalizeMovieList()`, `NormalizeShowList()`, `NormalizeSeasonList()`, `NormalizeEpisodeList()`, and `NormalizeOnDeck()` functions, but none of these are called anywhere in the codebase. Each screen manually creates ContentNode trees from raw JSON instead.
- Files: `SimPlex/source/normalizers.brs` (131 lines)
- Impact: Dead code that creates confusion about the intended architecture. The normalizers use `SafeGet()` for robust field access, but the screen implementations inline their own field-checking logic instead.
- Fix approach: Either adopt normalizers in all screens (replacing manual ContentNode construction in `HomeScreen.brs`, `EpisodeScreen.brs`, `SearchScreen.brs`) or delete the file. Adopting normalizers would also fix the duplicated ratingKey coercion issue.

**Capabilities module parsed but never queried at runtime:**
- Issue: `SimPlex/source/capabilities.brs` provides `ParseServerCapabilities()` and `HasCapability()` functions, but no code ever calls them. Server capabilities are never fetched or stored.
- Files: `SimPlex/source/capabilities.brs` (97 lines)
- Impact: Features like intro/credits skip markers cannot be conditionally shown or hidden. The capability infrastructure exists but is not wired up.
- Fix approach: Fetch server capabilities during `ServerConnectionTask` connection flow and store in `m.global`. Use `HasCapability()` checks in `VideoPlayer.brs` to show skip buttons when supported.

**Repeated `showError()` function across screens:**
- Issue: An identical `showError()` function is defined in 5 different screen files. Each creates a `StandardMessageDialog` with the same pattern.
- Files:
  - `SimPlex/components/screens/HomeScreen.brs` (lines 216-222)
  - `SimPlex/components/screens/DetailScreen.brs` (lines 272-278)
  - `SimPlex/components/screens/EpisodeScreen.brs` (lines 253-259)
  - `SimPlex/components/screens/SearchScreen.brs` (lines 152-158)
  - `SimPlex/components/widgets/VideoPlayer.brs` (lines 259-265)
- Impact: Minor -- code duplication but functionally correct.
- Fix approach: Extract to `SimPlex/source/utils.brs` or create a shared dialog utility component.

**`GetConstants()` creates a new associative array on every call:**
- Issue: `GetConstants()` in `SimPlex/source/constants.brs` allocates a new `roAssociativeArray` every time it is called. It is called frequently (every screen init, every key event in VideoPlayer, every poster URL build, etc.).
- Files: `SimPlex/source/constants.brs`
- Impact: Minor memory churn. On low-end Roku devices this adds unnecessary garbage collection pressure.
- Fix approach: Cache the constants object in `m.global` during app init, or use a module-scoped variable pattern.

## Known Bugs

**SettingsScreen signOut uses wrong registry section:**
- Symptoms: Signing out from the Settings screen does not actually clear authentication. On next launch, the app reconnects with old credentials.
- Files: `SimPlex/components/screens/SettingsScreen.brs` (line 85)
- Trigger: Navigate to Settings > Sign Out.
- Workaround: The `ClearAuthData()` function in `SimPlex/source/utils.brs` (line 40) uses the correct `"SimPlex"` section. The `signOut()` in `MainScene.brs` (line 150) calls `ClearAuthData()` correctly via the `showSignOut` field.
- Fix: Replace `CreateObject("roRegistrySection", "PlexClassic")` with `ClearAuthData()` call in `SettingsScreen.brs`.

**SettingsScreen server connection test callback never fires:**
- Symptoms: When discovering servers from SettingsScreen, the connection test result handler `onConnectionTestComplete()` is defined (line 220) but never wired up as an observer. After the API task completes, `onApiTaskStateChange()` fires but does not route to `onConnectionTestComplete()`.
- Files: `SimPlex/components/screens/SettingsScreen.brs` (lines 192-233)
- Trigger: Settings > Switch Server, then select a server with multiple connections.
- Workaround: None -- server switching from Settings is likely broken.
- Fix: The `onApiTaskStateChange()` handler needs to differentiate between server discovery responses and connection test responses (using a flag or separate task), and call `onConnectionTestComplete()` accordingly.

**VideoPlayer `errorMsg` field may not exist:**
- Symptoms: Potential crash when a video playback error occurs. Line 212 accesses `m.video.errorMsg` but the Roku `Video` node's error information is in `errorCode` and `errorStr`, not `errorMsg`.
- Files: `SimPlex/components/widgets/VideoPlayer.brs` (line 212)
- Trigger: Any video playback error (network timeout, unsupported codec, etc.).
- Workaround: None.
- Fix: Replace `m.video.errorMsg` with `m.video.errorStr` or a concatenation of `m.video.errorCode.ToStr() + ": " + m.video.errorStr`.

**PlexSearchTask and PlexAuthTask.checkPin use synchronous HTTP:**
- Symptoms: If the PMS or plex.tv is slow to respond, the task thread blocks with no timeout control for `GetToString()`.
- Files:
  - `SimPlex/components/tasks/PlexSearchTask.brs` (line 33): `url.GetToString()`
  - `SimPlex/components/tasks/PlexAuthTask.brs` (line 100): `url.GetToString()` in `checkPin()`
  - `SimPlex/components/tasks/PlexAuthTask.brs` (line 154): `url.GetToString()` in `fetchResources()`
- Trigger: Slow network or unresponsive server.
- Workaround: Task threads do not block the render thread, but the task cannot be cancelled while waiting.
- Fix: Use `AsyncGetToString()` with `wait(timeout, port)` pattern as done in `PlexApiTask.brs` (line 77-89).

## Security Considerations

**Auth token passed in URL query parameters:**
- Risk: The Plex auth token is appended to URLs as `X-Plex-Token={token}` query parameter. This means tokens appear in server access logs and could be leaked through referrer headers or cached URL strings.
- Files:
  - `SimPlex/source/utils.brs` (line 71): `BuildPlexUrl()` appends token to URL
  - `SimPlex/components/widgets/VideoPlayer.brs` (line 192): Transcode URL includes token in query
  - `SimPlex/components/tasks/PlexSessionTask.brs` (line 20): Timeline URL includes token in query
- Current mitigation: This is the standard Plex API approach; all official Plex clients do this. HTTPS encrypts the full URL in transit.
- Recommendations: Consider using `X-Plex-Token` as a header instead of a query parameter where the API supports it (all endpoints except direct media playback URLs).

**No validation of server TLS certificates beyond system CA bundle:**
- Risk: The app uses `common:/certs/ca-bundle.crt` (Roku's built-in CA bundle) which is standard practice. However, there is no certificate pinning for plex.tv connections.
- Files: All task files that create `roUrlTransfer` objects.
- Current mitigation: Standard TLS validation via system CA bundle.
- Recommendations: Low priority. Certificate pinning for plex.tv would add security but is unusual for Roku apps.

## Performance Bottlenecks

**ImageCacheTask downloads images sequentially:**
- Problem: The image cache task fetches all images one-by-one in a `for each` loop using synchronous `GetToString()`.
- Files: `SimPlex/components/tasks/ImageCacheTask.brs` (lines 15-34)
- Cause: Each image URL is fetched synchronously before moving to the next. For a page of 50 posters, this means 50 sequential HTTP requests.
- Improvement path: Use `AsyncGetToString()` with a pool of concurrent requests (3-5 parallel downloads). Alternatively, rely on Roku's built-in image caching by setting poster URLs directly on `Poster` nodes (Roku fetches and caches images automatically).

**No pagination for On Deck and Recently Added:**
- Problem: `loadOnDeck()` and `loadRecentlyAdded()` in `HomeScreen.brs` fetch without pagination parameters, which means the server returns a default-sized result set. For large libraries this may return hundreds of items.
- Files: `SimPlex/components/screens/HomeScreen.brs` (lines 92-114)
- Cause: No `X-Plex-Container-Size` parameter is set for these endpoints.
- Improvement path: Add `X-Plex-Container-Size` parameter (e.g., 50) to these requests.

**Sidebar reloads libraries on every HomeScreen creation:**
- Problem: Each time the HomeScreen is pushed onto the screen stack, the Sidebar re-fetches `/library/sections`. Library sections rarely change during a session.
- Files: `SimPlex/components/widgets/Sidebar.brs` (line 32): `loadLibraries()` called in `init()`
- Cause: No caching of library section data.
- Improvement path: Store library sections in `m.global` and only refresh on explicit user action or after a timeout.

## Fragile Areas

**Screen stack focus restoration:**
- Files: `SimPlex/components/MainScene.brs` (lines 229-270)
- Why fragile: `getDeepFocusedChild()` recursively traverses the focus chain to save the deepest focused node. When a screen is popped, it restores focus to that saved node. If the saved node was removed or its parent hierarchy changed while the screen was hidden, `setFocus(true)` on the stale reference could fail silently (focus goes nowhere) or cause unexpected behavior.
- Safe modification: Always test screen stack navigation after changing any screen's child node structure. Ensure cleanup functions remove observers before nodes are freed.
- Test coverage: No automated tests exist.

**Single shared API task per screen:**
- Files:
  - `SimPlex/components/screens/HomeScreen.brs` (line 14): One `m.apiTask`
  - `SimPlex/components/screens/EpisodeScreen.brs` (line 12): One `m.apiTask` with `requestId` to multiplex
  - `SimPlex/components/screens/SettingsScreen.brs` (lines 14-19): Two tasks but `onApiTaskStateChange` conflates server discovery and connection test responses
- Why fragile: If a user triggers a second API request before the first completes, the task's fields (endpoint, params) are overwritten. The `m.isLoading` guard in `HomeScreen.brs` mitigates this for library loads, but rapid sidebar navigation could still cause race conditions.
- Safe modification: Create new task instances for each request, or use a request queue pattern.
- Test coverage: No automated tests exist.

**VideoPlayer lifecycle management:**
- Files:
  - `SimPlex/components/screens/DetailScreen.brs` (lines 206-231)
  - `SimPlex/components/screens/EpisodeScreen.brs` (lines 215-251)
- Why fragile: The VideoPlayer is appended directly to the scene root (`m.top.getScene().appendChild`) rather than pushed onto the screen stack. This bypasses the screen stack's cleanup and focus management. If playback errors occur during the `removeChild` operation, or if the user navigates away while the player is initializing, `m.player` could become an orphaned node.
- Safe modification: Consider integrating VideoPlayer into the screen stack, or ensure robust null-checking and cleanup in all error paths.
- Test coverage: No automated tests exist.

## Missing Critical Features

**No auto-play next episode:**
- Problem: After an episode finishes playing, there is no countdown or automatic transition to the next episode.
- Files: `SimPlex/components/screens/EpisodeScreen.brs` (line 235): `' TODO: Auto-play next episode with countdown`
- Blocks: Binge-watching workflow requires manual episode selection after each episode ends.

**No subtitle selection UI:**
- Problem: The transcode URL sets `subtitles=auto` but there is no user-facing control to select subtitle tracks or toggle subtitles on/off.
- Files: `SimPlex/components/widgets/VideoPlayer.brs` (line 191)
- Blocks: Users who need specific subtitle tracks or want to disable subtitles cannot do so.

**No audio track selection:**
- Problem: Multi-audio media always plays the default audio track with no way to switch.
- Files: `SimPlex/components/widgets/VideoPlayer.brs`
- Blocks: Users with multi-language media cannot select their preferred audio track.

**No music library support:**
- Problem: The Sidebar shows music libraries (type `"artist"`) but there is no playback or browsing UI for music content. Selecting a music library loads items into the poster grid but clicking an artist would try to show a DetailScreen, which is designed for movies/shows.
- Files: `SimPlex/components/widgets/Sidebar.brs` (lines 90-91)
- Blocks: Music libraries appear in the UI but are non-functional.

**No error recovery or retry mechanism:**
- Problem: When API requests fail, an error dialog is shown but there is no retry button or automatic retry logic. The user must navigate back and try again.
- Files: All screen files that call `showError()`.
- Blocks: Transient network errors require full re-navigation to recover.

## Test Coverage Gaps

**No automated tests exist:**
- What's not tested: The entire codebase has zero automated tests. BrightScript does not have a standard testing framework, but community tools like `rooibos` exist for Roku SceneGraph testing.
- Files: All files in `SimPlex/`
- Risk: Any code change could introduce regressions with no automated detection. The fragile areas identified above (screen stack, focus management, API task multiplexing) are especially risky to modify without tests.
- Priority: Medium -- manual testing on a physical Roku device is the current approach, but this is slow and error-prone for regression detection.

## Dependencies at Risk

**Plex API stability:**
- Risk: The app depends on undocumented or semi-documented Plex Media Server REST API endpoints. Plex can change these APIs without notice in server updates.
- Impact: Server updates could break library browsing, playback, or authentication.
- Migration plan: Monitor Plex changelog for API changes. The auth flow uses the documented v2 PIN API which is more stable than the library browsing endpoints.

---

*Concerns audit: 2026-03-08*
