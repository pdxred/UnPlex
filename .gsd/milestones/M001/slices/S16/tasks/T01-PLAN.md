---
estimated_steps: 5
estimated_files: 3
skills_used: []
---

# T01: Bundle Inter Bold font and wire into Sidebar title

**Slice:** S16 — App Branding
**Milestone:** M001

## Description

Download the Inter Bold static font file and integrate it into the SimPlex app package. Update the BrighterScript build configuration to include fonts in the deployment. Replace the system font on the Sidebar "SimPlex" title labels with the custom Inter Bold font using SceneGraph Font child nodes, and add shadow/stroke Label nodes behind each title label for a subtle depth effect.

## Steps

1. **Download Inter-Bold.ttf** — Obtain the static-weight Inter-Bold.ttf (~300KB, SIL OFL license) from Google Fonts. Create the `SimPlex/fonts/` directory and place the file there. Verify it loads in Pillow: `python3 -c "from PIL import ImageFont; f=ImageFont.truetype('SimPlex/fonts/Inter-Bold.ttf', 36); print(f.getname())"`. If download fails, copy from system path `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\Extensions\dmkamcknogkgcdfhhbddcghachkejeap\0.13.14_0\assets\Inter-Bold.ttf`.

2. **Update bsconfig.json** — Add `"fonts/**/*"` to the `files` array so the font deploys to the Roku device. The array currently contains: `manifest`, `source/**/*.brs`, `components/**/*.brs`, `components/**/*.xml`, `images/**/*`. Add `"fonts/**/*"` after the images entry.

3. **Update Sidebar.xml title labels** — Replace the two title Label nodes (`titleSim` and `titlePlex`) with versions that use child `<Font role="font">` nodes instead of the `font="font:LargeBoldSystemFont"` attribute. The `font=` attribute must be REMOVED entirely — it conflicts with child Font nodes. Use size 36 for both. Example:
   ```xml
   <Label id="titleSim" translation="[20, 25]" text="Sim" color="0xFFFFFFFF">
       <Font role="font" uri="pkg:/fonts/Inter-Bold.ttf" size="36" />
   </Label>
   ```

4. **Add shadow labels for depth effect** — Insert two shadow Label nodes BEFORE the main title labels (so they render behind). Offset by [2, 2] pixels from the main labels, with color `0x666666FF` (medium gray). These create the visual "stroke" effect in-app. Shadow labels also use Inter-Bold.ttf via child Font nodes. The shadow "Sim" label goes at translation `[22, 27]` and shadow "Plex" is positioned dynamically by Sidebar.brs. Note: Sidebar.brs lines 8-10 use `boundingRect()` on `titleSim` to position `titlePlex` — this pattern auto-adjusts for the new font width, no code change needed. However, verify the shadow Plex label also gets positioned: in `init()`, after the existing `titlePlex.translation` line, add equivalent positioning for the shadow Plex label: `titlePlexShadow.translation = [22 + simBounds.width, 27]`.

5. **Verify** — Run: `test -f SimPlex/fonts/Inter-Bold.ttf && grep -q "fonts" bsconfig.json && grep -q "Inter-Bold" SimPlex/components/widgets/Sidebar.xml && echo "PASS"`.

## Must-Haves

- [ ] `SimPlex/fonts/Inter-Bold.ttf` exists and is a valid TrueType font (~300KB)
- [ ] `bsconfig.json` files array includes `"fonts/**/*"`
- [ ] Sidebar.xml titleSim and titlePlex labels use `<Font role="font" uri="pkg:/fonts/Inter-Bold.ttf" size="36" />` child nodes
- [ ] Sidebar.xml titleSim and titlePlex labels do NOT have `font="font:LargeBoldSystemFont"` attribute
- [ ] Shadow Label nodes present behind both title labels with gray color and 2px offset
- [ ] Sidebar.brs init() positions shadow Plex label dynamically alongside the main Plex label

## Verification

- `test -f SimPlex/fonts/Inter-Bold.ttf` — font file exists
- `python3 -c "from PIL import ImageFont; f=ImageFont.truetype('SimPlex/fonts/Inter-Bold.ttf', 36); print('OK:', f.getname())"` — font is valid
- `grep -q '"fonts/\*\*/\*"' bsconfig.json && echo "fonts glob present"` — build config updated
- `grep -q "Inter-Bold" SimPlex/components/widgets/Sidebar.xml && echo "font wired"` — Sidebar uses custom font
- `grep -c "LargeBoldSystemFont" SimPlex/components/widgets/Sidebar.xml` — should return 0 (system font fully replaced)
- `grep -c "titleSimShadow\|titlePlexShadow" SimPlex/components/widgets/Sidebar.xml` — should return 2+ (shadow labels present)

## Inputs

- `SimPlex/components/widgets/Sidebar.xml` — current title label markup to modify
- `SimPlex/components/widgets/Sidebar.brs` — init() function that positions titlePlex dynamically (line 8-10); needs shadow Plex positioning added
- `bsconfig.json` — current build files array to extend

## Expected Output

- `SimPlex/fonts/Inter-Bold.ttf` — new font file bundled in app
- `bsconfig.json` — modified with fonts glob
- `SimPlex/components/widgets/Sidebar.xml` — modified with Font child nodes and shadow labels
- `SimPlex/components/widgets/Sidebar.brs` — modified with shadow Plex label positioning
