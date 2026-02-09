# Feature Landscape

**Domain:** Roku Media Player / Plex Client
**Researched:** 2026-02-09
**Confidence:** HIGH

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Library browsing | Core function of media client | LOW | Navigate Movies/TV Shows libraries with grid/list views |
| Poster grid view | Standard visual browsing pattern | LOW | Users expect to see posters in grid layout (6 columns typical for FHD) |
| Basic playback controls | Play/pause/stop are fundamental | LOW | Play, pause, stop, seek |
| Continue Watching / On Deck | Users expect to resume where they left off | MEDIUM | Show in-progress and next-to-watch content prominently |
| Watch state syncing | Plex servers track watch progress | LOW | Mark as watched/unwatched, sync progress with server |
| Direct Play | Avoid transcoding for performance | LOW | Stream original files without re-encoding when possible |
| Subtitle selection | Many users need subtitles | MEDIUM | Select from available subtitle tracks, handle manual/auto modes |
| Audio track selection | Multi-language support expected | MEDIUM | Choose between audio tracks (languages, commentary) |
| Server discovery | Must connect to Plex Media Server | MEDIUM | Auto-discover servers on local network |
| Search functionality | Users need to find specific content | HIGH | Search across libraries with debouncing, display results clearly |
| Item metadata display | Users want to know what they're watching | LOW | Show title, summary, ratings, cast, runtime, genre |
| Keyboard input | Roku remote typing is painful | LOW | Use Roku's on-screen keyboard for search/text entry |
| Resume playback | Pick up where user stopped | LOW | "Resume" button for partially-watched content |
| Recently Added | Discover new content added to server | LOW | Show newest additions to libraries |
| Episode lists for TV | Navigate seasons/episodes | MEDIUM | Hierarchical: Show → Season → Episode with proper ordering |
| Back button navigation | Users expect back to work | LOW | Return to previous screen, maintain screen stack |

## Differentiators

Features that set product apart from official Plex Roku app. Not expected, but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Fast sidebar navigation | Main complaint about official app is slow horizontal tabs | MEDIUM | Left sidebar for quick library switching (like "Plex Classic") |
| Instant library switching | Official app has slow loading between libraries | MEDIUM | Preload/cache library metadata, instant transitions |
| Collections support | Many users organize media into collections | MEDIUM | Browse and display Plex collections (Marvel movies, etc.) |
| Playlist support | Users create custom playlists | MEDIUM | Play user-created playlists |
| Automatic intro skip | Official app requires button press | HIGH | Detect intro markers, skip automatically (user pref) |
| Automatic credits skip | Jump to next episode seamlessly | HIGH | Skip credits, auto-play next episode |
| Chapter markers | Navigate within long videos | MEDIUM | Display and seek to chapter points |
| Jump to time | Power user feature for precise seeking | LOW | Manual time entry (e.g., "jump to 45:30") |
| Persistent focus position | Official app loses your place | LOW | Remember grid position when returning from detail screen |
| Grid customization | User preference for density | LOW | Adjustable poster size or columns |
| Clean, distraction-free UI | Official app criticized as "bloated" | LOW | No ads, no free Plex content, movies/TV only |
| Multiple sort options | Organize library your way | MEDIUM | Sort by title, date added, release year, rating, etc. |
| Multiple filter options | Find specific content | HIGH | Filter by genre, year, rating, unwatched, etc. |
| List view option | Alternative to grid for detail scanning | MEDIUM | List with title + metadata for faster text scanning |
| 10-second skip buttons | Standard video player pattern | LOW | Quick rewind/forward (Roku remote OK/asterisk patterns) |
| Responsive navigation | Official app has input lag | LOW | No delays in UI response to remote input |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Plex's free streaming content | Adds bloat, not core to custom client | Focus only on user's personal media server |
| News/Live TV | Complexity, not user's stated need | Movies & TV Shows only per user requirements |
| Music/Photos libraries | Scope creep, separate use case | Explicitly exclude - video content only |
| Multi-user profiles | Single user specified in requirements | Single account, no profile switching |
| Social features (Watch Together) | Complex, requires real-time sync | Single-player experience only |
| In-app purchases/ads | Keeps app lean and fast | Free, no monetization |
| Settings overload | Too many options slow users down | Opinionated defaults, minimal settings |
| Live transcoding controls | Server-side feature, client shouldn't micromanage | Trust server's automatic decisions |
| Download/sync for offline | Complex storage management on Roku | Streaming-only (typical for Roku apps) |
| Parental controls | Single user, no need | Assume adult user with appropriate content |
| DVR features | Not in user requirements | Focus on on-demand library content |
| News feeds/activity streams | Social bloat | Clean interface focused on content |
| Recommendations engine | Complex, Plex server already provides | Use server's existing recommendations if needed |
| Web browser integration | Scope creep | Dedicated media player only |

