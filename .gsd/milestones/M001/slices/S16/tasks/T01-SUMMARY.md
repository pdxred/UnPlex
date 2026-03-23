---
id: T01
parent: S16
milestone: M001
provides:
  - Inter Bold font bundled in SimPlex/fonts/
  - Sidebar title labels using custom Inter Bold font via SceneGraph Font child nodes
  - Shadow label depth effect on Sidebar "SimPlex" title
  - Build config includes fonts directory for Roku deployment
key_files:
  - SimPlex/fonts/Inter-Bold.ttf
  - SimPlex/components/widgets/Sidebar.xml
  - SimPlex/components/widgets/Sidebar.brs
  - bsconfig.json
key_decisions:
  - Used Google Fonts gstatic CDN URL for reliable Inter-Bold.ttf download (GitHub raw LFS URLs return HTML pages)
patterns_established:
  - Custom font integration pattern for Roku SceneGraph: Font child node with role="font" replaces font= attribute on Labels
  - Shadow label pattern: duplicate Label nodes rendered behind main labels with 2px offset and gray color for depth effect
observability_surfaces:
  - Roku BrightScript debugger console logs font path resolution failures (pkg:/fonts/Inter-Bold.ttf)
  - Pre-deploy validation: test -f SimPlex/fonts/Inter-Bold.ttf && grep -q Inter-Bold SimPlex/components/widgets/Sidebar.xml
  - Build staging check: out/staging/fonts/ should contain Inter-Bold.ttf after bsc build
duration: 12m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T01: Bundle Inter Bold font and wire into Sidebar title

**Bundled Inter-Bold.ttf (344KB, SIL OFL) from Google Fonts, replaced system font on Sidebar title labels with custom Font child nodes, added shadow label depth effect, and updated bsconfig.json to deploy fonts to Roku device.**

## What Happened

Downloaded Inter-Bold.ttf from Google Fonts gstatic CDN (the GitHub raw URL returned an HTML page due to Git LFS). Created `SimPlex/fonts/` directory and placed the 344KB font file. Added `"fonts/**/*"` glob to the bsconfig.json files array so the font deploys to the Roku staging directory.

In Sidebar.xml, replaced the two title Label nodes (`titleSim` and `titlePlex`) that used `font="font:LargeBoldSystemFont"` with versions using child `<Font role="font" uri="pkg:/fonts/Inter-Bold.ttf" size="36" />` nodes. The `font=` attribute was fully removed since it conflicts with child Font nodes in Roku SceneGraph.

Added two shadow Label nodes (`titleSimShadow` and `titlePlexShadow`) rendered before the main labels (so they appear behind) with 2px offset and `0x666666FF` gray color for a subtle depth effect. In Sidebar.brs, added dynamic positioning code for the shadow Plex label using the same `boundingRect()` pattern that already positions the main Plex label.

## Verification

All 6 task-level checks pass. Font file exists and is valid TrueType, bsconfig includes fonts glob, Sidebar.xml uses Inter-Bold via Font child nodes, no LargeBoldSystemFont references remain, and both shadow labels are present.

Slice-level checks: 3 of 8 pass (the 3 owned by T01). The remaining 5 checks are T02 scope (icon/splash dimensions, bg_gradient asset, MainScene wiring).

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `test -f SimPlex/fonts/Inter-Bold.ttf` | 0 | ✅ pass | <1s |
| 2 | `python3 -c "from PIL import ImageFont; f=ImageFont.truetype('SimPlex/fonts/Inter-Bold.ttf', 36); print('OK:', f.getname())"` | 0 | ✅ pass | <1s |
| 3 | `grep -q '"fonts/\*\*/\*"' bsconfig.json` | 0 | ✅ pass | <1s |
| 4 | `grep -q "Inter-Bold" SimPlex/components/widgets/Sidebar.xml` | 0 | ✅ pass | <1s |
| 5 | `grep -c "LargeBoldSystemFont" SimPlex/components/widgets/Sidebar.xml` → 0 | 0 | ✅ pass | <1s |
| 6 | `grep -c "titleSimShadow\|titlePlexShadow" SimPlex/components/widgets/Sidebar.xml` → 2 | 0 | ✅ pass | <1s |
| 7 | `test -f SimPlex/fonts/Inter-Bold.ttf` (slice SV4) | 0 | ✅ pass | <1s |
| 8 | `grep -q "fonts" bsconfig.json` (slice SV5) | 0 | ✅ pass | <1s |
| 9 | `grep -q "Inter-Bold" SimPlex/components/widgets/Sidebar.xml` (slice SV6) | 0 | ✅ pass | <1s |
| 10 | icon_focus_fhd.png dimensions (slice SV1) | 1 | ⏳ T02 scope | <1s |
| 11 | bg_gradient.png exists (slice SV7) | 1 | ⏳ T02 scope | <1s |
| 12 | bg_gradient in MainScene.xml (slice SV8) | 1 | ⏳ T02 scope | <1s |

## Diagnostics

- **Font load on device:** Roku firmware logs font resolution failures to BrightScript debugger console. If the Sidebar title appears in the default system font instead of Inter Bold after sideloading, check that `pkg:/fonts/Inter-Bold.ttf` resolves correctly.
- **Build staging:** After `bsc build`, verify `out/staging/fonts/Inter-Bold.ttf` exists to confirm the bsconfig glob is working.
- **Shadow visibility:** Shadow labels render behind main labels due to SceneGraph render order (earlier children render first). If shadows aren't visible, verify the Label IDs match in both XML and BRS.

## Deviations

- Google Fonts GitHub raw URL (`github.com/google/fonts/raw/...`) returned an HTML page due to Git LFS. Used the gstatic CDN URL (`fonts.gstatic.com/s/inter/...`) instead, which returns the actual font binary. The font name reads as ('Inter', 'Bold') and is 344KB (slightly larger than the plan's ~300KB estimate).

## Known Issues

None.

## Files Created/Modified

- `SimPlex/fonts/Inter-Bold.ttf` — new Inter Bold font file (344KB, SIL OFL license) from Google Fonts
- `bsconfig.json` — added `"fonts/**/*"` to files array for Roku deployment
- `SimPlex/components/widgets/Sidebar.xml` — replaced system font with Inter Bold Font child nodes, added shadow label nodes for depth effect
- `SimPlex/components/widgets/Sidebar.brs` — added dynamic positioning for shadow Plex label in init()
- `.gsd/milestones/M001/slices/S16/tasks/T01-PLAN.md` — added Observability Impact section (pre-flight fix)
