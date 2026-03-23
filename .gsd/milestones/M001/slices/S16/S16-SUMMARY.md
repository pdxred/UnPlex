# S16: App Branding — Summary

**Status:** Complete  
**Completed:** 2026-03-23  
**Duration:** ~20 minutes (T01: 12m, T02: 8m)

## What This Slice Delivered

Unified SimPlex visual branding across all surfaces — Roku home screen icons, app splash screen, and in-app Sidebar title. All assets use Inter Bold font, a diagonal black-to-charcoal gradient background, two-tone "Sim" (white) / "Plex" (gold #F3B125) text with gray stroke outline, and correct Roku dimensions.

### Concrete deliverables:
1. **Inter Bold font bundled** — `SimPlex/fonts/Inter-Bold.ttf` (344KB, SIL OFL license) downloaded from Google Fonts gstatic CDN. `bsconfig.json` updated with `"fonts/**/*"` glob so it deploys to Roku.
2. **Sidebar title uses Inter Bold** — Sidebar.xml title labels use `<Font role="font" uri="pkg:/fonts/Inter-Bold.ttf" size="36" />` child nodes (replacing system font). Shadow label nodes add subtle depth effect (2px offset, gray #666666).
3. **Branded icon assets** — `icon_focus_fhd.png` (540×405), `icon_side_fhd.png` (246×140) with gradient bg, Inter Bold text, gray stroke.
4. **Branded splash screen** — `splash_fhd.jpg` (1920×1080, JPEG q=95) with same branded design.
5. **In-app gradient background** — `bg_gradient.png` (1920×1080) replaces solid Rectangle in MainScene.xml with `<Poster>` node.
6. **Reproducible generation script** — `scripts/generate_branding.py` regenerates all four images deterministically from the font file + Pillow.

## Requirements Validated

- **BRAND-01:** Inter Bold font in icon, splash, and Sidebar title ✓
- **BRAND-02:** Gray stroke outline visible on all text assets ✓
- **BRAND-03:** Diagonal black-to-charcoal gradient on all backgrounds ✓
- **BRAND-04:** All icon variants at correct Roku dimensions ✓

## Verification Results

All 8 slice-level checks pass:

| # | Check | Result |
|---|-------|--------|
| SV1 | icon_focus_fhd.png = 540×405 | ✅ |
| SV2 | icon_side_fhd.png = 246×140 | ✅ |
| SV3 | splash_fhd.jpg = 1920×1080 | ✅ |
| SV4 | Inter-Bold.ttf exists | ✅ |
| SV5 | fonts glob in bsconfig.json | ✅ |
| SV6 | Inter-Bold in Sidebar.xml | ✅ |
| SV7 | bg_gradient.png exists | ✅ |
| SV8 | bg_gradient in MainScene.xml | ✅ |

**UAT required:** Visual confirmation needed on sideloaded Roku — font rendering, gradient smoothness, icon appearance on home screen.

## Patterns Established

- **Custom font integration:** Use `<Font role="font" uri="pkg:/fonts/..." size="N" />` child nodes inside Labels. Remove the `font="font:..."` attribute entirely — both present = undefined behavior.
- **Shadow label depth effect:** Duplicate Label nodes rendered before (behind) main labels with small offset and gray color.
- **Image-based backgrounds:** `<Poster uri="pkg:/images/..." />` replaces `<Rectangle color="..." />` for gradient/image backgrounds in SceneGraph.
- **Reproducible asset generation:** `scripts/generate_branding.py` is the single source of truth for branding assets. Change parameters there, re-run, and all four images update consistently.

## Key Files Modified

| File | Change |
|------|--------|
| `SimPlex/fonts/Inter-Bold.ttf` | New — Inter Bold font (344KB) |
| `bsconfig.json` | Added `"fonts/**/*"` to files array |
| `SimPlex/components/widgets/Sidebar.xml` | Custom Font nodes + shadow labels |
| `SimPlex/components/widgets/Sidebar.brs` | Shadow label positioning logic |
| `SimPlex/components/MainScene.xml` | Rectangle → Poster with bg_gradient.png |
| `SimPlex/images/icon_focus_fhd.png` | Replaced — branded 540×405 |
| `SimPlex/images/icon_side_fhd.png` | Replaced — branded 246×140 |
| `SimPlex/images/splash_fhd.jpg` | Replaced — branded 1920×1080 |
| `SimPlex/images/bg_gradient.png` | New — gradient-only 1920×1080 |
| `scripts/generate_branding.py` | New — Pillow generation script |

## What S17 Should Know

- The `manifest` file already references the correct icon/splash paths — no change was needed there.
- `scripts/generate_branding.py` requires `Pillow` and the bundled `Inter-Bold.ttf` to regenerate assets.
- The in-app background is now an image (`bg_gradient.png`) loaded via Poster, not a Rectangle with a color attribute. If any code references the background Rectangle's `color` field, it will fail — use `uri` instead.
- Inter-Bold.ttf is licensed under SIL Open Font License — attribution should go in README if documenting fonts.

## Deviations from Plan

- Side icon font size reduced from 32pt to 28pt (and stroke from 2px to 1px) to fit 246×140 canvas without text clipping.
- Stroke uses full offset grid (all non-zero dx,dy in ±N) rather than 4 cardinal offsets — smoother outline.
- Google Fonts GitHub raw URL returned HTML due to Git LFS; used gstatic CDN URL instead.

## Known Issues

None. Full visual confirmation requires sideload to Roku device (documented in UAT).