## Feature Dependencies

```
Server Discovery & Authentication
    └──requires──> PlexAuthTask (PIN-based OAuth)
                       └──requires──> roUrlTransfer in Task node

Library Browsing
    └──requires──> PlexApiTask
                       └──requires──> Authenticated server connection
                       └──requires──> PosterGrid component

Poster Grid Display
    └──enhances──> Image Caching (PlexImageCacheTask)
    └──requires──> ContentNode tree structure

Item Detail Screen
    └──requires──> Metadata fetching (PlexApiTask)
    └──requires──> Poster grid (user navigates from grid)

Video Playback
    └──requires──> Item metadata (Direct Play URL or transcode params)
    └──requires──> VideoPlayer component
    └──enhances──> Progress reporting (PlexSessionTask)

Continue Watching / On Deck
    └──requires──> Watch state tracking
    └──requires──> PlexApiTask for /library/onDeck endpoint

Search
    └──requires──> PlexSearchTask (with debouncing)
    └──requires──> Keyboard input handling
    └──requires──> Results grid display

Collections
    └──requires──> PlexApiTask for collections endpoint
    └──requires──> Same grid/browsing patterns as libraries

Intro Skip (Automatic)
    └──requires──> Intro markers from server
    └──requires──> Playback position monitoring
    └──conflicts──> Manual intro skip button (choose one approach)

Chapter Navigation
    └──requires──> Chapter metadata from server
    └──requires──> Seek controls in VideoPlayer

Filter/Sort
    └──requires──> PlexApiTask with query params
    └──requires──> UI controls for filter/sort selection
    └──enhances──> Library browsing

Sidebar Navigation
    └──requires──> MainScene screen stack management
    └──conflicts──> Top horizontal tabs (UI layout decision)
```

## MVP Recommendation

### Launch With (v1.0)

Essential features that make PlexClassic minimally viable.

- [x] Server discovery and authentication (PIN-based)
- [x] Library browsing (Movies & TV Shows)
- [x] Poster grid view (6 columns, FHD optimized)
- [x] Sidebar navigation (fast library switching)
- [x] Item detail screen (metadata display)
- [x] Basic video playback (Direct Play)
- [x] Continue Watching / On Deck
- [x] Watch state syncing (mark watched/unwatched)
- [x] Episode lists (Show → Season → Episode)
- [x] Basic seek controls (play/pause/seek/stop)
- [x] Back button navigation (screen stack)
- [x] Resume playback (for in-progress content)
- [x] Recently Added section
- [x] Subtitle track selection
- [x] Audio track selection

### Add After Core Works (v1.1 - v1.5)

Features that enhance usability but aren't blockers for initial release.

