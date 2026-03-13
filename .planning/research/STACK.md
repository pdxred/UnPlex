# Stack Research

**Domain:** Roku BrightScript / SceneGraph channel — v1.1 Polish & Navigation milestone
**Researched:** 2026-03-13
**Confidence:** HIGH for platform findings; MEDIUM for icon dimensions (official spec page returned 403, community-verified values used)

---

## What This Document Covers

This replaces the v1.0 STACK.md. The v1.0 stack (BrighterScript 0.70.x, SceneGraph RSG 1.3, Task nodes, roRegistrySection) is fully validated and unchanged. This document covers **only delta requirements** for v1.1 features: TV show navigation overhaul, bug fixes, branding refresh, codebase cleanup, and GitHub documentation.

---

## Key Finding: Most v1.1 Work Requires No New Stack

After examining the existing codebase (`EpisodeScreen.brs`, `EpisodeScreen.xml`, `EpisodeItem.xml`, `constants.brs`, `utils.brs`, `SearchScreen.brs`, `manifest`), the v1.1 milestone is overwhelmingly a **bug fix and polish** milestone. The platform capabilities needed already exist in Roku OS and the existing codebase. The only genuine new stack items are:

1. A bundled custom TTF font for bolder title typography
2. Pre-rendered PNG image assets for gradient backgrounds and redesigned icons/splash

Everything else — auto-play Timer, watch state propagation, season progress display, search layout fixes — uses existing SceneGraph nodes and BrightScript patterns.

---

## Delta Stack for v1.1

### New Assets (Not Code Dependencies)

| Asset | Type | Dimensions / Format | Purpose | Source |
|-------|------|---------------------|---------|--------|
| InterBold.ttf OR OutfitBold.ttf | TrueType font | N/A | Heavier title/heading weight than system bold | rsms.me/inter / fonts.google.com |
| icon_focus_fhd.png (redesigned) | PNG | 540 x 405 px | Channel tile, focused state (FHD) | Designed externally, bundled in `images/` |
| icon_side_fhd.png (redesigned) | PNG | 246 x 140 px | Channel tile, side state (FHD) | Designed externally, bundled in `images/` |
| icon_focus_hd.png (redesigned) | PNG | 336 x 210 px | Channel tile, focused state (HD) | Designed externally, bundled in `images/` |
| icon_side_hd.png (redesigned) | PNG | 164 x 94 px | Channel tile, side state (HD) | Designed externally, bundled in `images/` |
| splash_fhd.jpg (redesigned) | JPG or PNG | 1920 x 1080 px | Launch splash screen | Designed externally, bundled in `images/` |
| gradient panels (optional) | PNG | Varies (1580x1080 or similar) | Background gradient overlay for screens | Designed externally, bundled in `images/` |

**No new npm packages.** **No new BrighterScript plugins.** **No new Task nodes.**

---

## Feature-by-Feature Stack Analysis

### 1. TV Show Navigation Overhaul

**Existing implementation is mostly correct.** `EpisodeScreen.xml` already uses:
- `LabelList` for horizontal season tabs (fires `itemFocused` to load episodes dynamically)
- `MarkupList` with custom `EpisodeItem` component for episode rows
- Up/down key routing between season list and episode list
- `grandparentRatingKey` / `parentRatingKey` passing into `VideoPlayer` for auto-play

**What needs fixing (BrightScript logic only, no new stack):**

| Issue | What It Is | Fix Approach |
|-------|-----------|--------------|
| Season progress display | `leafCount` and `viewedLeafCount` are returned by `/library/metadata/{id}/children` but not parsed | Read these fields in `processSeasons()` and format "S01 (6/10)" in the LabelList content |
| Auto-play countdown wiring | `onPlaybackComplete` in EpisodeScreen has a `TODO` comment; countdown never fires | Use SceneGraph `Timer` node (already in Roku OS) with a 10-second countdown overlay Group/Label |
| Watch state propagation | `m.global.watchStateUpdate` is fired from DetailScreen but HomeScreen does not observe it | Add `m.global.observeField("watchStateUpdate", ...)` in HomeScreen and refresh hub rows |

**SceneGraph `Timer` node** (for auto-play countdown):
- Built into Roku OS — zero import, zero dependency
- `timer.duration = 10`, `timer.repeat = false`, `timer.observeField("fire", "onAutoPlayTimer")`
- Already used in `SearchScreen.brs` for debounce — proven pattern in this codebase

### 2. Bug Fixes

All bugs are BrightScript/XML logic errors. No new stack for any of them:

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Collections navigation | Likely ratingKey type coercion or missing `type = "collection"` check | BrightScript fix in collection item handler |
| Search result layout | `EpisodeItem`-style component assumes 2:3 portrait ratio for all results; episode results are 16:9 | Branch on `type` field in search result item renderer; apply correct `width`/`height` to `BuildPosterUrl()` |
| Thumbnail aspect ratios | Same root cause as search layout | Correct dimensions per content type: movie=240x360, episode=320x180, show=240x360 |
| Auto-play wiring gap | `onPlaybackComplete` missing countdown implementation (confirmed by `TODO` comment in code) | Timer node + overlay Group (see above) |
| Watch state propagation | HomeScreen not observing `m.global.watchStateUpdate` | Single `observeField` call + refresh logic |
| Server switching | Feature is unclear/broken; PROJECT.md lists as "fix or remove" | Remove UI paths for server switching; consolidate to single-server flow (deletion task) |

