# S16: App Branding — Research

**Slice:** S16 — App Branding  
**Depth:** Light research (asset work + one established SceneGraph pattern)  
**Confidence:** HIGH  

## Summary

S16 is purely asset and font work with no new architecture. It decomposes into three independent work areas: (1) bundle InterBold.ttf and wire it into the Sidebar title and optionally other title labels, (2) regenerate icon and splash image files at correct dimensions with gradient backgrounds, gray stroke on text, and bolder typography, and (3) update `bsconfig.json` to include the `fonts/**/*` glob. No code dependencies exist on other slices — S15 is complete and the codebase is stable.

## Requirements Targeted

| Requirement | Description | This Slice's Role |
|---|---|---|
| BRAND-01 | App icon and splash screen use bolder font (Inter Bold) | Primary owner |
| BRAND-02 | Icon/splash text has gray external stroke | Primary owner |
| BRAND-03 | Icon and splash backgrounds have subtle gradient | Primary owner |
| BRAND-04 | All icon variants updated at correct dimensions | Primary owner |

## Recommendation

Apply InterBold.ttf to the Sidebar "SimPlex" title and screen header labels (the `font:LargeBoldSystemFont` usages). Regenerate all icon/splash images externally (Figma, Photoshop, or programmatic tool) — these are static PNG/JPG assets, not runtime-generated. Update `bsconfig.json` and `manifest` as needed. No gradient can be rendered at runtime by SceneGraph `Rectangle` nodes — use a pre-rendered PNG `Poster` node if an in-app gradient background is desired (scope TBD; roadmap says "optional").

## Implementation Landscape

### 1. Custom Font (InterBold.ttf)

**Current state:** All labels use system fonts (`font:LargeBoldSystemFont`, `font:MediumSystemFont`, etc.) — 80 total `font=` declarations across 30 XML files. No custom font has ever been loaded in this project. No `fonts/` directory exists.

**Pattern (confirmed working):** SceneGraph `Font` node with `role="font"` as child of `Label`:

```xml
<Label id="titleSim" text="Sim" color="0xFFFFFFFF">
    <Font role="font" uri="pkg:/fonts/InterBold.ttf" size="36" />
</Label>
```

Or programmatically in BrightScript:
```brightscript
font = CreateObject("roSGNode", "Font")
font.uri = "pkg:/fonts/InterBold.ttf"
font.size = 36
label.font = font
```