- [ ] Search functionality — Once browsing is solid, add search with debouncing
- [ ] Collections support — If users request it frequently
- [ ] Playlists support — Lower priority than collections
- [ ] Sort options (by title, date, year, rating) — Adds flexibility
- [ ] Filter options (genre, year, unwatched) — Power user feature
- [ ] List view option — Alternative to grid for some users
- [ ] Jump to time — Power user feature, not critical path
- [ ] 10-second skip buttons — Nice UX improvement
- [ ] Grid customization — User preference, not essential

### Future Consideration (v2.0+)

Features requiring significant complexity, defer until product-market fit proven.

- [ ] Automatic intro skip — HIGH complexity, requires intro marker detection + auto-seek logic
- [ ] Automatic credits skip — Same complexity as intro skip, plus next episode queuing
- [ ] Chapter markers — Depends on server providing chapter metadata reliably
- [ ] Advanced filters (actor, director, studio) — Complex UI, niche use case
- [ ] Custom themes/skins — UI polish, not functional value early on
- [ ] Settings screen — Keep minimal until more user preferences accumulate

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Poster grid view | HIGH | LOW | P1 |
| Sidebar navigation | HIGH | MEDIUM | P1 |
| Basic playback | HIGH | LOW | P1 |
| Continue Watching | HIGH | MEDIUM | P1 |
| Server discovery | HIGH | MEDIUM | P1 |
| Watch state sync | HIGH | LOW | P1 |
| Episode lists | HIGH | MEDIUM | P1 |
| Item metadata | HIGH | LOW | P1 |
| Resume playback | HIGH | LOW | P1 |
| Subtitle/audio tracks | HIGH | MEDIUM | P1 |
| Search | HIGH | HIGH | P2 |
| Collections | MEDIUM | MEDIUM | P2 |
| Playlists | MEDIUM | MEDIUM | P2 |
| Sort options | MEDIUM | MEDIUM | P2 |
| Filter options | MEDIUM | HIGH | P2 |
| List view | MEDIUM | MEDIUM | P2 |
| Jump to time | MEDIUM | LOW | P2 |
| 10-second skip | MEDIUM | LOW | P2 |
| Intro skip (auto) | HIGH | HIGH | P3 |
| Credits skip (auto) | HIGH | HIGH | P3 |
| Chapter markers | MEDIUM | MEDIUM | P3 |
| Grid customization | LOW | LOW | P3 |

**Priority key:**
- **P1**: Must have for v1.0 launch — Core functionality that makes app minimally viable
- **P2**: Should have for v1.x releases — Enhances usability, add when P1 stable
- **P3**: Nice to have for v2.0+ — High complexity or niche value, defer until proven

## Competitor Feature Analysis

| Feature | Official Plex Roku | PlexClassic Target | Our Approach |
|---------|-------------------|-------------------|--------------|
| Navigation | Horizontal tabs (slow, criticized) | Sidebar (fast, loved) | **Sidebar** - addresses #1 complaint |
| Library loading | Slow transitions | Instant | **Instant** - cache/preload metadata |
| Intro skip | Manual button press | N/A | **Automatic** (v2.0) - competitive advantage |
| Collections | Supported | Unknown | **Support** (v1.x) - table stakes |
| Focus persistence | Lost on back | Unknown | **Remember position** - polish detail |
| UI bloat | Ads, free content, complex | Clean, simple | **Clean** - movies/TV only, no ads |
| Search | Supported | Unknown | **Support with debouncing** (v1.x) |
| Playlists | Supported | Unknown | **Support** (v1.x) - common use case |
| Chapter navigation | Limited | N/A | **Full support** (v2.0) - power user feature |
| Grid customization | Fixed | Unknown | **Adjustable** (v2.0+) - user preference |

## User Pain Points Addressed

Based on research into official Plex Roku app complaints:

1. **"Navigation is painfully slow"** → Fast sidebar navigation with instant library switching
2. **"Horizontal tabs take forever"** → Vertical sidebar, fewer clicks to switch context
3. **"UI is clunky and laggy"** → Responsive navigation, no input lag
4. **"App feels bloated"** → Movies/TV only, no ads, no free Plex content hub
5. **"Lost my place in the grid when going back"** → Persistent focus position
6. **"Wish intro skip was automatic"** → Automatic intro/credits skip (v2.0 feature)
7. **"Can't find my collections"** → Collections support (v1.x)
8. **"Miss the old Plex Classic UI"** → Sidebar navigation inspired by Classic

## Sources

### Official Plex Documentation (HIGH confidence)
- [Navigating the Big Screen Apps | Plex Support](https://support.plex.tv/articles/navigating-the-big-screen-apps/)
- [Using the Library View | Plex Support](https://support.plex.tv/articles/200392126-using-the-library-view/)
- [Settings: Plex for Roku | Plex Support](https://support.plex.tv/articles/204275243-settings-plex-for-roku/)
- [Mark as Watched or Unwatched | Plex Support](https://support.plex.tv/articles/201018487-mark-as-watched-or-unwatched/)
- [Account Audio/Subtitle Language Settings | Plex Support](https://support.plex.tv/articles/204985278-account-audio-subtitle-language-settings/)
- [Direct Play, Direct Stream, Transcoding Overview | Plex Support](https://support.plex.tv/articles/200430303-streaming-overview/)

### User Feedback & Industry Analysis (MEDIUM confidence)
- [New UI is an awful experience - Plex Forum](https://forums.plex.tv/t/new-ui-is-an-awful-experience/931048)
- [Plex Just Ruined Their Roku App - Plex Forum](https://forums.plex.tv/t/plex-just-ruined-their-roku-app/931058)
- [Plex is still trying to fix its Roku app - How-To Geek](https://www.howtogeek.com/plexs-roku-app-is-getting-yet-another-redesign/)
- ["Hot Garbage": New Plex for Roku update getting slammed - Piunikaweb](https://piunikaweb.com/2025/09/17/plex-roku-update-backlash/)
- [Vote to roll back to Plex Classic! - Plex Forum](https://forums.plex.tv/t/vote-to-roll-back-to-plex-classic/931767)
- [This new Plex client has a sleek design - How-To Geek](https://www.howtogeek.com/this-new-plex-client-with-a-sleek-design-just-got-an-upgrade/)
- [List vs. Grid View: When to Use Which on Mobile - UX Movement](https://uxmovement.com/mobile/list-vs-grid-view-when-to-use-which-on-mobile/)

### Third-Party Clients & Alternatives (MEDIUM confidence)
- [The best Plex alternative in 2025 is Jellyfin - Android Authority](https://www.androidauthority.com/jellyfin-vs-plex-home-server-3360937/)
- [Best Plex alternatives in 2024 - XDA Developers](https://www.xda-developers.com/best-plex-alternatives/)
- [Playlists Versus Collections in Plex - Plexopedia](https://www.plexopedia.com/plex-media-server/general/playlists-versus-collections/)

### Roku Platform Best Practices (MEDIUM confidence)
- [How to use Roku Media Player - Roku Support](https://support.roku.com/article/208754908)
- [New Roku Features 2026 - Oxagile](https://www.oxagile.com/article/roku-features/)
- [Roku app essential features - AndroidPolice](https://www.androidpolice.com/lesser-known-roku-mobile-app-features/)

### Video Player Standards (MEDIUM confidence)
- [Enable skip intro and outro in the player - Kaltura](https://knowledge.kaltura.com/help/enable-skip-intro-and-outro-in-the-player)
- [Skip Intro/Outro Credits - VideoLAN addons](https://addons.videolan.org/p/1185871/)
- [intro-skipper Wiki - GitHub](https://github.com/intro-skipper/intro-skipper/wiki)

---

*Feature research for: PlexClassic (Roku Plex Client Replacement)*
*Researched: 2026-02-09*
*Confidence: HIGH (Official Plex docs + extensive user feedback + platform standards)*
