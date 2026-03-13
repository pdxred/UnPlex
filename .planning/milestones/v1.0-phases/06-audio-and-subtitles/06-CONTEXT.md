# Phase 6: Audio and Subtitles - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can select audio and subtitle tracks during playback. SRT/text subtitles are delivered as sidecars without transcoding. PGS/bitmap subtitles automatically trigger transcode with burn-in. This phase does NOT include playback transport controls, skip buttons, or auto-play — those are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Overlay design
- Side panel that slides in from the right edge; playback video remains visible behind it
- Playback pauses while the panel is open
- Two trigger methods: Options (*) button opens panel directly, AND an icon in the playback HUD
- Combined panel with Audio section on top, Subtitles section below (single panel, not tabs)

### Track display
- Audio tracks show: language + codec/channels (e.g. "English (AAC 5.1)")
- Subtitle tracks show: language + type (e.g. "English (SRT)" or "English (PGS)")
- Active/selected track gets a checkmark icon AND accent color highlight (Plex gold)
- Subtitles always include an "Off" option in the list

### Selection behavior
- Track changes apply immediately on select — no confirm button
- Track choices persist across episodes via Plex server API (PUT to set preferred tracks)
- Forced subtitles auto-enable when audio language doesn't match user's language (e.g. Japanese audio → English forced subs appear automatically)

### PGS/transcode handling
- When selecting a PGS subtitle, show a brief spinner with "Switching subtitles..." while transcode session starts
- Type label "(PGS)" vs "(SRT)" in the track list is sufficient distinction — no warning icons
- On transcode failure: show error toast "Subtitle unavailable" and revert to previous track
- Playback position must be preserved when switching from direct play to transcode — record offset, start transcode at same position

### Claude's Discretion
- Panel animation speed and easing
- Exact panel width and typography
- HUD icon design and placement
- How to handle tracks with no language metadata
- Spinner/loading indicator style

</decisions>

<specifics>
## Specific Ideas

- Panel should feel like the official Plex side panel — slides in from right, clean list of tracks
- "Switching subtitles..." spinner keeps users informed during the transcode pivot, rather than a mysterious rebuffer

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-audio-and-subtitles*
*Context gathered: 2026-03-10*
