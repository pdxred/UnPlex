# Requirements: SimPlex

**Defined:** 2026-03-13
**Core Value:** Fast, intuitive library browsing and playback on a single personal Plex server with tens of thousands of media items.

## v1.1 Requirements

Requirements for v1.1 Polish & Navigation. Each maps to roadmap phases.

### Crash Safety & Foundation

- [x] **SAFE-01**: BusySpinner SIGSEGV root cause confirmed and resolved (safe loading states across all screens)
- [x] **SAFE-02**: Orphaned files deleted (normalizers.brs, capabilities.brs)
- [x] **SAFE-03**: Utility code cleanup (extract common helpers, remove dead code patterns)

### Bug Fixes

- [x] **FIX-01**: Auto-play next episode fires correctly from both EpisodeScreen and DetailScreen (grandparentRatingKey wiring)
- [x] **FIX-02**: Auto-play countdown can be cancelled by user
- [x] **FIX-03**: Watch state changes propagate to parent screens (poster grids and hub rows)
- [ ] **FIX-04**: Collections menu item navigates to collections browsing screen
- [ ] **FIX-05**: Search results display without occluding search controls and are navigable
- [ ] **FIX-06**: Thumbnail aspect ratio adapts based on image type — detect whether Plex is serving a poster (2:3) or screen grab (16:9) and size the grid item accordingly, rather than hardcoding by library type
- [x] **FIX-07**: Progress bar width uses constant instead of hardcoded 240px
- [ ] **FIX-08**: Subtitle/audio track selection panel must be accessible during playback — trigger with down arrow key (options key intercepted by Roku firmware on Video node; keep built-in trickplay bar)

### TV Show Navigation

- [ ] **NAV-01**: User can view a show's seasons as a poster grid/list screen
- [ ] **NAV-02**: User can select a season to see its episodes in a grid
- [ ] **NAV-03**: Season and episode screens show watched/progress state
- [ ] **NAV-04**: Back button navigates correctly through Show → Seasons → Episodes stack

### Server Switching Removal

- [ ] **SRV-01**: Server switching UI and code removed cleanly from SettingsScreen
- [ ] **SRV-02**: All 4 codepaths referencing server switching patched (no crash on multi-server accounts)

### App Branding

- [ ] **BRAND-01**: App icon and splash screen use a bolder font (Inter Bold or similar)
- [ ] **BRAND-02**: Icon/splash text has gray external stroke visible against dark background
- [ ] **BRAND-03**: Icon and splash screen backgrounds have subtle corner-to-corner black-to-charcoal gradient
- [ ] **BRAND-04**: All icon variants updated (focus FHD 540x405, side FHD, HD variants)

### Documentation & GitHub

- [ ] **DOCS-01**: Full README with user guide (install, configure, use)
- [ ] **DOCS-02**: Developer/architecture documentation (components, patterns, API)
- [ ] **DOCS-03**: .gitignore updated (exclude HAR files, credentials, build artifacts)
- [ ] **DOCS-04**: Repository published to GitHub

## Future Requirements

### Media Types

- **MUSIC-01**: Album/artist browsing with track lists
- **MUSIC-02**: Playback queue and now-playing bar
- **PHOTO-01**: Photo grid with full-screen viewer
- **PHOTO-02**: Slideshow mode
- **LIVETV-01**: EPG guide grid and channel tuning
- **LIVETV-02**: DVR recordings list

### UI Enhancements

- **UI-01**: Library grid/list toggle view
- **UI-02**: Pre-roll detection and playback
- **UI-03**: Artwork caching and performance profiling
- **UI-04**: ASS subtitle support

## Out of Scope

| Feature | Reason |
|---------|--------|
| Channel store submission | Sideload only — personal use |
| Multi-server support | Single personal server; server switching removed in v1.1 |
| Mobile companion app | Roku only |
| Cloud relay playback | Direct server connection only |
| BrighterScript v1.0.0-alpha | Defer until stable release |
| Watch Together | Rarely used feature |
| Maestro MVVM | Deprecated Nov 2023; plain BrightScript is sufficient |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SAFE-01 | Phase 11 | Complete |
| SAFE-02 | Phase 11 | Complete |
| SAFE-03 | Phase 11 | Complete |
| FIX-07 | Phase 11 | Complete |
| FIX-01 | Phase 12 | Complete |
| FIX-02 | Phase 12 | Complete |
| FIX-03 | Phase 12 | Complete |
| FIX-04 | Phase 13 | Pending |
| FIX-05 | Phase 13 | Pending |
| FIX-06 | Phase 13 | Pending |
| NAV-01 | Phase 14 | Pending |
| NAV-02 | Phase 14 | Pending |
| NAV-03 | Phase 14 | Pending |
| NAV-04 | Phase 14 | Pending |
| SRV-01 | Phase 15 | Pending |
| SRV-02 | Phase 15 | Pending |
| BRAND-01 | Phase 16 | Pending |
| BRAND-02 | Phase 16 | Pending |
| BRAND-03 | Phase 16 | Pending |
| BRAND-04 | Phase 16 | Pending |
| DOCS-01 | Phase 17 | Pending |
| DOCS-02 | Phase 17 | Pending |
| DOCS-03 | Phase 17 | Pending |
| DOCS-04 | Phase 17 | Pending |

**Coverage:**
- v1.1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 — traceability complete, all 24 requirements mapped to Phases 11-17*
