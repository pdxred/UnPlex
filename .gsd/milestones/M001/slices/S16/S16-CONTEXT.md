---
id: S16
milestone: M001
status: ready
---

# S16: App Branding — Context

## Goal

Rebrand the app from "SimPlex" to "UnPlex" across the entire codebase (including the registry storage key), replace all bold system fonts with bundled Inter Bold, generate gradient icon and splash assets via ImageMagick, and bump the manifest to version 1.1.0.

## Why this Slice

With S15 completing the code cleanup and server switching removal, the codebase is final. Branding is the last visual step before S17 (Documentation and GitHub publish). The rename to "UnPlex" and the Inter Bold font give the channel a distinct identity on the Roku home screen and in the GitHub repo. This must be done before S17 because documentation, README screenshots, and the repo name all need to reflect the final brand.

## Scope

### In Scope

- **Rename "SimPlex" → "UnPlex" everywhere.** This includes:
  - `manifest` → `title=UnPlex`, `subtitle=Custom Plex Client` (subtitle unchanged or adjusted)
  - `constants.brs` → `PLEX_PRODUCT: "UnPlex"`
  - All `roRegistrySection("SimPlex")` calls in `utils.brs`, `MainScene.brs`, `ServerListScreen.brs` (if still present after S15) → `roRegistrySection("UnPlex")`
  - `MainScene.brs` exit dialog → `"Exit UnPlex?"`
  - Icon and splash wordmark text → "UnPlex"
  - Any other user-visible or internal string references to "SimPlex"
- **Accept data wipe from registry rename.** Changing the registry section key from "SimPlex" to "UnPlex" means all stored auth tokens, server URI, user preferences, and pinned libraries are lost on the next sideload. The user must re-authenticate via PIN flow after this update. This is accepted.
- **Bundle Inter Bold font.** Create `SimPlex/fonts/` directory (or rename to `UnPlex/fonts/` if the project directory is also renamed — see open questions), add `InterBold.ttf` (static weight, ~300KB, SIL OFL license). Update `bsconfig.json` to include `"fonts/**/*"` in the files array.
- **Replace all bold system fonts with Inter Bold.** All 27+ `font="font:LargeBoldSystemFont"` and `font="font:MediumBoldSystemFont"` references across screen XML files and BrightScript dynamic font assignments get replaced with Inter Bold at appropriate sizes. Non-bold system fonts (`MediumSystemFont`, `SmallSystemFont`) stay as-is for body text.
- **No stacked-label shadow effect.** Inter Bold provides sufficient visual weight. Do not add offset shadow Labels.
- **Generate icon and splash assets via ImageMagick.** Produce all five required assets:
  - `icon_focus_fhd.png` — 540×405 px, dark gradient background, "UnPlex" wordmark, Plex-gold accent
  - `icon_side_fhd.png` — 246×140 px, same branding scaled for legibility
  - `icon_focus_hd.png` — 336×210 px
  - `icon_side_hd.png` — 164×94 px
  - `splash_fhd.jpg` — 1920×1080 px, dark gradient background, large "UnPlex" wordmark centered, gold accent
  - All from the same source design so branding is consistent across variants
- **Gradient only on icon/splash.** In-app screen backgrounds remain solid black (`BG_PRIMARY: "0x000000FF"`). No gradient PNG Poster nodes added to screens.
- **Manifest version bump.** Change `major_version=1`, `minor_version=0`, `build_version=1` to `major_version=1`, `minor_version=1`, `build_version=0` (version 1.1.0).
- **Update bsconfig.json.** Add `"fonts/**/*"` to the files array so Inter Bold is included in the sideload package.

### Out of Scope

- **Renaming the project directory** from `SimPlex/` to `UnPlex/`. This would break all existing paths in `bsconfig.json`, `.gitignore`, scripts, and documentation. The directory stays as `SimPlex/` for now — it's an internal build artifact, not user-facing. Can be addressed in a future refactor if desired.
- **In-app gradient screen backgrounds.** Screens stay solid black.
- **Stacked-label shadow/stroke effect.** Not needed with Inter Bold.
- **Non-bold font replacement.** `MediumSystemFont`, `SmallSystemFont`, `LargeSystemFont` (non-bold) stay as Roku system fonts. Only bold variants are replaced.
- **Custom font for EpisodeItem or PosterGridItem.** These widget item components use small system fonts for metadata text — keep system fonts for legibility at small sizes.
- **Animated splash or icon.** Static assets only. Roku manifest expects static PNG/JPG.

