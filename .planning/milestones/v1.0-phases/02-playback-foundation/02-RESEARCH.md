# Phase 2: Playback Foundation - Research

**Researched:** 2026-03-08
**Domain:** Roku SceneGraph UI overlays, Plex playback/watch-state APIs, BrightScript rendering
**Confidence:** HIGH

## Summary

Phase 2 transforms the existing skeleton playback and watch-state code into a polished experience. The codebase already has: a `VideoPlayer` widget with progress reporting via `PlexSessionTask`, a `DetailScreen` with play/resume buttons and mark watched/unwatched actions, `PosterGridItem` with a basic dot indicator, and `EpisodeItem` with watched state. What is missing: progress bar overlays, triangle corner badges (replacing dots), resume prompt dialogs from grids, options-key context menus, "X min remaining" on detail screen, and live badge propagation after state changes.

The primary technical challenges are: (1) rendering a triangle overlay in SceneGraph without custom draw primitives (requires a pre-rendered PNG asset), (2) propagating watched-state changes back to grid items after scrobble/unscrobble calls, and (3) intercepting the `options` key on grid screens for a context menu without conflicting with Video node's built-in options overlay.

**Primary recommendation:** Use a small PNG triangle asset for the unwatched badge (SceneGraph has no polygon rendering), build progress bars from two stacked `Rectangle` nodes, and implement a lightweight custom dialog component for the resume prompt and options context menu.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Progress bars: Bottom edge overlay on posters, gold accent fill over semi-transparent track, always visible regardless of focus, below 5% = no bar, show bar up to 100% (never auto-mark watched at 95%), appears on BOTH poster grid items AND episode list items, detail screen shows "X min remaining" text alongside a progress bar
- Watched badges: Corner triangle overlay style (like official Plex app), NOT a dot. Uses accent/theme color. Watched = no indicator (clean poster). TV show posters show triangle with unwatched episode count. Movies/individual episodes = triangle only, no count. If progress bar is shown, hide triangle.
- Resume behavior: From grids/episode list = prompt dialog ("Resume from 32:15" / "Start from beginning"). From detail screen = separate visible buttons (no dialog). Progress reporting frequency at Claude's discretion. Crash recovery at Claude's discretion.
- Mark watched/unwatched: BOTH visible button on detail screen AND options (*) remote button context menu. Options menu available on poster grids too. TV show scope is context-aware (show=whole show, season=whole season, episode=that episode). UI update timing at Claude's discretion.
- All accent-colored elements must reference a centralized accent color constant for future theme support.

### Claude's Discretion
- Progress bar exact placement (bottom edge overlay recommended)
- Progress bar thickness
- Detail screen progress bar sizing
- Progress reporting interval to PMS
- Crash recovery strategy (periodic + seek saves)
- Optimistic vs confirmed UI updates for mark watched/unwatched
- Context menu visual design

### Deferred Ideas (OUT OF SCOPE)
- Color theme picker (8 alternate accent colors beyond gold)
- Dark/light mode toggle
- Settings screen
- Sidebar pinning and reordering
- Background image priority
- Minimize clicks philosophy across all screens
</user_constraints>

## Standard Stack

### Core (Already in Project)
| Component | Purpose | Status |
|-----------|---------|--------|
| `VideoPlayer` widget | Playback with direct play / transcode | Exists - needs resume seek fix |
| `PlexSessionTask` | Timeline progress reporting to PMS | Exists - works |
| `PlexApiTask` | General API calls (scrobble/unscrobble) | Exists - works |
| `DetailScreen` | Item detail with play/resume/mark buttons | Exists - needs enhancement |
| `PosterGridItem` | Grid poster rendering | Exists - needs progress bar + triangle badge |
| `EpisodeItem` | Episode list item rendering | Exists - needs progress bar + triangle badge |
| `constants.brs` | `GetConstants()` cached in `m.global.constants` | Exists - needs theme-aware accent constant |

### New Components Needed
| Component | Purpose | Pattern |
|-----------|---------|---------|
| Triangle PNG asset | Unwatched corner badge (SceneGraph has no polygon primitives) | `Poster` node loading `pkg:/images/badge-unwatched.png` |
| Resume Dialog | "Resume from X" / "Start from beginning" prompt | `StandardMessageDialog` with 2 buttons |
| Options Context Menu | Mark watched/unwatched from grid via `*` key | Custom `Group` component (floating menu) |

