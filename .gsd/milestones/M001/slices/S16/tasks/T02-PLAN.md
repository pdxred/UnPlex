---
estimated_steps: 4
estimated_files: 6
skills_used: []
---

# T02: Generate branded icon, splash, and gradient background assets

**Slice:** S16 — App Branding
**Milestone:** M001

## Description

Generate all branded image assets using Python/Pillow: focus icon (540×405), side icon (246×140), splash screen (1920×1080), and in-app gradient background (1920×1080). All images use a consistent design: black-to-charcoal diagonal gradient background, "SimPlex" text in Inter Bold with "Sim" in white and "Plex" in gold, gray external stroke on the text. Then wire the gradient background into MainScene.xml by replacing the solid-color Rectangle with a Poster node.

## Steps

1. **Write the Python image generation script** — Create a Python script (e.g. `scripts/generate_branding.py`) that uses Pillow to generate all four images. The script should:
   - Load Inter-Bold.ttf from `SimPlex/fonts/Inter-Bold.ttf` (placed by T01)
   - For each image size, create the background gradient and render centered text
   - Design specification:
     - **Background**: Linear gradient from top-left (#1A1A2E, dark navy) to bottom-right (#0A0A14, near-black). Use pixel interpolation across the diagonal.
     - **Text**: Two-part "SimPlex" — "Sim" in white (#FFFFFF) and "Plex" in Plex gold (#F3B125), rendered side by side, horizontally and vertically centered on the canvas.
     - **Text stroke**: Draw the text first in gray (#666666) at 4 offsets (±2px horizontal, ±2px vertical) behind the main text to create an external stroke/outline effect. For the splash (large canvas), use ±3px offset.
     - **Font sizes**: icon_focus=72pt, icon_side=32pt, splash=120pt. Adjust if text overflows canvas — the icon_side at 246×140 is tight, may need ~28pt.
     - **bg_gradient.png**: Same gradient as above, NO text. Just the gradient at 1920×1080.
   - Output files directly to their target paths in `SimPlex/images/`.
   - `splash_fhd.jpg` must be saved as JPEG (quality=95). All others as PNG.

2. **Run the generation script** — Execute: `python3 scripts/generate_branding.py`. Verify all four files are created at correct dimensions.

3. **Update MainScene.xml** — Replace the solid-color Rectangle background with a Poster node that displays the gradient image. Change:
   ```xml
   <Rectangle
       id="background"
       width="1920"
       height="1080"
       color="0x1A1A2EFF"
   ```
   To:
   ```xml
   <Poster
       id="background"
       width="1920"
       height="1080"
       uri="pkg:/images/bg_gradient.png"
   ```
   The closing `/>` or `>` tag depends on whether the Rectangle was self-closing or had children — check the actual XML. The Poster node displays the gradient PNG as a static full-screen background, replacing the flat color. Remove the `color=` attribute (Poster doesn't use it).

4. **Verify all assets** — Run dimension checks on all four images and confirm MainScene.xml references bg_gradient.png:
   ```
   python3 -c "from PIL import Image; sizes={'SimPlex/images/icon_focus_fhd.png':(540,405),'SimPlex/images/icon_side_fhd.png':(246,140),'SimPlex/images/splash_fhd.jpg':(1920,1080),'SimPlex/images/bg_gradient.png':(1920,1080)}; [exec('img=Image.open(p); assert img.size==s, f\"{p}: {img.size} != {s}\"') for p,s in sizes.items()]; print('All dimensions OK')"
   grep -q "bg_gradient" SimPlex/components/MainScene.xml && echo "Gradient wired into MainScene"
   ```

## Must-Haves

- [ ] `SimPlex/images/icon_focus_fhd.png` is 540×405 PNG with gradient bg, Inter Bold "SimPlex" text (Sim=white, Plex=gold), gray stroke
- [ ] `SimPlex/images/icon_side_fhd.png` is 246×140 PNG with same branded design, proportionally scaled
- [ ] `SimPlex/images/splash_fhd.jpg` is 1920×1080 JPEG with same branded design, larger text
- [ ] `SimPlex/images/bg_gradient.png` is 1920×1080 PNG with gradient only (no text)
- [ ] `SimPlex/components/MainScene.xml` uses Poster node with `uri="pkg:/images/bg_gradient.png"` instead of solid Rectangle
- [ ] Generation script is committed for reproducibility

## Verification

- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/icon_focus_fhd.png'); assert img.size==(540,405)"` — focus icon
- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/icon_side_fhd.png'); assert img.size==(246,140)"` — side icon
- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/splash_fhd.jpg'); assert img.size==(1920,1080)"` — splash
- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/bg_gradient.png'); assert img.size==(1920,1080)"` — gradient bg
- `grep -q "bg_gradient" SimPlex/components/MainScene.xml` — gradient wired into MainScene
- `grep -c "Rectangle" SimPlex/components/MainScene.xml | head -1` — verify Rectangle for background is replaced (may still have other Rectangles in the file)

## Inputs

- `SimPlex/fonts/Inter-Bold.ttf` — font file for text rendering (created by T01)
- `SimPlex/components/MainScene.xml` — background node to replace
- `SimPlex/images/icon_focus_fhd.png` — existing file to overwrite (currently 336×210, wrong size)
- `SimPlex/images/icon_side_fhd.png` — existing file to overwrite (currently 108×69, wrong size)
- `SimPlex/images/splash_fhd.jpg` — existing file to overwrite (currently correct 1920×1080 but wrong design)

## Expected Output

- `SimPlex/images/icon_focus_fhd.png` — replaced with 540×405 branded design
- `SimPlex/images/icon_side_fhd.png` — replaced with 246×140 branded design
- `SimPlex/images/splash_fhd.jpg` — replaced with 1920×1080 branded design
- `SimPlex/images/bg_gradient.png` — new gradient background for in-app use
- `SimPlex/components/MainScene.xml` — modified to use Poster with gradient bg
- `scripts/generate_branding.py` — new generation script for reproducibility

## Observability Impact

- **New signals:** The `bg_gradient.png` Poster node in MainScene.xml will produce a visible gradient background on app launch. Missing or corrupt PNG will show as a magenta placeholder or blank background — immediately visible during visual inspection.
- **Icon/splash signals:** Roku firmware silently scales/crops incorrectly-sized icons on the home screen. The Python dimension-check script (`scripts/generate_branding.py` self-verifies) and slice verification commands provide pre-deploy validation.
- **Regeneration:** Running `python scripts/generate_branding.py` from the project root regenerates all four assets deterministically. Any changes to the design spec can be verified by re-running the script and checking output dimensions.
- **Failure visibility:** If the gradient background fails to load at runtime, the Poster node renders transparent (showing Scene default black). The BrightScript debugger console may log image load failures for `pkg:/images/bg_gradient.png`.
