# M001: SimPlex v1.1 - Polish & Navigation

**Vision:** A full-featured, personal-use Plex Media Server client for Roku 4K TV, side-loaded as a developer channel.

## Success Criteria


## Slices

- [x] **S01: Infrastructure — completed 2026 03 08** `risk:medium` `depends:[]`
  > BrighterScript toolchain, F5 deploy, constants in m.global, concurrent API task pattern established.
- [x] **S02: Playback Foundation — completed 2026 03 09** `risk:medium` `depends:[S01]`
  > Video playback with direct play and transcode fallback, resume from last position, progress bars, watched/unwatched badges.
- [x] **S03: Hub Rows — completed 2026 03 09** `risk:medium` `depends:[S02]`
  > Continue Watching, Recently Added, and On Deck hub rows on HomeScreen with RowList.
- [x] **S04: Error States — completed 2026 03 10** `risk:medium` `depends:[S03]`
  > Loading spinners, empty states, retry dialogs, and server reconnect handling across all screens.
- [x] **S05: Filter and Sort — completed 2026 03 10** `risk:medium` `depends:[S04]`
  > Library filter/sort by genre, year, unwatched status, and sort order via FilterBar.
- [x] **S06: Audio and Subtitles — completed 2026 03 10** `risk:medium` `depends:[S05]`
  > Audio track selection, subtitle track selection (SRT sidecar + PGS burn-in), and track preference persistence.
- [x] **S07: Intro and Credits Skip — completed 2026 03 10** `risk:medium` `depends:[S06]`
  > Skip Intro and Skip Credits overlay buttons using Plex chapter markers.
- [x] **S08: Auto Play Next Episode — completed 2026 03 10** `risk:medium` `depends:[S07]`
  > Auto-play next episode infrastructure in VideoPlayer (had wiring gap fixed in S12).
- [x] **S09: Collections and Playlists — completed 2026 03 10** `risk:medium` `depends:[S08]`
  > Collections browsing and playlist browsing with sequential playback support.
- [x] **S10: Managed Users — completed 2026 03 10** `risk:medium` `depends:[S09]`
  > Managed user switching with PIN entry, admin token preservation for re-auth.
- [x] **S11: Crash Safety And Foundation** `risk:medium` `depends:[S10]`
  > After this: Confirm BusySpinner SIGSEGV root cause, replace the crashed component with a safe loading indicator, assess VideoPlayer's transcodingSpinner, and delete confirmed orphaned files.
- [x] **S12: Auto Play And Watch State** `risk:medium` `depends:[S11]`
  > After this: Wire auto-play next episode from both entry points (DetailScreen and EpisodeScreen) with a cancellable 30-second countdown, create PostPlayScreen for consistent post-playback navigation, and add season-boundary auto-play.
- [x] **S13: Search, Collections, and Thumbnails — completed 2026 03 23** `risk:medium` `depends:[S12]`
  > Fixed search keyboard collapse/expand with dynamic grid columns, collections auto-select first library, and episode thumbnail fallback for portrait posters.
- [ ] **S14: TV Show Navigation Overhaul** `risk:medium` `depends:[S13]`
  > Grid tap on TV shows goes directly to EpisodeScreen; DetailScreen accessible via options key "Info" action.
- [ ] **S15: Server Switching Removal** `risk:medium` `depends:[S14]`
  > Remove "Switch Server" from SettingsScreen, patch all 4 codepaths, simplify to single-server design.
- [ ] **S16: App Branding** `risk:medium` `depends:[S15]`
  > Bolder Inter Bold font, gray stroke on icon/splash text, gradient backgrounds, all icon variants updated.
- [ ] **S17: Documentation and GitHub** `risk:medium` `depends:[S16]`
  > Full README with user guide, developer/architecture docs, .gitignore cleanup, publish to GitHub.