### No External Libraries Needed
This phase uses only built-in Roku SceneGraph nodes and Plex REST API endpoints. No third-party BrightScript libraries are required.

## Architecture Patterns

### Pattern 1: Progress Bar as Stacked Rectangles
**What:** Two `Rectangle` nodes overlaid - a dim background track and a colored fill bar
**When to use:** On every poster grid item and episode list item that has `viewOffset > 0`
**Why:** SceneGraph `Rectangle` is the cheapest renderable node. No images, no custom rendering.

```xml
<!-- Inside PosterGridItem, positioned at bottom of poster -->
<Rectangle
    id="progressTrack"
    translation="[0, 352]"
    width="240"
    height="8"
    color="0xFFFFFF33"
    visible="false"
/>
<Rectangle
    id="progressFill"
    translation="[0, 352]"
    width="0"
    height="8"
    color="0xE5A00DFF"
    visible="false"
/>
```

```brightscript
' In BrightScript, calculate fill width
sub updateProgressBar(viewOffset as Integer, duration as Integer)
    if duration <= 0 or viewOffset <= 0 then
        m.progressTrack.visible = false
        m.progressFill.visible = false
        return
    end if

    progress = viewOffset / duration
    if progress < 0.05 then
        ' Below 5% threshold - treat as not started
        m.progressTrack.visible = false
        m.progressFill.visible = false
        return
    end if

    m.progressTrack.visible = true
    m.progressFill.visible = true
    m.progressFill.width = Int(240 * progress)  ' 240 = poster width
end sub
```

**Recommended dimensions:**
- Poster grid items (240x360): bar height 6px, positioned at y=354 (bottom edge overlay, slightly inset)
- Episode thumbnails (213x120): bar height 4px, positioned at y=116
- Detail screen: bar height 8px, width proportional to metadata area

### Pattern 2: Triangle Badge via PNG Asset
**What:** A pre-rendered PNG triangle image loaded as a `Poster` node child, positioned in top-right corner
**When to use:** On unwatched items that do NOT have a progress bar showing
**Why:** Roku SceneGraph has no polygon/path rendering. The only way to draw a triangle is with a PNG image asset.

```xml
<!-- Corner triangle badge (top-right) -->
<Poster
    id="unwatchedBadge"
    translation="[200, 0]"
    width="40"
    height="40"
    uri="pkg:/images/badge-unwatched.png"
    visible="false"
/>
<!-- Episode count label centered on triangle -->
<Label
    id="unwatchedCount"
    translation="[218, 4]"
    font="font:SmallestSystemFont"
    color="0xFFFFFFFF"
    visible="false"
/>
```

**Asset requirements:**
- `badge-unwatched.png`: Right-angle triangle, 40x40px, filled with the accent gold color (`#E5A00D`). Triangle occupies top-right corner (hypotenuse goes from top-left to bottom-right). Include alpha transparency for the non-triangle area.
- At runtime, the badge color cannot be dynamically changed (PNG is baked). For future theme support, either: (a) ship multiple colored badge PNGs and swap `uri`, or (b) use `blendColor` on the Poster node if the source PNG is white.

**Recommended approach for theme support:** Ship a WHITE triangle PNG and use `Poster.blendColor` set to `m.global.constants.ACCENT`. This way the badge color is fully dynamic and tied to the accent constant.

```brightscript
m.unwatchedBadge.blendColor = m.global.constants.ACCENT
```

### Pattern 3: Resume Prompt Dialog
**What:** A `StandardMessageDialog` shown when user selects a partially-watched item from a grid or episode list
**When to use:** Item has `viewOffset > 0` AND selection originated from grid/episode list (not detail screen buttons)

```brightscript
sub showResumeDialog(item as Object)
    dialog = CreateObject("roSGNode", "StandardMessageDialog")
    dialog.title = item.title
    resumeTime = FormatTime(item.viewOffset)
    dialog.message = ["Resume from " + resumeTime + "?"]
    dialog.buttons = ["Resume from " + resumeTime, "Start from Beginning"]
    dialog.observeField("buttonSelected", "onResumeDialogButton")
    m.top.getScene().dialog = dialog
    m.pendingPlayItem = item
end sub

sub onResumeDialogButton(event as Object)
    index = event.getData()
    m.top.getScene().dialog.close = true
    if index = 0
        ' Resume
        startPlayback(m.pendingPlayItem, m.pendingPlayItem.viewOffset)
    else
        ' Start from beginning
        startPlayback(m.pendingPlayItem, 0)
    end if
end sub
```

