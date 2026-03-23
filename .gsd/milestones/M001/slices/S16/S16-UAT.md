# S16: App Branding — UAT Script

**Preconditions:**
- SimPlex project built and sideloaded to a Roku device in developer mode
- Roku device on same network as development machine
- BrightScript debugger console accessible (telnet to Roku port 8085)

---

## TC-01: Focus Icon on Roku Home Screen

**Objective:** Verify the focus icon displays correctly on the Roku home screen.

1. Navigate to the Roku home screen
2. Scroll to the SimPlex channel tile and highlight it (give it focus)
3. **Expected:** The focus icon (540×405) displays:
   - Diagonal gradient background transitioning from dark navy (#1A1A2E) to near-black (#0A0A14)
   - "SimPlex" text centered — "Sim" in white, "Plex" in gold
   - Text is in Inter Bold font (noticeably bolder than default system font)
   - Gray outline/stroke visible around text characters
   - Icon is sharp, not blurry or cropped by firmware scaling

**Edge case:** Compare with a non-focused state — the side icon (246×140) should show a similar but smaller branded design when the tile is not highlighted.

---

## TC-02: Splash Screen on App Launch

**Objective:** Verify the splash screen renders correctly during app startup.

1. Launch the SimPlex channel from the Roku home screen
2. Observe the splash screen during the brief loading period
3. **Expected:** Full-screen (1920×1080) branded splash:
   - Same diagonal gradient background as the icon
   - "SimPlex" text centered with "Sim" in white, "Plex" in gold
   - Text is large (120pt equivalent) and clearly in Inter Bold
   - Gray stroke visible around text
   - No pixelation, no JPEG compression artifacts at normal viewing distance

---

## TC-03: Sidebar Title Font

**Objective:** Verify the Sidebar "SimPlex" title uses Inter Bold with shadow effect.

1. After app loads, observe the Sidebar on the left side of the screen
2. Look at the "SimPlex" title at the top of the Sidebar
3. **Expected:**
   - "Sim" appears in white, "Plex" appears in gold (#F3B125)
   - Font is noticeably bolder than before (Inter Bold vs. system LargeBoldSystemFont)
   - Subtle gray shadow visible behind the text (2px offset, adds depth)
4. Navigate between different screens (Home, Settings, Search) — the title should remain consistently styled

**Edge case:** If the font fails to load, Roku firmware silently falls back to the system font. Compare the weight/style to the known Inter Bold appearance. If it looks identical to the pre-S16 system font, check the debugger console for font load errors.

---

## TC-04: In-App Gradient Background

**Objective:** Verify the in-app background is the gradient image, not a solid color.

1. Launch SimPlex and let it reach the Home screen
2. Look at the background visible around/behind content areas
3. **Expected:**
   - Smooth diagonal gradient from dark navy to near-black (same palette as icons)
   - NOT a flat solid color — the gradient should be perceptible, especially on larger empty areas
   - No banding artifacts (gradient should be smooth)
4. Navigate to different screens (Home → Library → Settings → Search)
5. **Expected:** Background gradient is consistent across all screens (it's the MainScene root background)

**Edge case:** If bg_gradient.png fails to load, the background will appear blank/transparent. The Roku debugger console will log an image load failure for `pkg:/images/bg_gradient.png`.

---

## TC-05: Font Deployment Verification (Pre-Sideload)

**Objective:** Verify the build system includes the font in the deployment package.

1. Run `npx bsc build` (or the F5 deploy process)
2. Check the staging directory: `out/staging/fonts/`
3. **Expected:** `Inter-Bold.ttf` is present in the staging output
4. If deploying via zip, unzip the package and confirm `fonts/Inter-Bold.ttf` is included

**Edge case:** If the font is missing from staging, verify `bsconfig.json` contains `"fonts/**/*"` in its files array.

---

## TC-06: Asset Dimension Integrity (Pre-Sideload)

**Objective:** Verify all branded assets are at correct Roku dimensions before deploying.

1. Run from project root:
   ```
   python scripts/generate_branding.py
   ```
2. Then run the dimension verification:
   ```
   python -c "from PIL import Image; sizes={'SimPlex/images/icon_focus_fhd.png':(540,405),'SimPlex/images/icon_side_fhd.png':(246,140),'SimPlex/images/splash_fhd.jpg':(1920,1080),'SimPlex/images/bg_gradient.png':(1920,1080)}; [exec('img=Image.open(p); assert img.size==s, f\"{p}: {img.size} != {s}\"') for p,s in sizes.items()]; print('All OK')"
   ```
3. **Expected:** "All OK" — all four assets at correct dimensions

---

## TC-07: BrightScript Debugger Console Check

**Objective:** Confirm no font or image load errors in the runtime console.

1. Connect to the BrightScript debugger console (telnet to Roku IP, port 8085)
2. Launch SimPlex
3. Navigate through Home, a library, Settings, and back
4. **Expected:** No errors related to:
   - `pkg:/fonts/Inter-Bold.ttf` (font load failure)
   - `pkg:/images/bg_gradient.png` (image load failure)
   - Any other asset-related errors
5. Console may show normal network/API activity — focus only on font and image errors

---

## Summary

| TC | Test | Type | Pass Criteria |
|----|------|------|--------------|
| TC-01 | Focus icon on home screen | Visual | Gradient bg, bold text, gray stroke, correct size |
| TC-02 | Splash screen on launch | Visual | Full-screen branded design, no artifacts |
| TC-03 | Sidebar title font | Visual | Inter Bold with shadow, "Sim" white / "Plex" gold |
| TC-04 | In-app gradient background | Visual | Smooth gradient, consistent across screens |
| TC-05 | Font in build output | Automated | Inter-Bold.ttf in staging/fonts/ |
| TC-06 | Asset dimensions | Automated | All 4 assets at correct pixel dimensions |
| TC-07 | Debugger console clean | Runtime | No font/image load errors |

**Minimum pass:** TC-05 and TC-06 must pass before sideloading. TC-01 through TC-04 require visual confirmation on device. TC-07 confirms clean runtime.
