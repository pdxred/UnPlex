---
id: T02
parent: S16
milestone: M001
provides:
  - Branded icon_focus_fhd.png (540x405) with gradient bg and SimPlex text
  - Branded icon_side_fhd.png (246x140) with gradient bg and SimPlex text
  - Branded splash_fhd.jpg (1920x1080) with gradient bg and SimPlex text
  - In-app gradient background bg_gradient.png (1920x1080)
  - MainScene.xml uses Poster node with gradient bg instead of solid Rectangle
  - Reproducible Python/Pillow generation script
key_files:
  - SimPlex/images/icon_focus_fhd.png
  - SimPlex/images/icon_side_fhd.png
  - SimPlex/images/splash_fhd.jpg
  - SimPlex/images/bg_gradient.png
  - SimPlex/components/MainScene.xml
  - scripts/generate_branding.py
key_decisions:
  - Used pixel-by-pixel diagonal gradient (x+y)/(w+h) interpolation for smooth gradient across all asset sizes
  - Font size 28pt for side icon (246x140) instead of plan's 32pt to avoid text overflow on small canvas
  - Full offset grid for stroke (all non-zero dx,dy combinations) rather than just 4 cardinal offsets for smoother outline
patterns_established:
  - Python/Pillow asset generation pattern: scripts/generate_branding.py regenerates all branded assets deterministically from Inter-Bold.ttf
  - Poster node replaces Rectangle for image-based backgrounds in Roku SceneGraph
observability_surfaces:
  - Pre-deploy validation: python scripts/generate_branding.py regenerates and self-verifies all asset dimensions
  - Dimension check: python -c "from PIL import Image; img=Image.open('SimPlex/images/icon_focus_fhd.png'); print(img.size)"
  - Runtime: Missing bg_gradient.png causes Poster to render transparent/blank (visible on app launch)
  - Roku debugger console logs image load failures for pkg:/images/bg_gradient.png
duration: 8m
verification_result: passed
completed_at: 2026-03-23
blocker_discovered: false
---

# T02: Generate branded icon, splash, and gradient background assets

**Generated all branded image assets (icons, splash, gradient bg) with Pillow using Inter Bold text and diagonal gradient, replaced MainScene solid Rectangle with Poster gradient background.**

## What Happened

Created `scripts/generate_branding.py` — a Python/Pillow script that generates four branded assets:

1. **icon_focus_fhd.png** (540×405) — diagonal gradient (#1A1A2E→#0A0A14), centered "SimPlex" text with "Sim" in white and "Plex" in gold (#F3B125), gray (#666666) stroke outline at 2px offset, Inter Bold 72pt
2. **icon_side_fhd.png** (246×140) — same design scaled down, 28pt font, 1px stroke offset (adjusted from plan's 32pt/2px to fit the tight canvas)
3. **splash_fhd.jpg** (1920×1080, JPEG q=95) — same design at full resolution, 120pt font, 3px stroke offset
4. **bg_gradient.png** (1920×1080) — gradient only, no text, for in-app background

The gradient uses pixel-interpolated diagonal distance `t = (x + y) / (width + height)` for smooth color transition. The stroke effect renders text at all non-zero offset combinations in a ±N grid before the main colored text.

In MainScene.xml, replaced the `<Rectangle id="background" color="0x1A1A2EFF" />` with `<Poster id="background" uri="pkg:/images/bg_gradient.png" />` to display the gradient image as the full-screen app background.

## Verification

All 8 slice-level verification checks pass. This is the final task (T02) of slice S16, so all checks must pass:

- Focus icon: 540×405 ✓
- Side icon: 246×140 ✓
- Splash: 1920×1080 ✓
- Font file exists ✓
- Fonts glob in bsconfig.json ✓
- Inter-Bold in Sidebar.xml ✓
- bg_gradient.png exists ✓
- bg_gradient in MainScene.xml ✓

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `python -c "...Image.open('SimPlex/images/icon_focus_fhd.png'); assert img.size==(540,405)"` | 0 | ✅ pass | <1s |
| 2 | `python -c "...Image.open('SimPlex/images/icon_side_fhd.png'); assert img.size==(246,140)"` | 0 | ✅ pass | <1s |
| 3 | `python -c "...Image.open('SimPlex/images/splash_fhd.jpg'); assert img.size==(1920,1080)"` | 0 | ✅ pass | <1s |
| 4 | `python -c "...Image.open('SimPlex/images/bg_gradient.png'); assert img.size==(1920,1080)"` | 0 | ✅ pass | <1s |
| 5 | `python -c "assert 'bg_gradient' in open('SimPlex/components/MainScene.xml').read()"` | 0 | ✅ pass | <1s |
| 6 | `python -c "...count('Rectangle') == 0 and 'Poster' in content"` | 0 | ✅ pass | <1s |
| 7 | `python -c "assert os.path.isfile('SimPlex/fonts/Inter-Bold.ttf')"` (slice SV4) | 0 | ✅ pass | <1s |
| 8 | `python -c "assert 'fonts' in open('bsconfig.json').read()"` (slice SV5) | 0 | ✅ pass | <1s |
| 9 | `python -c "assert 'Inter-Bold' in open('SimPlex/components/widgets/Sidebar.xml').read()"` (slice SV6) | 0 | ✅ pass | <1s |
| 10 | `python -c "assert os.path.isfile('SimPlex/images/bg_gradient.png')"` (slice SV7) | 0 | ✅ pass | <1s |

## Diagnostics

- **Regenerate assets:** Run `python scripts/generate_branding.py` from the project root to regenerate all four branded assets. The script self-verifies dimensions after each save.
- **Runtime gradient background:** If the background appears blank/transparent after sideloading, check the BrightScript debugger console for image load failures on `pkg:/images/bg_gradient.png`. Verify the file is present in `out/staging/images/` after build.
- **Icon appearance on Roku home:** Roku firmware silently scales/crops incorrectly-sized icons. If icons appear blurry or misaligned, re-run the dimension verification commands above.

## Deviations

- Replaced Unicode checkmark (✓) in print statements with "OK:" to avoid Windows cp1252 encoding error in Python stdout.
- Used 28pt font and 1px stroke offset for side icon (246×140) instead of plan's 32pt/2px — the smaller canvas needed tighter text to avoid clipping.
- Used full offset grid for stroke (all non-zero dx,dy in ±N range) rather than just 4 cardinal offsets — produces a smoother, more uniform outline at minimal extra cost.
- Used Python assertions instead of `grep` for verification checks since `grep` is not available on Windows; functionally equivalent.

## Known Issues

None.

## Files Created/Modified

- `scripts/generate_branding.py` — new Python/Pillow script that generates all four branded image assets deterministically
- `SimPlex/images/icon_focus_fhd.png` — replaced with 540×405 branded design (20KB)
- `SimPlex/images/icon_side_fhd.png` — replaced with 246×140 branded design (5KB)
- `SimPlex/images/splash_fhd.jpg` — replaced with 1920×1080 branded JPEG (59KB, q=95)
- `SimPlex/images/bg_gradient.png` — new 1920×1080 gradient-only background (63KB)
- `SimPlex/components/MainScene.xml` — replaced Rectangle background with Poster node using bg_gradient.png
- `.gsd/milestones/M001/slices/S16/tasks/T02-PLAN.md` — added Observability Impact section (pre-flight fix)