### Pattern 4: Options Key Context Menu
**What:** A custom floating menu component triggered by the `options` ("*") remote key
**When to use:** When a poster grid item or episode list item is focused
**Why:** The built-in `StandardMessageDialog` works but feels heavy for a quick action. A lightweight custom panel is more appropriate. However, `StandardMessageDialog` is acceptable as an MVP approach.

**Key concern:** The `options` key is intercepted by the `Video` node's built-in trickplay overlay when a Video node has focus. This is NOT a problem for this phase because the context menu triggers from grid/list screens, not during playback.

```brightscript
' In PosterGrid or HomeScreen's onKeyEvent:
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "options"
        showContextMenu()
        return true
    end if

    return false
end function
```

**Context menu options vary by item type:**
- Movie: "Mark as Watched" / "Mark as Unwatched"
- TV Show: "Mark Show as Watched" / "Mark Show as Unwatched"
- Season: "Mark Season as Watched" / "Mark Season as Unwatched"
- Episode: "Mark as Watched" / "Mark as Unwatched"

### Pattern 5: Optimistic UI Updates
**What:** Update the badge/progress bar immediately on user action, then fire the API call in the background
**When to use:** After mark watched/unwatched actions
**Why:** Waiting for the API round-trip creates a sluggish feel. The Plex scrobble/unscrobble endpoints rarely fail.

**Recommended approach:** Optimistic update. Change the visual state immediately, fire the task, and only revert on error (which should be rare). This aligns with the user's "less clicks, fast" philosophy.

```brightscript
sub markItemWatched(item as Object)
    ' Optimistic: update UI immediately
    item.viewCount = 1
    item.viewOffset = 0
    updateBadge(item)
    updateProgressBar(0, item.duration)

    ' Fire API call
    task = CreateObject("roSGNode", "PlexApiTask")
    task.endpoint = "/:/scrobble"
    task.params = {
        "identifier": "com.plexapp.plugins.library"
        "key": item.ratingKey
    }
    task.control = "run"
end sub
```

### Anti-Patterns to Avoid
- **Re-fetching entire library after scrobble:** Do NOT reload the grid content after marking an item watched. Update the specific ContentNode in-place and let the MarkupGrid re-render just that item.
- **Creating PlexSessionTask per report:** The VideoPlayer already creates one `PlexSessionTask` at init. Do NOT create a new task instance for every progress report -- the existing pattern of reusing `m.sessionTask` and setting `control = "run"` is correct (per Phase 1 create-per-request pattern, a new task instance per report is actually fine and avoids state collision).
- **Blocking dialog on detail screen for resume:** The CONTEXT.md explicitly says detail screen uses separate buttons, NOT a dialog. Only grid/episode-list selections get the resume dialog.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Triangle shape rendering | Custom pixel-by-pixel drawing | White PNG + `blendColor` on Poster node | SceneGraph has no polygon primitives |
| Dialog framework | Custom dialog from scratch | `StandardMessageDialog` | Built-in, handles focus, remote dismiss, consistent UI |
| Progress reporting timer | Manual `roDateTime` polling | `Timer` node with `repeat=true` | Already implemented in VideoPlayer, reliable |
| Time formatting | Custom format function | Existing `FormatTime()` in `utils.brs` | Already exists and handles hours/minutes/seconds |

## Common Pitfalls

### Pitfall 1: Video Node Seek Units
**What goes wrong:** The `Video.seek` field expects seconds, but `viewOffset` from Plex API is in milliseconds. The existing code has this partially handled but inconsistently.
**Why it happens:** Plex API returns all time values in milliseconds. Roku Video node uses seconds for seek.
**How to avoid:** Always divide viewOffset by 1000 before assigning to `m.video.seek`. The existing `VideoPlayer.brs` line 201 does `m.video.seek = m.top.startOffset / 1000` which is correct.
**Warning signs:** Video starts from wrong position, or seeks to absurdly long position.