### 3. App Branding

#### Custom Font (Bolder Title Weight)

Roku SceneGraph supports custom fonts via the `Font` node:

```xml
<Label id="titleLabel" translation="[80, 40]" color="0xFFFFFFFF">
    <Font uri="pkg:/fonts/InterBold.ttf" size="52" />
</Label>
```

Or in BrightScript when setting font dynamically:
```brightscript
font = CreateObject("roSGNode", "Font")
font.uri = "pkg:/fonts/InterBold.ttf"
font.size = 52
m.titleLabel.font = font
```

**Recommended font:** Inter Bold (`InterBold.ttf`)
- Open-source, SIL OFL licensed — no legal constraints
- Designed for screen legibility at small pixel densities; excellent for 10-foot TV UI
- ~300KB file size; no enforced sideload package size limit for developer channels
- Download from https://rsms.me/inter/ (variable font or static Bold weight)

**File placement:** `SimPlex/fonts/InterBold.ttf` — new `fonts/` directory at same level as `source/`, `components/`, `images/`

**bsconfig.json files array must include:** `"fonts/**/*"` (or the fonts dir will not be zipped into the package)

#### Text Stroke / Outline Effect

Roku SceneGraph `Label` nodes have **no stroke, outline, or shadow property**. This is a confirmed platform limitation — there is no workaround via Label fields.

**Standard community workaround:** Stack two Label nodes at the same position, offset the lower one by 1-2px in a dark translucent color:

```xml
<!-- Shadow/depth layer (render first, underneath) -->
<Label id="titleShadow" translation="[82, 42]" color="0x00000099" />
<!-- Primary text layer -->
<Label id="titleLabel" translation="[80, 40]" color="0xFFFFFFFF" />
```

Both labels receive the same `text` value in BrightScript. Render cost is negligible for a few title labels.

#### Gradient Backgrounds

Roku SceneGraph `Rectangle` nodes have **no gradient fill property**. This is a confirmed platform limitation — no workaround exists within SceneGraph node properties.

**Only approach:** Pre-render gradient as a PNG image and display it via a `Poster` node:

```xml
<Poster id="gradientBg" uri="pkg:/images/gradient_bg.png" width="1920" height="1080" />
```

Generate gradient PNGs using any image tool (Figma, Photoshop, ImageMagick, etc.) outside the channel. Bundle the PNG in `SimPlex/images/`. PNG supports alpha channel for partial-transparency gradient overlays.

#### Icon and Splash Screen Assets

Icons and splash are static image files referenced in `manifest`. They are replaced by designing new assets externally and overwriting the existing files. **No BrightScript or SceneGraph changes needed.**

Required dimensions (community-verified; official spec page returned HTTP 403):

| Manifest Key | Current File | Required Size | Format |
|-------------|-------------|---------------|--------|
| `mm_icon_focus_fhd` | icon_focus_fhd.png | 540 x 405 px | PNG |
| `mm_icon_side_fhd` | icon_side_fhd.png | 246 x 140 px | PNG |
| `mm_icon_focus_hd` | icon_focus_hd.png | 336 x 210 px | PNG |
| `mm_icon_side_hd` | icon_side_hd.png | 164 x 94 px | PNG |
| `splash_screen_fhd` | splash_fhd.jpg | 1920 x 1080 px | JPG or PNG |

`splash_min_time = 1500` in manifest is appropriate — no change needed.

### 4. Codebase Cleanup

Pure deletion and refactoring — no new stack:

| Task | What |
|------|------|
| Delete `normalizers.brs` | Confirmed orphaned in PROJECT.md ("Known issues") |
| Delete `capabilities.brs` | Confirmed orphaned in PROJECT.md |
| Extract `SafeStr(ratingKey)` helper to `utils.brs` | The ratingKey string coercion block appears 15+ times verbatim across EpisodeScreen, DetailScreen, etc. — consolidate |
| Remove server switching UI | Delete or simplify ServerListScreen paths |

### 5. GitHub Documentation

Plain Markdown in the repository. No documentation generator needed.

**Recommended structure:**
```
README.md                  — Project overview, screenshots, sideload how-to, feature list
docs/
  USER_GUIDE.md            — Remote control map, navigation flows, settings
  ARCHITECTURE.md          — Component map, task node pattern, screen stack, data flow
  CONTRIBUTING.md          — BrightScript style guide, how to add a screen/widget
```

No Docusaurus, MkDocs, or similar — overengineered for a personal sideloaded channel with no public API.

---

## Recommended Stack Summary (v1.1 Delta)

### New Code Dependencies: None

The BrighterScript 0.70.x + SceneGraph RSG 1.3 toolchain handles everything. No new npm packages, no new plugins, no new ropm packages.

### New File System Additions

