# Roadmap: SimPlex

## Milestones

- ✅ **v1.0 MVP** — Phases 1-10 (shipped 2026-03-13)
- 🚧 **v1.1 Polish & Navigation** — Phases 11-17 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-10) — SHIPPED 2026-03-13</summary>

- [x] Phase 1: Infrastructure (2/2 plans) — completed 2026-03-08
- [x] Phase 2: Playback Foundation (2/2 plans) — completed 2026-03-09
- [x] Phase 3: Hub Rows (2/2 plans) — completed 2026-03-09
- [x] Phase 4: Error States (2/2 plans) — completed 2026-03-10
- [x] Phase 5: Filter and Sort (2/2 plans) — completed 2026-03-10
- [x] Phase 6: Audio and Subtitles (2/2 plans) — completed 2026-03-10
- [x] Phase 7: Intro and Credits Skip (1/1 plan) — completed 2026-03-10
- [x] Phase 8: Auto-play Next Episode (1/1 plan) — completed 2026-03-10
- [x] Phase 9: Collections and Playlists (2/2 plans) — completed 2026-03-10
- [x] Phase 10: Managed Users (1/1 plan) — completed 2026-03-10

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

### 🚧 v1.1 Polish & Navigation (In Progress)

**Milestone Goal:** Fix v1.0 bugs, overhaul TV show navigation, clean up codebase, refresh branding, and publish to GitHub.

- [ ] **Phase 11: Crash Safety and Foundation** - Confirm BusySpinner root cause, delete orphaned files, extract shared utilities, apply 1-line progress bar fix
- [ ] **Phase 12: Auto-play and Watch State** - Wire auto-play end-to-end from both entry points and propagate watch state to all parent screens
- [ ] **Phase 13: Search, Collections, and Thumbnails** - Fix search layout, collections navigation, and thumbnail aspect ratios
- [ ] **Phase 14: TV Show Navigation Overhaul** - Route TV show taps directly to EpisodeScreen with full season/episode grid and correct back stack
- [ ] **Phase 15: Server Switching Removal** - Remove server switching UI and patch all four call sites cleanly
- [ ] **Phase 16: App Branding** - Refresh icon, splash, and typography with bolder font and gradient backgrounds
- [ ] **Phase 17: Documentation and GitHub** - Write user and developer documentation, publish repository to GitHub

## Phase Details

### Phase 11: Crash Safety and Foundation
**Goal**: Establish a crash-safe, clean codebase baseline before any screen changes
**Depends on**: Phase 10 (v1.0 complete)
**Requirements**: SAFE-01, SAFE-02, SAFE-03, FIX-07
**Success Criteria** (what must be TRUE):
  1. BusySpinner SIGSEGV root cause is confirmed and documented — the crash trigger is known and all future loading states use the safe pattern
  2. The app compiles and sideloads cleanly with normalizers.brs and capabilities.brs deleted
  3. GetRatingKeyStr() exists as a single shared helper in utils.brs — no inline duplicate blocks remain
  4. Progress bar width in PosterGridItem references POSTER_WIDTH constant, not a hardcoded 240px value
**Plans**: TBD

Plans:
- [ ] 11-01: Confirm BusySpinner crash root cause and delete orphaned files
- [ ] 11-02: Extract shared utilities and apply PosterGridItem progress bar fix

### Phase 12: Auto-play and Watch State
**Goal**: Auto-play next episode fires correctly from every entry point and watch state changes reach all visible screens
**Depends on**: Phase 11
**Requirements**: FIX-01, FIX-02, FIX-03
**Success Criteria** (what must be TRUE):
  1. Playing an episode from DetailScreen and reaching the auto-play threshold triggers the countdown to the next episode
  2. Playing an episode from EpisodeScreen and reaching the threshold also triggers the countdown
  3. User can press any remote button during the countdown to cancel and stay on the post-play screen
  4. Marking an episode watched from EpisodeScreen updates the badge on the poster in the library grid and in the Continue Watching hub row
**Plans**: TBD

Plans:
- [ ] 12-01: Wire grandparentRatingKey in DetailScreen and fix auto-play countdown
- [ ] 12-02: Add hub row ContentNode walker for watch state propagation

### Phase 13: Search, Collections, and Thumbnails
**Goal**: Search results are legible and navigable, collections are reachable from the sidebar, and thumbnails use correct aspect ratios
**Depends on**: Phase 11
**Requirements**: FIX-04, FIX-05, FIX-06
**Success Criteria** (what must be TRUE):
  1. Tapping Collections in the sidebar opens the collections browsing screen
  2. Search results appear below the search bar without overlapping the keyboard or search controls
  3. Selecting a search result and pressing back returns focus to the search grid
  4. Episode results in search show portrait parent thumbnails (not distorted landscape grabs); movie results show portrait posters