### Pitfall 2: ContentNode Field Updates Not Triggering Re-render
**What goes wrong:** Changing a custom field on a ContentNode child does not automatically trigger the MarkupGrid/MarkupList item component to re-render.
**Why it happens:** MarkupGrid only calls `onItemContentChange` when the `itemContent` field on the item component is SET, not when sub-fields of the content node change.
**How to avoid:** After modifying a content node's fields (e.g., after marking watched), either: (a) force a re-render by re-assigning the content tree, or (b) use `content.update()` if available, or (c) for optimistic updates, directly manipulate the item component's visual nodes if you have a reference.
**Warning signs:** Badge/progress bar doesn't visually update after API call succeeds.

### Pitfall 3: Options Key Intercepted by Video Node
**What goes wrong:** Pressing `*` during video playback triggers the Video node's built-in options overlay instead of your custom handler.
**Why it happens:** The Roku firmware intercepts `options` key events when a Video node has focus, before `onKeyEvent` fires.
**How to avoid:** For this phase, the options context menu only applies to grid/list screens (not during playback), so this is not a problem. Do NOT try to override the `options` key during video playback.
**Warning signs:** Context menu appearing during playback instead of trickplay controls.

### Pitfall 4: Scrobble/Unscrobble Key Parameter
**What goes wrong:** Using the wrong key format for the scrobble endpoint.
**Why it happens:** The Plex API `key` parameter for `/:/scrobble` expects the `ratingKey` integer (not the full `/library/metadata/{id}` path). The existing code uses `getRatingKeyString()` which is correct.
**How to avoid:** Always pass just the ratingKey number (as string), not the full metadata path. For shows/seasons, pass the show's or season's ratingKey to mark all children.
**Warning signs:** 400/404 errors on scrobble calls, or only one episode getting marked instead of entire season.

### Pitfall 5: Progress Bar Z-Order in PosterGridItem
**What goes wrong:** Progress bar rectangles render behind the poster image instead of on top.
**Why it happens:** SceneGraph renders children in XML declaration order (last declared = on top). If the progress bar `Rectangle` is declared before the `Poster`, it renders underneath.
**How to avoid:** Declare progress bar and badge nodes AFTER the `Poster` node in the XML children list.
**Warning signs:** Progress bar invisible even when viewOffset > 0 and visible=true.

### Pitfall 6: Dialog Focus Trap
**What goes wrong:** After dismissing a dialog, focus returns to the scene root instead of the grid/list item that was focused.
**Why it happens:** `StandardMessageDialog` manages its own focus. When closed, focus may not automatically return to the previous element.
**How to avoid:** After closing a dialog (`dialog.close = true`), explicitly restore focus to the grid/list that triggered it. Store a reference before showing the dialog.
**Warning signs:** Remote keys stop working after dialog dismiss, or focus jumps to wrong screen element.

## Code Examples

### Existing Plex API Patterns (from codebase)

**Scrobble (mark watched) - already in DetailScreen.brs:**
```brightscript
task = CreateObject("roSGNode", "PlexApiTask")
task.endpoint = "/:/scrobble"
task.params = {
    "identifier": "com.plexapp.plugins.library"
    "key": getRatingKeyString(m.itemData.ratingKey)
}
task.control = "run"
```

**Unscrobble (mark unwatched) - already in DetailScreen.brs:**
```brightscript
task = CreateObject("roSGNode", "PlexApiTask")
task.endpoint = "/:/unscrobble"
task.params = {
    "identifier": "com.plexapp.plugins.library"
    "key": getRatingKeyString(m.itemData.ratingKey)
}
task.control = "run"
```

**Progress reporting (timeline) - already in PlexSessionTask.brs:**
```brightscript
requestUrl = serverUri + "/:/timeline"
    + "?ratingKey=" + m.top.ratingKey
    + "&key=" + UrlEncode(m.top.mediaKey)
    + "&state=" + m.top.state  ' "playing", "paused", "stopped"
    + "&time=" + m.top.time.ToStr()  ' milliseconds
    + "&duration=" + m.top.duration.ToStr()
```

### Theme-Aware Accent Color Pattern

All new UI elements must reference the accent constant, not hardcode gold:

```brightscript
' In component init or content change handler:
c = m.global.constants
m.progressFill.color = c.ACCENT
m.unwatchedBadge.blendColor = c.ACCENT
m.focusRing.color = c.FOCUS_RING  ' Already same as ACCENT
```

### Remaining Time Calculation for Detail Screen

```brightscript
function getRemainingTimeText(viewOffset as Integer, duration as Integer) as String
    if viewOffset <= 0 or duration <= 0 then return ""
    remainingMs = duration - viewOffset
    if remainingMs <= 0 then return ""
    remainingMin = remainingMs \ 60000
    if remainingMin < 1 then return "Less than 1 min remaining"
    return remainingMin.ToStr() + " min remaining"
end function
```