**Files to create:**
- `SimPlex/fonts/InterBold.ttf` — ~300KB, SIL OFL licensed, download from [rsms.me/inter](https://rsms.me/inter). Use the static `Inter-Bold.ttf` weight, NOT the variable font.

**Files to modify:**
- `bsconfig.json` — add `"fonts/**/*"` to `files` array
- `SimPlex/components/widgets/Sidebar.xml` — replace `font="font:LargeBoldSystemFont"` on `titleSim` and `titlePlex` labels with embedded `<Font role="font" uri="pkg:/fonts/InterBold.ttf" size="XX" />` child nodes
- Optionally: screen header labels in `HomeScreen.xml`, `DetailScreen.xml`, `EpisodeScreen.xml`, `SearchScreen.xml`, `SettingsScreen.xml` — the `LargeBoldSystemFont` labels used for screen titles could be upgraded to InterBold for visual consistency

**Scope decision:** The slice description says "Bolder Inter Bold font" — the minimum is Sidebar title + icon/splash. Extending to all `LargeBoldSystemFont` screen titles is optional polish. The planner should decide scope based on time budget.

**Constraint:** The `font=` attribute on `<Label>` in XML does NOT accept `pkg:/` URIs directly. You must use either the child `<Font role="font">` element or the BrightScript programmatic approach. The existing `font="font:LargeBoldSystemFont"` attribute syntax is only valid for system font shorthand strings.

### 2. Icon and Splash Assets

**Current state (WRONG DIMENSIONS):**

| File | Current Size | Required Size | Format |
|---|---|---|---|
| `icon_focus_fhd.png` | 336×210 | **540×405** | PNG |
| `icon_side_fhd.png` | 108×69 | **246×140** | PNG |
| `splash_fhd.jpg` | 1920×1080 | 1920×1080 ✅ | JPG |

The current icon_focus_fhd is at the wrong HD dimensions (336×210 is the old `mm_icon_focus_hd` size). For an FHD-only sideloaded channel, the correct focus icon is **540×405**.

**Confirmed dimensions (from Roku forums and docs):**
- `mm_icon_focus_fhd` = **540×405** (4:3 aspect ratio)
- `mm_icon_side_fhd` = **246×140** (≈16:9 aspect ratio)
- `splash_screen_fhd` = **1920×1080** (16:9)

**Side icon note:** The manifest currently lists `mm_icon_side_fhd` but per Roku community knowledge, side icons are rarely displayed for sideloaded channels. The _focus icon is the one visible on the Roku home screen. Still, both should be produced at correct dimensions.

**HD variants:** The manifest currently only declares FHD assets (`ui_resolutions=fhd`). The roadmap mentions "all four Roku variants" (FHD focus, FHD side, HD focus, HD side) — but since `ui_resolutions=fhd` is set, the firmware handles downscaling. Adding HD manifest entries is optional; the minimum is correct FHD assets. If HD entries are added:
- `mm_icon_focus_hd` = 290×218
- `mm_icon_side_hd` = 108×69

**Design specs (from roadmap + requirements):**
- Inter Bold font for "SimPlex" text
- Gray external stroke on text (achieved in image editor, not at runtime)
- Subtle corner-to-corner black-to-charcoal gradient background
- "Sim" in white, "Plex" in Plex gold (#E5A00D / #F3B125)
- Background starting color: ~#1A1A2E or darker, ending: ~#0A0A14

**These are static image files** — created once in an external tool and committed. The planner should emit a task that specifies exact design parameters so the executor can produce them (or instruct the user to produce them).

### 3. In-App Gradient Background (Optional)

**Current state:** All screens use solid-color `Rectangle` backgrounds. MainScene = `0x1A1A2EFF`, most other screens = `0x000000FF`.

**Platform limitation:** SceneGraph `Rectangle` nodes have NO gradient fill property. This is a confirmed platform limitation.

**Workaround:** Use a `Poster` node (image-displaying node) with a pre-rendered gradient PNG instead of a `Rectangle`. The gradient PNG would be a single 1920×1080 image (or a vertical strip that stretches horizontally). This replaces the `<Rectangle id="background">` with `<Poster id="background" uri="pkg:/images/bg_gradient.png" width="1920" height="1920" />`.

**Recommendation:** This is listed as "optional" in the roadmap. If pursued, create a single `bg_gradient.png` (1920×1080) and swap it into MainScene.xml (or all screens). File size impact: a dark gradient PNG compresses extremely well — likely under 10KB. The Poster node is as performant as Rectangle for static full-screen backgrounds.

### 4. Stacked-Label Shadow/Stroke (In-App, Optional)

**Platform limitation:** SceneGraph `Label` nodes have NO stroke or text-shadow properties.

**Workaround:** Stack two `Label` nodes — a "shadow" label offset by 1-2px with a darker color, behind the main label. This is the established community pattern. Example for the Sidebar title:

```xml
<Label id="titleSimShadow" translation="[22, 27]" text="Sim" color="0x666666FF">
    <Font role="font" uri="pkg:/fonts/InterBold.ttf" size="36" />
</Label>
<Label id="titleSim" translation="[20, 25]" text="Sim" color="0xFFFFFFFF">
    <Font role="font" uri="pkg:/fonts/InterBold.ttf" size="36" />
</Label>
```

**Recommendation:** This is a nice-to-have for the in-app Sidebar title. Not essential — the BRAND-02 requirement is specifically about icon/splash text stroke, which is handled in the static image assets.

## File Inventory

### Files to Create
| File | Purpose |
|---|---|
| `SimPlex/fonts/InterBold.ttf` | Inter Bold static weight (~300KB) |
| `SimPlex/images/icon_focus_fhd.png` | Replacement: 540×405 with branded design |
| `SimPlex/images/icon_side_fhd.png` | Replacement: 246×140 with branded design |
| `SimPlex/images/splash_fhd.jpg` | Replacement: 1920×1080 with branded design |
| `SimPlex/images/bg_gradient.png` (optional) | Gradient background for in-app screens |

### Files to Modify
| File | Change |
|---|---|
| `bsconfig.json` | Add `"fonts/**/*"` to files array |
| `SimPlex/components/widgets/Sidebar.xml` | Replace system font with InterBold on title labels |
| `SimPlex/components/widgets/Sidebar.brs` | May need adjustment if font size changes label bounds (line 10-11 uses `boundingRect()` for positioning) |
| `SimPlex/manifest` | Only if adding HD icon entries; FHD entries already correct |

### Files NOT Touched
- All task nodes (PlexApiTask, etc.)
- VideoPlayer, PosterGrid, EpisodeItem, etc.
- All .brs logic files (unless extending font to screen headers)
- `constants.brs` (no new constants needed unless adding font path constant)

## Task Decomposition Seams

The work divides cleanly into 3 independent tasks:

1. **Font Bundle** — Create `fonts/` dir, add InterBold.ttf, update bsconfig.json, update Sidebar.xml title labels. Self-contained, verifiable by compile + visual inspection.

2. **Icon/Splash Assets** — Generate 3 image files at correct dimensions with the branded design (gradient bg, Inter Bold text, gray stroke, Sim=white Plex=gold). This is design work, not code. Verify by file dimensions and visual inspection.

3. **In-App Gradient Background (optional)** — Create bg_gradient.png, swap Rectangle for Poster in MainScene.xml or individual screens. Independent of tasks 1-2.

Tasks 1 and 2 can run in parallel. Task 3 is optional and can be deferred to the planner's judgment.

## Constraints

- **Static-weight TTF only.** Variable font support in Roku's Font node is unverified. Use `Inter-Bold.ttf` (the static weight file), not `Inter-VariableFont_*.ttf`.
- **No WebP/AVIF.** Roku manifest and SceneGraph only support PNG and JPG for images.
- **Image generation is external.** These PNG/JPG files must be produced by a design tool or image generation script — they cannot be created by BrightScript at runtime.
- **Sidebar title positioning is bounds-dependent.** `Sidebar.brs` line 10-11 calls `boundingRect()` on `titleSim` to position `titlePlex` immediately after it. If the font change alters the rendered width, the positioning auto-adjusts (this is the correct pattern). No manual coordinate changes needed.
- **SIGSEGV-safe.** This slice adds no Animation nodes, no BusySpinner, and no dynamic component creation. All changes are static assets and XML attribute updates. Zero crash risk.

## Verification

- `bsc build` compiles without errors (font path in bsconfig, no broken XML)
- `file SimPlex/images/icon_focus_fhd.png` reports 540×405
- `file SimPlex/images/icon_side_fhd.png` reports 246×140
- `file SimPlex/images/splash_fhd.jpg` reports 1920×1080
- `file SimPlex/fonts/InterBold.ttf` exists and is a TrueType font
- `grep "fonts" bsconfig.json` shows `"fonts/**/*"` in files array
- `grep "Font" SimPlex/components/widgets/Sidebar.xml` shows `pkg:/fonts/InterBold.ttf`
- Sideload to Roku: icon appears correctly sized on home screen, splash shows on launch, Sidebar title renders in Inter Bold