## Constraints

- **Inter Bold must be static-weight TTF.** Variable font support on Roku's SceneGraph `Font` node is unverified. Use the static `Inter-Bold.ttf` file from the Inter font project, not the variable `Inter.ttf`.
- **All four icon variants must be updated in a single pass.** Updating only FHD icons while leaving HD unchanged creates mismatched branding on different Roku devices (per Pitfall 10 in research).
- **Splash must be exactly 1920×1080 pixels.** Roku firmware rejects or distorts other sizes.
- **ImageMagick must be available** for asset generation. The agent should verify `magick` or `convert` is on PATH before generating.
- **Registry data wipe is accepted.** After the `roRegistrySection` rename, all previously stored data is inaccessible. The first launch after sideload will require PIN re-authentication.
- **`bsconfig.json` files array must include `"fonts/**/*"`** or the font will be missing from the sideload package (blank labels instead of Inter Bold — silent failure, no crash).
- **Font size mapping:** `LargeBoldSystemFont` maps to Inter Bold at ~40-44px. `MediumBoldSystemFont` maps to Inter Bold at ~28-32px. Exact sizes should be tested on device — system bold and Inter Bold may render at different optical sizes. Start with the system font size equivalents and adjust if needed.

## Integration Points

### Consumes

- `SimPlex/manifest` — current version 1.0.1, title "SimPlex", icon/splash file references.
- `SimPlex/source/constants.brs` — `PLEX_PRODUCT: "SimPlex"`, `BG_PRIMARY: "0x000000FF"`.
- `SimPlex/source/utils.brs` — 15+ `roRegistrySection("SimPlex")` calls.
- `SimPlex/components/MainScene.brs` — exit dialog title, registry section call.
- All screen `.xml` files — 27+ `font="font:LargeBoldSystemFont"` and `font="font:MediumBoldSystemFont"` references.
- `SimPlex/components/screens/HomeScreen.brs` — dynamic `rowLabelFont = "font:MediumBoldSystemFont"` for hub rows.
- `bsconfig.json` — current files array (missing `fonts/**/*`).
- Inter font project (rsms.me/inter) — download static Bold weight.
- ImageMagick — for generating icon/splash assets.

### Produces

- `SimPlex/fonts/InterBold.ttf` — new bundled font file (~300KB).
- `SimPlex/images/icon_focus_fhd.png` — redesigned 540×405 icon with "UnPlex" wordmark.
- `SimPlex/images/icon_side_fhd.png` — redesigned 246×140 side icon.
- `SimPlex/images/icon_focus_hd.png` — redesigned 336×210 icon.
- `SimPlex/images/icon_side_hd.png` — redesigned 164×94 side icon.
- `SimPlex/images/splash_fhd.jpg` — redesigned 1920×1080 splash with "UnPlex" wordmark.
- Updated `bsconfig.json` — includes `"fonts/**/*"`.
- Updated `manifest` — version 1.1.0, title "UnPlex".
- Updated `constants.brs` — `PLEX_PRODUCT: "UnPlex"`.
- Updated `utils.brs` — all registry section calls use `"UnPlex"`.
- Updated `MainScene.brs` — exit dialog says "Exit UnPlex?".
- Updated screen XML files — all bold fonts reference Inter Bold via `<Font>` node.
- Updated `HomeScreen.brs` — dynamic hub row label font uses Inter Bold.

## Open Questions

- **Inter Bold font size mapping** — System `LargeBoldSystemFont` renders at a Roku-defined size (~40px at FHD). Inter Bold at the same pixel size may appear larger or smaller due to different metrics. The exact size for `<Font uri="pkg:/fonts/InterBold.ttf" size="XX" />` needs to be calibrated on device. Start with 40 for large titles and 28 for medium bold, adjust if they look wrong. This is a test-and-tune question, not a blocking design decision.
- **ImageMagick font availability** — ImageMagick needs a path to `InterBold.ttf` to render the wordmark on icons/splash. The agent should download the font first, then reference it in ImageMagick commands. If ImageMagick is not installed, fall back to a manual asset creation task.
- **Icon color palette** — The gradient direction, exact colors, and gold accent placement on the icon need to be decided during execution. Target: dark navy/black gradient matching the app's dark theme, "UnPlex" in white Inter Bold, subtle Plex-gold (`#E5A00D` / `0xE5A00DFF`) accent line or glow. The agent should generate a first pass and the user can request adjustments via UAT.
