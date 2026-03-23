# S16: App Branding

**Goal:** SimPlex icon, splash screen, and in-app Sidebar title use Inter Bold font with branded design — gradient backgrounds, gray text stroke, correct icon dimensions, and consistent visual identity.
**Demo:** Sideloaded channel shows 540×405 focus icon on Roku home screen with gradient bg and bold "SimPlex" text; splash screen renders the same branded design at 1920×1080; Sidebar title renders in Inter Bold with shadow effect.

## Must-Haves

- Inter Bold font bundled and used for Sidebar "SimPlex" title (BRAND-01)
- Icon and splash text rendered in Inter Bold with gray external stroke (BRAND-01, BRAND-02)
- Icon and splash backgrounds have subtle black-to-charcoal gradient (BRAND-03)
- `icon_focus_fhd.png` at 540×405, `icon_side_fhd.png` at 246×140, `splash_fhd.jpg` at 1920×1080 (BRAND-04)
- `bsconfig.json` includes `fonts/**/*` glob so font deploys to device
- In-app gradient background PNG replaces solid Rectangle in MainScene

## Proof Level

- This slice proves: operational
- Real runtime required: yes (side-load to Roku for visual confirmation)
- Human/UAT required: yes (visual branding must be eyeballed)

## Verification

- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/icon_focus_fhd.png'); assert img.size==(540,405), f'Wrong: {img.size}'"` — focus icon dimensions
- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/icon_side_fhd.png'); assert img.size==(246,140), f'Wrong: {img.size}'"` — side icon dimensions
- `python3 -c "from PIL import Image; img=Image.open('SimPlex/images/splash_fhd.jpg'); assert img.size==(1920,1080), f'Wrong: {img.size}'"` — splash dimensions
- `test -f SimPlex/fonts/Inter-Bold.ttf` — font file exists
- `grep -q "fonts" bsconfig.json` — font glob in build config
- `grep -q "Inter-Bold" SimPlex/components/widgets/Sidebar.xml` — custom font wired into Sidebar
- `test -f SimPlex/images/bg_gradient.png` — gradient background asset exists
- `grep -q "bg_gradient" SimPlex/components/MainScene.xml` — gradient background wired into MainScene
- Failure diagnostic: `python3 -c "from PIL import Image; [print(f'{p}: {Image.open(p).size}') for p in ['SimPlex/images/icon_focus_fhd.png','SimPlex/images/icon_side_fhd.png','SimPlex/images/splash_fhd.jpg']]"` — prints all dimensions for quick triage if any assertion fails

## Observability / Diagnostics

- Runtime signals: Roku firmware logs font load errors to BrightScript debugger console (`pkg:/fonts/Inter-Bold.ttf` path resolution failure shows as label rendering fallback to system font). No structured log from SimPlex code.
- Inspection surfaces: Visual inspection of Roku home screen (icon), app launch (splash), and Sidebar title (font). Python dimension-check script above for pre-deploy validation.
- Failure visibility: Wrong icon dimensions → Roku firmware silently scales/crops (visible as blurry or misaligned icon on home screen). Missing font → labels silently fall back to system font (visible as unchanged Sidebar title). Missing gradient PNG → Poster node shows magenta placeholder or blank.
- Redaction constraints: none

## Integration Closure

- Upstream surfaces consumed: `SimPlex/components/widgets/Sidebar.xml` (title labels), `SimPlex/components/MainScene.xml` (background Rectangle), `bsconfig.json` (build files), `SimPlex/manifest` (icon/splash paths — already correct, no change needed)
- New wiring introduced in this slice: Font node in Sidebar.xml, Poster node replacing Rectangle in MainScene.xml, shadow Label nodes for Sidebar title effect
- What remains before the milestone is truly usable end-to-end: S17 (Documentation and GitHub)

## Tasks

- [ ] **T01: Bundle Inter Bold font and wire into Sidebar title** `est:20m`
  - Why: BRAND-01 requires Inter Bold for app branding. The font must be bundled in the app package and wired into the Sidebar title labels. Build config must include the fonts directory.
  - Files: `SimPlex/fonts/Inter-Bold.ttf`, `bsconfig.json`, `SimPlex/components/widgets/Sidebar.xml`
  - Do: Download Inter-Bold.ttf (static weight, ~300KB) from Google Fonts or copy from system. Create `SimPlex/fonts/` directory. Add `"fonts/**/*"` to `bsconfig.json` files array. In Sidebar.xml, replace `font="font:LargeBoldSystemFont"` on titleSim and titlePlex with child `<Font role="font" uri="pkg:/fonts/Inter-Bold.ttf" size="36" />` nodes. Add shadow Label nodes (offset 2px, color `0x666666FF`) behind each title label for subtle depth effect. The `font=` attribute must be REMOVED when using child Font nodes — they are mutually exclusive.
  - Verify: `test -f SimPlex/fonts/Inter-Bold.ttf && grep -q "fonts" bsconfig.json && grep -q "Inter-Bold" SimPlex/components/widgets/Sidebar.xml`
  - Done when: Inter-Bold.ttf exists in fonts/, bsconfig includes fonts glob, Sidebar.xml uses Font child nodes with pkg:/fonts/Inter-Bold.ttf URI, shadow labels present

- [ ] **T02: Generate branded icon, splash, and gradient background assets** `est:30m`
  - Why: BRAND-01 through BRAND-04 require all icon/splash images regenerated with branded design (Inter Bold text, gray stroke, gradient bg) at correct Roku dimensions. BRAND-03 extends to an in-app gradient background.
  - Files: `SimPlex/images/icon_focus_fhd.png`, `SimPlex/images/icon_side_fhd.png`, `SimPlex/images/splash_fhd.jpg`, `SimPlex/images/bg_gradient.png`, `SimPlex/components/MainScene.xml`
  - Do: Write a Python/Pillow script that generates all four images: (1) icon_focus_fhd.png at 540×405, (2) icon_side_fhd.png at 246×140, (3) splash_fhd.jpg at 1920×1080, (4) bg_gradient.png at 1920×1080. Design: black-to-charcoal diagonal gradient background (#1A1A2E → #0A0A14), centered "SimPlex" text in Inter Bold with "Sim" in white and "Plex" in gold (#F3B125), gray (#666666) stroke/outline on text. Scale font size proportionally per image. In MainScene.xml, replace `<Rectangle id="background">` with `<Poster id="background" uri="pkg:/images/bg_gradient.png" width="1920" height="1080" />`.
  - Verify: `python3 -c "from PIL import Image; sizes={'SimPlex/images/icon_focus_fhd.png':(540,405),'SimPlex/images/icon_side_fhd.png':(246,140),'SimPlex/images/splash_fhd.jpg':(1920,1080),'SimPlex/images/bg_gradient.png':(1920,1080)}; [exec('img=Image.open(p); assert img.size==s, f\"{p}: {img.size} != {s}\"') for p,s in sizes.items()]; print('All OK')"`
  - Done when: All four images exist at correct dimensions, MainScene.xml uses Poster with bg_gradient.png instead of solid Rectangle

## Files Likely Touched

- `SimPlex/fonts/Inter-Bold.ttf` (new)
- `SimPlex/images/icon_focus_fhd.png` (replaced)
- `SimPlex/images/icon_side_fhd.png` (replaced)
- `SimPlex/images/splash_fhd.jpg` (replaced)
- `SimPlex/images/bg_gradient.png` (new)
- `bsconfig.json` (modified — add fonts glob)
- `SimPlex/components/widgets/Sidebar.xml` (modified — custom font + shadow labels)
- `SimPlex/components/MainScene.xml` (modified — gradient background)
