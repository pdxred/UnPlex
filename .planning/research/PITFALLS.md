# Domain Pitfalls

**Domain:** Roku Plex Media Server Client (BrightScript / SceneGraph)
**Researched:** 2026-03-08
**Overall confidence:** HIGH (grounded in Roku platform docs, Plex API references, and existing codebase analysis)

---

## Critical Pitfalls

Mistakes that cause rewrites, crashes, or fundamentally broken features.

### Pitfall 1: Roku Cannot Render PGS or Bitmap Subtitles -- Burn-In Is the Only Path

**What goes wrong:** PGS (Presentation Graphic Stream) subtitles are the default format for Blu-ray rips in MKV containers. Roku has zero support for PGS rendering. If the client requests direct play with PGS subtitles selected, the user sees no subtitles at all -- no error, just silence. This is the single most common Plex+Roku complaint.

**Why it happens:** Roku's Video node only supports text-based subtitle formats: SRT (universally supported), TTML/SMPTE-TT, WebVTT (HLS-embedded), and EIA-608/708 (embedded in video stream). PGS is image-based and requires the decoder to composite bitmaps onto the video frame, which Roku's hardware pipeline does not support.

**Consequences:** Users with anime, foreign films, or Blu-ray rips will see "subtitles available" in the UI but get nothing on screen. This is a silent failure -- no error is thrown.

**Prevention:**
1. When building subtitle track selection, inspect each stream's `codec` field from the Plex API response. PGS streams have codec `"pgs"`, ASS/SSA have `"ass"`, SRT has `"srt"`.
2. For PGS, ASS, or any bitmap/styled format: force transcode with `subtitles=burn` in the transcode URL. Do not attempt direct play.
3. For SRT: use sidecar delivery via `SubtitleTracks` content metadata on the ContentNode. SRT can be direct-played.
4. Show a visual indicator in the subtitle picker distinguishing "direct" vs "burn-in (slower start)" tracks.
5. The current `buildTranscodeUrl()` uses `subtitles=auto` which may not reliably burn in PGS. Change to `subtitles=burn&subtitleStreamID={id}` when a bitmap subtitle is selected.

**Detection:** Test with an MKV containing PGS subtitles. If subtitles appear with no video re-buffering, something is wrong (PGS requires transcoding). If they do not appear at all, burn-in is not being triggered.

**Phase relevance:** Subtitle track selection phase. This must be the first thing validated.