```
SimPlex/
  fonts/                    ← NEW directory
    InterBold.ttf           ← NEW font asset
  images/
    icon_focus_fhd.png      ← REPLACE (redesigned)
    icon_side_fhd.png       ← REPLACE (redesigned)
    icon_focus_hd.png       ← REPLACE (redesigned)
    icon_side_hd.png        ← REPLACE (redesigned)
    splash_fhd.jpg          ← REPLACE (redesigned)
    gradient_bg.png         ← NEW (optional, if gradient backgrounds are used)
```

### bsconfig.json Update Required

Add `fonts/**/*` to the `files` array so the font is included in the sideload package:

```json
{
  "files": [
    "manifest",
    "source/**/*",
    "components/**/*",
    "images/**/*",
    "fonts/**/*"
  ]
}
```

---

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not |
|---------|-------------|-------------|---------|
| Bolder font | Bundle InterBold.ttf | Use `font:LargeBoldSystemFont` | System bold is visually thin at 40-52px title sizes; no weight control; cannot match brand intent |
| Text stroke | Stacked Label shadow offset | Image-based text overlay | Image overlays cannot work for dynamic text strings |
| Gradient background | Pre-rendered PNG as Poster | Rectangle gradient | Rectangle gradient not supported in Roku OS (confirmed) |
| Auto-play countdown | SceneGraph `Timer` node | New Task node | Timer fires on render thread — no async work needed; simpler |
| Season progress | Parse `leafCount`/`viewedLeafCount` from existing API response | Additional API call | Fields already present in `/children` response; zero cost |
| Documentation | Plain Markdown | Docusaurus/MkDocs | No public API surface; sideload-only personal project; Markdown is faster to write and maintain |
| Font weight | Inter Bold | Outfit Bold | Both are excellent choices; Inter has stronger screen legibility research behind it and is used by major tech products |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| BrighterScript 1.0.0-alpha | Explicitly deferred in PROJECT.md; unstable alpha with breaking changes | Stay on 0.70.x |
| Maestro MVVM | Deprecated November 2023; confirmed in v1.0 research | Plain BrightScript + SceneGraph |
| SGDEX (SceneGraph Developer Extensions) | Heavy Roku-official framework for channel-store apps; adds enormous complexity for a custom sideloaded channel | Native SceneGraph nodes |
| roFontRegistry BrightScript API | Legacy API for non-SceneGraph font registration; SceneGraph Font node is the correct approach | SceneGraph `Font` node with `uri` field |
| WebP or AVIF for icons/splash | Roku firmware manifest image rendering expects PNG/JPG for icon and splash assets | PNG for icons, JPG/PNG for splash |
| Variable font (single TTF with all weights) | Variable font support in Roku OS Font node is unverified; static weight TTF is confirmed working | Static weight TTF (e.g., InterBold.ttf, not Inter.ttf with `wght` axis) |

---

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| BrighterScript | 0.70.x | Unchanged from v1.0; confirmed stable |
| Roku OS | 11.5+ | Target per PROJECT.md; Timer, Font node, MarkupList, MarkupGrid all available since OS 9.x |
| SceneGraph | RSG 1.3 | Set in manifest; confirmed in existing channel |
| Inter font | v4.x (static Bold) | Download static Bold variant, not the variable font package |
| PNG images | Standard PNG-24/32 | Roku OS renders standard PNG; APNG animation not supported |

---

## Sources

- Roku Community — mm_icon_focus_fhd dimensions: https://community.roku.com/t5/Roku-Developer-Program/mm-icon-focus-fhd-resolution/td-p/492827 (MEDIUM confidence; official spec page returned 403; community values are consistent across multiple threads)
- Roku Developer docs — Timer node: https://developer.roku.com/docs/references/scenegraph/control-nodes/timer.md
- Roku Developer docs — Font node: https://developer.roku.com/docs/references/scenegraph/typographic-nodes/font.md
- Roku Community — Gradient Rectangle limitation: https://community.roku.com/t5/Roku-Developer-Program/Gradient-rectangle/td-p/404364 (MEDIUM confidence; multiple threads confirm no native gradient; Roku docs page returned 403)
- Roku Community — Custom TTF font usage: https://community.roku.com/t5/Roku-Developer-Program/Using-custom-fonts-ttf-files-in-XML/td-p/505688 (HIGH confidence; consistent with Font node documentation pattern)
- Roku Community — Label stroke limitation: https://community.roku.com/t5/Roku-Developer-Program/How-to-modify-System-Fonts-in-SceneGraph/td-p/466671 (MEDIUM confidence; community confirms no stroke property; stacked-label workaround is established pattern)
- Existing codebase — EpisodeScreen.brs, EpisodeScreen.xml, EpisodeItem.xml, constants.brs, utils.brs, SearchScreen.brs, manifest (HIGH confidence; direct code inspection)
- PROJECT.md — Known issues (orphaned files, auto-play gap, watch state gap) (HIGH confidence; on-disk project record)
- Inter font project — https://rsms.me/inter/ (HIGH confidence; verified open-source, SIL OFL license)

---

*Stack research for: SimPlex v1.1 Polish & Navigation (Roku BrightScript/SceneGraph channel)*
*Researched: 2026-03-13*