**Plans**: TBD

Plans:
- [ ] 13-01: Fix collections routing and search layout
- [ ] 13-02: Fix episode thumbnail aspect ratio in search results

### Phase 14: TV Show Navigation Overhaul
**Goal**: Tapping a TV show goes directly to the episode/season screen with no unnecessary Detail Screen hop, and the back stack is clean throughout
**Depends on**: Phase 12
**Requirements**: NAV-01, NAV-02, NAV-03, NAV-04
**Success Criteria** (what must be TRUE):
  1. Tapping a TV show in the library grid opens the season/episode screen directly — no Detail Screen intermediary
  2. User can select a season from the season list and see that season's episodes in a grid
  3. Watched badges and progress bars are visible on season and episode items
  4. Pressing back from the episode grid returns to the season list; pressing back from the season list returns to the library grid
  5. Show-level metadata (Detail Screen) is still reachable via the options key from within the season/episode screen
**Plans**: TBD

Plans:
- [ ] 14-01: Route TV show taps to EpisodeScreen and add options-key Info action
- [ ] 14-02: Implement season poster grid and episode grid with watched/progress state

### Phase 15: Server Switching Removal
**Goal**: Server switching is fully removed — no UI, no dead code, no crash risk on multi-server accounts
**Depends on**: Phase 11
**Requirements**: SRV-01, SRV-02
**Success Criteria** (what must be TRUE):
  1. The Settings screen has no Switch Server option
  2. The app does not crash on a plex.tv account that has multiple servers
  3. No compiler warnings or reference errors from removed server switching code
**Plans**: TBD

Plans:
- [ ] 15-01: Patch all four server switching call sites and remove SettingsScreen server switching UI

### Phase 16: App Branding
**Goal**: The app icon and splash screen are visually polished with bolder typography and gradient backgrounds across all Roku icon variants
**Depends on**: Phase 11
**Requirements**: BRAND-01, BRAND-02, BRAND-03, BRAND-04
**Success Criteria** (what must be TRUE):
  1. The app icon in the Roku home screen channel row displays bold, legible text with a gray stroke visible against the dark background
  2. The splash screen shown at launch uses the same bold typography and gradient background
  3. All four required icon variants (focus FHD, side FHD, focus HD, side HD) are present with correct dimensions and load without errors
**Plans**: TBD

Plans:
- [ ] 16-01: Create branding assets (InterBold font, updated icon and splash PNGs) and wire into bsconfig.json

### Phase 17: Documentation and GitHub
**Goal**: The repository has complete user and developer documentation and is safe to publish publicly
**Depends on**: Phase 16
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):
  1. README covers installation (sideload steps), configuration (server URL, PIN auth), and feature overview — a new user can get started without asking
  2. Developer documentation describes the component architecture, Task node pattern, and how to run and deploy the channel locally
  3. .gitignore excludes HAR files, credentials, and build artifacts — no sensitive data is committed
  4. The GitHub repository is publicly accessible with the README rendered correctly on the landing page
**Plans**: TBD

Plans:
- [ ] 17-01: Write README and developer documentation
- [ ] 17-02: Audit .gitignore, verify no secrets in history, publish to GitHub

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Infrastructure | v1.0 | 2/2 | Complete | 2026-03-08 |
| 2. Playback Foundation | v1.0 | 2/2 | Complete | 2026-03-09 |
| 3. Hub Rows | v1.0 | 2/2 | Complete | 2026-03-09 |
| 4. Error States | v1.0 | 2/2 | Complete | 2026-03-10 |
| 5. Filter and Sort | v1.0 | 2/2 | Complete | 2026-03-10 |
| 6. Audio and Subtitles | v1.0 | 2/2 | Complete | 2026-03-10 |
| 7. Intro and Credits Skip | v1.0 | 1/1 | Complete | 2026-03-10 |
| 8. Auto-play Next Episode | v1.0 | 1/1 | Complete | 2026-03-10 |
| 9. Collections and Playlists | v1.0 | 2/2 | Complete | 2026-03-10 |
| 10. Managed Users | v1.0 | 1/1 | Complete | 2026-03-10 |
| 11. Crash Safety and Foundation | v1.1 | 0/2 | Not started | - |
| 12. Auto-play and Watch State | v1.1 | 0/2 | Not started | - |
| 13. Search, Collections, and Thumbnails | v1.1 | 0/2 | Not started | - |
| 14. TV Show Navigation Overhaul | v1.1 | 0/2 | Not started | - |
| 15. Server Switching Removal | v1.1 | 0/1 | Not started | - |
| 16. App Branding | v1.1 | 0/1 | Not started | - |
| 17. Documentation and GitHub | v1.1 | 0/2 | Not started | - |
