# Requirements

## Active

### FIX-08 — Subtitle/audio track selection panel must be accessible during playback — trigger with down arrow key (options key intercepted by Roku firmware on Video node; keep built-in trickplay bar)

### FIX-08 — Subtitle/audio track selection panel must be accessible during playback — trigger with down arrow key (options key intercepted by Roku firmware on Video node; keep built-in trickplay bar)

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Subtitle/audio track selection panel must be accessible during playback — trigger with down arrow key (options key intercepted by Roku firmware on Video node; keep built-in trickplay bar)

### NAV-01 — User can view a show's seasons as a poster grid/list screen

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

User can view a show's seasons as a poster grid/list screen

### NAV-02 — User can select a season to see its episodes in a grid

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

User can select a season to see its episodes in a grid

### NAV-03 — Season and episode screens show watched/progress state

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Season and episode screens show watched/progress state

### NAV-04 — Back button navigates correctly through Show → Seasons → Episodes stack

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Back button navigates correctly through Show → Seasons → Episodes stack

### SRV-01 — Server switching UI and code removed cleanly from SettingsScreen

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S15
- Validation: grep -c "Switch Server" SettingsScreen.brs → 0. Menu item removed, index handler renumbered (Sign Out at index 4). discoverServers() preserved for auth flows (3 occurrences).

Server switching UI and code removed cleanly from SettingsScreen

### SRV-02 — All 4 codepaths referencing server switching patched (no crash on multi-server accounts)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S15
- Validation: All 4 codepaths patched: (1) SettingsScreen menu item removed, (2) MainScene multi-server branch auto-connects to servers[0], (3) disconnect dialog "Server List" button removed, (4) four dead navigation subs deleted. ServerListScreen files deleted with zero dangling references.

All 4 codepaths referencing server switching patched (no crash on multi-server accounts)

### BRAND-01 — App icon and splash screen use a bolder font (Inter Bold or similar)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S16
- Validation: Inter-Bold.ttf bundled in SimPlex/fonts/, Sidebar.xml uses Font child nodes with pkg:/fonts/Inter-Bold.ttf URI, all icon/splash images generated with Inter Bold text via scripts/generate_branding.py.

App icon and splash screen use a bolder font (Inter Bold or similar)

### BRAND-02 — Icon/splash text has gray external stroke visible against dark background

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S16
- Validation: All icon and splash images rendered with gray (#666666) stroke outline using full-offset grid technique in generate_branding.py. Stroke visible against dark gradient background in generated assets.

Icon/splash text has gray external stroke visible against dark background

### BRAND-03 — Icon and splash screen backgrounds have subtle corner-to-corner black-to-charcoal gradient

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S16
- Validation: All four assets use diagonal gradient (#1A1A2E → #0A0A14) via (x+y)/(w+h) interpolation. bg_gradient.png (1920×1080) wired into MainScene.xml as Poster node replacing solid Rectangle.

Icon and splash screen backgrounds have subtle corner-to-corner black-to-charcoal gradient

### BRAND-04 — All icon variants updated (focus FHD 540x405, side FHD, HD variants)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S16
- Validation: icon_focus_fhd.png at 540×405, icon_side_fhd.png at 246×140, splash_fhd.jpg at 1920×1080 — all dimensions verified via PIL Image.open().size assertions.

All icon variants updated (focus FHD 540x405, side FHD, HD variants)

### DOCS-01 — Full README with user guide (install, configure, use)

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Full README with user guide (install, configure, use)

### DOCS-02 — Developer/architecture documentation (components, patterns, API)

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Developer/architecture documentation (components, patterns, API)

### DOCS-03 — .gitignore updated (exclude HAR files, credentials, build artifacts)

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

.gitignore updated (exclude HAR files, credentials, build artifacts)

### DOCS-04 — Repository published to GitHub

- Status: active
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Repository published to GitHub

## Validated

### SAFE-01 — BusySpinner SIGSEGV root cause confirmed and resolved (safe loading states across all screens)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

BusySpinner SIGSEGV root cause confirmed and resolved (safe loading states across all screens)

### SAFE-02 — Orphaned files deleted (normalizers.brs, capabilities.brs)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Orphaned files deleted (normalizers.brs, capabilities.brs)

### SAFE-03 — Utility code cleanup (extract common helpers, remove dead code patterns)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Utility code cleanup (extract common helpers, remove dead code patterns)

### FIX-01 — Auto-play next episode fires correctly from both EpisodeScreen and DetailScreen (grandparentRatingKey wiring)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Auto-play next episode fires correctly from both EpisodeScreen and DetailScreen (grandparentRatingKey wiring)

### FIX-02 — Auto-play countdown can be cancelled by user

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Auto-play countdown can be cancelled by user

### FIX-03 — Watch state changes propagate to parent screens (poster grids and hub rows)

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Watch state changes propagate to parent screens (poster grids and hub rows)

### FIX-07 — Progress bar width uses constant instead of hardcoded 240px

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: none yet

Progress bar width uses constant instead of hardcoded 240px

### FIX-04 — Collections menu item navigates to collections browsing screen

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S13
- Validation: HomeScreen auto-selects first library when m.currentSectionId is empty; Sidebar.libraries interface field exposes loaded library list. grep confirms wiring in Sidebar.brs and HomeScreen.brs.

Collections menu item navigates to collections browsing screen

### FIX-05 — Search results display without occluding search controls and are navigable

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S13
- Validation: SearchScreen keyboard collapses on right-nav (grid expands to 6 cols), reappears on left-nav (grid shrinks to 4 cols). PosterGrid computes columns dynamically from gridWidth. No Animation nodes.

Search results display without occluding search controls and are navigable

### FIX-06 — Thumbnail aspect ratio adapts based on image type

- Status: validated
- Class: core-capability
- Source: inferred
- Primary Slice: S13
- Validation: SearchScreen processSearchResults() applies grandparentThumb → parentThumb → thumb fallback chain for HDPosterUrl. Episodes show portrait show poster instead of stretched 16:9 screenshot.

Thumbnail aspect ratio adapts based on image type — detect whether Plex is serving a poster (2:3) or screen grab (16:9) and size the grid item accordingly, rather than hardcoding by library type

## Deferred

## Out of Scope