## State of the Art

| Old Approach (current code) | New Approach (this phase) | Impact |
|------------------------------|--------------------------|--------|
| Dot rectangle badge for unwatched | Triangle PNG with blendColor | Matches Plex official style, theme-ready |
| No progress bar on posters | Dual-rectangle progress overlay | Users see watch progress at a glance |
| Resume only from detail buttons | Resume dialog from grid + detail buttons | Fewer clicks to resume |
| No options key handling | Context menu on `*` key from grids | Quick mark watched without entering detail |
| Post-action full metadata reload | Optimistic in-place ContentNode update | Instant visual feedback |

**Note on existing code quality:** The existing `DetailScreen.brs` already has correct scrobble/unscrobble and play/resume logic. The `VideoPlayer.brs` has correct progress reporting and seek handling. This phase is primarily about adding visual overlays and additional interaction paths, not rebuilding core playback.

## Open Questions

1. **ContentNode re-render after in-place update**
   - What we know: MarkupGrid/MarkupList item components get `onItemContentChange` when `itemContent` is set, but not when sub-fields change.
   - What's unclear: Whether calling `content.update({}, true)` or re-assigning the content tree root triggers item re-render efficiently, or if we need to replace the specific child node.
   - Recommendation: Test both approaches during implementation. If in-place field update doesn't trigger re-render, swap the child ContentNode (remove + re-add at same index).

2. **Show-level unwatched count from API**
   - What we know: The Plex API returns `leafCount` and `viewedLeafCount` on show/season metadata, allowing calculation of unwatched episode count.
   - What's unclear: Whether these fields are included in library browse responses (`/library/sections/{id}/all`) or only in individual metadata fetches.
   - Recommendation: Check the `/library/sections/{id}/all` response during implementation. If counts are missing, a supplementary metadata fetch may be needed for show posters.

3. **PlexSessionTask reuse pattern**
   - What we know: VideoPlayer creates one `PlexSessionTask` at init and reuses it by setting fields and `control = "run"`.
   - What's unclear: Whether setting `control = "run"` on an already-completed task reliably re-runs it, or if task state needs resetting first. Phase 1 established create-per-request as the safe pattern.
   - Recommendation: Switch to creating a new `PlexSessionTask` per report (consistent with Phase 1 create-per-request pattern) if the reuse pattern shows issues during testing.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `DetailScreen.brs`, `VideoPlayer.brs`, `PosterGridItem.xml/brs`, `EpisodeItem.xml/brs`, `PlexSessionTask.brs`, `MainScene.brs`, `constants.brs`, `utils.brs`
- [Roku onKeyEvent documentation](https://sdkdocs-archive.roku.com/1608547.html) - key string values including `options`
- [Plexopedia: Mark Item Unwatched](https://www.plexopedia.com/plex-media-server/api/library/media-mark-unwatched/) - scrobble/unscrobble endpoint format
- [Plex API Timeline Reference](https://plexapi.dev/api-reference/timeline/report-media-timeline) - timeline parameters and state values

### Secondary (MEDIUM confidence)
- [Roku Dialog nodes](https://developer.roku.com/docs/references/scenegraph/dialog-nodes/dialog.md) - StandardMessageDialog structure
- [Roku Poster node](https://developer.roku.com/docs/references/scenegraph/renderable-nodes/poster.md) - Poster blendColor for dynamic tinting
- [Plex Forum: scrobble/unscrobble API](https://forums.plex.tv/t/api-to-mark-watched-unwatched/49375) - show/season/episode key scoping

### Tertiary (LOW confidence)
- [Roku custom progress bar example (GitHub)](https://github.com/gokulpulikkal/CustomProgressBar) - community pattern, not official

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components already exist in codebase, APIs are well-documented
- Architecture: HIGH - patterns are straightforward SceneGraph composition (Rectangles, Posters, Dialogs)
- Pitfalls: HIGH - derived from direct codebase analysis and Roku documentation review
- Triangle badge approach: MEDIUM - blendColor on white PNG is standard Roku practice but needs validation that blendColor works as expected on Poster nodes with alpha

**Research date:** 2026-03-08
**Valid until:** 2026-04-08 (stable domain - Roku SceneGraph and Plex API are mature)
