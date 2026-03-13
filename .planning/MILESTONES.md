# Milestones

## v1.0 MVP (Shipped: 2026-03-13)

**Phases:** 1-10 (17 plans)
**Timeline:** 30 days (2026-02-09 → 2026-03-10)
**Lines of code:** 11,158 BrightScript + XML
**Git range:** `feat(01-01)` → `feat(10-01)`

**Key accomplishments:**
1. BrighterScript toolchain with F5 deploy, constants caching, concurrent API tasks
2. Resume playback, progress bars, watched/unwatched badges with optimistic updates
3. Hub rows (Continue Watching, Recently Added, On Deck) with three-zone focus model
4. Error handling across all screens: loading spinners, empty states, retry, server reconnect
5. Library filter/sort with bottom sheet (genre, year, unwatched, sort order)
6. Audio/subtitle track selection with PGS transcode pivot and forced subtitle support
7. Intro/credits skip buttons, auto-play next episode with countdown
8. Collections browsing, playlist sequential playback
9. Managed user switching with PIN entry and token management

### Known Gaps

Deferred to v1.1:
- **PLAY-12**: Auto-play next episode — `grandparentRatingKey` never set by callers, countdown never triggers
- **PLAY-13**: Cancel auto-play countdown — unreachable (same root cause as PLAY-12)
- **PLAY-04**: Mark watched — updates DetailScreen but `watchStateChanged` not observed by parent screens
- **PLAY-05**: Mark unwatched — same propagation gap as PLAY-04

**Archives:**
- [v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)
- [v1.0-REQUIREMENTS.md](milestones/v1.0-REQUIREMENTS.md)
- [v1.0-MILESTONE-AUDIT.md](milestones/v1.0-MILESTONE-AUDIT.md)

---