**Sources:**
- [Roku Closed Caption docs](https://developer.roku.com/docs/developer-program/media-playback/closed-caption.md)
- [PGS subtitle Plex+Roku pain](https://www.howtogeek.com/as-a-plex-user-im-begging-roku-to-support-pgs-subtitles/)

---

### Pitfall 2: Rendezvous Timeouts from Observer Callback Cascades

**What goes wrong:** When a Task node completes and fires an observer callback on the render thread, that callback runs on the render thread. If the callback creates ContentNode trees, sets multiple fields, or triggers further observer chains, it blocks the render thread. On lower-end Roku hardware, cascading observer callbacks (e.g., hub row data loading triggering 8+ row population callbacks in quick succession) cause rendezvous timeouts and app crashes.

**Why it happens:** Each Task-to-render-thread communication is a rendezvous. Setting fields on SceneGraph nodes from the render thread is fine, but doing it in bulk (creating 200+ ContentNodes in a single callback) or triggering observer chains (setting a field that triggers another observer that sets more fields) creates a blocking cascade. Roku's rendezvous has a timeout; exceed it and the app crashes.

**Consequences:** App crash with no user-visible error. On low-end Roku devices (Express, Streaming Stick), this happens more frequently and earlier. The crash is non-deterministic, making it hard to reproduce.

**Prevention:**
1. Build ContentNode trees entirely within the Task thread, then pass the completed tree to the render thread via a single field assignment. One rendezvous for the whole tree, not one per node.
2. Use `setFields()` instead of multiple individual field assignments (one rendezvous instead of N).
3. For hub rows: load rows sequentially with small delays (`Timer` node with 100-200ms between row loads) rather than firing all row requests simultaneously.
4. Never create SceneGraph nodes (other than ContentNode) inside Task threads -- only ContentNode trees are safe to build in tasks and pass across.
5. Profile with `channelperf` debug port and Roku Resource Monitor to identify rendezvous hotspots.

**Detection:** Enable the BrightScript debug console and look for "rendezvous" warnings. Test on the lowest-end supported Roku device.

**Phase relevance:** Hub rows phase (loading multiple hub endpoints), filter/sort phase (rebuilding grids), any phase that populates large ContentNode trees.

**Sources:**
- [Roku SceneGraph Threads](https://sdkdocs-archive.roku.com/SceneGraph-Threads_4262152.html)
- [Rendezvous explanation](https://medium.com/@amitdogra70512/rendezevous-in-roku-bd55d81fc994)

---

### Pitfall 3: Memory Pressure from ContentNode Trees in Large Libraries

**What goes wrong:** With tens of thousands of items in a library, naive approaches (loading all items, keeping all ContentNode trees in memory for back-navigation) exhaust Roku's available memory. Roku devices have limited RAM (256MB-1.5GB depending on model), and texture memory is capped at approximately 95MB shared with the OS. The app gets killed by the OS with no crash dialog.

**Why it happens:** Each ContentNode with custom fields costs significant memory. Benchmarks show 2,000 extended ContentNodes take ~1,324ms to create and consume substantial heap. Poster images at full resolution (even when displayed at 240x360) consume texture memory at `width * height * 4 bytes`. A grid page of 50 posters at 480x720 source resolution uses ~66MB of texture memory.

**Consequences:** OS kills the channel silently. User sees "channel closed" or a reboot on very low-end devices. This is the hardest bug to diagnose because there is no error callback.

**Prevention:**
1. Paginate aggressively: 50 items per page maximum, which the existing code already does.
2. When navigating away from a screen (popping the screen stack), explicitly release ContentNode trees by setting the grid's `content` field to `invalid` in the cleanup function. Do not rely on garbage collection.
3. Request poster images at the exact display size via Plex's `/photo/:/transcode?width=240&height=360` -- the existing code does this, but verify all new image-loading paths follow this pattern.
4. For hub rows: limit to 20 items per row initially (Plex hub endpoints return limited results by default -- do not override with large container sizes).
5. Use Roku Resource Monitor during development to track system memory, texture memory, and node count.
6. Use `addFields` instead of `extends` when creating ContentNode subtypes -- `extends` is significantly more expensive.

**Detection:** Monitor memory via `sgnodes all` in the debug console. Watch for increasing node counts after navigation (indicates leaks). Test with libraries of 10,000+ items.

**Phase relevance:** Every phase, but especially hub rows (many concurrent data sources), music (album art grids), and photo browsing (high-resolution images).

**Sources:**
- [Roku Memory Management](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md)
- [ContentNode benchmarks](https://medium.com/dazn-tech/rokus-scenegraph-benchmarks-aa-vs-node-9be5158474c1)

---

### Pitfall 4: Music Playback Cannot Survive Screen Navigation with Current Architecture

**What goes wrong:** The current VideoPlayer is appended directly to the scene and removed when playback completes. Music playback requires audio to continue while the user browses other screens (album art, queue, library). If the Audio node is owned by a screen that gets popped from the stack, playback stops.

**Why it happens:** Roku's SceneGraph node tree is the DOM -- removing a node from the tree stops its playback. The Audio node must remain in the scene tree for the duration of playback. The current architecture has no concept of a persistent, cross-screen playback component.

**Consequences:** Music stops every time the user navigates. The app feels broken for music use. Retrofitting this after building music screens is a significant refactor.

**Prevention:**
1. Create the Audio node as a child of MainScene (the root), not any individual screen. It persists across all screen stack operations.
2. Build a `NowPlayingBar` widget that is always visible at the bottom of MainScene when audio is playing. This bar shows track info, progress, and play/pause.
3. The NowPlayingBar observes fields on the persistent Audio node. Screens can interact with the Audio node via `m.global` fields (e.g., `m.global.audioQueue`, `m.global.audioControl`).
4. Design this architecture before building any music screens. Retrofitting is painful.
5. The Audio node playlist cannot be modified after playback starts -- build the full queue ContentNode tree before calling `control = "play"`.

**Detection:** Navigate away from the music player screen. If audio stops, the node is parented incorrectly.

**Phase relevance:** Music phase. This architecture decision must be made at the start of the music phase, not mid-implementation.

**Sources:**
- [Roku Audio node](https://developer.roku.com/docs/references/scenegraph/media-playback-nodes/audio.md)

---

### Pitfall 5: Intro Skip Button Timing Is a Race Condition Without Marker Pre-Fetch

**What goes wrong:** The intro skip button must appear at a precise timestamp (e.g., second 32) and disappear at another (e.g., second 91). Developers fetch the marker data from `/library/metadata/{id}?includeMarkers=1` after playback starts, but the API call takes 200-500ms. If the intro starts at second 0 (cold opens), the marker data arrives after the intro has already begun, and the skip button appears late or not at all.

**Why it happens:** The Plex API returns intro/credits markers as part of the metadata response, but only when `includeMarkers=1` is included in the request. The current `processMediaInfo()` does not request markers. Even when markers are requested, network latency means marker data arrives after playback has already started.

**Consequences:** Skip button appears 0.5-2 seconds late, or the intro window is already past when the button renders. For short intros (15-20 seconds), the button may never appear.

**Prevention:**
1. Fetch markers during the `loadMedia()` phase, before playback starts. The metadata endpoint already returns markers when `includeMarkers=1` is added -- bundle it with the existing media info fetch, not as a separate request.
2. Parse the `Marker` array from the metadata response. Each marker has `type` ("intro", "credits"), `startTimeOffset` (ms), and `endTimeOffset` (ms).
3. Store markers in `m.markers` before calling `m.video.control = "play"`.
4. In `onPositionChange()`, compare current position against stored marker ranges. Show/hide the skip button based on the pre-fetched data. No async call needed at playback time.
5. Credits skip is the same mechanism but triggers the "next episode" flow instead of seeking.

**Detection:** Test with an episode whose intro starts at 0:00. If the skip button does not appear within the first second, markers are being fetched too late.

**Phase relevance:** Intro/credits skip phase, auto-play next episode phase.

**Sources:**
- [Plex marker types](https://forums.plex.tv/t/question-about-markers-and-manipulating-them/931778)
- [Plex skip content docs](https://support.plex.tv/articles/skip-content/)

---

## Moderate Pitfalls

### Pitfall 6: SubtitleTracks vs SubtitleConfig Confusion Breaks Auto-Selection

**What goes wrong:** Roku has two subtitle configuration mechanisms: `SubtitleTracks` (content metadata that lists available tracks with language/description) and `SubtitleConfig` (overrides automatic track selection). Developers commonly set `SubtitleConfig` thinking it enables subtitles, but this actually disables Roku's automatic language-based selection, breaking the user's system-level caption preference.

**Prevention:**
1. Always populate `SubtitleTracks` on the ContentNode with all available subtitle streams from the Plex API response.
2. Only use `SubtitleConfig` when the user explicitly selects a specific track from your UI picker.
3. Map Plex stream data to Roku's expected format: `{ "TrackName": "srt/path", "Language": "eng", "Description": "English" }`.
4. For sidecar SRT files, the `TrackName` must be the full URL to the SRT file served by the Plex server: `{serverUri}/library/streams/{streamId}?X-Plex-Token={token}`.

**Phase relevance:** Subtitle track selection phase.

**Sources:**
- [Roku SubtitleTracks docs](https://developer.roku.com/docs/developer-program/media-playback/closed-caption.md)

---

### Pitfall 7: Managed User Token Swap Invalidates All Active Tasks

**What goes wrong:** When switching managed users via the Plex Home API (`POST /api/home/users/{id}/switch`), a new auth token is returned. Any in-flight API tasks using the old token will receive 401 responses. If the app does not cancel all active tasks and update the stored token atomically, some requests succeed with the new token while others fail with the old one, creating inconsistent state.

**Prevention:**
1. When switching users: stop all active Task nodes first (set `control = "stop"` on every task).
2. Update the token in registry AND in `m.global.authToken` atomically (single function call).
3. Clear all cached data (library sections, hub rows, on-deck) -- the new user may have different library access.
4. Pop all screens and push a fresh HomeScreen. Do not try to refresh screens in place.
5. The switch endpoint returns a token for the managed user, but managed user tokens cannot manage PINs. Store the admin token separately if PIN management is needed later.

**Phase relevance:** Managed users phase.

**Sources:**
- [Plex managed user switch API](https://www.plexopedia.com/plex-media-server/api-plextv/managed-user-add/)
- [Plex fast user switching](https://support.plex.tv/articles/204232453-fast-user-switching/)

---

### Pitfall 8: RowList Vertical Lazy Loading Causes Visible Scroll Stutters

**What goes wrong:** When using RowList for hub rows on the home screen, scrolling down triggers lazy loading of the next row's data. During the load, the scroll animation freezes visibly. The user experiences the UI "sticking" for 200-500ms at each row boundary. This is especially noticeable on lower-end devices.

**Prevention:**
1. Pre-fetch 2-3 rows ahead of the current visible area. Use the RowList's `rowItemFocused` field to detect which row is focused and trigger loading for `focusedRow + 2` and `focusedRow + 3`.
2. Populate rows with placeholder ContentNodes (empty titles, placeholder poster URLs) immediately, then update with real data when the API response arrives. This prevents the RowList from resizing during scroll.
3. Consider using MarkupGrid instead of RowList for the main library view -- benchmarks show 50% better scroll performance in some configurations.
4. Build the entire ContentNode subtree for a row in the Task thread, then assign it to the RowList content with a single `replaceChild()` call. Do not append children one at a time.

**Phase relevance:** Hub rows phase.

**Sources:**
- [RowList lazy loading issues](https://community.roku.com/t5/Roku-Developer-Program/Problem-with-vertical-lazy-loading-in-RowList/td-p/1014936)
- [MarkupGrid vs RowList performance](https://community.roku.com/discussions/developer/markupgrid-or-rowlist-what-should-i-use/480811)

---

### Pitfall 9: Live TV HLS Streams Require Different Buffering and Error Handling

**What goes wrong:** Live TV streams from Plex DVR tuners behave differently from VOD streams. The HLS manifest is a live sliding window (no duration, no seekability). Developers reuse the same Video node configuration as VOD, resulting in: seek buttons that crash or show errors, progress bars that display nonsensical durations, and buffering that never recovers when the tuner has a momentary signal loss.

**Prevention:**
1. Detect live streams from the Plex API response: live sessions have `live="1"` in the metadata, and the stream URL is a live HLS manifest (`EVENT` or `LIVE` type, not `VOD`).
2. Disable seek controls (forward/back keys) in `onKeyEvent` for live streams.
3. Hide the progress bar or show a "LIVE" indicator instead of elapsed/remaining time.
4. Set `m.video.bufferingBar.visible = true` with appropriate buffering thresholds. Live streams need higher buffer tolerance (2-5 seconds) compared to VOD.
5. Handle the `error` state more gracefully for live streams -- a tuner glitch may resolve in seconds. Implement auto-retry with a 3-second delay before showing an error dialog.
6. The Plex live TV API uses `/livetv/sessions` for tuner management. Each tuner session must be explicitly started and stopped. Failing to stop a session when the user navigates away leaves the tuner locked, blocking other recordings.

**Phase relevance:** Live TV phase.

**Sources:**
- [Roku streaming specifications](https://developer.roku.com/docs/specs/media/streaming-specifications.md)
- [Plex Live TV & DVR docs](https://support.plex.tv/articles/225877347-live-tv-dvr/)

---

### Pitfall 10: Focus Traps in Overlay UI (Subtitle Picker, Skip Button, Settings Dialogs)

**What goes wrong:** When an overlay UI element (subtitle track picker, audio track picker, intro skip button) is shown on top of the video player, focus management becomes complex. If the overlay consumes the "back" key to close itself but does not properly restore focus to the Video node, the video becomes uncontrollable -- the user cannot pause, seek, or exit playback. On Roku, a focus-less screen is a dead end requiring the Home button.

**Why it happens:** `onKeyEvent` propagates up the node tree. An overlay that returns `true` for "back" to close itself prevents the Video node (its parent or sibling) from ever receiving that key. After the overlay is removed, if `setFocus(true)` is not called on the Video node, focus falls to the scene root or nowhere.

**Prevention:**
1. Every overlay component must call `m.top.getParent().setFocus(true)` or a designated focus target after removing itself.
2. Test the sequence: open overlay -> close overlay -> verify all remote buttons still work (play, pause, back, directional).
3. The intro skip button should auto-dismiss (hide, not remove from tree) after the intro window passes. Do not remove nodes from the tree during playback -- just toggle visibility.
4. Use a focus management pattern: store the "focus return target" before showing any overlay, restore it on overlay dismissal.

**Phase relevance:** Subtitle selection phase, intro skip phase, audio track selection phase, any phase adding playback overlays.

**Sources:**
- [Roku focus handling guide](https://www.tothenew.com/blog/mastering-focus-handling-in-roku-a-comprehensive-guide-to-focus-handling-through-mapping/)
- [Roku onKeyEvent docs](https://developer.roku.com/docs/references/scenegraph/component-functions/onkeyevent.md)

---

## Minor Pitfalls

### Pitfall 11: Plex API `/hubs` Response Structure Varies by Library Type

**What goes wrong:** The `/hubs` endpoint returns different hub types depending on the library type (movie, show, music, photo). Developers build a single hub row renderer and it breaks when music hubs return `artist` items instead of `movie`/`show` items, or when photo hubs return items with no `thumb` field (they use `art` instead).

**Prevention:**
1. Build the hub row data normalizer to handle all item types: `movie`, `show`, `season`, `episode`, `artist`, `album`, `track`, `photo`, `clip`.
2. Use a type-based poster URL builder: movies/shows use `thumb`, artists/albums use `thumb`, photos use `art` or the first `Media[0].Part[0].key`.
3. Use the existing `normalizers.brs` module (currently unused) as the foundation -- extend it to handle all types.

**Phase relevance:** Hub rows phase, music phase, photos phase.

---

### Pitfall 12: Audio Node Playlist Is Immutable After Playback Starts

**What goes wrong:** Developers build a music queue, start playback, then try to add/remove tracks from the queue by modifying the Audio node's content ContentNode. Changes are silently ignored. The queue appears to update in the UI but the Audio node continues playing the original playlist.

**Prevention:**
1. To modify a music queue mid-playback: note the current track index and position, stop the Audio node, rebuild the entire ContentNode playlist tree, re-assign it to the Audio node, seek to the saved position.
2. Build a queue management layer in BrightScript (an array of track metadata) that is the source of truth. The Audio node's ContentNode is rebuilt from this array whenever the queue changes.
3. For "play next" and "add to queue" features: modify the BrightScript queue array, then rebuild and re-assign the ContentNode.

**Phase relevance:** Music phase (playback queue management).

---

### Pitfall 13: Single Shared API Task Causes Request Collisions

**What goes wrong:** The current codebase uses one `m.apiTask` per screen. If the user triggers a second API request before the first completes (e.g., rapid sidebar navigation, or loading detail metadata while hub rows are still fetching), the task's `endpoint` field is overwritten. The first request's response handler processes the second request's data, or vice versa.

**Why it happens:** BrightScript Task nodes can only run one request at a time. Setting new fields on a running task overwrites the pending request. The `m.isLoading` guard in HomeScreen mitigates this partially but not completely.

**Prevention:**
1. Create a new Task node instance for each API request. Task nodes are lightweight; creating one per request avoids all collision issues.
2. Alternatively, implement a request queue in the screen that serializes requests and processes responses in order.
3. For screens that genuinely need multiple concurrent requests (hub rows loading 8 endpoints), create multiple Task instances (one per hub row).

**Phase relevance:** Hub rows phase (multiple concurrent requests), filter/sort phase (rapid re-queries).

**Note:** This is already documented in CONCERNS.md as a fragile area. Fixing it in the hub rows phase prevents compounding issues in later phases.

---

### Pitfall 14: EPG Grid for Live TV Is a Custom Component Nightmare

**What goes wrong:** Roku has no built-in EPG (Electronic Program Guide) grid component. Developers must build a custom scrolling time-based grid from scratch using Group/Rectangle/Label nodes. This is the most complex custom UI component in any Roku app and is extremely prone to: focus management bugs, memory leaks (thousands of program cells), scroll performance issues, and time-zone rendering errors.

**Prevention:**
1. Start with the simplest possible EPG: a LabelList of channels, and when a channel is focused, show the current/next program info in a detail panel. This avoids the full grid entirely for v1.
2. If a full grid is required: limit the visible time window to 2 hours, virtualize the grid (only render visible cells), and use `Timer` nodes to shift the time window rather than re-rendering the entire grid.
3. Time zone handling: Plex EPG data uses UTC timestamps. Convert to local time using `CreateObject("roDateTime")` and its `toLocalTime()` method. Do not do string-based time math.
4. Limit the EPG data fetch to the current 4-hour window. Do not pre-fetch a full day's guide data.

**Phase relevance:** Live TV phase.

---

### Pitfall 15: GetConstants() Called on Every Key Event Creates GC Pressure

**What goes wrong:** The existing `GetConstants()` function in `constants.brs` allocates a new `roAssociativeArray` every time it is called. In `VideoPlayer.brs`, it is called on every key press and every position change callback. Under rapid key repeat (holding fast-forward), this creates hundreds of allocations per second, contributing to garbage collection pauses that cause visible playback stutters.

**Prevention:**
1. Cache constants in `m.global` during app initialization. Access via `m.global.constants` everywhere.
2. This is already documented in CONCERNS.md. Fix it before adding more constant-heavy features (subtitle picker, intro skip, music playback controls).

**Phase relevance:** Should be fixed in the first phase as infrastructure cleanup. Affects every subsequent phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Hub Rows | Rendezvous cascade from 8+ concurrent hub row loads (#2) | Stagger row loads with 100-200ms Timer delays; build ContentNode trees in Task threads |
| Hub Rows | Single shared API task collisions (#13) | Create one Task per hub row request |
| Hub Rows | RowList scroll stutter (#8) | Pre-fetch 2-3 rows ahead, use placeholder ContentNodes |
| Filters/Sort | Rebuilding grid with 1000+ items blocks render thread (#2) | Build new ContentNode tree in Task, swap atomically |
| Subtitle Selection | PGS/bitmap subtitles show nothing on direct play (#1) | Detect codec, force burn-in transcode for non-SRT formats |
| Subtitle Selection | SubtitleTracks vs SubtitleConfig confusion (#6) | Use SubtitleTracks for listing, SubtitleConfig only for user override |
| Subtitle Selection | Focus trap in subtitle picker overlay (#10) | Store focus target, restore on overlay dismiss |
| Intro Skip | Marker data arrives after intro starts (#5) | Pre-fetch markers with media metadata before playback |
| Intro Skip | Skip button overlay focus issues (#10) | Auto-hide (visibility toggle), do not remove from tree |
| Audio Track Selection | Focus trap in audio picker overlay (#10) | Same pattern as subtitle picker |
| Music Playback | Audio stops on screen navigation (#4) | Parent Audio node to MainScene, not to any screen |
| Music Playback | Immutable playlist after play starts (#12) | Rebuild entire ContentNode on queue change |
| Live TV | VOD-style controls break on live streams (#9) | Detect `live="1"`, disable seek, show LIVE indicator |
| Live TV | EPG grid custom component complexity (#14) | Start with simple channel list, not full grid |
| Live TV | Tuner session not released on navigate-away (#9) | Explicitly stop tuner session in screen cleanup |
| Managed Users | Token swap invalidates active tasks (#7) | Stop all tasks, update token atomically, clear caches, reset screen stack |
| All Phases | Memory pressure from ContentNode accumulation (#3) | Release content on screen pop, request sized images, monitor with Resource Monitor |
| All Phases | GetConstants() GC pressure (#15) | Cache in m.global before starting feature work |

---

## Sources

- [Roku Closed Caption Support](https://developer.roku.com/docs/developer-program/media-playback/closed-caption.md) -- subtitle format support, SubtitleTracks/SubtitleConfig
- [Roku Video Node Reference](https://developer.roku.com/docs/references/scenegraph/media-playback-nodes/video.md) -- availableSubtitleTracks, subtitleTrack fields
- [Roku Audio Node Reference](https://developer.roku.com/docs/references/scenegraph/media-playback-nodes/audio.md) -- playlist behavior, content field
- [Roku SceneGraph Threads](https://sdkdocs-archive.roku.com/SceneGraph-Threads_4262152.html) -- rendezvous mechanics
- [Roku Memory Management](https://developer.roku.com/docs/developer-program/performance-guide/memory-management.md) -- memory limits, optimization
- [Roku Data Management](https://developer.roku.com/docs/developer-program/performance-guide/data-management.md) -- ContentNode best practices
- [Roku Streaming Specifications](https://developer.roku.com/docs/specs/media/streaming-specifications.md) -- HLS, format support
- [Roku Focus Handling Guide](https://www.tothenew.com/blog/mastering-focus-handling-in-roku-a-comprehensive-guide-to-focus-handling-through-mapping/)
- [ContentNode Benchmarks (DAZN Engineering)](https://medium.com/dazn-tech/rokus-scenegraph-benchmarks-aa-vs-node-9be5158474c1)
- [Rendezvous Explained](https://medium.com/@amitdogra70512/rendezevous-in-roku-bd55d81fc994)
- [PGS Subtitles on Roku (How-To Geek)](https://www.howtogeek.com/as-a-plex-user-im-begging-roku-to-support-pgs-subtitles/)
- [Plex Skip Content](https://support.plex.tv/articles/skip-content/) -- marker types, intro/credits detection
- [Plex Marker API Discussion](https://forums.plex.tv/t/question-about-markers-and-manipulating-them/931778)
- [Plex Live TV & DVR](https://support.plex.tv/articles/225877347-live-tv-dvr/)
- [Plex Fast User Switching](https://support.plex.tv/articles/204232453-fast-user-switching/)
- [Plex Managed User API](https://www.plexopedia.com/plex-media-server/api-plextv/managed-user-add/)
- [RowList Lazy Loading Issues](https://community.roku.com/t5/Roku-Developer-Program/Problem-with-vertical-lazy-loading-in-RowList/td-p/1014936)
- [Roku Resource Monitor](https://blog.roku.com/developer/resource-monitor)

---

*Pitfalls audit: 2026-03-08*
